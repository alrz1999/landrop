import 'dart:async';
import 'dart:collection';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/api.dart';
import 'dialogs.dart';
import 'settings_page.dart';
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

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.pickFiles = defaultPickFiles});
  final FilesPicker pickFiles;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  StreamSubscription<IncomingRequest>? _sub;
  final Queue<IncomingRequest> _pending = Queue();
  bool _dialogOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sub ??= AppScope.read(context).incomingRequests.listen((r) {
      _pending.add(r);
      _drainIncoming();
    });
  }

  Future<void> _drainIncoming() async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    while (_pending.isNotEmpty && mounted) {
      final req = _pending.removeFirst();
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

  Future<void> _addByIp() async {
    final c = AppScope.read(context);
    final res = await showAddByIpDialog(context);
    if (res == null) return;
    final (ip, port) = res;
    try {
      final d = await c.addPeerByIp(ip, port: port);
      _snack(d == null
          ? 'No LanDrop device answered at $ip:$port'
          : 'Added ${d.alias}', error: d == null);
    } catch (e) {
      _snack('Could not reach $ip:$port — $e', error: true);
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
    final peersSection = <Widget>[
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
        const EmptyPeersHelp()
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('LanDrop'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('sendFab'),
        onPressed: _sendFlow,
        icon: const Icon(Icons.upload_file),
        label: const Text('Send files'),
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
                children: [...peersSection, ...transfersSection],
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
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}
