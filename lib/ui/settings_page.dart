import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'dialogs.dart';
import 'format.dart';
import 'widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _pickDir(BuildContext context, AppController c) async {
    String? dir;
    try {
      dir = await FilePicker.getDirectoryPath(
          dialogTitle: 'Save received files to', initialDirectory: c.saveDir);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open folder picker: $e')));
      }
      return;
    }
    if (dir != null) await c.updateSettings(saveDir: dir);
  }

  Future<void> _resetDir(AppController c) async {
    await c.resetSaveDir();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final fp = c.self?.fingerprint;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Device name'),
                subtitle: Text(c.alias),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final v = await showAliasDialog(context, c.alias);
                  if (v != null && v.trim().isNotEmpty) {
                    await c.updateSettings(alias: v);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('Save received files to'),
                subtitle: Text(c.saveDir.isEmpty ? 'Not set' : c.saveDir),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pickDir(context, c),
              ),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Reset to default folder'),
                subtitle: const Text('Downloads, or Documents if unavailable'),
                onTap: () => _resetDir(c),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.lan_outlined),
                title: const Text('Address'),
                subtitle: Text(c.selfUrl ?? 'Unknown'),
              ),
              if (fp != null)
                ListTile(
                  leading: const Icon(Icons.fingerprint),
                  title: const Text('Certificate fingerprint'),
                  subtitle: SelectableText(shortFingerprint(fp)),
                ),
              ListTile(
                leading: const Icon(Icons.restart_alt),
                title: const Text('Restart service'),
                subtitle: Text(c.status.name),
                onTap: c.restart,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
