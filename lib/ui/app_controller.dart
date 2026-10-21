import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../core/api.dart';
import 'background_service.dart';
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

/// App-level controller wrapping a [LanDropCore].
class AppController extends ChangeNotifier {
  AppController({
    required this.core,
    SettingsStore? store,
    String? initialSaveDir,
    String? initialAlias,
  })  : _store = store ?? const SettingsStore(),
        _saveDir = initialSaveDir ?? '',
        _alias = initialAlias ?? _defaultAlias();

  final LanDropCore core;
  final SettingsStore _store;

  String _alias;
  String _saveDir;
  bool _background = true; // Android foreground service on/off
  bool _customDir = false; // user picked a folder; only then is it persisted
  CoreStatus status = CoreStatus.stopped;
  String? lastError;
  List<DeviceInfo> peers = const [];
  final List<TransferSession> sessions = [];
  bool scanning = false;
  String? _fallbackIp;
  bool _disposed = false;

  final _incomingCtrl = StreamController<IncomingRequest>.broadcast();
  final List<StreamSubscription<dynamic>> _subs = [];

  /// Progress for sessions not (yet) known here, latest event per file.
  /// Applied when a send learns its session id or a request is accepted.
  final Map<String, Map<String, TransferProgress>> _orphans = {};
  bool _discoveryErrorDismissed = false;

  String get alias => _alias;
  String get saveDir => _saveDir;
  bool get background => _background;
  Stream<IncomingRequest> get incomingRequests => _incomingCtrl.stream;

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
      peers = p;
      _notify();
    }));
    _subs.add(core.incoming.listen(_incomingCtrl.add));
    _subs.add(core.progress.listen(_onProgress));

    final s = await _store.load();
    if (s['alias'] is String && (s['alias'] as String).trim().isNotEmpty) {
      _alias = s['alias'] as String;
    }
    if (s['background'] is bool) _background = s['background'] as bool;
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
      await core.start(alias: _alias, saveDir: _saveDir);
      status = CoreStatus.running;
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

  Future<void> _persist() => _store.save({
        'alias': _alias,
        'background': _background,
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
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subs) {
      s.cancel();
    }
    _incomingCtrl.close();
    core.stop().catchError((_) {});
    MulticastLock.release();
    BackgroundService.stop();
    super.dispose();
  }
}
