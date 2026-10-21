// Wi-Fi Direct assist (DESIGN.md 3.5): service (channel, permission, events),
// page (peers, connect, connected -> discovery), Settings entry.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/core/api.dart';
import 'package:landrop/ui/app_controller.dart';
import 'package:landrop/ui/fake_core.dart';
import 'package:landrop/ui/hotspot_service.dart';
import 'package:landrop/ui/settings_page.dart';
import 'package:landrop/ui/widgets.dart';
import 'package:landrop/ui/wifi_direct_page.dart';
import 'package:landrop/ui/wifi_direct_service.dart';

const _channel = MethodChannel(WifiDirectService.channelName);

class _Calls {
  final List<String> methods = [];
  final List<Object?> args = [];
}

_Calls _mock({int sdk = 34, Object? supported = true, PlatformException? err}) {
  final calls = _Calls();
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  m.setMockMethodCallHandler(_channel, (call) async {
    calls.methods.add(call.method);
    calls.args.add(call.arguments);
    switch (call.method) {
      case 'sdkInt':
        return sdk;
      case 'supported':
        return supported;
      case 'info':
        return {'type': 'state', 'connected': true, 'isOwner': false,
          'ownerAddress': '192.168.49.1', 'ssid': 'DIRECT-ab'};
      default:
        if (err != null) throw err;
        return true;
    }
  });
  addTearDown(() => m.setMockMethodCallHandler(_channel, null));
  return calls;
}

class _FakeService implements WifiDirectApi {
  final peersC = StreamController<List<WifiDirectPeer>>.broadcast();
  final statesC = StreamController<WifiDirectState>.broadcast();
  final errorsC = StreamController<WifiDirectException>.broadcast();
  final calls = <String>[];
  WifiDirectException? availableError;
  @override
  bool get supported => true;
  @override
  Stream<List<WifiDirectPeer>> get peers => peersC.stream;
  @override
  Stream<WifiDirectState> get states => statesC.stream;
  @override
  Stream<WifiDirectException> get errors => errorsC.stream;
  @override
  Future<void> checkAvailable() async {
    calls.add('check');
    if (availableError != null) throw availableError!;
  }

  @override
  Future<void> discover() async => calls.add('discover');
  @override
  Future<void> stopDiscover() async => calls.add('stopDiscover');
  @override
  Future<void> connect(String address, {int? groupOwnerIntent}) async =>
      calls.add('connect:$address');
  @override
  Future<void> createGroup() async => calls.add('createGroup');
  @override
  Future<void> disconnect() async => calls.add('disconnect');
  @override
  Future<WifiDirectState> info() async => WifiDirectState.disconnected;
  @override
  void dispose() {}
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
      home: AppScope(controller: c, child: WifiDirectPage(service: svc))));
  await tester.pumpAndSettle();
  return core;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('service', () {
    test('permission: nearby devices on 33+, location before', () async {
      for (final (sdk, want) in [
        (34, HotspotPermission.nearbyWifiDevices),
        (33, HotspotPermission.nearbyWifiDevices),
        (32, HotspotPermission.location),
        (26, HotspotPermission.location),
      ]) {
        _mock(sdk: sdk);
        final asked = <HotspotPermission>[];
        final s = WifiDirectService(
            android: true,
            events: const Stream.empty(),
            requestPermission: (p) async {
              asked.add(p);
              return true;
            });
        await s.discover();
        expect(asked, [want], reason: 'sdk $sdk');
        s.dispose();
      }
    });

    test('denied permission throws and does not call native', () async {
      final calls = _mock();
      final s = WifiDirectService(
          android: true,
          events: const Stream.empty(),
          requestPermission: (_) async => false);
      await expectLater(
          s.discover(),
          throwsA(isA<WifiDirectException>()
              .having((e) => e.code, 'code', 'permission')));
      expect(calls.methods, ['sdkInt']);
      s.dispose();
    });

    test('method calls and arguments', () async {
      final calls = _mock();
      final s = WifiDirectService(
          android: true,
          events: const Stream.empty(),
          requestPermission: (_) async => true);
      await s.checkAvailable();
      await s.discover();
      await s.connect('aa:bb', groupOwnerIntent: 3);
      await s.createGroup();
      await s.stopDiscover();
      final st = await s.info();
      await s.disconnect();
      expect(calls.methods, [
        'supported', 'sdkInt', 'discover', 'sdkInt', 'connect', 'sdkInt',
        'createGroup', 'stopDiscover', 'info', 'disconnect'
      ]);
      expect(calls.args[4], {'address': 'aa:bb', 'groupOwnerIntent': 3});
      expect(st.connected, isTrue);
      expect(st.ownerAddress, '192.168.49.1');
      expect(st.ssid, 'DIRECT-ab');
      s.dispose();
    });

    test('availability: wifi off and missing feature', () async {
      _mock(supported: {'feature': true, 'wifiEnabled': false});
      final s = WifiDirectService(android: true, events: const Stream.empty());
      await expectLater(s.checkAvailable(),
          throwsA(isA<WifiDirectException>().having((e) => e.code, 'c', 'wifi-off')));
      _mock(supported: false);
      await expectLater(s.checkAvailable(),
          throwsA(isA<WifiDirectException>().having((e) => e.code, 'c', 'unsupported')));
      s.dispose();
    });

    test('platform errors become readable exceptions', () async {
      _mock(err: PlatformException(code: 'busy', message: 'x'));
      final s = WifiDirectService(
          android: true,
          events: const Stream.empty(),
          requestPermission: (_) async => true);
      await expectLater(
          s.createGroup(),
          throwsA(isA<WifiDirectException>()
              .having((e) => e.message, 'message', contains('busy'))));
      s.dispose();
    });

    test('not Android: unsupported, no channel use', () async {
      final calls = _mock();
      final s = WifiDirectService(android: false);
      expect(s.supported, isFalse);
      await expectLater(s.discover(), throwsA(isA<WifiDirectException>()));
      await s.disconnect();
      expect(calls.methods, isEmpty);
    });

    test('events: peers, state, errors', () async {
      _mock();
      final ev = StreamController<dynamic>();
      final s = WifiDirectService(android: true, events: ev.stream);
      final peers = <List<WifiDirectPeer>>[];
      final states = <WifiDirectState>[];
      final errors = <WifiDirectException>[];
      s.peers.listen(peers.add);
      s.states.listen(states.add);
      s.errors.listen(errors.add);
      ev.add({
        'type': 'peers',
        'peers': [
          {'name': 'Pixel', 'address': 'aa:01', 'status': 'available'},
          {'name': '', 'address': 'aa:02', 'status': 'invited'},
          {'name': 'bad'},
        ]
      });
      ev.add({
        'type': 'state', 'connected': true, 'isOwner': true,
        'ownerAddress': '192.168.49.1', 'ssid': 'DIRECT-x'
      });
      ev.add({'type': 'error', 'code': 'busy', 'message': 'Wi-Fi Direct is busy'});
      ev.add({'type': 'error', 'code': 'error', 'message': 'boom'});
      ev.add('garbage');
      await Future<void>.delayed(Duration.zero);
      expect(peers.single, [
        const WifiDirectPeer('Pixel', 'aa:01', 'available'),
        const WifiDirectPeer('aa:02', 'aa:02', 'invited'),
      ]);
      expect(states.single.connected, isTrue);
      expect(states.single.isOwner, isTrue);
      expect(states.single.ownerAddress, '192.168.49.1');
      expect(states.single.ssid, 'DIRECT-x');
      expect(errors.map((e) => e.code), ['busy', 'error']);
      expect(errors.first.message, contains('busy'));
      expect(errors.last.message, contains('boom'));
      s.dispose();
      await ev.close();
    });
  });

  group('page', () {
    testWidgets('lists peers and connects on tap', (tester) async {
      final svc = _FakeService();
      await _pumpPage(tester, svc);
      expect(svc.calls, ['check', 'discover']);
      expect(find.byKey(const Key('wifiDirectEmpty')), findsOneWidget);
      svc.peersC.add(const [
        WifiDirectPeer('Pixel 9', 'aa:01', 'available'),
        WifiDirectPeer('Galaxy', 'aa:02', 'invited'),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Pixel 9'), findsOneWidget);
      expect(find.textContaining('invitation dialog'), findsOneWidget);
      expect(find.textContaining('Accept it on the other device'), findsOneWidget);
      await tester.tap(find.byKey(const Key('wifiDirectPeer_aa:01')));
      await tester.pumpAndSettle();
      expect(svc.calls, contains('connect:aa:01'));
      await tester.tap(find.byKey(const Key('wifiDirectCreateGroup')));
      await tester.pumpAndSettle();
      expect(svc.calls, contains('createGroup'));
    });

    testWidgets('connected: restarts discovery, probes owner, lists devices',
        (tester) async {
      final svc = _FakeService();
      final core = await _pumpPage(tester, svc);
      core.probeAnswers['192.168.49.1'] = const DeviceInfo(
          alias: 'Direct Phone',
          deviceType: 'mobile',
          fingerprint: 'dd44',
          ip: '192.168.49.1');
      final before = core.restartDiscoveryCalls;
      svc.statesC.add(const WifiDirectState(
          connected: true, ownerAddress: '192.168.49.7', ssid: 'DIRECT-q'));
      await tester.pumpAndSettle();
      expect(find.text('Connected via Wi-Fi Direct'), findsOneWidget);
      expect(core.restartDiscoveryCalls, before + 1);
      expect(core.probeCalls.last, ['192.168.49.1', '192.168.49.7']);
      expect(find.text('Direct Phone'), findsOneWidget);
      await tester.tap(find.byKey(const Key('wifiDirectDisconnect')));
      await tester.pumpAndSettle();
      expect(svc.calls, contains('disconnect'));
      expect(find.text('Connected via Wi-Fi Direct'), findsNothing);
    });

    testWidgets('errors are shown with what to try', (tester) async {
      final svc = _FakeService()
        ..availableError =
            WifiDirectException('wifi-off', wifiDirectMessage('wifi-off'));
      await _pumpPage(tester, svc);
      expect(find.byKey(const Key('wifiDirectError')), findsOneWidget);
      expect(find.textContaining('Wi-Fi is off'), findsOneWidget);
      expect(find.textContaining('accept the invitation'), findsOneWidget);
      svc.errorsC.add(WifiDirectException('busy', wifiDirectMessage('busy')));
      await tester.pumpAndSettle();
      expect(find.textContaining('busy'), findsOneWidget);
    });
  });

  group('settings entry', () {
    Future<void> pump(WidgetTester tester, bool android) async {
      tester.view.physicalSize = const Size(420, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = AppController(
          core: FakeCore(simulateDelay: const Duration(milliseconds: 10)),
          store: MemorySettingsStore(),
          initialSaveDir: '/tmp/landrop-test',
          initialAlias: 'Tester');
      await c.init();
      await tester.pumpWidget(MaterialApp(
          home: AppScope(
              controller: c, child: SettingsPage(isAndroid: android))));
      await tester.pumpAndSettle();
    }

    testWidgets('shown on Android', (tester) async {
      await pump(tester, true);
      expect(find.byKey(const Key('wifiDirectSettings')), findsOneWidget);
      expect(find.text('Connect with Wi-Fi Direct'), findsOneWidget);
    });

    testWidgets('hidden elsewhere', (tester) async {
      await pump(tester, false);
      expect(find.byKey(const Key('wifiDirectSettings')), findsNothing);
    });
  });
}
