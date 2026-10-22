// LocalSend-v2-compatible implementation of [LanDropCore] (pure dart:io).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show min;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'api.dart';
import 'diagnosis.dart';
import 'discovery.dart';
import 'guarded_server.dart';
import 'mdns.dart';
import 'identity.dart';
import 'transport.dart';
import 'util.dart';
import 'web_server.dart';

export 'discovery.dart' show DiscoveryTransport, MulticastDiscoveryTransport;
export 'mdns.dart' show MdnsSocket, RawMdnsSocket;
export 'identity.dart' show TlsIdentity, fingerprintOfDer;
// `Link` is not re-exported (it would clash with dart:io's Link); import
// transport.dart for it.
export 'transport.dart'
    show Transport, LanHttpsTransport, TransportSelector, InfoProbe;
export 'util.dart' show sanitizeFileName, sanitizeRelativePath;
export 'guarded_server.dart' show ServerLimits;
export 'web_server.dart' show parseRange, ByteRange, RangeNotSatisfiable;

const _apiBase = '/api/localsend/v2';
const _landropBase = '/api/landrop/v1';
const _protocolVersion = '2.1';

class LanDropCoreOptions {
  /// Preferred HTTPS port. If busy, the next [portFallbackRange] ports are
  /// tried. 0 = ephemeral port.
  final int port;
  final int portFallbackRange;

  /// Address the HTTPS server binds to.
  final InternetAddress? bindAddress;

  /// IP advertised in [LanDropCore.self]. Auto-detected when null.
  final String? advertiseIp;

  /// Enable UDP multicast discovery (ignored if [discoveryTransport] given).
  final bool multicastEnabled;
  final int multicastPort;

  /// Custom discovery transport (e.g. in-memory for tests).
  final DiscoveryTransport? discoveryTransport;

  /// Also discover and advertise through mDNS / Bonjour (`_landrop._tcp`,
  /// DESIGN.md 2.4a). Off by default; the app turns it on.
  final bool mdnsEnabled;

  /// Test seam: how the mDNS socket is made (default [RawMdnsSocket]).
  final MdnsSocket Function()? mdnsSocketFactory;

  /// Test seam: accept 127.x.x.x addresses found through mDNS.
  final bool mdnsAllowLoopback;

  /// Where cert.pem/key.pem are kept. Null: `<saveDir>/.landrop` (copied to
  /// a new save folder when it changes). When set, an identity found in
  /// `<saveDir>/.landrop` is migrated here once (DESIGN.md 2.10).
  final String? identityDir;

  /// When false a new certificate is generated every run.
  final bool persistIdentity;

  final String deviceType;
  final String? deviceModel;

  final Duration announceInterval;
  final Duration peerTimeout;

  /// How long to wait for the UI to accept/decline an incoming request.
  final Duration decisionTimeout;

  /// Receiver drops an accepted session if no upload activity for this long.
  final Duration sessionIdleTimeout;

  final Duration probeTimeout;
  final Duration scanTimeout;
  final int scanConcurrency;

  /// Hosts [LanDropCore.scanSubnet] probes instead of the local /24s
  /// (test seam). Null: scan every local /24.
  final List<String>? scanHosts;

  /// Sender: an upload with no bytes moving for this long is aborted and
  /// resumed (see [uploadRetries]).
  final Duration stallTimeout;

  /// Sender: how many times a broken upload is resumed before giving up.
  final int uploadRetries;

  /// Sender: delay before the first resume; doubled for each further one.
  final Duration retryBackoff;

  /// Test seam: called on the sender for every chunk written to an upload
  /// connection with the file id, bytes sent so far (including the resume
  /// offset) and the attempt number (0 = first). Returning true kills that
  /// connection, as if the network dropped.
  final bool Function(String fileId, int sentBytes, int attempt)?
      debugKillUpload;

  /// Plain HTTP listener for browsers (DESIGN.md 4.4 option 2). Null: off
  /// at start (turn on with [LanDropCore.setWebHttpEnabled]; it then uses
  /// port 53320 or a free one). 0: on, ephemeral port.
  final int? httpPort;

  /// Browser access: pairing timeout, pending pairing cap, failed attempts
  /// per IP per [webRateWindow] before 429, browser session lifetime, and
  /// how long a charged range sequence stays open (see [WebService]).
  final Duration webPairingTimeout;
  final int webMaxPendingPairings;
  final int webRateLimit;
  final Duration webRateWindow;
  final Duration webSessionTtl;
  final Duration webStreamWindow;

  /// Test seam: clock for the expiry of nearby nonces, tickets, grants and
  /// prompts. Null: the system clock.
  final DateTime Function()? webClock;

  /// JSON file where shares are kept across restarts (DESIGN.md 4.8). Null:
  /// shares live in memory only. See [LanDropCore.setSharesPersistence].
  final String? sharesStorePath;

  /// Ways to reach a peer when sending (DESIGN.md 3.4). The best link is
  /// chosen by [TransportSelector] and cached for [linkCacheTtl]; a stalled
  /// upload falls back to the next one.
  final List<Transport> transports;

  /// How long the selector waits for transports to open a link.
  final Duration selectTimeout;
  final Duration linkCacheTtl;

  /// Connection limits of the HTTPS server and the HTTP listener
  /// (SECURITY.md S1).
  final ServerLimits serverLimits;

  /// Most peers kept in the peer table (SECURITY.md S4).
  final int maxPeers;

  /// Prepare-upload: most files in one request, and the largest declared
  /// size of one file and of all files together (SECURITY.md S5).
  final int maxOfferFiles;
  final int maxOfferBytes;

  /// Per remote IP: declined, withdrawn or unanswered prepare-uploads and
  /// failed token checks allowed within [webRateWindow] before 429
  /// (SECURITY.md S15).
  final int requestRateLimit;

  /// Free bytes in a folder, or null when unknown (test seam; default
  /// [freeDiskBytes]). A transfer larger than the free space is refused
  /// with 507 (SECURITY.md S18).
  final Future<int?> Function(String dir)? freeSpace;

  const LanDropCoreOptions({
    this.port = 53317,
    this.portFallbackRange = 20,
    this.bindAddress,
    this.advertiseIp,
    this.multicastEnabled = true,
    this.multicastPort = 53317,
    this.discoveryTransport,
    this.mdnsEnabled = false,
    this.mdnsSocketFactory,
    this.mdnsAllowLoopback = false,
    this.identityDir,
    this.persistIdentity = true,
    this.deviceType = 'desktop',
    this.deviceModel,
    this.announceInterval = const Duration(seconds: 5),
    this.peerTimeout = const Duration(seconds: 20),
    this.decisionTimeout = const Duration(seconds: 120),
    this.sessionIdleTimeout = const Duration(minutes: 2),
    this.probeTimeout = const Duration(seconds: 3),
    this.scanTimeout = const Duration(milliseconds: 2500),
    this.scanConcurrency = 64,
    this.scanHosts,
    this.stallTimeout = const Duration(seconds: 15),
    this.uploadRetries = 3,
    this.retryBackoff = const Duration(milliseconds: 500),
    this.debugKillUpload,
    this.httpPort,
    this.webPairingTimeout = const Duration(seconds: 60),
    this.webMaxPendingPairings = 5,
    this.webRateLimit = 10,
    this.webRateWindow = const Duration(minutes: 1),
    this.webSessionTtl = const Duration(hours: 1),
    this.webStreamWindow = const Duration(minutes: 30),
    this.sharesStorePath,
    this.transports = const [LanHttpsTransport()],
    this.selectTimeout = const Duration(seconds: 2),
    this.linkCacheTtl = const Duration(minutes: 5),
    this.serverLimits = const ServerLimits(),
    this.maxPeers = 256,
    this.maxOfferFiles = 10000,
    this.maxOfferBytes = 1 << 50,
    this.requestRateLimit = 10,
    this.freeSpace,
    this.webClock,
  });
}

typedef _HttpError = HttpStatusError;

/// Upload attempt outcome. [broken]: the connection failed or stalled, so
/// another link may work better; [retry]: the receiver answered 400/409.
enum _Attempt { ok, retry, broken, fatal }

/// Connecting to the peer failed (before anything was sent).
class _ConnectFailed implements Exception {
  final Object cause;
  _ConnectFailed(this.cause);
  @override
  String toString() => '$cause';
}

/// The link a send currently uses, and the links that failed for it.
class _Route {
  Link link;
  final List<Link> failed = [];
  _Route(this.link);
}

class _Peer {
  DeviceInfo info;
  DateTime lastSeen;
  bool probing = false;

  /// How this peer was found (see [DeviceInfo.foundVia]).
  final Set<String> via = {};

  /// Every address this peer was verified at, and when it was last seen
  /// there. [info.ip] is the best one (see [LanDropCoreImpl._upsertPeer]).
  final Map<String, DateTime> addrs = {};
  _Peer(this.info) : lastSeen = DateTime.now() {
    addrs[info.ip] = lastSeen;
  }

  /// [info.ip] first.
  List<String> get addresses =>
      [info.ip, ...addrs.keys.where((a) => a != info.ip)];
}

/// One file of an accepted incoming session.
class _InFile {
  final FileOffer offer;
  final String token;

  /// Directory segments below saveDir (already sanitised, top-level folder
  /// already made unique) and the sanitised file name.
  final List<String> dirSegs;
  final String name;

  /// Temporary `.<name>.part` file; renamed to the final name when complete.
  File? part;
  bool active = false;
  bool finished = false;
  _InFile(this.offer, this.token, this.dirSegs, this.name);
}

/// A send in progress (after the receiver accepted), so
/// [LanDropCoreImpl.cancelSession] can stop it.
class _OutSend {
  final _Route route;
  final String? cancelSecret;
  bool cancelled = false;

  /// The upload request currently streaming, aborted on cancel.
  HttpClientRequest? current;
  _OutSend(this.route, this.cancelSecret);
}

class _InSession {
  final String id;
  final DeviceInfo sender;
  final Map<String, _InFile> files;

  /// Given to the sender in prepare-upload; required by /cancel.
  final String cancelSecret;

  /// Directories this session created (deleted again if left empty).
  final List<String> createdDirs = [];
  bool cancelled = false;

  /// Why the session ended early, for the progress events of its files.
  SendErrorCode? endCode;
  Timer? idle;

  /// Browser session that created it (browser uploads only).
  final String? owner;

  /// The save folder when the session was accepted; its files go below it
  /// even if [LanDropCoreImpl.setSaveDir] changes the folder meanwhile.
  final String saveDir;
  _InSession(this.id, this.sender, this.files, this.cancelSecret,
      {this.owner, required this.saveDir});

  bool get anyActive => files.values.any((f) => f.active);
  bool get allFinished => files.values.every((f) => f.finished);
}

class LanDropCoreImpl implements LanDropCore {
  final LanDropCoreOptions options;
  LanDropCoreImpl([this.options = const LanDropCoreOptions()]);

  final _peerCtrl = StreamController<List<DeviceInfo>>.broadcast();
  final _incomingCtrl = StreamController<IncomingRequest>.broadcast();
  final _progressCtrl = StreamController<TransferProgress>.broadcast();

  final Map<String, _Peer> _peers = {}; // keyed by fingerprint
  GuardedHttpServer? _server;
  DiscoveryTransport? _discovery;
  TlsIdentity? _identity;
  DeviceInfo? _self;
  String _saveDir = '.';
  Timer? _announceTimer;
  Timer? _pruneTimer;
  bool _running = false;
  Completer<void> _stopped = Completer<void>();

  bool _pendingDecision = false;

  /// The request waiting for this device's answer and the sender's
  /// withdraw secret (null for browsers and LocalSend senders).
  (IncomingRequest, String?)? _pending;
  _InSession? _session;

  /// Sends the receiver accepted and that are still uploading, by session id.
  final Map<String, _OutSend> _outgoing = {};
  String? _discoveryError;

  MdnsService? _mdns;
  StreamSubscription<MdnsCandidate>? _mdnsSub;

  /// Devices mDNS reported, by fingerprint (for the diagnosis).
  final Map<String, MdnsPeerObservation> _mdnsSeen = {};

  /// Failed or refused requests per remote IP (SECURITY.md S15).
  late final AttemptLimiter _limiter = AttemptLimiter(
      limit: options.requestRateLimit, window: options.webRateWindow);

  /// Throttle for the outbound verifications that untrusted discovery data
  /// (UDP announce, mDNS, register) causes (SECURITY.md S4).
  final Map<String, DateTime> _verifyFailed = {};
  final Set<String> _verifyRunning = {};
  final Map<String, int> _verifyPerIp = {};
  DateTime _lastUdpReply = DateTime.fromMillisecondsSinceEpoch(0);
  static const _maxVerifyInflight = 16;
  static const _maxVerifyPerIp = 4;
  static const _verifyRetryAfter = Duration(seconds: 5);
  static const _maxMdnsSeen = 64;

  /// Free space kept after a transfer (SECURITY.md S18).
  static const _freeSpaceMargin = 64 << 20;

  /// Addresses advertised in the capability record (set on start).
  List<String> _capAddrs = const [];

  /// Hotspot this device shares (capability `hotspot` entry), if any.
  String? _hotspotSsid;
  String? _hotspotGateway;

  /// Chooses and caches the link used to send to a peer.
  late final TransportSelector _selector = TransportSelector(
      options.transports,
      timeout: options.selectTimeout,
      cacheTtl: options.linkCacheTtl);

  /// Test/diagnostic access to the link selector.
  TransportSelector get transportSelector => _selector;

  /// Browser access (web page, pairing, shares, HTTP listener).
  late final WebService _web = WebService(
    config: WebConfig(
      httpPort: options.httpPort,
      bindAddress: options.bindAddress,
      pairingTimeout: options.webPairingTimeout,
      maxPendingPairings: options.webMaxPendingPairings,
      rateLimit: options.webRateLimit,
      rateWindow: options.webRateWindow,
      sessionTtl: options.webSessionTtl,
      streamWindow: options.webStreamWindow,
      serverLimits: options.serverLimits,
    ),
    selfInfo: () => self,
    prepareUpload: (req, sender, files, owner) =>
        _prepareIncoming(req, sender, files, owner: owner),
    upload: (req, owner) => _handleUpload(req, owner: owner),
    onSessionEnded: _onWebSessionEnded,
    storePath: options.sharesStorePath,
    now: options.webClock,
    knownAlias: (fp) => _peers[fp]?.info.alias,
  );

  /// A browser signed out or was disconnected: its receive session (if any)
  /// is cancelled, so uploads prepared under it are refused from now on.
  void _onWebSessionEnded(String owner) {
    final s = _session;
    if (s != null && s.owner == owner) {
      s.endCode = SendErrorCode.cancelled;
      _endSession(s, reason: 'browser disconnected');
    }
  }

  static const _progressStep = 256 * 1024;

  // ------------------------------------------------------- browser access

  @override
  Stream<WebPairingRequest> get webPairing => _web.pairing;
  @override
  List<Share> get shares => _web.shares;
  @override
  Stream<List<Share>> get sharesChanged => _web.sharesChanged;
  @override
  Share createShare(List<String> paths,
          {Duration? ttl, int? maxDownloads, bool nearby = false}) =>
      _web.createShare(paths,
          ttl: ttl, maxDownloads: maxDownloads, nearby: nearby);
  @override
  void setShareNearby(String id, bool on) => _web.setShareNearby(id, on);
  @override
  void setNearbyTrusted(Set<String> fingerprints) =>
      _web.setNearbyAllowed(fingerprints);
  @override
  void revokeNearbyAccess(String fp) => _web.revokeNearbyAccess(fp);
  @override
  Stream<NearbyAccessRequest> get nearbyRequests => _web.nearbyRequests;
  @override
  void respondNearbyAccess(String id, NearbyDecision decision) =>
      _web.respondNearbyAccess(id, decision);

  /// Test seam: the browser/nearby service.
  @visibleForTesting
  WebService get debugWeb => _web;

  @override
  void revokeShare(String id) => _web.revokeShare(id);
  @override
  bool get sharesPersistence => _web.persistence;
  @override
  void setSharesPersistence(bool enabled) => _web.setPersistence(enabled);
  @override
  List<WebSessionInfo> get webSessions => _web.sessions;
  @override
  Stream<List<WebSessionInfo>> get webSessionsChanged => _web.sessionsChanged;
  @override
  void revokeWebSession(String id) => _web.revokeSession(id);
  @override
  String? get webUrl => _web.webUrl;
  @override
  bool get webHttpEnabled => _web.httpEnabled;
  @override
  Future<void> setWebHttpEnabled(bool enabled) =>
      _web.setHttpEnabled(enabled);
  @override
  int? get webHttpPort => _web.httpPort;
  @override
  String? get webHttpUrl => _web.httpUrl;

  // ---------------------------------------------------------------- public

  @override
  DeviceInfo get self =>
      _self ??
      DeviceInfo(
          alias: '',
          deviceType: options.deviceType,
          deviceModel: options.deviceModel,
          fingerprint: '',
          ip: '0.0.0.0',
          port: options.port);

  /// Emits the current list immediately on listen, then on every change.
  @override
  Stream<List<DeviceInfo>> get peers => Stream.multi((c) {
        c.add(currentPeers);
        final sub = _peerCtrl.stream.listen(c.add, onDone: c.close);
        c.onCancel = sub.cancel;
      }, isBroadcast: true);

  List<DeviceInfo> get currentPeers => List.unmodifiable(_peers.values.map(
      (p) => p.info.copyWith(
          foundVia: Set.unmodifiable(p.via),
          addresses: List.unmodifiable(p.addresses))));

  @override
  Stream<IncomingRequest> get incoming => _incomingCtrl.stream;

  @override
  String? get discoveryError => _discoveryError;

  @override
  Stream<TransferProgress> get progress => _progressCtrl.stream;

  @override
  Future<void> start({required String alias, required String saveDir}) async {
    if (_running) return;
    _saveDir = Directory(saveDir).absolute.path;
    await Directory(_saveDir).create(recursive: true);
    final idDir = options.persistIdentity
        ? (options.identityDir ??
            '$_saveDir${Platform.pathSeparator}.landrop')
        : null;
    final known = _identity;
    // With an [identityDir] (the app passes its support folder), an
    // identity left in `<saveDir>/.landrop` by older versions is copied
    // there once, so the fingerprint stays the same.
    final identity = _identity ??= await TlsIdentity.loadOrCreate(idDir,
        migrateFrom: options.identityDir == null
            ? null
            : '$_saveDir${Platform.pathSeparator}.landrop');
    // The save folder changed during this run: keep the same identity (and
    // so the same security code) there, instead of a new one next start.
    if (known != null && idDir != null) await _storeIdentity(known, idDir);

    final server = await _bind(identity.securityContext());
    _server = server;
    _stopped = Completer<void>();
    _running = true;

    final lanAddrs = (await localIPv4Addresses()).map((a) => a.address);
    final ip = options.advertiseIp ?? lanAddrs.firstOrNull ?? '127.0.0.1';
    _capAddrs = {ip, ...lanAddrs}.toList();
    _self = DeviceInfo(
        alias: alias,
        deviceType: options.deviceType,
        deviceModel: options.deviceModel,
        fingerprint: identity.fingerprint,
        ip: ip,
        port: server.port);

    server.http.listen(_handle, onError: (_) {});
    await _web.start();
    await _startDiscovery();
    await _startMdns();
    _pruneTimer = Timer.periodic(
        Duration(
            milliseconds:
                (options.peerTimeout.inMilliseconds ~/ 4).clamp(250, 5000)),
        (_) => _prune());
  }

  /// Writes [id] to [dir] unless an identity is already stored there.
  static Future<void> _storeIdentity(TlsIdentity id, String dir) async {
    try {
      if (await File('$dir${Platform.pathSeparator}cert.pem').exists()) return;
      await id.save(dir);
    } catch (_) {}
  }

  @override
  Future<void> setSaveDir(String saveDir) async {
    final dir = Directory(saveDir).absolute.path;
    await Directory(dir).create(recursive: true);
    _saveDir = dir;
    final id = _identity;
    if (id != null && options.persistIdentity && options.identityDir == null) {
      await _storeIdentity(id, '$dir${Platform.pathSeparator}.landrop');
    }
  }

  /// Starts UDP discovery (a new socket bound and joined on the current
  /// interfaces) and the announce timer. Failures end up in
  /// [discoveryError].
  Future<void> _startDiscovery() async {
    _discoveryError = null;
    final transport = options.discoveryTransport ??
        (options.multicastEnabled
            ? MulticastDiscoveryTransport(port: options.multicastPort)
            : null);
    if (transport == null) return;
    try {
      await transport.start(_onDiscoveryMessage);
      if (!_running) {
        await transport.close();
        return;
      }
      _discovery = transport;
      unawaited(_announce());
      _announceTimer =
          Timer.periodic(options.announceInterval, (_) => _announce());
    } catch (e) {
      // multicast unavailable; scanSubnet/addPeerByIp still work
      stderr.writeln('LanDrop: UDP discovery unavailable: $e');
      _discoveryError = e is SocketException
          ? (e.osError?.message.isNotEmpty == true
              ? '${e.message}: ${e.osError!.message}'
              : e.message)
          : '$e';
      _discovery = null;
      try {
        await transport.close();
      } catch (_) {}
    }
  }

  /// Starts mDNS (advertise + browse). Failure only sets the error that the
  /// diagnosis shows; it never breaks the app.
  Future<void> _startMdns() async {
    if (!options.mdnsEnabled || !_running) return;
    final svc = MdnsService(
      socket: options.mdnsSocketFactory?.call() ?? RawMdnsSocket(),
      fingerprint: self.fingerprint,
      alias: self.alias,
      deviceType: self.deviceType,
      port: self.port,
      addresses: () async => {
        for (final a in await localIPv4Addresses()) a.address,
        ?options.advertiseIp,
      }.toList(),
      allowLoopback: options.mdnsAllowLoopback,
    );
    try {
      await svc.start();
    } catch (e) {
      svc.error = '$e';
    }
    if (!_running) {
      await svc.stop();
      return;
    }
    _mdns = svc;
    if (svc.started) _mdnsSub = svc.onFound.listen(_onMdnsCandidate);
  }

  Future<void> _stopMdns() async {
    final sub = _mdnsSub;
    final svc = _mdns;
    _mdnsSub = null;
    _mdns = null;
    await sub?.cancel();
    try {
      await svc?.stop();
    } catch (_) {}
  }

  /// A device showed up in mDNS: only a hint. Verify it over HTTPS against
  /// the fingerprint it claims, exactly like a UDP announce.
  void _onMdnsCandidate(MdnsCandidate c) {
    if (!_running || c.fingerprint == _self?.fingerprint) return;
    for (final ip in c.addresses) {
      final known = _peers[c.fingerprint];
      if (known != null &&
          known.addrs.containsKey(ip) &&
          known.info.port == c.port) {
        _seenAt(known, ip, 'mdns');
        _noteMdns(MdnsPeerObservation(c.alias, c.fingerprint, ip, c.port));
        continue;
      }
      unawaited(_verifyMdns(c, ip));
    }
  }

  Future<void> _verifyMdns(MdnsCandidate c, String ip) async {
    var ran = false;
    final info = await _gatedVerify(ip, c.port, c.fingerprint, () {
      ran = true;
      return _fetchInfo(ip, c.port,
          expectFp: c.fingerprint, timeout: options.probeTimeout);
    });
    if (!_running || (info == null && !ran)) return;
    if (info != null) {
      _noteMdns(MdnsPeerObservation(c.alias, c.fingerprint, ip, c.port));
      _upsertPeer(info, via: 'mdns');
      return;
    }
    // Find out why, for the diagnosis.
    final p = await _probe(ip, c.port, pinned: c.fingerprint);
    if (!_running) return;
    final failure = p.fingerprintMismatch
        ? 'fingerprint-mismatch'
        : switch (p.tcp) {
            TcpOutcome.refused => 'refused',
            TcpOutcome.timeout => 'timeout',
            _ => 'other',
          };
    // Another address may have verified it meanwhile: keep that.
    if (!_peers.containsKey(c.fingerprint)) {
      _noteMdns(MdnsPeerObservation(c.alias, c.fingerprint, ip, c.port,
          failure: failure));
    }
  }

  /// Re-reads the local addresses: the capability record, and [self.ip]
  /// unless it is fixed by [LanDropCoreOptions.advertiseIp] or still valid.
  Future<void> _refreshAddresses() async {
    final lanAddrs = [
      for (final a in await localIPv4Addresses()) a.address
    ];
    final old = _self;
    if (old == null) return;
    // Keep the current address, except a link-local one once a real
    // (non-link-local) address exists.
    final keepOld = lanAddrs.contains(old.ip) &&
        !(isLinkLocalIPv4(old.ip) &&
            lanAddrs.any((a) => !isLinkLocalIPv4(a)));
    final ip = options.advertiseIp ??
        (keepOld ? old.ip : null) ??
        lanAddrs.firstOrNull ??
        '127.0.0.1';
    _capAddrs = {ip, ...lanAddrs}.toList();
    if (ip != old.ip) _self = old.copyWith(ip: ip);
  }

  @override
  Future<void> restartDiscovery() async {
    if (!_running) return;
    await _refreshAddresses();
    _announceTimer?.cancel();
    _announceTimer = null;
    final d = _discovery;
    _discovery = null;
    try {
      await d?.close();
    } catch (_) {}
    if (!_running) return;
    await _startDiscovery();
    await _stopMdns();
    await _startMdns();
  }

  @override
  void setHotspotInfo(String? ssid, {String? gateway}) {
    _hotspotSsid = ssid == null || ssid.isEmpty ? null : ssid;
    _hotspotGateway = _hotspotSsid == null ? null : gateway;
    if (_running) unawaited(_announce());
  }

  @override
  Future<List<DeviceInfo>> probeAddresses(List<String> ips,
      {int? port}) async {
    if (!_running) return const [];
    final ports = <int>{
      ?port,
      if (port == null) 53317,
      if (port == null && options.port > 0) options.port,
    };
    final jobs = <(String, int)>[
      for (final ip in {...ips.map((e) => e.trim())})
        if (ip.isNotEmpty)
          for (final p in ports)
            if (!(_capAddrs.contains(ip) && p == _self?.port)) (ip, p)
    ];
    final found = <String>{};
    var next = 0;
    Future<void> worker() async {
      while (next < jobs.length && _running) {
        final (ip, p) = jobs[next++];
        final info = await _fetchInfo(ip, p, timeout: options.probeTimeout);
        if (info != null && info.fingerprint != _self?.fingerprint) {
          _upsertPeer(info, via: 'scan');
          found.add(info.fingerprint);
        }
      }
    }

    await Future.wait(List.generate(min(32, jobs.length), (_) => worker()));
    return [
      for (final p in currentPeers)
        if (found.contains(p.fingerprint)) p
    ];
  }

  @override
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    if (!_stopped.isCompleted) _stopped.complete();
    _announceTimer?.cancel();
    _pruneTimer?.cancel();
    _announceTimer = _pruneTimer = null;
    await _discovery?.close();
    _discovery = null;
    await _stopMdns();
    await _server?.close(force: true);
    _server = null;
    await _web.stop();
    final s = _session;
    if (s != null) _endSession(s, reason: 'receiver stopped');
    _pendingDecision = false;
    if (_peers.isNotEmpty) {
      _peers.clear();
      _mdnsSeen.clear();
      _emitPeers();
    }
  }

  /// Stops and closes all streams. The instance cannot be reused afterwards.
  Future<void> dispose() async {
    await stop();
    await _web.dispose();
    await _peerCtrl.close();
    await _incomingCtrl.close();
    await _progressCtrl.close();
  }

  @override
  Future<DeviceInfo?> addPeerByIp(String ip, {int port = 53317}) async {
    final info =
        await _fetchInfo(ip.trim(), port, timeout: options.probeTimeout);
    if (info == null || info.fingerprint == _self?.fingerprint) return null;
    _upsertPeer(info, via: 'manual');
    return info.copyWith(foundVia: {...?_peers[info.fingerprint]?.via});
  }

  @override
  Future<void> scanSubnet() async {
    final targets = <String>{};
    final own = <String>{};
    for (final a in await localIPv4Addresses()) {
      own.add(a.address);
      final b = a.rawAddress;
      if (options.scanHosts != null) continue;
      for (var i = 1; i < 255; i++) {
        targets.add('${b[0]}.${b[1]}.${b[2]}.$i');
      }
    }
    targets.addAll(options.scanHosts ?? const []);
    final ports = <int>{options.port, 53317};
    final jobs = <(String, int)>[
      for (final t in targets)
        for (final p in ports)
          if (!(own.contains(t) && p == _self?.port)) (t, p)
    ];
    var next = 0;
    Future<void> worker() async {
      while (next < jobs.length && _running) {
        final (ip, port) = jobs[next++];
        final info = await _fetchInfo(ip, port, timeout: options.scanTimeout);
        if (info != null && info.fingerprint != _self?.fingerprint) {
          _upsertPeer(info, via: 'scan');
        }
      }
    }

    await Future.wait(
        List.generate(options.scanConcurrency, (_) => worker()));
  }

  @override
  Future<bool> send(DeviceInfo to, List<String> paths) async =>
      (await sendFiles(to, [for (final p in paths) SendItem(p)])).ok;

  @override
  Future<SendResult> sendFiles(DeviceInfo to, List<SendItem> items,
          {void Function(String sessionId)? onSession,
          Future<void>? withdraw}) =>
      _sendFiles(to, items, onSession: onSession, withdraw: withdraw);

  @override
  Future<SendResult> sendText(DeviceInfo to, String text,
      {void Function(String sessionId)? onSession,
      Future<void>? withdraw}) async {
    if (!_running || _self == null) throw StateError('core not started');
    final bytes = utf8.encode(text);
    if (text.trim().isEmpty || bytes.length > maxTextBytes) {
      return SendResult(
          ok: false,
          error: text.trim().isEmpty ? 'empty text' : 'text too large',
          errorCode: SendErrorCode.unknown);
    }
    // The same pipeline as files: if the receiver wants the bytes (it does
    // not show previews), message.txt is uploaded like any file.
    final tmp = await Directory.systemTemp.createTemp('landrop_text');
    try {
      final f = File('${tmp.path}${Platform.pathSeparator}$textMessageFileName');
      await f.writeAsBytes(bytes);
      return await _sendFiles(
          to, [SendItem(f.path, name: textMessageFileName)],
          onSession: onSession, preview: text, withdraw: withdraw);
    } finally {
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    }
  }

  /// [sendFiles]; with [preview] (text messages) the single offer carries it
  /// as `text/plain`, and a 204 answer means delivered.
  Future<SendResult> _sendFiles(DeviceInfo to, List<SendItem> items,
      {void Function(String sessionId)? onSession,
      String? preview,
      Future<void>? withdraw}) async {
    if (!_running || _self == null) throw StateError('core not started');
    if (to.fingerprint.isEmpty) {
      return const SendResult(
          ok: false,
          error: 'peer has no fingerprint',
          errorCode: SendErrorCode.unknown);
    }
    final List<(File, String, int)> expanded;
    try {
      expanded = await _expand(items);
    } catch (e) {
      return SendResult(
          ok: false,
          error: '$e',
          errorCode: e is FileSystemException
              ? SendErrorCode.diskError
              : SendErrorCode.unknown);
    }
    if (expanded.isEmpty) {
      return const SendResult(
          ok: false,
          error: 'nothing to send',
          errorCode: SendErrorCode.unknown);
    }
    final files = <String, (File, FileOffer)>{};
    for (final (f, name, size) in expanded) {
      final id = randomHex(8);
      files[id] = (
        f,
        FileOffer(id, name, size,
            preview != null ? 'text/plain' : guessMime(name),
            preview: preview)
      );
    }

    final peer = _withKnownAddresses(to);
    final route = _Route(await _selector.select(peer) ?? _directLink(peer));
    final client = _newClient(expectFp: to.fingerprint);
    String? sessionId;
    String? cancelSecret;
    _OutSend? out;
    // Lets this sender withdraw the request while the receiver decides
    // (LanDrop extra field `landropWithdraw`, PROTOCOL.md "Withdraw").
    final withdrawSecret = randomHex(16);
    var withdrawn = false;
    var answered = false;
    try {
      // 1. prepare-upload (waits for the receiver's decision). When the
      // connection cannot be made, the next link is tried.
      final identity = _identity;
      final body = {
        'info': _selfJson(),
        'files': {
          for (final e in files.entries)
            e.key: {
              'id': e.value.$2.id,
              'fileName': e.value.$2.fileName,
              'size': e.value.$2.size,
              'fileType': e.value.$2.fileType,
              'preview': ?e.value.$2.preview,
            }
        },
        // Proves to the receiver that this request comes from the holder of
        // our certificate's key (PROTOCOL.md "Sender proof"); LocalSend
        // receivers ignore it.
        if (identity != null)
          'landropProof': {
            'cert': base64Encode(identity.certDer),
            'sig': base64Encode(identity.sign(senderProofMessage(
                to.fingerprint, identity.fingerprint, [
              for (final e in files.entries)
                (e.key, e.value.$2.fileName, e.value.$2.size)
            ]))),
          },
        'landropWithdraw': withdrawSecret,
      };
      unawaited(withdraw?.then((_) async {
        if (sessionId != null || answered) return;
        withdrawn = true;
        await _postCancel(route.link, {'withdrawSecret': withdrawSecret});
      }));
      (int, Map<String, dynamic>?) prep;
      while (true) {
        try {
          prep = await _postJson(
              client, route.link.uri('$_apiBase/prepare-upload'), body,
              expectFp: to.fingerprint,
              timeout: options.decisionTimeout + const Duration(seconds: 30));
          break;
        } on _ConnectFailed {
          if (!await _switchLink(peer, route)) rethrow;
        }
      }
      // A text message was shown: nothing to upload (LocalSend behaviour).
      if (prep.$1 == 204 && preview != null) {
        return const SendResult(ok: true);
      }
      answered = true;
      if (withdrawn) {
        if (prep.$1 == 200 && prep.$2?['sessionId'] is String) {
          // Accepted just before the withdrawal arrived: end the session.
          unawaited(_sendCancel(route.link, prep.$2!['sessionId'] as String,
              prep.$2!['cancelSecret'] as String?));
        }
        return const SendResult(
            ok: false,
            error: _cancelledError,
            errorCode: SendErrorCode.cancelled);
      }
      if (prep.$1 != 200 || prep.$2 == null) {
        return SendResult(
            ok: false,
            error: switch (prep.$1) {
              403 => 'declined',
              409 => 'receiver is busy',
              _ => 'HTTP ${prep.$1}',
            },
            errorCode: switch (prep.$1) {
              403 => SendErrorCode.declined,
              409 => SendErrorCode.busy,
              _ => SendErrorCode.unknown,
            });
      }
      final sid = prep.$2!['sessionId'];
      final tokens = prep.$2!['files'];
      if (sid is! String || tokens is! Map) {
        return const SendResult(
            ok: false,
            error: 'invalid prepare response',
            errorCode: SendErrorCode.unknown);
      }
      sessionId = sid;
      final secret = prep.$2!['cancelSecret'];
      cancelSecret = secret is String ? secret : null;
      out = _OutSend(route, cancelSecret);
      _outgoing[sid] = out;
      try {
        onSession?.call(sid);
      } catch (_) {}
      // Every file with its size at once, so the UI knows the total (time
      // left) before the first byte goes out.
      for (final e in files.entries) {
        if (tokens[e.key] is! String) continue;
        _progressCtrl.add(TransferProgress(sid, e.key, 0, e.value.$2.size,
            fileName: e.value.$2.fileName));
      }

      // 2. upload each file (resuming broken connections)
      final finished = <String>{};
      for (final e in files.entries) {
        final token = tokens[e.key];
        if (token is! String) continue; // receiver skipped this file
        final started = !out.cancelled;
        final err = started
            ? await _uploadOne(client, peer, route, sid, e.key, token,
                e.value.$1, e.value.$2.size, e.value.$2.fileName, out)
            : _cancelledError;
        // _uploadOne sent this file's final event itself.
        if (err == null || started) finished.add(e.key);
        if (err != null) {
          if (out.cancelled) {
            // cancelSession already told the receiver. Files not started
            // yet end as cancelled too.
            for (final f in files.entries) {
              if (tokens[f.key] is! String || finished.contains(f.key)) {
                continue;
              }
              _progressCtrl.add(TransferProgress(sid, f.key, 0, f.value.$2.size,
                  done: true,
                  error: _cancelledError,
                  errorCode: SendErrorCode.cancelled,
                  fileName: f.value.$2.fileName));
            }
            return SendResult(
                ok: false,
                sessionId: sid,
                error: _cancelledError,
                errorCode: SendErrorCode.cancelled);
          }
          _selector.invalidate(to.fingerprint);
          unawaited(_sendCancel(route.link, sid, cancelSecret));
          return SendResult(
              ok: false,
              sessionId: sid,
              error: err,
              errorCode: _uploadErrorCode(err));
        }
      }
      return SendResult(ok: true, sessionId: sid);
    } catch (e) {
      if (out != null && out.cancelled) {
        return SendResult(
            ok: false,
            sessionId: sessionId,
            error: _cancelledError,
            errorCode: SendErrorCode.cancelled);
      }
      _selector.invalidate(to.fingerprint);
      if (sessionId != null) {
        unawaited(_sendCancel(route.link, sessionId, cancelSecret));
      }
      return SendResult(
          ok: false,
          sessionId: sessionId,
          error: '$e',
          errorCode: _sendExceptionCode(e));
    } finally {
      if (sessionId != null) _outgoing.remove(sessionId);
      client.close(force: true);
    }
  }

  static const _cancelledError = 'cancelled';

  @override
  Future<void> cancelSession(String sessionId) async {
    final out = _outgoing[sessionId];
    if (out != null) {
      if (out.cancelled) return;
      out.cancelled = true;
      out.current?.abort(const SocketException('cancelled'));
      await _sendCancel(out.route.link, sessionId, out.cancelSecret);
      return;
    }
    final s = _session;
    if (s != null && s.id == sessionId && !s.allFinished) {
      s.endCode = SendErrorCode.cancelled;
      _endSession(s, reason: _cancelledError, includeActive: true);
    }
  }

  /// [SendErrorCode] for an exception thrown while sending.
  static SendErrorCode _sendExceptionCode(Object e) {
    final cause = e is _ConnectFailed ? e.cause : e;
    if (cause is HandshakeException) {
      // The pinned client rejects a certificate only when its fingerprint
      // differs (badCertificateCallback), which surfaces as VERIFY_FAILED.
      final m = '$cause';
      return m.contains('fingerprint') || m.contains('CERTIFICATE_VERIFY')
          ? SendErrorCode.fingerprintMismatch
          : SendErrorCode.unreachable;
    }
    if (cause is TimeoutException) return SendErrorCode.timeout;
    if (cause is FileSystemException) return SendErrorCode.diskError;
    if (cause is SocketException || e is _ConnectFailed) {
      return SendErrorCode.unreachable;
    }
    return SendErrorCode.unknown;
  }

  /// [SendErrorCode] for the error string [_uploadOne] returns.
  static SendErrorCode _uploadErrorCode(String err) {
    if (err.contains('fingerprint')) return SendErrorCode.fingerprintMismatch;
    if (err.contains('stalled')) return SendErrorCode.timeout;
    if (err.contains('no longer valid') ||
        err == 'HTTP 403' ||
        err == 'HTTP 409') {
      return SendErrorCode.cancelled;
    }
    if (err == 'HTTP 500' || err == 'HTTP 507') return SendErrorCode.diskError;
    if (err.contains('FileSystemException')) return SendErrorCode.diskError;
    if (err.contains('SocketException') || err.contains('Connection')) {
      return SendErrorCode.unreachable;
    }
    return SendErrorCode.unknown;
  }

  /// [to] plus every address the peer table knows for it.
  DeviceInfo _withKnownAddresses(DeviceInfo to) {
    final known = _peers[to.fingerprint];
    if (known == null) return to;
    return to.copyWith(
      addresses: {...to.addresses, ...known.addresses}.toList(),
      capabilities: to.capabilities ?? known.info.capabilities,
    );
  }

  /// Unverified link to the peer's [DeviceInfo.ip] (when no transport
  /// answered in time); the certificate is still pinned on every request.
  static Link _directLink(DeviceInfo to) => Link(
      transportId: 'lan-https',
      host: to.ip,
      port: to.port,
      fingerprint: to.fingerprint);

  /// [route.link] failed: forget the cached link and move to the best other
  /// one. False (and the link stays) when nothing else answers.
  Future<bool> _switchLink(DeviceInfo peer, _Route route) async {
    if (!route.failed.any((l) => l.key == route.link.key)) {
      route.failed.add(route.link);
    }
    _selector.invalidate(peer.fingerprint);
    if (!_running) return false;
    final next = await _selector.next(peer, route.failed);
    if (next == null) return false;
    route.link = next;
    return true;
  }

  // ------------------------------------------------------------ diagnosis

  @override
  Future<List<Finding>> runDiagnosis(
          {String? targetIp, int? targetPort}) async =>
      diagnose(await observe(targetIp: targetIp, targetPort: targetPort));

  /// What [runDiagnosis] feeds into [diagnose]. Probes [targetIp] (TCP
  /// connect, then TLS + GET /info) within [LanDropCoreOptions.probeTimeout].
  Future<DiagnosisInput> observe({String? targetIp, int? targetPort}) async {
    final ifaces = <InterfaceObservation>[];
    try {
      for (final i in await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLoopback: false)) {
        ifaces.add(InterfaceObservation(
            i.name, [for (final a in i.addresses) a.address]));
      }
    } catch (_) {}
    final server = _server;
    final listening =
        _running && server != null && await _selfReachable(server.port);
    ProbeObservation? probe;
    final ip = targetIp?.trim();
    if (ip != null && ip.isNotEmpty) {
      final known = _peers.values
          .where((p) =>
              p.addrs.containsKey(ip) &&
              (targetPort == null || p.info.port == targetPort))
          .firstOrNull;
      probe = await _probe(ip, targetPort ?? known?.info.port ?? 53317,
          pinned: known?.info.fingerprint);
    }
    return DiagnosisInput(
      discoveryError: _discoveryError,
      discoveryEnabled:
          options.discoveryTransport != null || options.multicastEnabled,
      interfaces: ifaces,
      serverListening: listening,
      serverPort: server?.port,
      peers: [
        for (final p in _peers.values)
          PeerObservation(p.info.alias, p.info.ip, {...p.via})
      ],
      probe: probe,
      mdnsEnabled: options.mdnsEnabled,
      mdnsStarted: _mdns?.started ?? false,
      mdnsError: _mdns?.error,
      mdnsPeers: _mdnsSeen.values.toList(),
    );
  }

  /// Own HTTPS port accepts TCP connections (via loopback when bound to all
  /// interfaces).
  Future<bool> _selfReachable(int port) async {
    final b = options.bindAddress;
    final host = b == null || b.isLoopback || b == InternetAddress.anyIPv4
        ? InternetAddress.loopbackIPv4
        : b;
    try {
      final s = await Socket.connect(host, port, timeout: options.probeTimeout);
      s.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  static TcpOutcome _classify(SocketException e) {
    final code = e.osError?.errorCode;
    final msg = '${e.message} ${e.osError?.message ?? ''}'.toLowerCase();
    // errno: ETIMEDOUT macOS 60 / Linux 110 / Windows 10060 (Dart's own
    // connect timeout reports 110); ECONNREFUSED 61 / 111 / 10061.
    if (const {60, 110, 10060}.contains(code) || msg.contains('timed out')) {
      return TcpOutcome.timeout;
    }
    if (const {61, 111, 10061}.contains(code) || msg.contains('refused')) {
      return TcpOutcome.refused;
    }
    return TcpOutcome.unreachable;
  }

  Future<ProbeObservation> _probe(String ip, int port, {String? pinned}) async {
    final t = options.probeTimeout;
    try {
      final s = await Socket.connect(ip, port, timeout: t)
          .timeout(t + const Duration(seconds: 1));
      s.destroy();
    } on TimeoutException {
      return ProbeObservation(ip: ip, port: port, tcp: TcpOutcome.timeout);
    } on SocketException catch (e) {
      return ProbeObservation(
          ip: ip,
          port: port,
          tcp: _classify(e),
          error: e.osError?.message ?? e.message);
    } catch (e) {
      return ProbeObservation(
          ip: ip, port: port, tcp: TcpOutcome.unreachable, error: '$e');
    }
    // TCP works: try TLS + /info, accepting any certificate so a different
    // one can be reported instead of just failing.
    String? presented;
    DeviceInfo? info;
    String? err;
    final client = _newClient(connectTimeout: t);
    try {
      final req = await client.getUrl(_uri(ip, port, '/info')).timeout(t);
      final res = await req.close().timeout(t);
      presented = _checkPeerCert(res, null);
      if (res.statusCode == 200) {
        info = _infoFromJson(await _readJsonStream(res).timeout(t), ip, port);
        if (info == null) err = 'invalid info response';
      } else {
        await res.drain<void>();
        err = 'HTTP ${res.statusCode}';
      }
    } catch (e) {
      err = e is HandshakeException ? 'TLS: ${e.message}' : '$e';
    } finally {
      client.close(force: true);
    }
    final claimed = info?.fingerprint;
    final mismatch = presented != null &&
        ((pinned != null && pinned != presented) ||
            (claimed != null && claimed != presented));
    return ProbeObservation(
      ip: ip,
      port: port,
      tcp: TcpOutcome.connected,
      infoOk: info != null,
      fingerprintMismatch: mismatch,
      expectedFingerprint: pinned ?? claimed,
      presentedFingerprint: presented,
      alias: info?.alias,
      error: err,
    );
  }

  // ------------------------------------------------------------ sending

  static String _baseName(String path) => path
      .split(RegExp(r'[\\/]'))
      .lastWhere((s) => s.isNotEmpty, orElse: () => 'file');

  /// Files to send as (file, name on the wire, size). Directories are listed
  /// recursively; their files are named `<dir>/<relative path>` with '/'.
  static Future<List<(File, String, int)>> _expand(List<SendItem> items) async {
    final out = <(File, String, int)>[];
    for (final it in items) {
      final type = await FileSystemEntity.type(it.path);
      if (type == FileSystemEntityType.directory) {
        final root =
            Directory(it.path).absolute.path.replaceAll(RegExp(r'[\\/]+$'), '');
        final top = it.name ?? _baseName(root);
        final entries = await Directory(root)
            .list(recursive: true, followLinks: false)
            .where((e) => e is File)
            .cast<File>()
            .toList();
        entries.sort((a, b) => a.path.compareTo(b.path));
        for (final f in entries) {
          final rel = f.path.substring(root.length + 1).replaceAll('\\', '/');
          out.add((f, '$top/$rel', await f.length()));
        }
      } else {
        final f = File(it.path);
        out.add((f, it.name ?? _baseName(it.path), await f.length()));
      }
    }
    return out;
  }

  /// Uploads one file, resuming from the receiver's byte count when the
  /// connection breaks or stalls. A broken or stalled connection first moves
  /// [route] to the next link (another address or transport), if any.
  /// Returns null on success, else the error.
  Future<String?> _uploadOne(
      HttpClient client,
      DeviceInfo peer,
      _Route route,
      String sessionId,
      String fileId,
      String token,
      File file,
      int size,
      String name,
      _OutSend out) async {
    final q = {'sessionId': sessionId, 'fileId': fileId, 'token': token};
    void emit(int sent,
            {bool done = false, String? error, SendErrorCode? code}) =>
        _progressCtrl.add(TransferProgress(sessionId, fileId, sent, size,
            done: done, error: error, errorCode: code, fileName: name));

    emit(0);
    var offset = 0;
    var broken = false;
    String lastError = 'upload failed';
    for (var attempt = 0; attempt <= options.uploadRetries; attempt++) {
      if (out.cancelled) break;
      if (attempt > 0) {
        await Future<void>.delayed(options.retryBackoff * (1 << (attempt - 1)));
        if (!_running || out.cancelled) break;
        if (broken) await _switchLink(peer, route);
        try {
          final st = await _uploadStatus(route.link, q);
          if (st == null) {
            broken = true; // receiver unreachable on this link right now
            continue;
          }
          if (st.done) {
            emit(size, done: true);
            return null;
          }
          offset = st.received;
        } on _HttpError catch (e) {
          lastError = e.message;
          break; // session gone: not resumable
        }
      }
      final (outcome, msg) = await _uploadAttempt(client, route.link, q,
          fileId, file, offset, size, attempt, emit, out);
      if (outcome == _Attempt.ok) {
        emit(size, done: true);
        return null;
      }
      lastError = msg ?? lastError;
      if (outcome == _Attempt.fatal) break;
      broken = outcome == _Attempt.broken;
    }
    if (out.cancelled) {
      emit(offset,
          done: true, error: _cancelledError, code: SendErrorCode.cancelled);
      return _cancelledError;
    }
    emit(offset,
        done: true, error: lastError, code: _uploadErrorCode(lastError));
    return lastError;
  }

  Future<(_Attempt, String?)> _uploadAttempt(
      HttpClient client,
      Link to,
      Map<String, String> q,
      String fileId,
      File file,
      int offset,
      int size,
      int attempt,
      void Function(int sent) emit,
      _OutSend out) async {
    var sent = offset;
    var lastEmit = offset;
    var lastActivity = DateTime.now();
    var stalled = false;
    Timer? watchdog;
    try {
      final req = await client
          .postUrl(to.uri('$_apiBase/upload', {...q, 'offset': '$offset'}))
          .timeout(options.probeTimeout * 2);
      req.contentLength = size - offset;
      req.headers.contentType = ContentType.binary;
      out.current = req;
      if (out.cancelled) req.abort(const SocketException('cancelled'));
      final tick = Duration(
          milliseconds:
              (options.stallTimeout.inMilliseconds ~/ 4).clamp(50, 1000));
      watchdog = Timer.periodic(tick, (_) {
        if (DateTime.now().difference(lastActivity) > options.stallTimeout) {
          stalled = true;
          watchdog?.cancel();
          req.abort(TimeoutException('upload stalled'));
        }
      });
      final kill = options.debugKillUpload;
      var killed = false;
      await req.addStream(file.openRead(offset).map((chunk) {
        sent += chunk.length;
        lastActivity = DateTime.now();
        if (sent - lastEmit >= _progressStep) {
          lastEmit = sent;
          emit(sent);
        }
        if (!killed && kill != null && kill(fileId, sent, attempt)) {
          killed = true;
          req.abort(const SocketException('upload connection killed'));
        }
        return chunk;
      }));
      final res = await req.close();
      lastActivity = DateTime.now();
      _checkPeerCert(res, to.fingerprint);
      await res.drain<void>();
      return switch (res.statusCode) {
        200 => (_Attempt.ok, null),
        400 || 409 => (_Attempt.retry, 'HTTP ${res.statusCode}'),
        _ => (_Attempt.fatal, 'HTTP ${res.statusCode}'),
      };
    } on HandshakeException catch (e) {
      return (_Attempt.fatal, e.message);
    } catch (e) {
      return (_Attempt.broken, stalled ? 'upload stalled' : '$e');
    } finally {
      watchdog?.cancel();
      out.current = null;
    }
  }

  /// Asks the receiver how many bytes of a file it has. Waits (up to
  /// [LanDropCoreOptions.stallTimeout]) while the receiver still sees the old
  /// connection as active. Null when unreachable; throws [_HttpError] when the
  /// session or token is no longer valid.
  Future<({int received, bool done})?> _uploadStatus(
      Link to, Map<String, String> q) async {
    final deadline = DateTime.now().add(options.stallTimeout);
    final c = _newClient(expectFp: to.fingerprint);
    try {
      while (true) {
        final req = await c
            .getUrl(to.uri('$_landropBase/upload-status', q))
            .timeout(options.probeTimeout);
        final res = await req.close().timeout(options.probeTimeout);
        _checkPeerCert(res, to.fingerprint);
        if (res.statusCode == 403) {
          await res.drain<void>();
          throw _HttpError(403, 'session no longer valid on receiver');
        }
        if (res.statusCode != 200) {
          await res.drain<void>();
          return null;
        }
        final j = await _readJsonStream(res).timeout(options.probeTimeout);
        final received = j['received'];
        if (received is! int) return null;
        if (j['active'] == true && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          continue;
        }
        return (received: received, done: j['done'] == true);
      }
    } on _HttpError {
      rethrow;
    } catch (_) {
      return null;
    } finally {
      c.close(force: true);
    }
  }

  Future<void> _sendCancel(
          Link to, String sessionId, String? cancelSecret) =>
      _postCancel(to, {
        'sessionId': sessionId,
        'cancelSecret': ?cancelSecret,
      });

  /// POST /cancel with [query] (a session's cancel, or a withdrawal).
  Future<void> _postCancel(Link to, Map<String, String> query) async {
    final c = _newClient(expectFp: to.fingerprint);
    try {
      final req = await c
          .postUrl(to.uri('$_apiBase/cancel', query))
          .timeout(options.probeTimeout);
      final res = await req.close().timeout(options.probeTimeout);
      await res.drain<void>();
    } catch (_) {
    } finally {
      c.close(force: true);
    }
  }

  // ------------------------------------------------------------ HTTP client

  Uri _uri(String ip, int port, String path,
          [Map<String, String>? q, String base = _apiBase]) =>
      Uri(
          scheme: 'https',
          host: ip,
          port: port,
          path: '$base$path',
          queryParameters: q);

  /// HTTP client that accepts self-signed certs. If [expectFp] is set, only a
  /// certificate with that SHA-256 fingerprint is accepted (pinning).
  HttpClient _newClient({String? expectFp, Duration? connectTimeout}) {
    final c = HttpClient(context: SecurityContext(withTrustedRoots: false));
    c.connectionTimeout = connectTimeout ?? options.probeTimeout;
    c.userAgent = 'LanDrop/1.0';
    c.badCertificateCallback = (cert, host, port) =>
        expectFp == null || fingerprintOfDer(cert.der) == expectFp;
    return c;
  }

  /// Returns the fingerprint of the presented cert, throwing on mismatch.
  String _checkPeerCert(HttpClientResponse res, String? expectFp) {
    final cert = res.certificate;
    if (cert == null) throw const HandshakeException('no peer certificate');
    final fp = fingerprintOfDer(cert.der);
    if (expectFp != null && fp != expectFp) {
      throw const HandshakeException('certificate fingerprint mismatch');
    }
    return fp;
  }

  Future<(int, Map<String, dynamic>?)> _postJson(
      HttpClient client, Uri uri, Map<String, dynamic> body,
      {String? expectFp, required Duration timeout}) async {
    final HttpClientRequest req;
    try {
      req = await client.postUrl(uri).timeout(options.probeTimeout * 2);
    } on SocketException catch (e) {
      throw _ConnectFailed(e);
    } on TimeoutException catch (e) {
      throw _ConnectFailed(e);
    } on HandshakeException catch (e) {
      // Wrong certificate at this address: never trusted, try another.
      throw _ConnectFailed(e);
    }
    req.headers.contentType = ContentType.json;
    req.add(utf8.encode(jsonEncode(body)));
    final res = await req.close().timeout(timeout);
    _checkPeerCert(res, expectFp);
    Map<String, dynamic>? json;
    if (res.statusCode == 200) {
      json = await _readJsonStream(res).timeout(timeout);
    } else {
      await res.drain<void>();
    }
    return (res.statusCode, json);
  }

  /// GET /info and verify the advertised fingerprint equals the presented
  /// certificate (and [expectFp] if given).
  Future<DeviceInfo?> _fetchInfo(String ip, int port,
      {String? expectFp, required Duration timeout}) async {
    final client = _newClient(expectFp: expectFp, connectTimeout: timeout);
    try {
      final req = await client.getUrl(_uri(ip, port, '/info')).timeout(timeout);
      final res = await req.close().timeout(timeout);
      final presented = _checkPeerCert(res, expectFp);
      if (res.statusCode != 200) {
        await res.drain<void>();
        return null;
      }
      final json = await _readJsonStream(res).timeout(timeout);
      final info = _infoFromJson(json, ip, port);
      if (info == null || info.fingerprint != presented) return null;
      return info;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// POST /register (reply to an announcement) and verify the peer.
  Future<DeviceInfo?> _register(String ip, int port, String expectFp) async {
    final client = _newClient(expectFp: expectFp);
    try {
      final (status, json) = await _postJson(
          client, _uri(ip, port, '/register'), _selfJson(),
          expectFp: expectFp, timeout: options.probeTimeout);
      if (status != 200 || json == null) return null;
      final info = _infoFromJson(json, ip, port);
      if (info == null || info.fingerprint != expectFp) return null;
      return info;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static Future<Map<String, dynamic>> _readJsonStream(Stream<List<int>> s,
      {int max = 1 << 20}) async {
    final b = BytesBuilder(copy: false);
    var n = 0;
    await for (final c in s) {
      n += c.length;
      if (n > max) throw _HttpError(413, 'body too large');
      b.add(c);
    }
    final v = jsonDecode(utf8.decode(b.takeBytes()));
    if (v is! Map<String, dynamic>) throw _HttpError(400, 'expected object');
    return v;
  }

  // ------------------------------------------------------------ device info

  Map<String, dynamic> _selfJson() {
    final s = self;
    return {
      'alias': s.alias,
      'version': _protocolVersion,
      'deviceModel': s.deviceModel,
      'deviceType': s.deviceType,
      'fingerprint': s.fingerprint,
      'port': s.port,
      'protocol': 'https',
      'download': false,
      'landrop': _capabilities().toJson(),
    };
  }

  /// This device's capability record (DESIGN.md 3.3): the LAN path, plus
  /// the hotspot this device shares while it does.
  PeerCapabilities _capabilities() => PeerCapabilities(
        transports: [
          TransportCapability('lan-https', addrs: _capAddrs, port: self.port),
          if (_hotspotSsid != null)
            TransportCapability('hotspot',
                ssid: _hotspotSsid, gateway: _hotspotGateway),
        ],
        features: const {'resume', 'folders', 'browser-ui'},
      );

  DeviceInfo? _infoFromJson(Map<String, dynamic> j, String ip, int port) {
    final fp = j['fingerprint'];
    if (fp is! String || fp.isEmpty || fp.length > 128) return null;
    // Peer-supplied names are shown in the UI: no control or bidi spoofing
    // characters, bounded length (SECURITY.md S6, S19).
    final rawAlias = j['alias'];
    final alias = rawAlias is String ? sanitizeDisplayText(rawAlias) : '';
    final type = j['deviceType'];
    final model = j['deviceModel'];
    final cleanModel =
        model is String ? sanitizeDisplayText(model, max: 64) : '';
    return DeviceInfo(
      alias: alias.isNotEmpty ? alias : ip,
      deviceType: type is String && RegExp(r'^[a-z]{1,16}$').hasMatch(type)
          ? type
          : 'desktop',
      deviceModel: cleanModel.isEmpty ? null : cleanModel,
      fingerprint: fp.toLowerCase(),
      ip: ip,
      port: port,
      capabilities: PeerCapabilities.fromJson(j['landrop']),
    );
  }

  // ------------------------------------------------------------ peers

  /// Adds or refreshes a peer; [via] records how it was found. The same
  /// fingerprint at another address is the same peer: the address is added
  /// to its list and [DeviceInfo.ip] stays the current best one (see
  /// [_bestIp]).
  void _upsertPeer(DeviceInfo info, {String? via}) {
    if (!_running || info.fingerprint == _self?.fingerprint) return;
    final existing = _peers[info.fingerprint];
    if (existing == null) {
      if (_peers.length >= options.maxPeers) return; // SECURITY.md S4
      _peers[info.fingerprint] = _Peer(info)..via.addAll([?via]);
      _emitPeers();
      return;
    }
    final now = DateTime.now();
    existing.lastSeen = now;
    var changed = via != null && existing.via.add(via);
    final o = existing.info;
    // Restarted on another port: the old addresses are stale.
    if (o.port != info.port) existing.addrs.clear();
    if (existing.addrs[info.ip] == null) changed = true;
    existing.addrs[info.ip] = now;
    final ip = o.port == info.port ? _bestIp(existing, info.ip) : info.ip;
    if (o.ip != ip ||
        o.port != info.port ||
        o.alias != info.alias ||
        o.deviceType != info.deviceType ||
        o.deviceModel != info.deviceModel ||
        jsonEncode(o.capabilities?.toJson()) !=
            jsonEncode(info.capabilities?.toJson())) {
      existing.info = info.copyWith(ip: ip);
      changed = true;
    }
    if (changed) _emitPeers();
  }

  /// The current address of [p] while it is still seen (within
  /// [LanDropCoreOptions.peerTimeout]); otherwise [candidate], which was
  /// just seen. Keeps the shown address from flipping between interfaces.
  String _bestIp(_Peer p, String candidate) {
    final seen = p.addrs[p.info.ip];
    if (seen != null &&
        DateTime.now().difference(seen) < options.peerTimeout) {
      return p.info.ip;
    }
    return candidate;
  }

  /// A known peer was seen again at [ip] (already verified there): refresh
  /// without re-probing, record [via].
  void _seenAt(_Peer p, String ip, String via) {
    p.lastSeen = DateTime.now();
    p.addrs[ip] = p.lastSeen;
    var changed = p.via.add(via);
    final best = _bestIp(p, ip);
    if (best != p.info.ip) {
      p.info = p.info.copyWith(ip: best);
      changed = true;
    }
    if (changed) _emitPeers();
  }

  void _emitPeers() {
    if (!_peerCtrl.isClosed) _peerCtrl.add(currentPeers);
  }

  /// Peers not seen for [peerTimeout] get one re-probe of every known
  /// address; addresses that do not answer are dropped, and the peer when
  /// none does. (Keeps manually added / scanned peers alive while
  /// reachable, without multicast.) For peers still seen, addresses not
  /// seen for 3 x [peerTimeout] are dropped.
  void _prune() {
    final now = DateTime.now();
    for (final p in _peers.values.toList()) {
      if (p.probing) continue;
      if (now.difference(p.lastSeen) < options.peerTimeout) {
        final stale = [
          for (final e in p.addrs.entries)
            if (now.difference(e.value) >= options.peerTimeout * 3) e.key
        ];
        if (stale.isNotEmpty && stale.length < p.addrs.length) {
          stale.forEach(p.addrs.remove);
          if (!p.addrs.containsKey(p.info.ip)) {
            final newest = p.addrs.entries
                .reduce((a, b) => a.value.isAfter(b.value) ? a : b);
            p.info = p.info.copyWith(ip: newest.key);
          }
          _emitPeers();
        }
        continue;
      }
      p.probing = true;
      final fp = p.info.fingerprint;
      final port = p.info.port;
      Future.wait([
        for (final ip in p.addresses)
          _fetchInfo(ip, port, expectFp: fp, timeout: options.probeTimeout)
      ]).then((infos) {
        p.probing = false;
        if (!_running || !identical(_peers[fp], p)) return;
        final alive = infos.whereType<DeviceInfo>().toList();
        if (alive.isEmpty) {
          _peers.remove(fp);
          _emitPeers();
          return;
        }
        final before = p.addrs.length;
        p.addrs.removeWhere((a, _) => !alive.any((i) => i.ip == a));
        final t = DateTime.now();
        for (final i in alive) {
          p.addrs[i.ip] = t;
        }
        final best = alive.firstWhere((i) => i.ip == p.info.ip,
            orElse: () => alive.first);
        _upsertPeer(best);
        if (p.addrs.length != before) _emitPeers();
      });
    }
  }

  // ------------------------------------------------------------ discovery

  /// Runs [verify] for a peer claimed by untrusted data at [ip]:[port] with
  /// fingerprint [fp], unless the same claim is being checked or failed
  /// within [_verifyRetryAfter], or too many checks run (16 at once, 4 per
  /// address). Null when skipped.
  Future<DeviceInfo?> _gatedVerify(String ip, int port, String fp,
      Future<DeviceInfo?> Function() verify) async {
    final key = '$ip|$port|$fp';
    final now = DateTime.now();
    final failed = _verifyFailed[key];
    if (failed != null && now.difference(failed) < _verifyRetryAfter) {
      return null;
    }
    if (_verifyRunning.contains(key) ||
        _verifyRunning.length >= _maxVerifyInflight ||
        (_verifyPerIp[ip] ?? 0) >= _maxVerifyPerIp) {
      return null;
    }
    _verifyRunning.add(key);
    _verifyPerIp[ip] = (_verifyPerIp[ip] ?? 0) + 1;
    DeviceInfo? info;
    try {
      info = await verify();
    } finally {
      _verifyRunning.remove(key);
      final n = (_verifyPerIp[ip] ?? 1) - 1;
      if (n <= 0) {
        _verifyPerIp.remove(ip);
      } else {
        _verifyPerIp[ip] = n;
      }
    }
    if (info == null) {
      if (_verifyFailed.length >= 1024) {
        final t = DateTime.now();
        _verifyFailed.removeWhere((_, v) => t.difference(v) >= _verifyRetryAfter);
        if (_verifyFailed.length >= 1024) {
          _verifyFailed.remove(_verifyFailed.keys.first);
        }
      }
      _verifyFailed[key] = DateTime.now();
    } else {
      _verifyFailed.remove(key);
    }
    return info;
  }

  /// A spoofed announce of a known peer must not make us connect to it for
  /// every datagram: one register per peer address every 2 seconds. The map
  /// only holds addresses of known peers, so it is bounded by the peer table.
  final Map<String, DateTime> _lastRegister = {};
  bool _registerDue(String key) {
    final now = DateTime.now();
    final last = _lastRegister[key];
    if (last != null && now.difference(last) < const Duration(seconds: 2)) {
      return false;
    }
    if (_lastRegister.length >= 4096) _lastRegister.clear();
    _lastRegister[key] = now;
    return true;
  }

  static final _hexFp = RegExp(r'^[0-9a-f]{64}$');
  static bool _validPort(Object? p) => p is int && p > 0 && p <= 65535;

  void _noteMdns(MdnsPeerObservation o) {
    if (!_mdnsSeen.containsKey(o.fingerprint) &&
        _mdnsSeen.length >= _maxMdnsSeen) {
      _mdnsSeen.remove(_mdnsSeen.keys.first);
    }
    _mdnsSeen[o.fingerprint] = o;
  }

  /// A JSON object request body of at most [max] bytes, read within 30 s.
  static Future<Map<String, dynamic>> _readJsonBody(HttpRequest req,
      {int max = 1 << 20}) async {
    final bytes = await readBodyBounded(req, max: max);
    Object? v;
    try {
      v = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw _HttpError(400, 'invalid JSON');
    }
    if (v is! Map<String, dynamic>) throw _HttpError(400, 'expected object');
    return v;
  }

  /// Discards a refused request's body (at most 64 MB within 60 s, so a
  /// sender still reads the answer); a larger or slower one closes the
  /// connection instead. Repeated refusals hit the per-IP limit.
  static Future<void> _discard(HttpRequest req) async {
    try {
      await drainBounded(req,
          max: 64 << 20, timeout: const Duration(seconds: 60));
    } catch (_) {
      req.response.persistentConnection = false;
    }
  }

  Future<void> _announce() async {
    final d = _discovery;
    if (d == null || !_running) return;
    await d.broadcast({..._selfJson(), 'announce': true, 'announcement': true});
  }

  void _onDiscoveryMessage(Map<String, dynamic> msg, InternetAddress from) {
    if (!_running) return;
    final fp = (msg['fingerprint'] as Object?)?.toString().toLowerCase();
    // Only a certificate fingerprint can ever be verified.
    if (fp == null || !_hexFp.hasMatch(fp) || fp == _self?.fingerprint) return;
    final rawPort = msg['port'];
    if (rawPort != null && !_validPort(rawPort)) return;
    final port = rawPort is int ? rawPort : 53317;
    final ip = from.address;
    final announce = msg['announce'] == true || msg['announcement'] == true;
    // LanDrop senders tag each datagram with how it was sent; others don't.
    final tag = msg['landropVia'];
    final via = tag == 'multicast' || tag == 'broadcast' ? tag as String
        : 'announce';

    final known = _peers[fp];
    if (known != null &&
        known.addrs.containsKey(ip) &&
        known.info.port == port) {
      // Already verified at this address; refresh without reconnecting.
      _seenAt(known, ip, via);
      if (announce && _registerDue('$ip|$port|$fp')) {
        unawaited(_register(ip, port, fp));
      }
      return;
    }
    if (known == null && _peers.length >= options.maxPeers) return;
    // Verify over HTTPS (pinning the announced fingerprint) before adding;
    // throttled, since the datagram's source may be spoofed.
    var skipped = true;
    _gatedVerify(ip, port, fp, () {
      skipped = false;
      return announce
          ? _register(ip, port, fp)
          : _fetchInfo(ip, port, expectFp: fp, timeout: options.probeTimeout);
    }).then((info) async {
      if (info == null && announce && !skipped) {
        // HTTP reply failed: answer over UDP so the announcer can probe us
        // (at most once a second, so it cannot be used to amplify).
        final now = DateTime.now();
        if (now.difference(_lastUdpReply) >= const Duration(seconds: 1)) {
          _lastUdpReply = now;
          await _discovery?.broadcast({..._selfJson(), 'announce': false});
        }
      }
      if (info != null) _upsertPeer(info, via: via);
    });
  }

  // ------------------------------------------------------------ server

  Future<GuardedHttpServer> _bind(SecurityContext ctx) async {
    final addr = options.bindAddress ?? InternetAddress.anyIPv4;
    // Connection caps, TLS handshake and idle timeouts (SECURITY.md S1).
    Future<GuardedHttpServer> bind(int p) =>
        bindGuarded(addr, p, context: ctx, limits: options.serverLimits);
    if (options.port == 0) return bind(0);
    SocketException? last;
    for (var i = 0; i <= options.portFallbackRange; i++) {
      final p = options.port + i;
      if (p > 65535) break;
      try {
        return await bind(p);
      } on SocketException catch (e) {
        last = e;
      }
    }
    // Last resort: any free port.
    try {
      return await bind(0);
    } on SocketException {
      throw last ?? const SocketException('no free port');
    }
  }

  /// Endpoints whose failures count toward the per-IP limit.
  static const _limitedPaths = {
    '$_apiBase/prepare-upload',
    '$_apiBase/upload',
    '$_apiBase/cancel',
    '$_landropBase/upload-status',
  };

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    if (_web.handles(req.uri.path)) return _web.handle(req, secure: true);
    try {
      final path = req.uri.path;
      final m = req.method;
      if (_limitedPaths.contains(path) && _limiter.limited(_remoteIp(req))) {
        // Answered without reading the body; the connection is closed.
        res.persistentConnection = false;
        throw _HttpError(429, 'too many attempts');
      }
      if (path == '$_apiBase/info' && (m == 'GET' || m == 'POST')) {
        await drainBounded(req);
        _json(res, 200, _selfJson());
      } else if (path == '$_apiBase/register' && m == 'POST') {
        await _handleRegister(req);
      } else if (path == '$_apiBase/prepare-upload' && m == 'POST') {
        await _handlePrepare(req);
      } else if (path == '$_apiBase/upload' && m == 'POST') {
        await _handleUpload(req);
      } else if (path == '$_landropBase/upload-status' && m == 'GET') {
        await _handleUploadStatus(req);
      } else if (path == '$_landropBase/capabilities' && m == 'GET') {
        await drainBounded(req);
        _json(res, 200, _capabilities().toJson());
      } else if (path == '$_apiBase/cancel' && m == 'POST') {
        await drainBounded(req);
        _handleCancel(req);
      } else {
        await _discard(req);
        throw _HttpError(404, 'not found');
      }
    } on _HttpError catch (e) {
      // Too large or too slow: the rest of the body is not read, so the
      // connection cannot be reused.
      if (e.status == 408 || e.status == 413) res.persistentConnection = false;
      if (_limitedPaths.contains(req.uri.path) &&
          (e.status == 400 || e.status == 403 || e.status == 413)) {
        _limiter.hit(_remoteIp(req));
      }
      _json(res, e.status, {'message': e.message, ...?e.extra});
    } catch (e) {
      _json(res, 500, {'message': 'internal error'});
    }
  }

  void _json(HttpResponse res, int status, Map<String, dynamic> body) {
    try {
      res.statusCode = status;
      res.headers.contentType = ContentType.json;
      res.write(jsonEncode(body));
      res.close().catchError((_) {});
    } catch (_) {
      // headers already sent / connection gone
    }
  }

  String _remoteIp(HttpRequest req) =>
      req.connectionInfo?.remoteAddress.address ?? '0.0.0.0';

  Future<void> _handleRegister(HttpRequest req) async {
    final body = await _readJsonBody(req, max: 64 * 1024);
    _json(req.response, 200, _selfJson());
    // The caller's identity is unverified (no client certs), so probe it back
    // and only add it if its HTTPS cert matches the claimed fingerprint.
    final fp = (body['fingerprint'] as Object?)?.toString().toLowerCase();
    final rawPort = body['port'];
    if (rawPort != null && !_validPort(rawPort)) return;
    final port = rawPort is int ? rawPort : 53317;
    if (fp == null || !_hexFp.hasMatch(fp) || fp == _self?.fingerprint) {
      return;
    }
    final ip = _remoteIp(req);
    final known = _peers[fp];
    if (known != null &&
        known.addrs.containsKey(ip) &&
        known.info.port == port) {
      _seenAt(known, ip, 'register');
      return;
    }
    if (known == null && _peers.length >= options.maxPeers) return;
    unawaited(_gatedVerify(ip, port, fp,
            () => _fetchInfo(ip, port, expectFp: fp, timeout: options.probeTimeout))
        .then((info) {
      if (info != null) _upsertPeer(info, via: 'register');
    }));
  }

  Future<void> _handlePrepare(HttpRequest req) async {
    final body = await _readJsonBody(req, max: 16 << 20);
    if (_pendingDecision || _session != null) {
      throw _HttpError(409, 'busy');
    }
    final infoJson = body['info'];
    final filesJson = body['files'];
    if (infoJson is! Map<String, dynamic> || filesJson is! Map) {
      throw _HttpError(400, 'invalid body');
    }
    final ip = _remoteIp(req);
    final sender = _infoFromJson(infoJson, ip,
        infoJson['port'] is int ? infoJson['port'] as int : 53317);
    if (sender == null) throw _HttpError(400, 'invalid sender info');
    final withdraw = body['landropWithdraw'];
    await _prepareIncoming(req, sender, filesJson,
        withdrawSecret: withdraw is String && withdraw.length >= 16
            ? withdraw
            : null,
        verified: _senderProven(sender, filesJson, body['landropProof']));
  }

  /// Checks the optional sender proof of prepare-upload (PROTOCOL.md
  /// "Sender proof"): the certificate must have the claimed fingerprint and
  /// its key must have signed this receiver's fingerprint, the claimed
  /// fingerprint and the offered files. False when absent or wrong; the
  /// request is still handled (as an unverified sender).
  bool _senderProven(
      DeviceInfo sender, Map<dynamic, dynamic> filesJson, Object? proof) {
    final self = _self;
    if (proof is! Map || self == null || sender.fingerprint.isEmpty) {
      return false;
    }
    // No hashing work for a request that is refused for its size anyway.
    if (filesJson.length > options.maxOfferFiles) return false;
    try {
      final certB64 = proof['cert'] as String;
      final sigB64 = proof['sig'] as String;
      // A certificate of a few KB and an RSA signature of at most 4096 bit
      // (SECURITY.md S3); the key size is checked by verifyCertSignature.
      if (certB64.length > 16384 || sigB64.length > 1024) return false;
      final cert = base64Decode(certB64);
      final sig = base64Decode(sigB64);
      if (fingerprintOfDer(cert) != sender.fingerprint) return false;
      final files = <(String, String, int)>[];
      for (final e in filesJson.entries) {
        final f = e.value as Map;
        files.add(((f['id'] ?? e.key).toString(), f['fileName'] as String,
            f['size'] as int));
      }
      return verifyCertSignature(cert,
          senderProofMessage(self.fingerprint, sender.fingerprint, files), sig);
    } catch (_) {
      return false;
    }
  }

  /// Validates and sanitises an offered file list, asks the UI (Accept
  /// dialog), creates the receive session and answers [req]. Shared by
  /// prepare-upload and browser uploads ([owner] = browser session id).
  Future<void> _prepareIncoming(
      HttpRequest req, DeviceInfo sender, Map<dynamic, dynamic> filesJson,
      {String? owner, bool verified = false, String? withdrawSecret}) async {
    if (_pendingDecision || _session != null) {
      throw _HttpError(409, 'busy');
    }
    final offers = <String, FileOffer>{};
    final segments = <String, List<String>>{};
    // Bounded work and memory per request, and no 64-bit overflow of the
    // total size, which the auto-accept limit relies on (SECURITY.md S5).
    if (filesJson.length > options.maxOfferFiles) {
      throw _HttpError(413, 'too many files');
    }
    var total = 0;
    for (final entry in filesJson.entries) {
      final f = entry.value;
      if (f is! Map) throw _HttpError(400, 'invalid file');
      final id = (f['id'] ?? entry.key).toString();
      final name = f['fileName'];
      final size = f['size'];
      if (name is! String ||
          size is! int ||
          size < 0 ||
          id.isEmpty ||
          id.length > 128 ||
          name.length > 4096) {
        throw _HttpError(400, 'invalid file');
      }
      // total <= max always holds here, so neither side can overflow.
      if (size > options.maxOfferBytes ||
          size > options.maxOfferBytes - total) {
        throw _HttpError(413, 'too large');
      }
      total += size;
      final rawType = f['fileType'];
      final type = rawType is String &&
              rawType.length <= 128 &&
              !hasSpoofingChars(rawType)
          ? rawType
          : null;
      // Folder transfers carry relative paths; every segment is sanitised.
      final segs = sanitizeRelativePath(name);
      segments[id] = segs;
      offers[id] = FileOffer(id, segs.join('/'), size,
          type is String ? type : 'application/octet-stream',
          preview: owner == null && filesJson.length == 1
              ? textPreview(f['preview'])
              : null);
    }
    if (offers.isEmpty) throw _HttpError(400, 'no files');
    final isText = owner == null &&
        offers.length == 1 &&
        offers.values.single.preview != null &&
        offers.values.single.fileType.startsWith('text/plain');
    // Refuse what cannot fit before asking anyone (SECURITY.md S18).
    if (!isText && total > 0) {
      final free = await (options.freeSpace ?? freeDiskBytes)(_saveDir);
      if (free != null && total > free - _freeSpaceMargin) {
        throw _HttpError(507, 'not enough free space');
      }
    }

    final sessionId = randomHex(16);
    final request = IncomingRequest(sessionId, sender, offers.values.toList(),
        verified: verified && owner == null);
    if (!_incomingCtrl.hasListener) throw _HttpError(403, 'declined');

    _pendingDecision = true;
    _pending = (request, withdrawSecret);
    bool accepted;
    try {
      _incomingCtrl.add(request);
      accepted = await Future.any<bool>([
        request.decision.future,
        _stopped.future.then((_) {
          request.endedBy ??= IncomingRequestEnd.stopped;
          return false;
        }),
      ]).timeout(options.decisionTimeout, onTimeout: () {
        request.endedBy ??= IncomingRequestEnd.timeout;
        return false;
      });
    } catch (_) {
      accepted = false;
    } finally {
      _pendingDecision = false;
      _pending = null;
      // Ended without an answer: the UI closes its dialog (endedBy says why).
      if (!request.decision.isCompleted) {
        request.endedBy ??= IncomingRequestEnd.stopped;
        request.decision.complete(false);
      }
    }
    // A 403 counts toward the per-IP limit in [_handle], so a sender cannot
    // keep a dialog on screen by asking again and again (SECURITY.md S15).
    if (!accepted || !_running) throw _HttpError(403, 'declined');
    if (isText) {
      // The text was shown: nothing to upload, nothing written to disk.
      try {
        req.response.statusCode = HttpStatus.noContent;
        await req.response.close();
      } catch (_) {}
      return;
    }
    // The browser signed out or was disconnected while the owner decided.
    if (owner != null && !_web.sessionActive(owner)) {
      throw _HttpError(401, 'not paired');
    }
    if (_session != null) throw _HttpError(409, 'busy');

    final saveDir = _saveDir;
    // Top-level folders get a unique name ("Photos (1)") so a second
    // transfer of the same folder never merges into / overwrites the first.
    final tops = <String, String>{};
    final files = <String, _InFile>{};
    for (final o in offers.values) {
      final segs = segments[o.id]!;
      var dir = <String>[];
      if (segs.length > 1) {
        final top = tops.putIfAbsent(
            segs.first,
            () => uniqueDirName(saveDir, segs.first,
                taken: tops.values.toSet()));
        dir = [top, ...segs.sublist(1, segs.length - 1)];
      }
      files[o.id] = _InFile(o, randomHex(16), dir, segs.last);
    }
    final session = _InSession(sessionId, sender, files, randomHex(16),
        owner: owner, saveDir: saveDir);
    _session = session;
    _touch(session);
    _json(req.response, 200, {
      'sessionId': sessionId,
      'files': {for (final f in files.values) f.offer.id: f.token},
      'cancelSecret': session.cancelSecret,
    });
  }

  void _touch(_InSession s) {
    s.idle?.cancel();
    s.idle = Timer(options.sessionIdleTimeout, () {
      if (!identical(_session, s)) return;
      // An upload still running has its own read timeout; check again later.
      if (s.anyActive) {
        _touch(s);
      } else {
        s.endCode = SendErrorCode.timeout;
        _endSession(s, reason: 'timed out');
      }
    });
  }

  /// Ends [s]. Unfinished files get an error progress event (when [reason]
  /// is given; files still uploading report their own, unless
  /// [includeActive]) and their `.part` files are deleted, as are
  /// directories the session created that are still empty.
  void _endSession(_InSession s, {String? reason, bool includeActive = false}) {
    s.idle?.cancel();
    if (identical(_session, s)) _session = null;
    if (s.allFinished) return;
    s.cancelled = true;
    if (reason != null) {
      for (final f in s.files.values) {
        if (!f.finished && (includeActive || !f.active)) {
          _progressCtrl.add(TransferProgress(s.id, f.offer.id, 0, f.offer.size,
              done: true,
              error: reason,
              errorCode: s.endCode,
              fileName: f.offer.fileName));
        }
      }
    }
    unawaited(_cleanup(s));
  }

  Future<void> _cleanup(_InSession s) async {
    for (final f in s.files.values) {
      // Also for an active upload: it may be blocked waiting for data. (If
      // the delete fails, e.g. on Windows, the upload deletes its part when
      // it notices `cancelled`.)
      if (!f.finished) {
        try {
          await f.part?.delete();
        } catch (_) {}
      }
    }
    for (final d in s.createdDirs.reversed) {
      try {
        await Directory(d).delete(); // only succeeds when empty
      } catch (_) {}
    }
  }

  /// Validates session id and file token for upload / upload-status.
  /// With [owner] (browser uploads) the session must belong to that browser.
  (_InSession, _InFile) _authFile(HttpRequest req, {String? owner}) {
    final q = req.uri.queryParameters;
    final sessionId = q['sessionId'];
    final fileId = q['fileId'];
    final token = q['token'];
    if (sessionId == null || fileId == null || token == null) {
      throw _HttpError(400, 'missing parameters');
    }
    final s = _session;
    if (s == null ||
        s.id != sessionId ||
        s.cancelled ||
        (owner != null && s.owner != owner)) {
      throw _HttpError(403, 'invalid session');
    }
    final f = s.files[fileId];
    if (f == null || !_secretEquals(f.token, token)) {
      throw _HttpError(403, 'invalid token');
    }
    return (s, f);
  }

  static bool _secretEquals(String a, String b) {
    if (a.length != b.length) return false;
    var r = 0;
    for (var i = 0; i < a.length; i++) {
      r |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return r == 0;
  }

  Future<int> _partLength(_InFile f) async {
    if (f.finished) return f.offer.size;
    try {
      return await f.part?.length() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _handleUploadStatus(HttpRequest req) async {
    await drainBounded(req);
    final (_, f) = _authFile(req);
    _json(req.response, 200, {
      'received': await _partLength(f),
      'size': f.offer.size,
      'active': f.active,
      'done': f.finished,
    });
  }

  /// Creates (one level at a time) the directory for [f] below saveDir and
  /// checks, with symlinks resolved, that it is still inside saveDir.
  Future<Directory> _dirFor(_InSession s, _InFile f) async {
    final sep = Platform.pathSeparator;
    var path = s.saveDir;
    for (final seg in f.dirSegs) {
      path = '$path$sep$seg';
      final d = Directory(path);
      if (!await d.exists()) {
        await d.create();
        s.createdDirs.add(path);
      }
      if (!await isWithinDir(s.saveDir, path)) {
        throw _HttpError(403, 'unsafe path');
      }
    }
    return Directory(path);
  }

  Future<void> _handleUpload(HttpRequest req, {String? owner}) async {
    final _InSession s;
    final _InFile f;
    try {
      (s, f) = _authFile(req, owner: owner);
    } catch (_) {
      await _discard(req);
      rethrow;
    }
    if (f.finished) {
      await _discard(req);
      throw _HttpError(409, 'file already uploaded');
    }
    if (f.active) {
      await _discard(req);
      throw _HttpError(
          409, 'upload in progress', {'received': await _partLength(f)});
    }
    final offsetParam = req.uri.queryParameters['offset'];
    final offset = offsetParam == null ? null : int.tryParse(offsetParam);
    if (offsetParam != null && (offset == null || offset < 0)) {
      await _discard(req);
      throw _HttpError(400, 'invalid offset');
    }
    f.active = true;
    _touch(s);

    final fileId = f.offer.id;
    final size = f.offer.size;
    RandomAccessFile? raf;
    var received = 0;
    var lastEmit = 0;
    var fatal = false;
    void emit({bool done = false, String? error, String? savedPath}) =>
        _progressCtrl.add(TransferProgress(s.id, fileId, received, size,
            done: done,
            error: error,
            errorCode: error == null ? null : s.endCode ?? SendErrorCode.unknown,
            fileName: f.offer.fileName,
            savedPath: savedPath));
    try {
      final dir = await _dirFor(s, f);
      // Written under a hidden temporary name, renamed when complete.
      f.part ??= await reserveUniqueFile(dir.path, '.${f.name}.part');
      // Never write through a symlink planted in place of the .part file.
      if (FileSystemEntity.typeSync(f.part!.path, followLinks: false) !=
          FileSystemEntityType.file) {
        fatal = true;
        await _discard(req);
        throw _HttpError(403, 'unsafe path');
      }
      final have = await f.part!.length();
      if (offset != null && offset != have) {
        await _discard(req);
        throw _HttpError(409, 'offset mismatch', {'received': have});
      }
      // No offset (plain LocalSend sender): start over.
      received = offset ?? 0;
      lastEmit = received;
      raf = await f.part!.open(
          mode: offset == null ? FileMode.writeOnly : FileMode.writeOnlyAppend);
      emit();
      // `await for` + awaited writes = backpressure; never buffers the file.
      await for (final chunk in req.timeout(options.sessionIdleTimeout)) {
        if (s.cancelled || !_running) {
          fatal = true;
          throw _HttpError(409, 'cancelled');
        }
        if (received + chunk.length > size) {
          fatal = true;
          throw _HttpError(400, 'more data than declared');
        }
        await raf.writeFrom(chunk);
        received += chunk.length;
        if (received - lastEmit >= _progressStep) {
          lastEmit = received;
          emit();
          _touch(s);
        }
      }
      await raf.close();
      raf = null;
      if (received != size) {
        throw _HttpError(400, 'incomplete upload', {'received': received});
      }
      // Final size verified: move into place under a unique name. The
      // placeholder reserved by reserveUniqueFile is overwritten by rename.
      final target = await reserveUniqueFile(dir.path, f.name);
      await f.part!.rename(target.path);
      f.finished = true;
      f.active = false;
      emit(done: true, savedPath: target.path);
      if (s.allFinished) _endSession(s);
      _json(req.response, 200, {});
    } catch (e) {
      f.active = false;
      try {
        await raf?.close();
      } catch (_) {}
      if (fatal || s.cancelled || !_running) {
        try {
          await f.part?.delete();
        } catch (_) {}
        emit(done: true, error: e is _HttpError ? e.message : '$e');
        _endSession(s);
      }
      // Otherwise (connection dropped, stalled, short body) the .part is kept
      // so the sender can resume until the session idles out.
      if (e is _HttpError) rethrow;
      throw _HttpError(500, 'upload failed');
    } finally {
      f.active = false;
      _touch(s);
    }
  }

  void _handleCancel(HttpRequest req) {
    final q = req.uri.queryParameters;
    // A LanDrop sender withdraws a request nobody answered yet.
    final w = q['withdrawSecret'];
    if (w != null) {
      final p = _pending;
      final secret = p?.$2;
      if (p == null || secret == null || !_secretEquals(secret, w)) {
        throw _HttpError(403, 'nothing to withdraw');
      }
      if (!p.$1.decision.isCompleted) {
        p.$1.endedBy = IncomingRequestEnd.withdrawn;
        p.$1.decision.complete(false);
      }
      _json(req.response, 200, {});
      return;
    }
    final sid = q['sessionId'];
    final secret = q['cancelSecret'];
    final s = _session;
    if (s == null ||
        sid != s.id ||
        secret == null ||
        !_secretEquals(s.cancelSecret, secret)) {
      throw _HttpError(403, 'invalid session or cancel secret');
    }
    s.cancelled = true;
    s.endCode = SendErrorCode.cancelled;
    _endSession(s, reason: 'cancelled by sender');
    _json(req.response, 200, {});
  }
}
