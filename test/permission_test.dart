// Just-in-time permission explanations (docs/UX.md 3.6): notifications on
// the first background use, "Nearby devices" before the hotspot and
// Wi-Fi Direct, the camera before Join by QR.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/l10n/app_localizations.dart';
import 'package:landrop/ui/app.dart';
import 'package:landrop/ui/app_controller.dart';
import 'package:landrop/ui/fake_core.dart';
import 'package:landrop/ui/hotspot_service.dart';
import 'package:landrop/ui/hotspot_wizard.dart' show HotspotCard;
import 'package:landrop/ui/widgets.dart' show AppScope;
import 'package:landrop/ui/wifi_direct_page.dart';
import 'package:landrop/ui/wifi_direct_service.dart';
import 'package:landrop/ui/wifi_join_page.dart';
import 'package:landrop/ui/wifi_join_service.dart';
import 'package:landrop/ui/wifi_qr.dart' show WifiCredentials;

final en = lookupAppLocalizations(const Locale('en'));
final fa = lookupAppLocalizations(const Locale('fa'));

/// Android without system dialogs: [grantOnRequest] is the user's answer.
class FakePermissions extends PermissionAccess {
  FakePermissions({Set<AppPermission>? granted, this.grantOnRequest = true})
      : grantedNow = {...?granted};
  final Set<AppPermission> grantedNow;
  bool grantOnRequest;
  final List<AppPermission> requests = [];

  @override
  bool get isAndroid => true;
  @override
  Future<bool> granted(AppPermission p) async => grantedNow.contains(p);
  @override
  Future<bool> request(AppPermission p) async {
    requests.add(p);
    if (grantOnRequest) grantedNow.add(p);
    return grantOnRequest;
  }
}

Future<MemorySettingsStore> _pumpApp(WidgetTester t, FakePermissions perms,
    {MemorySettingsStore? store,
    String locale = 'en',
    double width = 400}) async {
  t.view.physicalSize = Size(width, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  store ??= MemorySettingsStore({'locale': locale});
  await t.pumpWidget(LanDropApp(
    core: FakeCore(simulateDelay: const Duration(milliseconds: 10)),
    store: store,
    initialSaveDir: '/tmp/landrop-test',
    initialAlias: 'Tester',
    pickFiles: () async => <String>[],
    pickFolder: () async => null,
    permissionAccess: perms,
  ));
  await t.pumpAndSettle();
  return store;
}

Future<AppController> _controller(FakePermissions perms,
    {HotspotService? hotspot}) async {
  final c = AppController(
      core: FakeCore(simulateDelay: const Duration(milliseconds: 10)),
      store: MemorySettingsStore({'background': false}),
      initialSaveDir: '/tmp/landrop-test',
      initialAlias: 'Tester',
      hotspotService: hotspot,
      permissionAccess: perms,
      hotspotSettleDelay: Duration.zero);
  await c.init();
  return c;
}

Future<void> _pumpIn(WidgetTester t, AppController c, Widget child,
    {Locale locale = const Locale('en'), double width = 420}) async {
  t.view.physicalSize = Size(width, 1200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AppScope(controller: c, child: child)));
  await t.pumpAndSettle();
}

class _Direct implements WifiDirectApi {
  final calls = <String>[];
  @override
  bool get supported => true;
  @override
  Stream<List<WifiDirectPeer>> get peers => const Stream.empty();
  @override
  Stream<WifiDirectState> get states => const Stream.empty();
  @override
  Stream<WifiDirectException> get errors => const Stream.empty();
  @override
  Future<void> checkAvailable() async {}
  @override
  Future<void> discover() async => calls.add('discover');
  @override
  Future<void> stopDiscover() async {}
  @override
  Future<void> connect(String address, {int? groupOwnerIntent}) async {}
  @override
  Future<void> createGroup() async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<WifiDirectState> info() async => WifiDirectState.disconnected;
  @override
  void dispose() {}
}

class _Join implements WifiJoinApi {
  int cameraRequests = 0;
  @override
  bool get supported => true;
  @override
  Stream<WifiJoinException> get lost => const Stream.empty();
  @override
  Future<bool> requestCamera() async {
    cameraRequests++;
    return true;
  }

  @override
  Future<WifiJoinResult> join(WifiCredentials c) async =>
      WifiJoinResult(c.ssid);
  @override
  Future<void> leave() async {}
  @override
  void dispose() {}
}

const _hotspotChannel = MethodChannel(HotspotService.channelName);

void main() {
  group('notifications', () {
    testWidgets('explained on the first background use; Not now is '
        'remembered and Settings offers a retry', (t) async {
      final perms = FakePermissions();
      final store = await _pumpApp(t, perms);
      expect(find.byKey(const Key('permissionSheet-notifications')),
          findsOneWidget);
      expect(find.text(en.permNotificationsTitle), findsOneWidget);
      await t.tap(find.byKey(const Key('permissionNotNow')));
      await t.pumpAndSettle();
      expect(perms.requests, isEmpty);
      expect(find.byKey(const Key('notificationsOffSnack')), findsOneWidget);
      expect(store.stored['permissionsExplained'], contains('notifications'));

      // Next start: not asked again.
      await t.pumpWidget(const SizedBox());
      await _pumpApp(t, perms, store: store);
      expect(find.byKey(const Key('permissionSheet-notifications')),
          findsNothing);

      // Settings: "Allow notifications" opens Android's dialog.
      await t.tap(find.byIcon(Icons.settings_outlined));
      await t.pumpAndSettle();
      final allow = find.byKey(const Key('allowNotifications'));
      await t.scrollUntilVisible(allow, 200,
          scrollable: find.byType(Scrollable).first);
      await t.tap(find.descendant(of: allow, matching: find.byType(TextButton)));
      await t.pumpAndSettle();
      expect(perms.requests, [AppPermission.notifications]);
      expect(find.byKey(const Key('allowNotifications')), findsNothing);
    });

    testWidgets('Continue asks Android once', (t) async {
      final perms = FakePermissions();
      await _pumpApp(t, perms);
      await t.tap(find.byKey(const Key('permissionContinue')));
      await t.pumpAndSettle();
      expect(perms.requests, [AppPermission.notifications]);
      expect(find.byKey(const Key('notificationsOffSnack')), findsNothing);
    });

    testWidgets('not shown when granted already or background is off',
        (t) async {
      await _pumpApp(t,
          FakePermissions(granted: {AppPermission.notifications}));
      expect(find.byKey(const Key('permissionSheet-notifications')),
          findsNothing);
      await t.pumpWidget(const SizedBox());
      await _pumpApp(t, FakePermissions(),
          store: MemorySettingsStore({'locale': 'en', 'background': false}));
      expect(find.byKey(const Key('permissionSheet-notifications')),
          findsNothing);
    });
  });

  group('nearby devices', () {
    testWidgets('hotspot: Not now leaves it off; Try again asks Android',
        (t) async {
      final calls = <String>[];
      final messenger = t.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(_hotspotChannel, (call) async {
        calls.add(call.method);
        return switch (call.method) {
          'sdkInt' => 34,
          'start' => {'ssid': 'AndroidShare_1', 'password': 'pw12345678'},
          _ => true,
        };
      });
      addTearDown(
          () => messenger.setMockMethodCallHandler(_hotspotChannel, null));
      final asked = <HotspotPermission>[];
      final perms = FakePermissions();
      final c = await _controller(perms,
          hotspot: HotspotService(
              android: true,
              requestPermission: (p) async {
                asked.add(p);
                return true;
              }));
      await _pumpIn(t, c, const Scaffold(body: HotspotCard()));

      await t.tap(find.byKey(const Key('startHotspot')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('permissionSheet-nearbyDevices')),
          findsOneWidget);
      await t.tap(find.byKey(const Key('permissionNotNow')));
      await t.pumpAndSettle();
      expect(asked, isEmpty);
      expect(calls, isEmpty);
      expect(find.byKey(const Key('permissionNotNow-nearbyDevices')),
          findsOneWidget);
      expect(find.text(en.permNearbyOff), findsOneWidget);

      await t.tap(find.byKey(const Key('permissionRetry-nearbyDevices')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('permissionSheet-nearbyDevices')),
          findsNothing, reason: 'explained once');
      expect(asked, [HotspotPermission.nearbyWifiDevices]);
      expect(c.hotspot?.ssid, 'AndroidShare_1');
      c.dispose();
    });

    testWidgets('Wi-Fi Direct: no search before Continue', (t) async {
      final svc = _Direct();
      final c = await _controller(FakePermissions());
      await _pumpIn(t, c, WifiDirectPage(service: svc));
      expect(find.byKey(const Key('permissionSheet-nearbyDevices')),
          findsOneWidget);
      expect(svc.calls, isEmpty);
      await t.tap(find.byKey(const Key('permissionNotNow')));
      await t.pumpAndSettle();
      expect(svc.calls, isEmpty);
      expect(find.byKey(const Key('permissionNotNow-nearbyDevices')),
          findsOneWidget);
      await t.tap(find.byKey(const Key('permissionRetry-nearbyDevices')));
      await t.pumpAndSettle();
      expect(svc.calls, ['discover']);
      expect(find.byKey(const Key('permissionNotNow-nearbyDevices')),
          findsNothing);
      c.dispose();
    });

    testWidgets('already granted: no explanation', (t) async {
      final svc = _Direct();
      final c = await _controller(
          FakePermissions(granted: {AppPermission.nearbyDevices}));
      await _pumpIn(t, c, WifiDirectPage(service: svc));
      expect(find.byKey(const Key('permissionSheet-nearbyDevices')),
          findsNothing);
      expect(svc.calls, ['discover']);
      c.dispose();
    });
  });

  group('camera', () {
    testWidgets('Join by QR: Not now offers typing; Try again asks', (t) async {
      final svc = _Join();
      final c = await _controller(FakePermissions());
      await _pumpIn(
          t,
          c,
          WifiJoinPage(
              service: svc,
              scannerBuilder: (_, _) => const SizedBox(key: Key('scanner')),
              localAddresses: () async => const []));
      expect(find.byKey(const Key('permissionSheet-camera')), findsOneWidget);
      await t.tap(find.byKey(const Key('permissionNotNow')));
      await t.pumpAndSettle();
      expect(svc.cameraRequests, 0);
      expect(find.byKey(const Key('permissionNotNow-camera')), findsOneWidget);
      expect(find.byKey(const Key('manualSsid')), findsOneWidget);
      await t.tap(find.byKey(const Key('permissionRetry-camera')));
      await t.pumpAndSettle();
      expect(svc.cameraRequests, 1);
      expect(find.byKey(const Key('scanner')), findsOneWidget);
      c.dispose();
    });
  });

  group('Persian', () {
    for (final width in [375.0, 1000.0]) {
      testWidgets('fa at ${width.toInt()} px: sheet and note are RTL',
          (t) async {
        final svc = _Direct();
        final c = await _controller(FakePermissions());
        await _pumpIn(t, c, WifiDirectPage(service: svc),
            locale: const Locale('fa'), width: width);
        final sheet = find.byKey(const Key('permissionSheet-nearbyDevices'));
        expect(sheet, findsOneWidget);
        expect(Directionality.of(t.element(sheet)), TextDirection.rtl);
        expect(find.text(fa.permNearbyTitle), findsOneWidget);
        expect(find.text(fa.permContinue), findsOneWidget);
        expect(find.text(en.permNearbyTitle), findsNothing);
        await t.tap(find.byKey(const Key('permissionNotNow')));
        await t.pumpAndSettle();
        expect(find.text(fa.permNearbyOff), findsOneWidget);
        expect(find.text(fa.permTryAgain), findsOneWidget);
        c.dispose();
      });

      testWidgets('fa at ${width.toInt()} px: notification and camera sheets',
          (t) async {
        await _pumpApp(t, FakePermissions(), locale: 'fa', width: width);
        expect(find.text(fa.permNotificationsTitle), findsOneWidget);
        await t.tap(find.byKey(const Key('permissionNotNow')));
        await t.pumpAndSettle();
        expect(find.text(fa.permNotificationsOff), findsOneWidget);
        await t.pumpWidget(const SizedBox());
        final c = await _controller(FakePermissions());
        await _pumpIn(
            t,
            c,
            WifiJoinPage(
                service: _Join(),
                scannerBuilder: (_, _) => const SizedBox(),
                localAddresses: () async => const []),
            locale: const Locale('fa'),
            width: width);
        expect(find.text(fa.permCameraTitle), findsOneWidget);
        await t.tap(find.byKey(const Key('permissionNotNow')));
        await t.pumpAndSettle();
        expect(find.text(fa.permCameraOff), findsOneWidget);
        c.dispose();
      });
    }
  });
}
