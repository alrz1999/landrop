import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import '../core/api.dart';
import 'diagnosis_dialog.dart';
import 'dialogs.dart';
import 'cable_wizard.dart';
import 'finding_text.dart';
import 'hotspot_wizard.dart';
import 'l10n.dart';
import 'pickers.dart';
import 'settings_page.dart';
import 'shares.dart';
import 'widgets.dart';

export 'pickers.dart';

/// What the Send sheet offers (UX.md 3.3).
enum SendKind { files, folder }

/// Home (UX.md 3.2, step U1): who I am, nearby devices, activity, and one
/// "Send" button that asks "Files or folder?". Sharing links and browser
/// access live on the Shares page (app bar), the address in Settings ▸
/// Advanced.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.pickFiles = defaultPickFiles,
    this.pickFolder = defaultPickFolder,
  });
  final FilesPicker pickFiles;
  final FolderPicker pickFolder;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  StreamSubscription<IncomingRequest>? _sub;
  StreamSubscription<WebPairingRequest>? _pairSub;

  /// Incoming transfer requests and browser pairings, one dialog at a time.
  final Queue<Object> _pending = Queue();
  bool _dialogOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = AppScope.read(context);
    _sub ??= c.incomingRequests.listen((r) {
      _pending.add(r);
      _drainIncoming();
    });
    _pairSub ??= c.pairingRequests.listen((r) {
      _pending.add(r);
      _drainIncoming();
    });
  }

  Future<void> _drainIncoming() async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    while (_pending.isNotEmpty && mounted) {
      final next = _pending.removeFirst();
      if (next is WebPairingRequest) {
        if (next.decision.isCompleted) continue; // timed out by core
        final ok = await showWebPairingDialog(context, next);
        if (!mounted) break;
        AppScope.read(context).respondPairing(next, ok);
        continue;
      }
      final req = next as IncomingRequest;
      if (req.decision.isCompleted) continue; // e.g. timed out by core
      final c = AppScope.read(context);
      final ok = await showIncomingDialog(context, req, saveDir: c.saveDir);
      if (!mounted) break;
      c.respond(req, ok);
      if (ok) {
        final l = context.l;
        _snack(l.homeReceiving(req.files.length, l.isoName(req.sender.alias)));
      }
    }
    _dialogOpen = false;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pairSub?.cancel();
    super.dispose();
  }

  void _snack(String msg, {bool error = false, SnackBarAction? action}) {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? scheme.error : null,
      action: action,
    ));
  }

  /// The FAB: "What do you want to send?" Files / Folder, then the device.
  Future<void> _sendSheet() async {
    final kind = await showSendSheet(context);
    if (kind == null || !mounted) return;
    await (kind == SendKind.folder ? _sendFolderFlow() : _sendFlow());
  }

  /// Tells the user how a send ended: sent, declined, or why it failed
  /// (UX.md 3.3, quick win 4).
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
      SendErrorCode.unknown =>
        l.sendFailed(name),
      final code => localizeSendError(l, code),
    };
    _snack(message,
        error: r.errorCode != SendErrorCode.declined,
        action: r.errorCode == SendErrorCode.declined
            ? null
            : SnackBarAction(
                label: l.homeHelp,
                onPressed: () => showDiagnosisDialog(context)));
  }

  Future<DeviceInfo?> _pickPeer(String title) => showPeerPicker(
      context, AppScope.read(context).peers,
      title: title, onHelp: () => showDiagnosisDialog(context));

  Future<void> _sendFlow({DeviceInfo? to}) async {
    final c = AppScope.read(context);
    List<String> paths;
    try {
      paths = await widget.pickFiles();
    } catch (e) {
      if (mounted) _snack(context.l.errorFilePicker('$e'), error: true);
      return;
    }
    if (paths.isEmpty || !mounted) return;
    final peer =
        to ?? await _pickPeer(context.l.sendPickerTitleFiles(paths.length));
    if (peer == null || !mounted) return;
    final r = await c.sendWithResult(peer, paths);
    if (mounted) _sendResult(peer, r);
  }

  Future<void> _sendFolderFlow({DeviceInfo? to}) async {
    final c = AppScope.read(context);
    String? dir;
    try {
      dir = await widget.pickFolder();
    } catch (e) {
      if (mounted) _snack(context.l.errorFolderPicker('$e'), error: true);
      return;
    }
    if (dir == null || dir.isEmpty || !mounted) return;
    final name = dir
        .split(RegExp(r'[\\/]'))
        .lastWhere((s) => s.isNotEmpty, orElse: () => dir!);
    final l = context.l;
    final peer =
        to ?? await _pickPeer(l.sendPickerTitleFolder(l.isoName(name)));
    if (peer == null || !mounted) return;
    final r = await c.sendWithResult(peer, [dir]);
    if (mounted) _sendResult(peer, r);
  }

  Future<void> _addByIp() async {
    final c = AppScope.read(context);
    final res = await showAddByIpDialog(context);
    if (res == null || !mounted) return;
    final (ip, port) = res;
    final l = context.l;
    final address = l.ltrValue('$ip:$port');
    String? failure;
    try {
      final d = await c.addPeerByIp(ip, port: port);
      if (d != null) {
        _snack(l.addByIpAdded(l.isoName(d.alias)));
      } else {
        failure = l.addByIpNoAnswer(address);
      }
    } catch (e) {
      failure = l.addByIpError(address, '$e');
    }
    if (failure != null && mounted) {
      final diagnose = await showAddFailedDialog(context, failure);
      if (diagnose && mounted) {
        await showDiagnosisDialog(context, targetIp: ip, targetPort: port);
      }
    }
  }

  Future<void> _rescan() async {
    final c = AppScope.read(context);
    try {
      await c.rescan();
      if (mounted) _snack(context.l.homeScanFinished(c.peers.length));
    } catch (e) {
      if (mounted) _snack(context.l.homeScanFailed('$e'), error: true);
    }
  }

  Future<void> _editAlias() async {
    final c = AppScope.read(context);
    final v = await showAliasDialog(context, c.alias);
    if (v != null && v.trim().isNotEmpty) await c.updateSettings(alias: v);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = context.l;
    final discoveryError = c.discoveryError;
    final peersSection = <Widget>[
      // One plain line; the raw error is in the connection check (Help).
      if (discoveryError != null)
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 8),
          child: MaterialBanner(
            key: const Key('discoveryBanner'),
            leading: const Icon(Icons.wifi_off),
            content: Text(l.homeDiscoveryOff),
            actions: [
              TextButton(
                key: const Key('discoveryHelp'),
                onPressed: () => showDiagnosisDialog(context),
                child: Text(l.homeHelp),
              ),
              TextButton(
                key: const Key('dismissDiscoveryBanner'),
                onPressed: c.dismissDiscoveryError,
                child: Text(l.commonDismiss),
              ),
            ],
          ),
        ),
      SectionHeader(l.homeNearbyDevices),
      Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
        child: Wrap(spacing: 4, children: [
          TextButton.icon(
            key: const Key('rescan'),
            onPressed: c.scanning ? null : _rescan,
            icon: c.scanning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            label: Text(l.homeRescan),
          ),
          TextButton.icon(
            key: const Key('addByIp'),
            onPressed: _addByIp,
            icon: const Icon(Icons.add_link),
            label: Text(l.homeAddByIp),
          ),
        ]),
      ),
      if (c.hotspot != null)
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 8),
          child: MaterialBanner(
            key: const Key('hotspotBanner'),
            leading: const Icon(Icons.wifi_tethering),
            content: Text(l.homeHotspotBanner(l.ltrValue(c.hotspot!.ssid))),
            actions: [
              TextButton(
                onPressed: () => openHotspotWizard(context),
                child: Text(l.commonShow),
              ),
              TextButton(
                key: const Key('bannerStopHotspot'),
                onPressed: c.stopHotspot,
                child: Text(l.commonStop),
              ),
            ],
          ),
        ),
      if (c.peers.isEmpty)
        EmptyPeersHelp(
            onDiagnose: () => showDiagnosisDialog(context),
            onHotspot: () => openHotspotWizard(context),
            onCable: () => openCableWizard(context))
      else
        Card(
          child: Column(children: [
            for (final p in c.peers)
              PeerTile(peer: p, onSend: () => _sendFlow(to: p)),
          ]),
        ),
    ];
    final transfersSection = <Widget>[
      if (c.sessions.isNotEmpty) ...[
        SectionHeader(l.homeActivity,
            trailing: TextButton(
                key: const Key('clearFinished'),
                onPressed: c.clearFinished,
                child: Text(l.homeClearFinished))),
        for (final s in c.sessions) TransferSessionCard(session: s),
      ],
    ];
    final activeShares =
        c.shares.where((s) => !s.expired && !s.exhausted).length;
    final sharesRow = <Widget>[
      // Active links as one compact row; the Shares page has the rest.
      if (activeShares > 0)
        Card(
          child: ListTile(
            key: const Key('activeSharesRow'),
            leading: const Icon(Icons.link),
            title: Text(l.homeActiveShares(activeShares)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openShares,
          ),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l.appTitle),
        actions: [
          // A text label where there is room (UX.md 3.1), an icon on phones.
          if (MediaQuery.sizeOf(context).width >= 840)
            TextButton.icon(
              key: const Key('sharesAction'),
              onPressed: _openShares,
              icon: const Icon(Icons.ios_share),
              label: Text(l.homeShareLink),
            )
          else
            IconButton(
              key: const Key('sharesAction'),
              tooltip: l.homeShareLink,
              icon: const Icon(Icons.ios_share),
              onPressed: _openShares,
            ),
          IconButton(
            tooltip: l.settingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => SettingsPage(
                        pickFiles: widget.pickFiles,
                        pickFolder: widget.pickFolder))),
          ),
        ],
      ),
      // One primary action (UX.md 2.1); "Files" or "Folder" in its sheet.
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('sendFab'),
        heroTag: 'send',
        onPressed: _sendSheet,
        icon: const Icon(Icons.upload),
        label: Text(l.homeSend),
      ),
      body: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 840;
        if (!wide) {
          return ListView(
            // Room for the one FAB.
            padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 96),
            children: [
              SelfCard(onEditAlias: _editAlias),
              ...peersSection,
              ...sharesRow,
              ...transfersSection,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 96),
                children: [
                  ...peersSection,
                  ...sharesRow,
                  ...transfersSection,
                ],
              ),
            ),
            SizedBox(
              width: 360,
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 16, 96),
                children: [
                  SelfCard(onEditAlias: _editAlias),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  void _openShares() => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => SharesPage(
              pickFiles: widget.pickFiles, pickFolder: widget.pickFolder)));
}

/// "What do you want to send?" with Files and Folder (UX.md 3.3). Returns
/// null when dismissed.
Future<SendKind?> showSendSheet(BuildContext context) {
  return showModalBottomSheet<SendKind>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final l = ctx.l;
      return SafeArea(
        child: Column(
          key: const Key('sendSheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 8),
              child: Text(l.sendSheetTitle,
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            ListTile(
              key: const Key('sendFiles'),
              leading: const Icon(Icons.upload_file),
              title: Text(l.sendSheetFiles),
              onTap: () => Navigator.pop(ctx, SendKind.files),
            ),
            ListTile(
              key: const Key('sendFolder'),
              leading: const Icon(Icons.drive_folder_upload),
              title: Text(l.sendSheetFolder),
              onTap: () => Navigator.pop(ctx, SendKind.folder),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
