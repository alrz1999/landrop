// Browser access (DESIGN.md 4): the web page, browser pairing, browser
// uploads, shares with HTTP range streaming, and the optional plain HTTP
// listener. Pure dart:io; the core plugs in its receive pipeline through
// [WebPrepareUpload] / [WebUpload] so the upload safety logic lives in one
// place (landrop_core.dart).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'api.dart';
import 'guarded_server.dart';
import 'util.dart';
import 'web_assets.dart';

const webApiBase = '/api/landrop/v1';

/// CSP source for the inline `<tag>` block of the page: its SHA-256 hash,
/// so no other inline script or style can run (SECURITY.md S14).
String _inlineHash(String tag) {
  final m = RegExp('<$tag>(.*?)</$tag>', dotAll: true).firstMatch(webPageHtml);
  if (m == null) return "'none'";
  return "'sha256-${base64Encode(sha256.convert(utf8.encode(m.group(1)!)).bytes)}'";
}

/// Sent with every web response (page, JSON, file bytes, errors). Inline
/// script and style are allowed only by hash; no plugins, no `<base>`, forms
/// only to this origin, no framing.
final String webCsp = "default-src 'self'; style-src 'self' ${_inlineHash('style')}; "
    "script-src 'self' ${_inlineHash('script')}; img-src 'self' data:; "
    "media-src 'self'; object-src 'none'; base-uri 'none'; "
    "form-action 'self'; frame-ancestors 'none'";

/// Token -> map key. Secrets are looked up by their SHA-256, so the map's
/// hashing and equality never run on the secret itself (SECURITY.md S17).
String webTokenKey(String token) => sha256.convert(utf8.encode(token)).toString();

const webSessionCookie = 'landrop_session';

/// Default port of the plain HTTP listener (falls back to a free port).
const defaultWebHttpPort = 53320;

void setWebSecurityHeaders(HttpHeaders h) {
  h.set('Content-Security-Policy', webCsp);
  h.set('Referrer-Policy', 'no-referrer');
  h.set('X-Frame-Options', 'DENY');
  h.set('X-Content-Type-Options', 'nosniff');
  h.set('Cache-Control', 'no-store');
}

class WebConfig {
  /// Port of the plain HTTP listener. Null: listener off at start (it can be
  /// turned on later and then uses [defaultWebHttpPort]); 0: ephemeral.
  final int? httpPort;
  final InternetAddress? bindAddress;
  final Duration pairingTimeout;
  final int maxPendingPairings;

  /// Failed or suspicious attempts allowed per remote IP within
  /// [rateWindow] before web API requests from that IP get 429.
  final int rateLimit;
  final Duration rateWindow;
  final Duration sessionTtl;

  /// See the download counting rule on [WebService].
  final Duration streamWindow;

  /// Connection limits of the plain HTTP listener (SECURITY.md S1).
  final ServerLimits serverLimits;
  const WebConfig({
    this.serverLimits = const ServerLimits(),
    this.httpPort,
    this.bindAddress,
    this.pairingTimeout = const Duration(seconds: 60),
    this.maxPendingPairings = 5,
    this.rateLimit = 10,
    this.rateWindow = const Duration(minutes: 1),
    this.sessionTtl = const Duration(hours: 1),
    this.streamWindow = const Duration(minutes: 30),
  });
}

/// Core hook: run the normal prepare-upload path (Accept dialog, sanitised
/// names, session tokens) for a browser and write the response. [files] has
/// the LocalSend shape `{ id: {id, fileName, size, fileType} }`; [owner]
/// ties the receive session to the browser session.
typedef WebPrepareUpload = Future<void> Function(HttpRequest req,
    DeviceInfo sender, Map<String, dynamic> files, String owner);

/// Core hook: the normal upload handler, restricted to sessions of [owner].
typedef WebUpload = Future<void> Function(HttpRequest req, String owner);

/// Inclusive byte range.
class ByteRange {
  final int start;
  final int end;
  const ByteRange(this.start, this.end);
  int get length => end - start + 1;
  @override
  String toString() => '$start-$end';
}

/// A malformed or unsatisfiable `Range` header (answered with 416).
class RangeNotSatisfiable implements Exception {
  const RangeNotSatisfiable();
}

/// Parses a `Range` header for a resource of [size] bytes.
///
/// Returns null when the whole resource is to be sent: no header, a unit
/// other than `bytes` (ignored as RFC 9110 allows), or several ranges
/// (multi-range is ignored and answered 200 with the full body; LanDrop never
/// sends multipart/byteranges). Supports `bytes=a-b` (end clamped to the
/// last byte), `bytes=a-` and the suffix form `bytes=-n` (n larger than the
/// file means the whole file). Throws [RangeNotSatisfiable] for a malformed
/// single range, `b < a`, a start at or past the end, `bytes=-0`, or any
/// range on an empty file.
ByteRange? parseRange(String? header, int size) {
  if (header == null) return null;
  final h = header.trim();
  if (!h.toLowerCase().startsWith('bytes=')) return null;
  final spec = h.substring(6).trim();
  if (spec.contains(',')) return null;
  final m = RegExp(r'^(\d*)\s*-\s*(\d*)$').firstMatch(spec);
  if (m == null) throw const RangeNotSatisfiable();
  final a = m.group(1)!;
  final b = m.group(2)!;
  if (a.isEmpty && b.isEmpty) throw const RangeNotSatisfiable();
  if (a.isEmpty) {
    final n = int.tryParse(b);
    if (n == null || n == 0 || size == 0) throw const RangeNotSatisfiable();
    return ByteRange(n >= size ? 0 : size - n, size - 1);
  }
  final start = int.tryParse(a);
  if (start == null || start >= size) throw const RangeNotSatisfiable();
  var end = b.isEmpty ? size - 1 : int.tryParse(b);
  if (end == null || end < start) throw const RangeNotSatisfiable();
  if (end >= size) end = size - 1;
  return ByteRange(start, end);
}

/// `Content-Disposition` with an ASCII fallback and an RFC 5987 `filename*`.
String contentDisposition(String name, {required bool inline}) {
  final fallback = name.replaceAll(RegExp(r'[^\x20-\x7e]|["\\%;]'), '_');
  final encoded = Uri.encodeComponent(name)
      .replaceAll("'", '%27')
      .replaceAll('(', '%28')
      .replaceAll(')', '%29')
      .replaceAll('*', '%2A');
  return '${inline ? 'inline' : 'attachment'}; filename="$fallback"; '
      "filename*=UTF-8''$encoded";
}

/// Host header values the web endpoints answer: an IPv4 or bracketed IPv6
/// literal, `localhost`, or an mDNS `.local` name, with an optional port.
/// Any other name can only reach this device through DNS rebinding.
bool validWebHost(String? host) {
  if (host == null || host.isEmpty || host.length > 255) return false;
  var h = host.toLowerCase();
  if (h.startsWith('[')) {
    final end = h.indexOf(']');
    if (end < 0) return false;
    final rest = h.substring(end + 1);
    if (rest.isNotEmpty && !RegExp(r'^:\d{1,5}$').hasMatch(rest)) return false;
    return InternetAddress.tryParse(h.substring(1, end))?.type ==
        InternetAddressType.IPv6;
  }
  final m = RegExp(r'^([^:]+)(:\d{1,5})?$').firstMatch(h);
  if (m == null) return false;
  h = m.group(1)!;
  if (h.endsWith('.')) h = h.substring(0, h.length - 1);
  if (h == 'localhost' || h.endsWith('.localhost')) return true;
  if (RegExp(r'^[a-z0-9-]+(\.[a-z0-9-]+)*\.local$').hasMatch(h)) return true;
  return RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(h) &&
      InternetAddress.tryParse(h) != null;
}

/// Short, fixed-vocabulary summary of a User-Agent ("Chrome on Android").
/// Never echoes the raw header, so it is safe to display anywhere.
String summarizeUserAgent(String? ua) {
  if (ua == null || ua.trim().isEmpty) return 'Unknown browser';
  final String b;
  if (ua.contains('Edg/') || ua.contains('EdgA/') || ua.contains('EdgiOS/')) {
    b = 'Edge';
  } else if (ua.contains('OPR/') || ua.contains('Opera')) {
    b = 'Opera';
  } else if (ua.contains('SamsungBrowser/')) {
    b = 'Samsung Internet';
  } else if (ua.contains('Firefox/') || ua.contains('FxiOS/')) {
    b = 'Firefox';
  } else if (ua.contains('CriOS/') || ua.contains('Chrome/')) {
    b = 'Chrome';
  } else if (ua.contains('Safari/')) {
    b = 'Safari';
  } else if (ua.startsWith('curl/')) {
    b = 'curl';
  } else if (ua.startsWith('Dart/') || ua.startsWith('LanDrop/')) {
    b = 'Dart client';
  } else {
    b = 'Browser';
  }
  final String? os;
  if (ua.contains('Android')) {
    os = 'Android';
  } else if (ua.contains('iPhone')) {
    os = 'iPhone';
  } else if (ua.contains('iPad')) {
    os = 'iPad';
  } else if (ua.contains('Windows')) {
    os = 'Windows';
  } else if (ua.contains('CrOS')) {
    os = 'ChromeOS';
  } else if (ua.contains('Macintosh') || ua.contains('Mac OS X')) {
    os = 'Mac';
  } else if (ua.contains('Linux')) {
    os = 'Linux';
  } else {
    os = null;
  }
  return os == null ? b : '$b on $os';
}

class _ShareFile {
  final String id;
  final String name;
  final String path;
  final int size;
  final String mime;
  _ShareFile(this.id, this.name, this.path, this.size, this.mime);
}

/// True when [path] is a real path: resolving symlinks gives [path] again.
bool _samePath(String path) {
  try {
    return File(path).resolveSymbolicLinksSync() == path &&
        FileSystemEntity.typeSync(path, followLinks: false) ==
            FileSystemEntityType.file;
  } catch (_) {
    return false;
  }
}

class _Share {
  final String id;
  final String token;
  final List<_ShareFile> files;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final int? maxDownloads;

  /// Downloads charged so far (see the counting rule on [WebService]).
  int downloads = 0;

  /// Full reads in flight; each holds one download slot until it ends.
  int inFlight = 0;

  /// `fileId|ip` -> last request of a charged range sequence.
  final Map<String, DateTime> windows = {};
  _Share(this.id, this.token, this.files, this.expiresAt, this.maxDownloads,
      {DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();

  /// Stored form (see [WebService.storePath]). Includes local paths, so the
  /// file is kept owner-only.
  Map<String, dynamic> toJson() => {
        'id': id,
        'token': token,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'expiresAt': expiresAt?.toUtc().toIso8601String(),
        'maxDownloads': maxDownloads,
        'downloadsLeft': downloadsLeft,
        'files': [
          for (final f in files)
            {
              'id': f.id,
              'name': f.name,
              'path': f.path,
              'size': f.size,
              'mime': f.mime,
            }
        ],
      };

  static final _tokenRe = RegExp(r'^[A-Za-z0-9_-]{16,64}$');

  /// A stored share, or null when it is malformed, expired, used up, or any
  /// of its files is gone or no longer has the stored size.
  static _Share? fromJson(Object? j, DateTime now) {
    if (j is! Map) return null;
    final id = j['id'];
    final token = j['token'];
    final rawFiles = j['files'];
    if (id is! String || token is! String || !_tokenRe.hasMatch(token)) {
      return null;
    }
    if (rawFiles is! List || rawFiles.isEmpty) return null;
    final exp = j['expiresAt'];
    DateTime? expiresAt;
    if (exp != null) {
      expiresAt = exp is String ? DateTime.tryParse(exp)?.toLocal() : null;
      if (expiresAt == null || !now.isBefore(expiresAt)) return null;
    }
    final maxRaw = j['maxDownloads'];
    final leftRaw = j['downloadsLeft'];
    int? maxDownloads;
    var used = 0;
    if (maxRaw != null) {
      if (maxRaw is! int || maxRaw < 1 || leftRaw is! int || leftRaw < 1) {
        return null;
      }
      maxDownloads = maxRaw;
      used = maxRaw - min(leftRaw, maxRaw);
    }
    final files = <_ShareFile>[];
    final ids = <String>{};
    for (final f in rawFiles) {
      if (f is! Map) return null;
      final fid = f['id'];
      final name = f['name'];
      final path = f['path'];
      final size = f['size'];
      final mime = f['mime'];
      if (fid is! String ||
          name is! String ||
          path is! String ||
          size is! int ||
          mime is! String ||
          !ids.add(fid)) {
        return null;
      }
      final st = File(path).statSync();
      if (st.type != FileSystemEntityType.file ||
          st.size != size ||
          !_samePath(path)) {
        return null;
      }
      files.add(_ShareFile(fid, name, path, size, mime));
    }
    final created = j['createdAt'];
    return _Share(id, token, files, expiresAt, maxDownloads,
        createdAt: created is String ? DateTime.tryParse(created)?.toLocal() : null)
      ..downloads = used;
  }

  bool expired(DateTime now) => expiresAt != null && !now.isBefore(expiresAt!);
  int? get downloadsLeft =>
      maxDownloads == null ? null : max(0, maxDownloads! - downloads);

  /// Slots a new client could still take.
  bool get available =>
      maxDownloads == null || maxDownloads! - downloads - inFlight > 0;
}

class _WebSession {
  final String id;
  final String token;
  final String ip;
  final String userAgent;
  DateTime expires;
  final DateTime pairedAt = DateTime.now();
  DateTime lastSeen = DateTime.now();
  _WebSession(this.id, this.token, this.ip, this.userAgent, this.expires);

  WebSessionInfo get info => WebSessionInfo(
      id: id,
      remoteIp: ip,
      userAgent: userAgent,
      pairedAt: pairedAt,
      lastSeen: lastSeen);
}

enum _PairState { pending, approved, declined, expired }

class _Pairing {
  final WebPairingRequest request;
  final DateTime created = DateTime.now();
  _PairState state = _PairState.pending;
  _WebSession? session;
  Timer? timer;
  Completer<void> changed = Completer<void>();
  _Pairing(this.request);
  String get ip => request.remoteIp;

  void set(_PairState s) {
    state = s;
    timer?.cancel();
    if (!changed.isCompleted) changed.complete();
  }
}

/// Serves the browser side of LanDrop.
///
/// Download counting rule (shares with a download limit; documented in
/// PROTOCOL.md too). A download is one client (remote IP) reading one file:
/// 1. A request for a file from an IP that has an open range sequence for
///    that file (last request less than [WebConfig.streamWindow] ago) is
///    served without charge and keeps the sequence open. This is what lets a
///    `<video>` element seek.
/// 2. Otherwise, when no download slot is left (charged + in-flight full
///    reads >= limit), the answer is the same 404 as for a wrong token.
/// 3. A partial range request (anything other than the whole file) is the
///    first request of a sequence: it is charged immediately and opens the
///    sequence. So reassembling a file from ranges always costs one download.
/// 4. A full read (no Range, or a Range covering byte 0 to the last byte)
///    reserves a slot while it runs and is charged only when every byte was
///    handed to the socket; an aborted full read releases its slot. A full
///    read does not open a sequence.
/// HEAD requests are never charged but get 404 like rule 2.
class WebService {
  WebService({
    required this.config,
    required this.selfInfo,
    required this.prepareUpload,
    required this.upload,
    this.onSessionEnded,
    this.storePath,
  }) : _httpEnabled = config.httpPort != null;

  /// JSON file the shares are kept in across restarts; null = memory only.
  /// Written atomically (temporary file + rename, owner-only where chmod
  /// exists) on every change; read once, on the first [start].
  final String? storePath;
  bool _persist = true;
  bool _restored = false;
  String? _lastSaved;

  final WebConfig config;
  final DeviceInfo Function() selfInfo;
  final WebPrepareUpload prepareUpload;
  final WebUpload upload;

  /// Core hook: a browser session ended (sign out or revoked); the core
  /// cancels a receive session it owns.
  final void Function(String sessionId)? onSessionEnded;

  final _pairCtrl = StreamController<WebPairingRequest>.broadcast();
  final _sharesCtrl = StreamController<List<Share>>.broadcast();
  final _sessionsCtrl = StreamController<List<WebSessionInfo>>.broadcast();

  final Map<String, _Share> _sharesByToken = {}; // by webTokenKey(token)
  final Map<String, _WebSession> _sessions = {}; // by webTokenKey(token)
  final Map<String, _Pairing> _pairings = {}; // by id
  final Map<String, List<DateTime>> _failures = {}; // by remote IP

  bool _running = false;
  bool _httpEnabled;
  GuardedHttpServer? _http;
  Timer? _pruneTimer;

  static final List<int> _pageBytes = utf8.encode(webPageHtml);

  Stream<WebPairingRequest> get pairing => _pairCtrl.stream;
  Stream<List<Share>> get sharesChanged => _sharesCtrl.stream;

  bool get httpEnabled => _httpEnabled;
  int? get httpPort => _http?.port;

  String? get webUrl {
    if (!_running) return null;
    final s = selfInfo();
    return 'https://${s.ip}:${s.port}/';
  }

  String? get httpUrl {
    final h = _http;
    if (!_running || h == null) return null;
    return 'http://${selfInfo().ip}:${h.port}/';
  }

  // ------------------------------------------------------------ lifecycle

  Future<void> start() async {
    if (!_restored) {
      _restored = true;
      if (_persist) _restore();
    }
    _running = true;
    _pruneTimer?.cancel();
    _pruneTimer = Timer.periodic(const Duration(seconds: 15), (_) => _prune());
    if (_httpEnabled) await _bindHttp();
    _emitShares();
  }

  Future<void> stop() async {
    _running = false;
    _pruneTimer?.cancel();
    _pruneTimer = null;
    await _closeHttp();
    for (final p in _pairings.values) {
      if (p.state == _PairState.pending) {
        p.set(_PairState.expired);
        if (!p.request.decision.isCompleted) p.request.decision.complete(false);
      }
    }
    _pairings.clear();
  }

  Future<void> dispose() async {
    await stop();
    await _pairCtrl.close();
    await _sharesCtrl.close();
    await _sessionsCtrl.close();
  }

  // ------------------------------------------------------------ sessions

  Stream<List<WebSessionInfo>> get sessionsChanged => _sessionsCtrl.stream;

  List<WebSessionInfo> get sessions {
    final now = DateTime.now();
    return [
      for (final s in _sessions.values)
        if (now.isBefore(s.expires)) s.info
    ]..sort((a, b) => a.pairedAt.compareTo(b.pairedAt));
  }

  /// True while the browser session [id] is valid.
  bool sessionActive(String id) {
    final now = DateTime.now();
    return _sessions.values.any((s) => s.id == id && now.isBefore(s.expires));
  }

  void _emitSessions() {
    if (!_sessionsCtrl.isClosed) _sessionsCtrl.add(sessions);
  }

  void revokeSession(String id) {
    final before = _sessions.length;
    _sessions.removeWhere((_, s) => s.id == id);
    if (_sessions.length == before) return;
    onSessionEnded?.call(id);
    _emitSessions();
  }

  Future<void> setHttpEnabled(bool on) async {
    _httpEnabled = on;
    if (!_running) return;
    if (on && _http == null) {
      await _bindHttp();
    } else if (!on) {
      await _closeHttp();
    }
    _emitShares(); // share URLs changed
  }

  Future<void> _bindHttp() async {
    final addr = config.bindAddress ?? InternetAddress.anyIPv4;
    GuardedHttpServer server;
    try {
      server = await bindGuarded(addr, config.httpPort ?? defaultWebHttpPort,
          limits: config.serverLimits);
    } on SocketException {
      server = await bindGuarded(addr, 0, limits: config.serverLimits);
    }
    _http = server;
    server.http.listen((req) async {
      if (handles(req.uri.path)) {
        await handle(req, secure: false);
      } else {
        // Never the device API (LocalSend endpoints) on plain HTTP.
        await _drainQuietly(req);
        setWebSecurityHeaders(req.response.headers);
        _json(req.response, 404, const {'message': 'not found'});
      }
    }, onError: (_) {});
  }

  Future<void> _closeHttp() async {
    final h = _http;
    _http = null;
    await h?.close(force: true);
  }

  void _prune() {
    final now = DateTime.now();
    final before = _sharesByToken.length;
    _sharesByToken.removeWhere((_, s) => s.expired(now));
    for (final s in _sharesByToken.values) {
      s.windows.removeWhere(
          (_, t) => now.difference(t) >= config.streamWindow);
    }
    if (_sharesByToken.length != before) _emitShares();
    final sessionsBefore = _sessions.length;
    _sessions.removeWhere((_, s) => !now.isBefore(s.expires));
    if (_sessions.length != sessionsBefore) _emitSessions();
    _pairings.removeWhere((_, p) =>
        p.state != _PairState.pending &&
        now.difference(p.created) > config.pairingTimeout * 2);
    _failures.removeWhere((_, l) {
      l.removeWhere((t) => now.difference(t) >= config.rateWindow);
      return l.isEmpty;
    });
  }

  // ------------------------------------------------------------ shares

  List<Share> get shares {
    final now = DateTime.now();
    return [
      for (final s in _sharesByToken.values)
        if (!s.expired(now)) _snapshot(s)
    ];
  }

  Share _snapshot(_Share s) {
    final self = selfInfo();
    final h = _http;
    return Share(
      id: s.id,
      token: s.token,
      files: [
        for (final f in s.files) SharedFile(f.id, f.name, f.size, f.mime)
      ],
      url: 'https://${self.ip}:${self.port}/#s=${s.token}',
      httpUrl: h == null ? null : 'http://${self.ip}:${h.port}/#s=${s.token}',
      createdAt: s.createdAt,
      expiresAt: s.expiresAt,
      maxDownloads: s.maxDownloads,
      downloadsLeft: s.downloadsLeft,
    );
  }

  void _emitShares() {
    _save();
    if (!_sharesCtrl.isClosed) _sharesCtrl.add(shares);
  }

  // ------------------------------------------------------------ share store

  bool get persistence => _persist;

  /// Off: the stored file is deleted and nothing is written any more. On:
  /// the current shares are written (after the first start has read the
  /// file, so an earlier store is never overwritten unread).
  void setPersistence(bool on) {
    _persist = on;
    final p = storePath;
    if (p == null) return;
    if (on) {
      _save();
      return;
    }
    _restored = true; // nothing left to read
    _lastSaved = null;
    for (final f in [File(p), File('$p.tmp')]) {
      try {
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
  }

  void _restore() {
    final p = storePath;
    if (p == null) return;
    Object? data;
    try {
      final f = File(p);
      if (!f.existsSync()) return;
      data = jsonDecode(f.readAsStringSync());
    } catch (e) {
      // Corrupt or unreadable: start without shares; the next save replaces
      // the file.
      // Only the error type: a parse error quotes the file, which holds
      // share tokens and local paths (SECURITY.md S16).
      stderr.writeln('LanDrop: ignoring unreadable share store '
          '(${e.runtimeType})');
      return;
    }
    final list = data is Map ? data['shares'] : null;
    if (list is! List) return;
    final now = DateTime.now();
    for (final j in list) {
      try {
        final s = _Share.fromJson(j, now);
        if (s != null && !_sharesByToken.containsKey(webTokenKey(s.token))) {
          _sharesByToken[webTokenKey(s.token)] = s;
        }
      } catch (_) {
        // one bad entry never blocks the others
      }
    }
  }

  void _save() {
    final p = storePath;
    if (p == null || !_persist || !_restored) return;
    final now = DateTime.now();
    final json = jsonEncode({
      'v': 1,
      'shares': [
        for (final s in _sharesByToken.values)
          if (!s.expired(now) && s.downloadsLeft != 0) s.toJson()
      ],
    });
    if (json == _lastSaved) return;
    final tmp = File('$p.tmp');
    try {
      tmp.parent.createSync(recursive: true);
      tmp.writeAsStringSync(''); // create (or truncate), then restrict
      _ownerOnly(tmp.path);
      tmp.writeAsStringSync(json, flush: true);
      tmp.renameSync(p); // atomic replace; keeps the temp file's mode
      _lastSaved = json;
    } catch (e) {
      stderr.writeln('LanDrop: could not save shares (${e.runtimeType})');
    }
  }

  /// chmod 600 where a chmod binary exists (dart:io cannot set modes).
  /// Elsewhere (Windows, iOS) the app data directory is already per user.
  static void _ownerOnly(String path) {
    if (!(Platform.isLinux || Platform.isMacOS || Platform.isAndroid)) return;
    try {
      Process.runSync('chmod', ['600', path]);
    } catch (_) {}
  }

  static String _baseName(String path) => path
      .split(RegExp(r'[\\/]'))
      .lastWhere((s) => s.isNotEmpty, orElse: () => 'file');

  Share createShare(List<String> paths, {Duration? ttl, int? maxDownloads}) {
    if (!_running) throw StateError('core not started');
    if (maxDownloads != null && maxDownloads < 1) {
      throw ArgumentError.value(maxDownloads, 'maxDownloads');
    }
    if (ttl != null && ttl <= Duration.zero) {
      throw ArgumentError.value(ttl, 'ttl');
    }
    final files = <_ShareFile>[];
    final ids = <String>{};
    void add(File f, String name) {
      final st = f.statSync();
      if (st.type != FileSystemEntityType.file) return;
      String id;
      do {
        id = randomHex(8);
      } while (!ids.add(id));
      // The real path (symlinks resolved) is kept; serving checks that it
      // still is one, so a file swapped for a symlink later is refused
      // (SECURITY.md S12).
      files.add(_ShareFile(
          id, name, f.resolveSymbolicLinksSync(), st.size, guessMime(name)));
    }

    for (final p in paths) {
      final type = FileSystemEntity.typeSync(p);
      if (type == FileSystemEntityType.directory) {
        final root =
            Directory(p).absolute.path.replaceAll(RegExp(r'[\\/]+$'), '');
        final top = _baseName(root);
        // Symlinks are not followed, so a share never reaches outside the
        // chosen folder.
        final entries = Directory(root)
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
        for (final f in entries) {
          final rel = f.path.substring(root.length + 1).replaceAll('\\', '/');
          add(f, '$top/$rel');
        }
      } else if (type == FileSystemEntityType.file) {
        add(File(p), _baseName(p));
      } else {
        throw ArgumentError('not a file or folder: $p');
      }
    }
    if (files.isEmpty) throw ArgumentError('nothing to share');
    final s = _Share(randomHex(8), randomToken(16), files,
        ttl == null ? null : DateTime.now().add(ttl), maxDownloads);
    _sharesByToken[webTokenKey(s.token)] = s;
    _emitShares();
    return _snapshot(s);
  }

  void revokeShare(String id) {
    final before = _sharesByToken.length;
    _sharesByToken.removeWhere((_, s) => s.id == id);
    if (_sharesByToken.length != before) _emitShares();
  }

  /// Unknown, expired and revoked look the same (null).
  _Share? _liveShare(String token) {
    if (token.length > 128) return null;
    final key = webTokenKey(token);
    final s = _sharesByToken[key];
    if (s == null) return null;
    if (s.expired(DateTime.now())) {
      _sharesByToken.remove(key);
      _emitShares();
      return null;
    }
    return s;
  }

  // ------------------------------------------------------------ rate limit

  bool _limited(String ip) {
    final l = _failures[ip];
    if (l == null) return false;
    final now = DateTime.now();
    l.removeWhere((t) => now.difference(t) >= config.rateWindow);
    if (l.isEmpty) {
      _failures.remove(ip);
      return false;
    }
    return l.length >= config.rateLimit;
  }

  void _fail(String ip) {
    final l = _failures[ip] ??= [];
    l.add(DateTime.now());
    if (l.length > config.rateLimit * 2) l.removeAt(0);
  }

  // ------------------------------------------------------------ HTTP

  /// Paths served by [handle] (on both the HTTPS server and the HTTP
  /// listener).
  bool handles(String path) =>
      path == '/' ||
      path == '/index.html' ||
      path.startsWith('$webApiBase/web/') ||
      path.startsWith('$webApiBase/shares/');

  static String _remoteIp(HttpRequest req) =>
      req.connectionInfo?.remoteAddress.address ?? '0.0.0.0';

  /// A state-changing request from a browser must come from our own page:
  /// when an Origin header is present, its host:port must equal Host.
  static bool _sameOrigin(HttpRequest req) {
    // Fetch metadata: browsers say whether the request comes from another
    // site; only our own page (same-origin) or a direct navigation/tool
    // (no header, `none`) may change state.
    final site = req.headers.value('sec-fetch-site');
    if (site != null && site != 'same-origin' && site != 'none') return false;
    final origin = req.headers.value('origin');
    if (origin == null) return true; // non-browser client
    final host = req.headers.value(HttpHeaders.hostHeader);
    final o = Uri.tryParse(origin);
    if (host == null || o == null || !o.hasAuthority) return false;
    return o.authority.toLowerCase() == host.toLowerCase();
  }

  Future<void> handle(HttpRequest req, {required bool secure}) async {
    final res = req.response;
    final ip = _remoteIp(req);
    final path = req.uri.path;
    final m = req.method;
    var bodyRead = false;
    try {
      setWebSecurityHeaders(res.headers);
      // DNS rebinding: a page served from a host name that resolves to this
      // device would otherwise be same-origin with the API (SECURITY.md S2).
      if (!validWebHost(req.headers.value(HttpHeaders.hostHeader))) {
        throw HttpStatusError(421, 'unknown host');
      }
      if (path == '/' || path == '/index.html') {
        await drainBounded(req);
        bodyRead = true;
        if (m != 'GET' && m != 'HEAD') {
          throw HttpStatusError(405, 'method not allowed');
        }
        res.statusCode = 200;
        res.headers.contentType = ContentType.html;
        res.contentLength = _pageBytes.length;
        if (m != 'HEAD') res.add(_pageBytes);
        await res.close();
        return;
      }
      if (_limited(ip)) throw HttpStatusError(429, 'too many attempts');
      if (m != 'GET' && m != 'HEAD' && !_sameOrigin(req)) {
        throw HttpStatusError(403, 'cross-origin request');
      }
      final segs = req.uri.pathSegments;
      // ['api', 'landrop', 'v1', ...rest]
      final rest = segs.length > 3 ? segs.sublist(3) : const <String>[];
      final get = m == 'GET';
      switch (rest) {
        case ['web', 'info'] when get:
          await drainBounded(req);
          bodyRead = true;
          _json(res, 200, {'alias': selfInfo().alias});
        case ['web', 'session'] when get:
          await drainBounded(req);
          bodyRead = true;
          final s = _sessionOf(req, ip);
          if (s == null) throw HttpStatusError(401, 'not paired');
          _json(res, 200, {
            'paired': true,
            'expiresIn': s.expires.difference(DateTime.now()).inSeconds,
          });
        case ['web', 'logout'] when m == 'POST':
          await drainBounded(req);
          bodyRead = true;
          _logout(req, ip, secure: secure);
        case ['web', 'pair'] when m == 'POST':
          await drainBounded(req);
          bodyRead = true;
          _pair(req, ip);
        case ['web', 'pair', final id] when get:
          await drainBounded(req);
          bodyRead = true;
          await _pairStatus(req, ip, id, secure: secure);
        case ['web', 'upload-prepare'] when m == 'POST':
          final s = _sessionOf(req, ip);
          if (s == null) {
            _fail(ip);
            throw HttpStatusError(401, 'not paired');
          }
          bodyRead = true;
          await _prepare(req, ip, s);
        case ['web', 'upload'] when m == 'POST':
          final s = _sessionOf(req, ip);
          if (s == null) {
            _fail(ip);
            throw HttpStatusError(401, 'not paired');
          }
          bodyRead = true; // the core's upload handler consumes the body
          await upload(req, s.id);
        case ['shares', final token] when get:
          await drainBounded(req);
          bodyRead = true;
          _listing(res, ip, token);
        case ['shares', final token, 'files', final fileId]
            when get || m == 'HEAD':
          await drainBounded(req);
          bodyRead = true;
          await _file(req, ip, token, fileId, head: m == 'HEAD');
        default:
          throw HttpStatusError(404, 'not found');
      }
    } on HttpStatusError catch (e) {
      if (e.status == 408 || e.status == 413) {
        res.persistentConnection = false; // body not (fully) read
      } else if (!bodyRead) {
        await _drainQuietly(req);
      }
      _json(res, e.status, {'message': e.message, ...?e.extra});
    } catch (_) {
      if (!bodyRead) await _drainQuietly(req);
      _json(res, 500, const {'message': 'internal error'});
    }
  }

  /// Discards an unread body (at most 64 MB within 60 s); a larger or
  /// slower one closes the connection instead.
  static Future<void> _drainQuietly(HttpRequest req) async {
    try {
      await drainBounded(req,
          max: 64 << 20, timeout: const Duration(seconds: 60));
    } catch (_) {
      req.response.persistentConnection = false;
    }
  }

  static void _json(HttpResponse res, int status, Map<String, dynamic> body) {
    try {
      final bytes = utf8.encode(jsonEncode(body));
      res.statusCode = status;
      res.headers.contentType = ContentType.json;
      res.contentLength = bytes.length;
      res.add(bytes);
      res.close().catchError((_) {});
    } catch (_) {
      // headers already sent / connection gone
    }
  }

  static Future<Map<String, dynamic>> _readJson(HttpRequest req,
      {int max = 1 << 20}) async {
    final bytes = await readBodyBounded(req, max: max);
    try {
      final v = jsonDecode(utf8.decode(bytes));
      if (v is Map<String, dynamic>) return v;
    } on FormatException {
      // fall through
    }
    throw HttpStatusError(400, 'expected a JSON object');
  }

  // ------------------------------------------------------------ sessions

  _WebSession? _sessionOf(HttpRequest req, String ip) {
    String? token;
    final auth = req.headers.value(HttpHeaders.authorizationHeader);
    if (auth != null && auth.startsWith('Bearer ')) {
      token = auth.substring(7).trim();
    }
    token ??= _cookie(req, webSessionCookie);
    if (token == null || token.isEmpty || token.length > 256) return null;
    final key = webTokenKey(token);
    final s = _sessions[key];
    if (s == null) return null;
    final now = DateTime.now();
    if (!now.isBefore(s.expires)) {
      _sessions.remove(key);
      _emitSessions();
      return null;
    }
    // Bound to the browser's address: a token copied off the (plain HTTP)
    // network is useless from another device.
    if (s.ip != ip) return null;
    final quiet = now.difference(s.lastSeen) >= const Duration(seconds: 30);
    s.lastSeen = now;
    if (quiet) _emitSessions(); // not on every request
    return s;
  }

  /// POST web/logout: ends the caller's session (if any) and clears the
  /// cookie. Always 200, so it is safe to call twice.
  void _logout(HttpRequest req, String ip, {required bool secure}) {
    final s = _sessionOf(req, ip);
    if (s != null) revokeSession(s.id);
    req.response.headers.add(
        HttpHeaders.setCookieHeader,
        '$webSessionCookie=; Max-Age=0; Path=/; HttpOnly; '
        'SameSite=Strict${secure ? '; Secure' : ''}');
    _json(req.response, 200, {'paired': false});
  }

  static String? _cookie(HttpRequest req, String name) {
    for (final h in req.headers[HttpHeaders.cookieHeader] ?? const []) {
      for (final part in h.split(';')) {
        final i = part.indexOf('=');
        if (i > 0 && part.substring(0, i).trim() == name) {
          return part.substring(i + 1).trim();
        }
      }
    }
    return null;
  }

  // ------------------------------------------------------------ pairing

  void _pair(HttpRequest req, String ip) {
    // Every attempt counts toward the per-IP limit (pairing is rare).
    _fail(ip);
    final pending =
        _pairings.values.where((p) => p.state == _PairState.pending);
    if (pending.any((p) => p.ip == ip)) {
      throw HttpStatusError(409, 'a pairing from this address is waiting');
    }
    if (pending.length >= config.maxPendingPairings) {
      throw HttpStatusError(429, 'too many pairings waiting');
    }
    if (!_pairCtrl.hasListener) throw HttpStatusError(403, 'declined');
    final r = WebPairingRequest(randomToken(16), randomDigits(4),
        summarizeUserAgent(req.headers.value(HttpHeaders.userAgentHeader)), ip);
    final p = _Pairing(r);
    _pairings[r.id] = p;
    p.timer = Timer(config.pairingTimeout, () {
      if (p.state != _PairState.pending) return;
      p.set(_PairState.expired);
      _fail(ip);
      if (!r.decision.isCompleted) r.decision.complete(false);
    });
    r.decision.future.then((ok) {
      if (p.state != _PairState.pending) return;
      if (ok && _running) {
        final token = randomToken(32);
        final s = _WebSession(randomHex(8), token, ip, r.userAgent,
            DateTime.now().add(config.sessionTtl));
        _sessions[webTokenKey(token)] = s;
        p.session = s;
        p.set(_PairState.approved);
        _emitSessions();
      } else {
        _fail(ip);
        p.set(_PairState.declined);
      }
    });
    _pairCtrl.add(r);
    _json(req.response, 200, {
      'id': r.id,
      'code': r.code,
      'expiresIn': config.pairingTimeout.inSeconds,
    });
  }

  /// Long poll (up to 20 s) for the owner's decision on pairing [id].
  Future<void> _pairStatus(HttpRequest req, String ip, String id,
      {required bool secure}) async {
    final p = _pairings[id];
    if (p == null || p.ip != ip) {
      _fail(ip);
      throw HttpStatusError(404, 'not found');
    }
    if (p.state == _PairState.pending) {
      final wait = Completer<void>();
      final t = Timer(const Duration(seconds: 20), () {
        if (!wait.isCompleted) wait.complete();
      });
      unawaited(p.changed.future.then((_) {
        if (!wait.isCompleted) wait.complete();
      }));
      await wait.future;
      t.cancel();
    }
    switch (p.state) {
      case _PairState.pending:
        _json(req.response, 200, {'status': 'pending'});
      case _PairState.approved:
        _pairings.remove(id); // the token is handed out once
        final s = p.session!;
        // The lifetime starts when the browser gets the token.
        s.expires = DateTime.now().add(config.sessionTtl);
        final ttl = config.sessionTtl.inSeconds;
        req.response.headers.add(
            HttpHeaders.setCookieHeader,
            '$webSessionCookie=${s.token}; Max-Age=$ttl; Path=/; HttpOnly; '
            'SameSite=Strict${secure ? '; Secure' : ''}');
        _json(req.response, 200,
            {'status': 'approved', 'token': s.token, 'expiresIn': ttl});
      case _PairState.declined:
        _pairings.remove(id);
        throw HttpStatusError(403, 'declined', {'status': 'declined'});
      case _PairState.expired:
        _pairings.remove(id);
        throw HttpStatusError(403, 'expired', {'status': 'expired'});
    }
  }

  // ------------------------------------------------------------ uploads

  Future<void> _prepare(HttpRequest req, String ip, _WebSession s) async {
    final body = await _readJson(req, max: 16 << 20);
    final list = body['files'];
    if (list is! List || list.isEmpty || list.length > 10000) {
      throw HttpStatusError(400, 'invalid file list');
    }
    final files = <String, dynamic>{};
    for (final f in list) {
      if (f is! Map) throw HttpStatusError(400, 'invalid file');
      final id = f['id'];
      if (id is! String ||
          id.isEmpty ||
          id.length > 64 ||
          files.containsKey(id)) {
        throw HttpStatusError(400, 'invalid file id');
      }
      files[id] = {
        'id': id,
        'fileName': f['fileName'],
        'size': f['size'],
        'fileType': f['fileType'],
      };
    }
    final sender = DeviceInfo(
      alias: 'Browser $ip',
      deviceType: 'web',
      deviceModel: s.userAgent,
      fingerprint: '',
      ip: ip,
      port: 0,
    );
    await prepareUpload(req, sender, files, s.id);
  }

  // ------------------------------------------------------------ share HTTP

  static final _notFound = HttpStatusError(404, 'not found');

  void _listing(HttpResponse res, String ip, String token) {
    final s = _liveShare(token);
    if (s == null || !s.available) {
      _fail(ip);
      throw _notFound;
    }
    final now = DateTime.now();
    _json(res, 200, {
      'alias': selfInfo().alias,
      'files': [
        for (final f in s.files)
          {'id': f.id, 'name': f.name, 'size': f.size, 'mime': f.mime}
      ],
      'expiresAt': s.expiresAt?.toUtc().toIso8601String(),
      'expiresIn': s.expiresAt?.difference(now).inSeconds,
      'maxDownloads': s.maxDownloads,
      'downloadsLeft': s.downloadsLeft,
    });
  }

  Future<void> _file(HttpRequest req, String ip, String token, String fileId,
      {required bool head}) async {
    final res = req.response;
    final s = _liveShare(token);
    final f = s?.files.where((x) => x.id == fileId).firstOrNull;
    if (s == null || f == null) {
      _fail(ip);
      throw _notFound;
    }
    // The file must still be the one that was shared, at the same real
    // path (no symlink put in its place or in a parent).
    final st = await File(f.path).stat();
    if (st.type != FileSystemEntityType.file ||
        st.size != f.size ||
        !_samePath(f.path)) {
      throw _notFound;
    }
    ByteRange? range;
    try {
      range = parseRange(req.headers.value(HttpHeaders.rangeHeader), f.size);
    } on RangeNotSatisfiable {
      res.headers.set(HttpHeaders.contentRangeHeader, 'bytes */${f.size}');
      res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      throw HttpStatusError(416, 'range not satisfiable');
    }
    final whole = range == null || (range.start == 0 && range.end == f.size - 1);

    // Download counting rule: see the class comment.
    var reserved = false;
    if (s.maxDownloads != null) {
      final now = DateTime.now();
      final key = '$fileId|$ip';
      final last = s.windows[key];
      if (last != null && now.difference(last) < config.streamWindow) {
        s.windows[key] = now; // rule 1
      } else if (!s.available) {
        _fail(ip);
        throw _notFound; // rule 2
      } else if (head) {
        // never charged
      } else if (!whole) {
        s.downloads++; // rule 3
        s.windows[key] = now;
        _emitShares();
      } else {
        s.inFlight++; // rule 4
        reserved = true;
      }
    }

    final start = range?.start ?? 0;
    final len = range?.length ?? f.size;
    final inline = req.uri.queryParameters['inline'] == '1' &&
        isInlineSafeMime(f.mime);
    final h = res.headers;
    res.statusCode = range == null ? 200 : 206;
    h.set(HttpHeaders.acceptRangesHeader, 'bytes');
    if (range != null) {
      h.set(HttpHeaders.contentRangeHeader, 'bytes $range/${f.size}');
    }
    h.set(HttpHeaders.contentTypeHeader,
        f.mime.startsWith('text/') ? '${f.mime}; charset=utf-8' : f.mime);
    h.set('Content-Disposition', contentDisposition(_baseName(f.name), inline: inline));
    res.contentLength = len;

    var sent = 0;
    var completed = false;
    try {
      if (!head && len > 0) {
        // Streamed from disk with backpressure; never buffered whole.
        await res.addStream(File(f.path).openRead(start, start + len).map((c) {
          sent += c.length;
          return c;
        }));
      }
      await res.close();
      completed = sent == len || head;
    } catch (_) {
      // client went away or the file changed under us
      try {
        await res.close();
      } catch (_) {}
    } finally {
      if (reserved) {
        s.inFlight--;
        if (completed && !head) {
          s.downloads++;
          _emitShares();
        }
      }
    }
  }
}
