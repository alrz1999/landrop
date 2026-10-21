// Join a hotspot by QR (DESIGN.md 3.5): service (channel, camera, events),
// page (scan -> confirm -> join -> find device), entry points.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/ui/app_controller.dart';
import 'package:landrop/ui/fake_core.dart';
import 'package:landrop/ui/hotspot_wizard.dart';
import 'package:landrop/ui/settings_page.dart';
import 'package:landrop/ui/widgets.dart';
import 'package:landrop/ui/wifi_join_page.dart';
import 'package:landrop/ui/wifi_join_service.dart';
import 'package:landrop/ui/wifi_qr.dart';

const _channel = MethodChannel(WifiJoinService.channelName);

class _Calls {
  final List<String> methods = [];
  final List<Object?> args = [];
}

_Calls _mock({int sdk = 34, PlatformException? err}) {
  final calls = _Calls();
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  m.setMockMethodCallHandler(_channel, (call) async {
    calls.methods.add(call.method);
    calls.args.add(call.arguments);
    if (call.method == 'sdkInt') return sdk;
    if (err != null) throw err;
    return true;
  });
  addTearDown(() => m.setMockMethodCallHandler(_channel, null));
  return calls;
}

const _creds = WifiCredentials('AndroidShare_42', 'pa;ss1234');

class _FakeService implements WifiJoinApi {
  final lostC = StreamController<WifiJoinException>.broadcast();
  final calls = <String>[];
  bool camera = true;
  WifiJoinException? joinError;
  Completer<void>? gate;
  WifiJoinResult result =
      const WifiJoinResult('AndroidShare_42', gateway: '192.168.43.1');
  WifiCredentials? joinedWith;
  @override
  bool get supported => true;
  @override
  Stream<WifiJoinException> get lost => lostC.stream;
  @override
  Future<bool> requestCamera() async {
    calls.add('camera');
    return camera;
  }

  @override
  Future<WifiJoinResult> join(WifiCredentials c) async {
    calls.add('join');
    joinedWith = c;
    await gate?.future;
    if (joinError != null) throw joinError!;
    return result;
  }

  @override
  Future<void> leave() async => calls.add('leave');
  @override
  void dispose() {}
}

void Function(String)? _onCode;

Widget _fakeScanner(BuildContext _, void Function(String) onCode) {
  _onCode = onCode;
  return const SizedBox(key: Key('fakeScanner'));
}

Future<FakeCore> _pumpPage(WidgetTester tester, _FakeService svc) async {
  tester.view.physicalSize = const Size(420, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final core = FakeCore(simulateDelay: const Duration(milliseconds: 10));
  final c = AppController(
      core: core,
      store: MemorySettingsStore(),
      initialSaveDir: '/tmp/landrop-test',
      initialAlias: 'Tester');
  await c.init();
  await tester.pumpWidget(MaterialApp(
      home: AppScope(
          controller: c,
          child: WifiJoinPage(
              service: svc,
              scannerBuilder: _fakeScanner,
              localAddresses: () async => ['192.168.43.20']))));
  await tester.pumpAndSettle();
  return core;
}

Future<void> _scanAndJoin(WidgetTester tester) async {
  _onCode!('WIFI:T:WPA;S:AndroidShare_42;P:pa\\;ss1234;;');
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('joinButton')));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('service', () {
    test('join sends arguments and completes on the connected event',
        () async {
      final calls = _mock();
      final ev = StreamController<dynamic>();
      final s = WifiJoinService(
          android: true, events: ev.stream, requestCameraPermission: () async => true);
      final f = s.join(const WifiCredentials('Net', 'secret123',
          security: WifiSecurity.wpa3, hidden: true));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      ev.add({
        'type': 'connected',
        'ssid': 'Net',
        'gateway': '192.168.43.1',
        'addresses': ['192.168.43.20'],
      });
      final r = await f;
      expect(r.ssid, 'Net');
      expect(r.gateway, '192.168.43.1');
      expect(r.addresses, ['192.168.43.20']);
      expect(calls.methods, ['sdkInt', 'join']);
      expect(calls.args[1], {
        'ssid': 'Net',
        'password': 'secret123',
        'security': 'wpa3',
        'hidden': true,
      });
      s.dispose();
      await ev.close();
    });

    test('failed event throws a readable exception', () async {
      _mock();
      final ev = StreamController<dynamic>();
      final s = WifiJoinService(android: true, events: ev.stream);
      final f = s.join(_creds);
      final expectation = expectLater(
          f,
          throwsA(isA<WifiJoinException>()
              .having((e) => e.code, 'code', 'timeout')
              .having((e) => e.message, 'message', contains('password'))));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      ev.add({'type': 'failed', 'code': 'timeout', 'message': 'x'});
      await expectation;
      s.dispose();
      await ev.close();
    });

    test('lost event: before connect fails the join, after it is reported',
        () async {
      _mock();
      final ev = StreamController<dynamic>();
      final s = WifiJoinService(android: true, events: ev.stream);
      final lost = <String>[];
      s.lost.listen((e) => lost.add(e.code));
      final f = s.join(_creds);
      final expectation = expectLater(f, throwsA(isA<WifiJoinException>()));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      ev.add({'type': 'lost'});
      await expectation;
      expect(lost, isEmpty);
      ev.add({'type': 'lost'});
      await Future<void>.delayed(Duration.zero);
      expect(lost, ['lost']);
      s.dispose();
      await ev.close();
    });

    test('platform error and old Android', () async {
      _mock(err: PlatformException(code: 'unsupported-security', message: 'x'));
      final s = WifiJoinService(android: true, events: const Stream.empty());
      await expectLater(
          s.join(_creds),
          throwsA(isA<WifiJoinException>()
              .having((e) => e.code, 'code', 'unsupported-security')));
      _mock(sdk: 23);
      await expectLater(
          s.join(_creds),
          throwsA(isA<WifiJoinException>()
              .having((e) => e.code, 'code', 'unsupported')));
      s.dispose();
    });

    test('join times out without an event', () async {
      _mock();
      final s = WifiJoinService(
          android: true,
          events: const Stream.empty(),
          timeout: const Duration(milliseconds: 20));
      await expectLater(
          s.join(_creds),
          throwsA(isA<WifiJoinException>()
              .having((e) => e.code, 'code', 'timeout')));
      s.dispose();
    });

    test('camera permission and leave', () async {
      final calls = _mock();
      var asked = 0;
      final s = WifiJoinService(
          android: true,
          events: const Stream.empty(),
          requestCameraPermission: () async {
            asked++;
            return false;
          });
      expect(await s.requestCamera(), isFalse);
      expect(asked, 1);
      await s.leave();
      expect(calls.methods, ['leave']);
      s.dispose();
    });

    test('not Android: unsupported, no channel use, no camera', () async {
      final calls = _mock();
      var asked = 0;
      final s = WifiJoinService(
          android: false,
          requestCameraPermission: () async {
            asked++;
            return true;
          });
      expect(s.supported, isFalse);
      expect(await s.requestCamera(), isFalse);
      await expectLater(s.join(_creds), throwsA(isA<WifiJoinException>()));
      await s.leave();
      expect(calls.methods, isEmpty);
      expect(asked, 0);
    });
  });

  group('page', () {
    testWidgets('scan -> confirm -> join -> find device', (tester) async {
      final svc = _FakeService();
      final core = await _pumpPage(tester, svc);
      expect(find.byKey(const Key('fakeScanner')), findsOneWidget);
      _onCode!('WIFI:T:WPA;S:AndroidShare_42;P:pa\\;ss1234;;');
      await tester.pumpAndSettle();
      expect(find.text('Join AndroidShare_42?'), findsOneWidget);
      expect(find.textContaining('Android will ask you to confirm'),
          findsOneWidget);
      expect(find.textContaining('lose its internet'), findsOneWidget);
      expect(svc.calls, isNot(contains('join')));
      await tester.tap(find.byKey(const Key('joinButton')));
      await tester.pumpAndSettle();
      expect(svc.joinedWith, _creds);
      expect(find.byKey(const Key('joinedTitle')), findsOneWidget);
      expect(core.restartDiscoveryCalls, 1);
      expect(core.probeCalls, isNotEmpty);
      expect(core.probeCalls.last, contains('192.168.43.1'));
      await tester.tap(find.byKey(const Key('leaveNetwork')));
      await tester.pumpAndSettle();
      expect(svc.calls, contains('leave'));
      expect(find.byKey(const Key('fakeScanner')), findsOneWidget);
    });

    testWidgets('progress while joining', (tester) async {
      final svc = _FakeService()..gate = Completer<void>();
      await _pumpPage(tester, svc);
      _onCode!('WIFI:S:AndroidShare_42;P:pa\\;ss1234;;');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('joinButton')));
      await tester.pump();
      expect(find.byKey(const Key('joining')), findsOneWidget);
      svc.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('joinedTitle')), findsOneWidget);
    });

    testWidgets('not a Wi-Fi code shows a hint and keeps scanning',
        (tester) async {
      await _pumpPage(tester, _FakeService());
      _onCode!('https://example.com');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('scanHint')), findsOneWidget);
      expect(find.byKey(const Key('joinConfirmTitle')), findsNothing);
    });

    testWidgets('cancel returns to the scanner', (tester) async {
      await _pumpPage(tester, _FakeService());
      _onCode!('WIFI:S:Net;P:abcdefgh;;');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cancelJoin')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fakeScanner')), findsOneWidget);
    });

    testWidgets('join failure shows the error and can retry', (tester) async {
      final svc = _FakeService()
        ..joinError = WifiJoinException('timeout', wifiJoinMessage('timeout'));
      final core = await _pumpPage(tester, svc);
      await _scanAndJoin(tester);
      expect(find.byKey(const Key('joinError')), findsOneWidget);
      expect(find.textContaining('decline'), findsOneWidget);
      expect(core.restartDiscoveryCalls, 0);
      svc.joinError = null;
      await tester.tap(find.byKey(const Key('joinRetry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('joinedTitle')), findsOneWidget);
      expect(core.restartDiscoveryCalls, 1);
    });

    testWidgets('camera denied: message, retry, manual form still works',
        (tester) async {
      final svc = _FakeService()..camera = false;
      await _pumpPage(tester, svc);
      expect(find.byKey(const Key('cameraDenied')), findsOneWidget);
      expect(find.byKey(const Key('fakeScanner')), findsNothing);
      svc.camera = true;
      await tester.tap(find.byKey(const Key('retryCamera')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fakeScanner')), findsOneWidget);
    });

    testWidgets('manual form: name and password -> confirm -> join',
        (tester) async {
      final svc = _FakeService();
      await _pumpPage(tester, svc);
      await tester.tap(find.byKey(const Key('manualToggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('manualContinue')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('scanHint')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('manualSsid')), 'My;Net');
      await tester.enterText(find.byKey(const Key('manualPassword')), 'abc:defgh');
      await tester.tap(find.byKey(const Key('manualContinue')));
      await tester.pumpAndSettle();
      expect(find.text('Join My;Net?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('joinButton')));
      await tester.pumpAndSettle();
      expect(svc.joinedWith, const WifiCredentials('My;Net', 'abc:defgh'));
    });

    testWidgets('network lost after joining shows a notice', (tester) async {
      final svc = _FakeService();
      await _pumpPage(tester, svc);
      await _scanAndJoin(tester);
      svc.lostC.add(WifiJoinException('lost', wifiJoinMessage('lost')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('joinLost')), findsOneWidget);
    });
  });

  group('entry points', () {
    Future<void> pumpWizard(WidgetTester tester, HotspotPlatform p) async {
      tester.view.physicalSize = const Size(420, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = AppController(
          core: FakeCore(),
          store: MemorySettingsStore(),
          initialSaveDir: '/tmp/landrop-test',
          initialAlias: 'Tester');
      await c.init();
      await tester.pumpWidget(MaterialApp(
          home: AppScope(
              controller: c, child: HotspotWizardPage(platform: p))));
      await tester.pumpAndSettle();
    }

    testWidgets('wizard: Android join branch only', (tester) async {
      await pumpWizard(tester, HotspotPlatform.android);
      expect(find.byKey(const Key('scanHotspotQr')), findsOneWidget);
      expect(find.text('Scan the hotspot QR code'), findsOneWidget);
      await tester.tap(find.byKey(const Key('roleShare')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('scanHotspotQr')), findsNothing);
    });

    testWidgets('wizard: not on other platforms', (tester) async {
      for (final p in [
        HotspotPlatform.ios,
        HotspotPlatform.macos,
        HotspotPlatform.windows,
        HotspotPlatform.linux,
      ]) {
        await pumpWizard(tester, p);
        expect(find.byKey(const Key('scanHotspotQr')), findsNothing,
            reason: p.name);
      }
    });

    for (final android in [true, false]) {
      testWidgets('settings entry visible=$android', (tester) async {
        tester.view.physicalSize = const Size(420, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final c = AppController(
            core: FakeCore(),
            store: MemorySettingsStore(),
            initialSaveDir: '/tmp/landrop-test',
            initialAlias: 'Tester');
        await c.init();
        await tester.pumpWidget(MaterialApp(
            home: AppScope(
                controller: c,
                child: AdvancedSettingsPage(isAndroid: android))));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('wifiJoinSettings'), skipOffstage: false),
            android ? findsOneWidget : findsNothing);
      });
    }
  });
}
