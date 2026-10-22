// Polish: "Try again" on failed sends, trusted mark and recent devices on
// home, Appearance (light/dark) in Settings.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/core/api.dart';
import 'package:landrop/l10n/app_localizations.dart';
import 'package:landrop/ui/app.dart';
import 'package:landrop/ui/app_controller.dart';
import 'package:landrop/ui/fake_core.dart';

import 'helpers/pump_localized.dart';

final en = lookupAppLocalizations(const Locale('en'));
final fa = lookupAppLocalizations(const Locale('fa'));

const _trusted = {
  'trustedDevices': [
    {
      'fingerprint': 'aa11',
      'alias': 'Pixel 9',
      'trustedAt': '2026-10-01T10:00:00.000Z',
      'autoAccept': false,
    }
  ],
};

Future<(FakeCore, MemorySettingsStore, AppController)> _pump(WidgetTester t,
    {String locale = 'en',
    double width = 400,
    double height = 1200,
    Map<String, dynamic>? stored,
    List<DeviceInfo>? peers,
    Future<List<String>> Function()? pick}) async {
  t.view.physicalSize = Size(width, height);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final core = FakeCore(
      simulateDelay: const Duration(milliseconds: 10), initialPeers: peers);
  final store = MemorySettingsStore({'locale': locale, ...?stored});
  await t.pumpWidget(LanDropApp(
    core: core,
    store: store,
    initialSaveDir: '/tmp/landrop-test',
    initialAlias: 'Tester',
    pickFiles: pick ?? () async => <String>[],
    pickFolder: () async => null,
  ));
  await t.pumpAndSettle();
  final c = (t.state(find.byType(LanDropApp)) as dynamic).controller
      as AppController;
  return (core, store, c);
}

Future<void> _tap(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  group('Try again', () {
    testWidgets('a failed send re-sends the same files to the same device',
        (t) async {
      final dir = await t.runAsync(
          () => Directory.systemTemp.createTemp('landrop_retry'));
      addTearDown(() => dir!.deleteSync(recursive: true));
      final a = File('${dir!.path}/a.txt')..writeAsStringSync('a');
      final b = File('${dir.path}/b.txt')..writeAsStringSync('b');
      final (core, _, c) =
          await _pump(t, pick: () async => [a.path, b.path]);
      core.failSends['aa11'] = SendErrorCode.unreachable;
      await t.tap(find.byKey(const Key('send-aa11')));
      await t.pumpAndSettle();
      final failed = c.sessions.single;
      expect(failed.state, TransferState.failed);
      final sid = failed.sessionId;
      expect(sid, isNotEmpty);
      expect(find.byKey(Key('retry-$sid')), findsOneWidget);
      expect(find.byKey(Key('retryMissing-$sid')), findsNothing);

      core.failSends.clear();
      await _tap(t, 'retry-$sid');
      expect(core.sent, hasLength(2));
      expect(core.sent.last.$1.fingerprint, 'aa11');
      expect(core.sent.last.$2, [a.path, b.path]);
      expect(c.sessions.first.state, TransferState.done);
      // Done and declined sends have no "Try again".
      expect(find.byKey(Key('retry-${c.sessions.first.sessionId}')),
          findsNothing);
    });

    testWidgets('disabled, with a reason, when a file is gone', (t) async {
      final dir = await t.runAsync(
          () => Directory.systemTemp.createTemp('landrop_retry'));
      addTearDown(() => dir!.deleteSync(recursive: true));
      final a = File('${dir!.path}/a.txt')..writeAsStringSync('a');
      final (core, _, c) = await _pump(t, pick: () async => [a.path]);
      core.failSends['aa11'] = SendErrorCode.unreachable;
      await t.tap(find.byKey(const Key('send-aa11')));
      await t.pumpAndSettle();
      a.deleteSync();
      c.notifyListeners();
      await t.pumpAndSettle();
      final sid = c.sessions.single.sessionId;
      final btn = t.widget<TextButton>(find.byKey(Key('retry-$sid')));
      expect(btn.onPressed, isNull);
      expect(find.byKey(Key('retryMissing-$sid')), findsOneWidget);
      expect(find.text(en.transferRetryMissing), findsOneWidget);
      expect(c.canRetry(c.sessions.single), isFalse);
    });

    testWidgets('declined: no Try again', (t) async {
      final (core, _, c) = await _pump(t, pick: () async => ['/tmp/x.txt']);
      core.failSends['aa11'] = SendErrorCode.declined;
      await t.tap(find.byKey(const Key('send-aa11')));
      await t.pumpAndSettle();
      expect(c.sessions.single.state, TransferState.declined);
      expect(find.byKey(Key('retry-${c.sessions.single.sessionId}')),
          findsNothing);
    });
  });

  group('devices', () {
    testWidgets('trusted devices carry a mark', (t) async {
      await _pump(t, stored: _trusted);
      expect(find.byKey(const Key('trustedMark-aa11')), findsOneWidget);
      expect(find.byKey(const Key('trustedMark-bb22')), findsNothing);
      expect(find.byTooltip(en.peerTrusted), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(en.peerTrusted)), findsWidgets);
    });

    testWidgets('devices that left show under Recent with Help', (t) async {
      final (core, store, _) = await _pump(t);
      expect(find.byKey(const Key('recentDevices')), findsNothing);
      core.setPeers([FakeCore.defaultPeers.last]);
      await t.pumpAndSettle();
      expect(find.text(en.homeRecent), findsOneWidget);
      expect(find.byKey(const Key('recent-aa11')), findsOneWidget);
      expect(find.byKey(const Key('recent-bb22')), findsNothing);
      expect(find.textContaining(en.recentNotNearby), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Pixel 9, not nearby')),
          findsOneWidget);
      final saved = store.stored['recentDevices'] as List;
      expect(saved.map((e) => (e as Map)['fingerprint']),
          containsAll(['aa11', 'bb22']));
      await _tap(t, 'recentHelp-aa11');
      expect(find.byKey(const Key('connectHelper')), findsOneWidget);
    });

    testWidgets('recent devices are restored at the next start', (t) async {
      await _pump(t, peers: const [], stored: {
        'recentDevices': [
          {
            'fingerprint': 'cc33',
            'alias': 'Home PC',
            'deviceType': 'desktop',
            'lastSeen': '2026-10-01T10:00:00.000Z',
          }
        ],
      });
      expect(find.text('Home PC'), findsOneWidget);
      expect(find.byKey(const Key('recent-cc33')), findsOneWidget);
      expect(find.text(en.emptyTitle), findsOneWidget, reason: 'still empty');
    });

    test('at most 20 recent devices, the most recent kept', () async {
      var now = DateTime(2026, 10, 22, 9);
      final core = FakeCore(simulateDelay: Duration.zero);
      final store = MemorySettingsStore();
      final c = AppController(
          core: core,
          store: store,
          initialSaveDir: '/tmp/landrop-test',
          clock: () => now);
      await c.init();
      for (var i = 0; i < 25; i++) {
        now = now.add(const Duration(minutes: 1));
        core.setPeers([
          DeviceInfo(
              alias: 'Device $i',
              deviceType: 'mobile',
              fingerprint: 'fp$i',
              ip: '192.168.1.${i + 2}'),
        ]);
        await Future<void>.delayed(Duration.zero);
      }
      final saved = store.stored['recentDevices'] as List;
      expect(saved, hasLength(AppController.maxRecent));
      final fps = saved.map((e) => (e as Map)['fingerprint']).toSet();
      expect(fps, contains('fp24'));
      expect(fps, isNot(contains('fp0')));
      expect(c.recentOffline.first.fingerprint, 'fp23');
      c.dispose();
    });
  });

  group('Appearance', () {
    testWidgets('Settings ▸ Appearance: Dark is applied and kept', (t) async {
      final (_, store, _) = await _pump(t);
      MaterialApp app() => t.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app().themeMode, ThemeMode.system);
      await t.tap(find.byTooltip('Settings'));
      await t.pumpAndSettle();
      expect(find.text(en.themeSystem), findsOneWidget);
      await _tap(t, 'themeSettings');
      expect(find.byKey(const Key('themeDialog')), findsOneWidget);
      expect(find.bySemanticsLabel(en.settingsAppearance), findsWidgets);
      await _tap(t, 'theme-dark');
      expect(app().themeMode, ThemeMode.dark);
      expect(store.stored['theme'], 'dark');
      expect(find.text(en.themeDark), findsOneWidget);
      expect(Theme.of(t.element(find.byType(Scaffold).last)).brightness,
          Brightness.dark);
    });

    testWidgets('a stored theme is applied at start', (t) async {
      await _pump(t, stored: {'theme': 'light'});
      expect(t.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
          ThemeMode.light);
    });
  });

  group('Persian', () {
    for (final width in [375.0, 1000.0]) {
      final w = width.toInt();
      testWidgets('recent, trusted mark, Appearance in fa at $w px',
          (t) async {
        final (core, _, _) = await _pump(t,
            locale: 'fa',
            width: width,
            stored: _trusted,
            peers: [FakeCore.persianPeer, FakeCore.defaultPeers.first]);
        expectRtl(t);
        expect(find.byKey(const Key('trustedMark-aa11')), findsOneWidget);
        core.setPeers([FakeCore.defaultPeers.first]);
        await t.pumpAndSettle();
        expect(find.text(fa.homeRecent), findsOneWidget);
        expect(find.text('لپ‌تاپ سارا'), findsOneWidget);
        expect(find.textContaining(fa.recentNotNearby), findsOneWidget);
        expect(find.text('Recent'), findsNothing);
        expect(t.takeException(), isNull);

        await t.tap(find.byIcon(Icons.settings_outlined));
        await t.pumpAndSettle();
        expect(find.text(fa.settingsAppearance), findsOneWidget);
        expect(find.text(fa.settingsSectionPrivacy), findsOneWidget);
        expect(find.text(fa.settingsKeepHistory), findsOneWidget);
        await _tap(t, 'themeSettings');
        expect(find.text(fa.themeLight), findsOneWidget);
        expect(find.text(fa.themeDark), findsOneWidget);
        expect(find.text('Dark'), findsNothing);
        expect(t.takeException(), isNull);
      });
    }
  });
}
