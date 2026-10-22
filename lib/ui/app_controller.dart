import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../core/api.dart';
import '../core/util.dart' show reserveUniqueFile;
import 'background_service.dart';
import 'file_opener.dart';
import 'history_store.dart';
import 'hotspot_service.dart';
import 'l10n.dart' show englishStrings;
import 'multicast_lock.dart';
import 'storage_access.dart';

export 'history_store.dart' show HistoryEntry, HistoryStore, MemoryHistoryStore;

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

  /// The transfer history, in its own file next to the settings file.
  HistoryStore get history => const HistoryStore();
}

/// Non-persistent store (tests). Starts with `onboarded: true` so tests
/// land on the home page; pass `onboarded: false` (or the key in
/// [initial]) to see the first-run onboarding.
class MemorySettingsStore extends SettingsStore {
  MemorySettingsStore([Map<String, dynamic>? initial, bool onboarded = true])
      : stored = {'onboarded': onboarded, ...?initial};
  final Map<String, dynamic> stored;

  /// In-memory history (see [SettingsStore.history]).
  @override
  final MemoryHistoryStore history = MemoryHistoryStore();
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
  SendErrorCode? errorCode;

  /// Receiving side: where the finished file was saved.
  String? savedPath;

  double get fraction => total <= 0 ? (done ? 1 : 0) : (sent / total).clamp(0, 1);
}

/// Bytes per second over a short moving window (UX.md 3.8: 3 s), from
/// (time, bytes so far) samples. UI only; the core reports bytes.
class SpeedMeter {
  SpeedMeter({this.window = const Duration(seconds: 3)});
  final Duration window;
  final List<(DateTime, int)> _samples = [];

  void add(DateTime at, int bytes) {
    if (_samples.isNotEmpty && bytes < _samples.last.$2) _samples.clear();
    _samples.add((at, bytes));
    // Keep one sample at or before the start of the window.
    while (_samples.length > 2 && at.difference(_samples[1].$1) >= window) {
      _samples.removeAt(0);
    }
  }

  /// Null until the samples span at least half a second.
  double? get bytesPerSecond {
    if (_samples.length < 2) return null;
    final (t0, b0) = _samples.first;
    final (t1, b1) = _samples.last;
    final ms = t1.difference(t0).inMilliseconds;
    if (ms < 500) return null;
    return (b1 - b0) * 1000 / ms;
  }
}

/// What a transfer card shows (UX.md 3.8). Declined, cancelled, failed and
/// done are told apart by icon and text, not only colour.
enum TransferState {
  waiting,
  running,
  done,
  declined,
  cancelled,
  failed;

  bool get isFinal => index >= done.index;
}

class TransferSession {
  TransferSession({
    required this.sessionId,
    required this.incoming,
    required this.peerAlias,
    this.peerFingerprint = '',
    this.savedTo,
    this.autoAccepted = false,
    this.peer,
    this.paths = const [],
    this.text,
  });

  String sessionId;

  /// Outgoing: the device and the paths sent, so "Try again" can send the
  /// same items to the same device.
  final DeviceInfo? peer;
  final List<String> paths;

  /// A text message (sent or received); its text, shown on the card.
  final String? text;

  /// Written to the persistent history already.
  bool recorded = false;
  final bool incoming;
  final String peerAlias;
  final String peerFingerprint;
  final String? savedTo;

  /// Accepted without asking (trusted device with "Always accept"); the
  /// card says so (UX.md 3.7).
  final bool autoAccepted;
  final Map<String, FileTransfer> files = {};
  final DateTime started = DateTime.now();
  final SpeedMeter meter = SpeedMeter();

  bool? result; // outgoing: send() result
  String? error; // outgoing: why send() failed (English, technical)
  SendErrorCode? errorCode; // outgoing: why send() failed, for the UI

  /// Cancel was pressed before the receiver accepted (no session id yet).
  bool cancelRequested = false;

  int get sentBytes => files.values.fold(0, (a, f) => a + f.sent);
  int get totalBytes => files.values.fold(0, (a, f) => a + f.total);

  TransferState get state {
    if (!incoming) {
      return switch (result) {
        true => TransferState.done,
        false => switch (errorCode) {
            SendErrorCode.declined => TransferState.declined,
            SendErrorCode.cancelled => TransferState.cancelled,
            _ => TransferState.failed,
          },
        null => files.isEmpty ? TransferState.waiting : TransferState.running,
      };
    }
    if (files.isEmpty ||
        !files.values.every((f) => f.done || f.error != null)) {
      return TransferState.running;
    }
    final failed = files.values.where((f) => f.error != null);
    if (failed.isEmpty) return TransferState.done;
    return failed.any((f) => f.errorCode == SendErrorCode.cancelled)
        ? TransferState.cancelled
        : TransferState.failed;
  }

  /// Why it failed, for [localizeSendError].
  SendErrorCode? get failureCode => incoming
      ? files.values
          .where((f) => f.error != null)
          .map((f) => f.errorCode ?? SendErrorCode.unknown)
          .firstOrNull
      : errorCode;

  /// Incoming: every file finished. Outgoing: send() returned (files appear
  /// one at a time as the core starts them, so they cannot tell).
  bool get done => state.isFinal;
  bool get hasError => files.values.any((f) => f.error != null);

  /// Smoothed speed while running, else null.
  double? get speed =>
      state == TransferState.running ? meter.bytesPerSecond : null;

  /// Estimated time left while running and the speed is known.
  Duration? get timeLeft {
    final s = speed;
    final left = totalBytes - sentBytes;
    if (s == null || s <= 0 || left <= 0) return null;
    return Duration(seconds: (left / s).ceil());
  }

  /// Receiving: where the finished files are.
  List<String> get savedPaths => [
        for (final f in files.values)
          if (f.savedPath != null) f.savedPath!
      ];

  /// What "Open" opens: the file when there is one, else the folder that
  /// holds them all (a received folder, or the save folder).
  String? get openPath {
    final p = savedPaths;
    if (p.isEmpty) return savedTo;
    return p.length == 1 ? p.single : commonDirectory(p) ?? savedTo;
  }
}

/// The deepest directory containing every path in [paths] (separators as
/// in the paths), or null when there is none.
String? commonDirectory(List<String> paths) {
  if (paths.isEmpty) return null;
  final sep = paths.first.contains('\\') && !paths.first.contains('/')
      ? '\\'
      : '/';
  List<String> dirOf(String p) {
    final parts = p.split(RegExp(r'[\\/]'));
    return parts.sublist(0, parts.length - 1);
  }

  var common = dirOf(paths.first);
  for (final p in paths.skip(1)) {
    final d = dirOf(p);
    var i = 0;
    while (i < common.length && i < d.length && common[i] == d[i]) {
      i++;
    }
    common = common.sublist(0, i);
  }
  if (common.isEmpty || (common.length == 1 && common.first.isEmpty)) {
    return null;
  }
  return common.join(sep);
}

/// A device the user accepted files from (UX.md 3.7, step U7). Stored in
/// the settings JSON under `trustedDevices`. [fingerprint] is the identity;
/// [alias] is the name the device announced, [displayName] the user's own
/// name for it (display only, never used for decisions).
class TrustedDevice {
  TrustedDevice({
    required this.fingerprint,
    required this.alias,
    required this.trustedAt,
    this.autoAccept = false,
    this.displayName,
  });

  final String fingerprint;
  String alias;
  final DateTime trustedAt;
  bool autoAccept;
  String? displayName;

  String get name =>
      displayName == null || displayName!.trim().isEmpty ? alias : displayName!;

  Map<String, dynamic> toJson() => {
        'fingerprint': fingerprint,
        'alias': alias,
        'trustedAt': trustedAt.toUtc().toIso8601String(),
        'autoAccept': autoAccept,
        'displayName': ?displayName,
      };

  static TrustedDevice? fromJson(Object? j) {
    if (j is! Map) return null;
    final fp = j['fingerprint'], alias = j['alias'];
    if (fp is! String || fp.isEmpty || alias is! String) return null;
    final at = j['trustedAt'];
    final name = j['displayName'];
    return TrustedDevice(
      fingerprint: fp,
      alias: alias,
      trustedAt: (at is String ? DateTime.tryParse(at) : null) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      autoAccept: j['autoAccept'] == true,
      displayName: name is String ? name : null,
    );
  }
}

/// How the incoming dialog presents the sender (UX.md 3.7).
enum SenderTrust {
  /// A web browser: never trusted, never auto-accepted.
  browser,

  /// The sender did not prove its fingerprint (e.g. a plain LocalSend app).
  unverified,

  /// A proven fingerprint never accepted before.
  firstTime,

  /// A proven fingerprint the user accepted before.
  trusted,
}

/// A device seen nearby before (UX.md 3.2 "Recent"), kept in the settings
/// JSON under `recentDevices` (at most [AppController.maxRecent]).
class RecentDevice {
  RecentDevice({
    required this.fingerprint,
    required this.alias,
    required this.deviceType,
    required this.lastSeen,
  });

  final String fingerprint;
  String alias;
  String deviceType;
  DateTime lastSeen;

  Map<String, dynamic> toJson() => {
        'fingerprint': fingerprint,
        'alias': alias,
        'deviceType': deviceType,
        'lastSeen': lastSeen.toUtc().toIso8601String(),
      };

  static RecentDevice? fromJson(Object? j) {
    if (j is! Map) return null;
    final fp = j['fingerprint'], alias = j['alias'], seen = j['lastSeen'];
    if (fp is! String || fp.isEmpty || alias is! String || seen is! String) {
      return null;
    }
    final at = DateTime.tryParse(seen);
    if (at == null) return null;
    final type = j['deviceType'];
    return RecentDevice(
        fingerprint: fp,
        alias: alias,
        deviceType: type is String ? type : 'desktop',
        lastSeen: at.toLocal());
  }
}

/// A text message to show (PROTOCOL.md "Text messages"). [auto]: accepted
/// without asking (a trusted device with "Always accept"); the dialog says
/// so.
class IncomingText {
  const IncomingText(this.request, {this.auto = false});
  final IncomingRequest request;
  final bool auto;
  String get text => request.text ?? '';
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
    FileOpener? fileOpener,
    DateTime Function()? clock,
    StorageAccess? storageAccess,
    HistoryStore? historyStore,
  })  : _store = store ?? const SettingsStore(),
        storage = storageAccess ?? const StorageAccess(),
        _historyStore = historyStore ?? (store ?? const SettingsStore()).history,
        _saveDir = initialSaveDir ?? '',
        _alias = initialAlias ?? _defaultAlias(),
        _statusNotifier = statusNotifier ?? _defaultStatusNotifier,
        hotspotService = hotspotService ?? HotspotService(),
        fileOpener = fileOpener ?? SystemFileOpener(),
        _clock = clock ?? DateTime.now;

  final LanDropCore core;
  final SettingsStore _store;

  /// Android "All files access" (test seam).
  final StorageAccess storage;

  /// Where the transfer history is kept (test seam).
  final HistoryStore _historyStore;

  /// History entries kept (newest first).
  static int get maxHistoryEntries => HistoryStore.maxEntries;

  /// Recent devices kept in the settings JSON.
  static const maxRecent = 20;

  /// "Open" / "Show in folder" for received files (test seam).
  final FileOpener fileOpener;

  /// Time source for the speed meter (test seam).
  final DateTime Function() _clock;

  /// Finished transfers kept on the home page (oldest dropped first);
  /// running ones are never dropped.
  static const maxHistory = 20;

  /// Transfers larger than this are never accepted automatically, even from
  /// a trusted device, unless [autoAcceptLarge] is on (UX.md 3.7).
  static const autoAcceptMaxBytes = 2 * 1024 * 1024 * 1024; // 2 GB

  /// Android local-only hotspot (test seam).
  final HotspotService hotspotService;

  /// Wait after the hotspot started before re-reading the interfaces (the
  /// hotspot interface gets its address a moment later).
  final Duration hotspotSettleDelay;

  /// The hotspot this device shares, while it does.
  HotspotCredentials? hotspot;
  bool hotspotStarting = false;

  /// Why the hotspot did not start, in English (logs, tests);
  /// [hotspotFailure] has the code the UI localizes.
  String? hotspotError;
  HotspotException? hotspotFailure;

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
  Locale? _locale; // app language; null = follow the system
  ThemeMode _themeMode = ThemeMode.system;
  bool _settingsLoaded = false;
  bool _onboarded = false; // first-run onboarding done (UX.md 3.6)
  bool _storageAsked = false; // Android "All files access" explained once
  bool _keepHistory = true;
  List<HistoryEntry> _history = [];
  int _localSeq = 0;
  final Map<String, RecentDevice> _recent = {};
  Set<String> _online = {};
  CoreStatus status = CoreStatus.stopped;
  /// The last technical error (English, shown in Settings ▸ Advanced).
  String? lastError;

  /// Set with [lastError] when plain HTTP for browsers failed to start: the
  /// raw error, so the UI can say what failed in the user's language.
  String? webHttpStartError;
  List<DeviceInfo> peers = const [];
  final List<TransferSession> sessions = [];
  bool scanning = false;
  String? _fallbackIp;
  bool _disposed = false;

  final _incomingCtrl = StreamController<IncomingRequest>.broadcast();
  final _pairingCtrl = StreamController<WebPairingRequest>.broadcast();
  final _autoAcceptedCtrl = StreamController<TransferSession>.broadcast();
  final _textCtrl = StreamController<IncomingText>.broadcast();

  /// Devices the user accepted from, by fingerprint (persisted).
  final Map<String, TrustedDevice> _trusted = {};
  bool _autoAcceptLarge = false;

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

  /// Transfers accepted without asking (trusted device with "Always
  /// accept"), so the UI can say so with a "Stop auto-accept" action.
  Stream<TransferSession> get autoAccepted => _autoAcceptedCtrl.stream;

  /// Text messages to show (PROTOCOL.md "Text messages"). Unless
  /// [IncomingText.auto], the UI calls [receiveText] when it shows one.
  Stream<IncomingText> get incomingTexts => _textCtrl.stream;

  /// The settings file was read (the UI waits for it before choosing
  /// between onboarding and home).
  bool get settingsLoaded => _settingsLoaded;

  /// First-run onboarding was finished or skipped (persisted as
  /// `onboarded`).
  bool get onboarded => _onboarded;

  /// Ends the onboarding for good; [alias] (when given and not blank)
  /// renames this device.
  Future<void> completeOnboarding({String? alias}) async {
    _onboarded = true;
    final a = alias?.trim();
    if (a != null && a.isNotEmpty && a != _alias) {
      await updateSettings(alias: a);
      return;
    }
    await _persist();
    _notify();
  }

  /// Light, dark or follow the system (persisted as `theme`).
  ThemeMode get themeMode => _themeMode;

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    await _persist();
    _notify();
  }

  static ThemeMode _parseTheme(Object? v) => switch (v) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

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

  /// The app language chosen in Settings (persisted as `'locale'`:
  /// `'system'`, `'en'` or `'fa'`); null follows the system language.
  Locale? get locale => _locale;

  /// Changes the app language (null = system default). No restart needed.
  Future<void> setLocale(Locale? locale) async {
    final next = locale == null ? null : Locale(locale.languageCode);
    if (next == _locale) return;
    _locale = next;
    await _persist();
    _notify();
  }

  static Locale? _parseLocale(Object? v) =>
      v is String && v.isNotEmpty && v != 'system' ? Locale(v) : null;

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

  /// The platform default folder. Never asks for a permission (UX.md
  /// 3.6): on Android it is Downloads/LanDrop only when "All files access"
  /// was already granted, else the app's own folder until the user allows
  /// it after [needsStorageExplanation].
  static Future<String> defaultSaveDir(
      [StorageAccess storage = const StorageAccess()]) async {
    if (storage.isAndroid) {
      // Visible in the Files app: Downloads/LanDrop.
      if (await storage.granted()) {
        try {
          await Directory(storage.publicDir).create(recursive: true);
          return storage.publicDir;
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
      _rememberPeers();
      _notify();
    }));
    _subs.add(core.incoming.listen(_onIncoming));
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
    _locale = _parseLocale(s['locale']);
    _themeMode = _parseTheme(s['theme']);
    // Settings saved by a version without onboarding: not a first run.
    _onboarded = s['onboarded'] == true ||
        (!s.containsKey('onboarded') && s.isNotEmpty);
    _storageAsked = s['storageAsked'] == true;
    if (s['keepHistory'] is bool) _keepHistory = s['keepHistory'] as bool;
    final recent = s['recentDevices'];
    if (recent is List) {
      for (final j in recent) {
        final r = RecentDevice.fromJson(j);
        if (r != null) _recent[r.fingerprint] = r;
      }
    }
    if (s['autoAcceptLarge'] is bool) {
      _autoAcceptLarge = s['autoAcceptLarge'] as bool;
    }
    final trusted = s['trustedDevices'];
    if (trusted is List) {
      for (final j in trusted) {
        final t = TrustedDevice.fromJson(j);
        if (t != null) _trusted[t.fingerprint] = t;
      }
    }
    if (s['saveDir'] is String && (s['saveDir'] as String).isNotEmpty) {
      _saveDir = s['saveDir'] as String;
      _customDir = true;
    }
    if (_saveDir.isEmpty) {
      try {
        _saveDir = await defaultSaveDir(storage);
      } catch (e) {
        _saveDir = Directory.systemTemp.path;
      }
    }
    if (_keepHistory) {
      try {
        final h = await _historyStore.load();
        // Entries recorded while loading stay first.
        _history = [..._history, ...h.where((e) => !_history.any((x) => x.id == e.id))];
      } catch (_) {}
    }
    _settingsLoaded = true;
    _notify();
    await _start();
  }

  Future<void> _start() async {
    status = CoreStatus.starting;
    lastError = null;
    webHttpStartError = null;
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
          webHttpStartError = '$e';
          lastError = englishStrings.errorWebHttpStart('$e');
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
      // A folder the user picked outside the app's own folder.
      if (storage.isAndroid) await storage.request();
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
    _saveDir = await defaultSaveDir(storage);
    await _persist();
    _notify();
    if (status != CoreStatus.stopped) await restart();
  }

  /// Android: received files go to the app's own folder (only visible inside
  /// LanDrop) because "All files access" was not granted.
  bool get savesToPrivateFolder =>
      storage.isAndroid && !_customDir && _saveDir != storage.publicDir;

  /// Android, the first time a receive folder is needed (an incoming
  /// transfer was accepted): LanDrop should explain "All files access"
  /// before the system screen (UX.md 3.6). Once answered, only Settings
  /// ("Use Downloads") asks again.
  bool get needsStorageExplanation => savesToPrivateFolder && !_storageAsked;

  /// The user answered the explanation. [allow]: open the system screen
  /// and, when granted, save to Downloads/LanDrop from now on (also the
  /// transfer being accepted). "Not now" keeps the private folder. Returns
  /// whether files now go to Downloads.
  Future<bool> answerStorageExplanation(bool allow) async {
    _storageAsked = true;
    await _persist();
    if (!allow) {
      _notify();
      return false;
    }
    return useDownloadsFolder();
  }

  /// Android: asks for "All files access" (after the explanation) and,
  /// when granted, moves received files to Downloads/LanDrop without a
  /// restart. Returns whether it is granted.
  Future<bool> useDownloadsFolder() async {
    if (!await storage.request()) {
      _notify();
      return false;
    }
    final dir = storage.publicDir;
    try {
      Directory(dir).createSync(recursive: true);
    } catch (_) {}
    _customDir = false;
    _saveDir = dir;
    _storageAsked = true;
    if (status == CoreStatus.running) {
      try {
        await core.setSaveDir(dir);
      } catch (_) {}
    }
    await _persist();
    _notify();
    return true;
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
        'locale': _locale?.languageCode ?? 'system',
        'theme': switch (_themeMode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
        },
        'onboarded': _onboarded,
        if (_storageAsked) 'storageAsked': true,
        'keepHistory': _keepHistory,
        'recentDevices': [for (final r in _recent.values) r.toJson()],
        if (_customDir) 'saveDir': _saveDir,
        'trustedDevices': [for (final t in _trusted.values) t.toJson()],
        'autoAcceptLarge': _autoAcceptLarge,
      });

  /// Complete an incoming request's decision and start tracking it.
  /// Accepting from a device that proved its fingerprint remembers it as
  /// trusted; [alwaysAccept] also turns on auto-accept for it.
  void respond(IncomingRequest req, bool accept, {bool alwaysAccept = false}) =>
      _respond(req, accept, alwaysAccept: alwaysAccept);

  TransferSession? _respond(IncomingRequest req, bool accept,
      {bool alwaysAccept = false, bool auto = false}) {
    if (!req.decision.isCompleted) req.decision.complete(accept);
    if (!accept) return null;
    final s = TransferSession(
      sessionId: req.sessionId,
      incoming: true,
      peerAlias: req.sender.alias,
      peerFingerprint: req.verified ? req.sender.fingerprint : '',
      savedTo: _saveDir,
      autoAccepted: auto,
    );
    for (final f in req.files) {
      s.files[f.id] = FileTransfer(f.id, f.fileName, f.size);
    }
    sessions.insert(0, s);
    _trimHistory();
    _bind(s, req.sessionId);
    if (trustOf(req) case SenderTrust.firstTime || SenderTrust.trusted) {
      final fp = req.sender.fingerprint;
      final t = _trusted[fp];
      if (t == null) {
        _trusted[fp] = TrustedDevice(
            fingerprint: fp,
            alias: req.sender.alias,
            trustedAt: _clock(),
            autoAccept: alwaysAccept);
      } else {
        t.alias = req.sender.alias;
        if (alwaysAccept) t.autoAccept = true;
      }
      unawaited(_persist());
    }
    _notify();
    return s;
  }

  // ------------------------------------------- trusted devices (UX.md 3.7)

  /// Devices the user accepted from, oldest first.
  List<TrustedDevice> get trustedDevices => _trusted.values.toList()
    ..sort((a, b) => a.trustedAt.compareTo(b.trustedAt));

  TrustedDevice? trustedDevice(String fingerprint) => _trusted[fingerprint];

  /// "Accept large transfers automatically too" (persisted, default off):
  /// lifts [autoAcceptMaxBytes].
  bool get autoAcceptLarge => _autoAcceptLarge;

  Future<void> setAutoAcceptLarge(bool on) async {
    if (on == _autoAcceptLarge) return;
    _autoAcceptLarge = on;
    await _persist();
    _notify();
  }

  /// How the incoming dialog presents [req]'s sender. Only a proven
  /// fingerprint ([IncomingRequest.verified]) can be first-time or trusted.
  SenderTrust trustOf(IncomingRequest req) {
    final d = req.sender;
    if (d.deviceType == 'web') return SenderTrust.browser;
    if (!req.verified || d.fingerprint.isEmpty) return SenderTrust.unverified;
    return _trusted.containsKey(d.fingerprint)
        ? SenderTrust.trusted
        : SenderTrust.firstTime;
  }

  /// A trusted device whose name [req]'s sender uses although it is not
  /// that device (another or an unproven fingerprint): the dialog warns.
  /// Names are compared without case and surrounding spaces.
  TrustedDevice? aliasConflict(IncomingRequest req) {
    String norm(String s) => s.trim().toLowerCase();
    final alias = norm(req.sender.alias);
    if (alias.isEmpty) return null;
    final own = trustOf(req) == SenderTrust.trusted ||
            trustOf(req) == SenderTrust.firstTime
        ? req.sender.fingerprint
        : null;
    for (final t in _trusted.values) {
      if (t.fingerprint == own) continue;
      if (norm(t.alias) == alias ||
          (t.displayName != null && norm(t.displayName!) == alias)) {
        return t;
      }
    }
    return null;
  }

  /// Whether [req] is accepted without asking. Decided here, before any
  /// dialog, by the proven fingerprint only (never the name), and never for
  /// browsers, without a save folder, or above [autoAcceptMaxBytes] unless
  /// [autoAcceptLarge] is on.
  bool shouldAutoAccept(IncomingRequest req) {
    if (trustOf(req) != SenderTrust.trusted) return false;
    if (_trusted[req.sender.fingerprint]?.autoAccept != true) return false;
    if (_saveDir.trim().isEmpty) return false;
    final total = req.files.fold<int>(0, (a, f) => a + f.size);
    if (total > autoAcceptMaxBytes && !_autoAcceptLarge) return false;
    return true;
  }

  void _onIncoming(IncomingRequest req) {
    if (req.isText) {
      // Shown in a dialog either way; a trusted device with "Always accept"
      // is answered at once, every other sender when the dialog shows it.
      final auto = shouldAutoAccept(req);
      if (auto) receiveText(req);
      _textCtrl.add(IncomingText(req, auto: auto));
      return;
    }
    if (shouldAutoAccept(req)) {
      final s = _respond(req, true, auto: true);
      if (s != null) _autoAcceptedCtrl.add(s);
      return;
    }
    _incomingCtrl.add(req);
  }

  Future<void> setAutoAccept(String fingerprint, bool on) async {
    final t = _trusted[fingerprint];
    if (t == null || t.autoAccept == on) return;
    t.autoAccept = on;
    await _persist();
    _notify();
  }

  /// Changes the name shown for a trusted device (display only; empty
  /// restores the device's own name).
  Future<void> renameTrusted(String fingerprint, String name) async {
    final t = _trusted[fingerprint];
    if (t == null) return;
    final n = name.trim();
    t.displayName = n.isEmpty ? null : n;
    await _persist();
    _notify();
  }

  /// Forgets a device: its next request asks again ("First time").
  Future<void> removeTrusted(String fingerprint) async {
    if (_trusted.remove(fingerprint) == null) return;
    await _persist();
    _notify();
  }

  // ------------------------------------------------------------ transfers

  /// Stops a transfer in either direction (UX.md 3.8). Before the receiver
  /// accepted (no session id yet) the send is cancelled as soon as it is.
  Future<void> cancel(TransferSession s) async {
    if (s.state.isFinal) return;
    if (s.sessionId.isEmpty) {
      s.cancelRequested = true;
      _notify();
      return;
    }
    s.cancelRequested = true;
    _notify();
    try {
      await core.cancelSession(s.sessionId);
    } catch (_) {}
  }

  /// Drops the oldest finished transfers beyond [maxHistory].
  void _trimHistory() {
    var finished = sessions.where((s) => s.state.isFinal).length;
    for (var i = sessions.length - 1;
        i >= 0 && finished > maxHistory;
        i--) {
      if (sessions[i].state.isFinal) {
        sessions.removeAt(i);
        finished--;
      }
    }
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
    hotspotFailure = null;
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
      hotspotFailure = e;
      hotspotError = e.message;
    } catch (e) {
      final f = HotspotException('failed', hotspotMessage('start-error', '$e'),
          messageCode: 'start-error', detail: '$e');
      hotspotFailure = f;
      hotspotError = f.message;
    } finally {
      hotspotStarting = false;
      _notify();
    }
  }

  Future<void> stopHotspot() async {
    await hotspotService.stop();
    hotspot = null;
    hotspotError = null;
    hotspotFailure = null;
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
  /// the session id the core reports. Returns whether it succeeded.
  Future<bool> send(DeviceInfo to, List<String> paths) async =>
      (await sendWithResult(to, paths)).ok;

  /// [send] with the core's [SendResult], so the UI can tell "declined"
  /// from "failed" ([SendResult.errorCode]).
  Future<SendResult> sendWithResult(DeviceInfo to, List<String> paths) =>
      _send(to, paths: paths);

  /// Sends a text message (PROTOCOL.md "Text messages"). Its card shows
  /// the text; nothing is uploaded when the receiver shows it.
  Future<SendResult> sendText(DeviceInfo to, String text) =>
      _send(to, text: text);

  /// "Try again" on a failed or cancelled send: the same items to the
  /// same device (its current address when it is still nearby). Null when
  /// [canRetry] is false.
  Future<SendResult?> retry(TransferSession s) async {
    if (!canRetry(s)) return null;
    final fresh =
        peers.where((p) => p.fingerprint == s.peerFingerprint).firstOrNull;
    final to = fresh ?? s.peer!;
    return s.text != null ? sendText(to, s.text!) : sendWithResult(to, s.paths);
  }

  /// Whether [retry] can send [s] again: an outgoing send that failed or
  /// was cancelled, whose files all still exist.
  bool canRetry(TransferSession s) {
    if (s.incoming || s.peer == null) return false;
    if (s.state != TransferState.failed && s.state != TransferState.cancelled) {
      return false;
    }
    if (s.text != null) return true;
    return s.paths.isNotEmpty &&
        s.paths.every((p) =>
            FileSystemEntity.typeSync(p) != FileSystemEntityType.notFound);
  }

  Future<SendResult> _send(DeviceInfo to,
      {List<String> paths = const [], String? text}) async {
    final s = TransferSession(
      sessionId: '',
      incoming: false,
      peerAlias: to.alias,
      peerFingerprint: to.fingerprint,
      peer: to,
      paths: List.unmodifiable(paths),
      text: text,
    );
    sessions.insert(0, s);
    _trimHistory();
    _notify();
    SendResult res;
    void onSession(String sid) {
      _bind(s, sid);
      // Cancel was pressed while waiting for the receiver.
      if (s.cancelRequested) unawaited(core.cancelSession(sid));
      _notify();
    }

    try {
      final r = text != null
          ? await core.sendText(to, text, onSession: onSession)
          : await core.sendFiles(to, [for (final p in paths) SendItem(p)],
              onSession: onSession);
      res = r;
      s.error = r.error;
      s.errorCode = r.ok ? null : r.errorCode;
      if (r.sessionId != null && s.sessionId.isEmpty) _bind(s, r.sessionId!);
    } catch (e) {
      res = SendResult(
          ok: false, error: '$e', errorCode: SendErrorCode.unknown);
      s.error = '$e';
      s.errorCode = SendErrorCode.unknown;
      lastError = '$e';
    }
    s.result = res.ok;
    // Ended without a session id (unreachable, declined, a text shown by
    // the receiver): a local id keeps the card's keys unique.
    if (s.sessionId.isEmpty) s.sessionId = 'local-${++_localSeq}';
    _record(s);
    _trimHistory();
    _notify();
    return res;
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
    if (p.done) {
      if (s.incoming) _record(s);
      _trimHistory();
    }
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
      ..error = p.error
      ..errorCode = p.errorCode;
    if (p.savedPath != null) f.savedPath = p.savedPath;
    s.meter.add(_clock(), s.sentBytes);
  }

  void clearFinished() {
    sessions.removeWhere((s) => s.state.isFinal);
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

  // ------------------------------------------------------- text messages

  /// Accepts a text message (the dialog shows it): the sender is told it
  /// was delivered (204); nothing is written to disk. Not a trust decision:
  /// the device is not remembered as trusted.
  void receiveText(IncomingRequest req) {
    if (req.decision.isCompleted) return;
    req.decision.complete(true);
    final t = req.text ?? '';
    _addHistory(HistoryEntry(
      id: 'in-${req.sessionId}',
      incoming: true,
      peerAlias: req.sender.alias,
      fileNames: const [textMessageFileName],
      fileCount: 1,
      totalBytes: utf8.encode(t).length,
      state: TransferState.done.name,
      at: _clock(),
      text: true,
    ));
  }

  /// "Save as file": writes [text] as `message.txt` (a unique name) in
  /// the save folder. Returns the path, or null when it failed.
  Future<String?> saveTextAsFile(String text) async {
    try {
      await Directory(_saveDir).create(recursive: true);
      final f = await reserveUniqueFile(_saveDir, textMessageFileName);
      await f.writeAsString(text, flush: true);
      return f.path;
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------- history

  /// Finished transfers, newest first (empty when [keepHistory] is off).
  List<HistoryEntry> get history => List.unmodifiable(_history);

  /// "Keep history" (persisted, default on). Off deletes it at once.
  bool get keepHistory => _keepHistory;

  Future<void> setKeepHistory(bool on) async {
    if (on == _keepHistory) return;
    _keepHistory = on;
    if (!on) {
      _history = [];
      await _historyStore.clear();
    }
    await _persist();
    _notify();
  }

  /// Deletes the whole history (received files stay).
  Future<void> clearHistory() async {
    _history = [];
    await _historyStore.clear();
    _notify();
  }

  void _record(TransferSession s) {
    if (s.recorded || !s.state.isFinal) return;
    s.recorded = true;
    final names = [for (final f in s.files.values) f.name];
    final text = s.text != null;
    _addHistory(HistoryEntry(
      id: '${s.incoming ? 'in' : 'out'}-${s.sessionId}-'
          '${s.started.microsecondsSinceEpoch}',
      incoming: s.incoming,
      peerAlias: s.peerAlias,
      fileNames: text
          ? const [textMessageFileName]
          : names.isNotEmpty
              ? names.take(HistoryStore.maxNames).toList()
              : [
                  for (final p in s.paths.take(HistoryStore.maxNames))
                    p.split(RegExp(r'[\\/]')).lastWhere((x) => x.isNotEmpty,
                        orElse: () => p)
                ],
      fileCount: text ? 1 : (names.isNotEmpty ? names.length : s.paths.length),
      totalBytes: text ? utf8.encode(s.text!).length : s.totalBytes,
      state: s.state.name,
      at: _clock(),
      savedPath: s.incoming && s.savedPaths.isNotEmpty ? s.openPath : null,
      text: text,
    ));
  }

  void _addHistory(HistoryEntry e) {
    if (!_keepHistory) return;
    _history = [e, ..._history.where((x) => x.id != e.id)];
    if (_history.length > HistoryStore.maxEntries) {
      _history = _history.sublist(0, HistoryStore.maxEntries);
    }
    unawaited(_historyStore.save(_history));
    _notify();
  }

  // ------------------------------------------------------ recent devices

  /// Devices seen before that are not nearby now, most recent first.
  List<RecentDevice> get recentOffline {
    final online = {for (final p in peers) p.fingerprint};
    return _recent.values.where((r) => !online.contains(r.fingerprint)).toList()
      ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
  }

  /// Updates the recent devices from [peers]: new devices and new names are
  /// saved; a device that left gets its "last seen" time.
  void _rememberPeers() {
    final now = _clock();
    final online = <String>{};
    var changed = false;
    for (final p in peers) {
      if (p.fingerprint.isEmpty || p.deviceType == 'web') continue;
      online.add(p.fingerprint);
      final r = _recent[p.fingerprint];
      if (r == null) {
        _recent[p.fingerprint] = RecentDevice(
            fingerprint: p.fingerprint,
            alias: p.alias,
            deviceType: p.deviceType,
            lastSeen: now);
        changed = true;
      } else {
        if (r.alias != p.alias || r.deviceType != p.deviceType) changed = true;
        r
          ..alias = p.alias
          ..deviceType = p.deviceType
          ..lastSeen = now;
      }
    }
    for (final fp in _online.difference(online)) {
      _recent[fp]?.lastSeen = now;
      changed = true;
    }
    _online = online;
    if (_recent.length > maxRecent) {
      final keep = (_recent.values.toList()
            ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen)))
          .take(maxRecent)
          .map((r) => r.fingerprint)
          .toSet();
      _recent.removeWhere((fp, _) => !keep.contains(fp));
      changed = true;
    }
    if (changed && _settingsLoaded) unawaited(_persist());
  }

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subs) {
      s.cancel();
    }
    _incomingCtrl.close();
    _pairingCtrl.close();
    _autoAcceptedCtrl.close();
    _textCtrl.close();
    if (hotspot != null) hotspotService.stop();
    core.stop().catchError((_) {});
    MulticastLock.release();
    BackgroundService.stop();
    super.dispose();
  }
}
