import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_controller.dart';
import 'format.dart';
import 'l10n.dart';
import 'ltr_text.dart';
import 'widgets.dart';

/// Opens the History page.
Future<void> openHistory(BuildContext context) => Navigator.push(
    context, MaterialPageRoute(builder: (_) => const HistoryPage()));

/// "From Sara" / "To Work Laptop".
String historyTitle(AppLocalizations l, HistoryEntry e) => e.incoming
    ? l.transferFrom(l.isoName(e.peerAlias))
    : l.transferTo(l.isoName(e.peerAlias));

/// What was sent: "Text message", one name, or "a.jpg and 3 more".
String historyWhat(AppLocalizations l, HistoryEntry e) {
  if (e.text) return l.textMessage;
  if (e.fileNames.isEmpty) return l.fileCount(e.fileCount);
  final first = l.isoName(e.fileNames.first);
  return e.fileCount <= 1 ? first : l.historyFilesMore(first, e.fileCount - 1);
}

/// Result in words and as an icon (never colour alone).
(IconData, String) historyResult(AppLocalizations l, HistoryEntry e) =>
    switch (e.state) {
      'done' => (Icons.check_circle, l.transferDone),
      'declined' => (
          Icons.block,
          l.transferDeclined(l.isoName(e.peerAlias))
        ),
      'cancelled' => (Icons.cancel_outlined, l.transferCancelled),
      _ => (Icons.error_outline, l.transferFailedPlain),
    };

/// Whether a received entry's files are still where they were saved.
bool historyPathExists(String? path) {
  if (path == null) return false;
  try {
    return FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound;
  } catch (_) {
    return false;
  }
}

/// Past transfers on this device (newest first), grouped "Today",
/// "Yesterday" and by date; a privacy note; "Clear history" with a
/// confirmation. Tapping an entry shows its details.
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, this.now});

  /// Test seam for the "Today" / "Yesterday" groups.
  final DateTime? now;

  Future<void> _clear(BuildContext context, AppController c) async {
    final l = context.l;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('confirmClearHistory'),
        semanticLabel: l.historyClear,
        title: Text(l.historyClear),
        content: Text(l.historyClearBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.commonCancel)),
          FilledButton(
              key: const Key('confirmClearHistoryOk'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.historyClearConfirm)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await c.clearHistory();
    messenger.showSnackBar(SnackBar(content: Text(l.historyCleared)));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final entries = c.history;
    final children = <Widget>[
      Card(
        key: const Key('historyPrivacy'),
        color: scheme.surfaceContainerHighest,
        child: ListTile(
          leading: const Icon(Icons.lock_outline),
          title: Text(l.historyPrivacy, style: t.bodyMedium),
        ),
      ),
      if (!c.keepHistory || entries.isEmpty)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(c.keepHistory ? l.historyEmpty : l.historyOff,
              key: const Key('historyEmpty'),
              textAlign: TextAlign.center,
              style: t.bodyMedium),
        ),
    ];
    String? day;
    for (final e in entries) {
      final d = formatDay(e.at, l, now: now);
      if (d != day) {
        day = d;
        children.add(SectionHeader(d));
      }
      final (icon, result) = historyResult(l, e);
      children.add(Card(
        child: ListTile(
          key: Key('history-${e.id}'),
          leading: Icon(e.incoming ? Icons.download : Icons.upload,
              color: scheme.primary),
          title: Text(historyTitle(l, e),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            [
              historyWhat(l, e),
              formatBytes(e.totalBytes, l),
              formatClock(e.at, l),
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Tooltip(
            message: result,
            child: Icon(icon,
                semanticLabel: result,
                color: e.state == 'done' ? scheme.primary : scheme.error),
          ),
          onTap: () => showHistoryDetails(context, e),
        ),
      ));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l.historyTitle),
        actions: [
          if (entries.isNotEmpty)
            IconButton(
              key: const Key('clearHistory'),
              tooltip: l.historyClear,
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _clear(context, c),
            ),
        ],
      ),
      body: Semantics(
        label: l.historyTitle,
        explicitChildNodes: true,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              key: const Key('historyPage'),
              padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 24),
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// Details of one history entry: who, when, result, size, files and, for
/// received files that still exist, Open / Show in folder (desktops) or
/// the path with Copy (phones).
Future<void> showHistoryDetails(BuildContext context, HistoryEntry e) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final l = ctx.l;
      final t = Theme.of(ctx).textTheme;
      final c = AppScope.of(ctx);
      final (icon, result) = historyResult(l, e);
      final path = e.savedPath;
      final exists = e.incoming && historyPathExists(path);
      final canOpen = c.fileOpener.canOpen;
      Widget row(String label, Widget value, {Key? key}) => Padding(
            key: key,
            padding: const EdgeInsetsDirectional.fromSTEB(24, 6, 24, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.labelMedium),
                const SizedBox(height: 2),
                value,
              ],
            ),
          );
      final shown = e.fileNames.take(20).toList();
      final more = e.fileCount - shown.length;
      return SafeArea(
        child: Semantics(
          label: l.historyDetailsSemantics,
          explicitChildNodes: true,
          child: SingleChildScrollView(
            key: const Key('historyDetails'),
            padding: const EdgeInsetsDirectional.only(bottom: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding:
                      const EdgeInsetsDirectional.symmetric(horizontal: 24),
                  leading:
                      Icon(e.incoming ? Icons.download : Icons.upload),
                  title: Text(historyTitle(l, e), style: t.titleMedium),
                ),
                row(l.historyWhen, Text(formatWhen(e.at, l))),
                row(
                    l.historyResult,
                    Row(children: [
                      Icon(icon, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                          child: Text(result,
                              key: const Key('historyResult'))),
                    ])),
                row(l.historySize, Text(formatBytes(e.totalBytes, l))),
                row(
                    e.text ? l.textMessage : l.historyFiles,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!e.text)
                          for (final n in shown)
                            AutoDirText(n,
                                fileName: true,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                        if (!e.text && more > 0) Text(l.historyMoreFiles(more)),
                      ],
                    )),
                if (e.incoming && path != null)
                  row(
                      l.historySavedIn,
                      exists
                          ? LtrText(path,
                              key: const Key('historySavedPath'),
                              selectable: true)
                          : Text(l.historyGone,
                              key: const Key('historyGone'))),
                if (exists)
                  Padding(
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      children: [
                        if (canOpen) ...[
                          TextButton.icon(
                            key: const Key('historyReveal'),
                            onPressed: () => c.fileOpener.reveal(path!),
                            icon: const Icon(Icons.folder_open),
                            label: Text(l.transferShowInFolder),
                          ),
                          FilledButton.tonalIcon(
                            key: const Key('historyOpen'),
                            onPressed: () => c.fileOpener.open(path!),
                            icon: const Icon(Icons.open_in_new),
                            label: Text(l.transferOpen),
                          ),
                        ] else
                          TextButton.icon(
                            key: const Key('historyCopyPath'),
                            onPressed: () async {
                              final m = ScaffoldMessenger.maybeOf(ctx);
                              await Clipboard.setData(
                                  ClipboardData(text: path!));
                              m?.showSnackBar(SnackBar(
                                  content: Text(l.transferPathCopied)));
                            },
                            icon: const Icon(Icons.copy),
                            label: Text(l.transferCopyPath),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
