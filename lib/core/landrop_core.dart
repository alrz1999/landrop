// LocalSend-v2-compatible implementation of [LanDropCore] (pure dart:io).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'api.dart';
import 'diagnosis.dart';
import 'discovery.dart';
import 'identity.dart';
import 'util.dart';
import 'web_server.dart';

export 'discovery.dart' show DiscoveryTransport, MulticastDiscoveryTransport;
export 'identity.dart' show TlsIdentity, fingerprintOfDer;
export 'util.dart' show sanitizeFileName, sanitizeRelativePath;
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

  /// Where cert.pem/key.pem are kept. Null: `<saveDir>/.landrop`.
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

  const LanDropCoreOptions({
    this.port = 53317,
    this.portFallbackRange = 20,
    this.bindAddress,
    this.advertiseIp,
    this.multicastEnabled = true,
    this.multicastPort = 53317,
    this.discoveryTransport,
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
  });
}

typedef _HttpError = HttpStatusError;

enum _Attempt { ok, retry, fatal }

class _Peer {
  DeviceInfo info;
  DateTime lastSeen;
  bool probing = false;

  /// How this peer was found (see [DeviceInfo.foundVia]).
  final Set<String> via = {};
  _Peer(this.info) : lastSeen = DateTime.now();
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

class _InSession {
  final String id;
  final DeviceInfo sender;
  final Map<String, _InFile> files;

  /// Given to the sender in prepare-upload; required by /cancel.
  final String cancelSecret;

  /// Directories this session created (deleted again if left empty).
  final List<String> createdDirs = [];
  bool cancelled = false;
  Timer? idle;

  /// Browser session that created it (browser uploads only).
  final String? owner;
  _InSession(this.id, this.sender, this.files, this.cancelSecret, {this.owner});

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
  HttpServer? _server;
  DiscoveryTransport? _discovery;
  TlsIdentity? _identity;
  DeviceInfo? _self;
  String _saveDir = '.';
  Timer? _announceTimer;
  Timer? _pruneTimer;
  bool _running = false;
  Completer<void> _stopped = Completer<void>();

  bool _pendingDecision = false;
  _InSession? _session;
  String? _discoveryError;

  /// Addresses advertised in the capability record (set on start).
  List<String> _capAddrs = const [];

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
    ),
    selfInfo: () => self,
    prepareUpload: (req, sender, files, owner) =>
        _prepareIncoming(req, sender, files, owner: owner),
    upload: (req, owner) => _handleUpload(req, owner: owner),
  );

  static const _progressStep = 256 * 1024;

  // ------------------------------------------------------- browser access

  @override
  Stream<WebPairingRequest> get webPairing => _web.pairing;
  @override
  List<Share> get shares => _web.shares;
  @override
  Stream<List<Share>> get sharesChanged => _web.sharesChanged;
  @override
  Share createShare(List<String> paths, {Duration? ttl, int? maxDownloads}) =>
      _web.createShare(paths, ttl: ttl, maxDownloads: maxDownloads);
  @override
  void revokeShare(String id) => _web.revokeShare(id);
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

  List<DeviceInfo> get currentPeers => List.unmodifiable(_peers.values
      .map((p) => p.info.copyWith(foundVia: Set.unmodifiable(p.via))));

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
    final identity = _identity ??= await TlsIdentity.loadOrCreate(idDir);

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

    server.listen(_handle, onError: (_) {});
    await _web.start();
    _discoveryError = null;

    final transport = options.discoveryTransport ??
        (options.multicastEnabled
            ? MulticastDiscoveryTransport(port: options.multicastPort)
            : null);
    if (transport != null) {
      try {
        await transport.start(_onDiscoveryMessage);
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
    _pruneTimer = Timer.periodic(
        Duration(
            milliseconds:
                (options.peerTimeout.inMilliseconds ~/ 4).clamp(250, 5000)),
        (_) => _prune());
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
    await _server?.close(force: true);
    _server = null;
    await _web.stop();
    final s = _session;
    if (s != null) _endSession(s, reason: 'receiver stopped');
    _pendingDecision = false;
    if (_peers.isNotEmpty) {
      _peers.clear();
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
      {void Function(String sessionId)? onSession}) async {
    if (!_running || _self == null) throw StateError('core not started');
    if (to.fingerprint.isEmpty) {
      return const SendResult(ok: false, error: 'peer has no fingerprint');
    }
    final List<(File, String, int)> expanded;
    try {
      expanded = await _expand(items);
    } catch (e) {
      return SendResult(ok: false, error: '$e');
    }
    if (expanded.isEmpty) {
      return const SendResult(ok: false, error: 'nothing to send');
    }
    final files = <String, (File, FileOffer)>{};
    for (final (f, name, size) in expanded) {
      final id = randomHex(8);
      files[id] = (f, FileOffer(id, name, size, guessMime(name)));
    }

    final client = _newClient(expectFp: to.fingerprint);
    String? sessionId;
    String? cancelSecret;
    try {
      // 1. prepare-upload (waits for the receiver's decision)
      final prep = await _postJson(
          client,
          _uri(to.ip, to.port, '/prepare-upload'),
          {
            'info': _selfJson(),
            'files': {
              for (final e in files.entries)
                e.key: {
                  'id': e.value.$2.id,
                  'fileName': e.value.$2.fileName,
                  'size': e.value.$2.size,
                  'fileType': e.value.$2.fileType,
                }
            },
          },
          expectFp: to.fingerprint,
          timeout: options.decisionTimeout + const Duration(seconds: 30));
      if (prep.$1 != 200 || prep.$2 == null) {
        return SendResult(
            ok: false,
            error: switch (prep.$1) {
              403 => 'declined',
              409 => 'receiver is busy',
              _ => 'HTTP ${prep.$1}',
            });
      }
      final sid = prep.$2!['sessionId'];
      final tokens = prep.$2!['files'];
      if (sid is! String || tokens is! Map) {
        return const SendResult(ok: false, error: 'invalid prepare response');
      }
      sessionId = sid;
      final secret = prep.$2!['cancelSecret'];
      cancelSecret = secret is String ? secret : null;
      try {
        onSession?.call(sid);
      } catch (_) {}

      // 2. upload each file (resuming broken connections)
      for (final e in files.entries) {
        final token = tokens[e.key];
        if (token is! String) continue; // receiver skipped this file
        final err = await _uploadOne(client, to, sid, e.key, token,
            e.value.$1, e.value.$2.size, e.value.$2.fileName);
        if (err != null) {
          unawaited(_sendCancel(to, sid, cancelSecret));
          return SendResult(ok: false, sessionId: sid, error: err);
        }
      }
      return SendResult(ok: true, sessionId: sid);
    } catch (e) {
      if (sessionId != null) {
        unawaited(_sendCancel(to, sessionId, cancelSecret));
      }
      return SendResult(ok: false, sessionId: sessionId, error: '$e');
    } finally {
      client.close(force: true);
    }
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
              p.info.ip == ip &&
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
  /// connection breaks or stalls. Returns null on success, else the error.
  Future<String?> _uploadOne(HttpClient client, DeviceInfo to, String sessionId,
      String fileId, String token, File file, int size, String name) async {
    final q = {'sessionId': sessionId, 'fileId': fileId, 'token': token};
    void emit(int sent, {bool done = false, String? error}) =>
        _progressCtrl.add(TransferProgress(sessionId, fileId, sent, size,
            done: done, error: error, fileName: name));

    emit(0);
    var offset = 0;
    String lastError = 'upload failed';
    for (var attempt = 0; attempt <= options.uploadRetries; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(options.retryBackoff * (1 << (attempt - 1)));
        if (!_running) break;
        try {
          final st = await _uploadStatus(to, q);
          if (st == null) continue; // receiver unreachable right now
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
      final (outcome, msg) =
          await _uploadAttempt(client, to, q, fileId, file, offset, size,
              attempt, emit);
      if (outcome == _Attempt.ok) {
        emit(size, done: true);
        return null;
      }
      lastError = msg ?? lastError;
      if (outcome == _Attempt.fatal) break;
    }
    emit(offset, done: true, error: lastError);
    return lastError;
  }

  Future<(_Attempt, String?)> _uploadAttempt(
      HttpClient client,
      DeviceInfo to,
      Map<String, String> q,
      String fileId,
      File file,
      int offset,
      int size,
      int attempt,
      void Function(int sent) emit) async {
    var sent = offset;
    var lastEmit = offset;
    var lastActivity = DateTime.now();
    var stalled = false;
    Timer? watchdog;
    try {
      final req = await client
          .postUrl(_uri(to.ip, to.port, '/upload', {...q, 'offset': '$offset'}))
          .timeout(options.probeTimeout * 2);
      req.contentLength = size - offset;
      req.headers.contentType = ContentType.binary;
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
      return (_Attempt.retry, stalled ? 'upload stalled' : '$e');
    } finally {
      watchdog?.cancel();
    }
  }

  /// Asks the receiver how many bytes of a file it has. Waits (up to
  /// [LanDropCoreOptions.stallTimeout]) while the receiver still sees the old
  /// connection as active. Null when unreachable; throws [_HttpError] when the
  /// session or token is no longer valid.
  Future<({int received, bool done})?> _uploadStatus(
      DeviceInfo to, Map<String, String> q) async {
    final deadline = DateTime.now().add(options.stallTimeout);
    final c = _newClient(expectFp: to.fingerprint);
    try {
      while (true) {
        final req = await c
            .getUrl(_uri(to.ip, to.port, '/upload-status', q, _landropBase))
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
      DeviceInfo to, String sessionId, String? cancelSecret) async {
    final c = _newClient(expectFp: to.fingerprint);
    try {
      final req = await c
          .postUrl(_uri(to.ip, to.port, '/cancel', {
            'sessionId': sessionId,
            'cancelSecret': ?cancelSecret,
          }))
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
    final req = await client.postUrl(uri).timeout(options.probeTimeout * 2);
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

  /// This device's capability record (DESIGN.md 3.3). LAN only for now.
  PeerCapabilities _capabilities() => PeerCapabilities(
        transports: [
          TransportCapability('lan-https', addrs: _capAddrs, port: self.port),
        ],
        features: const {'resume', 'folders', 'browser-ui'},
      );

  DeviceInfo? _infoFromJson(Map<String, dynamic> j, String ip, int port) {
    final fp = j['fingerprint'];
    if (fp is! String || fp.isEmpty) return null;
    final alias = j['alias'];
    final type = j['deviceType'];
    final model = j['deviceModel'];
    return DeviceInfo(
      alias: alias is String && alias.isNotEmpty ? alias : ip,
      deviceType: type is String ? type : 'desktop',
      deviceModel: model is String ? model : null,
      fingerprint: fp.toLowerCase(),
      ip: ip,
      port: port,
      capabilities: PeerCapabilities.fromJson(j['landrop']),
    );
  }

  // ------------------------------------------------------------ peers

  /// Adds or refreshes a peer; [via] records how it was found.
  void _upsertPeer(DeviceInfo info, {String? via}) {
    if (!_running || info.fingerprint == _self?.fingerprint) return;
    final existing = _peers[info.fingerprint];
    if (existing == null) {
      _peers[info.fingerprint] = _Peer(info)..via.addAll([?via]);
      _emitPeers();
      return;
    }
    existing.lastSeen = DateTime.now();
    final newVia = via != null && existing.via.add(via);
    final o = existing.info;
    if (o.ip != info.ip ||
        o.port != info.port ||
        o.alias != info.alias ||
        o.deviceType != info.deviceType ||
        o.deviceModel != info.deviceModel ||
        jsonEncode(o.capabilities?.toJson()) !=
            jsonEncode(info.capabilities?.toJson())) {
      existing.info = info;
      _emitPeers();
    } else if (newVia) {
      _emitPeers();
    }
  }

  /// Records [via] for an already known peer (refresh without re-probing).
  void _noteVia(_Peer p, String via) {
    if (p.via.add(via)) _emitPeers();
  }

  void _emitPeers() {
    if (!_peerCtrl.isClosed) _peerCtrl.add(currentPeers);
  }

  /// Peers not seen for [peerTimeout] get one re-probe; if that fails they
  /// are removed. (Keeps manually added / scanned peers alive while
  /// reachable, without multicast.)
  void _prune() {
    final now = DateTime.now();
    for (final p in _peers.values.toList()) {
      if (p.probing || now.difference(p.lastSeen) < options.peerTimeout) {
        continue;
      }
      p.probing = true;
      _fetchInfo(p.info.ip, p.info.port,
              expectFp: p.info.fingerprint, timeout: options.probeTimeout)
          .then((info) {
        p.probing = false;
        if (!_running) return;
        if (info != null) {
          _upsertPeer(info);
        } else if (identical(_peers[p.info.fingerprint], p)) {
          _peers.remove(p.info.fingerprint);
          _emitPeers();
        }
      });
    }
  }

  // ------------------------------------------------------------ discovery

  Future<void> _announce() async {
    final d = _discovery;
    if (d == null || !_running) return;
    await d.broadcast({..._selfJson(), 'announce': true, 'announcement': true});
  }

  void _onDiscoveryMessage(Map<String, dynamic> msg, InternetAddress from) {
    if (!_running) return;
    final fp = (msg['fingerprint'] as Object?)?.toString().toLowerCase();
    if (fp == null || fp.isEmpty || fp == _self?.fingerprint) return;
    final port = msg['port'] is int ? msg['port'] as int : 53317;
    final ip = from.address;
    final announce = msg['announce'] == true || msg['announcement'] == true;
    // LanDrop senders tag each datagram with how it was sent; others don't.
    final tag = msg['landropVia'];
    final via = tag == 'multicast' || tag == 'broadcast' ? tag as String
        : 'announce';

    final known = _peers[fp];
    if (known != null && known.info.ip == ip && known.info.port == port) {
      // Already verified at this address; refresh without reconnecting.
      known.lastSeen = DateTime.now();
      _noteVia(known, via);
      if (announce) unawaited(_register(ip, port, fp));
      return;
    }
    // Verify over HTTPS (pinning the announced fingerprint) before adding.
    final Future<DeviceInfo?> verify = announce
        ? _register(ip, port, fp)
        : _fetchInfo(ip, port, expectFp: fp, timeout: options.probeTimeout);
    verify.then((info) async {
      if (info == null && announce) {
        // HTTP reply failed: answer over UDP so the announcer can probe us.
        await _discovery?.broadcast({..._selfJson(), 'announce': false});
      }
      if (info != null) _upsertPeer(info, via: via);
    });
  }

  // ------------------------------------------------------------ server

  Future<HttpServer> _bind(SecurityContext ctx) async {
    final addr = options.bindAddress ?? InternetAddress.anyIPv4;
    if (options.port == 0) return HttpServer.bindSecure(addr, 0, ctx);
    SocketException? last;
    for (var i = 0; i <= options.portFallbackRange; i++) {
      final p = options.port + i;
      if (p > 65535) break;
      try {
        return await HttpServer.bindSecure(addr, p, ctx);
      } on SocketException catch (e) {
        last = e;
      }
    }
    // Last resort: any free port.
    try {
      return await HttpServer.bindSecure(addr, 0, ctx);
    } on SocketException {
      throw last ?? const SocketException('no free port');
    }
  }

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    if (_web.handles(req.uri.path)) return _web.handle(req, secure: true);
    try {
      final path = req.uri.path;
      final m = req.method;
      if (path == '$_apiBase/info' && (m == 'GET' || m == 'POST')) {
        await req.drain<void>();
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
        await req.drain<void>();
        _json(res, 200, _capabilities().toJson());
      } else if (path == '$_apiBase/cancel' && m == 'POST') {
        await req.drain<void>();
        _handleCancel(req);
      } else {
        await req.drain<void>();
        throw _HttpError(404, 'not found');
      }
    } on _HttpError catch (e) {
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
    final body = await _readJsonStream(req);
    _json(req.response, 200, _selfJson());
    // The caller's identity is unverified (no client certs), so probe it back
    // and only add it if its HTTPS cert matches the claimed fingerprint.
    final fp = (body['fingerprint'] as Object?)?.toString().toLowerCase();
    final port = body['port'] is int ? body['port'] as int : 53317;
    if (fp == null || fp == _self?.fingerprint) return;
    final ip = _remoteIp(req);
    final known = _peers[fp];
    if (known != null && known.info.ip == ip && known.info.port == port) {
      known.lastSeen = DateTime.now();
      _noteVia(known, 'register');
      return;
    }
    unawaited(_fetchInfo(ip, port, expectFp: fp, timeout: options.probeTimeout)
        .then((info) {
      if (info != null) _upsertPeer(info, via: 'register');
    }));
  }

  Future<void> _handlePrepare(HttpRequest req) async {
    final body = await _readJsonStream(req, max: 16 << 20);
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
    await _prepareIncoming(req, sender, filesJson);
  }

  /// Validates and sanitises an offered file list, asks the UI (Accept
  /// dialog), creates the receive session and answers [req]. Shared by
  /// prepare-upload and browser uploads ([owner] = browser session id).
  Future<void> _prepareIncoming(
      HttpRequest req, DeviceInfo sender, Map<dynamic, dynamic> filesJson,
      {String? owner}) async {
    if (_pendingDecision || _session != null) {
      throw _HttpError(409, 'busy');
    }
    final offers = <String, FileOffer>{};
    final segments = <String, List<String>>{};
    for (final entry in filesJson.entries) {
      final f = entry.value;
      if (f is! Map) throw _HttpError(400, 'invalid file');
      final id = (f['id'] ?? entry.key).toString();
      final name = f['fileName'];
      final size = f['size'];
      if (name is! String || size is! int || size < 0 || id.isEmpty) {
        throw _HttpError(400, 'invalid file');
      }
      final type = f['fileType'];
      // Folder transfers carry relative paths; every segment is sanitised.
      final segs = sanitizeRelativePath(name);
      segments[id] = segs;
      offers[id] = FileOffer(id, segs.join('/'), size,
          type is String ? type : 'application/octet-stream');
    }
    if (offers.isEmpty) throw _HttpError(400, 'no files');

    final sessionId = randomHex(16);
    final request = IncomingRequest(sessionId, sender, offers.values.toList());
    if (!_incomingCtrl.hasListener) throw _HttpError(403, 'declined');

    _pendingDecision = true;
    bool accepted;
    try {
      _incomingCtrl.add(request);
      accepted = await Future.any<bool>([
        request.decision.future,
        _stopped.future.then((_) => false),
      ]).timeout(options.decisionTimeout, onTimeout: () => false);
    } catch (_) {
      accepted = false;
    } finally {
      _pendingDecision = false;
    }
    if (!accepted || !_running) throw _HttpError(403, 'declined');
    if (_session != null) throw _HttpError(409, 'busy');

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
            () => uniqueDirName(_saveDir, segs.first,
                taken: tops.values.toSet()));
        dir = [top, ...segs.sublist(1, segs.length - 1)];
      }
      files[o.id] = _InFile(o, randomHex(16), dir, segs.last);
    }
    final session =
        _InSession(sessionId, sender, files, randomHex(16), owner: owner);
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
        _endSession(s, reason: 'timed out');
      }
    });
  }

  /// Ends [s]. Unfinished files get an error progress event (when [reason]
  /// is given) and their `.part` files are deleted, as are directories the
  /// session created that are still empty.
  void _endSession(_InSession s, {String? reason}) {
    s.idle?.cancel();
    if (identical(_session, s)) _session = null;
    if (s.allFinished) return;
    s.cancelled = true;
    if (reason != null) {
      for (final f in s.files.values) {
        if (!f.finished && f.part != null && !f.active) {
          _progressCtrl.add(TransferProgress(s.id, f.offer.id, 0, f.offer.size,
              done: true, error: reason, fileName: f.offer.fileName));
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
    await req.drain<void>();
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
    var path = _saveDir;
    for (final seg in f.dirSegs) {
      path = '$path$sep$seg';
      final d = Directory(path);
      if (!await d.exists()) {
        await d.create();
        s.createdDirs.add(path);
      }
      if (!await isWithinDir(_saveDir, path)) {
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
      await req.drain<void>();
      rethrow;
    }
    if (f.finished) {
      await req.drain<void>();
      throw _HttpError(409, 'file already uploaded');
    }
    if (f.active) {
      await req.drain<void>();
      throw _HttpError(
          409, 'upload in progress', {'received': await _partLength(f)});
    }
    final offsetParam = req.uri.queryParameters['offset'];
    final offset = offsetParam == null ? null : int.tryParse(offsetParam);
    if (offsetParam != null && (offset == null || offset < 0)) {
      await req.drain<void>();
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
    void emit({bool done = false, String? error}) =>
        _progressCtrl.add(TransferProgress(s.id, fileId, received, size,
            done: done, error: error, fileName: f.offer.fileName));
    try {
      final dir = await _dirFor(s, f);
      // Written under a hidden temporary name, renamed when complete.
      f.part ??= await reserveUniqueFile(dir.path, '.${f.name}.part');
      final have = await f.part!.length();
      if (offset != null && offset != have) {
        await req.drain<void>();
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
      emit(done: true);
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
    _endSession(s, reason: 'cancelled by sender');
    _json(req.response, 200, {});
  }
}
