// Wired links (DESIGN.md 3.5): interface classification, address ranking
// with link-local last, the link-local-only diagnosis, the cable wizard, and
// a capability record that only holds a 169.254 address.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/core/api.dart';
import 'package:landrop/core/diagnosis.dart';
import 'package:landrop/core/util.dart';
import 'package:landrop/ui/app.dart';
import 'package:landrop/ui/app_controller.dart';
import 'package:landrop/ui/cable_wizard.dart';
import 'package:landrop/ui/fake_core.dart';
import 'package:landrop/ui/hotspot_service.dart';
import 'package:landrop/ui/hotspot_wizard.dart';

InternetAddress _ip(String s) => InternetAddress(s);

DiagnosisInput _in(List<InterfaceObservation> ifaces) =>
    DiagnosisInput(interfaces: ifaces);

Future<FakeCore> _pumpApp(WidgetTester tester, {FakeCore? core}) async {
  tester.view.physicalSize = const Size(420, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  core ??= FakeCore(simulateDelay: const Duration(milliseconds: 10));
  await tester.pumpWidget(
    LanDropApp(
      core: core,
      store: MemorySettingsStore(),
      initialSaveDir: '/tmp/landrop-test',
      initialAlias: 'Tester',
      hotspotService: HotspotService(android: false),
    ),
  );
  await tester.pumpAndSettle();
  return core;
}

Future<void> _openCable(
  WidgetTester tester,
  HotspotPlatform platform, {
  List<String> own = const ['169.254.3.4'],
}) async {
  tester
      .state<NavigatorState>(find.byType(Navigator).first)
      .push(
        MaterialPageRoute(
          builder: (_) => CableWizardPage(
            platform: platform,
            localAddresses: () async => own,
          ),
        ),
      );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  group('interface names', () {
    test('virtual interfaces are not networks', () {
      for (final n in [
        'docker0',
        'br-1a2b3c4d',
        'veth12ab',
        'vmnet1',
        'vmnet8',
        'vboxnet0',
        'virbr0',
        'lxcbr0',
        'awdl0',
        'llw0',
        'bridge0',
        'anpi0',
        'vEthernet (WSL)',
        'lo',
        'lo0',
      ]) {
        expect(isVirtualInterface(n), isTrue, reason: n);
        expect(isRealInterface(n), isFalse, reason: n);
      }
    });

    test('real interfaces incl. USB tethers count', () {
      for (final n in [
        'rndis0',
        'usb0',
        'enx0a1b2c3d4e5f',
        'en0',
        'en5',
        'en7',
        'eth0',
        'eth1',
        'enp3s0',
        'wlan0',
        'wlp2s0',
        'Ethernet',
        'Ethernet 2',
        'Wi-Fi',
        'ap0',
      ]) {
        expect(isVirtualInterface(n), isFalse, reason: n);
        expect(isVpnInterface(n), isFalse, reason: n);
        expect(isRealInterface(n), isTrue, reason: n);
      }
    });

    test('isVpnInterface is unchanged', () {
      for (final n in ['utun3', 'tun0', 'tap0', 'ppp0', 'wg0', 'tailscale0']) {
        expect(isVpnInterface(n), isTrue, reason: n);
        expect(isRealInterface(n), isFalse, reason: n);
      }
      expect(isVpnInterface('docker0'), isFalse);
    });

    test('link-local detection', () {
      expect(isLinkLocalIPv4('169.254.1.2'), isTrue);
      expect(isLinkLocalIPv4('169.253.1.2'), isFalse);
      expect(isLinkLocalIPv4('192.168.1.2'), isFalse);
    });
  });

  group('address ranking', () {
    test('private, then other, then link-local; stable', () {
      final r = rankedIPv4([
        ('en5', [_ip('169.254.9.9')]),
        ('en0', [_ip('8.8.4.4'), _ip('192.168.1.10')]),
        ('eth1', [_ip('10.0.0.5')]),
      ]).map((a) => a.address).toList();
      expect(r, ['192.168.1.10', '10.0.0.5', '8.8.4.4', '169.254.9.9']);
    });

    test('link-local is used when nothing else exists', () {
      final r = rankedIPv4([
        ('en5', [_ip('169.254.9.9')]),
      ]);
      expect(r.map((a) => a.address), ['169.254.9.9']);
    });

    test('VPN, virtual and loopback interfaces are skipped', () {
      final r = rankedIPv4([
        ('utun4', [_ip('10.8.0.2')]),
        ('docker0', [_ip('172.17.0.1')]),
        ('br-abc', [_ip('172.18.0.1')]),
        ('awdl0', [_ip('169.254.1.1')]),
        ('vmnet8', [_ip('192.168.99.1')]),
        ('lo0', [_ip('127.0.0.1')]),
        ('eth0', [_ip('127.0.0.1'), _ip('192.168.1.7')]),
      ]);
      expect(r.map((a) => a.address), ['192.168.1.7']);
    });

    test('IPv6 entries are ignored', () {
      expect(
        rankedIPv4([
          ('eth0', [_ip('fe80::1')]),
        ]),
        isEmpty,
      );
    });

    test('probe targets: tether gateways, no .1 for link-local', () {
      final t = hotspotProbeTargets([
        '169.254.3.4',
      ], extraGateways: commonTetherGateways);
      expect(t, containsAll(['192.168.42.129', '192.168.42.1', '172.20.10.1']));
      expect(t, isNot(contains('169.254.3.1')));
      expect(t.toSet().length, t.length);
      expect(
        hotspotProbeTargets([
          '192.168.42.129',
        ], extraGateways: commonTetherGateways),
        isNot(contains('192.168.42.129')),
      );
      expect(
        hotspotProbeTargets(['10.1.2.3']),
        isNot(contains('192.168.42.129')),
      );
    });
  });

  group('diagnosis', () {
    const ll = InterfaceObservation('en5', ['169.254.7.8']);
    const wifi = InterfaceObservation('en0', ['192.168.1.10']);

    test('link-local only: info, cable action, not no-lan', () {
      expect(ruleNoLan(_in([ll])), isEmpty);
      final f = ruleLinkLocalOnly(_in([ll])).single;
      expect(f.code, 'link-local-only');
      expect(f.severity, Severity.info);
      expect(f.action, cableWizardAction);
      expect(f.detail, contains('direct cable or a network without DHCP'));
      expect(f.detail, contains('both devices must be connected'));
      final all = diagnose(_in([ll]));
      expect(all.map((x) => x.code), contains('link-local-only'));
      expect(all.map((x) => x.code), isNot(contains('no-lan')));
      expect(all.map((x) => x.code), isNot(contains('all-good')));
    });

    test('with a normal LAN the rule is silent', () {
      expect(ruleLinkLocalOnly(_in([wifi, ll])), isEmpty);
      expect(ruleNoLan(_in([wifi, ll])), isEmpty);
    });

    test('nothing, VPN, virtual or link-local on a bridge: still no-lan', () {
      expect(ruleLinkLocalOnly(_in(const [])), isEmpty);
      expect(ruleNoLan(_in(const [])).single.code, 'no-lan');
      for (final i in [
        const InterfaceObservation('utun2', ['169.254.1.1']),
        const InterfaceObservation('awdl0', ['169.254.1.1']),
        const InterfaceObservation('docker0', ['172.17.0.1']),
      ]) {
        expect(ruleLinkLocalOnly(_in([i])), isEmpty, reason: i.name);
        expect(ruleNoLan(_in([i])).single.code, 'no-lan', reason: i.name);
      }
    });

    test('summary marks virtual interfaces', () {
      final s = networkSummary(
        _in(const [
          InterfaceObservation('docker0', ['172.17.0.1']),
        ]),
      );
      expect(s.technical, contains('docker0 (virtual): 172.17.0.1'));
    });
  });

  group('cable wizard', () {
    test('steps exist for every platform and kind', () {
      for (final p in HotspotPlatform.values) {
        for (final k in CableKind.values) {
          expect(cableSteps(p, k), isNotEmpty, reason: '$p $k');
        }
      }
      expect(
        cableSteps(HotspotPlatform.macos, CableKind.ethernet).join(' '),
        allOf(contains('Using DHCP'), contains('169.254')),
      );
      expect(
        cableSteps(HotspotPlatform.windows, CableKind.ethernet).join(' '),
        contains('Network & internet > Ethernet'),
      );
      expect(
        cableSteps(HotspotPlatform.linux, CableKind.ethernet).join(' '),
        contains('link-local'),
      );
      expect(
        cableSteps(HotspotPlatform.android, CableKind.usbTether).join(' '),
        contains('USB tethering'),
      );
      expect(
        cableSteps(HotspotPlatform.ios, CableKind.usbTether).join(' '),
        contains('Personal Hotspot'),
      );
    });

    testWidgets('shows steps per platform and kind', (tester) async {
      await _pumpApp(tester);
      await _openCable(tester, HotspotPlatform.macos);
      expect(find.text('On this device (Mac)'), findsOneWidget);
      expect(_text(tester, 'cable-step-1'), contains('System Settings'));
      await _tap(tester, find.byKey(const Key('kindUsb')));
      expect(find.byKey(const Key('tetherPhoneHint')), findsOneWidget);
      expect(_text(tester, 'cable-step-0'), contains('USB cable'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _openCable(tester, HotspotPlatform.windows);
      expect(_text(tester, 'cable-step-1'), contains('Ethernet'));
    });

    testWidgets('find: probes tether gateways and shows the device', (
      tester,
    ) async {
      final core = FakeCore(simulateDelay: const Duration(milliseconds: 10))
        ..scanFindsDevice = false
        ..probeAnswers['192.168.42.129'] = const DeviceInfo(
          alias: 'Pixel',
          deviceType: 'mobile',
          fingerprint: 'tether01',
          ip: '192.168.42.129',
        );
      await _pumpApp(tester, core: core);
      core.setPeers(const []);
      await tester.pumpAndSettle();
      await _openCable(tester, HotspotPlatform.linux, own: ['192.168.42.20']);
      await _tap(tester, find.byKey(const Key('kindUsb')));
      await _tap(tester, find.byKey(const Key('findDevice')));
      expect(core.restartDiscoveryCalls, 1);
      expect(
        core.probeCalls.single,
        containsAll([
          '192.168.42.129',
          '192.168.42.1',
          '172.20.10.1',
          '192.168.43.1',
        ]),
      );
      expect(core.probeCalls.single, isNot(contains('192.168.42.20')));
      expect(find.byKey(const Key('found-tether01')), findsOneWidget);
    });

    testWidgets('find: nothing found shows the diagnosis', (tester) async {
      final core = FakeCore(
        simulateDelay: const Duration(milliseconds: 10),
        initialPeers: [],
      )..scanFindsDevice = false;
      await _pumpApp(tester, core: core);
      await _openCable(tester, HotspotPlatform.windows);
      await _tap(tester, find.byKey(const Key('findDevice')));
      expect(find.byKey(const Key('nothingFound')), findsOneWidget);
      expect(core.diagnosisCalls, [(null, null)]);
      // 169.254 own address: no .1 gateway is probed for it.
      expect(core.probeCalls.single, isNot(contains('169.254.3.1')));
    });

    testWidgets('entry points: empty list, hotspot wizard, diagnosis dialog', (
      tester,
    ) async {
      final core = await _pumpApp(tester);
      core.setPeers(const []);
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const Key('cableHelp')));
      expect(find.byKey(const Key('cableWizard')), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // From the hotspot wizard.
      await _tap(tester, find.byKey(const Key('hotspotHelp')));
      await _tap(tester, find.byKey(const Key('cableInstead')));
      expect(find.byKey(const Key('cableWizard')), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      // From a link-local finding in the diagnosis dialog.
      core.diagnosisFindings = const [
        Finding(
          Severity.info,
          'link-local-only',
          'Direct cable or no DHCP',
          'This looks like a direct cable.',
          action: cableWizardAction,
        ),
      ];
      await _tap(tester, find.byKey(const Key('whyNoDevices')));
      expect(find.text('Connect with a cable'), findsWidgets);
      await _tap(
        tester,
        find.byKey(const Key('findingAction-link-local-only')),
      );
      expect(find.byKey(const Key('cableWizard')), findsOneWidget);
    });
  });
}
