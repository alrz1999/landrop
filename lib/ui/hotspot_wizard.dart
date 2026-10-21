import 'dart:io';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/api.dart';
import '../core/util.dart' show hotspotProbeTargets, localIPv4Addresses;
import 'cable_wizard.dart' show openCableWizard;
import 'diagnosis_dialog.dart' show FindingTile;
import 'format.dart';
import 'hotspot_service.dart';
import 'widgets.dart';

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

String hotspotPlatformName(HotspotPlatform p) => switch (p) {
      HotspotPlatform.android => 'Android',
      HotspotPlatform.ios => 'iPhone / iPad',
      HotspotPlatform.macos => 'Mac',
      HotspotPlatform.windows => 'Windows',
      HotspotPlatform.linux => 'Linux',
      HotspotPlatform.other => 'Other devices',
    };

/// Plain-language steps for [role] on [p].
List<String> hotspotSteps(HotspotPlatform p, HotspotRole role) {
  if (role == HotspotRole.share) {
    return switch (p) {
      HotspotPlatform.android => const [
          'Tap "Start hotspot" below: LanDrop makes a private hotspot (no '
              'mobile data is shared) and shows a QR code the other device '
              'can scan to join. This phone may leave its Wi-Fi while it '
              'runs.',
          'Or use the normal hotspot: Settings > Network & internet > Hotspot '
              '& tethering > Wi-Fi hotspot (names differ a little by brand). '
              'Turn it on and note its name and password.',
        ],
      HotspotPlatform.ios => const [
          'Open Settings > Personal Hotspot and turn on "Allow Others to '
              'Join". (Your mobile plan must allow hotspot use.)',
          'Keep that screen open until the other device has joined: it shows '
              'the Wi-Fi password.',
        ],
      HotspotPlatform.macos => const [
          'Easiest: do it the other way round. Let the other device share a '
              'hotspot and join it from this Mac (choose "This device joins '
              'it" above).',
          'To share from this Mac anyway: System Settings > General > Sharing, '
              'click (i) next to Internet Sharing, share your connection '
              '(for example Ethernet) to computers using Wi-Fi, set a network '
              'name and password, then turn Internet Sharing on.',
        ],
      HotspotPlatform.windows => const [
          'Open Settings > Network & internet > Mobile hotspot.',
          'Turn on "Mobile hotspot". The network name and password are shown '
              'on that page.',
        ],
      HotspotPlatform.linux => const [
          'Open Settings > Wi-Fi, open the menu (⋮) and choose "Turn On Wi-Fi '
              'Hotspot…". On other desktops use NetworkManager: create a new '
              'Wi-Fi network with mode "Hotspot", or run: nmcli device wifi '
              'hotspot ssid LanDrop password <password>',
          'Note the network name and password.',
        ],
      HotspotPlatform.other => const [
          'Turn on the hotspot ("tethering") in this device\'s network '
              'settings and note its name and password.',
        ],
    };
  }
  return switch (p) {
    HotspotPlatform.android => const [
        'Open Settings > Wi-Fi and pick the other device\'s hotspot, then '
            'enter its password. Or tap the QR icon next to "Add network" and '
            'scan the code shown on the other device.',
      ],
    HotspotPlatform.ios => const [
        'Open Settings > Wi-Fi and pick the other device\'s hotspot, then '
            'enter its password. Or point the Camera at the QR code shown on '
            'the other device and tap "Join network".',
      ],
    HotspotPlatform.macos => const [
        'Click the Wi-Fi icon in the menu bar (or Control Center), pick the '
            'other device\'s hotspot and enter its password.',
      ],
    HotspotPlatform.windows => const [
        'Click the network icon in the taskbar, open the Wi-Fi list, pick the '
            'other device\'s hotspot and enter its password.',
      ],
    HotspotPlatform.linux => const [
        'Open the network menu (top right) > Wi-Fi > Select network, pick the '
            'other device\'s hotspot and enter its password. Or run: nmcli '
            'device wifi connect <name> password <password>',
      ],
    HotspotPlatform.other => const [
        'Open the Wi-Fi settings, pick the other device\'s hotspot and enter '
            'its password.',
      ],
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
    final t = Theme.of(context).textTheme;
    final p = _platform;
    final other =
        _role == HotspotRole.share ? HotspotRole.join : HotspotRole.share;
    final mine = [
      ...hotspotSteps(p, _role),
      if (_role == HotspotRole.share)
        'On the other device, join this hotspot like any Wi-Fi network (see '
            'below).'
      else
        'Turn off any VPN. Mobile data can stay on.',
      'Open LanDrop on both devices, then tap "I\'m connected, find the '
          'other device".',
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Connect without Wi-Fi')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            key: const Key('hotspotWizard'),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(
                'No router needed: one device shares a Wi-Fi hotspot, the '
                'other joins it, and LanDrop finds the other device on that '
                'network. This also helps when the Wi-Fi keeps devices apart '
                '(guest, office or hotel networks). Files go directly between '
                'the two devices and do not use mobile data.',
                style: t.bodyMedium,
              ),
              const SizedBox(height: 16),
              SegmentedButton<HotspotRole>(
                segments: const [
                  ButtonSegment(
                      value: HotspotRole.share,
                      icon: Icon(Icons.wifi_tethering),
                      label: Text('This device shares the hotspot',
                          key: Key('roleShare'))),
                  ButtonSegment(
                      value: HotspotRole.join,
                      icon: Icon(Icons.wifi),
                      label: Text('This device joins it',
                          key: Key('roleJoin'))),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
              SectionHeader('On this device (${hotspotPlatformName(p)})'),
              WizardSteps(mine, keyPrefix: 'step'),
              if (p == HotspotPlatform.android &&
                  _role == HotspotRole.share &&
                  c.hotspotService.supported)
                const HotspotCard(),
              const SizedBox(height: 8),
              Card(
                child: ExpansionTile(
                  key: const Key('otherDevice'),
                  title: Text(other == HotspotRole.join
                      ? 'On the other device: join the hotspot'
                      : 'On the other device: share a hotspot'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final op in HotspotPlatform.values)
                      if (op != HotspotPlatform.other) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(hotspotPlatformName(op),
                              style: t.titleSmall),
                        ),
                        WizardSteps(hotspotSteps(op, other),
                            keyPrefix: 'other-${op.name}'),
                      ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FindDevicePanel(
                label: "I'm connected, find the other device",
                localAddresses: widget.localAddresses,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                key: const Key('cableInstead'),
                onPressed: () => openCableWizard(context,
                    platform: widget.platform,
                    localAddresses: widget.localAddresses),
                icon: const Icon(Icons.cable),
                label: const Text('Using a cable instead? Ethernet or USB'),
              ),
            ],
          ),
        ),
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
    final t = Theme.of(context).textTheme;
    final h = c.hotspot;
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
                label: const Text('Start hotspot'),
              ),
              if (c.hotspotError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(c.hotspotError!,
                      key: const Key('hotspotError'),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ),
            ] else ...[
              Text('Hotspot is on', style: t.titleMedium),
              const SizedBox(height: 8),
              SelectableText('Name: ${h.ssid}', key: const Key('hotspotSsid')),
              SelectableText(
                  h.password.isEmpty
                      ? 'No password'
                      : 'Password: ${h.password}',
                  key: const Key('hotspotPassword')),
              const SizedBox(height: 12),
              Center(
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
              const SizedBox(height: 4),
              Text(
                'Scan with the other device\'s camera to join (Android 10+, '
                'iPhone). The hotspot stops when you tap Stop or close '
                'LanDrop.',
                style: t.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('stopHotspot'),
                onPressed: c.stopHotspot,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Stop hotspot'),
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
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                    radius: 12, child: Text('${i + 1}', style: t.labelMedium)),
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
    this.phaseProbe = 'Checking the usual hotspot addresses…',
    this.nothingFoundHint =
        'Check that both devices are on the same hotspot and LanDrop is open '
            'on both. Then try again, or use "Add by IP" with the address '
            'shown on the other device.',
  });

  final String label;

  /// Test seam: this device's LAN addresses; default [localIPv4Addresses].
  final Future<List<String>> Function()? localAddresses;
  final List<String> extraGateways;
  final String phaseProbe;
  final String nothingFoundHint;

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

  Future<void> _find() async {
    final c = AppScope.read(context);
    setState(() {
      _searching = true;
      _found = null;
      _findings = null;
      _phase = 'Looking at the new network…';
    });
    final byFp = <String, DeviceInfo>{};
    try {
      await c.restartDiscovery();
      List<String> own = const [];
      try {
        own = await (widget.localAddresses ?? _defaultAddresses)();
      } catch (_) {}
      if (mounted) setState(() => _phase = widget.phaseProbe);
      final targets =
          hotspotProbeTargets(own, extraGateways: widget.extraGateways);
      for (final d in await c.probeAddresses(targets)) {
        byFp[d.fingerprint] = d;
      }
      if (mounted) setState(() => _phase = 'Scanning the network…');
      await c.rescan();
      for (final d in c.peers) {
        byFp.putIfAbsent(d.fingerprint, () => d);
      }
      List<Finding>? findings;
      if (byFp.isEmpty) {
        if (mounted) setState(() => _phase = 'Nothing found. Checking why…');
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
          Finding(Severity.problem, 'search-failed', 'The search failed', '$e')
        ];
      });
    } finally {
      if (mounted) setState(() => _searching = false);
    }
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
            padding: const EdgeInsets.only(top: 8),
            child: Text(_phase!, key: const Key('searchPhase')),
          ),
        ..._results(t),
      ],
    );
  }

  List<Widget> _results(TextTheme t) {
    final found = _found;
    if (found == null || _searching) return const [];
    if (found.isNotEmpty) {
      return [
        SectionHeader(
            'Found ${found.length} device${found.length == 1 ? '' : 's'}'),
        Card(
          child: Column(children: [
            for (final d in found)
              ListTile(
                key: Key('found-${d.fingerprint}'),
                leading: CircleAvatar(child: Icon(deviceIcon(d.deviceType))),
                title: Text(d.alias),
                subtitle: Text('${d.ip}:${d.port}'),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('wizardDone'),
          onPressed: () => Navigator.maybePop(context),
          child: const Text('Back to devices'),
        ),
      ];
    }
    return [
      const SizedBox(height: 16),
      Text('No device found yet',
          key: const Key('nothingFound'), style: t.titleMedium),
      const SizedBox(height: 4),
      Text(widget.nothingFoundHint, style: t.bodyMedium),
      for (final f in _findings ?? const <Finding>[]) FindingTile(finding: f),
    ];
  }
}
