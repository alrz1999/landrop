// "Can't find the other device?" connection helper (docs/UX.md 3.4, step
// U4): automatic check, the two questions, one method per answer built from
// the existing wizard widgets, entry points, "Try another way", copy report.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/core/api.dart';
import 'package:landrop/ui/app.dart';
import 'package:landrop/ui/app_controller.dart';
import 'package:landrop/ui/cable_wizard.dart';
import 'package:landrop/ui/connect_helper.dart';
import 'package:landrop/ui/fake_core.dart';
import 'package:landrop/ui/hotspot_service.dart';
import 'package:landrop/ui/hotspot_wizard.dart';

Future<FakeCore> _pumpApp(WidgetTester tester,
    {FakeCore? core, HotspotService? hotspot}) async {
  tester.view.physicalSize = const Size(420, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  core ??= FakeCore(simulateDelay: const Duration(milliseconds: 10));
  await tester.pumpWidget(LanDropApp(
    core: core,
    store: MemorySettingsStore(),
    initialSaveDir: '/tmp/landrop-test',
    initialAlias: 'Tester',
    pickFiles: () async => ['/x/a.txt'],
    hotspotService: hotspot ?? HotspotService(android: false),
  ));
  await tester.pumpAndSettle();
  return core;
}

/// Opens the helper as if on [platform] (the page's platform seam).
Future<void> _openHelper(WidgetTester tester, HotspotPlatform platform,
    {bool autoCheck = true}) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).push(
      MaterialPageRoute(
          builder: (_) => ConnectHelperPage(
              platform: platform,
              autoCheck: autoCheck,
              localAddresses: () async => ['192.168.1.10'])));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(f, 200,
        scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Finder _key(String k) => find.byKey(Key(k));

/// Scrolls until the widget with key [k] is built (lists build lazily).
Future<Finder> _show(WidgetTester tester, String k) async {
  final f = _key(k);
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(f, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
  }
  return f;
}

void main() {
  group('decision tree (unit)', () {
    test('recommended method first, per platform and other device', () {
      const a = HotspotPlatform.android, i = HotspotPlatform.ios;
      const m = HotspotPlatform.macos, w = HotspotPlatform.windows;
      expect(connectMethodsFor(a, OtherDeviceKind.android), [
        ConnectMethod.shareHotspot,
        ConnectMethod.joinByQr,
        ConnectMethod.wifiDirect,
      ]);
      expect(connectMethodsFor(a, OtherDeviceKind.iphone).first,
          ConnectMethod.shareHotspot);
      expect(connectMethodsFor(a, OtherDeviceKind.computer),
          [ConnectMethod.shareHotspot, ConnectMethod.cable]);
      expect(connectMethodsFor(i, OtherDeviceKind.android).first,
          ConnectMethod.joinHotspot);
      expect(connectMethodsFor(i, OtherDeviceKind.iphone).first,
          ConnectMethod.shareHotspot);
      expect(connectMethodsFor(m, OtherDeviceKind.android).first,
          ConnectMethod.joinHotspot);
      expect(connectMethodsFor(m, OtherDeviceKind.iphone).first,
          ConnectMethod.joinHotspot);
      expect(connectMethodsFor(w, OtherDeviceKind.computer).first,
          ConnectMethod.cable);
      for (final p in HotspotPlatform.values) {
        expect(connectMethodsFor(p, OtherDeviceKind.browser),
            [ConnectMethod.browser]);
        // Android-only methods only where this device is Android.
        if (p == a) continue;
        for (final o in OtherDeviceKind.values) {
          expect(connectMethodsFor(p, o),
              isNot(contains(ConnectMethod.joinByQr)), reason: '$p $o');
          expect(connectMethodsFor(p, o),
              isNot(contains(ConnectMethod.wifiDirect)), reason: '$p $o');
        }
      }
    });

    test('mainFinding: worst problem first, info-only codes never', () {
      const warn = Finding(Severity.warn, 'announce-blocked', 'W', 'w');
      const problem = Finding(Severity.problem, 'vpn-active', 'P', 'p');
      const network = Finding(Severity.info, 'network', 'N', 'n');
      const good = Finding(Severity.info, 'all-good', 'G', 'g');
      expect(mainFinding([network, warn, problem]), problem);
      expect(mainFinding([network, warn]), warn);
      expect(mainFinding([network, good]), good);
      expect(mainFinding([network]), isNull);
      expect(mainFinding(const []), isNull);
    });
  });

  group('helper page', () {
    testWidgets('automatic check: one plain result, details collapsed',
        (tester) async {
      final core = FakeCore(simulateDelay: const Duration(milliseconds: 10))
        ..scanFindsDevice = false
        ..diagnosisFindings = const [
          Finding(Severity.info, 'network', 'Your network', 'Addresses.',
              technical: 'en0: 192.168.1.10'),
          Finding(Severity.warn, 'announce-blocked',
              'Devices only show up after a scan', 'Router blocks it.',
              fix: 'Use "Rescan network".', action: hotspotWizardAction),
          Finding(Severity.problem, 'vpn-active', 'A VPN is on',
              'It can hide devices.',
              fix: 'Turn it off.', technical: 'utun3: 10.8.0.2'),
        ];
      await _pumpApp(tester, core: core);
      await _openHelper(tester, HotspotPlatform.macos);
      expect(core.diagnosisCalls, [(null, null)]);
      expect(_key('connectHelper'), findsOneWidget);
      // The worst finding is the one result, in plain words.
      expect(
          find.descendant(
              of: _key('helperResult'), matching: find.text('A VPN is on')),
          findsOneWidget);
      expect(find.text('What to do: Turn it off.'), findsOneWidget);
      // Technical text hidden under the finding's own "Details".
      expect(find.textContaining('utun3: 10.8.0.2'), findsNothing);
      await _tap(tester, 'findingDetails-vpn-active');
      expect(find.textContaining('utun3: 10.8.0.2'), findsOneWidget);
      // The rest is collapsed under the helper's "Details"; never the
      // network summary.
      expect(find.text('Devices only show up after a scan'), findsNothing);
      await _tap(tester, 'helperDetails');
      expect(find.text('Devices only show up after a scan'), findsOneWidget);
      expect(_key('finding-network'), findsNothing);
      // Then question 1.
      expect(_key('helperQ1'), findsOneWidget);
      expect(_key('helperFound'), findsNothing);
    });

    testWidgets('a device that appears during the check is announced',
        (tester) async {
      final core = await _pumpApp(tester);
      core.setPeers(const []);
      await tester.pumpAndSettle();
      await _openHelper(tester, HotspotPlatform.windows);
      expect(find.text('Found Living Room PC!'), findsOneWidget);
      await _tap(tester, 'helperBack');
      expect(_key('connectHelper'), findsNothing);
      expect(find.text('Living Room PC'), findsOneWidget);
    });

    testWidgets('nothing wrong: says so', (tester) async {
      final core = FakeCore(simulateDelay: const Duration(milliseconds: 10))
        ..diagnosisFindings = const [
          Finding(Severity.info, 'network', 'Your network', 'Addresses.'),
        ];
      await _pumpApp(tester, core: core);
      await _openHelper(tester, HotspotPlatform.linux);
      expect(_key('helperCheckFine'), findsOneWidget);
      expect(_key('helperResult'), findsNothing);
    });

    testWidgets('same Wi-Fi: checklist, search, then "connect directly"',
        (tester) async {
      final core = FakeCore(
          simulateDelay: const Duration(milliseconds: 10), initialPeers: [])
        ..scanFindsDevice = false;
      await _pumpApp(tester, core: core);
      await _openHelper(tester, HotspotPlatform.macos);
      await _tap(tester, 'q1-same');
      expect(_key('helperChecklist'), findsOneWidget);
      expect(find.textContaining('Turn off any VPN'), findsOneWidget);
      expect(_key('helperBlocked'), findsNothing);
      await _tap(tester, 'findDevice');
      expect(core.restartDiscoveryCalls, 1);
      expect(_key('nothingFound'), findsOneWidget);
      expect(find.textContaining('not a guest network'), findsOneWidget);
      expect(_key('helperBlocked'), findsOneWidget);
      await _tap(tester, 'helperConnectDirectly');
      expect(_key('helperQ2'), findsOneWidget);
    });

    testWidgets('same Wi-Fi: a found device ends with "Back to devices"',
        (tester) async {
      final core = FakeCore(
          simulateDelay: const Duration(milliseconds: 10), initialPeers: [])
        ..scanFindsDevice = false
        ..probeAnswers['192.168.1.1'] = const DeviceInfo(
            alias: 'Router PC', deviceType: 'desktop', fingerprint: 'rr11',
            ip: '192.168.1.1');
      await _pumpApp(tester, core: core);
      await _openHelper(tester, HotspotPlatform.windows, autoCheck: false);
      await _tap(tester, 'q1-same');
      await _tap(tester, 'findDevice');
      expect(_key('found-rr11'), findsOneWidget);
      expect(_key('helperBlocked'), findsNothing);
      await _tap(tester, 'wizardDone');
      expect(_key('connectHelper'), findsNothing);
    });

    testWidgets('cable answer: the cable steps with their own search',
        (tester) async {
      await _pumpApp(tester);
      await _openHelper(tester, HotspotPlatform.windows);
      await _tap(tester, 'q1-cable');
      expect(_key('helperMethod-cable'), findsOneWidget);
      expect(_key('kindEthernet'), findsOneWidget);
      expect(
          tester.widget<Text>(_key('cable-step-0')).data,
          cableSteps(HotspotPlatform.windows, CableKind.ethernet).first);
      expect(_key('findDevice'), findsOneWidget);
      // No other way is listed without the second question.
      expect(_key('helperRecommended'), findsNothing);
    });

    testWidgets('Android to Android: own hotspot, then QR join, Wi-Fi Direct',
        (tester) async {
      await _pumpApp(tester);
      await _openHelper(tester, HotspotPlatform.android);
      await _tap(tester, 'q1-different');
      await _tap(tester, 'q2-android');
      expect(_key('helperMethod-shareHotspot'), findsOneWidget);
      expect(_key('helperRecommended'), findsOneWidget);
      expect(find.text('Share a hotspot from this phone'), findsOneWidget);
      expect(tester.widget<Text>(_key('helper-step-0')).data,
          hotspotSteps(HotspotPlatform.android, HotspotRole.share).first);
      // The other phone joins: its steps are shown directly.
      expect(tester.widget<Text>(_key('helper-other-0')).data,
          hotspotSteps(HotspotPlatform.android, HotspotRole.join).first);
      expect(await _show(tester, 'findDevice'), findsOneWidget);
      expect(await _show(tester, 'alt-joinByQr'), findsOneWidget);
      expect(await _show(tester, 'alt-wifiDirect'), findsOneWidget);

      await _tap(tester, 'alt-joinByQr');
      expect(_key('helperMethod-joinByQr'), findsOneWidget);
      expect(_key('helperRecommended'), findsNothing);
      await _tap(tester, 'helperScanQr');
      expect(_key('wifiJoinPage'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await _tap(tester, 'alt-wifiDirect');
      expect(_key('helperMethod-wifiDirect'), findsOneWidget);
      await _tap(tester, 'helperWifiDirect');
      expect(_key('wifiDirectPage'), findsOneWidget);
    });

    testWidgets('Android hotspot card when the phone can start one',
        (tester) async {
      await _pumpApp(tester, hotspot: HotspotService(android: true));
      await _openHelper(tester, HotspotPlatform.android, autoCheck: false);
      await _tap(tester, 'q1-different');
      await _tap(tester, 'q2-computer');
      expect(_key('helperMethod-shareHotspot'), findsOneWidget);
      expect(_key('startHotspot'), findsOneWidget);
      // A computer joins: steps for every desktop system.
      expect(find.text('Mac'), findsOneWidget);
      expect(find.text('Windows'), findsOneWidget);
      expect(find.text('Linux'), findsOneWidget);
      expect(await _show(tester, 'alt-cable'), findsOneWidget);
    });

    testWidgets('iPhone helper: join the Android hotspot, no Android methods',
        (tester) async {
      await _pumpApp(tester);
      await _openHelper(tester, HotspotPlatform.ios);
      await _tap(tester, 'q1-different');
      await _tap(tester, 'q2-android');
      expect(_key('helperMethod-joinHotspot'), findsOneWidget);
      expect(tester.widget<Text>(_key('helper-other-0')).data,
          hotspotSteps(HotspotPlatform.android, HotspotRole.share).first);
      expect(tester.widget<Text>(_key('helper-step-0')).data,
          hotspotSteps(HotspotPlatform.ios, HotspotRole.join).first);
      expect(_key('helperScanQr'), findsNothing);
      expect(await _show(tester, 'alt-shareHotspot'), findsOneWidget);
      expect(_key('alt-joinByQr'), findsNothing);
      expect(_key('alt-wifiDirect'), findsNothing);
    });

    testWidgets('Mac and an iPhone: join its Personal Hotspot, or a cable',
        (tester) async {
      await _pumpApp(tester);
      await _openHelper(tester, HotspotPlatform.macos);
      await _tap(tester, 'q1-different');
      await _tap(tester, 'q2-iphone');
      expect(_key('helperMethod-joinHotspot'), findsOneWidget);
      expect(tester.widget<Text>(_key('helper-other-0')).data,
          contains('Personal Hotspot'));
      expect(tester.widget<Text>(_key('helper-step-0')).data,
          contains('menu bar'));
      await _tap(tester, 'alt-cable');
      expect(_key('helperMethod-cable'), findsOneWidget);
      // A phone on the other end: USB tethering is preselected.
      expect(tester.widget<Text>(_key('cable-step-0')).data,
          cableSteps(HotspotPlatform.macos, CableKind.usbTether).first);
    });

    testWidgets('two computers: cable recommended', (tester) async {
      await _pumpApp(tester);
      await _openHelper(tester, HotspotPlatform.linux);
      await _tap(tester, 'q1-different');
      await _tap(tester, 'q2-computer');
      expect(_key('helperMethod-cable'), findsOneWidget);
      expect(_key('helperRecommended'), findsOneWidget);
      expect(tester.widget<Text>(_key('cable-step-0')).data,
          cableSteps(HotspotPlatform.linux, CableKind.ethernet).first);
      expect(await _show(tester, 'alt-shareHotspot'), findsOneWidget);
      expect(await _show(tester, 'alt-joinHotspot'), findsOneWidget);
    });

    testWidgets('only a browser: the Share page', (tester) async {
      await _pumpApp(tester);
      await _openHelper(tester, HotspotPlatform.windows);
      await _tap(tester, 'q1-different');
      await _tap(tester, 'q2-browser');
      expect(_key('helperMethod-browser'), findsOneWidget);
      expect(_key('findDevice'), findsNothing);
      await _tap(tester, 'helperOpenShares');
      expect(_key('sendLinkSection'), findsOneWidget);
    });

    testWidgets('"Try another way" goes back to the first question',
        (tester) async {
      await _pumpApp(tester);
      await _openHelper(tester, HotspotPlatform.macos);
      expect(_key('helperTryAnother'), findsNothing);
      await _tap(tester, 'q1-different');
      await _tap(tester, 'q2-computer');
      expect(_key('helperMethod-cable'), findsOneWidget);
      await _tap(tester, 'helperTryAnother');
      expect(_key('helperQ1'), findsOneWidget);
      expect(_key('helperMethod-cable'), findsNothing);
      await _tap(tester, 'q1-same');
      await _tap(tester, 'helperTryAnother');
      expect(_key('helperQ1'), findsOneWidget);
    });

    testWidgets('copy connection report puts the English report on the '
        'clipboard', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      final core = await _pumpApp(tester);
      await _openHelper(tester, HotspotPlatform.windows);
      await _tap(tester, 'helperCopyReport');
      expect(copied, startsWith('LanDrop connection report'));
      expect(copied, contains('Devices only show up after a scan'));
      // The network summary is in the report even though it is hidden.
      expect(copied, contains('en0: 192.168.1.10'));
      expect(find.text('Report copied'), findsOneWidget);
      expect(core.diagnosisCalls, hasLength(1)); // reuses the check

      // Without a check, copying runs one first.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _openHelper(tester, HotspotPlatform.windows, autoCheck: false);
      copied = null;
      await _tap(tester, 'helperCopyReport');
      expect(core.diagnosisCalls, hasLength(2));
      expect(copied, startsWith('LanDrop connection report'));
    });

    testWidgets('a finding action routes inside the helper', (tester) async {
      await _pumpApp(tester);
      await _openHelper(tester, HotspotPlatform.macos);
      // The default check has "announce-blocked" with the hotspot action.
      await _tap(tester, 'findingAction-announce-blocked');
      expect(_key('connectHelper'), findsOneWidget);
      expect(_key('helperQ2'), findsOneWidget);
    });
  });

  group('entry points', () {
    testWidgets('empty list: whyNoDevices', (tester) async {
      final core = await _pumpApp(tester);
      core.setPeers(const []);
      await tester.pumpAndSettle();
      await _tap(tester, 'whyNoDevices');
      expect(_key('connectHelper'), findsOneWidget);
      expect(find.text('Help me connect'), findsOneWidget); // title
      expect(core.diagnosisCalls, [(null, null)]);
    });

    testWidgets('discovery banner: Help', (tester) async {
      final core = FakeCore(simulateDelay: const Duration(milliseconds: 10))
        ..discoveryError = 'Failed to create datagram socket';
      await _pumpApp(tester, core: core);
      await _tap(tester, 'discoveryHelp');
      expect(_key('connectHelper'), findsOneWidget);
    });

    testWidgets('device picker without devices: Help me connect',
        (tester) async {
      final core = await _pumpApp(tester);
      core.setPeers(const []);
      await tester.pumpAndSettle();
      await _tap(tester, 'sendFab');
      await _tap(tester, 'sendFiles');
      await _tap(tester, 'pickerHelp');
      expect(_key('connectHelper'), findsOneWidget);
    });

    testWidgets('Settings row and Settings ▸ Advanced', (tester) async {
      await _pumpApp(tester);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await _tap(tester, 'connectHelpSettings');
      expect(_key('connectHelper'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tap(tester, 'advancedSettings');
      await _tap(tester, 'helperAdvanced');
      expect(_key('connectHelper'), findsOneWidget);
      // The old wizards stay reachable from Advanced.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tap(tester, 'hotspotSettings');
      expect(_key('hotspotWizard'), findsOneWidget);
    });

    testWidgets('diagnosis dialog: hotspot and cable actions', (tester) async {
      final core = await _pumpApp(tester);
      Future<void> openDialog() async {
        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();
        await _tap(tester, 'advancedSettings');
        await _tap(tester, 'diagnoseSettings');
        expect(_key('diagnosisDialog'), findsOneWidget);
      }

      await openDialog();
      await _tap(tester, 'findingAction-announce-blocked');
      expect(_key('diagnosisDialog'), findsNothing);
      expect(_key('helperQ2'), findsOneWidget);
      // Opened from the dialog: no second check.
      expect(core.diagnosisCalls, hasLength(1));
      expect(_key('helperChecking'), findsNothing);
      // Back to home.
      for (var i = 0; i < 3; i++) {
        await tester.pageBack();
        await tester.pumpAndSettle();
      }

      core.diagnosisFindings = const [
        Finding(Severity.info, 'link-local-only', 'Direct cable or no DHCP',
            'This looks like a direct cable.',
            action: cableWizardAction),
      ];
      await openDialog();
      await _tap(tester, 'findingAction-link-local-only');
      expect(_key('helperMethod-cable'), findsOneWidget);
      expect(_key('kindUsb'), findsOneWidget);
    });
  });
}
