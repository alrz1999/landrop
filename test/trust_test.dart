// Receive dialog and trusted devices (docs/UX.md 3.7, step U7).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/core/api.dart';
import 'package:landrop/ui/app.dart';
import 'package:landrop/ui/app_controller.dart';
import 'package:landrop/ui/fake_core.dart';
import 'package:landrop/ui/widgets.dart';

const _pixel = DeviceInfo(
    alias: 'Pixel 9',
    deviceType: 'mobile',
    deviceModel: 'Google',
    fingerprint: 'aa11',
    ip: '192.168.1.21');

/// Another device that took the trusted device's name.
const _impostor = DeviceInfo(
    alias: ' pixel 9 ',
    deviceType: 'desktop',
    fingerprint: 'ee55',
    ip: '192.168.1.66');

const _browser = DeviceInfo(
    alias: 'Browser 192.168.1.77',
    deviceType: 'web',
    deviceModel: 'Safari on iPhone',
    fingerprint: '',
    ip: '192.168.1.77',
    port: 0);

IncomingRequest _req(DeviceInfo from,
        {bool verified = true, int size = 1000, String id = 'r'}) =>
    IncomingRequest(id, from, [FileOffer('f1', 'a.txt', size, 'text/plain')],
        verified: verified);

Map<String, dynamic> _trustedJson(
        {String fp = 'aa11', String alias = 'Pixel 9', bool auto = true}) =>
    {
      'trustedDevices': [
        {
          'fingerprint': fp,
          'alias': alias,
          'trustedAt': '2026-10-01T10:00:00.000Z',
          'autoAccept': auto,
        }
      ],
    };

Future<(AppController, FakeCore)> _controller(
    {Map<String, dynamic>? stored, String saveDir = '/tmp/landrop-test'}) async {
  final core = FakeCore(simulateDelay: Duration.zero);
  final c = AppController(
      core: core,
      store: MemorySettingsStore(stored),
      initialSaveDir: saveDir);
  await c.init();
  return (c, core);
}

Future<FakeCore> _pumpApp(WidgetTester t,
    {Map<String, dynamic>? stored, double width = 400}) async {
  t.view.physicalSize = Size(width, 1200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final core = FakeCore(simulateDelay: const Duration(milliseconds: 10));
  await t.pumpWidget(LanDropApp(
    core: core,
    store: MemorySettingsStore({'locale': 'en', ...?stored}),
    initialSaveDir: '/tmp/landrop-test',
    initialAlias: 'Tester',
    pickFiles: () async => <String>[],
    pickFolder: () async => null,
  ));
  await t.pumpAndSettle();
  return core;
}

void main() {
  group('controller', () {
    test('first accept remembers the device; "Always accept" is persisted',
        () async {
      final store = MemorySettingsStore();
      final core = FakeCore(simulateDelay: Duration.zero);
      final c = AppController(
          core: core, store: store, initialSaveDir: '/tmp/landrop-test');
      await c.init();
      final first = _req(_pixel);
      expect(c.trustOf(first), SenderTrust.firstTime);
      c.respond(first, true, alwaysAccept: true);
      await Future<void>.delayed(Duration.zero);
      final saved = (store.stored['trustedDevices'] as List).single as Map;
      expect(saved['fingerprint'], 'aa11');
      expect(saved['alias'], 'Pixel 9');
      expect(saved['autoAccept'], isTrue);
      expect(DateTime.tryParse(saved['trustedAt'] as String), isNotNull);
      c.dispose();

      // A new start reads it back.
      final c2 = AppController(
          core: FakeCore(simulateDelay: Duration.zero),
          store: store,
          initialSaveDir: '/tmp/landrop-test');
      await c2.init();
      expect(c2.trustedDevices.single.fingerprint, 'aa11');
      expect(c2.trustOf(_req(_pixel)), SenderTrust.trusted);
      expect(c2.shouldAutoAccept(_req(_pixel)), isTrue);
      c2.dispose();
    });

    test('accept without the box: trusted but still asks', () async {
      final (c, _) = await _controller();
      c.respond(_req(_pixel), true);
      expect(c.trustOf(_req(_pixel)), SenderTrust.trusted);
      expect(c.shouldAutoAccept(_req(_pixel)), isFalse);
      // Declining never trusts.
      c.respond(_req(_impostor), false);
      expect(c.trustedDevice('ee55'), isNull);
      c.dispose();
    });

    test('auto-accept by fingerprint only, never by name', () async {
      final (c, core) = await _controller(stored: _trustedJson());
      final asked = <IncomingRequest>[];
      final auto = <TransferSession>[];
      final s1 = c.incomingRequests.listen(asked.add);
      final s2 = c.autoAccepted.listen(auto.add);

      // The trusted device itself: accepted, no dialog.
      final real = core.simulateIncoming(from: _pixel, autoProgress: false);
      await Future<void>.delayed(Duration.zero);
      expect(await real.decision.future, isTrue);
      expect(asked, isEmpty);
      expect(auto.single.sessionId, real.sessionId);
      expect(auto.single.autoAccepted, isTrue);
      expect(c.sessions.first.autoAccepted, isTrue);

      // Same name, other fingerprint: asks, with a warning.
      final spoof = core.simulateIncoming(from: _impostor, autoProgress: false);
      await Future<void>.delayed(Duration.zero);
      expect(spoof.decision.isCompleted, isFalse);
      expect(asked.single, same(spoof));
      expect(c.trustOf(spoof), SenderTrust.firstTime);
      expect(c.aliasConflict(spoof)?.fingerprint, 'aa11');

      // The trusted fingerprint claimed without proof: asks, warns.
      final claim = core.simulateIncoming(
          from: _pixel, autoProgress: false, verified: false);
      await Future<void>.delayed(Duration.zero);
      expect(claim.decision.isCompleted, isFalse);
      expect(c.trustOf(claim), SenderTrust.unverified);
      expect(c.aliasConflict(claim)?.fingerprint, 'aa11');

      // The real device has no conflict with itself.
      expect(c.aliasConflict(_req(_pixel)), isNull);
      await s1.cancel();
      await s2.cancel();
      c.dispose();
    });

    test('browsers are never trusted or auto-accepted', () async {
      final (c, _) = await _controller(
          stored: _trustedJson(fp: '', alias: 'Browser 192.168.1.77'));
      final r = _req(_browser, verified: false);
      expect(c.trustOf(r), SenderTrust.browser);
      expect(c.shouldAutoAccept(r), isFalse);
      // Even a (wrongly) verified browser request.
      expect(c.shouldAutoAccept(_req(_browser)), isFalse);
      c.respond(r, true, alwaysAccept: true);
      expect(c.trustedDevices, isEmpty);
      c.dispose();
    });

    test('removing trust: the next request asks again ("First time")',
        () async {
      final (c, _) = await _controller(stored: _trustedJson());
      expect(c.shouldAutoAccept(_req(_pixel)), isTrue);
      await c.removeTrusted('aa11');
      expect(c.trustedDevices, isEmpty);
      expect(c.trustOf(_req(_pixel)), SenderTrust.firstTime);
      expect(c.shouldAutoAccept(_req(_pixel)), isFalse);
      c.dispose();
    });

    test('size cap: large transfers ask unless the setting allows them',
        () async {
      final (c, _) = await _controller(stored: _trustedJson());
      const cap = AppController.autoAcceptMaxBytes;
      expect(c.shouldAutoAccept(_req(_pixel, size: cap)), isTrue);
      expect(c.shouldAutoAccept(_req(_pixel, size: cap + 1)), isFalse);
      await c.setAutoAcceptLarge(true);
      expect(c.shouldAutoAccept(_req(_pixel, size: cap + 1)), isTrue);
      c.dispose();
    });

    test('no auto-accept without a save folder', () async {
      // Without init the folder stays as given (here: unset).
      final c = AppController(
          core: FakeCore(simulateDelay: Duration.zero),
          store: MemorySettingsStore(),
          initialSaveDir: '');
      c.respond(_req(_pixel), true, alwaysAccept: true);
      expect(c.trustedDevice('aa11')!.autoAccept, isTrue);
      expect(c.shouldAutoAccept(_req(_pixel)), isFalse);
      c.dispose();
    });

    test('rename is display only; auto-accept toggles', () async {
      final (c, _) = await _controller(stored: _trustedJson());
      await c.renameTrusted('aa11', 'Sara phone');
      expect(c.trustedDevice('aa11')!.name, 'Sara phone');
      expect(c.trustedDevice('aa11')!.alias, 'Pixel 9');
      // The new name decides nothing: same fingerprint still matches...
      expect(c.shouldAutoAccept(_req(_pixel)), isTrue);
      // ...and someone calling itself "Sara phone" is flagged.
      final fake = _req(const DeviceInfo(
          alias: 'Sara Phone',
          deviceType: 'mobile',
          fingerprint: 'ff66',
          ip: '192.168.1.9'));
      expect(c.aliasConflict(fake)?.fingerprint, 'aa11');
      await c.setAutoAccept('aa11', false);
      expect(c.shouldAutoAccept(_req(_pixel)), isFalse);
      // Empty name restores the device's own.
      await c.renameTrusted('aa11', '  ');
      expect(c.trustedDevice('aa11')!.name, 'Pixel 9');
      c.dispose();
    });
  });

  group('incoming dialog', () {
    testWidgets('first time: badge, Always accept box, details collapsed',
        (t) async {
      final core = await _pumpApp(t);
      final req = core.simulateIncoming(autoProgress: false);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('incomingBadge-firstTime')), findsOneWidget);
      expect(find.text('First time from this device'), findsOneWidget);
      expect(find.byKey(const Key('incomingAliasWarning')), findsNothing);
      // The security code is only under Details.
      expect(find.byKey(const Key('incomingSecurityCode')), findsNothing);
      await t.tap(find.byKey(const Key('incomingDetails')));
      await t.pumpAndSettle();
      expect(find.text('AA11'), findsOneWidget);
      expect(find.text('192.168.1.21:53317'), findsOneWidget);
      await t.tap(find.byKey(const Key('alwaysAccept')));
      await t.pump();
      await t.tap(find.byKey(const Key('incomingAccept')));
      await t.pumpAndSettle();
      expect(await req.decision.future, isTrue);
      final c = AppScopeHelper.controller(t);
      expect(c.trustedDevice('aa11')!.autoAccept, isTrue);
    });

    testWidgets('trusted without auto-accept: badge, no box', (t) async {
      final core = await _pumpApp(t, stored: _trustedJson(auto: false));
      core.simulateIncoming(autoProgress: false);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('incomingBadge-trusted')), findsOneWidget);
      expect(find.text('Trusted device'), findsOneWidget);
      expect(find.byKey(const Key('alwaysAccept')), findsNothing);
      await t.tap(find.byKey(const Key('incomingDecline')));
      await t.pumpAndSettle();
    });

    testWidgets('a trusted name with another security code: strong warning',
        (t) async {
      final core = await _pumpApp(t, stored: _trustedJson());
      final req =
          core.simulateIncoming(from: _impostor, autoProgress: false);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('incomingDialog')), findsOneWidget);
      expect(
          find.text('This device uses the name of "Pixel 9" but is not the '
              'same device.'),
          findsOneWidget);
      expect(find.byKey(const Key('incomingBadge-firstTime')), findsOneWidget);
      expect(find.byKey(const Key('alwaysAccept')), findsNothing);
      await t.tap(find.byKey(const Key('incomingDecline')));
      await t.pumpAndSettle();
      expect(await req.decision.future, isFalse);
    });

    testWidgets('unverified sender and browsers: no box', (t) async {
      final core = await _pumpApp(t);
      core.simulateIncoming(autoProgress: false, verified: false);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('incomingBadge-unverified')), findsOneWidget);
      expect(find.text('Identity not confirmed'), findsOneWidget);
      expect(find.byKey(const Key('alwaysAccept')), findsNothing);
      await t.tap(find.byKey(const Key('incomingDecline')));
      await t.pumpAndSettle();
      core.simulateIncoming(from: _browser, autoProgress: false);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('alwaysAccept')), findsNothing);
      expect(find.byKey(const Key('incomingDetails')), findsNothing);
      expect(find.byKey(const Key('incomingBadge-browser')), findsNothing);
      await t.tap(find.byKey(const Key('incomingDecline')));
      await t.pumpAndSettle();
    });

    testWidgets('"Change" opens Settings over the dialog', (t) async {
      final core = await _pumpApp(t);
      core.simulateIncoming(autoProgress: false);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('incomingChangeFolder')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('saveFolderSettings')), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.byKey(const Key('incomingDialog')), findsOneWidget);
      await t.tap(find.byKey(const Key('incomingDecline')));
      await t.pumpAndSettle();
    });
  });

  testWidgets('auto-accepted transfer: snackbar with Stop, card notice',
      (t) async {
    final core = await _pumpApp(t, stored: _trustedJson());
    final req = core.simulateIncoming(autoProgress: false);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('incomingDialog')), findsNothing);
    expect(await req.decision.future, isTrue);
    expect(find.byKey(const Key('autoAcceptSnack')), findsOneWidget);
    expect(find.text('Accepted from Pixel 9 automatically'), findsOneWidget);
    expect(find.byKey(Key('autoAccepted-${req.sessionId}')), findsOneWidget);
    expect(find.text('Accepted automatically'), findsOneWidget);
    await t.tap(find.widgetWithText(SnackBarAction, 'Stop auto-accept'));
    await t.pumpAndSettle();
    final c = AppScopeHelper.controller(t);
    expect(c.trustedDevice('aa11')!.autoAccept, isFalse);
    // The next transfer asks again.
    core.simulateIncoming(autoProgress: false);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('incomingBadge-trusted')), findsOneWidget);
    await t.tap(find.byKey(const Key('incomingDecline')));
    await t.pumpAndSettle();
  });

  testWidgets('Settings ▸ Trusted devices: list, rename, toggle, remove',
      (t) async {
    await _pumpApp(t, stored: _trustedJson(auto: false));
    await t.tap(find.byTooltip('Settings'));
    await t.pumpAndSettle();
    expect(find.text('1 device'), findsOneWidget);
    await t.tap(find.byKey(const Key('trustedDevicesSettings')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('trusted-aa11')), findsOneWidget);
    expect(find.text('Pixel 9'), findsOneWidget);
    expect(find.text('AA11'), findsOneWidget);
    final c = AppScopeHelper.controller(t);

    await t.tap(find.byKey(const Key('autoAccept-aa11')));
    await t.pumpAndSettle();
    expect(c.trustedDevice('aa11')!.autoAccept, isTrue);

    await t.tap(find.byKey(const Key('rename-aa11')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('renameTrustedField')), 'Sara');
    await t.tap(find.byKey(const Key('renameTrustedSave')));
    await t.pumpAndSettle();
    expect(find.text('Sara'), findsOneWidget);
    expect(find.text('Device name: Pixel 9'), findsOneWidget);

    await t.tap(find.byKey(const Key('autoAcceptLargeSwitch')));
    await t.pumpAndSettle();
    expect(c.autoAcceptLarge, isTrue);

    await t.tap(find.byKey(const Key('remove-aa11')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('trusted-aa11')), findsNothing);
    expect(find.byKey(const Key('trustedEmpty')), findsOneWidget);
    expect(c.trustedDevices, isEmpty);
  });
}

/// The app's controller, from the widget tree.
class AppScopeHelper {
  static AppController controller(WidgetTester t) =>
      AppScope.read(t.element(find.byType(Scaffold).first));
}
