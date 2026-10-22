// Incoming requests that arrive before home is shown are queued, and the
// incoming dialog closes itself when the core ends the request (decision
// timeout, sender withdrew it). docs/UX.md section 6.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/core/api.dart';
import 'package:landrop/l10n/app_localizations.dart';
import 'package:landrop/ui/app.dart';
import 'package:landrop/ui/app_controller.dart';
import 'package:landrop/ui/fake_core.dart';
import 'package:landrop/ui/widgets.dart' show AppScope;

final en = lookupAppLocalizations(const Locale('en'));
final fa = lookupAppLocalizations(const Locale('fa'));

Future<FakeCore> _pump(WidgetTester t,
    {bool onboarded = true,
    String locale = 'en',
    double width = 400,
    FakeCore? core}) async {
  t.view.physicalSize = Size(width, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  core ??= FakeCore(simulateDelay: const Duration(milliseconds: 10));
  await t.pumpWidget(LanDropApp(
    core: core,
    store: MemorySettingsStore({'locale': locale}, onboarded),
    initialSaveDir: '/tmp/landrop-test',
    initialAlias: 'Tester',
    pickFiles: () async => <String>[],
    pickFolder: () async => null,
    onboardingPlatform: 'linux',
  ));
  await t.pumpAndSettle();
  return core;
}

AppController _controllerOf(WidgetTester t) =>
    AppScope.read(t.element(find.byType(Scaffold).first));

void main() {
  group('queue', () {
    test('the controller keeps requests until they are taken; ended ones '
        'leave by themselves', () async {
      final core = FakeCore(simulateDelay: Duration.zero);
      final c = AppController(
          core: core,
          store: MemorySettingsStore(),
          initialSaveDir: '/tmp/landrop-test');
      await c.init();
      var added = 0;
      final sub = c.promptsAdded.listen((_) => added++);
      final r1 = core.simulateIncoming(autoProgress: false);
      final r2 = core.simulateIncoming(autoProgress: false);
      final t1 = core.simulateIncomingText('hello');
      await Future<void>.delayed(Duration.zero);
      expect(added, 3);
      expect(c.pendingPrompts, hasLength(3));

      core.endIncoming(r1);
      await Future<void>.delayed(Duration.zero);
      expect(c.pendingPrompts, hasLength(2), reason: 'r1 timed out');
      expect(c.takePrompt(), same(r2));
      expect((c.takePrompt() as IncomingText).request, same(t1));
      expect(c.takePrompt(), isNull);

      // A request the core ended before it was taken is skipped too.
      final r3 = core.simulateIncoming(autoProgress: false);
      await Future<void>.delayed(Duration.zero);
      r3.endedBy = IncomingRequestEnd.withdrawn;
      r3.decision.complete(false);
      expect(c.takePrompt(), isNull);
      // Answering an ended request does not start a transfer.
      c.respond(r3, true);
      expect(c.sessions, isEmpty);
      await sub.cancel();
      c.dispose();
    });

    testWidgets('a request that arrives during onboarding is shown on home',
        (t) async {
      final core = await _pump(t, onboarded: false);
      expect(find.byKey(const Key('onboarding')), findsOneWidget);
      core.simulateIncoming(autoProgress: false);
      core.simulateIncomingText('Hi there');
      await t.pumpAndSettle();
      expect(find.byKey(const Key('incomingDialog')), findsNothing);

      await t.tap(find.byKey(const Key('onboardingSkip')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('incomingDialog')), findsOneWidget);
      await t.tap(find.byKey(const Key('incomingAccept')));
      await t.pumpAndSettle();
      // Then the text, in arrival order.
      expect(find.byKey(const Key('textDialog')), findsOneWidget);
      await t.tap(find.byKey(const Key('textClose')));
      await t.pumpAndSettle();
      expect(_controllerOf(t).pendingPrompts, isEmpty);
    });

    testWidgets('a request that timed out during onboarding is never shown',
        (t) async {
      final core = await _pump(t, onboarded: false);
      final r = core.simulateIncoming(autoProgress: false);
      await t.pumpAndSettle();
      core.endIncoming(r);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('onboardingSkip')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('incomingDialog')), findsNothing);
    });
  });

  group('dialog closes itself', () {
    testWidgets('on the decision timeout, with a snackbar', (t) async {
      final core = await _pump(t);
      final r = core.simulateIncoming(autoProgress: false);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('incomingDialog')), findsOneWidget);
      core.endIncoming(r, IncomingRequestEnd.timeout);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('incomingDialog')), findsNothing);
      expect(find.text(en.incomingExpired(r.sender.alias)), findsOneWidget);
      expect(_controllerOf(t).sessions, isEmpty);
    });

    testWidgets('when the sender withdraws, also with Settings on top',
        (t) async {
      final core = await _pump(t);
      final r = core.simulateIncoming(autoProgress: false);
      final next = core.simulateIncoming(
          from: FakeCore.defaultPeers.last, autoProgress: false);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('incomingChangeFolder')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('saveFolderSettings')), findsOneWidget);

      core.endIncoming(r, IncomingRequestEnd.withdrawn);
      await t.pumpAndSettle();
      // Settings stays open; the dialog under it is gone.
      expect(find.byKey(const Key('saveFolderSettings')), findsOneWidget);
      // The next request in the queue is shown (over Settings).
      expect(find.byKey(const Key('incomingDialog')), findsOneWidget);
      expect(find.text(en.incomingTitle(next.sender.alias, 2)), findsOneWidget);
      await t.tap(find.byKey(const Key('incomingDecline')));
      await t.pumpAndSettle();
      expect(next.decision.isCompleted, isTrue);
    });

    for (final width in [375.0, 1000.0]) {
      testWidgets('fa at ${width.toInt()} px: Persian snackbar, RTL',
          (t) async {
        final core = await _pump(t, locale: 'fa', width: width);
        final r = core.simulateIncoming(
            from: FakeCore.persianPeer, autoProgress: false);
        await t.pumpAndSettle();
        core.endIncoming(r, IncomingRequestEnd.withdrawn);
        await t.pumpAndSettle();
        final snack = find.byKey(const Key('incomingEnded'));
        expect(snack, findsOneWidget);
        expect(
            find.descendant(
                of: snack,
                matching: find.textContaining(fa
                    .incomingWithdrawn('X')
                    .replaceAll('X', '')
                    .trim())),
            findsOneWidget);
        expect(Directionality.of(t.element(snack)), TextDirection.rtl);
        expect(find.text(en.incomingWithdrawn(r.sender.alias)), findsNothing);
      });
    }
  });

  group('sender withdraws', () {
    test('Cancel before the receiver answers withdraws the request',
        () async {
      final core = FakeCore(simulateDelay: Duration.zero);
      final c = AppController(
          core: core,
          store: MemorySettingsStore(),
          initialSaveDir: '/tmp/landrop-test');
      await c.init();
      final peer = FakeCore.defaultPeers.first;
      core.acceptDelays[peer.fingerprint] = const Duration(seconds: 30);
      final send = c.sendWithResult(peer, ['/tmp/a.txt']);
      await Future<void>.delayed(Duration.zero);
      final s = c.sessions.single;
      expect(s.state, TransferState.waiting);
      unawaited(c.cancel(s));
      final r = await send.timeout(const Duration(seconds: 2));
      expect(r.errorCode, SendErrorCode.cancelled);
      expect(core.withdrawals.single.fingerprint, peer.fingerprint);
      expect(s.state, TransferState.cancelled);
      c.dispose();
    });
  });
}
