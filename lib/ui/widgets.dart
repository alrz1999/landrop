import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/api.dart';
import 'app_controller.dart';
import 'format.dart';

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({super.key, required AppController controller, required super.child})
      : super(notifier: controller);

  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.primary)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Own alias (editable), IP and port, status.
class SelfCard extends StatelessWidget {
  const SelfCard({super.key, required this.onEditAlias});
  final VoidCallback onEditAlias;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (statusText, statusColor) = switch (c.status) {
      CoreStatus.running => ('Ready to receive', scheme.primary),
      CoreStatus.starting => ('Starting…', scheme.onSurfaceVariant),
      CoreStatus.stopped => ('Stopped', scheme.onSurfaceVariant),
      CoreStatus.error => ('Error: ${c.lastError ?? 'unknown'}', scheme.error),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: scheme.primaryContainer,
              child: Icon(deviceIcon(c.self?.deviceType ?? 'desktop'),
                  color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(c.alias,
                            key: const Key('selfAlias'),
                            style: Theme.of(context).textTheme.titleLarge,
                            overflow: TextOverflow.ellipsis),
                      ),
                      IconButton(
                        tooltip: 'Rename device',
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: onEditAlias,
                      ),
                    ],
                  ),
                  SelectableText(
                    c.selfIp == null
                        ? 'IP unknown · port ${c.selfPort}'
                        : '${c.selfIp} · port ${c.selfPort}',
                    key: const Key('selfAddress'),
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.circle, size: 10, color: statusColor),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(statusText,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: statusColor)),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PeerTile extends StatelessWidget {
  const PeerTile({super.key, required this.peer, required this.onSend});
  final DeviceInfo peer;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    // Same device reachable at other addresses (e.g. Wi-Fi + hotspot).
    final more = peer.addresses.where((a) => a != peer.ip).toSet().length;
    return ListTile(
      leading: CircleAvatar(child: Icon(deviceIcon(peer.deviceType))),
      title: Text(peer.alias),
      subtitle: Text([
        '${peer.ip}:${peer.port}',
        if (more > 0) '+$more more address${more == 1 ? '' : 'es'}',
        if (peer.deviceModel != null) peer.deviceModel!,
      ].join(' · ')),
      trailing: FilledButton.tonalIcon(
        key: Key('send-${peer.fingerprint}'),
        onPressed: onSend,
        icon: const Icon(Icons.send, size: 18),
        label: const Text('Send'),
      ),
    );
  }
}

class EmptyPeersHelp extends StatelessWidget {
  const EmptyPeersHelp({super.key, this.onDiagnose, this.onHotspot});

  /// Shows a "Why can't I see my device?" button when set.
  final VoidCallback? onDiagnose;

  /// Shows a "Connect without Wi-Fi / router" button when set.
  final VoidCallback? onHotspot;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.wifi_find,
              size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text('No nearby devices yet', style: t.titleMedium),
          const SizedBox(height: 8),
          Text(
            '• Make sure both devices are on the same Wi-Fi network and have LanDrop open.\n'
            '• Some routers block device-to-device traffic ("AP isolation" / '
            '"client isolation" / guest networks) — turn it off or use another network.\n'
            '• Disconnect VPNs, which often hide the local network.\n'
            '• Allow LanDrop through the firewall (TCP/UDP port 53317).\n'
            '• Still nothing? Use "Rescan network", "Add by IP", or scan the QR code below.',
            style: t.bodyMedium,
          ),
          if (onDiagnose != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('whyNoDevices'),
              onPressed: onDiagnose,
              icon: const Icon(Icons.troubleshoot),
              label: const Text("Why can't I see my device?"),
            ),
          ],
          if (onHotspot != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('hotspotHelp'),
              onPressed: onHotspot,
              icon: const Icon(Icons.wifi_tethering),
              label: const Text('Connect without Wi-Fi / router'),
            ),
          ],
        ],
      ),
    );
  }
}

class QrCard extends StatelessWidget {
  const QrCard({super.key});

  @override
  Widget build(BuildContext context) {
    final url = AppScope.of(context).selfUrl;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('This device', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (url == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Address not available yet'),
              )
            else ...[
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                child: QrImageView(
                  data: url,
                  size: 160,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(url, key: const Key('selfUrl')),
            ],
          ],
        ),
      ),
    );
  }
}

class TransferSessionCard extends StatelessWidget {
  const TransferSessionCard({super.key, required this.session});
  final TransferSession session;

  static const _maxFileRows = 5;

  List<Widget> _summary(BuildContext context, TransferSession s) {
    var sent = 0, total = 0, done = 0;
    for (final f in s.files.values) {
      sent += f.sent;
      total += f.total;
      if (f.done && f.error == null) done++;
    }
    return [
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(children: [
          Expanded(
            child: Text('$done of ${s.files.length} files',
                key: Key('summary-${s.sessionId}')),
          ),
          Text('${formatBytes(sent)} / ${formatBytes(total)}',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
      const SizedBox(height: 4),
      LinearProgressIndicator(
        key: Key('progress-${s.sessionId}'),
        value: total <= 0 ? null : (sent / total).clamp(0, 1),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = session;
    final scheme = Theme.of(context).colorScheme;
    String status;
    if (s.hasError || s.result == false) {
      status = s.error != null ? 'Failed: ${s.error}' : 'Failed';
    } else if (s.done || s.result == true) {
      status = 'Done';
    } else if (s.files.isEmpty) {
      status = 'Waiting for ${s.peerAlias} to accept…';
    } else {
      status = 'Transferring';
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(s.incoming ? Icons.call_received : Icons.call_made,
                  size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.incoming ? 'From ${s.peerAlias}' : 'To ${s.peerAlias}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                        color: status.startsWith('Failed')
                            ? scheme.error
                            : null)),
              ),
            ]),
            if (s.files.isEmpty && s.result == null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
            // Folders can hold hundreds of files: show one overall bar plus
            // the files that are running or failed.
            if (s.files.length > _maxFileRows) ..._summary(context, s),
            for (final f in s.files.length > _maxFileRows
                ? s.files.values
                    .where((f) => f.error != null || (!f.done && f.sent > 0))
                    .take(3)
                : s.files.values)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(f.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Text(
                        f.error != null
                            ? f.error!
                            : '${formatBytes(f.sent)} / ${formatBytes(f.total)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: f.error != null ? scheme.error : null),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      key: Key('progress-${s.sessionId}-${f.fileId}'),
                      value: f.fraction,
                      color: f.error != null ? scheme.error : null,
                    ),
                  ],
                ),
              ),
            if (s.incoming && s.savedTo != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  const Icon(Icons.folder_outlined, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SelectableText('Saved to ${s.savedTo}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}
