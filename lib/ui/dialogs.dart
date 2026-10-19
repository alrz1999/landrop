import 'package:flutter/material.dart';

import '../core/api.dart';
import 'format.dart';

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
              '${req.sender.ip} · fingerprint ${shortFingerprint(req.sender.fingerprint)}',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final f in req.files)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.insert_drive_file_outlined),
                      title: Text(f.fileName,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Text(formatBytes(f.size)),
                    ),
                ],
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

/// Lets the user choose a peer. Returns null when cancelled.
Future<DeviceInfo?> showPeerPicker(
    BuildContext context, List<DeviceInfo> peers, int fileCount) {
  return showDialog<DeviceInfo>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text('Send $fileCount file${fileCount == 1 ? '' : 's'} to…'),
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
