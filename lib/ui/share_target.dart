import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import 'app_controller.dart' show CoreStatus;
import 'connect_helper.dart';
import 'diagnosis_dialog.dart';
import 'dialogs.dart';
import 'finding_text.dart';
import 'format.dart';
import 'l10n.dart';
import 'pickers.dart';
import 'widgets.dart';

/// What another app shared to LanDrop through Android's Share sheet
/// (docs/UX.md U10). [files] are copies in the app cache, deleted again
/// through [ShareTargetApi.clear] once the send is over.
class SharedContent {
  const SharedContent({this.files = const [], this.text, this.error});

  final List<String> files;
  final String? text;

  /// `tooMany`, `tooBig`, `unreadable` or `failed` (ShareIntentHandler.kt);
  /// may come with [files] when only some items failed.
  final String? error;

  bool get hasFiles => files.isNotEmpty;

  /// Parses a native payload; null when it carries nothing.
  static SharedContent? fromMap(Object? m) {
    if (m is! Map) return null;
    final files = m['files'];
    final text = m['text'];
    final error = m['error'];
    final c = SharedContent(
      files: [if (files is List) ...files.whereType<String>()],
      text: text is String && text.trim().isNotEmpty ? text : null,
      error: error is String && error.isNotEmpty ? error : null,
    );
    return c.files.isEmpty && c.text == null && c.error == null ? null : c;
  }
}

/// What the host needs; widget tests use a fake.
abstract class ShareTargetApi {
  /// False off Android: nothing is ever shared.
  bool get supported;

  /// The share that started the app (null when none); returns it once.
  Future<SharedContent?> getInitial();

  /// Shares that arrive while the app is running.
  Stream<SharedContent> get shares;

  /// Forgets the pending share and deletes the cached copies at [paths].
  Future<void> clear([List<String> paths = const []]);
}

/// `dev.landrop/share` and its event channel (ShareIntentHandler.kt).
/// A no-op where [supported] is false.
class ShareTargetService implements ShareTargetApi {
  ShareTargetService({
    MethodChannel? channel,
    this.events,
    bool? android,
  }) : _channel = channel ?? const MethodChannel(channelName),
       supported = android ?? Platform.isAndroid;

  static const channelName = 'dev.landrop/share';
  static const eventsName = 'dev.landrop/share/events';

  final MethodChannel _channel;
  final Stream<dynamic>? events;

  @override
  final bool supported;

  @override
  Future<SharedContent?> getInitial() async {
    if (!supported) return null;
    try {
      return SharedContent.fromMap(
        await _channel.invokeMethod<Object?>('getInitial'),
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return const SharedContent(error: 'failed');
    }
  }

  @override
  Stream<SharedContent> get shares {
    if (!supported) return const Stream.empty();
    final s =
        events ?? const EventChannel(eventsName).receiveBroadcastStream();
    return s
        .map<SharedContent?>(SharedContent.fromMap)
        .where((c) => c != null)
        .cast<SharedContent>()
        .handleError((Object _) {});
  }

  @override
  Future<void> clear([List<String> paths = const []]) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<bool>('clear', {'paths': paths});
    } catch (_) {
      // The files are deleted at the next start anyway.
    }
  }
}

/// Wraps the app's home: when something is shared to LanDrop it waits for
/// the settings, the onboarding and the core, asks for the device ("Sending
/// 3 files" / "Sending text"), sends with the normal send flow, shows the
/// usual result and deletes the cache copies.
class ShareTargetHost extends StatefulWidget {
  const ShareTargetHost({
    super.key,
    required this.child,
    this.service,
    this.pickFiles = defaultPickFiles,
    this.pickFolder = defaultPickFolder,
  });

  final Widget child;

  /// Test seam; default [ShareTargetService].
  final ShareTargetApi? service;

  /// For "Can't find the other device?" in the picker.
  final FilesPicker pickFiles;
  final FolderPicker pickFolder;

  @override
  State<ShareTargetHost> createState() => _ShareTargetHostState();
}

class _ShareTargetHostState extends State<ShareTargetHost> {
  late final ShareTargetApi _api = widget.service ?? ShareTargetService();
  StreamSubscription<SharedContent>? _sub;
  final Queue<SharedContent> _queue = Queue();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _sub = _api.shares.listen(_enqueue);
    _api.getInitial().then((c) {
      if (c != null) _enqueue(c);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _enqueue(SharedContent c) {
    if (!mounted) return;
    setState(() => _queue.add(c)); // rebuilds, which starts the drain
  }

  bool _ready() {
    final c = AppScope.read(context);
    return c.settingsLoaded && c.onboarded && c.status == CoreStatus.running;
  }

  void _drainSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _drain();
    });
  }

  Future<void> _drain() async {
    if (_busy) return;
    _busy = true;
    try {
      while (_queue.isNotEmpty && mounted && _ready()) {
        await _handle(_queue.removeFirst());
      }
    } finally {
      _busy = false;
    }
  }

  void _snack(String msg, {bool error = false, SnackBarAction? action}) {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('shareSnack'),
        content: Text(msg),
        backgroundColor: error ? scheme.error : null,
        action: action,
      ),
    );
  }

  Future<void> _handle(SharedContent s) async {
    final l = context.l;
    final c = AppScope.read(context);
    final err = s.error;
    if (err != null) _snack(shareErrorText(l, err), error: true);
    final String title;
    if (s.hasFiles) {
      title = l.shareSendingFiles(s.files.length);
    } else if (s.text != null) {
      if (utf8.encode(s.text!).length > maxTextBytes) {
        _snack(l.sendTextTooLong(formatBytes(maxTextBytes, l)), error: true);
        await _api.clear();
        return;
      }
      title = l.shareSendingText;
    } else {
      await _api.clear();
      return;
    }
    final peer = await showPeerPicker(
      context,
      c.peers,
      title: title,
      onHelp: () => openConnectHelper(
        context,
        pickFiles: widget.pickFiles,
        pickFolder: widget.pickFolder,
      ),
    );
    if (peer == null || !mounted) {
      await _api.clear(s.files);
      return;
    }
    // Files win over a caption that came with them.
    final r = s.hasFiles
        ? await c.sendWithResult(peer, s.files)
        : await c.sendText(peer, s.text!);
    await _api.clear(s.files);
    if (mounted) _sendResult(peer, r);
  }

  /// The same messages as the home page's own sends (UX.md 3.3).
  void _sendResult(DeviceInfo peer, SendResult r) {
    final l = context.l;
    final name = l.isoName(peer.alias);
    if (r.ok) {
      _snack(l.sendSent(name));
      return;
    }
    final message = switch (r.errorCode) {
      SendErrorCode.declined => l.sendDeclined(name),
      null ||
      SendErrorCode.unreachable ||
      SendErrorCode.timeout ||
      SendErrorCode.unknown => l.sendFailed(name),
      final code => localizeSendError(l, code),
    };
    _snack(
      message,
      error: r.errorCode != SendErrorCode.declined,
      action: r.errorCode == SendErrorCode.declined
          ? null
          : SnackBarAction(
              label: l.homeHelp,
              onPressed: () => showDiagnosisDialog(context),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Depend on the controller so a finished onboarding or a started core
    // resumes a waiting share.
    AppScope.of(context);
    if (_queue.isNotEmpty && !_busy && _ready()) _drainSoon();
    return widget.child;
  }
}

/// Snackbar text for a native share error code.
String shareErrorText(AppLocalizations l, String code) => switch (code) {
  'tooMany' => l.shareErrTooMany,
  'tooBig' => l.shareErrTooBig,
  'unreadable' => l.shareErrUnreadable,
  _ => l.shareErrFailed,
};
