// Hotspot assist (DESIGN.md 3.5 hotspot): wizard, Wi-Fi QR payload, the
// Android hotspot service (permission choice, channel), diagnosis action.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/core/api.dart';
import 'package:landrop/core/util.dart';
import 'package:landrop/ui/app.dart';
import 'package:landrop/ui/app_controller.dart';
import 'package:landrop/ui/fake_core.dart';
import 'package:landrop/ui/hotspot_service.dart';
import 'package:landrop/ui/hotspot_wizard.dart';

const _channel = MethodChannel(HotspotService.channelName);

/// Answers the hotspot channel like MainActivity would; records calls.
List<String> _mockChannel(WidgetTester? tester,
    {int sdk = 34,
    Map<String, Object?>? creds,
    PlatformException? error}) {
  final calls = <String>[];
  final messenger = tester?.binding.defaultBinaryMessenger ??
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_channel, (call) async {
    calls.add(call.method);
    switch (call.method) {
      case 'sdkInt':
        return sdk;
      case 'start':
        if (error != null) throw error;
        return creds ??
            {'ssid': 'AndroidShare_42', 'password': 'pa;ss', 'gateway': null};
      case 'stop':
        return true;
    }
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(_channel, null));
  return calls;
}

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
    hotspotService: hotspot ?? HotspotService(android: false),
  ));
  await tester.pumpAndSettle();
  return core;
}

Future<void> _openWizard(WidgetTester tester, HotspotPlatform platform,
    {List<String> own = const ['192.168.1.10']}) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).push(
      MaterialPageRoute(
          builder: (_) => HotspotWizardPage(
              platform: platform, localAddresses: () async => own)));
  await tester.pumpAndSettle();
}

String _stepText(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

Future<void> _tapVisible(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Wi-Fi QR payload', () {
    test('plain', () {
      expect(wifiQrPayload('Home', 'secret123'),
          'WIFI:T:WPA;S:Home;P:secret123;;');
    });
    test(r'escapes \ ; , : " in name and password', () {
      expect(escapeWifiQr(r'a\b;c,d:e"f'), r'a\\b\;c\,d\:e\"f');
      expect(wifiQrPayload('My;Net', r'p:a"s\s,'),
          r'WIFI:T:WPA;S:My\;Net;P:p\:a\"s\\s\,;;');
      // Characters outside the set are untouched (also non-ASCII).
      expect(wifiQrPayload('Café 5G', 'x y'), 'WIFI:T:WPA;S:Café 5G;P:x y;;');
    });
    test('open network', () {
      expect(wifiQrPayload('Open', ''), 'WIFI:T:nopass;S:Open;;');
    });
  });

  test('likely hotspot addresses to probe', () {
    final t = hotspotProbeTargets(['172.20.10.5', '10.1.2.3']);
    expect(t, containsAll(['172.20.10.1', '10.1.2.1', '192.168.43.1',
        '192.168.2.1', '192.168.137.1']));
    expect(t.toSet().length, t.length, reason: 'no duplicates');
    // Our own address is never probed (we are the gateway).
    expect(hotspotProbeTargets(['192.168.43.1']), isNot(contains('192.168.43.1')));
  });

  group('hotspot service', () {
    test('permission: Nearby devices on API 33+, location before', () {
      expect(hotspotPermissionFor(26), HotspotPermission.location);
      expect(hotspotPermissionFor(32), HotspotPermission.location);
      expect(hotspotPermissionFor(33), HotspotPermission.nearbyWifiDevices);
      expect(hotspotPermissionFor(35), HotspotPermission.nearbyWifiDevices);
    });

    for (final (sdk, want) in [
      (30, HotspotPermission.location),
      (33, HotspotPermission.nearbyWifiDevices),
    ]) {
      test('API $sdk asks for $want, then starts', () async {
        final calls = _mockChannel(null, sdk: sdk);
        final asked = <HotspotPermission>[];
        final s = HotspotService(
            android: true,
            requestPermission: (p) async {
              asked.add(p);
              return true;
            });
        final h = await s.start();
        expect(asked, [want]);
        expect(calls, ['sdkInt', 'start']);
        expect(h.ssid, 'AndroidShare_42');
        expect(h.password, 'pa;ss');
        expect(h.gateway, isNull);
      });
    }

    test('permission denied: hotspot is not started', () async {
      final calls = _mockChannel(null, sdk: 33);
      final s = HotspotService(android: true, requestPermission: (_) async => false);
      await expectLater(
          s.start(),
          throwsA(isA<HotspotException>()
              .having((e) => e.code, 'code', 'permission')
              .having((e) => e.message, 'message', contains('Nearby devices'))));
      expect(calls, ['sdkInt']);
    });

    test('Android 7 and other platforms are unsupported', () async {
      final calls = _mockChannel(null, sdk: 25);
      await expectLater(
          HotspotService(android: true, requestPermission: (_) async => true)
              .start(),
          throwsA(isA<HotspotException>()
              .having((e) => e.code, 'code', 'unsupported')));
      expect(calls, ['sdkInt']);
      await expectLater(HotspotService(android: false).start(),
          throwsA(isA<HotspotException>()));
    });

    test('native error codes become plain messages', () async {
      _mockChannel(null,
          error: PlatformException(code: 'incompatible-mode', message: 'x'));
      await expectLater(
          HotspotService(android: true, requestPermission: (_) async => true)
              .start(),
          throwsA(isA<HotspotException>()
              .having((e) => e.code, 'code', 'incompatible-mode')
              .having((e) => e.message, 'message', contains('tethering'))));
    });
  });

  group('wizard steps per platform', () {
    test('share and join steps name the right settings', () {
      String share(HotspotPlatform p) =>
          hotspotSteps(p, HotspotRole.share).join(' ');
      String join(HotspotPlatform p) =>
          hotspotSteps(p, HotspotRole.join).join(' ');
      expect(share(HotspotPlatform.android), contains('Start hotspot'));
      expect(share(HotspotPlatform.android), contains('Hotspot & tethering'));
      expect(share(HotspotPlatform.ios), contains('Personal Hotspot'));
      expect(share(HotspotPlatform.macos),
          contains('General > Sharing'));
      expect(share(HotspotPlatform.macos), contains('Internet Sharing'));
      expect(share(HotspotPlatform.macos), contains('the other way round'));
      expect(share(HotspotPlatform.windows),
          contains('Network & internet > Mobile hotspot'));
      expect(share(HotspotPlatform.linux), contains('Hotspot'));
      expect(share(HotspotPlatform.linux), contains('nmcli'));
      expect(join(HotspotPlatform.ios), contains('Camera'));
      expect(join(HotspotPlatform.android), contains('QR'));
      expect(join(HotspotPlatform.macos), contains('menu bar'));
      expect(join(HotspotPlatform.windows), contains('taskbar'));
      expect(join(HotspotPlatform.linux), contains('Wi-Fi'));
    });
  });

  testWidgets('wizard shows steps for the platform and role', (tester) async {
    await _pumpApp(tester);
    await _openWizard(tester, HotspotPlatform.ios);
    expect(find.text('On this device (iPhone / iPad)'), findsOneWidget);
    expect(_stepText(tester, 'step-0'), contains('Camera'));
    await _tapVisible(tester, find.byKey(const Key('roleShare')));
    expect(_stepText(tester, 'step-0'), contains('Personal Hotspot'));
    // No in-app hotspot button off Android.
    expect(find.byKey(const Key('startHotspot')), findsNothing);
    // The other device's steps (joining) for every OS.
    await _tapVisible(tester, find.byKey(const Key('otherDevice')));
    expect(_stepText(tester, 'other-windows-0'), contains('taskbar'));
    expect(_stepText(tester, 'other-android-0'), contains('QR'));

    await tester.pageBack();
    await tester.pumpAndSettle();
    await _openWizard(tester, HotspotPlatform.windows);
    await _tapVisible(tester, find.byKey(const Key('roleShare')));
    expect(_stepText(tester, 'step-0'), contains('Mobile hotspot'));
  });

  testWidgets('find: restarts discovery, probes gateways, shows the device',
      (tester) async {
    final core = FakeCore(simulateDelay: const Duration(milliseconds: 10))
      ..scanFindsDevice = false
      ..probeAnswers['172.20.10.1'] = const DeviceInfo(
          alias: 'Anna’s iPhone',
          deviceType: 'mobile',
          fingerprint: 'ip01',
          ip: '172.20.10.1');
    await _pumpApp(tester, core: core);
    core.setPeers(const []);
    await tester.pumpAndSettle();
    await _openWizard(tester, HotspotPlatform.android, own: ['172.20.10.4']);
    await _tapVisible(tester, find.byKey(const Key('findDevice')));
    expect(core.restartDiscoveryCalls, 1);
    final probed = core.probeCalls.single;
    expect(probed, containsAll(['172.20.10.1', '192.168.43.1',
        '192.168.137.1', '192.168.2.1']));
    expect(probed, isNot(contains('172.20.10.4')));
    expect(find.byKey(const Key('found-ip01')), findsOneWidget);
    expect(find.text('Anna’s iPhone'), findsWidgets);
    expect(core.diagnosisCalls, isEmpty);
    await _tapVisible(tester, find.byKey(const Key('wizardDone')));
    expect(find.byKey(const Key('hotspotWizard')), findsNothing);
    expect(find.text('Anna’s iPhone'), findsOneWidget, reason: 'in the list');
  });

  testWidgets('find: nothing found runs the diagnosis again',
      (tester) async {
    final core = FakeCore(
        simulateDelay: const Duration(milliseconds: 10), initialPeers: [])
      ..scanFindsDevice = false;
    await _pumpApp(tester, core: core);
    await _openWizard(tester, HotspotPlatform.macos);
    await _tapVisible(tester, find.byKey(const Key('findDevice')));
    expect(core.restartDiscoveryCalls, 1);
    expect(core.probeCalls, hasLength(1));
    expect(find.byKey(const Key('nothingFound')), findsOneWidget);
    expect(core.diagnosisCalls, [(null, null)]);
    expect(find.byKey(const Key('finding-announce-blocked')), findsOneWidget);
    // Inside the wizard the findings have no "open the wizard" button.
    expect(find.byKey(const Key('findingAction-announce-blocked')),
        findsNothing);
  });

  testWidgets('diagnosis dialog: "Connect with a hotspot" opens the wizard',
      (tester) async {
    final core = await _pumpApp(tester);
    core.setPeers(const []);
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.byKey(const Key('whyNoDevices')));
    expect(find.byKey(const Key('diagnosisDialog')), findsOneWidget);
    final action = find.byKey(const Key('findingAction-announce-blocked'));
    expect(action, findsOneWidget);
    expect(find.text('Connect with a hotspot'), findsOneWidget);
    // The network summary has no action.
    expect(find.byKey(const Key('findingAction-network')), findsNothing);
    await _tapVisible(tester, action);
    expect(find.byKey(const Key('diagnosisDialog')), findsNothing);
    expect(find.byKey(const Key('hotspotWizard')), findsOneWidget);
  });

  testWidgets('wizard from the empty peer list and from Settings',
      (tester) async {
    final core = await _pumpApp(tester);
    core.setPeers(const []);
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.byKey(const Key('hotspotHelp')));
    expect(find.byKey(const Key('hotspotWizard')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.byKey(const Key('hotspotSettings')));
    expect(find.byKey(const Key('hotspotWizard')), findsOneWidget);
  });

  testWidgets('Android: start hotspot shows name, password, QR; stop',
      (tester) async {
    final calls = _mockChannel(tester,
        sdk: 33,
        creds: {
          'ssid': 'AndroidShare_7',
          'password': 'x;y',
          'gateway': '192.168.49.1'
        });
    final asked = <HotspotPermission>[];
    final core = await _pumpApp(tester,
        hotspot: HotspotService(
            android: true,
            requestPermission: (p) async {
              asked.add(p);
              return true;
            }));
    await _openWizard(tester, HotspotPlatform.android);
    await _tapVisible(tester, find.byKey(const Key('roleShare')));
    await _tapVisible(tester, find.byKey(const Key('startHotspot')));
    // The controller waits for the hotspot interface before rediscovering.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(asked, [HotspotPermission.nearbyWifiDevices]);
    expect(calls, ['sdkInt', 'start']);
    expect(find.text('Name: AndroidShare_7'), findsOneWidget);
    expect(find.text('Password: x;y'), findsOneWidget);
    expect(find.byKey(const Key('hotspotQr')), findsOneWidget);
    expect(core.hotspotInfo, ('AndroidShare_7', '192.168.49.1'));
    expect(core.restartDiscoveryCalls, 1);

    await _tapVisible(tester, find.byKey(const Key('stopHotspot')));
    expect(calls.last, 'stop');
    expect(core.hotspotInfo, (null, null));
    expect(core.restartDiscoveryCalls, 2);
    expect(find.byKey(const Key('startHotspot')), findsOneWidget);
  });

  testWidgets('Android: a refused permission is shown, nothing starts',
      (tester) async {
    final calls = _mockChannel(tester, sdk: 31);
    final core = await _pumpApp(tester,
        hotspot: HotspotService(
            android: true, requestPermission: (_) async => false));
    await _openWizard(tester, HotspotPlatform.android);
    await _tapVisible(tester, find.byKey(const Key('roleShare')));
    await _tapVisible(tester, find.byKey(const Key('startHotspot')));
    expect(calls, ['sdkInt']);
    expect(find.byKey(const Key('hotspotError')), findsOneWidget);
    expect(find.textContaining('location permission'), findsOneWidget);
    expect(core.hotspotInfo, (null, null));
  });
}
