import 'package:file_picker/file_picker.dart';
import 'dart:io';

import 'package:flutter/material.dart';

import 'advanced_settings.dart';
import 'app_controller.dart';
import 'connect_helper.dart';
import 'dialogs.dart';
import 'l10n.dart';
import 'ltr_text.dart';
import 'pickers.dart';
import 'shares.dart';
import 'trusted_devices.dart';
import 'widgets.dart';

export 'advanced_settings.dart';

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

/// Settings (UX.md 3.10, step U3): this device, connections, Android
/// lifecycle, and an Advanced page with everything technical.
class SettingsPage extends StatelessWidget {
  const SettingsPage(
      {super.key,
      this.isAndroid,
      this.pickFiles = defaultPickFiles,
      this.pickFolder = defaultPickFolder});

  /// Test seam for the Android-only entries; default [Platform.isAndroid].
  final bool? isAndroid;

  /// Passed on to the Shares page.
  final FilesPicker pickFiles;
  final FolderPicker pickFolder;

  Future<void> _pickDir(BuildContext context, AppController c) async {
    String? dir;
    final l = context.l;
    try {
      dir = await FilePicker.getDirectoryPath(
          dialogTitle: l.settingsSaveFolder, initialDirectory: c.saveDir);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.errorFolderPicker('$e'))));
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

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = context.l;
    final android = isAndroid ?? Platform.isAndroid;
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsetsDirectional.only(bottom: 24),
            children: [
              SectionHeader(l.settingsSectionDevice),
              ListTile(
                key: const Key('aliasSettings'),
                leading: const Icon(Icons.badge_outlined),
                title: Text(l.settingsDeviceName),
                subtitle: AutoDirText(c.alias),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final v = await showAliasDialog(context, c.alias);
                  if (v != null && v.trim().isNotEmpty) {
                    await c.updateSettings(alias: v);
                  }
                },
              ),
              ListTile(
                key: const Key('saveFolderSettings'),
                leading: const Icon(Icons.folder_outlined),
                title: Text(l.settingsSaveFolder),
                subtitle: c.saveDir.isEmpty
                    ? Text(l.settingsNotSet)
                    : LtrText(c.saveDir, key: const Key('saveFolderPath')),
                // "Use default folder" is an option of this row (UX.md 1.3).
                trailing: IconButton(
                  key: const Key('resetFolder'),
                  tooltip: l.settingsUseDefaultFolder,
                  icon: const Icon(Icons.restore),
                  onPressed: () => _resetDir(c),
                ),
                onTap: () => _pickDir(context, c),
              ),
              // Android without "All files access": say where files are.
              if (c.savesToPrivateFolder)
                ListTile(
                  key: const Key('privateFolderHint'),
                  leading: const Icon(Icons.info_outline),
                  title: Text(l.settingsPrivateFolder),
                  trailing: TextButton(
                    key: const Key('useDownloads'),
                    onPressed: c.useDownloadsFolder,
                    child: Text(l.settingsUseDownloads),
                  ),
                ),
              ListTile(
                key: const Key('languageSettings'),
                leading: const Icon(Icons.translate),
                title: Text(l.settingsLanguage),
                subtitle: Text(languageName(l, c.locale)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pickLanguage(context, c),
              ),
              ListTile(
                key: const Key('trustedDevicesSettings'),
                leading: const Icon(Icons.verified_user_outlined),
                title: Text(l.settingsTrustedDevices),
                subtitle:
                    Text(l.settingsTrustedDevicesSub(c.trustedDevices.length)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TrustedDevicesPage())),
              ),
              SectionHeader(l.settingsSectionConnect),
              ListTile(
                key: const Key('connectHelpSettings'),
                leading: const Icon(Icons.troubleshoot),
                title: Text(l.settingsConnectHelp),
                subtitle: Text(l.settingsConnectHelpSub),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openConnectHelper(context,
                    pickFiles: pickFiles, pickFolder: pickFolder),
              ),
              ListTile(
                key: const Key('sharesSettings'),
                leading: const Icon(Icons.ios_share),
                title: Text(l.settingsShares),
                subtitle: Text(l.settingsSharesSub),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => SharesPage(
                            pickFiles: pickFiles, pickFolder: pickFolder))),
              ),
              if (Platform.isAndroid) ...[
                SectionHeader(l.settingsSectionApp),
                SwitchListTile(
                  secondary: const Icon(Icons.sync_outlined),
                  title: Text(l.settingsBackground),
                  subtitle: Text(l.settingsBackgroundSub),
                  value: c.background,
                  onChanged: c.setBackground,
                ),
                ListTile(
                  leading: const Icon(Icons.power_settings_new),
                  title: Text(l.settingsQuit),
                  subtitle: Text(l.settingsQuitSub),
                  onTap: c.quit,
                ),
              ],
              const Divider(),
              ListTile(
                key: const Key('advancedSettings'),
                leading: const Icon(Icons.tune),
                title: Text(l.settingsAdvanced),
                subtitle: Text(l.settingsAdvancedSub),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            AdvancedSettingsPage(isAndroid: android))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
