import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import 'hotspot_wizard.dart';
import 'widgets.dart';

/// Runs the guided diagnosis (optionally probing [targetIp]) and shows the
/// findings with "Run again" and "Copy report". A finding's action button
/// ("Connect with a hotspot") closes the dialog and opens the wizard.
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
  if (action == hotspotWizardAction && context.mounted) {
    await openHotspotWizard(context);
  }
}

/// Button label for a [Finding.action] the UI knows, else null.
String? findingActionLabel(String? action) => switch (action) {
      hotspotWizardAction => 'Connect with a hotspot',
      _ => null,
    };

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
    final text =
        formatDiagnosisReport(f, at: DateTime.now(), target: widget.target);
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(const SnackBar(content: Text('Report copied')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final findings = _findings;
    return AlertDialog(
      key: const Key('diagnosisDialog'),
      title: Text(widget.target == null
          ? 'Connection check'
          : 'Checking ${widget.target}'),
      content: SizedBox(
        width: 480,
        child: _running && findings == null
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Row(children: [
                  SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 16),
                  Expanded(child: Text('Checking the network…')),
                ]),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null)
                      Text('Could not run the check: $_error',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    if (_running) const LinearProgressIndicator(),
                    for (final f in findings ?? const <Finding>[])
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
          child: const Text('Copy report'),
        ),
        TextButton(
          key: const Key('runAgain'),
          onPressed: _running ? null : _run,
          child: const Text('Run again'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
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
    final (icon, color) = switch (f.severity) {
      Severity.problem => (Icons.error_outline, scheme.error),
      Severity.warn => (Icons.warning_amber_rounded, Colors.orange.shade800),
      Severity.info => (
          f.code == 'all-good' || f.code == 'probe-ok'
              ? Icons.check_circle_outline
              : Icons.info_outline,
          scheme.primary
        ),
    };
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
                Text(f.title, style: t.titleSmall?.copyWith(color: color)),
                if (f.detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(f.detail, style: t.bodyMedium),
                ],
                if (f.fix.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('What to do: ${f.fix}', style: t.bodyMedium),
                ],
                if (f.technical != null && f.technical!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  SelectableText(f.technical!,
                      style: t.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                ],
                if (onAction != null &&
                    findingActionLabel(f.action) != null) ...[
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    key: Key('findingAction-${f.code}'),
                    onPressed: () => onAction!(f.action!),
                    icon: const Icon(Icons.wifi_tethering, size: 18),
                    label: Text(findingActionLabel(f.action)!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
