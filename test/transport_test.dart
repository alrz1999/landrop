// Transport interface, selector and the send path's fallback (DESIGN.md
// 3.4-3.6). Fake transports for the selector; two real cores on loopback for
// address racing, fingerprint checks and stall -> fallback -> resume.
import 'dart:async';
import 'dart:convert';
import 'dart:io' hide Link;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/core/api.dart';
import 'package:landrop/core/discovery.dart';
import 'package:landrop/core/landrop_core.dart';
import 'package:landrop/core/transport.dart';

const _fp = 'aa11';
const _peer = DeviceInfo(
    alias: 'Peer', deviceType: 'desktop', fingerprint: _fp, ip: '10.0.0.2');

/// Returns a link after [delay] (or null when [fail]); [rtt] is what it
/// claims to have measured.
class _FakeTransport implements Transport {
  _FakeTransport(this.id,
      {this.basePriority = 0,
      this.delay = Duration.zero,
      this.rtt = const Duration(milliseconds: 5),
      this.fail = false,
      this.available = true,
      this.host = '10.0.0.2',
      this.port = 53317,
      this.fingerprint});
  @override
  final String id;
  @override
  final int basePriority;
  final Duration delay;
  final Duration rtt;
  bool fail;
  final bool available;
  final String host;
  final int port;
  final String? fingerprint;
  int opens = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<Link?> open(DeviceInfo peer,
      {Duration timeout = const Duration(seconds: 2),
      Set<String> exclude = const {}}) async {
    opens++;
    await Future<void>.delayed(delay);
    if (fail) return null;
    final l = Link(
        transportId: id,
        host: host,
        port: port,
        fingerprint: fingerprint ?? peer.fingerprint,
        rtt: rtt);
    return exclude.contains(l.key) ? null : l;
  }
}

LanDropCoreOptions _opts({
  List<Transport> transports = const [LanHttpsTransport()],
  Duration stallTimeout = const Duration(seconds: 5),
  DiscoveryTransport? discovery,
}) =>
    LanDropCoreOptions(
      port: 0,
      bindAddress: InternetAddress.loopbackIPv4,
      advertiseIp: '127.0.0.1',
      multicastEnabled: false,
      discoveryTransport: discovery,
      persistIdentity: false,
      decisionTimeout: const Duration(seconds: 10),
      announceInterval: const Duration(milliseconds: 300),
      retryBackoff: const Duration(milliseconds: 50),
      stallTimeout: stallTimeout,
      transports: transports,
    );

Future<String> _sha(File f) async =>
    (await sha256.bind(f.openRead()).first).toString();

Future<File> _randomFile(String path, int bytes, int seed) async {
  final f = File(path);
  await f.parent.create(recursive: true);
  final rnd = Random(seed);
  final sink = f.openWrite();
  for (var left = bytes; left > 0; left -= 1 << 20) {
    sink.add(List<int>.generate(min(left, 1 << 20), (_) => rnd.nextInt(256)));
  }
  await sink.close();
  return f;
}

/// TCP proxy to [target]. A connection that sends more than [stallAfter]
/// bytes stops being forwarded (the rest is dropped, nothing comes back),
/// like a Wi-Fi path that died mid-transfer; it is torn down when the client
/// gives up.
class _StallProxy {
  _StallProxy(this.target, this.stallAfter);
  final int target;
  final int stallAfter;
  late final ServerSocket _server;
  int connections = 0;
  int stalls = 0;
  int get port => _server.port;

  Future<void> start() async {
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_onClient);
  }

  Future<void> _onClient(Socket client) async {
    connections++;
    final Socket up;
    try {
      up = await Socket.connect(InternetAddress.loopbackIPv4, target);
    } catch (_) {
      client.destroy();
      return;
    }
    var forwarded = 0;
    var stalled = false;
    void close() {
      up.destroy();
      client.destroy();
    }

    client.listen((data) {
      if (stalled) return;
      if (forwarded + data.length > stallAfter) {
        final n = stallAfter - forwarded;
        if (n > 0) up.add(data.sublist(0, n));
        forwarded = stallAfter;
        stalled = true;
        stalls++;
        return;
      }
      forwarded += data.length;
      up.add(data);
    }, onDone: close, onError: (_) => close());
    up.listen((d) {
      if (stalled) return;
      try {
        client.add(d);
      } catch (_) {}
    }, onDone: close, onError: (_) => close());
  }

  Future<void> close() => _server.close();
}

/// In-memory discovery LAN (as in core_test.dart).
class _Hub {
  final List<_HubTransport> members = [];
}

class _HubTransport implements DiscoveryTransport {
  final _Hub hub;
  DiscoveryMessageHandler? _handler;
  int starts = 0;
  _HubTransport(this.hub);
  @override
  Future<void> start(DiscoveryMessageHandler onMessage) async {
    starts++;
    _handler = onMessage;
    hub.members.add(this);
  }

  @override
  Future<void> broadcast(Map<String, dynamic> message) async {
    final copy = jsonDecode(jsonEncode(message)) as Map<String, dynamic>;
    for (final m in List.of(hub.members)) {
      m._handler?.call(copy, InternetAddress.loopbackIPv4);
    }
  }

  @override
  Future<void> close() async => hub.members.remove(this);
}

void main() {
  group('TransportSelector with fake transports', () {
    test('lowest RTT wins; slow and failing transports do not block', () async {
      final fast = _FakeTransport('fast', rtt: const Duration(milliseconds: 2));
      final slower = _FakeTransport('slower',
          basePriority: 50, rtt: const Duration(milliseconds: 40));
      final failing = _FakeTransport('failing', fail: true, basePriority: 99);
      final hanging = _FakeTransport('hanging',
          basePriority: 99, delay: const Duration(seconds: 30));
      final off = _FakeTransport('off', available: false, basePriority: 99);
      final s = TransportSelector([hanging, failing, slower, fast, off],
          timeout: const Duration(milliseconds: 300));
      final sw = Stopwatch()..start();
      final l = await s.select(_peer);
      expect(l!.transportId, 'fast');
      expect(sw.elapsed, lessThan(const Duration(milliseconds: 250)),
          reason: 'does not wait for the hanging transport');
      expect(off.opens, 0, reason: 'unavailable transports are not opened');
    });

    test('about equal RTT: basePriority breaks the tie', () async {
      final low = _FakeTransport('low',
          basePriority: 1, rtt: const Duration(milliseconds: 3));
      final high = _FakeTransport('high',
          basePriority: 9, rtt: const Duration(milliseconds: 4));
      final s = TransportSelector([low, high]);
      expect((await s.select(_peer))!.transportId, 'high');
    });

    test('a link that only answers after the grace period loses', () async {
      final quick = _FakeTransport('quick',
          rtt: const Duration(milliseconds: 50));
      final late = _FakeTransport('late',
          delay: const Duration(milliseconds: 400),
          rtt: const Duration(milliseconds: 1));
      final s = TransportSelector([late, quick],
          grace: const Duration(milliseconds: 50));
      expect((await s.select(_peer))!.transportId, 'quick');
    });

    test('nothing answers: null, nothing cached', () async {
      final s = TransportSelector([_FakeTransport('x', fail: true)]);
      expect(await s.select(_peer), isNull);
      expect(s.cached(_fp), isNull);
    });

    test('cache: hit, expiry, invalidate', () async {
      var now = DateTime(2026, 1, 1);
      final t = _FakeTransport('t');
      final s = TransportSelector([t],
          cacheTtl: const Duration(minutes: 5), now: () => now);
      final first = await s.select(_peer);
      expect(t.opens, 1);
      expect(await s.select(_peer), same(first));
      expect(t.opens, 1, reason: 'cache hit');
      now = now.add(const Duration(minutes: 4, seconds: 59));
      await s.select(_peer);
      expect(t.opens, 1);
      now = now.add(const Duration(seconds: 2));
      expect(s.cached(_fp), isNull, reason: 'expired');
      await s.select(_peer);
      expect(t.opens, 2);
      s.invalidate(_fp);
      expect(s.cached(_fp), isNull);
      await s.select(_peer);
      expect(t.opens, 3);
    });

    test('next() skips failed links and falls back to the next transport',
        () async {
      final a = _FakeTransport('a',
          basePriority: 9, rtt: const Duration(milliseconds: 1));
      final b = _FakeTransport('b',
          host: '192.168.43.7', rtt: const Duration(milliseconds: 30));
      final s = TransportSelector([a, b]);
      final first = (await s.select(_peer))!;
      expect(first.transportId, 'a');
      final second = (await s.next(_peer, [first]))!;
      expect(second.transportId, 'b');
      expect(s.cached(_fp), same(second));
      expect(await s.next(_peer, [first, second]), isNull);
      // A transport that answers only after a failure is picked up again.
      a.fail = true;
      s.invalidate(_fp);
      expect((await s.select(_peer))!.transportId, 'b');
    });

    test('a link pinned to another fingerprint is never used', () async {
      final wrong = _FakeTransport('wrong',
          fingerprint: 'evil', basePriority: 99,
          rtt: const Duration(milliseconds: 1));
      final right = _FakeTransport('right',
          rtt: const Duration(milliseconds: 30));
      final s = TransportSelector([wrong, right]);
      expect((await s.select(_peer))!.transportId, 'right');
      expect(await TransportSelector([wrong]).select(_peer), isNull);
    });
  });

  group('LanHttpsTransport', () {
    test('candidates: ip, addresses, capability addrs, deduplicated', () {
      const p = DeviceInfo(
        alias: 'P',
        deviceType: 'mobile',
        fingerprint: _fp,
        ip: '192.168.1.5',
        port: 53317,
        addresses: ['192.168.1.5', '192.168.43.1'],
        capabilities: PeerCapabilities(transports: [
          TransportCapability('lan-https',
              addrs: ['192.168.1.5', '10.0.0.9'], port: 53318),
          TransportCapability('hotspot', ssid: 'x'),
        ]),
      );
      expect(LanHttpsTransport.candidateEndpoints(p), [
        ('192.168.1.5', 53317),
        ('192.168.43.1', 53317),
        ('192.168.1.5', 53318),
        ('10.0.0.9', 53318),
      ]);
    });

    test('probes all addresses in parallel and takes the fastest', () async {
      final delays = {
        '10.0.0.1': 300, // answers, but slowly
        '10.0.0.2': 20, // fastest
        '10.0.0.3': -1, // wrong fingerprint / no answer
        '10.0.0.4': 10000, // black hole
      };
      final probed = <String>[];
      final t = LanHttpsTransport(
        endpoints: (_) => [for (final h in delays.keys) (h, 53317)],
        probe: (host, port, fp, timeout) async {
          probed.add(host);
          final d = delays[host]!;
          if (d < 0) return false;
          await Future<void>.delayed(Duration(milliseconds: d));
          return true;
        },
      );
      final sw = Stopwatch()..start();
      final l = await t.open(_peer, timeout: const Duration(seconds: 1));
      expect(l!.host, '10.0.0.2');
      expect(l.fingerprint, _fp);
      expect(l.rtt, lessThan(const Duration(milliseconds: 250)));
      expect(sw.elapsed, lessThan(const Duration(milliseconds: 250)));
      expect(probed.toSet(), delays.keys.toSet(), reason: 'all in parallel');
      // Excluding the winner gives the next one.
      final l2 = await t.open(_peer,
          timeout: const Duration(seconds: 1), exclude: {l.key});
      expect(l2!.host, '10.0.0.1');
    });
  });

  group('two cores on loopback', () {
    late Directory tmp;
    late LanDropCoreImpl a;
    late LanDropCoreImpl b;
    StreamSubscription<IncomingRequest>? auto;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('landrop_transport');
      a = LanDropCoreImpl(_opts());
      b = LanDropCoreImpl(_opts());
      await a.start(alias: 'Alice', saveDir: '${tmp.path}/a');
      await b.start(alias: 'Bob', saveDir: '${tmp.path}/b');
      auto = b.incoming.listen((r) => r.decision.complete(true));
    });

    tearDown(() async {
      await auto?.cancel();
      await a.dispose();
      await b.dispose();
      await tmp.delete(recursive: true);
    });

    test('real address race: verified fingerprint only, fastest answer',
        () async {
      final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final closedPort = closed.port;
      await closed.close();
      final bob = DeviceInfo(
          alias: 'Bob',
          deviceType: 'desktop',
          fingerprint: b.self.fingerprint,
          ip: '127.0.0.1',
          port: b.self.port);
      // Alice's endpoint answers too, but with another certificate.
      final t = LanHttpsTransport(
          endpoints: (_) => [
                ('127.0.0.1', closedPort),
                ('127.0.0.1', a.self.port),
                ('127.0.0.1', b.self.port),
              ]);
      final l = await t.open(bob, timeout: const Duration(seconds: 2));
      expect(l!.port, b.self.port);
      // A peer claiming Bob's fingerprint at Alice's address only: rejected.
      final onlyAlice = LanHttpsTransport(
          endpoints: (_) => [('127.0.0.1', a.self.port)]);
      expect(await onlyAlice.open(bob), isNull);
      expect(
          await LanHttpsTransport.verifyInfo('127.0.0.1', a.self.port,
              b.self.fingerprint, const Duration(seconds: 2)),
          isFalse);
      expect(
          await LanHttpsTransport.verifyInfo('127.0.0.1', b.self.port,
              b.self.fingerprint, const Duration(seconds: 2)),
          isTrue);
    });

    test('same fingerprint at two addresses is one peer with both', () async {
      final seen = <List<DeviceInfo>>[];
      final sub = a.peers.listen(seen.add);
      await a.addPeerByIp('127.0.0.1', port: b.self.port);
      final viaName = await a.addPeerByIp('localhost', port: b.self.port);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();
      expect(viaName, isNotNull, reason: 'localhost reaches the same core');
      final peer = a.currentPeers.single;
      expect(peer.fingerprint, b.self.fingerprint);
      expect(peer.ip, '127.0.0.1', reason: 'best address kept');
      expect(peer.addresses, ['127.0.0.1', 'localhost']);
      expect(seen.every((l) => l.length <= 1), isTrue);
      // Sending works and uses a verified link.
      final f = File('${tmp.path}/x.txt')..writeAsStringSync('hi');
      expect((await a.sendFiles(peer, [SendItem(f.path)])).ok, isTrue);
      final cached = a.transportSelector.cached(b.self.fingerprint)!;
      expect(cached.transportId, 'lan-https');
      expect(cached.port, b.self.port);
    });

    test('connect failure on the best link falls back before prepare',
        () async {
      final dead = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final deadPort = dead.port;
      await dead.close();
      final c = LanDropCoreImpl(_opts(transports: [
        _FakeTransport('dead',
            host: '127.0.0.1',
            port: deadPort,
            basePriority: 1000,
            rtt: const Duration(milliseconds: 1)),
        const LanHttpsTransport(),
      ]));
      await c.start(alias: 'Carol', saveDir: '${tmp.path}/c');
      try {
        final peer = (await c.addPeerByIp('127.0.0.1', port: b.self.port))!;
        expect(c.transportSelector.cached(peer.fingerprint), isNull);
        final f = File('${tmp.path}/y.txt')..writeAsStringSync('fallback');
        final r = await c.sendFiles(peer, [SendItem(f.path)]);
        expect(r.ok, isTrue, reason: r.error);
        expect(File('${tmp.path}/b/y.txt').readAsStringSync(), 'fallback');
        expect(c.transportSelector.cached(peer.fingerprint)!.transportId,
            'lan-https');
      } finally {
        await c.dispose();
      }
    });

    test('upload stalls on one link, continues on the next, sha256 equal',
        () async {
      final proxy = _StallProxy(b.self.port, 1 << 20);
      await proxy.start();
      final c = LanDropCoreImpl(_opts(
        stallTimeout: const Duration(seconds: 1),
        transports: [
          _FakeTransport('stalling-path',
              host: '127.0.0.1',
              port: proxy.port,
              rtt: const Duration(milliseconds: 1)),
          _FakeTransport('good-path',
              host: '127.0.0.1',
              port: b.self.port,
              rtt: const Duration(milliseconds: 40)),
        ],
      ));
      await c.start(alias: 'Carol', saveDir: '${tmp.path}/c');
      try {
        final src = await _randomFile('${tmp.path}/big.bin', 4 << 20, 11);
        final peer = (await c.addPeerByIp('127.0.0.1', port: b.self.port))!;
        final prog = <TransferProgress>[];
        final sub = c.progress.listen(prog.add);
        final r = await c.sendFiles(peer, [SendItem(src.path)]);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await sub.cancel();
        expect(r.ok, isTrue, reason: r.error);
        expect(proxy.stalls, greaterThanOrEqualTo(1),
            reason: 'the first link really stalled');
        final dst = File('${tmp.path}/b/big.bin');
        expect(await dst.length(), 4 << 20);
        expect(await _sha(dst), await _sha(src));
        expect(
            Directory('${tmp.path}/b')
                .listSync()
                .where((e) => e.path.endsWith('.part')),
            isEmpty);
        expect(c.transportSelector.cached(peer.fingerprint)!.transportId,
            'good-path');
        expect(prog.last.done, isTrue);
        expect(prog.last.error, isNull);
      } finally {
        await c.dispose();
        await proxy.close();
      }
    });

    test('probeAddresses finds a core and skips our own address', () async {
      final found = await a.probeAddresses(['127.0.0.1', '127.0.0.1'],
          port: b.self.port);
      expect(found.single.fingerprint, b.self.fingerprint);
      expect(a.currentPeers.single.foundVia, {'scan'});
      expect(await a.probeAddresses(['127.0.0.1'], port: a.self.port),
          isEmpty);
    });

    test('hotspot capability entry only while sharing a hotspot', () async {
      Future<List<TransportCapability>> caps() async =>
          (await a.addPeerByIp('127.0.0.1', port: b.self.port))!
              .capabilities!
              .transports;
      expect((await caps()).map((t) => t.id), ['lan-https']);
      b.setHotspotInfo('LanDrop-1234', gateway: '192.168.49.1');
      final t = await caps();
      expect(t.map((t) => t.id), ['lan-https', 'hotspot']);
      expect(t.last.ssid, 'LanDrop-1234');
      expect(t.last.gateway, '192.168.49.1');
      expect(t.last.toJson(),
          {'id': 'hotspot', 'ssid': 'LanDrop-1234', 'gateway': '192.168.49.1'});
      b.setHotspotInfo(null);
      expect((await caps()).map((t) => t.id), ['lan-https']);
    });
  });

  test('restartDiscovery rebinds discovery and finds peers again', () async {
    final tmp = await Directory.systemTemp.createTemp('landrop_restart');
    final hub = _Hub();
    final tc = _HubTransport(hub);
    final c = LanDropCoreImpl(_opts(discovery: tc));
    final d = LanDropCoreImpl(_opts(discovery: _HubTransport(hub)));
    try {
      await c.start(alias: 'Carol', saveDir: '${tmp.path}/c');
      await d.start(alias: 'Dave', saveDir: '${tmp.path}/d');
      await c.peers
          .firstWhere((l) => l.isNotEmpty)
          .timeout(const Duration(seconds: 5));
      await c.restartDiscovery();
      expect(tc.starts, 2);
      expect(hub.members.where((m) => identical(m, tc)), hasLength(1));
      expect(c.discoveryError, isNull);
      expect(c.self.ip, '127.0.0.1');
      // Still announcing after the restart: d keeps seeing c.
      await d.stop();
      final d2 = LanDropCoreImpl(_opts(discovery: _HubTransport(hub)));
      try {
        await d2.start(alias: 'Dave2', saveDir: '${tmp.path}/d2');
        final l = await d2.peers
            .firstWhere((l) => l.any((p) => p.fingerprint == c.self.fingerprint))
            .timeout(const Duration(seconds: 5));
        expect(l, isNotEmpty);
      } finally {
        await d2.dispose();
      }
    } finally {
      await c.dispose();
      await d.dispose();
      await tmp.delete(recursive: true);
    }
  });
}
