// LocalSend-v2-compatible implementation of [LanDropCore] (pure dart:io).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'api.dart';
import 'discovery.dart';
import 'identity.dart';
import 'util.dart';

export 'discovery.dart' show DiscoveryTransport, MulticastDiscoveryTransport;
export 'identity.dart' show TlsIdentity, fingerprintOfDer;
export 'util.dart' show sanitizeFileName;

const _apiBase = '/api/localsend/v2';
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
  });
}

class _HttpError implements Exception {
  final int status;
  final String message;
  _HttpError(this.status, this.message);
}

class _Peer {
  DeviceInfo info;
  DateTime lastSeen;
  bool probing = false;
  _Peer(this.info) : lastSeen = DateTime.now();
}

class _InSession {
  final String id;
  final DeviceInfo sender;
  final Map<String, FileOffer> files;
  final Map<String, String> tokens;
  final Set<String> finished = {};
  final Set<String> active = {};
  bool cancelled = false;
  Timer? idle;
  _InSession(this.id, this.sender, this.files, this.tokens);
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

  static const _progressStep = 256 * 1024;

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

  List<DeviceInfo> get currentPeers =>
      List.unmodifiable(_peers.values.map((p) => p.info));

  @override
  Stream<IncomingRequest> get incoming => _incomingCtrl.stream;

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

    final ip = options.advertiseIp ??
        (await localIPv4Addresses()).map((a) => a.address).firstOrNull ??
        '127.0.0.1';
    _self = DeviceInfo(
        alias: alias,
        deviceType: options.deviceType,
        deviceModel: options.deviceModel,
        fingerprint: identity.fingerprint,
        ip: ip,
        port: server.port);

    server.listen(_handle, onError: (_) {});

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
        _discovery = null;
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
    _session?.idle?.cancel();
    _session = null;
    _pendingDecision = false;
    if (_peers.isNotEmpty) {
      _peers.clear();
      _emitPeers();
    }
  }

  /// Stops and closes all streams. The instance cannot be reused afterwards.
  Future<void> dispose() async {
    await stop();
    await _peerCtrl.close();
    await _incomingCtrl.close();
    await _progressCtrl.close();
  }

  @override
  Future<DeviceInfo?> addPeerByIp(String ip, {int port = 53317}) async {
    final info =
        await _fetchInfo(ip.trim(), port, timeout: options.probeTimeout);
    if (info == null || info.fingerprint == _self?.fingerprint) return null;
    _upsertPeer(info);
    return info;
  }

  @override
  Future<void> scanSubnet() async {
    final targets = <String>{};
    final own = <String>{};
    for (final a in await localIPv4Addresses()) {
      own.add(a.address);
      final b = a.rawAddress;
      for (var i = 1; i < 255; i++) {
        targets.add('${b[0]}.${b[1]}.${b[2]}.$i');
      }
    }
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
          _upsertPeer(info);
        }
      }
    }

    await Future.wait(
        List.generate(options.scanConcurrency, (_) => worker()));
  }

  @override
  Future<bool> send(DeviceInfo to, List<String> paths) async {
    if (!_running || _self == null) throw StateError('core not started');
    if (to.fingerprint.isEmpty) return false;
    final files = <String, (File, FileOffer)>{};
    for (final p in paths) {
      final f = File(p);
      final size = await f.length();
      final name = f.uri.pathSegments.lastWhere((s) => s.isNotEmpty,
          orElse: () => 'file');
      final id = randomHex(8);
      files[id] = (f, FileOffer(id, name, size, guessMime(name)));
    }
    if (files.isEmpty) return false;

    final client = _newClient(expectFp: to.fingerprint);
    String? sessionId;
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
      if (prep.$1 != 200 || prep.$2 == null) return false;
      sessionId = prep.$2!['sessionId'] as String?;
      final tokens = prep.$2!['files'];
      if (sessionId == null || tokens is! Map) return false;

      // 2. upload each file
      for (final e in files.entries) {
        final token = tokens[e.key];
        if (token is! String) continue; // receiver skipped this file
        final ok = await _uploadOne(client, to, sessionId, e.key, token,
            e.value.$1, e.value.$2.size);
        if (!ok) {
          unawaited(_sendCancel(to, sessionId));
          return false;
        }
      }
      return true;
    } catch (e) {
      if (sessionId != null) unawaited(_sendCancel(to, sessionId));
      return false;
    } finally {
      client.close(force: true);
    }
  }

  // ------------------------------------------------------------ sending

  Future<bool> _uploadOne(HttpClient client, DeviceInfo to, String sessionId,
      String fileId, String token, File file, int size) async {
    var sent = 0;
    var lastEmit = 0;
    _progressCtrl.add(TransferProgress(sessionId, fileId, 0, size));
    try {
      final req = await client
          .postUrl(_uri(to.ip, to.port, '/upload', {
            'sessionId': sessionId,
            'fileId': fileId,
            'token': token,
          }))
          .timeout(options.probeTimeout * 2);
      req.contentLength = size;
      req.headers.contentType = ContentType.binary;
      await req.addStream(file.openRead().map((chunk) {
        sent += chunk.length;
        if (sent - lastEmit >= _progressStep) {
          lastEmit = sent;
          _progressCtrl.add(TransferProgress(sessionId, fileId, sent, size));
        }
        return chunk;
      }));
      final res = await req.close();
      _checkPeerCert(res, to.fingerprint);
      await res.drain<void>();
      if (res.statusCode != 200) {
        _progressCtrl.add(TransferProgress(sessionId, fileId, sent, size,
            done: true, error: 'HTTP ${res.statusCode}'));
        return false;
      }
      _progressCtrl.add(
          TransferProgress(sessionId, fileId, sent, size, done: true));
      return true;
    } catch (e) {
      _progressCtrl.add(TransferProgress(sessionId, fileId, sent, size,
          done: true, error: e.toString()));
      return false;
    }
  }

  Future<void> _sendCancel(DeviceInfo to, String sessionId) async {
    final c = _newClient(expectFp: to.fingerprint);
    try {
      final req = await c
          .postUrl(_uri(to.ip, to.port, '/cancel', {'sessionId': sessionId}))
          .timeout(options.probeTimeout);
      final res = await req.close().timeout(options.probeTimeout);
      await res.drain<void>();
    } catch (_) {
    } finally {
      c.close(force: true);
    }
  }

  // ------------------------------------------------------------ HTTP client

  Uri _uri(String ip, int port, String path, [Map<String, String>? q]) => Uri(
      scheme: 'https',
      host: ip,
      port: port,
      path: '$_apiBase$path',
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
    };
  }

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
    );
  }

  // ------------------------------------------------------------ peers

  void _upsertPeer(DeviceInfo info) {
    if (!_running || info.fingerprint == _self?.fingerprint) return;
    final existing = _peers[info.fingerprint];
    if (existing == null) {
      _peers[info.fingerprint] = _Peer(info);
      _emitPeers();
      return;
    }
    existing.lastSeen = DateTime.now();
    final o = existing.info;
    if (o.ip != info.ip ||
        o.port != info.port ||
        o.alias != info.alias ||
        o.deviceType != info.deviceType ||
        o.deviceModel != info.deviceModel) {
      existing.info = info;
      _emitPeers();
    }
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

    final known = _peers[fp];
    if (known != null && known.info.ip == ip && known.info.port == port) {
      // Already verified at this address; refresh without reconnecting.
      known.lastSeen = DateTime.now();
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
      if (info != null) _upsertPeer(info);
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
      } else if (path == '$_apiBase/cancel' && m == 'POST') {
        await req.drain<void>();
        _handleCancel(req);
      } else {
        await req.drain<void>();
        throw _HttpError(404, 'not found');
      }
    } on _HttpError catch (e) {
      _json(res, e.status, {'message': e.message});
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
      return;
    }
    unawaited(_fetchInfo(ip, port, expectFp: fp, timeout: options.probeTimeout)
        .then((info) {
      if (info != null) _upsertPeer(info);
    }));
  }

  Future<void> _handlePrepare(HttpRequest req) async {
    final body = await _readJsonStream(req);
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
    final offers = <String, FileOffer>{};
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
      offers[id] = FileOffer(id, name, size,
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

    final session = _InSession(sessionId, sender, offers,
        {for (final id in offers.keys) id: randomHex(16)});
    _session = session;
    _touch(session);
    _json(req.response, 200, {'sessionId': sessionId, 'files': session.tokens});
  }

  void _touch(_InSession s) {
    s.idle?.cancel();
    s.idle = Timer(options.sessionIdleTimeout, () {
      if (identical(_session, s) && s.active.isEmpty) _endSession(s);
    });
  }

  void _endSession(_InSession s) {
    s.idle?.cancel();
    if (identical(_session, s)) _session = null;
  }

  Future<void> _handleUpload(HttpRequest req) async {
    final q = req.uri.queryParameters;
    final sessionId = q['sessionId'];
    final fileId = q['fileId'];
    final token = q['token'];
    if (sessionId == null || fileId == null || token == null) {
      await req.drain<void>();
      throw _HttpError(400, 'missing parameters');
    }
    final s = _session;
    if (s == null || s.id != sessionId || s.cancelled) {
      await req.drain<void>();
      throw _HttpError(403, 'invalid session');
    }
    final offer = s.files[fileId];
    final expected = s.tokens[fileId];
    if (offer == null || expected == null || expected != token) {
      await req.drain<void>();
      throw _HttpError(403, 'invalid token');
    }
    if (s.finished.contains(fileId) || s.active.contains(fileId)) {
      await req.drain<void>();
      throw _HttpError(409, 'file already uploaded');
    }
    s.active.add(fileId);
    _touch(s);

    final size = offer.size;
    File? file;
    RandomAccessFile? raf;
    var received = 0;
    var lastEmit = 0;
    _progressCtrl.add(TransferProgress(sessionId, fileId, 0, size));
    try {
      file = await reserveUniqueFile(_saveDir, sanitizeFileName(offer.fileName));
      raf = await file.open(mode: FileMode.writeOnly);
      // `await for` + awaited writes = backpressure; never buffers the file.
      await for (final chunk in req) {
        if (s.cancelled || !_running) throw _HttpError(409, 'cancelled');
        received += chunk.length;
        if (received > size) throw _HttpError(400, 'more data than declared');
        await raf.writeFrom(chunk);
        if (received - lastEmit >= _progressStep) {
          lastEmit = received;
          _progressCtrl.add(TransferProgress(sessionId, fileId, received, size));
          _touch(s);
        }
      }
      await raf.close();
      raf = null;
      if (received != size) throw _HttpError(400, 'incomplete upload');
      s.active.remove(fileId);
      s.finished.add(fileId);
      _progressCtrl.add(
          TransferProgress(sessionId, fileId, received, size, done: true));
      if (s.finished.length == s.files.length) _endSession(s);
      _json(req.response, 200, {});
    } catch (e) {
      s.active.remove(fileId);
      try {
        await raf?.close();
      } catch (_) {}
      try {
        await file?.delete();
      } catch (_) {}
      _progressCtrl.add(TransferProgress(sessionId, fileId, received, size,
          done: true, error: e is _HttpError ? e.message : e.toString()));
      // Sender aborted or something failed: give up the whole session so
      // we don't stay busy.
      _endSession(s);
      if (e is _HttpError) rethrow;
      throw _HttpError(500, 'write failed');
    }
  }

  void _handleCancel(HttpRequest req) {
    final sid = req.uri.queryParameters['sessionId'];
    final s = _session;
    if (s != null && sid == s.id) {
      s.cancelled = true;
      _endSession(s);
    }
    _json(req.response, 200, {});
  }
}
