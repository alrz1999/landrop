import 'package:flutter/material.dart';

import '../core/api.dart';
import 'format.dart';

/// One row of the incoming dialog: a loose file, or a top-level folder with
/// the number and total size of the files below it.
class IncomingEntry {
  IncomingEntry(this.name, {required this.isFolder});
  final String name;
  final bool isFolder;
  int files = 0;
  int bytes = 0;
}

/// Groups offered files by their top-level folder (file names of folder
/// transfers are relative paths with '/'), keeping the offer order.
List<IncomingEntry> summarizeOffers(List<FileOffer> files) {
  final out = <String, IncomingEntry>{};
  for (final f in files) {
    final slash = f.fileName.indexOf('/');
    final isFolder = slash > 0;
    final name = isFolder ? f.fileName.substring(0, slash) : f.fileName;
    final e = out.putIfAbsent('${isFolder ? 'd' : 'f'}:$name',
        () => IncomingEntry(name, isFolder: isFolder));
    e.files++;
    e.bytes += f.size;
  }
  return out.values.toList();
}

/// Accept/Decline dialog for an incoming request. Returns true on accept.
Future<bool> showIncomingDialog(BuildContext context, IncomingRequest req) async {
  final total = req.files.fold<int>(0, (a, f) => a + f.size);
  final res = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.download),
      title: Text('${req.sender.alias} wants to send you '
          '${req.files.length} file${req.files.length == 1 ? '' : 's'}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              req.sender.deviceType == 'web'
                  ? 'Web browser at ${req.sender.ip}'
                      '${req.sender.deviceModel == null ? '' : ' · ${req.sender.deviceModel}'}'
                  : '${req.sender.ip} · fingerprint ${shortFingerprint(req.sender.fingerprint)}',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final e in summarizeOffers(req.files))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(e.isFolder
                            ? Icons.folder_outlined
                            : Icons.insert_drive_file_outlined),
                        title: Text(e.isFolder ? '${e.name}/' : e.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: e.isFolder
                            ? Text('${e.files} file${e.files == 1 ? '' : 's'}')
                            : null,
                        trailing: Text(formatBytes(e.bytes)),
                      ),
                  ],
                ),
              ),
            ),
            const Divider(),
            Text('Total: ${formatBytes(total)}',
                style: Theme.of(ctx).textTheme.labelLarge),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Decline'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Accept'),
        ),
      ],
    ),
  );
  return res ?? false;
}

/// Approve/Decline for a browser that wants to pair. Returns true on
/// approve. Closes itself (false) when the core times the request out.
Future<bool> showWebPairingDialog(
    BuildContext context, WebPairingRequest req) async {
  final res = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _PairingDialog(req),
  );
  return res ?? false;
}

class _PairingDialog extends StatefulWidget {
  const _PairingDialog(this.req);
  final WebPairingRequest req;
  @override
  State<_PairingDialog> createState() => _PairingDialogState();
}

class _PairingDialogState extends State<_PairingDialog> {
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    // Timed out (or answered elsewhere) while the dialog is open.
    widget.req.decision.future.then((_) => _close(false));
  }

  void _close(bool approve) {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.pop(context, approve);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final r = widget.req;
    return AlertDialog(
      key: const Key('pairingDialog'),
      icon: const Icon(Icons.public),
      title: const Text('Allow a browser to send you files?'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${r.userAgent} · ${r.remoteIp}', style: t.bodyMedium),
            const SizedBox(height: 12),
            Text('Code shown in the browser', style: t.labelMedium),
            Semantics(
              label: 'Pairing code ${r.code.split('').join(' ')}',
              child: ExcludeSemantics(
                child: Text(r.code,
                    key: const Key('pairingCode'),
                    style: t.displaySmall?.copyWith(
                        letterSpacing: 8, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Approve only if the browser shows the same code. For the next '
              'hour it can then offer you files; you still accept every '
              'transfer.',
              style: t.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('declinePairing'),
          onPressed: () => _close(false),
          child: const Text('Decline'),
        ),
        FilledButton(
          key: const Key('approvePairing'),
          onPressed: () => _close(true),
          child: const Text('Approve'),
        ),
      ],
    );
  }
}

/// Asks for an IP (optionally ip:port). Returns (ip, port) or null.
Future<(String, int)?> showAddByIpDialog(BuildContext context) {
  return showDialog<(String, int)>(
    context: context,
    builder: (ctx) => const _AddByIpDialog(),
  );
}

class _AddByIpDialog extends StatefulWidget {
  const _AddByIpDialog();
  @override
  State<_AddByIpDialog> createState() => _AddByIpDialogState();
}

class _AddByIpDialogState extends State<_AddByIpDialog> {
  final _ctrl = TextEditingController();
  String? _error;

  static final _re = RegExp(r'^(\d{1,3}(?:\.\d{1,3}){3})(?::(\d{1,5}))?$');

  void _submit() {
    final m = _re.firstMatch(_ctrl.text.trim());
    final octetsOk = m != null &&
        m.group(1)!.split('.').every((o) => int.parse(o) <= 255);
    final port = m?.group(2) == null ? 53317 : int.parse(m!.group(2)!);
    if (!octetsOk || port < 1 || port > 65535) {
      setState(() => _error = 'Enter an IPv4 address, e.g. 192.168.1.20');
      return;
    }
    Navigator.pop(context, (m.group(1)!, port));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add device by IP'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(
          labelText: 'IP address',
          hintText: '192.168.1.20 or 192.168.1.20:53317',
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}

/// Shown when Add by IP found nothing. Returns true for "Diagnose this IP".
Future<bool> showAddFailedDialog(BuildContext context, String message) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const Key('addFailedDialog'),
      icon: const Icon(Icons.link_off),
      title: const Text('Device not found'),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Close')),
        FilledButton(
          key: const Key('diagnoseIp'),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Diagnose this IP'),
        ),
      ],
    ),
  );
  return res ?? false;
}

/// Lets the user choose a peer. Returns null when cancelled.
Future<DeviceInfo?> showPeerPicker(
    BuildContext context, List<DeviceInfo> peers, int fileCount,
    {String? label}) {
  return showDialog<DeviceInfo>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(
          'Send ${label ?? '$fileCount file${fileCount == 1 ? '' : 's'}'} to…'),
      children: [
        if (peers.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No devices found yet. Try "Rescan" or "Add by IP".'),
          ),
        for (final p in peers)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, p),
            child: ListTile(
              leading: Icon(deviceIcon(p.deviceType)),
              title: Text(p.alias),
              subtitle: Text('${p.ip}:${p.port}'),
            ),
          ),
      ],
    ),
  );
}

Future<String?> showAliasDialog(BuildContext context, String current) {
  final ctrl = TextEditingController(text: current);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Device name'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLength: 40,
        decoration: const InputDecoration(labelText: 'Name shown to others'),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Save')),
      ],
    ),
  );
}
