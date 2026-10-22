import 'package:flutter/material.dart';

import '../core/util.dart' show commonTetherGateways;
import 'hotspot_wizard.dart';
import 'l10n.dart';
import 'widgets.dart';

/// Which cable setup the user wants help with.
enum CableKind { ethernet, usbTether }

/// Shell command quoted in the Linux Ethernet steps (never translated).
const linuxLinkLocalCommand = 'nmcli connection add type ethernet ifname '
    '<device> con-name landrop-cable ipv4.method link-local';

/// Address prefix a computer gives itself without a router.
const linkLocalPrefix = '169.254';

/// Plain-language steps for [kind] on [p] (the device this app runs on), in
/// the language of [l] (English when null).
List<String> cableSteps(HotspotPlatform p, CableKind kind,
    [AppLocalizations? l]) {
  l ??= englishStrings;
  if (kind == CableKind.ethernet) {
    return switch (p) {
      HotspotPlatform.macos => [
        l.cableEthMac1,
        l.cableEthMac2,
        l.cableEthMac3(l.ltrValue(linkLocalPrefix)),
      ],
      HotspotPlatform.windows => [
        l.cableEthPlugBoth,
        l.cableEthWindows2(l.ltrValue(linkLocalPrefix)),
        l.cableEthWindows3,
      ],
      HotspotPlatform.linux => [
        l.cableEthPlugBoth,
        l.cableEthLinux2(l.ltrValue(linuxLinkLocalCommand)),
        l.cableEthLinux3,
      ],
      _ => [l.cableEthOther1],
    };
  }
  return switch (p) {
    HotspotPlatform.android => [l.cableUsbAndroid1, l.cableUsbAndroid2],
    HotspotPlatform.ios => [l.cableUsbIos1, l.cableUsbIos2],
    HotspotPlatform.macos => [l.cableUsbMac1, l.cableUsbMac2],
    HotspotPlatform.windows => [l.cableUsbWindows1, l.cableUsbWindows2],
    HotspotPlatform.linux => [l.cableUsbLinux1, l.cableUsbLinux2],
    HotspotPlatform.other => [l.cableUsbOther1],
  };
}

/// "Connect with a cable": Ethernet between two computers, or USB tethering,
/// then LanDrop looks for the other device (same search as the hotspot
/// wizard, with the usual USB tether gateways added).
class CableWizardPage extends StatelessWidget {
  const CableWizardPage({super.key, this.platform, this.localAddresses});

  /// Test seam; default [currentHotspotPlatform].
  final HotspotPlatform? platform;

  /// Test seam: this device's LAN addresses.
  final Future<List<String>> Function()? localAddresses;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Scaffold(
      appBar: AppBar(title: Text(l.connectCableTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            key: const Key('cableWizard'),
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
            children: [
              Text(l.cableIntro, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              CableSetup(
                  platform: platform ?? currentHotspotPlatform(),
                  localAddresses: localAddresses),
            ],
          ),
        ),
      ),
    );
  }
}

/// The cable steps: Ethernet or USB tethering, the steps for [platform],
/// and the search for the other device. Shared by [CableWizardPage] and the
/// connection helper.
class CableSetup extends StatefulWidget {
  const CableSetup({
    super.key,
    required this.platform,
    this.localAddresses,
    this.initialKind,
  });

  final HotspotPlatform platform;
  final Future<List<String>> Function()? localAddresses;

  /// Default: Ethernet.
  final CableKind? initialKind;

  @override
  State<CableSetup> createState() => _CableSetupState();
}

class _CableSetupState extends State<CableSetup> {
  late CableKind _kind = widget.initialKind ?? CableKind.ethernet;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final p = widget.platform;
    final steps = [
      ...cableSteps(p, _kind, l),
      if (_kind == CableKind.ethernet) l.cableStepWait else l.cableStepVpn,
      l.cableStepOpenBoth,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<CableKind>(
          segments: [
            ButtonSegment(
              value: CableKind.ethernet,
              icon: const Icon(Icons.cable),
              label: Text(l.cableKindEthernet, key: const Key('kindEthernet')),
            ),
            ButtonSegment(
              value: CableKind.usbTether,
              icon: const Icon(Icons.usb),
              label: Text(l.cableKindUsb, key: const Key('kindUsb')),
            ),
          ],
          selected: {_kind},
          onSelectionChanged: (s) => setState(() => _kind = s.first),
        ),
        SectionHeader(l.wizardOnThisDevice(hotspotPlatformName(p, l))),
        WizardSteps(steps, keyPrefix: 'cable-step'),
        if (_kind == CableKind.usbTether) ...[
          const SizedBox(height: 4),
          Text(
            l.cableTetherHint,
            key: const Key('tetherPhoneHint'),
            style: t.bodySmall,
          ),
        ],
        const SizedBox(height: 16),
        FindDevicePanel(
          label: l.cableFindLabel,
          localAddresses: widget.localAddresses,
          extraGateways: commonTetherGateways,
          phaseProbe: l.cablePhaseProbe,
          nothingFoundHint: l.cableNothingHint,
        ),
      ],
    );
  }
}

/// Opens the cable wizard.
Future<void> openCableWizard(
  BuildContext context, {
  HotspotPlatform? platform,
  Future<List<String>> Function()? localAddresses,
}) => Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) =>
        CableWizardPage(platform: platform, localAddresses: localAddresses),
  ),
);
