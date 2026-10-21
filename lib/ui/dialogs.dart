import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import 'digits.dart';
import 'format.dart';
import 'l10n.dart';
import 'ltr_text.dart';
import 'widgets.dart' show deviceKindLabel;

/// The last two parts of [path] ("Download/LanDrop"), for showing where
/// files are saved without the whole path.
String shortFolder(String path) {
  final parts =
      path.split(RegExp(r'[\\/]')).where((p) => p.isNotEmpty).toList();
  if (parts.length <= 2) return path;
  return parts.sublist(parts.length - 2).join('/');
}

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
/// The line under the title is the sender's kind ("Phone"), not its address
/// or security code; only browsers show their IP (UX.md 7, quick win 2).
/// With [saveDir] the dialog says where the files will go.
Future<bool> showIncomingDialog(BuildContext context, IncomingRequest req,
    {String? saveDir}) async {
  final total = req.files.fold<int>(0, (a, f) => a + f.size);
  final res = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final l = ctx.l;
      final t = Theme.of(ctx).textTheme;
      final sender = req.sender;
      final name = l.isoName(sender.alias);
      return AlertDialog(
        key: const Key('incomingDialog'),
        icon: const Icon(Icons.download),
        title: Text(l.incomingTitle(name, req.files.length)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sender.deviceType == 'web'
                    ? (sender.deviceModel == null
                        ? l.incomingFromBrowser(l.ltrValue(sender.ip))
                        : l.incomingFromBrowserModel(l.ltrValue(sender.ip),
                            l.isoName(sender.deviceModel!)))
                    : [
                        deviceKindLabel(l, sender.deviceType),
                        if (sender.deviceModel != null)
                          l.isoName(sender.deviceModel!),
                      ].join(' · '),
                key: const Key('incomingSender'),
                style: t.bodySmall,
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
                          title: AutoDirText(
                              e.isFolder ? '${e.name}/' : e.name,
                              fileName: !e.isFolder,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          subtitle: e.isFolder
                              ? Text(l.fileCount(e.files))
                              : null,
                          trailing: Text(formatBytes(e.bytes, l)),
                        ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              Text(l.incomingTotal(formatBytes(total, l)),
                  style: t.labelLarge),
              if (saveDir != null && saveDir.isNotEmpty)
                Text(l.incomingSavesTo(l.ltrValue(shortFolder(saveDir))),
                    key: const Key('incomingSavesTo'), style: t.bodySmall),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.commonDecline),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.commonAccept),
          ),
        ],
      );
    },
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
    final l = context.l;
    final r = widget.req;
    return AlertDialog(
      key: const Key('pairingDialog'),
      icon: const Icon(Icons.public),
      title: Text(l.pairingTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${l.isoName(r.userAgent)} · ${l.ltrValue(r.remoteIp)}',
                style: t.bodyMedium),
            const SizedBox(height: 12),
            Text(l.pairingCodeLabel, style: t.labelMedium),
            // The code stays Latin digits and left to right: it is compared
            // with the browser (UX.md 4.6).
            Semantics(
              label: l.pairingCodeSemantics(r.code.split('').join(' ')),
              child: ExcludeSemantics(
                child: LtrText(r.code,
                    key: const Key('pairingCode'),
                    style: t.displaySmall?.copyWith(
                        letterSpacing: 8, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            Text(l.pairingBody, style: t.bodySmall),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('declinePairing'),
          onPressed: () => _close(false),
          child: Text(l.commonDecline),
        ),
        FilledButton(
          key: const Key('approvePairing'),
          onPressed: () => _close(true),
          child: Text(l.pairingApprove),
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
    // Persian/Arabic-Indic digits typed on a Persian keyboard count too.
    final m = _re.firstMatch(normalizeDigits(_ctrl.text).trim());
    final octetsOk = m != null &&
        m.group(1)!.split('.').every((o) => int.parse(o) <= 255);
    final port = m?.group(2) == null ? 53317 : int.parse(m!.group(2)!);
    if (!octetsOk || port < 1 || port > 65535) {
      setState(() =>
          _error = context.l.addByIpInvalid(context.l.ltrValue('192.168.1.20')));
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
    final l = context.l;
    return AlertDialog(
      title: Text(l.addByIpTitle),
      content: TextField(
        key: const Key('addByIpField'),
        controller: _ctrl,
        autofocus: true,
        keyboardType: TextInputType.url,
        // An address is typed and read left to right, with Latin digits
        // (UX.md 4.5 rule 5, 4.6).
        textDirection: TextDirection.ltr,
        inputFormatters: [latinDigitsFormatter],
        decoration: InputDecoration(
          labelText: l.addByIpLabel,
          hintText: l.addByIpHint('192.168.1.20', '192.168.1.20:53317'),
          hintTextDirection: TextDirection.ltr,
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.commonCancel)),
        FilledButton(onPressed: _submit, child: Text(l.addByIpAdd)),
      ],
    );
  }
}

/// Turns Persian/Arabic-Indic digits into Latin ones while typing, for
/// technical fields (IP, port, pairing code). Keeps the length, so the
/// cursor stays where it was.
final latinDigitsFormatter = TextInputFormatter.withFunction(
    (oldValue, newValue) =>
        newValue.copyWith(text: normalizeDigits(newValue.text)));

/// Shown when Add by IP found nothing. Returns true for "Diagnose this IP".
Future<bool> showAddFailedDialog(BuildContext context, String message) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final l = ctx.l;
      return AlertDialog(
        key: const Key('addFailedDialog'),
        icon: const Icon(Icons.link_off),
        title: Text(l.addFailedTitle),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.commonClose)),
          FilledButton(
            key: const Key('diagnoseIp'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.addFailedDiagnose),
          ),
        ],
      );
    },
  );
  return res ?? false;
}

/// Lets the user choose a peer. Returns null when cancelled. [title] is the
/// dialog title ("Send 2 files to…"). With no peers it offers [onHelp]
/// ("Help me connect") instead of a dead end.
Future<DeviceInfo?> showPeerPicker(
    BuildContext context, List<DeviceInfo> peers,
    {required String title, VoidCallback? onHelp}) async {
  var help = false;
  final picked = await showDialog<DeviceInfo>(
    context: context,
    builder: (ctx) {
      final l = ctx.l;
      return SimpleDialog(
        key: const Key('peerPicker'),
        title: Text(title),
        children: [
          if (peers.isEmpty) ...[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 12, 24, 8),
              child: Text(l.pickerEmpty),
            ),
            if (onHelp != null)
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    key: const Key('pickerHelp'),
                    onPressed: () {
                      help = true;
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.troubleshoot),
                    label: Text(l.pickerHelp),
                  ),
                ),
              ),
          ],
          for (final p in peers)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, p),
              child: ListTile(
                leading: Icon(deviceIcon(p.deviceType)),
                title: AutoDirText(p.alias,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(deviceKindLabel(l, p.deviceType)),
              ),
            ),
        ],
      );
    },
  );
  if (help) onHelp?.call();
  return picked;
}

Future<String?> showAliasDialog(BuildContext context, String current) {
  final ctrl = TextEditingController(text: current);
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      final l = ctx.l;
      return AlertDialog(
        title: Text(l.settingsDeviceName),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 40,
          decoration: InputDecoration(labelText: l.aliasLabel),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: Text(l.commonSave)),
        ],
      );
    },
  );
}
