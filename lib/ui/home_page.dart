import 'dart:async';
import 'dart:collection';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/api.dart';
import 'diagnosis_dialog.dart';
import 'dialogs.dart';
import 'settings_page.dart';
import 'shares.dart';
import 'widgets.dart';

/// Picks files to send. Overridable for tests.
typedef FilesPicker = Future<List<String>> Function();

Future<List<String>> defaultPickFiles() async {
  final files = await FilePicker.pickFiles(dialogTitle: 'Choose files to send');
  return [
    for (final f in files)
      if (f.path != null) f.path!,
  ];
}

/// Picks a folder to send. Overridable for tests.
typedef FolderPicker = Future<String?> Function();

Future<String?> defaultPickFolder() =>
    FilePicker.getDirectoryPath(dialogTitle: 'Choose a folder to send');

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
      final ok = await showIncomingDialog(context, req);
      if (!mounted) break;
      AppScope.read(context).respond(req, ok);
      if (ok) {
        _snack('Receiving ${req.files.length} file(s) from ${req.sender.alias}');
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

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? scheme.error : null,
    ));
  }

  Future<void> _sendFlow({DeviceInfo? to}) async {
    final c = AppScope.read(context);
    List<String> paths;
    try {
      paths = await widget.pickFiles();
    } catch (e) {
      _snack('Could not open file picker: $e', error: true);
      return;
    }
    if (paths.isEmpty || !mounted) return;
    final peer = to ?? await showPeerPicker(context, c.peers, paths.length);
    if (peer == null) return;
    final ok = await c.send(peer, paths);
    _snack(
      ok
          ? 'Sent ${paths.length} file(s) to ${peer.alias}'
          : 'Sending to ${peer.alias} failed or was declined',
      error: !ok,
    );
  }

  Future<void> _sendFolderFlow({DeviceInfo? to}) async {
    final c = AppScope.read(context);
    String? dir;
    try {
      dir = await widget.pickFolder();
    } catch (e) {
      _snack('Could not open folder picker: $e', error: true);
      return;
    }
    if (dir == null || dir.isEmpty || !mounted) return;
    final name = dir
        .split(RegExp(r'[\\/]'))
        .lastWhere((s) => s.isNotEmpty, orElse: () => dir!);
    final peer = to ??
        await showPeerPicker(context, c.peers, 1, label: 'folder "$name"');
    if (peer == null) return;
    final ok = await c.send(peer, [dir]);
    _snack(
      ok
          ? 'Sent folder $name to ${peer.alias}'
          : 'Sending to ${peer.alias} failed or was declined',
      error: !ok,
    );
  }

  Future<void> _addByIp() async {
    final c = AppScope.read(context);
    final res = await showAddByIpDialog(context);
    if (res == null) return;
    final (ip, port) = res;
    String? failure;
    try {
      final d = await c.addPeerByIp(ip, port: port);
      if (d != null) {
        _snack('Added ${d.alias}');
      } else {
        failure = 'No LanDrop device answered at $ip:$port.';
      }
    } catch (e) {
      failure = 'Could not reach $ip:$port — $e';
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
      _snack('Scan finished: ${c.peers.length} device(s) found');
    } catch (e) {
      _snack('Scan failed: $e', error: true);
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
    final discoveryError = c.discoveryError;
    final peersSection = <Widget>[
      if (discoveryError != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: MaterialBanner(
            key: const Key('discoveryBanner'),
            leading: const Icon(Icons.wifi_off),
            content: Text('Automatic discovery is unavailable: '
                '$discoveryError. Use Rescan or Add by IP.'),
            actions: [
              TextButton(
                key: const Key('dismissDiscoveryBanner'),
                onPressed: c.dismissDiscoveryError,
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ),
      const SectionHeader('Nearby devices'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
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
            label: const Text('Rescan network'),
          ),
          TextButton.icon(
            key: const Key('addByIp'),
            onPressed: _addByIp,
            icon: const Icon(Icons.add_link),
            label: const Text('Add by IP'),
          ),
        ]),
      ),
      if (c.peers.isEmpty)
        EmptyPeersHelp(onDiagnose: () => showDiagnosisDialog(context))
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
        SectionHeader('Transfers',
            trailing: TextButton(
                onPressed: c.clearFinished, child: const Text('Clear done'))),
        for (final s in c.sessions) TransferSessionCard(session: s),
      ],
    ];
    final sharesSection = SharesSection(
        pickFiles: widget.pickFiles, pickFolder: widget.pickFolder);

    return Scaffold(
      appBar: AppBar(
        title: const Text('LanDrop'),
        actions: [
          IconButton(
            key: const Key('sharesAction'),
            tooltip: 'Shares',
            icon: const Icon(Icons.ios_share),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => SharesPage(
                        pickFiles: widget.pickFiles,
                        pickFolder: widget.pickFolder))),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
      floatingActionButton: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.end,
        children: [
          FloatingActionButton.extended(
            key: const Key('sendFolderFab'),
            heroTag: 'sendFolder',
            onPressed: _sendFolderFlow,
            icon: const Icon(Icons.drive_folder_upload),
            label: const Text('Send folder'),
          ),
          FloatingActionButton.extended(
            key: const Key('sendFab'),
            heroTag: 'sendFiles',
            onPressed: _sendFlow,
            icon: const Icon(Icons.upload_file),
            label: const Text('Send files'),
          ),
        ],
      ),
      body: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 840;
        if (!wide) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            children: [
              SelfCard(onEditAlias: _editAlias),
              ...peersSection,
              ...transfersSection,
              sharesSection,
              const SectionHeader('Use from a browser'),
              const WebAccessCard(),
              const SectionHeader('Connect manually'),
              const QrCard(),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 96),
                children: [
                  ...peersSection,
                  ...transfersSection,
                  sharesSection,
                ],
              ),
            ),
            SizedBox(
              width: 360,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 96),
                children: [
                  SelfCard(onEditAlias: _editAlias),
                  const SectionHeader('Connect manually'),
                  const QrCard(),
                  const SectionHeader('Use from a browser'),
                  const WebAccessCard(),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}
