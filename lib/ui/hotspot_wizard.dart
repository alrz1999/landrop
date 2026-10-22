import 'dart:io';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/api.dart';
import '../core/util.dart' show hotspotProbeTargets, localIPv4Addresses;
import 'cable_wizard.dart' show openCableWizard;
import 'diagnosis_dialog.dart' show FindingTile;
import 'format.dart';
import 'hotspot_service.dart';
import 'l10n.dart';
import 'ltr_text.dart';
import 'widgets.dart';
import 'wifi_join_page.dart' show openWifiJoin;

enum HotspotPlatform { android, ios, macos, windows, linux, other }

enum HotspotRole { share, join }

HotspotPlatform currentHotspotPlatform() {
  if (Platform.isAndroid) return HotspotPlatform.android;
  if (Platform.isIOS) return HotspotPlatform.ios;
  if (Platform.isMacOS) return HotspotPlatform.macos;
  if (Platform.isWindows) return HotspotPlatform.windows;
  if (Platform.isLinux) return HotspotPlatform.linux;
  return HotspotPlatform.other;
}

String hotspotPlatformName(HotspotPlatform p, [AppLocalizations? l]) {
  l ??= englishStrings;
  return switch (p) {
    HotspotPlatform.android => l.platformAndroid,
    HotspotPlatform.ios => l.platformIos,
    HotspotPlatform.macos => l.platformMac,
    HotspotPlatform.windows => l.platformWindows,
    HotspotPlatform.linux => l.platformLinux,
    HotspotPlatform.other => l.platformOther,
  };
}

/// Shell commands quoted in the Linux steps (never translated).
const linuxHotspotCommand =
    'nmcli device wifi hotspot ssid LanDrop password <password>';
const linuxJoinCommand = 'nmcli device wifi connect <name> password <password>';

/// Plain-language steps for [role] on [p], in the language of [l] (English
/// when null).
List<String> hotspotSteps(HotspotPlatform p, HotspotRole role,
    [AppLocalizations? l]) {
  l ??= englishStrings;
  if (role == HotspotRole.share) {
    return switch (p) {
      HotspotPlatform.android => [
          l.hotspotShareAndroid1,
          l.hotspotShareAndroid2,
        ],
      HotspotPlatform.ios => [l.hotspotShareIos1, l.hotspotShareIos2],
      HotspotPlatform.macos => [l.hotspotShareMac1, l.hotspotShareMac2],
      HotspotPlatform.windows => [
          l.hotspotShareWindows1,
          l.hotspotShareWindows2,
        ],
      HotspotPlatform.linux => [
          l.hotspotShareLinux1(l.ltrValue(linuxHotspotCommand)),
          l.hotspotShareLinux2,
        ],
      HotspotPlatform.other => [l.hotspotShareOther1],
    };
  }
  return switch (p) {
    HotspotPlatform.android => [l.hotspotJoinAndroid1],
    HotspotPlatform.ios => [l.hotspotJoinIos1],
    HotspotPlatform.macos => [l.hotspotJoinMac1],
    HotspotPlatform.windows => [l.hotspotJoinWindows1],
    HotspotPlatform.linux => [l.hotspotJoinLinux1(l.ltrValue(linuxJoinCommand))],
    HotspotPlatform.other => [l.hotspotJoinOther1],
  };
}

/// "Connect without Wi-Fi / router": one device shares a hotspot, the other
/// joins it, then LanDrop looks for the other device on the new network.
class HotspotWizardPage extends StatefulWidget {
  const HotspotWizardPage({super.key, this.platform, this.localAddresses});

  /// Test seam; default [currentHotspotPlatform].
  final HotspotPlatform? platform;

  /// Test seam: this device's LAN addresses; default [localIPv4Addresses].
  final Future<List<String>> Function()? localAddresses;

  @override
  State<HotspotWizardPage> createState() => _HotspotWizardPageState();
}

class _HotspotWizardPageState extends State<HotspotWizardPage> {
  HotspotRole _role = HotspotRole.join;

  HotspotPlatform get _platform => widget.platform ?? currentHotspotPlatform();

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final p = _platform;
    final other =
        _role == HotspotRole.share ? HotspotRole.join : HotspotRole.share;
    final mine = [
      ...hotspotSteps(p, _role, l),
      if (_role == HotspotRole.share)
        l.hotspotStepShareOther
      else
        l.hotspotStepVpn,
      l.hotspotStepOpenBoth,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.hotspotWizardTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            key: const Key('hotspotWizard'),
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
            children: [
              Text(l.hotspotIntro, style: t.bodyMedium),
              const SizedBox(height: 16),
              SegmentedButton<HotspotRole>(
                segments: [
                  ButtonSegment(
                      value: HotspotRole.share,
                      icon: const Icon(Icons.wifi_tethering),
                      label: Text(l.hotspotRoleShare,
                          key: const Key('roleShare'))),
                  ButtonSegment(
                      value: HotspotRole.join,
                      icon: const Icon(Icons.wifi),
                      label: Text(l.hotspotRoleJoin,
                          key: const Key('roleJoin'))),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
              SectionHeader(l.wizardOnThisDevice(hotspotPlatformName(p, l))),
              WizardSteps(mine, keyPrefix: 'step'),
              if (p == HotspotPlatform.android &&
                  _role == HotspotRole.share &&
                  c.hotspotService.supported)
                const HotspotCard(),
              if (p == HotspotPlatform.android && _role == HotspotRole.join)
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 8),
                  child: FilledButton.icon(
                    key: const Key('scanHotspotQr'),
                    onPressed: () => openWifiJoin(context),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: Text(l.hotspotScanQr),
                  ),
                ),
              const SizedBox(height: 8),
              OtherDeviceSteps(
                tileKey: const Key('otherDevice'),
                role: other,
                title: other == HotspotRole.join
                    ? l.hotspotOtherJoin
                    : l.hotspotOtherShare,
              ),
              const SizedBox(height: 16),
              FindDevicePanel(
                label: l.hotspotFindLabel,
                localAddresses: widget.localAddresses,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                key: const Key('cableInstead'),
                onPressed: () => openCableWizard(context,
                    platform: widget.platform,
                    localAddresses: widget.localAddresses),
                icon: const Icon(Icons.cable),
                label: Text(l.hotspotCableInstead),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Collapsed card with what to do on the other device for [role], one block
/// per platform in [platforms] (every platform but "other" by default).
class OtherDeviceSteps extends StatelessWidget {
  const OtherDeviceSteps({
    super.key,
    required this.role,
    required this.title,
    this.platforms,
    this.initiallyExpanded = false,
    this.tileKey,
  });

  /// Key of the expandable tile (tap it to open).
  final Key? tileKey;

  final HotspotRole role;
  final String title;
  final List<HotspotPlatform>? platforms;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final shown = platforms ??
        [
          for (final op in HotspotPlatform.values)
            if (op != HotspotPlatform.other) op
        ];
    return Card(
      child: ExpansionTile(
        key: tileKey,
        title: Text(title),
        initiallyExpanded: initiallyExpanded,
        childrenPadding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final op in shown) ...[
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 8),
              child: Text(hotspotPlatformName(op, l), style: t.titleSmall),
            ),
            WizardSteps(hotspotSteps(op, role, l),
                keyPrefix: 'other-${op.name}'),
          ],
        ],
      ),
    );
  }
}

/// Android: start / show / stop the LanDrop hotspot (local-only hotspot).
class HotspotCard extends StatelessWidget {
  const HotspotCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final h = c.hotspot;
    final error = c.hotspotFailure?.localized(l) ?? c.hotspotError;
    return Card(
      key: const Key('hotspotCard'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (h == null) ...[
              FilledButton.tonalIcon(
                key: const Key('startHotspot'),
                onPressed: c.hotspotStarting ? null : c.startHotspot,
                icon: c.hotspotStarting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.wifi_tethering),
                label: Text(l.hotspotStart),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 8),
                  child: Text(error,
                      key: const Key('hotspotError'),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ),
            ] else ...[
              Text(l.hotspotOn, style: t.titleMedium),
              const SizedBox(height: 8),
              // Name and password are typed on the other device: LTR.
              SelectableText(l.hotspotName(l.ltrValue(h.ssid)),
                  key: const Key('hotspotSsid')),
              SelectableText(
                  h.password.isEmpty
                      ? l.hotspotNoPassword
                      : l.hotspotPassword(l.ltrValue(h.password)),
                  key: const Key('hotspotPassword')),
              const SizedBox(height: 12),
              Center(
                child: Semantics(
                  label: l.hotspotQrSemantics,
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(8),
                    child: QrImageView(
                      key: const Key('hotspotQr'),
                      data: wifiQrPayload(h.ssid, h.password),
                      size: 180,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(l.hotspotScanHint,
                  style: t.bodySmall, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('stopHotspot'),
                onPressed: c.stopHotspot,
                icon: const Icon(Icons.stop_circle_outlined),
                label: Text(l.hotspotStop),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Opens the wizard.
Future<void> openHotspotWizard(BuildContext context) => Navigator.push(
    context, MaterialPageRoute(builder: (_) => const HotspotWizardPage()));

/// Numbered plain-language steps; step i has the key `'$keyPrefix-$i'`.
class WizardSteps extends StatelessWidget {
  const WizardSteps(this.steps, {super.key, required this.keyPrefix});
  final List<String> steps;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, s) in steps.indexed)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                    radius: 12,
                    child: Text(context.l.digits(i + 1),
                        style: t.labelMedium)),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(s,
                        key: Key('$keyPrefix-$i'), style: t.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}

/// The "find the other device" button of the hotspot and cable wizards, with
/// its progress line and results: re-reads the interfaces
/// ([AppController.restartDiscovery]), probes the usual gateway addresses
/// ([hotspotProbeTargets] plus [extraGateways]), scans the subnet, and runs
/// the diagnosis when nothing is found.
class FindDevicePanel extends StatefulWidget {
  const FindDevicePanel({
    super.key,
    required this.label,
    this.localAddresses,
    this.extraGateways = const [],
    this.autoStart = false,
    this.phaseProbe,
    this.nothingFoundHint,
    this.onFound,
  });

  final String label;

  /// Test seam: this device's LAN addresses; default [localIPv4Addresses].
  final Future<List<String>> Function()? localAddresses;
  final List<String> extraGateways;

  /// Start searching as soon as the panel appears.
  final bool autoStart;

  /// Progress line while probing; default "Checking the usual hotspot
  /// addresses…".
  final String? phaseProbe;

  /// Shown when nothing was found; default: same hotspot, Add by IP.
  final String? nothingFoundHint;

  /// Called after every search with what it found (empty: nothing).
  final void Function(List<DeviceInfo> found)? onFound;

  @override
  State<FindDevicePanel> createState() => _FindDevicePanelState();
}

class _FindDevicePanelState extends State<FindDevicePanel> {
  bool _searching = false;
  String? _phase;

  /// Devices found by the last search (null: not searched yet).
  List<DeviceInfo>? _found;

  /// Diagnosis run when the last search found nothing.
  List<Finding>? _findings;

  static Future<List<String>> _defaultAddresses() async =>
      [for (final a in await localIPv4Addresses()) a.address];

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _find();
      });
    }
  }

  Future<void> _find() async {
    final c = AppScope.read(context);
    final l = context.l;
    setState(() {
      _searching = true;
      _found = null;
      _findings = null;
      _phase = l.findPhaseNetwork;
    });
    final byFp = <String, DeviceInfo>{};
    try {
      await c.restartDiscovery();
      List<String> own = const [];
      try {
        own = await (widget.localAddresses ?? _defaultAddresses)();
      } catch (_) {}
      if (mounted) {
        setState(() => _phase = widget.phaseProbe ?? l.findPhaseProbeHotspot);
      }
      final targets =
          hotspotProbeTargets(own, extraGateways: widget.extraGateways);
      for (final d in await c.probeAddresses(targets)) {
        byFp[d.fingerprint] = d;
      }
      if (mounted) setState(() => _phase = l.findPhaseScan);
      await c.rescan();
      for (final d in c.peers) {
        byFp.putIfAbsent(d.fingerprint, () => d);
      }
      List<Finding>? findings;
      if (byFp.isEmpty) {
        if (mounted) setState(() => _phase = l.findPhaseWhy);
        findings = await c.runDiagnosis();
      }
      if (!mounted) return;
      setState(() {
        _found = byFp.values.toList();
        _findings = findings;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _found = byFp.values.toList();
        _findings = [
          Finding(Severity.problem, 'search-failed', l.diagSearchFailedTitle,
              '$e')
        ];
      });
    } finally {
      if (mounted) setState(() => _searching = false);
    }
    if (mounted) widget.onFound?.call(byFp.values.toList());
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          key: const Key('findDevice'),
          onPressed: _searching ? null : _find,
          icon: _searching
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.search),
          label: Text(widget.label),
        ),
        if (_searching && _phase != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 8),
            child: Text(_phase!, key: const Key('searchPhase')),
          ),
        ..._results(t),
      ],
    );
  }

  List<Widget> _results(TextTheme t) {
    final found = _found;
    if (found == null || _searching) return const [];
    final l = context.l;
    if (found.isNotEmpty) {
      return [
        SectionHeader(l.findFound(found.length)),
        Card(
          child: Column(children: [
            for (final d in found)
              ListTile(
                key: Key('found-${d.fingerprint}'),
                leading: CircleAvatar(child: Icon(deviceIcon(d.deviceType))),
                title: AutoDirText(d.alias),
                subtitle: LtrText('${d.ip}:${d.port}'),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('wizardDone'),
          onPressed: () => Navigator.maybePop(context),
          child: Text(l.findBackToDevices),
        ),
      ];
    }
    return [
      const SizedBox(height: 16),
      Text(l.findNothingTitle,
          key: const Key('nothingFound'), style: t.titleMedium),
      const SizedBox(height: 4),
      Text(widget.nothingFoundHint ?? l.findNothingHintHotspot,
          style: t.bodyMedium),
      for (final f in _findings ?? const <Finding>[]) FindingTile(finding: f),
    ];
  }
}
