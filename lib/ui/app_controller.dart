import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../core/api.dart';
import 'background_service.dart';
import 'hotspot_service.dart';
import 'multicast_lock.dart';
import 'storage_access.dart';

/// Persists alias + save directory. The default implementation writes a small
/// JSON file in the application support directory.
class SettingsStore {
  const SettingsStore();

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}landrop_settings.json');
  }

  /// The share store next to the settings file
  /// (`LanDropCoreOptions.sharesStorePath`); null when there is no app
  /// support directory.
  static Future<String?> sharesPath() async {
    try {
      final dir = await getApplicationSupportDirectory();
      return '${dir.path}${Platform.pathSeparator}landrop_shares.json';
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        return (jsonDecode(await f.readAsString()) as Map)
            .cast<String, dynamic>();
      }
    } catch (_) {}
    return {};
  }

  Future<void> save(Map<String, dynamic> data) async {
    try {
      final f = await _file();
      await f.parent.create(recursive: true);
      await f.writeAsString(jsonEncode(data));
    } catch (_) {}
  }
}

/// Non-persistent store (tests).
class MemorySettingsStore extends SettingsStore {
  MemorySettingsStore([Map<String, dynamic>? initial])
      : stored = {...?initial};
  final Map<String, dynamic> stored;
  @override
  Future<Map<String, dynamic>> load() async => {...stored};
  @override
  Future<void> save(Map<String, dynamic> data) async => stored
    ..clear()
    ..addAll(data);
}

class FileTransfer {
  FileTransfer(this.fileId, this.name, this.total);
  final String fileId;
  String name;
  int total;
  int sent = 0;
  bool done = false;
  String? error;

  double get fraction => total <= 0 ? (done ? 1 : 0) : (sent / total).clamp(0, 1);
}

class TransferSession {
  TransferSession({
    required this.sessionId,
    required this.incoming,
    required this.peerAlias,
    this.savedTo,
  });

  String sessionId;
  final bool incoming;
  final String peerAlias;
  final String? savedTo;
  final Map<String, FileTransfer> files = {};
  final DateTime started = DateTime.now();

  bool? result; // outgoing: send() result
  String? error; // outgoing: why send() failed

  /// Incoming: every file finished. Outgoing: send() returned (files appear
  /// one at a time as the core starts them, so they cannot tell).
  bool get done => incoming
      ? files.isNotEmpty &&
          files.values.every((f) => f.done || f.error != null)
      : result != null;
  bool get hasError => files.values.any((f) => f.error != null);
}

enum CoreStatus { stopped, starting, running, error }

/// Receives the number of active shares and connected browsers.
typedef StatusNotifier = Future<void> Function(int shares, int browsers);

/// App-level controller wrapping a [LanDropCore].
class AppController extends ChangeNotifier {
  AppController({
    required this.core,
    SettingsStore? store,
    String? initialSaveDir,
    String? initialAlias,
    StatusNotifier? statusNotifier,
    HotspotService? hotspotService,
    this.hotspotSettleDelay = const Duration(seconds: 1),
  })  : _store = store ?? const SettingsStore(),
        _saveDir = initialSaveDir ?? '',
        _alias = initialAlias ?? _defaultAlias(),
        _statusNotifier = statusNotifier ?? _defaultStatusNotifier,
        hotspotService = hotspotService ?? HotspotService();

  final LanDropCore core;
  final SettingsStore _store;

  /// Android local-only hotspot (test seam).
  final HotspotService hotspotService;

  /// Wait after the hotspot started before re-reading the interfaces (the
  /// hotspot interface gets its address a moment later).
  final Duration hotspotSettleDelay;

  /// The hotspot this device shares, while it does.
  HotspotCredentials? hotspot;
  bool hotspotStarting = false;
  String? hotspotError;

  /// Shows the counts in the Android service notification (test seam).
  final StatusNotifier _statusNotifier;
  static Future<void> _defaultStatusNotifier(int shares, int browsers) =>
      BackgroundService.update(shares: shares, browsers: browsers);
  (int, int)? _lastStatus;

  String _alias;
  String _saveDir;
  bool _background = true; // Android foreground service on/off
  bool _customDir = false; // user picked a folder; only then is it persisted
  bool _webHttp = false; // plain HTTP listener for browsers (opt-in)
  bool _keepShares = true; // shares survive a restart (opt-out)
  CoreStatus status = CoreStatus.stopped;
  String? lastError;
  List<DeviceInfo> peers = const [];
  final List<TransferSession> sessions = [];
  bool scanning = false;
  String? _fallbackIp;
  bool _disposed = false;

  final _incomingCtrl = StreamController<IncomingRequest>.broadcast();
  final _pairingCtrl = StreamController<WebPairingRequest>.broadcast();

  /// Active shares (DESIGN.md 4.2 mode 2), newest last.
  List<Share> shares = const [];

  /// Paired browsers (DESIGN.md 4.5), oldest first.
  List<WebSessionInfo> webSessions = const [];
  final List<StreamSubscription<dynamic>> _subs = [];

  /// Progress for sessions not (yet) known here, latest event per file.
  /// Applied when a send learns its session id or a request is accepted.
  final Map<String, Map<String, TransferProgress>> _orphans = {};
  bool _discoveryErrorDismissed = false;

  String get alias => _alias;
  String get saveDir => _saveDir;
  bool get background => _background;
  Stream<IncomingRequest> get incomingRequests => _incomingCtrl.stream;

  /// Browsers asking to be paired, to approve or decline in the UI.
  Stream<WebPairingRequest> get pairingRequests => _pairingCtrl.stream;

  DeviceInfo? get self {
    if (status != CoreStatus.running) return null;
    try {
      return core.self;
    } catch (_) {
      return null;
    }
  }

  /// Best displayable IP for this device.
  String? get selfIp {
    final ip = self?.ip;
    if (ip != null && ip.isNotEmpty && ip != '0.0.0.0') return ip;
    return _fallbackIp;
  }

  int get selfPort => self?.port ?? 53317;

  /// Why automatic discovery is not running (null when fine or dismissed).
  String? get discoveryError {
    if (_discoveryErrorDismissed || status != CoreStatus.running) return null;
    try {
      return core.discoveryError;
    } catch (_) {
      return null;
    }
  }

  void dismissDiscoveryError() {
    _discoveryErrorDismissed = true;
    _notify();
  }

  String? get selfUrl => selfIp == null ? null : 'https://$selfIp:$selfPort';

  /// Address of the web page (`https://ip:port/`), when running.
  String? get webUrl => _guard(() => core.webUrl);

  /// Plain HTTP address of the web page, while that listener runs.
  String? get webHttpUrl => _guard(() => core.webHttpUrl);

  /// The user's choice for the plain HTTP listener (persisted).
  bool get webHttpEnabled => _webHttp;

  /// "Keep shares after restart" (persisted, default on).
  bool get keepShares => _keepShares;

  String? _guard(String? Function() f) {
    if (status != CoreStatus.running) return null;
    try {
      return f();
    } catch (_) {
      return null;
    }
  }

  /// One entry per fingerprint (a device seen at several addresses is one
  /// device; the core already merges them, this keeps the UI safe).
  static List<DeviceInfo> _oneEntryPerDevice(List<DeviceInfo> list) {
    final seen = <String>{};
    return [
      for (final d in list)
        if (d.fingerprint.isEmpty || seen.add(d.fingerprint)) d
    ];
  }

  static String _defaultAlias() {
    try {
      final h = Platform.localHostname;
      if (h.isNotEmpty && h != 'localhost') return h.split('.').first;
    } catch (_) {}
    return 'LanDrop device';
  }

  static Future<String> defaultSaveDir() async {
    if (Platform.isAndroid) {
      // Visible in the Files app: Downloads/LanDrop.
      if (await ensureStorageAccess()) {
        try {
          await Directory(androidPublicDir).create(recursive: true);
          return androidPublicDir;
        } catch (_) {}
      }
      try {
        final d = await getExternalStorageDirectory();
        if (d != null) return d.path;
      } catch (_) {}
    }
    try {
      final d = await getDownloadsDirectory();
      if (d != null) return d.path;
    } catch (_) {}
    final d = await getApplicationDocumentsDirectory();
    return d.path;
  }

  /// Load settings, subscribe to core streams and start the core.
  Future<void> init() async {
    _subs.add(core.peers.listen((p) {
      peers = _oneEntryPerDevice(p);
      _notify();
    }));
    _subs.add(core.incoming.listen(_incomingCtrl.add));
    _subs.add(core.progress.listen(_onProgress));
    _subs.add(core.webPairing.listen(_pairingCtrl.add));
    // Events arrive asynchronously and may be older than what createShare /
    // revoke already applied, so the current lists are read instead.
    _subs.add(core.sharesChanged.listen((_) {
      shares = core.shares;
      _notify();
    }));
    _subs.add(core.webSessionsChanged.listen((_) {
      webSessions = core.webSessions;
      _notify();
    }));

    final s = await _store.load();
    if (s['alias'] is String && (s['alias'] as String).trim().isNotEmpty) {
      _alias = s['alias'] as String;
    }
    if (s['background'] is bool) _background = s['background'] as bool;
    if (s['webHttp'] is bool) _webHttp = s['webHttp'] as bool;
    if (s['keepShares'] is bool) _keepShares = s['keepShares'] as bool;
    if (s['saveDir'] is String && (s['saveDir'] as String).isNotEmpty) {
      _saveDir = s['saveDir'] as String;
      _customDir = true;
    }
    if (_saveDir.isEmpty) {
      try {
        _saveDir = await defaultSaveDir();
      } catch (e) {
        _saveDir = Directory.systemTemp.path;
      }
    }
    await _start();
  }

  Future<void> _start() async {
    status = CoreStatus.starting;
    lastError = null;
    _discoveryErrorDismissed = false;
    _notify();
    try {
      await MulticastLock.acquire();
      if (_background) await BackgroundService.start();
      // Before start: when off, the stored shares are deleted, not restored.
      core.setSharesPersistence(_keepShares);
      await core.start(alias: _alias, saveDir: _saveDir);
      status = CoreStatus.running;
      shares = core.shares;
      webSessions = core.webSessions;
      if (_webHttp && !core.webHttpEnabled) {
        try {
          await core.setWebHttpEnabled(true);
        } catch (e) {
          lastError = 'Plain HTTP for browsers could not start: $e';
        }
      }
    } catch (e) {
      status = CoreStatus.error;
      lastError = '$e';
    }
    _notify();
    final ip = self?.ip;
    if (status == CoreStatus.running && (ip == null || ip.isEmpty || ip == '0.0.0.0')) {
      try {
        _fallbackIp = await NetworkInfo().getWifiIP();
        _notify();
      } catch (_) {}
    }
  }

  Future<void> restart() async {
    try {
      await core.stop();
    } catch (_) {}
    await _start();
  }

  Future<void> updateSettings({String? alias, String? saveDir}) async {
    final a = alias?.trim();
    final changed = (a != null && a.isNotEmpty && a != _alias) ||
        (saveDir != null && saveDir.isNotEmpty && saveDir != _saveDir);
    if (!changed) return;
    if (a != null && a.isNotEmpty) _alias = a;
    if (saveDir != null && saveDir.isNotEmpty && saveDir != _saveDir) {
      await ensureStorageAccess();
      _saveDir = saveDir;
      _customDir = true;
    }
    await _persist();
    _notify();
    if (status != CoreStatus.stopped) await restart();
  }

  /// Forget the custom folder and go back to the platform default.
  Future<void> resetSaveDir() async {
    _customDir = false;
    _saveDir = await defaultSaveDir();
    await _persist();
    _notify();
    if (status != CoreStatus.stopped) await restart();
  }

  /// Android: keep the server reachable while the app is in the background.
  Future<void> setBackground(bool on) async {
    if (on == _background) return;
    _background = on;
    await _persist();
    if (on) {
      await BackgroundService.start();
    } else {
      await BackgroundService.stop();
    }
    _lastStatus = null; // send the counts to a (re)started service
    _notify();
  }

  /// Stop the server and the background service, then close the app.
  Future<void> quit() async {
    try {
      await core.stop();
    } catch (_) {}
    await MulticastLock.release();
    await BackgroundService.stop();
    SystemNavigator.pop();
  }

  /// Turns the plain HTTP listener for browsers on or off (persisted).
  Future<void> setWebHttp(bool on) async {
    if (status == CoreStatus.running) await core.setWebHttpEnabled(on);
    _webHttp = on;
    await _persist();
    _notify();
  }

  /// Keep shares after a restart. Off deletes the stored shares at once
  /// (the shares stay active until the app stops).
  Future<void> setKeepShares(bool on) async {
    if (on == _keepShares) return;
    _keepShares = on;
    try {
      core.setSharesPersistence(on);
    } catch (_) {}
    await _persist();
    _notify();
  }

  /// Ends a browser's session (it must pair again to send files).
  void revokeWebSession(String id) {
    core.revokeWebSession(id);
    webSessions = core.webSessions;
    _notify();
  }

  /// Shares files/folders with browsers. Throws when nothing can be shared.
  Share createShare(List<String> paths, {Duration? ttl, int? maxDownloads}) {
    final s = core.createShare(paths, ttl: ttl, maxDownloads: maxDownloads);
    shares = core.shares;
    _notify();
    return s;
  }

  void revokeShare(String id) {
    core.revokeShare(id);
    shares = core.shares;
    _notify();
  }

  /// Approve or decline a browser pairing.
  void respondPairing(WebPairingRequest req, bool approve) {
    if (!req.decision.isCompleted) req.decision.complete(approve);
  }

  Future<void> _persist() => _store.save({
        'alias': _alias,
        'background': _background,
        'webHttp': _webHttp,
        'keepShares': _keepShares,
        if (_customDir) 'saveDir': _saveDir,
      });

  /// Complete an incoming request's decision and start tracking it.
  void respond(IncomingRequest req, bool accept) {
    if (!req.decision.isCompleted) req.decision.complete(accept);
    if (!accept) return;
    final s = TransferSession(
      sessionId: req.sessionId,
      incoming: true,
      peerAlias: req.sender.alias,
      savedTo: _saveDir,
    );
    for (final f in req.files) {
      s.files[f.id] = FileTransfer(f.id, f.fileName, f.size);
    }
    sessions.insert(0, s);
    _bind(s, req.sessionId);
    _notify();
  }

  Future<DeviceInfo?> addPeerByIp(String ip, {int port = 53317}) =>
      core.addPeerByIp(ip, port: port);

  Future<List<Finding>> runDiagnosis({String? targetIp, int? targetPort}) =>
      core.runDiagnosis(targetIp: targetIp, targetPort: targetPort);

  /// Re-reads the network after joining or starting a hotspot.
  Future<void> restartDiscovery() async {
    if (status != CoreStatus.running) return;
    try {
      await core.restartDiscovery();
    } catch (_) {}
    _notify();
  }

  /// Probes likely addresses (hotspot gateways) and adds what answers.
  Future<List<DeviceInfo>> probeAddresses(List<String> ips) async {
    if (status != CoreStatus.running) return const [];
    return core.probeAddresses(ips);
  }

  /// Starts the Android local-only hotspot; [hotspot] or [hotspotError] is
  /// set afterwards. The core then advertises it and rediscovers.
  Future<void> startHotspot() async {
    if (hotspotStarting) return;
    hotspotStarting = true;
    hotspotError = null;
    _notify();
    try {
      final h = await hotspotService.start();
      hotspot = h;
      _guardCall(() => core.setHotspotInfo(h.ssid, gateway: h.gateway));
      if (hotspotSettleDelay > Duration.zero) {
        await Future<void>.delayed(hotspotSettleDelay);
      }
      await restartDiscovery();
    } on HotspotException catch (e) {
      hotspotError = e.message;
    } catch (e) {
      hotspotError = 'The hotspot could not start: $e';
    } finally {
      hotspotStarting = false;
      _notify();
    }
  }

  Future<void> stopHotspot() async {
    await hotspotService.stop();
    hotspot = null;
    hotspotError = null;
    _guardCall(() => core.setHotspotInfo(null));
    await restartDiscovery();
    _notify();
  }

  void _guardCall(void Function() f) {
    try {
      f();
    } catch (_) {}
  }

  Future<void> rescan() async {
    if (scanning) return;
    scanning = true;
    _notify();
    try {
      await core.scanSubnet();
    } finally {
      scanning = false;
      _notify();
    }
  }

  /// Sends files and/or folders; progress shows up in [sessions], keyed by
  /// the session id the core reports. Returns the core result.
  Future<bool> send(DeviceInfo to, List<String> paths) async {
    final s = TransferSession(
      sessionId: '',
      incoming: false,
      peerAlias: to.alias,
    );
    sessions.insert(0, s);
    _notify();
    bool ok;
    try {
      final r = await core.sendFiles(
        to,
        [for (final p in paths) SendItem(p)],
        onSession: (sid) {
          _bind(s, sid);
          _notify();
        },
      );
      ok = r.ok;
      s.error = r.error;
      if (r.sessionId != null && s.sessionId.isEmpty) _bind(s, r.sessionId!);
    } catch (e) {
      ok = false;
      s.error = '$e';
      lastError = '$e';
    }
    s.result = ok;
    _notify();
    return ok;
  }

  /// Gives [s] its session id and applies progress that arrived before.
  void _bind(TransferSession s, String sessionId) {
    s.sessionId = sessionId;
    final early = _orphans.remove(sessionId);
    for (final p in early?.values ?? const <TransferProgress>[]) {
      _apply(s, p);
    }
  }

  void _onProgress(TransferProgress p) {
    final s = sessions
        .where((x) => x.sessionId.isNotEmpty && x.sessionId == p.sessionId)
        .firstOrNull;
    if (s == null) {
      // Not ours yet (e.g. the send call has not reported its id): keep it.
      if (_orphans.length >= 32 && !_orphans.containsKey(p.sessionId)) {
        _orphans.remove(_orphans.keys.first);
      }
      (_orphans[p.sessionId] ??= {})[p.fileId] = p;
      return;
    }
    _apply(s, p);
    _notify();
  }

  void _apply(TransferSession s, TransferProgress p) {
    final f = s.files.putIfAbsent(p.fileId,
        () => FileTransfer(p.fileId, p.fileName ?? p.fileId, p.totalBytes));
    if (p.fileName != null) f.name = p.fileName!;
    f
      ..sent = p.sentBytes
      ..total = p.totalBytes
      ..done = p.done
      ..error = p.error;
  }

  void clearFinished() {
    sessions.removeWhere((s) => s.done || s.result != null);
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    _updateStatus();
    notifyListeners();
  }

  /// Tells the background service how many shares and browsers are active,
  /// when that changed. Errors are swallowed (no service off Android).
  void _updateStatus() {
    if (!_background || status != CoreStatus.running) return;
    final now = (shares.where((s) => !s.expired && !s.exhausted).length,
        webSessions.length);
    if (now == _lastStatus) return;
    _lastStatus = now;
    try {
      _statusNotifier(now.$1, now.$2).catchError((_) {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subs) {
      s.cancel();
    }
    _incomingCtrl.close();
    _pairingCtrl.close();
    if (hotspot != null) hotspotService.stop();
    core.stop().catchError((_) {});
    MulticastLock.release();
    BackgroundService.stop();
    super.dispose();
  }
}
