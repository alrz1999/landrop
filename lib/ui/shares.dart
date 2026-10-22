// Sharing with browsers (DESIGN.md 4): create a share, list active shares,
// and the "Use from a browser" card.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/api.dart';
import 'format.dart';
import 'l10n.dart';
import 'ltr_text.dart';
import 'pickers.dart';
import 'widgets.dart';

typedef ShareOptions = ({Duration? ttl, int? maxDownloads, bool nearby});

/// "14 min", "1 h 20 min", "less than a minute" (Persian digits in fa).
String _remaining(AppLocalizations l, Duration d) => d.inMinutes < 1
    ? l.shareLessThanMinute
    : formatDuration(Duration(minutes: d.inMinutes), l);

/// Asks how long and how often a share may be used. Null when cancelled.
/// [title] is the dialog title ("Share 2 files").
Future<ShareOptions?> showShareOptionsDialog(
  BuildContext context,
  String title,
) {
  return showDialog<ShareOptions>(
    context: context,
    builder: (_) => _ShareOptionsDialog(title),
  );
}

class _ShareOptionsDialog extends StatefulWidget {
  const _ShareOptionsDialog(this.title);
  final String title;
  @override
  State<_ShareOptionsDialog> createState() => _ShareOptionsDialogState();
}

class _ShareOptionsDialogState extends State<_ShareOptionsDialog> {
  static const _ttls = <(String, Duration?)>[
    ('ttl-15m', Duration(minutes: 15)),
    ('ttl-1h', Duration(hours: 1)),
    ('ttl-24h', Duration(hours: 24)),
    ('ttl-none', null),
  ];
  static const _limits = <(String, int?)>[
    ('max-none', null),
    ('max-1', 1),
    ('max-5', 5),
  ];
  int _ttl = 1;
  int _limit = 0;
  bool _nearby = false; // default OFF

  String _ttlLabel(AppLocalizations l, Duration? d) => switch (d?.inMinutes) {
    null => l.shareTtlNone,
    60 => l.shareTtl1h,
    1440 => l.shareTtl24h,
    _ => formatDuration(d!, l),
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l = context.l;
    return AlertDialog(
      key: const Key('shareOptionsDialog'),
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.shareLinkWorksFor, style: t.labelLarge),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final (i, (key, ttl)) in _ttls.indexed)
                    ChoiceChip(
                      key: Key(key),
                      label: Text(_ttlLabel(l, ttl)),
                      selected: _ttl == i,
                      onSelected: (_) => setState(() => _ttl = i),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(l.shareDownloadsAllowed, style: t.labelLarge),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final (i, (key, max)) in _limits.indexed)
                    ChoiceChip(
                      key: Key(key),
                      label: Text(
                        max == null ? l.shareUnlimited : l.digits(max),
                      ),
                      selected: _limit == i,
                      onSelected: (_) => setState(() => _limit = i),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 8),
              SwitchListTile(
                key: const Key('shareNearbyToggle'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.shareShowNearby),
                subtitle: Text(l.shareShowNearbyHint),
                value: _nearby,
                onChanged: (v) => setState(() => _nearby = v),
              ),
              const SizedBox(height: 8),
              Text(l.shareOptionsNote, style: t.bodySmall),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          key: const Key('confirmShare'),
          onPressed: () => Navigator.pop<ShareOptions>(context, (
            ttl: _ttls[_ttl].$2,
            maxDownloads: _limits[_limit].$2,
            nearby: _nearby,
          )),
          child: Text(l.shareConfirm),
        ),
      ],
    );
  }
}

/// Pick files (or a folder), choose limits, create the share.
Future<void> startShareFlow(
  BuildContext context, {
  required Future<List<String>> Function() pickFiles,
  required Future<String?> Function() pickFolder,
  bool folder = false,
}) async {
  final c = AppScope.read(context);
  final l = context.l;
  final messenger = ScaffoldMessenger.of(context);
  void snack(String m) => messenger.showSnackBar(SnackBar(content: Text(m)));
  List<String> paths;
  try {
    if (folder) {
      final d = await pickFolderTitled(pickFolder, l.pickFolderTitle);
      paths = d == null || d.isEmpty ? const [] : [d];
    } else {
      paths = await pickFilesTitled(pickFiles, l.pickFilesTitle);
    }
  } catch (e) {
    snack(l.errorPicker('$e'));
    return;
  }
  if (paths.isEmpty || !context.mounted) return;
  final name = folder
      ? l.isoName(
          paths.single
              .split(RegExp(r'[\\/]'))
              .lastWhere((s) => s.isNotEmpty, orElse: () => paths.single),
        )
      : '';
  final opts = await showShareOptionsDialog(
    context,
    folder
        ? l.shareOptionsTitleFolder(name)
        : l.shareOptionsTitleFiles(paths.length),
  );
  if (opts == null) return;
  try {
    c.createShare(
      paths,
      ttl: opts.ttl,
      maxDownloads: opts.maxDownloads,
      nearby: opts.nearby,
    );
    snack(
      folder ? l.shareCreatedFolder(name) : l.shareCreatedFiles(paths.length),
    );
  } catch (e) {
    snack(l.errorShare('$e'));
  }
}

/// One active share: link, QR, what is left, copy and stop.
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.share});
  final Share share;

  @override
  Widget build(BuildContext context) {
    final s = share;
    final c = AppScope.read(context);
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final link = s.httpUrl ?? s.url;
    final first = s.files.first.name;
    final String time;
    if (s.expiresAt == null) {
      time = l.shareUntilStopped;
    } else if (s.expired) {
      time = l.shareExpired;
    } else {
      time = l.shareEndsIn(
        _remaining(l, s.expiresAt!.difference(DateTime.now())),
      );
    }
    final downloads = s.maxDownloads == null
        ? l.shareUnlimitedDownloads
        : s.exhausted
        ? l.shareLimitReached
        : l.shareDownloadsLeft(s.downloadsLeft ?? 0, s.maxDownloads!);
    return Card(
      key: Key('share-${s.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (s.files.length == 1)
                        AutoDirText(
                          first,
                          fileName: true,
                          style: t.titleSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        )
                      else
                        Text(
                          l.shareTitleMore(
                            l.isoName(middleEllipsis(first)),
                            s.files.length - 1,
                          ),
                          style: t.titleSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      Text(
                        '${l.fileCount(s.files.length)}'
                        ' · ${formatBytes(s.totalBytes, l)}',
                        style: t.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        time,
                        key: Key('shareTime-${s.id}'),
                        style: t.bodySmall,
                      ),
                      Text(
                        downloads,
                        key: Key('shareDownloads-${s.id}'),
                        style: t.bodySmall?.copyWith(
                          color: s.exhausted ? scheme.error : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  label: l.shareQrSemantics,
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(4),
                    child: QrImageView(
                      data: link,
                      size: 112,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LtrText(
              link,
              key: Key('shareUrl-${s.id}'),
              style: t.bodySmall,
              selectable: true,
            ),
            if (s.httpUrl != null)
              Text(
                l.shareHttpWarning,
                style: t.bodySmall?.copyWith(color: scheme.error),
              ),
            SwitchListTile(
              key: Key('nearbyToggle-${s.id}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(l.shareShowNearby),
              subtitle: Text(l.shareShowNearbyHint),
              value: s.nearby,
              onChanged: (v) => c.setShareNearby(s.id, v),
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  key: Key('copyShare-${s.id}'),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: link));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.l.shareLinkCopied)),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(l.shareCopyLink),
                ),
                OutlinedButton.icon(
                  key: Key('stopShare-${s.id}'),
                  onPressed: () => c.revokeShare(s.id),
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: Text(l.shareStop),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Send a link": active shares plus "Share files" / "Share folder"
/// buttons. Rebuilds every 30 s so remaining times stay current.
class SharesSection extends StatefulWidget {
  const SharesSection({
    super.key,
    required this.pickFiles,
    required this.pickFolder,
  });
  final FilesPicker pickFiles;
  final FolderPicker pickFolder;

  @override
  State<SharesSection> createState() => _SharesSectionState();
}

class _SharesSectionState extends State<SharesSection> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = context.l;
    final t = Theme.of(context).textTheme;
    return Column(
      key: const Key('sendLinkSection'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(l.shareSendLinkTitle),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 4),
          child: Text(l.shareSendLinkBody, style: t.bodyMedium),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
          child: Wrap(
            spacing: 4,
            children: [
              FilledButton.tonalIcon(
                key: const Key('shareFiles'),
                onPressed: () => startShareFlow(
                  context,
                  pickFiles: widget.pickFiles,
                  pickFolder: widget.pickFolder,
                ),
                icon: const Icon(Icons.ios_share),
                label: Text(l.shareFiles),
              ),
              TextButton.icon(
                key: const Key('shareFolder'),
                onPressed: () => startShareFlow(
                  context,
                  pickFiles: widget.pickFiles,
                  pickFolder: widget.pickFolder,
                  folder: true,
                ),
                icon: const Icon(Icons.folder_shared_outlined),
                label: Text(l.shareFolder),
              ),
            ],
          ),
        ),
        if (c.shares.isEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
            child: Text(l.shareNothingShared, style: t.bodySmall),
          )
        else
          for (final s in c.shares.reversed) ShareCard(share: s),
      ],
    );
  }
}

/// Shares screen (app bar, and Settings): "Send a link" (others download
/// from me) and "Use from a browser" (others send to me), UX.md 3.9.
class SharesPage extends StatelessWidget {
  const SharesPage({
    super.key,
    this.pickFiles = defaultPickFiles,
    this.pickFolder = defaultPickFolder,
  });
  final FilesPicker pickFiles;
  final FolderPicker pickFolder;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Scaffold(
      appBar: AppBar(title: Text(l.sharesTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 24),
            children: [
              SharesSection(pickFiles: pickFiles, pickFolder: pickFolder),
              Column(
                key: const Key('browserSection'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(l.browserSectionTitle),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 4),
                    child: Text(
                      l.browserSectionBody,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const WebAccessCard(),
                  const ConnectedBrowsersCard(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _clock(AppLocalizations l, DateTime t) => l.digits(
  '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
);

String _ago(AppLocalizations l, DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return l.agoJustNow;
  if (d.inHours < 1) return l.agoMinutes(l.digits(d.inMinutes));
  return l.agoHours(l.digits(d.inHours));
}

/// Paired browsers with a "Disconnect" button each (DESIGN.md 4.5).
class ConnectedBrowsersCard extends StatelessWidget {
  const ConnectedBrowsersCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final list = c.webSessions;
    return Card(
      key: const Key('connectedBrowsersCard'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
              child: Text(l.browsersTitle, style: t.titleSmall),
            ),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
                child: Text(l.browsersNone, style: t.bodySmall),
              )
            else
              for (final s in list)
                ListTile(
                  key: Key('webSession-${s.id}'),
                  leading: const Icon(Icons.public),
                  title: AutoDirText(s.userAgent),
                  subtitle: Text(
                    l.browserSessionSubtitle(
                      l.ltrValue(s.remoteIp),
                      _clock(l, s.pairedAt),
                      _ago(l, s.lastSeen),
                    ),
                  ),
                  trailing: TextButton(
                    key: Key('disconnect-${s.id}'),
                    onPressed: () {
                      c.revokeWebSession(s.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            l.browserDisconnected(l.isoName(s.userAgent)),
                          ),
                        ),
                      );
                    },
                    child: Text(l.browserDisconnect),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// The address of the web page, as text and QR, with the certificate
/// warning explained.
class WebAccessCard extends StatelessWidget {
  const WebAccessCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final url = c.webUrl;
    final httpUrl = c.webHttpUrl;
    return Card(
      key: const Key('webAccessCard'),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Says which code to scan: this one works with any camera.
            Text(l.webQrCaption, style: t.titleSmall),
            const SizedBox(height: 12),
            if (url == null)
              Text(l.addressNotAvailable)
            else ...[
              Center(
                child: Semantics(
                  label: l.webQrSemantics,
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(8),
                    child: QrImageView(
                      data: httpUrl ?? url,
                      size: 160,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (httpUrl != null) ...[
                LtrText(
                  httpUrl,
                  key: const Key('webHttpUrl'),
                  selectable: true,
                ),
                Text(
                  l.webHttpOnNote,
                  style: t.bodySmall?.copyWith(color: scheme.error),
                ),
              ],
              LtrText(url, key: const Key('webUrl'), selectable: true),
              // The certificate warning is explained only when asked.
              Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: const Key('certWarningHelp'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsetsDirectional.only(bottom: 8),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  title: Text(l.webWarningTitle, style: t.bodyMedium),
                  children: [Text(l.webWarningBody, style: t.bodySmall)],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
