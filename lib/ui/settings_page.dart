import 'package:file_picker/file_picker.dart';
import 'dart:io';

import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'diagnosis_dialog.dart';
import 'dialogs.dart';
import 'format.dart';
import 'cable_wizard.dart';
import 'hotspot_wizard.dart';
import 'l10n.dart';
import 'wifi_direct_page.dart';
import 'wifi_join_page.dart';
import 'shares.dart';
import 'widgets.dart';

const _systemLanguage = 'system';

/// The language choice as shown in Settings: "System default" (translated),
/// or the language's own name ("English", "فارسی"), never translated.
String languageName(AppLocalizations l, Locale? locale) =>
    switch (locale?.languageCode) {
      null => l.settingsLanguageSystem,
      'fa' => l.languagePersian,
      _ => l.languageEnglish,
    };

/// Picks the app language; pops with 'system', 'en' or 'fa' (null when
/// cancelled).
class LanguageDialog extends StatelessWidget {
  const LanguageDialog({super.key, this.current});

  /// The current language code; null = system default.
  final String? current;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final options = [
      (_systemLanguage, l.settingsLanguageSystem),
      ('en', l.languageEnglish),
      ('fa', l.languagePersian),
    ];
    return AlertDialog(
      key: const Key('languageDialog'),
      title: Text(l.settingsLanguage),
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      content: RadioGroup<String>(
        groupValue: current ?? _systemLanguage,
        onChanged: (v) => Navigator.pop(context, v),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (code, name) in options)
              RadioListTile<String>(
                key: Key('language-$code'),
                value: code,
                title: Text(name),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.commonCancel)),
      ],
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.isAndroid});

  /// Test seam for the Android-only entries; default [Platform.isAndroid].
  final bool? isAndroid;

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

  Future<void> _pickLanguage(BuildContext context, AppController c) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => LanguageDialog(current: c.locale?.languageCode),
    );
    if (picked == null) return;
    await c.setLocale(picked == _systemLanguage ? null : Locale(picked));
  }

  Future<void> _setWebHttp(
      BuildContext context, AppController c, bool on) async {
    if (on) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          key: const Key('confirmWebHttp'),
          icon: const Icon(Icons.warning_amber_rounded),
          title: const Text('Turn on plain HTTP for browsers?'),
          content: const Text(
              'Browsers will open LanDrop without a certificate warning, but '
              'nothing is encrypted: anyone on this Wi-Fi can read the files, '
              'share links and pairing codes, and could pretend to be this '
              'device. Use it only on a network you trust, such as your home '
              'Wi-Fi, never on public or work networks.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                key: const Key('confirmWebHttpOn'),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Turn on')),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      await c.setWebHttp(on);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not change plain HTTP: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = context.l;
    final fp = c.self?.fingerprint;
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
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
              ListTile(
                key: const Key('languageSettings'),
                leading: const Icon(Icons.translate),
                title: Text(l.settingsLanguage),
                subtitle: Text(languageName(l, c.locale)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pickLanguage(context, c),
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
              if (Platform.isAndroid) ...[
                const Divider(),
                SwitchListTile(
                  secondary: const Icon(Icons.sync_outlined),
                  title: const Text('Keep running in background'),
                  subtitle: const Text(
                      'Stays reachable with the screen off. Shows a notification.'),
                  value: c.background,
                  onChanged: c.setBackground,
                ),
                ListTile(
                  leading: const Icon(Icons.power_settings_new),
                  title: const Text('Quit LanDrop'),
                  subtitle: const Text('Stops receiving and closes the app'),
                  onTap: c.quit,
                ),
              ],
              ListTile(
                key: const Key('diagnoseSettings'),
                leading: const Icon(Icons.troubleshoot),
                title: const Text('Diagnose connection'),
                subtitle: const Text('Find out why devices cannot connect'),
                onTap: () => showDiagnosisDialog(context),
              ),
              ListTile(
                key: const Key('hotspotSettings'),
                leading: const Icon(Icons.wifi_tethering),
                title: const Text('Connect without Wi-Fi / router'),
                subtitle: const Text(
                    'Use a hotspot from a phone or laptop, step by step'),
                onTap: () => openHotspotWizard(context),
              ),
              ListTile(
                key: const Key('cableSettings'),
                leading: const Icon(Icons.cable),
                title: const Text('Connect with a cable'),
                subtitle: const Text(
                    'Ethernet cable between two computers, or USB tethering'),
                onTap: () => openCableWizard(context),
              ),
              if (isAndroid ?? Platform.isAndroid)
                ListTile(
                  key: const Key('wifiDirectSettings'),
                  leading: const Icon(Icons.wifi_find),
                  title: const Text('Connect with Wi-Fi Direct'),
                  subtitle: const Text(
                      'Phone to phone without a router (Android)'),
                  onTap: () => openWifiDirect(context),
                ),
              if (isAndroid ?? Platform.isAndroid)
                ListTile(
                  key: const Key('wifiJoinSettings'),
                  leading: const Icon(Icons.qr_code_scanner),
                  title: const Text('Join a hotspot by QR'),
                  subtitle: const Text(
                      'Scan the QR code of another phone\'s LanDrop hotspot'),
                  onTap: () => openWifiJoin(context),
                ),
              ListTile(
                leading: const Icon(Icons.restart_alt),
                title: const Text('Restart service'),
                subtitle: Text(c.status.name),
                onTap: c.restart,
              ),
              const Divider(),
              SwitchListTile(
                key: const Key('webHttpSwitch'),
                secondary: const Icon(Icons.no_encryption_gmailerrorred),
                title: const Text(
                    'Allow browsers without a certificate warning (plain HTTP)'),
                subtitle: const Text(
                    'Off is safer. When on, browser traffic is not encrypted: '
                    'anyone on this network can see the files and pairing '
                    'codes. Only for networks you trust.'),
                value: c.webHttpEnabled,
                onChanged: (v) => _setWebHttp(context, c, v),
              ),
              if (c.webHttpEnabled)
                ListTile(
                  key: const Key('webHttpUrlTile'),
                  leading: const Icon(Icons.public),
                  title: const Text('Browser address (plain HTTP)'),
                  subtitle: SelectableText(c.webHttpUrl ?? 'Starting…'),
                ),
              SwitchListTile(
                key: const Key('keepSharesSwitch'),
                secondary: const Icon(Icons.history),
                title: const Text('Keep shares after restart'),
                subtitle: const Text(
                    'Share links keep working after LanDrop restarts, as long '
                    'as they have not expired and the files are unchanged. The '
                    'list of shared files is stored on this device. Off deletes '
                    'it.'),
                value: c.keepShares,
                onChanged: c.setKeepShares,
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 8, 12, 16),
                child: ConnectedBrowsersCard(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
