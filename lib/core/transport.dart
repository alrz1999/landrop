// Transports (DESIGN.md 3.4-3.6): how the bytes reach a peer that is already
// known. Pure dart:io. The core asks a [TransportSelector] for a [Link] and
// sends prepare-upload, upload, upload-status and cancel through it.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'api.dart';
import 'identity.dart' show fingerprintOfDer;

/// A verified way to talk to one peer: an HTTPS endpoint whose certificate
/// has the peer's fingerprint, and how long a small request took.
class Link {
  final String transportId;
  final String host;
  final int port;

  /// Pinned certificate fingerprint (always the peer's).
  final String fingerprint;

  /// Round trip of the request that verified this link.
  final Duration rtt;

  const Link({
    required this.transportId,
    required this.host,
    required this.port,
    required this.fingerprint,
    this.rtt = Duration.zero,
  });

  static String keyOf(String transportId, String host, int port) =>
      '$transportId|$host|$port';

  /// Identifies the endpoint (for exclusion after a failure).
  String get key => keyOf(transportId, host, port);

  Uri uri(String path, [Map<String, String>? query]) => Uri(
      scheme: 'https',
      host: host,
      port: port,
      path: path,
      queryParameters: query);

  @override
  String toString() =>
      '$transportId $host:$port (${rtt.inMicroseconds / 1000} ms)';
}

abstract class Transport {
  String get id;

  /// Tie-break between links whose round trips are about equal (higher
  /// wins).
  int get basePriority;

  /// Radio present, permission granted, etc.
  Future<bool> isAvailable();

  /// A verified link to [peer] within [timeout], or null. Endpoints whose
  /// [Link.key] is in [exclude] (they failed before) are not tried.
  Future<Link?> open(DeviceInfo peer,
      {Duration timeout = const Duration(seconds: 2),
      Set<String> exclude = const {}});
}

/// Checks that [host]:[port] serves the LocalSend info of a device with
/// [fingerprint], over TLS with that certificate.
typedef InfoProbe = Future<bool> Function(
    String host, int port, String fingerprint, Duration timeout);

/// Today's LAN path: HTTPS to the peer's IPv4 address. A peer can have
/// several addresses (Wi-Fi, hotspot, Ethernet); all are probed in parallel
/// and the first one that answers with the right certificate wins.
class LanHttpsTransport implements Transport {
  const LanHttpsTransport(
      {this.basePriority = 100,
      this.probe,
      this.endpoints,
      this.maxCandidates = 8});

  @override
  String get id => 'lan-https';
  @override
  final int basePriority;

  /// Test seam; default [verifyInfo].
  final InfoProbe? probe;

  /// Test seam: the (host, port) pairs to try; default
  /// [candidateEndpoints].
  final List<(String, int)> Function(DeviceInfo peer)? endpoints;
  final int maxCandidates;

  @override
  Future<bool> isAvailable() async => true;

  /// [DeviceInfo.ip], then [DeviceInfo.addresses], then the `lan-https`
  /// addresses from its capability record; duplicates removed.
  static List<(String, int)> candidateEndpoints(DeviceInfo peer,
      {int max = 8}) {
    final out = <(String, int)>[];
    void add(String h, int p) {
      if (h.isEmpty || h == '0.0.0.0' || p <= 0 || out.contains((h, p))) {
        return;
      }
      out.add((h, p));
    }

    add(peer.ip, peer.port);
    for (final a in peer.addresses) {
      add(a, peer.port);
    }
    for (final t in peer.capabilities?.transports ?? const []) {
      if (t.id != 'lan-https') continue;
      for (final a in t.addrs) {
        add(a, t.port ?? peer.port);
      }
    }
    return out.take(max).toList();
  }

  @override
  Future<Link?> open(DeviceInfo peer,
      {Duration timeout = const Duration(seconds: 2),
      Set<String> exclude = const {}}) {
    final fp = peer.fingerprint;
    final eps = [
      for (final e in (endpoints ??
          (p) => candidateEndpoints(p, max: maxCandidates))(peer))
        if (!exclude.contains(Link.keyOf(id, e.$1, e.$2))) e
    ];
    if (fp.isEmpty || eps.isEmpty) return Future.value(null);
    final check = probe ?? verifyInfo;
    final done = Completer<Link?>();
    var left = eps.length;
    for (final (host, port) in eps) {
      final sw = Stopwatch()..start();
      check(host, port, fp, timeout)
          .timeout(timeout + const Duration(milliseconds: 500),
              onTimeout: () => false)
          .then((ok) {
        if (ok && !done.isCompleted) {
          done.complete(Link(
              transportId: id,
              host: host,
              port: port,
              fingerprint: fp,
              rtt: sw.elapsed));
        }
      }, onError: (_) {}).whenComplete(() {
        if (--left == 0 && !done.isCompleted) done.complete(null);
      });
    }
    return done.future;
  }

  /// GET /api/localsend/v2/info, accepting only a certificate with
  /// [fingerprint], and the info must claim that same fingerprint.
  static Future<bool> verifyInfo(
      String host, int port, String fingerprint, Duration timeout) async {
    final c = HttpClient(context: SecurityContext(withTrustedRoots: false))
      ..connectionTimeout = timeout
      ..userAgent = 'LanDrop/1.0'
      ..badCertificateCallback =
          (cert, _, _) => fingerprintOfDer(cert.der) == fingerprint;
    try {
      final req = await c
          .getUrl(Uri(
              scheme: 'https',
              host: host,
              port: port,
              path: '/api/localsend/v2/info'))
          .timeout(timeout);
      final res = await req.close().timeout(timeout);
      final cert = res.certificate;
      if (res.statusCode != 200 ||
          cert == null ||
          fingerprintOfDer(cert.der) != fingerprint) {
        await res.drain<void>();
        return false;
      }
      final body = await res
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);
      final j = jsonDecode(body);
      return j is Map &&
          (j['fingerprint'] as Object?)?.toString().toLowerCase() ==
              fingerprint;
    } catch (_) {
      return false;
    } finally {
      c.close(force: true);
    }
  }
}

/// Picks the best [Link] to a peer (DESIGN.md 3.6): every available
/// transport opens in parallel; once the first link is up, the others get
/// [grace] to finish; links are ranked by round trip (differences below
/// [rttTolerance] count as equal) and then by [Transport.basePriority]. The
/// winner is cached per fingerprint for [cacheTtl].
class TransportSelector {
  TransportSelector(
    this.transports, {
    this.cacheTtl = const Duration(minutes: 5),
    this.timeout = const Duration(seconds: 2),
    this.grace = const Duration(milliseconds: 100),
    this.rttTolerance = const Duration(milliseconds: 10),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final List<Transport> transports;
  final Duration cacheTtl;
  final Duration timeout;
  final Duration grace;
  final Duration rttTolerance;
  final DateTime Function() _now;
  final Map<String, (Link, DateTime)> _cache = {};

  /// The cached link for [fingerprint], when not expired.
  Link? cached(String fingerprint) {
    final c = _cache[fingerprint];
    if (c == null) return null;
    if (!_now().isBefore(c.$2)) {
      _cache.remove(fingerprint);
      return null;
    }
    return c.$1;
  }

  /// Drops the cached link (call after a failure on it).
  void invalidate(String fingerprint) => _cache.remove(fingerprint);

  /// The cached link, else the best one found now (and cached).
  Future<Link?> select(DeviceInfo peer) async =>
      cached(peer.fingerprint) ?? await next(peer, const []);

  /// The best link that is not one of [exclude] (fallback after those
  /// failed); cached when found. Null when nothing else answers.
  Future<Link?> next(DeviceInfo peer, Iterable<Link> exclude) async {
    if (peer.fingerprint.isEmpty) return null;
    final ex = {for (final l in exclude) l.key};
    final found = await _race(peer, ex);
    if (found.isEmpty) return null;
    found.sort(_compare);
    final best = found.first.$2;
    _cache[peer.fingerprint] = (best, _now().add(cacheTtl));
    return best;
  }

  int _compare((Transport, Link) a, (Transport, Link) b) {
    final tol = rttTolerance.inMicroseconds <= 0 ? 1 : rttTolerance.inMicroseconds;
    final ra = a.$2.rtt.inMicroseconds ~/ tol;
    final rb = b.$2.rtt.inMicroseconds ~/ tol;
    if (ra != rb) return ra - rb;
    return b.$1.basePriority - a.$1.basePriority;
  }

  Future<List<(Transport, Link)>> _race(
      DeviceInfo peer, Set<String> exclude) async {
    final avail = <Transport>[];
    await Future.wait([
      for (final t in transports)
        t
            .isAvailable()
            .timeout(timeout, onTimeout: () => false)
            .then((ok) {
          if (ok) avail.add(t);
        }, onError: (_) {}),
    ]);
    if (avail.isEmpty) return const [];
    final results = <(Transport, Link)>[];
    final done = Completer<void>();
    Timer? graceTimer;
    void finish() {
      if (!done.isCompleted) done.complete();
    }

    var pending = avail.length;
    for (final t in avail) {
      Future<Link?>.sync(
              () => t.open(peer, timeout: timeout, exclude: exclude))
          .timeout(timeout + const Duration(seconds: 1), onTimeout: () => null)
          .then((l) {
        // Never trust a link that is not pinned to this peer.
        if (l != null &&
            l.fingerprint == peer.fingerprint &&
            !exclude.contains(l.key)) {
          results.add((t, l));
          graceTimer ??= Timer(grace, finish);
        }
      }, onError: (_) {}).whenComplete(() {
        if (--pending == 0) finish();
      });
    }
    await done.future;
    graceTimer?.cancel();
    return List.of(results);
  }
}
