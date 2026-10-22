// First-run onboarding and the Android storage explanation (docs/UX.md
// 3.6, step U8).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/core/api.dart';
import 'package:landrop/l10n/app_localizations.dart';
import 'package:landrop/ui/app.dart';
import 'package:landrop/ui/app_controller.dart';
import 'package:landrop/ui/fake_core.dart';
import 'package:landrop/ui/ltr_text.dart' show ltr;
import 'package:landrop/ui/storage_access.dart';

import 'helpers/pump_localized.dart';

final en = lookupAppLocalizations(const Locale('en'));
final fa = lookupAppLocalizations(const Locale('fa'));

/// Android without a real permission dialog: [grant] decides the answer
/// of the system screen.
class FakeStorage extends StorageAccess {
  FakeStorage({this.android = true, this.grant = true, this.already = false});
  final bool android;
  bool grant;
  bool already;
  int requests = 0;

  @override
  bool get isAndroid => android;
  @override
  String get publicDir => '/tmp/landrop-test-public';
  @override
  Future<bool> granted() async => already;
  @override
  Future<bool> request() async {
    requests++;
    if (grant) already = true;
    return grant;
  }
}

Future<(FakeCore, MemorySettingsStore)> _pump(WidgetTester t,
    {String locale = 'en',
    bool onboarded = false,
    double width = 400,
    double height = 800,
    String platform = 'android',
    FakeStorage? storage,
    Map<String, dynamic>? stored}) async {
  t.view.physicalSize = Size(width, height);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final core = FakeCore(simulateDelay: const Duration(milliseconds: 10));
  final store = MemorySettingsStore({'locale': locale, ...?stored}, onboarded);
  await t.pumpWidget(LanDropApp(
    core: core,
    store: store,
    initialSaveDir: '/tmp/landrop-test',
    initialAlias: 'Tester',
    pickFiles: () async => <String>[],
    pickFolder: () async => null,
    storageAccess: storage ?? FakeStorage(android: false),
    onboardingPlatform: platform,
  ));
  await t.pumpAndSettle();
  return (core, store);
}

Future<void> _tap(WidgetTester t, String key) async {
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

void main() {
  group('onboarding', () {
    testWidgets('shown on the first run: three screens, Next, Start',
        (t) async {
      final (_, store) = await _pump(t);
      expect(find.byKey(const Key('onboarding')), findsOneWidget);
      expect(find.byKey(const Key('sendFab')), findsNothing);
      expect(find.text(en.onboarding1Title), findsOneWidget);
      expect(find.bySemanticsLabel(en.onboardingStep(1, 3)), findsOneWidget);
      await _tap(t, 'onboardingNext');
      expect(find.text(en.onboarding2Title), findsOneWidget);
      expect(find.bySemanticsLabel(en.onboardingStep(2, 3)), findsOneWidget);
      await _tap(t, 'onboardingNext');
      expect(find.text(en.onboarding3Title), findsOneWidget);
      // Explained, never asked during onboarding.
      expect(find.text(en.onboardingStorageAndroid), findsOneWidget);
      expect(find.byKey(const Key('onboardingSkip')), findsNothing);
      await t.enterText(find.byKey(const Key('onboardingAlias')), 'Sara');
      await _tap(t, 'onboardingStart');
      expect(find.byKey(const Key('onboarding')), findsNothing);
      expect(find.byKey(const Key('sendFab')), findsOneWidget);
      expect(store.stored['onboarded'], isTrue);
      expect(store.stored['alias'], 'Sara');
    });

    testWidgets('Skip ends it at once and keeps the name', (t) async {
      final (_, store) = await _pump(t);
      await _tap(t, 'onboardingSkip');
      expect(find.byKey(const Key('sendFab')), findsOneWidget);
      expect(store.stored['onboarded'], isTrue);
      expect(store.stored['alias'], 'Tester');
    });

    testWidgets('not shown again once done; not for older settings files',
        (t) async {
      await _pump(t, onboarded: true);
      expect(find.byKey(const Key('onboarding')), findsNothing);
      expect(find.byKey(const Key('sendFab')), findsOneWidget);
    });

    test('settings saved before onboarding existed count as onboarded',
        () async {
      final old = MemorySettingsStore({'alias': 'Old'})
        ..stored.remove('onboarded');
      final c = AppController(
          core: FakeCore(simulateDelay: Duration.zero),
          store: old,
          initialSaveDir: '/tmp/landrop-test');
      await c.init();
      expect(c.onboarded, isTrue);
      c.dispose();
      final fresh = MemorySettingsStore()..stored.clear();
      final c2 = AppController(
          core: FakeCore(simulateDelay: Duration.zero),
          store: fresh,
          initialSaveDir: '/tmp/landrop-test');
      await c2.init();
      expect(c2.onboarded, isFalse);
      c2.dispose();
    });

    for (final (os, text) in [
      ('macos', en.onboardingLocalNetworkComputer),
      ('ios', en.onboardingLocalNetworkPhone),
      ('windows', en.onboardingFirewallWindows),
      ('linux', en.onboardingNothingToAllow),
    ]) {
      testWidgets('permission line for $os', (t) async {
        await _pump(t, platform: os);
        await _tap(t, 'onboardingNext');
        await _tap(t, 'onboardingNext');
        expect(find.text(text), findsOneWidget);
        expect(find.text(en.onboardingStorageAndroid), findsNothing);
      });
    }

    for (final width in [375.0, 1000.0]) {
      testWidgets('Persian, right to left, at ${width.toInt()} px', (t) async {
        await _pump(t, locale: 'fa', width: width, platform: 'macos');
        expectRtl(t);
        expect(find.text(fa.onboarding1Title), findsOneWidget);
        expect(find.text(fa.onboardingSkip), findsOneWidget);
        expect(find.text('Skip'), findsNothing);
        // Skip sits at the end side: left in RTL.
        expect(t.getCenter(find.byKey(const Key('onboardingSkip'))).dx,
            lessThan(width / 2));
        expect(find.bySemanticsLabel(fa.onboardingStep(1, 3)), findsOneWidget);
        await _tap(t, 'onboardingNext');
        expect(find.text(fa.onboarding2Body), findsOneWidget);
        await _tap(t, 'onboardingNext');
        expect(find.text(fa.onboardingLocalNetworkComputer), findsOneWidget);
        expect(find.text(fa.onboardingStart), findsOneWidget);
        expect(t.takeException(), isNull);
        await _tap(t, 'onboardingStart');
        expect(find.byKey(const Key('sendFab')), findsOneWidget);
      });
    }
  });

  group('Android storage explanation', () {
    test('start never asks: private folder until granted', () async {
      final storage = FakeStorage();
      final c = AppController(
          core: FakeCore(simulateDelay: Duration.zero),
          store: MemorySettingsStore(),
          storageAccess: storage);
      await c.init();
      expect(storage.requests, 0);
      expect(c.saveDir, isNot(storage.publicDir));
      expect(c.savesToPrivateFolder, isTrue);
      expect(c.needsStorageExplanation, isTrue);
      c.dispose();

      // Granted earlier (e.g. by an older version): Downloads at once.
      final granted = FakeStorage(already: true);
      final c2 = AppController(
          core: FakeCore(simulateDelay: Duration.zero),
          store: MemorySettingsStore(),
          storageAccess: granted);
      await c2.init();
      expect(granted.requests, 0);
      expect(c2.saveDir, granted.publicDir);
      expect(c2.needsStorageExplanation, isFalse);
      c2.dispose();
    });

    test('Not now keeps the private folder and is not asked again',
        () async {
      final storage = FakeStorage();
      final store = MemorySettingsStore();
      final core = FakeCore(simulateDelay: Duration.zero);
      final c = AppController(
          core: core,
          store: store,
          initialSaveDir: '/tmp/landrop-private',
          storageAccess: storage);
      await c.init();
      expect(await c.answerStorageExplanation(false), isFalse);
      expect(storage.requests, 0);
      expect(c.saveDir, '/tmp/landrop-private');
      expect(c.needsStorageExplanation, isFalse);
      expect(store.stored['storageAsked'], isTrue);
      expect(core.saveDirChanges, isEmpty);
      c.dispose();
    });

    testWidgets(
        'first accepted transfer: explanation before the system screen; '
        'Allow moves it to Downloads without a restart', (t) async {
      final storage = FakeStorage();
      final (core, store) = await _pump(t, onboarded: true, storage: storage);
      final req = core.simulateIncoming(autoProgress: false);
      await t.pumpAndSettle();
      await _tap(t, 'incomingAccept');
      expect(find.byKey(const Key('storageSheet')), findsOneWidget);
      expect(find.text(en.storageTitle), findsOneWidget);
      expect(storage.requests, 0, reason: 'explained first');
      expect(req.decision.isCompleted, isFalse);
      await _tap(t, 'storageAllow');
      expect(storage.requests, 1);
      expect(core.saveDirChanges, [storage.publicDir]);
      expect(await req.decision.future, isTrue);
      expect(find.byKey(const Key('storageResult')), findsOneWidget);
      expect(store.stored['storageAsked'], isTrue);
      // The next transfer is not interrupted again.
      final next = core.simulateIncoming(autoProgress: false);
      await t.pumpAndSettle();
      await _tap(t, 'incomingAccept');
      expect(find.byKey(const Key('storageSheet')), findsNothing);
      expect(await next.decision.future, isTrue);
    });

    testWidgets('denied on the system screen: private folder, Settings can '
        'ask again', (t) async {
      final storage = FakeStorage(grant: false);
      final (core, _) = await _pump(t, onboarded: true, storage: storage);
      core.simulateIncoming(autoProgress: false);
      await t.pumpAndSettle();
      await _tap(t, 'incomingAccept');
      await _tap(t, 'storageAllow');
      expect(storage.requests, 1);
      expect(core.saveDirChanges, isEmpty);
      expect(find.text(en.storageKeptPrivate), findsOneWidget);

      // Settings ▸ "Use Downloads": the explanation again, then granted.
      await t.tap(find.byTooltip('Settings'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('privateFolderHint')), findsOneWidget);
      storage.grant = true;
      await _tap(t, 'useDownloads');
      expect(find.byKey(const Key('storageSheet')), findsOneWidget);
      await _tap(t, 'storageAllow');
      expect(storage.requests, 2);
      expect(core.saveDirChanges, [storage.publicDir]);
      expect(find.byKey(const Key('privateFolderHint')), findsNothing);
    });

    testWidgets('Not now in the sheet answers the request, files stay private',
        (t) async {
      final storage = FakeStorage();
      final (core, _) = await _pump(t, onboarded: true, storage: storage);
      final req = core.simulateIncoming(autoProgress: false);
      await t.pumpAndSettle();
      await _tap(t, 'incomingAccept');
      await _tap(t, 'storageNotNow');
      expect(storage.requests, 0);
      expect(await req.decision.future, isTrue);
      expect(find.text(en.storageKeptPrivate), findsOneWidget);
    });

    testWidgets('not shown off Android', (t) async {
      final (core, _) = await _pump(t, onboarded: true);
      final req = core.simulateIncoming(autoProgress: false);
      await t.pumpAndSettle();
      await _tap(t, 'incomingAccept');
      expect(find.byKey(const Key('storageSheet')), findsNothing);
      expect(await req.decision.future, isTrue);
    });

    for (final width in [375.0, 1000.0]) {
      testWidgets('explanation in Persian at ${width.toInt()} px', (t) async {
        final storage = FakeStorage();
        final (core, _) = await _pump(t,
            locale: 'fa', onboarded: true, width: width, storage: storage);
        core.simulateIncoming(from: FakeCore.persianPeer, autoProgress: false);
        await t.pumpAndSettle();
        await _tap(t, 'incomingAccept');
        expectRtl(t);
        expect(find.text(fa.storageTitle), findsOneWidget);
        expect(find.text(fa.storageBody), findsOneWidget);
        expect(find.text(fa.storageAllow), findsOneWidget);
        expect(find.text('Allow'), findsNothing);
        expect(t.takeException(), isNull);
        await _tap(t, 'storageAllow');
        expect(
            find.text(fa.storageGranted(ltr('Downloads/LanDrop'))),
            findsOneWidget);
      });
    }
  });

  test('IncomingRequest.text only for one text/plain offer with a preview',
      () {
    const d = FakeCore.persianPeer;
    IncomingRequest r(List<FileOffer> f) => IncomingRequest('s', d, f);
    expect(r([const FileOffer('a', 'message.txt', 2, 'text/plain', preview: 'hi')]).text,
        'hi');
    expect(r([const FileOffer('a', 'notes.txt', 2, 'text/plain')]).isText, isFalse);
    expect(
        r([const FileOffer('a', 'x.png', 2, 'image/png', preview: 'hi')]).isText,
        isFalse);
    expect(
        r([
          const FileOffer('a', 'm.txt', 2, 'text/plain', preview: 'a'),
          const FileOffer('b', 'n.txt', 2, 'text/plain', preview: 'b'),
        ]).isText,
        isFalse);
  });
}
