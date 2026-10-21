import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/api.dart';
import 'app_controller.dart';
import 'finding_text.dart';
import 'format.dart';
import 'l10n.dart';
import 'ltr_text.dart';

/// "Phone", "Computer", "Browser" for a [DeviceInfo.deviceType].
String deviceKindLabel(AppLocalizations l, String type) => switch (type) {
      'mobile' => l.deviceKindPhone,
      'web' => l.deviceKindBrowser,
      _ => l.deviceKindComputer,
    };

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
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 8, 4),
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

/// Own alias (editable), a plain status line ("Visible to nearby devices")
/// and, below it in small muted text, IP and port (UX.md 7, quick win 1).
class SelfCard extends StatelessWidget {
  const SelfCard({super.key, required this.onEditAlias});
  final VoidCallback onEditAlias;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final (statusText, statusColor, statusIcon) = switch (c.status) {
      CoreStatus.running =>
        (l.selfStatusReady, scheme.primary, Icons.check_circle),
      CoreStatus.starting =>
        (l.selfStatusStarting, scheme.onSurfaceVariant, Icons.circle_outlined),
      CoreStatus.stopped =>
        (l.selfStatusStopped, scheme.onSurfaceVariant, Icons.circle_outlined),
      CoreStatus.error => (l.selfStatusError, scheme.error, Icons.error),
    };
    final port = l.ltrValue('${c.selfPort}');
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
                        child: AutoDirText(c.alias,
                            key: const Key('selfAlias'),
                            style: t.titleLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      IconButton(
                        tooltip: l.selfRename,
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: onEditAlias,
                      ),
                    ],
                  ),
                  Row(children: [
                    Icon(statusIcon, size: 16, color: statusColor),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(statusText,
                          key: const Key('selfStatus'),
                          style: t.bodyMedium?.copyWith(color: statusColor)),
                    ),
                  ]),
                  if (c.status == CoreStatus.error)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        key: const Key('selfRetry'),
                        onPressed: c.restart,
                        child: Text(l.commonTryAgain),
                      ),
                    ),
                  const SizedBox(height: 2),
                  SelectableText(
                    c.selfIp == null
                        ? l.selfAddressUnknown(port)
                        : l.selfAddress(l.ltrValue(c.selfIp!), port),
                    key: const Key('selfAddress'),
                    style: t.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One nearby device: name, kind ("Phone · Google"), Send. No address here
/// (UX.md 3.2): the Details sheet (info button or long press) has it.
class PeerTile extends StatelessWidget {
  const PeerTile({super.key, required this.peer, required this.onSend});
  final DeviceInfo peer;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return ListTile(
      leading: CircleAvatar(child: Icon(deviceIcon(peer.deviceType))),
      title: AutoDirText(peer.alias,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text([
        deviceKindLabel(l, peer.deviceType),
        if (peer.deviceModel != null) l.isoName(peer.deviceModel!),
      ].join(' · ')),
      onLongPress: () => showPeerDetails(context, peer),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          key: Key('details-${peer.fingerprint}'),
          tooltip: l.peerDetails,
          icon: const Icon(Icons.info_outline),
          onPressed: () => showPeerDetails(context, peer),
        ),
        FilledButton.tonalIcon(
          key: Key('send-${peer.fingerprint}'),
          onPressed: onSend,
          icon: const Icon(Icons.send, size: 18),
          label: Text(l.homeSend),
        ),
      ]),
    );
  }
}

/// Bottom sheet with a device's technical details: address, other
/// addresses, direct cable link, security code (UX.md 3.2).
Future<void> showPeerDetails(BuildContext context, DeviceInfo peer) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final l = ctx.l;
      final t = Theme.of(ctx).textTheme;
      final others =
          peer.addresses.where((a) => a != peer.ip).toSet().toList();
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
      return SafeArea(
        child: SingleChildScrollView(
          key: const Key('peerDetailsSheet'),
          padding: const EdgeInsetsDirectional.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsetsDirectional.symmetric(horizontal: 24),
                leading: CircleAvatar(child: Icon(deviceIcon(peer.deviceType))),
                title: AutoDirText(peer.alias, style: t.titleMedium),
                subtitle: Text(deviceKindLabel(l, peer.deviceType)),
              ),
              row(
                  l.detailsAddress,
                  LtrText(
                      peer.port > 0 ? '${peer.ip}:${peer.port}' : peer.ip,
                      key: const Key('peerAddress'),
                      selectable: true)),
              if (peer.ip.startsWith('169.254.'))
                row(l.detailsConnection, Text(l.detailsCableLink)),
              if (others.isNotEmpty)
                row(
                    l.detailsOtherAddresses,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final a in others) LtrText(a, selectable: true)
                      ],
                    ),
                    key: const Key('peerOtherAddresses')),
              if (peer.deviceModel != null)
                row(l.detailsModel, AutoDirText(peer.deviceModel!)),
              if (peer.fingerprint.isNotEmpty)
                row(
                    l.securityCode,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LtrText(shortFingerprint(peer.fingerprint),
                            key: const Key('peerSecurityCode'),
                            selectable: true),
                        const SizedBox(height: 2),
                        Text(l.securityCodeHint, style: t.bodySmall),
                      ],
                    )),
            ],
          ),
        ),
      );
    },
  );
}

class EmptyPeersHelp extends StatelessWidget {
  const EmptyPeersHelp(
      {super.key, this.onDiagnose, this.onHotspot, this.onCable});

  /// Shows a "Why can't I see my device?" button when set.
  final VoidCallback? onDiagnose;

  /// Shows a "Connect without Wi-Fi / router" button when set.
  final VoidCallback? onHotspot;

  /// Shows a "Connect with a cable" button when set.
  final VoidCallback? onCable;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l = context.l;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.wifi_find,
              size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(l.emptyTitle,
              style: t.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(l.emptyBody, style: t.bodyMedium, textAlign: TextAlign.center),
          if (onDiagnose != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('whyNoDevices'),
              onPressed: onDiagnose,
              icon: const Icon(Icons.troubleshoot),
              label: Text(l.emptyWhy),
            ),
          ],
          if (onHotspot != null || onCable != null) ...[
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              children: [
                if (onHotspot != null)
                  TextButton.icon(
                    key: const Key('hotspotHelp'),
                    onPressed: onHotspot,
                    icon: const Icon(Icons.wifi_tethering),
                    label: Text(l.connectHotspotTitle),
                  ),
                if (onCable != null)
                  TextButton.icon(
                    key: const Key('cableHelp'),
                    onPressed: onCable,
                    icon: const Icon(Icons.cable),
                    label: Text(l.connectCableTitle),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// This device's address as QR and text, for another LanDrop app (UX.md 7,
/// quick win 7). Lives in Settings ▸ Advanced.
class QrCard extends StatelessWidget {
  const QrCard({super.key});

  @override
  Widget build(BuildContext context) {
    final url = AppScope.of(context).selfUrl;
    final l = context.l;
    return Card(
      key: const Key('qrCard'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(l.qrForLanDrop,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            if (url == null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l.addressNotAvailable),
              )
            else ...[
              Semantics(
                label: l.qrSelfSemantics,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(8),
                  child: QrImageView(
                    data: url,
                    size: 160,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              LtrText(url, key: const Key('selfUrl'), selectable: true),
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
    final l = context.l;
    return [
      Padding(
        padding: const EdgeInsetsDirectional.only(top: 8),
        child: Row(children: [
          Expanded(
            child: Text(l.transferSummary(done, s.files.length),
                key: Key('summary-${s.sessionId}')),
          ),
          Text('${formatBytes(sent, l)} / ${formatBytes(total, l)}',
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
    final l = context.l;
    final scheme = Theme.of(context).colorScheme;
    final name = l.isoName(s.peerAlias);
    String status;
    var failed = false;
    if (s.hasError || s.result == false) {
      failed = true;
      if (s.errorCode == SendErrorCode.declined) {
        status = l.transferDeclined(name);
      } else if (s.errorCode != null) {
        status = l.transferFailed(localizeSendError(l, s.errorCode));
      } else {
        status = s.error != null
            ? l.transferFailed(s.error!)
            : l.transferFailedPlain;
      }
    } else if (s.done || s.result == true) {
      status = l.transferDone;
    } else if (s.files.isEmpty) {
      status = l.transferWaiting(name);
    } else {
      status = l.transferRunning;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              // Arrows point down/up, never mirrored (UX.md 3.8, 4.4).
              Icon(s.incoming ? Icons.download : Icons.upload,
                  size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.incoming ? l.transferFrom(name) : l.transferTo(name),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(status,
                    key: Key('status-${s.sessionId}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(color: failed ? scheme.error : null)),
              ),
            ]),
            if (s.files.isEmpty && s.result == null)
              const Padding(
                padding: EdgeInsetsDirectional.only(top: 8),
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
                padding: const EdgeInsetsDirectional.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: AutoDirText(f.name,
                            fileName: true,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        f.error != null
                            ? f.error!
                            : '${formatBytes(f.sent, l)} / ${formatBytes(f.total, l)}',
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
                padding: const EdgeInsetsDirectional.only(top: 8),
                child: Row(children: [
                  const Icon(Icons.folder_outlined, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SelectableText(
                        l.transferSavedTo(l.ltrValue(s.savedTo!)),
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
