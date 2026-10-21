import 'package:flutter/material.dart';

import '../core/util.dart' show commonTetherGateways;
import 'hotspot_wizard.dart';
import 'widgets.dart';

/// Which cable setup the user wants help with.
enum CableKind { ethernet, usbTether }

/// Plain-language steps for [kind] on [p] (the device this app runs on).
List<String> cableSteps(HotspotPlatform p, CableKind kind) {
  if (kind == CableKind.ethernet) {
    return switch (p) {
      HotspotPlatform.macos => const [
        'Plug the Ethernet cable into both computers (a USB or Thunderbolt '
            'Ethernet adapter is fine). Cable or router: the same steps.',
        'Open System Settings > Network. If the adapter is not listed, '
            'click "…" > "Add Service…" (or the + button), pick the '
            'Ethernet adapter and click Create.',
        'Select it and set "Configure IPv4" to "Using DHCP". With no router '
            'the Mac gives itself an address starting with 169.254. That is '
            'normal.',
      ],
      HotspotPlatform.windows => const [
        'Plug the Ethernet cable into both computers.',
        'Open Settings > Network & internet > Ethernet. It should say '
            '"No Internet" or "Unidentified network": that is fine, Windows '
            'gives itself an address starting with 169.254.',
        'Under "IP assignment" keep "Automatic (DHCP)". On the Windows '
            'Firewall prompt, allow LanDrop on Private networks. If the '
            'network is marked "Public", set it to Private.',
      ],
      HotspotPlatform.linux => const [
        'Plug the Ethernet cable into both computers.',
        'Open Settings > Network, pick the wired connection and open its '
            'settings > IPv4. Choose the "Link-Local Only" method and '
            'apply. Or run: nmcli connection add type ethernet ifname '
            '<device> con-name landrop-cable ipv4.method link-local',
        'Turn the connection off and on so it gets an address.',
      ],
      _ => const [
        'Plug an Ethernet cable (with an adapter if needed) into both '
            'computers, and make sure the wired network uses automatic '
            'addresses (DHCP or "link-local").',
      ],
    };
  }
  return switch (p) {
    HotspotPlatform.android => const [
      'This phone is the one sharing: connect it to the computer with a USB '
          'cable.',
      'Open Settings > Network & internet > Hotspot & tethering (names '
          'differ a little by brand), then turn on "USB tethering". It only '
          'switches on while a computer is plugged in.',
    ],
    HotspotPlatform.ios => const [
      'Connect the iPhone to the computer with a USB cable and tap "Trust" '
          'if asked.',
      'Open Settings > Personal Hotspot and turn on "Allow Others to Join". '
          'On a Windows PC, iTunes or the Apple Devices app must be '
          'installed.',
    ],
    HotspotPlatform.macos => const [
      'Connect the phone to this Mac with a USB cable. On the phone turn on '
          'Personal Hotspot (iPhone) or USB tethering (Android).',
      'The Mac shows a new network adapter in System Settings > Network '
          '(for example "iPhone USB" or "RNDIS/Ethernet Gadget"). Android '
          'USB tethering needs a driver on a Mac, which is not built in; an '
          'iPhone works out of the box.',
    ],
    HotspotPlatform.windows => const [
      'Connect the phone to this PC with a USB cable. On the phone turn on '
          'USB tethering (Android) or Personal Hotspot (iPhone).',
      'Windows adds a new adapter (shown in Settings > Network & internet '
          '> Advanced network settings). Wait until it says Connected.',
    ],
    HotspotPlatform.linux => const [
      'Connect the phone to this computer with a USB cable. On the phone '
          'turn on USB tethering (Android) or Personal Hotspot (iPhone).',
      'A new wired connection appears (named like usb0, enx… or eth1). It '
          'usually connects by itself.',
    ],
    HotspotPlatform.other => const [
      'Connect the phone with a USB cable and turn on USB tethering or '
          'Personal Hotspot; the computer then has a new network adapter.',
    ],
  };
}

/// "Connect with a cable": Ethernet between two computers, or USB tethering,
/// then LanDrop looks for the other device (same search as the hotspot
/// wizard, with the usual USB tether gateways added).
class CableWizardPage extends StatefulWidget {
  const CableWizardPage({super.key, this.platform, this.localAddresses});

  /// Test seam; default [currentHotspotPlatform].
  final HotspotPlatform? platform;

  /// Test seam: this device's LAN addresses.
  final Future<List<String>> Function()? localAddresses;

  @override
  State<CableWizardPage> createState() => _CableWizardPageState();
}

class _CableWizardPageState extends State<CableWizardPage> {
  CableKind _kind = CableKind.ethernet;

  HotspotPlatform get _platform => widget.platform ?? currentHotspotPlatform();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = _platform;
    final steps = [
      ...cableSteps(p, _kind),
      if (_kind == CableKind.ethernet)
        'Wait a few seconds: with no router it takes up to a minute for both '
            'computers to get their addresses.'
      else
        'Turn off any VPN. The other device now shares its connection to this '
            'one.',
      'Open LanDrop on both devices, then tap "The cable is connected, find '
          'the other device".',
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Connect with a cable')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            key: const Key('cableWizard'),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(
                'No Wi-Fi or router needed: connect the two devices with a '
                'cable and LanDrop finds the other device on that link. Files '
                'go directly over the cable.',
                style: t.bodyMedium,
              ),
              const SizedBox(height: 16),
              SegmentedButton<CableKind>(
                segments: const [
                  ButtonSegment(
                    value: CableKind.ethernet,
                    icon: Icon(Icons.cable),
                    label: Text('Ethernet cable', key: Key('kindEthernet')),
                  ),
                  ButtonSegment(
                    value: CableKind.usbTether,
                    icon: Icon(Icons.usb),
                    label: Text('USB tethering', key: Key('kindUsb')),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              SectionHeader('On this device (${hotspotPlatformName(p)})'),
              WizardSteps(steps, keyPrefix: 'cable-step'),
              if (_kind == CableKind.usbTether) ...[
                const SizedBox(height: 4),
                Text(
                  'On the phone: Android > Settings > Network & internet > '
                  'Hotspot & tethering > USB tethering. iPhone > Settings > '
                  'Personal Hotspot.',
                  key: const Key('tetherPhoneHint'),
                  style: t.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              FindDevicePanel(
                label: 'The cable is connected, find the other device',
                localAddresses: widget.localAddresses,
                extraGateways: commonTetherGateways,
                phaseProbe: 'Checking the usual cable and USB addresses…',
                nothingFoundHint:
                    'Check the cable, that the adapter shows as connected, '
                    'and that LanDrop is open on both devices. A direct '
                    'cable can take up to a minute to get addresses. Then '
                    'try again, or use "Add by IP" with the address shown on '
                    'the other device.',
              ),
            ],
          ),
        ),
      ),
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
