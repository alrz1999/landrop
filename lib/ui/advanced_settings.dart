import 'dart:io';

import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'cable_wizard.dart';
import 'diagnosis_dialog.dart';
import 'format.dart';
import 'hotspot_wizard.dart';
import 'l10n.dart';
import 'ltr_text.dart';
import 'wifi_direct_page.dart';
import 'wifi_join_page.dart';
import 'widgets.dart';

/// Settings ▸ Advanced (UX.md 3.5, step U3): this device's address and QR,
/// security code, browser options, restart, connection report and every
/// connection method. Experts lose nothing; they need one more tap.
class AdvancedSettingsPage extends StatelessWidget {
  const AdvancedSettingsPage({super.key, this.isAndroid});

  /// Test seam for the Android-only entries; default [Platform.isAndroid].
  final bool? isAndroid;

  Future<void> _setWebHttp(
      BuildContext context, AppController c, bool on) async {
    if (on) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final l = ctx.l;
          return AlertDialog(
            key: const Key('confirmWebHttp'),
            icon: const Icon(Icons.warning_amber_rounded),
            title: Text(l.webHttpConfirmTitle),
            content: Text(l.webHttpConfirmBody),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l.commonCancel)),
              FilledButton(
                  key: const Key('confirmWebHttpOn'),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l.webHttpConfirmOn)),
            ],
          );
        },
      );
      if (ok != true) return;
    }
    try {
      await c.setWebHttp(on);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l.errorWebHttp('$e'))));
      }
    }
  }

  String _status(AppLocalizations l, AppController c) => switch (c.status) {
        CoreStatus.running => l.serviceRunning,
        CoreStatus.starting => l.serviceStarting,
        CoreStatus.stopped => l.serviceStopped,
        CoreStatus.error => l.serviceError,
      };

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final fp = c.self?.fingerprint;
    final android = isAndroid ?? Platform.isAndroid;
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsAdvanced)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            key: const Key('advancedPage'),
            padding: const EdgeInsetsDirectional.only(bottom: 24),
            children: [
              SectionHeader(l.advancedSectionAddress),
              const Padding(
                padding: EdgeInsetsDirectional.symmetric(horizontal: 12),
                child: QrCard(),
              ),
              if (fp != null)
                ListTile(
                  key: const Key('securityCode'),
                  leading: const Icon(Icons.fingerprint),
                  title: Text(l.securityCode),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LtrText(shortFingerprint(fp),
                          key: const Key('securityCodeValue'),
                          selectable: true),
                      Text(l.securityCodeHint, style: t.bodySmall),
                    ],
                  ),
                ),
              ListTile(
                key: const Key('restartService'),
                leading: const Icon(Icons.restart_alt),
                title: Text(l.advancedRestart),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_status(l, c)),
                    // Technical, for support; stays in English.
                    if (c.lastError != null)
                      LtrText(c.lastError!,
                          key: const Key('lastError'),
                          style: t.bodySmall,
                          selectable: true),
                  ],
                ),
                onTap: c.restart,
              ),
              SectionHeader(l.advancedSectionBrowsers),
              SwitchListTile(
                key: const Key('webHttpSwitch'),
                secondary: const Icon(Icons.no_encryption_gmailerrorred),
                title: Text(l.webHttpTitle),
                subtitle: Text(l.webHttpSub),
                value: c.webHttpEnabled,
                onChanged: (v) => _setWebHttp(context, c, v),
              ),
              if (c.webHttpEnabled)
                ListTile(
                  key: const Key('webHttpUrlTile'),
                  leading: const Icon(Icons.public),
                  title: Text(l.webHttpUrlTitle),
                  subtitle: c.webHttpUrl == null
                      ? Text(l.serviceStarting)
                      : LtrText(c.webHttpUrl!, selectable: true),
                ),
              SwitchListTile(
                key: const Key('keepSharesSwitch'),
                secondary: const Icon(Icons.history),
                title: Text(l.keepSharesTitle),
                subtitle: Text(l.keepSharesSub),
                value: c.keepShares,
                onChanged: c.setKeepShares,
              ),
              SectionHeader(l.advancedSectionTroubleshoot),
              ListTile(
                key: const Key('diagnoseSettings'),
                leading: const Icon(Icons.troubleshoot),
                title: Text(l.advancedReport),
                subtitle: Text(l.advancedReportSub),
                onTap: () => showDiagnosisDialog(context),
              ),
              SectionHeader(l.advancedSectionMethods),
              ListTile(
                key: const Key('hotspotSettings'),
                leading: const Icon(Icons.wifi_tethering),
                title: Text(l.connectHotspotTitle),
                subtitle: Text(l.connectHotspotSub),
                onTap: () => openHotspotWizard(context),
              ),
              ListTile(
                key: const Key('cableSettings'),
                leading: const Icon(Icons.cable),
                title: Text(l.connectCableTitle),
                subtitle: Text(l.connectCableSub),
                onTap: () => openCableWizard(context),
              ),
              if (android)
                ListTile(
                  key: const Key('wifiDirectSettings'),
                  leading: const Icon(Icons.wifi_find),
                  title: Text(l.connectWifiDirectTitle),
                  subtitle: Text(l.connectWifiDirectSub),
                  onTap: () => openWifiDirect(context),
                ),
              if (android)
                ListTile(
                  key: const Key('wifiJoinSettings'),
                  leading: const Icon(Icons.qr_code_scanner),
                  title: Text(l.connectWifiJoinTitle),
                  subtitle: Text(l.connectWifiJoinSub),
                  onTap: () => openWifiJoin(context),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
