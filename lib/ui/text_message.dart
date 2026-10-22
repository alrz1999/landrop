import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import 'app_controller.dart';
import 'file_opener.dart' show isWebLink;
import 'format.dart';
import 'l10n.dart';
import 'ltr_text.dart';
import 'widgets.dart';

/// "Send text": type or paste a note or a link (at most [maxTextBytes]).
/// Returns the text, or null when cancelled.
Future<String?> showSendTextDialog(BuildContext context) => showDialog<String>(
    context: context, builder: (_) => const _SendTextDialog());

class _SendTextDialog extends StatefulWidget {
  const _SendTextDialog();
  @override
  State<_SendTextDialog> createState() => _SendTextDialogState();
}

class _SendTextDialogState extends State<_SendTextDialog> {
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _tooLong => utf8.encode(_ctrl.text).length > maxTextBytes;
  bool get _canSend => _ctrl.text.trim().isNotEmpty && !_tooLong;

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final p = data?.text;
    if (p == null || p.isEmpty) return;
    final v = _ctrl.value;
    final sel = v.selection.isValid
        ? v.selection
        : TextSelection.collapsed(offset: v.text.length);
    final text = v.text.replaceRange(sel.start, sel.end, p);
    _ctrl.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: sel.start + p.length));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final outer = Directionality.of(context);
    return AlertDialog(
      key: const Key('sendTextDialog'),
      semanticLabel: l.sendTextTitle,
      title: Text(l.sendTextTitle),
      content: SizedBox(
        width: 480,
        child: TextField(
          key: const Key('sendTextField'),
          controller: _ctrl,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          keyboardType: TextInputType.multiline,
          // Persian, English or a link: the field follows what is typed.
          textDirection: firstStrongDirection(_ctrl.text) ?? outer,
          decoration: InputDecoration(
            labelText: l.sendTextLabel,
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
            errorText: _tooLong
                ? l.sendTextTooLong(formatBytes(maxTextBytes, l))
                : null,
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          key: const Key('sendTextPaste'),
          onPressed: _paste,
          icon: const Icon(Icons.content_paste),
          label: Text(l.sendTextPaste),
        ),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.commonCancel)),
        FilledButton(
          key: const Key('sendTextNext'),
          onPressed: _canSend ? () => Navigator.pop(context, _ctrl.text) : null,
          child: Text(l.sendTextNext),
        ),
      ],
    );
  }
}

/// Shows a received text message (PROTOCOL.md "Text messages"): the
/// sender, its trust badge, the text as plain selectable text in its own
/// direction, Copy, "Open link" (an http(s) link only, and only where the
/// [FileOpener] can open things, i.e. not on phones) and "Save as file".
/// Nothing is written to disk unless "Save as file" is chosen.
Future<void> showIncomingTextDialog(BuildContext context, IncomingText msg,
    {SenderTrust trust = SenderTrust.unverified}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _IncomingTextDialog(msg, trust),
  );
}

class _IncomingTextDialog extends StatelessWidget {
  const _IncomingTextDialog(this.msg, this.trust);
  final IncomingText msg;
  final SenderTrust trust;

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l = context.l;
    await Clipboard.setData(ClipboardData(text: msg.text));
    messenger?.showSnackBar(SnackBar(content: Text(l.textCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final c = AppScope.maybeOf(context);
    final sender = msg.request.sender;
    final title = l.textFromTitle(l.isoName(sender.alias));
    final text = msg.text;
    final link = isWebLink(text);
    final canOpen = c?.fileOpener.canOpen ?? false;
    final outer = Directionality.of(context);
    final badge = switch (trust) {
      SenderTrust.trusted => (Icons.verified_user_outlined, l.incomingTrusted),
      SenderTrust.firstTime => (Icons.fiber_new_outlined, l.incomingFirstTime),
      SenderTrust.known => (Icons.history, l.incomingKnown),
      SenderTrust.unverified => (Icons.help_outline, l.incomingUnverified),
      SenderTrust.browser => null,
    };
    return AlertDialog(
      key: const Key('textDialog'),
      semanticLabel: title,
      icon: const Icon(Icons.chat_outlined),
      title: Text(title),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (badge != null)
              Row(
                key: Key('textBadge-${trust.name}'),
                children: [
                  Icon(badge.$1, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Flexible(child: Text(badge.$2, style: t.labelMedium)),
                ],
              ),
            if (msg.auto)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 6),
                child: Text(l.textAutoNotice,
                    key: const Key('textAutoNotice'), style: t.bodySmall),
              ),
            const SizedBox(height: 12),
            Flexible(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  // Plain text only: never markup, never a link widget.
                  child: SelectableText(
                    text,
                    key: const Key('textContent'),
                    style: t.bodyLarge,
                    textDirection: firstStrongDirection(text) ?? outer,
                    textAlign: outer == TextDirection.rtl
                        ? TextAlign.right
                        : TextAlign.left,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('textSave'),
          onPressed: () async {
            final messenger = ScaffoldMessenger.maybeOf(context);
            final path = await c?.saveTextAsFile(text);
            messenger?.showSnackBar(SnackBar(
                content: Text(path == null
                    ? l.textSaveFailed
                    : l.transferSavedTo(l.ltrValue(path)))));
          },
          child: Text(l.textSaveFile),
        ),
        TextButton.icon(
          key: const Key('textCopy'),
          onPressed: () => _copy(context),
          icon: const Icon(Icons.copy),
          label: Text(l.textCopy),
        ),
        if (link && canOpen)
          TextButton.icon(
            key: const Key('textOpenLink'),
            onPressed: () async {
              final messenger = ScaffoldMessenger.maybeOf(context);
              final ok = await c!.fileOpener.openLink(text.trim());
              if (!ok) {
                messenger?.showSnackBar(
                    SnackBar(content: Text(l.textLinkFailed)));
              }
            },
            icon: const Icon(Icons.open_in_new),
            label: Text(l.textOpenLink),
          ),
        FilledButton(
          key: const Key('textClose'),
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonClose),
        ),
      ],
    );
  }
}
