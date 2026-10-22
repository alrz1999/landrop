import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import 'connect_helper.dart';
import 'finding_text.dart';
import 'l10n.dart';
import 'ltr_text.dart';
import 'widgets.dart';

/// Runs the guided diagnosis (optionally probing [targetIp]) and shows the
/// findings with "Run again" and "Copy report". A finding's action button
/// ("Connect with a hotspot") closes the dialog and opens the connection
/// helper at the matching step (UX.md 3.4).
Future<void> showDiagnosisDialog(BuildContext context,
    {String? targetIp, int? targetPort}) async {
  final c = AppScope.read(context);
  final action = await showDialog<String>(
    context: context,
    builder: (_) => DiagnosisDialog(
      run: () => c.runDiagnosis(targetIp: targetIp, targetPort: targetPort),
      target: targetIp == null
          ? null
          : '$targetIp${targetPort == null ? '' : ':$targetPort'}',
    ),
  );
  if ((action == hotspotWizardAction || action == cableWizardAction) &&
      context.mounted) {
    await openConnectHelper(context, action: action);
  }
}

/// Copies the diagnosis report: English for support (UX.md 4.10); in
/// Persian one translated line on top says so. Confirms with a snackbar.
Future<void> copyDiagnosisReport(BuildContext context, List<Finding> findings,
    {String? target}) async {
  final l = context.l;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final report =
      formatDiagnosisReport(findings, at: DateTime.now(), target: target);
  final text = l.isRtl ? '${l.diagReportNote}\n\n$report' : report;
  await Clipboard.setData(ClipboardData(text: text));
  messenger?.showSnackBar(SnackBar(content: Text(l.diagReportCopied)));
}

/// Button label for a [Finding.action] the UI knows, else null.
String? findingActionLabel(AppLocalizations l, String? action) =>
    switch (action) {
      hotspotWizardAction => l.diagActionHotspot,
      cableWizardAction => l.connectCableTitle,
      _ => null,
    };

/// Findings kept out of the dialog's list: the "Your network" summary is
/// only for support, so it stays in "Copy report" (UX.md 7, quick win 5).
const hiddenFindingCodes = {'network'};

/// Warning color with enough contrast in both themes (UX.md 5).
Color warningColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFFFB960)
        : const Color(0xFF7A4F00);

/// Pops with the finding's action (see [showDiagnosisDialog]).
class DiagnosisDialog extends StatefulWidget {
  const DiagnosisDialog({super.key, required this.run, this.target});
  final Future<List<Finding>> Function() run;
  final String? target;

  @override
  State<DiagnosisDialog> createState() => _DiagnosisDialogState();
}

class _DiagnosisDialogState extends State<DiagnosisDialog> {
  List<Finding>? _findings;
  String? _error;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      final f = await widget.run();
      if (mounted) setState(() => _findings = f);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _copy() async {
    final f = _findings;
    if (f == null) return;
    await copyDiagnosisReport(context, f, target: widget.target);
  }

  @override
  Widget build(BuildContext context) {
    final findings = _findings;
    final l = context.l;
    final shown = [
      for (final f in findings ?? const <Finding>[])
        if (!hiddenFindingCodes.contains(f.code)) f
    ];
    return AlertDialog(
      key: const Key('diagnosisDialog'),
      title: Text(widget.target == null
          ? l.diagTitle
          : l.diagTitleTarget(l.ltrValue(widget.target!))),
      content: SizedBox(
        width: 480,
        child: _running && findings == null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Row(children: [
                  const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 16),
                  Expanded(child: Text(l.diagRunning)),
                ]),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null)
                      Text(l.diagError(_error!),
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    if (_running) const LinearProgressIndicator(),
                    for (final f in shown)
                      FindingTile(
                          finding: f,
                          onAction: (a) => Navigator.pop(context, a)),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          key: const Key('copyReport'),
          onPressed: findings == null ? null : _copy,
          child: Text(l.diagCopyReport),
        ),
        TextButton(
          key: const Key('runAgain'),
          onPressed: _running ? null : _run,
          child: Text(l.diagRunAgain),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonClose),
        ),
      ],
    );
  }
}

class FindingTile extends StatelessWidget {
  const FindingTile({super.key, required this.finding, this.onAction});
  final Finding finding;

  /// Called with [Finding.action] when its button is tapped; no button
  /// when null or the action is unknown.
  final void Function(String action)? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final f = finding;
    // Localized title/detail/fix; technical details and the copied report
    // stay English (in English the finding's own texts are shown).
    final l = context.l;
    final text = localizeFinding(l, f);
    final (icon, color) = switch (f.severity) {
      Severity.problem => (Icons.error_outline, scheme.error),
      Severity.warn => (Icons.warning_amber_rounded, warningColor(context)),
      Severity.info => (
          f.code == 'all-good' || f.code == 'probe-ok'
              ? Icons.check_circle_outline
              : Icons.info_outline,
          scheme.primary
        ),
    };
    final actionLabel = findingActionLabel(l, f.action);
    // Plain first (title, what it means, what to do, the button); the
    // technical text is collapsed under "Details" and never translated.
    return Padding(
      key: Key('finding-${f.code}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text.title,
                    style: t.titleSmall?.copyWith(color: color)),
                if (text.detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(text.detail, style: t.bodyMedium),
                ],
                if (text.fix.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(l.diagWhatToDo(text.fix), style: t.bodyMedium),
                ],
                if (onAction != null && actionLabel != null) ...[
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    key: Key('findingAction-${f.code}'),
                    onPressed: () => onAction!(f.action!),
                    icon: Icon(
                        f.action == cableWizardAction
                            ? Icons.cable
                            : Icons.wifi_tethering,
                        size: 18),
                    label: Text(actionLabel),
                  ),
                ],
                if (f.technical != null && f.technical!.isNotEmpty)
                  Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      key: Key('findingDetails-${f.code}'),
                      tilePadding: EdgeInsets.zero,
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      title: Text(l.diagDetails,
                          style: t.labelLarge
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                      children: [
                        LtrText(f.technical!,
                            selectable: true,
                            style: t.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
