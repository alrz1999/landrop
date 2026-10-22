import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'format.dart';
import 'l10n.dart';
import 'ltr_text.dart';
import 'widgets.dart';

/// Settings ▸ Trusted devices (UX.md 3.7, 3.10, step U7): devices files
/// were accepted from, by security code (fingerprint). Per device: rename
/// (display name only), "Accept automatically" (off by default) and remove.
class TrustedDevicesPage extends StatelessWidget {
  const TrustedDevicesPage({super.key});

  Future<void> _rename(
      BuildContext context, AppController c, TrustedDevice t) async {
    final ctrl = TextEditingController(text: t.name);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final l = ctx.l;
        return AlertDialog(
          title: Text(l.trustedRename),
          content: TextField(
            key: const Key('renameTrustedField'),
            controller: ctrl,
            autofocus: true,
            maxLength: 40,
            decoration: InputDecoration(labelText: l.trustedRenameLabel),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.commonCancel)),
            FilledButton(
                key: const Key('renameTrustedSave'),
                onPressed: () => Navigator.pop(ctx, ctrl.text),
                child: Text(l.commonSave)),
          ],
        );
      },
    );
    if (v != null) await c.renameTrusted(t.fingerprint, v);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final devices = c.trustedDevices;
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTrustedDevices)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            key: const Key('trustedDevicesPage'),
            padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 24),
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 4, 8),
                child: Text(l.trustedIntro, style: t.bodyMedium),
              ),
              SwitchListTile(
                key: const Key('autoAcceptLargeSwitch'),
                title: Text(l.trustedLarge),
                subtitle: Text(l.trustedLargeSub(
                    formatBytes(AppController.autoAcceptMaxBytes, l))),
                value: c.autoAcceptLarge,
                onChanged: c.setAutoAcceptLarge,
              ),
              const Divider(),
              if (devices.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l.trustedEmpty,
                      key: const Key('trustedEmpty'),
                      textAlign: TextAlign.center,
                      style: t.bodyMedium),
                ),
              for (final d in devices)
                Card(
                  key: Key('trusted-${d.fingerprint}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.verified_user_outlined),
                        title: AutoDirText(d.name,
                            key: Key('trustedName-${d.fingerprint}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (d.displayName != null)
                              Text(l.trustedDeviceName(l.isoName(d.alias))),
                            Text(l.securityCode, style: t.labelSmall),
                            LtrText(shortFingerprint(d.fingerprint),
                                key: Key('trustedCode-${d.fingerprint}')),
                          ],
                        ),
                      ),
                      SwitchListTile(
                        key: Key('autoAccept-${d.fingerprint}'),
                        title: Text(l.trustedAutoAccept),
                        subtitle: Text(l.trustedAutoAcceptSub),
                        value: d.autoAccept,
                        onChanged: (v) => c.setAutoAccept(d.fingerprint, v),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 8),
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          children: [
                            TextButton.icon(
                              key: Key('rename-${d.fingerprint}'),
                              onPressed: () => _rename(context, c, d),
                              icon: const Icon(Icons.edit),
                              label: Text(l.trustedRename),
                            ),
                            TextButton.icon(
                              key: Key('remove-${d.fingerprint}'),
                              onPressed: () async {
                                final messenger =
                                    ScaffoldMessenger.of(context);
                                final name = l.isoName(d.name);
                                await c.removeTrusted(d.fingerprint);
                                messenger.showSnackBar(SnackBar(
                                    content: Text(l.trustedRemoved(name))));
                              },
                              icon: const Icon(Icons.delete_outline),
                              label: Text(l.trustedRemove),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
