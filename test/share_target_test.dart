// Android share target: the service (mocked channel) and the host that
// opens the device picker (docs/UX.md U10).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/core/api.dart';
import 'package:landrop/l10n/app_localizations.dart';
import 'package:landrop/ui/app.dart';
import 'package:landrop/ui/app_controller.dart';
import 'package:landrop/ui/fake_core.dart';
import 'package:landrop/ui/share_target.dart';

import 'package:landrop/ui/l10n.dart' show BidiL10n;

final en = lookupAppLocalizations(const Locale('en'));
final fa = lookupAppLocalizations(const Locale('fa'));

class FakeShare implements ShareTargetApi {
  FakeShare({this.initial});
  SharedContent? initial;
  final ctrl = StreamController<SharedContent>.broadcast();
  final cleared = <List<String>>[];

  @override
  bool get supported => true;
  @override
  Future<SharedContent?> getInitial() async => initial;
  @override
  Stream<SharedContent> get shares => ctrl.stream;
  @override
  Future<void> clear([List<String> paths = const []]) async =>
      cleared.add(paths);
}

Future<FakeCore> _pump(
  WidgetTester t,
  FakeShare share, {
  String locale = 'en',
  bool onboarded = true,
  double width = 400,
}) async {
  t.view.physicalSize = Size(width, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final core = FakeCore(simulateDelay: const Duration(milliseconds: 10));
  await t.pumpWidget(
    LanDropApp(
      core: core,
      store: MemorySettingsStore({'locale': locale}, onboarded),
      initialSaveDir: '/tmp/landrop-test',
      initialAlias: 'Tester',
      pickFiles: () async => <String>[],
      pickFolder: () async => null,
      shareTarget: share,
      onboardingPlatform: 'android',
    ),
  );
  await t.pumpAndSettle();
  return core;
}

Finder _inPicker(String name) =>
    find.descendant(of: _picker, matching: find.text(name));

Finder get _picker => find.byKey(const Key('peerPicker'));

void main() {
  group('ShareTargetService', () {
    const channel = MethodChannel('test/share');
    final calls = <MethodCall>[];
    Object? answer;

    setUp(() {
      calls.clear();
      answer = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (c) async {
            calls.add(c);
            if (answer is PlatformException) throw answer as PlatformException;
            return answer;
          });
    });
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    test('initial share: files and text', () async {
      answer = {
        'files': ['/c/shared/a/x.jpg', '/c/shared/a/y.pdf'],
        'text': null,
        'error': null,
      };
      final s = ShareTargetService(channel: channel, android: true);
      final c = await s.getInitial();
      expect(calls.single.method, 'getInitial');
      expect(c!.files, ['/c/shared/a/x.jpg', '/c/shared/a/y.pdf']);
      expect(c.text, isNull);
      expect(c.error, isNull);
      answer = {'files': [], 'text': 'https://example.com'};
      expect((await s.getInitial())!.text, 'https://example.com');
    });

    test('no initial share', () async {
      final s = ShareTargetService(channel: channel, android: true);
      expect(await s.getInitial(), isNull);
      answer = {'files': [], 'text': '  ', 'error': null};
      expect(await s.getInitial(), isNull);
    });

    test('a share while running arrives on the stream', () async {
      final events = StreamController<dynamic>();
      final s = ShareTargetService(
        channel: channel,
        events: events.stream,
        android: true,
      );
      final got = <SharedContent>[];
      final sub = s.shares.listen(got.add);
      events.add({
        'files': ['/c/a.txt'],
      });
      events.add('garbage');
      events.add({'files': [], 'text': 'hi'});
      await Future<void>.delayed(Duration.zero);
      expect(got.length, 2);
      expect(got[0].files, ['/c/a.txt']);
      expect(got[1].text, 'hi');
      await sub.cancel();
      await events.close();
    });

    test('errors: native error code and a failing channel', () async {
      final s = ShareTargetService(channel: channel, android: true);
      answer = {'files': [], 'error': 'tooMany'};
      expect((await s.getInitial())!.error, 'tooMany');
      answer = PlatformException(code: 'x');
      expect((await s.getInitial())!.error, 'failed');
    });

    test('clear passes the cached paths; failures are ignored', () async {
      final s = ShareTargetService(channel: channel, android: true);
      await s.clear(['/c/shared/a/x.jpg']);
      expect(calls.single.method, 'clear');
      expect(calls.single.arguments, {
        'paths': ['/c/shared/a/x.jpg'],
      });
      answer = PlatformException(code: 'x');
      await s.clear();
    });

    test('not Android: no-op, the channel is never called', () async {
      final s = ShareTargetService(channel: channel, android: false);
      expect(s.supported, isFalse);
      expect(await s.getInitial(), isNull);
      expect(await s.shares.isEmpty, isTrue);
      await s.clear(['/x']);
      expect(calls, isEmpty);
    });

    test('shareErrorText maps every code', () {
      expect(shareErrorText(en, 'tooMany'), en.shareErrTooMany);
      expect(shareErrorText(en, 'tooBig'), en.shareErrTooBig);
      expect(shareErrorText(en, 'unreadable'), en.shareErrUnreadable);
      expect(shareErrorText(en, 'other'), en.shareErrFailed);
    });
  });

  group('ShareTargetHost', () {
    testWidgets('shared files open the picker with the header; sending '
        'uses the controller and cleans the cache', (t) async {
      final share = FakeShare(
        initial: const SharedContent(
          files: ['/c/shared/a/x.jpg', '/c/shared/a/y.pdf'],
        ),
      );
      final core = await _pump(t, share);
      expect(_picker, findsOneWidget);
      expect(find.text(en.shareSendingFiles(2)), findsOneWidget);
      await t.tap(_inPicker('Pixel 9'));
      await t.pumpAndSettle();
      expect(core.sent.single.$1.fingerprint, 'aa11');
      expect(core.sent.single.$2, ['/c/shared/a/x.jpg', '/c/shared/a/y.pdf']);
      expect(share.cleared.single, ['/c/shared/a/x.jpg', '/c/shared/a/y.pdf']);
      expect(find.text(en.sendSent('Pixel 9')), findsOneWidget);
    });

    testWidgets('cancelling the picker still cleans the cache', (t) async {
      final share = FakeShare(initial: const SharedContent(files: ['/c/a/x']));
      final core = await _pump(t, share);
      expect(find.text(en.shareSendingFiles(1)), findsOneWidget);
      await t.tapAt(const Offset(5, 5)); // barrier
      await t.pumpAndSettle();
      expect(_picker, findsNothing);
      expect(core.sent, isEmpty);
      expect(share.cleared.single, ['/c/a/x']);
    });

    testWidgets('shared text goes through sendText', (t) async {
      final share = FakeShare(
        initial: const SharedContent(text: 'https://example.com/page'),
      );
      final core = await _pump(t, share);
      expect(find.text(en.shareSendingText), findsOneWidget);
      await t.tap(_inPicker('Work Laptop'));
      await t.pumpAndSettle();
      expect(core.sent, isEmpty);
      expect(core.sentTexts.single.$1.fingerprint, 'bb22');
      expect(core.sentTexts.single.$2, 'https://example.com/page');
      expect(share.cleared.single, isEmpty);
      expect(find.text(en.sendSent('Work Laptop')), findsOneWidget);
    });

    testWidgets('a share while the app runs', (t) async {
      final share = FakeShare();
      final core = await _pump(t, share);
      expect(_picker, findsNothing);
      share.ctrl.add(const SharedContent(files: ['/c/b/z.mp4']));
      await t.pumpAndSettle();
      expect(find.text(en.shareSendingFiles(1)), findsOneWidget);
      await t.tap(_inPicker('Pixel 9'));
      await t.pumpAndSettle();
      expect(core.sent.single.$2, ['/c/b/z.mp4']);
    });

    testWidgets('onboarding comes first, then the picker', (t) async {
      final share = FakeShare(initial: const SharedContent(text: 'hello'));
      final core = await _pump(t, share, onboarded: false);
      expect(find.byKey(const Key('onboarding')), findsOneWidget);
      expect(_picker, findsNothing);
      await t.tap(find.byKey(const Key('onboardingSkip')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('onboarding')), findsNothing);
      expect(_picker, findsOneWidget);
      await t.tap(_inPicker('Pixel 9'));
      await t.pumpAndSettle();
      expect(core.sentTexts.single.$2, 'hello');
    });

    testWidgets('an error shows a message and no picker', (t) async {
      final share = FakeShare(initial: const SharedContent(error: 'tooMany'));
      await _pump(t, share);
      expect(_picker, findsNothing);
      expect(find.text(en.shareErrTooMany), findsOneWidget);
      expect(share.cleared, isNotEmpty);
    });

    testWidgets('some items failed: message and the picker for the rest', (
      t,
    ) async {
      final share = FakeShare(
        initial: const SharedContent(files: ['/c/a/x'], error: 'unreadable'),
      );
      await _pump(t, share);
      expect(find.text(en.shareErrUnreadable), findsOneWidget);
      expect(find.text(en.shareSendingFiles(1)), findsOneWidget);
    });

    testWidgets('a failed send reports and still cleans the cache', (t) async {
      final share = FakeShare(initial: const SharedContent(files: ['/c/a/x']));
      final core = FakeCore(simulateDelay: const Duration(milliseconds: 10))
        ..failSends['aa11'] = SendErrorCode.declined;
      t.view.physicalSize = const Size(400, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        LanDropApp(
          core: core,
          store: MemorySettingsStore({'locale': 'en'}),
          initialSaveDir: '/tmp/landrop-test',
          shareTarget: share,
        ),
      );
      await t.pumpAndSettle();
      await t.tap(_inPicker('Pixel 9'));
      await t.pumpAndSettle();
      expect(find.text(en.sendDeclined('Pixel 9')), findsOneWidget);
      expect(share.cleared.single, ['/c/a/x']);
    });

    for (final width in [375.0, 1000.0]) {
      testWidgets('fa: RTL picker and header at ${width.toInt()} px', (
        t,
      ) async {
        final share = FakeShare(
          initial: const SharedContent(files: ['/c/a/x', '/c/a/y', '/c/a/z']),
        );
        await _pump(t, share, locale: 'fa', width: width);
        expect(_picker, findsOneWidget);
        expect(find.text(fa.shareSendingFiles(3)), findsOneWidget);
        expect(Directionality.of(t.element(_picker)), TextDirection.rtl);
        expect(t.takeException(), isNull);
        if (width < 500) {
          // Narrow: dismiss (the test font makes a Persian transfer card wider
          // than a phone; the real font fits).
          await t.tapAt(const Offset(5, 5));
          await t.pumpAndSettle();
          expect(share.cleared.single, ['/c/a/x', '/c/a/y', '/c/a/z']);
          return;
        }
        await t.tap(_inPicker('Pixel 9'));
        await t.pumpAndSettle();
        expect(find.text(fa.sendSent(fa.isoName('Pixel 9'))), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('fa: error text and shared text header', (t) async {
      final share = FakeShare(initial: const SharedContent(text: 'سلام'));
      await _pump(t, share, locale: 'fa', width: 375);
      expect(find.text(fa.shareSendingText), findsOneWidget);
      expect(fa.shareSendingText, isNot(en.shareSendingText));
      for (final code in ['tooMany', 'tooBig', 'unreadable', 'failed']) {
        expect(shareErrorText(fa, code), isNot(shareErrorText(en, code)));
      }
    });
  });
}
