import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// [of], or null outside an [AppScope] (dialogs shown in bare tests).
  static AppController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()?.notifier;
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

/// One transfer on the home page (UX.md 3.8): who, state (icon and text,
/// never colour alone), percent, speed, time left, per-file and overall
/// progress, Cancel while it runs; when received: Open / Show in folder on
/// desktops, the saved path with Copy on phones.
class TransferSessionCard extends StatelessWidget {
  const TransferSessionCard({super.key, required this.session});
  final TransferSession session;

  static const _maxFileRows = 5;

  List<Widget> _summary(BuildContext context, TransferSession s) {
    var done = 0;
    for (final f in s.files.values) {
      if (f.done && f.error == null) done++;
    }
    final sent = s.sentBytes, total = s.totalBytes;
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

  static (IconData, String) _stateText(AppLocalizations l, TransferSession s) {
    final name = l.isoName(s.peerAlias);
    final total = s.totalBytes;
    return switch (s.state) {
      TransferState.waiting => (
          Icons.hourglass_empty,
          s.cancelRequested ? l.transferCancelling : l.transferWaiting(name)
        ),
      TransferState.running => (
          Icons.swap_vert,
          s.cancelRequested
              ? l.transferCancelling
              : total <= 0
                  ? l.transferRunning
                  : formatTransferProgress(
                      s.sentBytes / total, s.speed, l)
        ),
      TransferState.done => (Icons.check_circle, l.transferDone),
      TransferState.declined => (Icons.block, l.transferDeclined(name)),
      TransferState.cancelled => (Icons.cancel_outlined, l.transferCancelled),
      TransferState.failed => (
          Icons.error_outline,
          s.failureCode != null &&
                  (!s.incoming || s.failureCode != SendErrorCode.unknown)
              ? l.transferFailed(localizeSendError(l, s.failureCode))
              : s.error != null
                  ? l.transferFailed(s.error!)
                  : l.transferFailedPlain
        ),
    };
  }

  Future<void> _openOrReveal(BuildContext context, bool reveal) async {
    final c = AppScope.read(context);
    final s = session;
    final path = reveal
        ? (s.savedPaths.length == 1 ? s.savedPaths.single : s.openPath)
        : s.openPath;
    if (path == null) return;
    final l = context.l;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = reveal
        ? await c.fileOpener.reveal(path)
        : await c.fileOpener.open(path);
    if (!ok) {
      messenger?.showSnackBar(
          SnackBar(content: Text(l.transferOpenFailed(l.ltrValue(path)))));
    }
  }

  Future<void> _copyPath(BuildContext context, String path) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l = context.l;
    await Clipboard.setData(ClipboardData(text: stripIsolates(path)));
    messenger?.showSnackBar(SnackBar(content: Text(l.transferPathCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final s = session;
    final sid = s.sessionId;
    final c = AppScope.of(context);
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final name = l.isoName(s.peerAlias);
    final state = s.state;
    final (stateIcon, status) = _stateText(l, s);
    final stateColor = switch (state) {
      TransferState.done => scheme.primary,
      TransferState.failed || TransferState.declined => scheme.error,
      _ => scheme.onSurfaceVariant,
    };
    final timeLeft = state == TransferState.running && !s.cancelRequested
        ? s.timeLeft
        : null;
    final canOpen = c.fileOpener.canOpen;
    final savedLine = state == TransferState.done ? s.openPath : s.savedTo;
    final trusted = s.autoAccepted && s.peerFingerprint.isNotEmpty
        ? c.trustedDevice(s.peerFingerprint)
        : null;
    final actions = <Widget>[
      if (!state.isFinal && !s.cancelRequested)
        TextButton.icon(
          key: Key('cancel-$sid'),
          onPressed: () => c.cancel(s),
          icon: const Icon(Icons.close),
          label: Text(l.transferCancelAction),
        ),
      if (state == TransferState.done && s.incoming && canOpen) ...[
        TextButton.icon(
          key: Key('reveal-$sid'),
          onPressed: () => _openOrReveal(context, true),
          icon: const Icon(Icons.folder_open),
          label: Text(l.transferShowInFolder),
        ),
        FilledButton.tonalIcon(
          key: Key('open-$sid'),
          onPressed: () => _openOrReveal(context, false),
          icon: const Icon(Icons.open_in_new),
          label: Text(l.transferOpen),
        ),
      ],
      if (state == TransferState.done &&
          s.incoming &&
          !canOpen &&
          savedLine != null)
        TextButton.icon(
          key: Key('copyPath-$sid'),
          onPressed: () => _copyPath(context, savedLine),
          icon: const Icon(Icons.copy),
          label: Text(l.transferCopyPath),
        ),
    ];
    return Card(
      key: Key('transfer-$sid'),
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
                  state == TransferState.done
                      ? (s.incoming
                          ? l.transferReceivedFrom(name)
                          : l.transferSentTo(name))
                      : (s.incoming ? l.transferFrom(name) : l.transferTo(name)),
                  key: Key('title-$sid'),
                  style: t.titleSmall,
                ),
              ),
              if (timeLeft != null) ...[
                const SizedBox(width: 8),
                Text(formatTimeLeft(timeLeft, l),
                    key: Key('timeLeft-$sid'), style: t.bodySmall),
              ],
            ]),
            const SizedBox(height: 4),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(stateIcon,
                  key: Key('stateIcon-$sid'), size: 16, color: stateColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(status,
                    key: Key('status-$sid'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyMedium?.copyWith(
                        color: state == TransferState.failed ||
                                state == TransferState.declined
                            ? scheme.error
                            : null)),
              ),
            ]),
            if (s.autoAccepted)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 4),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Icon(Icons.verified_user_outlined,
                        size: 16, color: scheme.onSurfaceVariant),
                    Text(l.transferAutoAccepted,
                        key: Key('autoAccepted-$sid'), style: t.bodySmall),
                    if (trusted != null && trusted.autoAccept)
                      TextButton(
                        key: Key('stopAutoAccept-$sid'),
                        onPressed: () =>
                            c.setAutoAccept(s.peerFingerprint, false),
                        child: Text(l.autoAcceptStop),
                      ),
                  ],
                ),
              ),
            if (state == TransferState.waiting)
              const Padding(
                padding: EdgeInsetsDirectional.only(top: 8),
                child: LinearProgressIndicator(),
              ),
            // Folders can hold hundreds of files: one overall bar plus the
            // files that are running or failed.
            if (s.files.length > 1) ..._summary(context, s),
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
                            ? (f.errorCode == SendErrorCode.cancelled
                                ? l.transferCancelled
                                : l.transferFileFailed)
                            : '${formatBytes(f.sent, l)} / ${formatBytes(f.total, l)}',
                        style: t.bodySmall?.copyWith(
                            color: f.error != null ? scheme.error : null),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      key: Key('progress-$sid-${f.fileId}'),
                      value: f.fraction,
                      color: f.error != null ? scheme.error : null,
                    ),
                  ],
                ),
              ),
            if (s.incoming && savedLine != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 8),
                child: Row(children: [
                  const Icon(Icons.folder_outlined, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SelectableText(
                        l.transferSavedTo(l.ltrValue(savedLine)),
                        key: Key('savedTo-$sid'),
                        style: t.bodySmall),
                  ),
                ]),
              ),
            if (actions.isNotEmpty)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(top: 4),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 4,
                    children: actions,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
