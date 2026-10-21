// Sharing with browsers (DESIGN.md 4): create a share, list active shares,
// and the "Use from a browser" card.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/api.dart';
import 'format.dart';
import 'widgets.dart';

typedef ShareOptions = ({Duration? ttl, int? maxDownloads});

String _remaining(Duration d) {
  if (d.inMinutes < 1) return 'less than a minute';
  if (d.inHours < 1) return '${d.inMinutes} min';
  final m = d.inMinutes % 60;
  return m == 0 ? '${d.inHours} h' : '${d.inHours} h $m min';
}

/// Asks how long and how often a share may be used. Null when cancelled.
Future<ShareOptions?> showShareOptionsDialog(
    BuildContext context, String label) {
  return showDialog<ShareOptions>(
    context: context,
    builder: (_) => _ShareOptionsDialog(label),
  );
}

class _ShareOptionsDialog extends StatefulWidget {
  const _ShareOptionsDialog(this.label);
  final String label;
  @override
  State<_ShareOptionsDialog> createState() => _ShareOptionsDialogState();
}

class _ShareOptionsDialogState extends State<_ShareOptionsDialog> {
  static const _ttls = <(String, String, Duration?)>[
    ('ttl-15m', '15 min', Duration(minutes: 15)),
    ('ttl-1h', '1 hour', Duration(hours: 1)),
    ('ttl-24h', '24 hours', Duration(hours: 24)),
    ('ttl-none', 'Until I stop', null),
  ];
  static const _limits = <(String, String, int?)>[
    ('max-none', 'Unlimited', null),
    ('max-1', '1', 1),
    ('max-5', '5', 5),
  ];
  int _ttl = 1;
  int _limit = 0;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AlertDialog(
      key: const Key('shareOptionsDialog'),
      title: Text('Share ${widget.label}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Link works for', style: t.labelLarge),
            const SizedBox(height: 4),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final (i, (key, label, _)) in _ttls.indexed)
                ChoiceChip(
                  key: Key(key),
                  label: Text(label),
                  selected: _ttl == i,
                  onSelected: (_) => setState(() => _ttl = i),
                ),
            ]),
            const SizedBox(height: 16),
            Text('Downloads allowed', style: t.labelLarge),
            const SizedBox(height: 4),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final (i, (key, label, _)) in _limits.indexed)
                ChoiceChip(
                  key: Key(key),
                  label: Text(label),
                  selected: _limit == i,
                  onSelected: (_) => setState(() => _limit = i),
                ),
            ]),
            const SizedBox(height: 16),
            Text(
              'Anyone on this network who has the link can download while it '
              'works. Playing a video counts as one download.',
              style: t.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          key: const Key('confirmShare'),
          onPressed: () => Navigator.pop<ShareOptions>(context,
              (ttl: _ttls[_ttl].$3, maxDownloads: _limits[_limit].$3)),
          child: const Text('Share'),
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
  final messenger = ScaffoldMessenger.of(context);
  void snack(String m) => messenger.showSnackBar(SnackBar(content: Text(m)));
  List<String> paths;
  try {
    if (folder) {
      final d = await pickFolder();
      paths = d == null || d.isEmpty ? const [] : [d];
    } else {
      paths = await pickFiles();
    }
  } catch (e) {
    snack('Could not open the picker: $e');
    return;
  }
  if (paths.isEmpty || !context.mounted) return;
  final label = folder
      ? 'folder "${paths.single.split(RegExp(r'[\\/]')).lastWhere((s) => s.isNotEmpty, orElse: () => paths.single)}"'
      : '${paths.length} file${paths.length == 1 ? '' : 's'}';
  final opts = await showShareOptionsDialog(context, label);
  if (opts == null) return;
  try {
    c.createShare(paths, ttl: opts.ttl, maxDownloads: opts.maxDownloads);
    snack('Sharing $label. Open the link on the other device.');
  } catch (e) {
    snack('Could not share: $e');
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
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final link = s.httpUrl ?? s.url;
    final first = s.files.first.name;
    final title = s.files.length == 1
        ? first
        : '$first and ${s.files.length - 1} more';
    final String time;
    if (s.expiresAt == null) {
      time = 'Until you stop it';
    } else if (s.expired) {
      time = 'Expired';
    } else {
      time = 'Ends in ${_remaining(s.expiresAt!.difference(DateTime.now()))}';
    }
    final downloads = s.maxDownloads == null
        ? 'Unlimited downloads'
        : s.exhausted
            ? 'Download limit reached'
            : '${s.downloadsLeft} of ${s.maxDownloads} downloads left';
    return Card(
      key: Key('share-${s.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: t.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    Text(
                        '${s.files.length} file${s.files.length == 1 ? '' : 's'}'
                        ' · ${formatBytes(s.totalBytes)}',
                        style: t.bodySmall),
                    const SizedBox(height: 6),
                    Text(time, key: Key('shareTime-${s.id}'), style: t.bodySmall),
                    Text(downloads,
                        key: Key('shareDownloads-${s.id}'),
                        style: t.bodySmall?.copyWith(
                            color: s.exhausted ? scheme.error : null)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: 'QR code for the share link',
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(4),
                  child: QrImageView(
                      data: link, size: 112, backgroundColor: Colors.white),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            SelectableText(link, key: Key('shareUrl-${s.id}'), style: t.bodySmall),
            if (s.httpUrl != null)
              Text('Plain HTTP link: not encrypted.',
                  style: t.bodySmall?.copyWith(color: scheme.error)),
            Wrap(spacing: 8, children: [
              TextButton.icon(
                key: Key('copyShare-${s.id}'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: link));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link copied')));
                  }
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy link'),
              ),
              OutlinedButton.icon(
                key: Key('stopShare-${s.id}'),
                onPressed: () => c.revokeShare(s.id),
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                label: const Text('Stop sharing'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Active shares plus "Share files" / "Share folder" buttons. Rebuilds every
/// 30 s so remaining times stay current.
class SharesSection extends StatefulWidget {
  const SharesSection(
      {super.key, required this.pickFiles, required this.pickFolder});
  final Future<List<String>> Function() pickFiles;
  final Future<String?> Function() pickFolder;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Share with a browser'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Wrap(spacing: 4, children: [
            TextButton.icon(
              key: const Key('shareFiles'),
              onPressed: () => startShareFlow(context,
                  pickFiles: widget.pickFiles, pickFolder: widget.pickFolder),
              icon: const Icon(Icons.ios_share),
              label: const Text('Share files'),
            ),
            TextButton.icon(
              key: const Key('shareFolder'),
              onPressed: () => startShareFlow(context,
                  pickFiles: widget.pickFiles,
                  pickFolder: widget.pickFolder,
                  folder: true),
              icon: const Icon(Icons.folder_shared_outlined),
              label: const Text('Share folder'),
            ),
          ]),
        ),
        if (c.shares.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Nothing shared. A share gives you a link and QR code that '
              'opens in any browser on this network, no app needed.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          for (final s in c.shares.reversed) ShareCard(share: s),
      ],
    );
  }
}

/// Shares screen (reachable from the app bar).
class SharesPage extends StatelessWidget {
  const SharesPage(
      {super.key, required this.pickFiles, required this.pickFolder});
  final Future<List<String>> Function() pickFiles;
  final Future<String?> Function() pickFolder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shares')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            children: [
              SharesSection(pickFiles: pickFiles, pickFolder: pickFolder),
              const SectionHeader('Use from a browser'),
              const WebAccessCard(),
            ],
          ),
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
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final url = c.webUrl;
    final httpUrl = c.webHttpUrl;
    return Card(
      key: const Key('webAccessCard'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Any phone or computer on this network can send files here '
              'from a browser, with nothing to install. Open this address '
              'or scan the code:',
              style: t.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (url == null)
              const Text('Address not available yet')
            else ...[
              Center(
                child: Semantics(
                  label: 'QR code for the browser address',
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(8),
                    child: QrImageView(
                        data: httpUrl ?? url,
                        size: 160,
                        backgroundColor: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (httpUrl != null) ...[
                SelectableText(httpUrl, key: const Key('webHttpUrl')),
                Text(
                  'Plain HTTP is on (Settings): no warning, but not '
                  'encrypted. Secure address:',
                  style: t.bodySmall?.copyWith(color: scheme.error),
                ),
              ],
              SelectableText(url, key: const Key('webUrl')),
              const SizedBox(height: 8),
              Text(
                'The browser will first warn that the connection is not '
                'private. That is expected: LanDrop uses its own certificate '
                'instead of one bought from a certificate company. Choose '
                '"Advanced" then "Proceed" (Chrome, Edge), or "Show details" '
                'then "visit this website" (Safari). Then tap "Pair this '
                'browser" and approve here if both show the same code.',
                style: t.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
