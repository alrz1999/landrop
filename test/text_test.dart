// Send text (PROTOCOL.md "Text messages"): the Send sheet's "Text", the
// received-text dialog, controller rules and Persian/RTL.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/core/api.dart';
import 'package:landrop/l10n/app_localizations.dart';
import 'package:landrop/ui/app.dart';
import 'package:landrop/ui/app_controller.dart';
import 'package:landrop/ui/fake_core.dart';
import 'package:landrop/ui/file_opener.dart';
import 'package:landrop/ui/ltr_text.dart' show iso;

import 'helpers/pump_localized.dart';

final en = lookupAppLocalizations(const Locale('en'));
final fa = lookupAppLocalizations(const Locale('fa'));

class _Opener implements FileOpener {
  _Opener({required this.canOpen});
  @override
  final bool canOpen;
  final List<String> links = [];
  @override
  Future<bool> open(String path) async => true;
  @override
  Future<bool> reveal(String path) async => true;
  @override
  Future<bool> openLink(String url) async {
    links.add(url);
    return true;
  }
}

const _trusted = {
  'trustedDevices': [
    {
      'fingerprint': 'aa11',
      'alias': 'Pixel 9',
      'trustedAt': '2026-10-01T10:00:00.000Z',
      'autoAccept': true,
    }
  ],
};

Future<(FakeCore, AppController)> _pump(WidgetTester t,
    {String locale = 'en',
    double width = 400,
    bool desktop = true,
    _Opener? opener,
    String saveDir = '/tmp/landrop-test',
    Map<String, dynamic>? stored}) async {
  t.view.physicalSize = Size(width, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final core = FakeCore(
      simulateDelay: const Duration(milliseconds: 10),
      initialPeers: [FakeCore.persianPeer, FakeCore.defaultPeers.first]);
  await t.pumpWidget(LanDropApp(
    core: core,
    store: MemorySettingsStore({'locale': locale, ...?stored}),
    initialSaveDir: saveDir,
    initialAlias: 'Tester',
    pickFiles: () async => <String>[],
    pickFolder: () async => null,
    fileOpener: opener ?? _Opener(canOpen: desktop),
  ));
  await t.pumpAndSettle();
  final c = (t.state(find.byType(LanDropApp)) as dynamic).controller
      as AppController;
  return (core, c);
}

Future<void> _tap(WidgetTester t, String key) async {
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

void main() {
  group('isWebLink', () {
    test('only one http(s) link with a host', () {
      expect(isWebLink('https://example.com/a?b=1'), isTrue);
      expect(isWebLink('  http://192.168.1.10:8080/x  '), isTrue);
      expect(isWebLink('see https://example.com'), isFalse);
      expect(isWebLink('https://exa mple.com'), isFalse);
      expect(isWebLink('javascript:alert(1)'), isFalse);
      expect(isWebLink('file:///etc/passwd'), isFalse);
      expect(isWebLink('ftp://example.com'), isFalse);
      expect(isWebLink('https://'), isFalse);
      expect(isWebLink('example.com'), isFalse);
      expect(isWebLink('https://example.com\nmore'), isFalse);
    });

    test('SystemFileOpener opens links without a shell, links only', () async {
      final calls = <(String, List<String>)>[];
      Future<ProcessResult> run(String exe, List<String> args) async {
        calls.add((exe, args));
        return ProcessResult(0, 0, '', '');
      }

      final mac = SystemFileOpener(os: 'macos', run: run);
      expect(await mac.openLink(' https://example.com '), isTrue);
      expect(calls.single.$1, 'open');
      expect(calls.single.$2, ['https://example.com']);
      expect(await mac.openLink('--help'), isFalse);
      expect(await mac.openLink('file:///etc/passwd'), isFalse);
      expect(calls, hasLength(1));
      final linux = SystemFileOpener(os: 'linux', run: run)
          .linkCommand('http://a.b')!;
      expect(linux.$1, 'xdg-open');
      expect(linux.$2, ['http://a.b']);
      final win = SystemFileOpener(os: 'windows', run: run)
          .linkCommand('http://a.b')!;
      expect(win.$1, 'explorer');
      expect(win.$2, ['http://a.b']);
      expect(SystemFileOpener(os: 'android', run: run)
          .linkCommand('http://a.b'), isNull);
    });
  });

  group('controller', () {
    test('sendText: a card with the text, history without the text',
        () async {
      final core = FakeCore(simulateDelay: Duration.zero);
      final store = MemorySettingsStore();
      final c = AppController(
          core: core, store: store, initialSaveDir: '/tmp/landrop-test');
      await c.init();
      final r = await c.sendText(FakeCore.defaultPeers.first, 'hello');
      expect(r.ok, isTrue);
      expect(core.sentTexts.single.$2, 'hello');
      final s = c.sessions.single;
      expect(s.text, 'hello');
      expect(s.state, TransferState.done);
      expect(s.sessionId, startsWith('local-'), reason: 'unique card keys');
      final h = c.history.single;
      expect(h.text, isTrue);
      expect(h.incoming, isFalse);
      expect(store.history.stored!.single.toString(), isNot(contains('hello')));
      c.dispose();
    });

    test('received text: delivered when shown, never trusts the sender',
        () async {
      final core = FakeCore(simulateDelay: Duration.zero);
      final c = AppController(
          core: core,
          store: MemorySettingsStore(),
          initialSaveDir: '/tmp/landrop-test');
      await c.init();
      final texts = <IncomingText>[];
      final asked = <IncomingRequest>[];
      final s1 = c.incomingTexts.listen(texts.add);
      final s2 = c.incomingRequests.listen(asked.add);
      final req = core.simulateIncomingText('hi there');
      await Future<void>.delayed(Duration.zero);
      expect(asked, isEmpty, reason: 'not the file dialog');
      expect(texts.single.auto, isFalse);
      expect(req.decision.isCompleted, isFalse);
      c.receiveText(req);
      expect(await req.decision.future, isTrue);
      expect(c.trustedDevices, isEmpty);
      expect(c.sessions, isEmpty, reason: 'nothing transferred');
      expect(c.history.single.text, isTrue);
      await s1.cancel();
      await s2.cancel();
      c.dispose();
    });

    test('auto-accept: only a proven, trusted device with "Always accept"',
        () async {
      final core = FakeCore(simulateDelay: Duration.zero);
      final c = AppController(
          core: core,
          store: MemorySettingsStore(_trusted),
          initialSaveDir: '/tmp/landrop-test');
      await c.init();
      final texts = <IncomingText>[];
      final sub = c.incomingTexts.listen(texts.add);
      final ok = core.simulateIncomingText('auto');
      await Future<void>.delayed(Duration.zero);
      expect(ok.decision.isCompleted, isTrue);
      expect(texts.last.auto, isTrue);
      // Same fingerprint claimed without proof: shown, never auto.
      final claim = core.simulateIncomingText('claim', verified: false);
      await Future<void>.delayed(Duration.zero);
      expect(claim.decision.isCompleted, isFalse);
      expect(texts.last.auto, isFalse);
      // Another device: never auto.
      final other =
          core.simulateIncomingText('x', from: FakeCore.defaultPeers.last);
      await Future<void>.delayed(Duration.zero);
      expect(other.decision.isCompleted, isFalse);
      expect(texts.last.auto, isFalse);
      await sub.cancel();
      c.dispose();
    });

    test('saveTextAsFile writes message.txt with a unique name', () async {
      final dir = await Directory.systemTemp.createTemp('landrop_text_ui');
      addTearDown(() => dir.delete(recursive: true));
      final c = AppController(
          core: FakeCore(simulateDelay: Duration.zero),
          store: MemorySettingsStore(),
          initialSaveDir: dir.path);
      await c.init();
      final p1 = await c.saveTextAsFile('one');
      final p2 = await c.saveTextAsFile('two');
      expect(File(p1!).readAsStringSync(), 'one');
      expect(p1, endsWith('message.txt'));
      expect(File(p2!).readAsStringSync(), 'two');
      expect(p2, endsWith('message (1).txt'));
      c.dispose();
    });
  });

  group('send', () {
    testWidgets('Send ▸ Text: type, choose the device, sent', (t) async {
      final (core, _) = await _pump(t);
      await _tap(t, 'sendFab');
      expect(find.byKey(const Key('sendText')), findsOneWidget);
      await _tap(t, 'sendText');
      expect(find.byKey(const Key('sendTextDialog')), findsOneWidget);
      expect(find.bySemanticsLabel(en.sendTextTitle), findsWidgets);
      final next = find.byKey(const Key('sendTextNext'));
      expect(t.widget<FilledButton>(next).onPressed, isNull, reason: 'empty');
      await t.enterText(find.byKey(const Key('sendTextField')), 'Hi Sara');
      await t.pump();
      await _tap(t, 'sendTextNext');
      expect(find.text(en.sendPickerTitleText), findsOneWidget);
      await t.tap(find.text('Pixel 9').last);
      await t.pumpAndSettle();
      expect(core.sentTexts.single.$1.fingerprint, 'aa11');
      expect(core.sentTexts.single.$2, 'Hi Sara');
      expect(find.text('Sent to Pixel 9.'), findsOneWidget);
      final preview = find.byWidgetPredicate((w) =>
          w.key is ValueKey<String> &&
          (w.key as ValueKey<String>).value.startsWith('textPreview-'));
      expect(preview, findsOneWidget);
    });

    testWidgets('Paste and the 64 KiB limit', (t) async {
      await _pump(t);
      String? clip = 'pasted https://example.com';
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') return {'text': clip};
        return null;
      });
      addTearDown(() => t.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      await _tap(t, 'sendFab');
      await _tap(t, 'sendText');
      await _tap(t, 'sendTextPaste');
      expect(
          t.widget<TextField>(find.byKey(const Key('sendTextField')))
              .controller!
              .text,
          'pasted https://example.com');
      await t.enterText(
          find.byKey(const Key('sendTextField')), 'x' * (maxTextBytes + 1));
      await t.pump();
      expect(find.text(en.sendTextTooLong('64.0 KB')), findsOneWidget);
      expect(
          t.widget<FilledButton>(find.byKey(const Key('sendTextNext')))
              .onPressed,
          isNull);
      clip = null;
    });

    testWidgets('failed text: Try again sends the same text', (t) async {
      final (core, _) = await _pump(t);
      core.failSends['aa11'] = SendErrorCode.unreachable;
      await _tap(t, 'sendFab');
      await _tap(t, 'sendText');
      await t.enterText(find.byKey(const Key('sendTextField')), 'retry me');
      await t.pump();
      await _tap(t, 'sendTextNext');
      await t.tap(find.text('Pixel 9').last);
      await t.pumpAndSettle();
      final retry = find.byWidgetPredicate((w) =>
          w is TextButton &&
          w.key is ValueKey<String> &&
          (w.key as ValueKey<String>).value.startsWith('retry-'));
      expect(retry, findsOneWidget);
      core.failSends.clear();
      await t.ensureVisible(retry);
      await t.tap(retry);
      await t.pumpAndSettle();
      expect(core.sentTexts.map((e) => e.$2), ['retry me', 'retry me']);
    });
  });

  group('receive', () {
    testWidgets('dialog: text, Copy, Open link on desktops, nothing saved',
        (t) async {
      final opener = _Opener(canOpen: true);
      final (core, _) = await _pump(t, opener: opener);
      final req = core.simulateIncomingText('https://example.com/x');
      await t.pumpAndSettle();
      expect(find.byKey(const Key('textDialog')), findsOneWidget);
      expect(find.text('Text from Pixel 9'), findsOneWidget);
      expect(find.bySemanticsLabel('Text from Pixel 9'), findsWidgets);
      expect(find.byKey(const Key('textBadge-firstTime')), findsOneWidget);
      expect(await req.decision.future, isTrue, reason: 'delivered');
      final content =
          t.widget<SelectableText>(find.byKey(const Key('textContent')));
      expect(content.data, 'https://example.com/x');
      expect(content.textDirection, TextDirection.ltr);
      await _tap(t, 'textOpenLink');
      expect(opener.links, ['https://example.com/x']);
      String? copied;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      });
      addTearDown(() => t.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      await _tap(t, 'textCopy');
      expect(copied, 'https://example.com/x');
      await _tap(t, 'textClose');
      expect(find.byKey(const Key('textDialog')), findsNothing);
    });

    testWidgets('phones: Copy only; plain text never offers Open link',
        (t) async {
      final (core, _) = await _pump(t, desktop: false);
      core.simulateIncomingText('https://example.com');
      await t.pumpAndSettle();
      expect(find.byKey(const Key('textCopy')), findsOneWidget);
      expect(find.byKey(const Key('textOpenLink')), findsNothing);
      await _tap(t, 'textClose');
      core.simulateIncomingText('<a href="https://evil">click</a>');
      await t.pumpAndSettle();
      expect(find.text('<a href="https://evil">click</a>'), findsOneWidget);
      expect(find.byKey(const Key('textOpenLink')), findsNothing);
    });

    testWidgets('desktop: a sentence with a link is not a link', (t) async {
      final (core, _) = await _pump(t);
      core.simulateIncomingText('see https://example.com today');
      await t.pumpAndSettle();
      expect(find.byKey(const Key('textOpenLink')), findsNothing);
    });

    testWidgets('Save as file writes it to the save folder', (t) async {
      final dir = await t.runAsync(
          () => Directory.systemTemp.createTemp('landrop_text_save'));
      addTearDown(() => dir!.deleteSync(recursive: true));
      final (core, _) = await _pump(t, saveDir: dir!.path);
      core.simulateIncomingText('keep me');
      await t.pumpAndSettle();
      expect(dir.listSync(), isEmpty, reason: 'nothing written yet');
      await t.runAsync(() async {
        await t.tap(find.byKey(const Key('textSave')));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await t.pumpAndSettle();
      final f = File('${dir.path}/message.txt');
      expect(f.readAsStringSync(), 'keep me');
      expect(find.textContaining('Saved to'), findsOneWidget);
    });

    testWidgets('trusted with auto-accept: shown with a notice', (t) async {
      final (core, _) = await _pump(t, stored: _trusted);
      final req = core.simulateIncomingText('from my phone');
      await t.pumpAndSettle();
      expect(req.decision.isCompleted, isTrue);
      expect(find.byKey(const Key('textAutoNotice')), findsOneWidget);
      expect(find.byKey(const Key('textBadge-trusted')), findsOneWidget);
    });

    testWidgets('unverified sender: badge, no notice, no auto', (t) async {
      final (core, _) = await _pump(t, stored: _trusted);
      core.simulateIncomingText('claim', verified: false);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('textBadge-unverified')), findsOneWidget);
      expect(find.byKey(const Key('textAutoNotice')), findsNothing);
    });

    testWidgets('texts queue behind a file request', (t) async {
      final (core, _) = await _pump(t);
      core.simulateIncoming(autoProgress: false);
      core.simulateIncomingText('second');
      await t.pumpAndSettle();
      expect(find.byKey(const Key('incomingDialog')), findsOneWidget);
      expect(find.byKey(const Key('textDialog')), findsNothing);
      await _tap(t, 'incomingDecline');
      expect(find.byKey(const Key('textDialog')), findsOneWidget);
    });
  });

  group('Persian', () {
    for (final width in [375.0, 1000.0]) {
      final w = width.toInt();
      testWidgets('send and receive text in fa at $w px', (t) async {
        final (core, _) = await _pump(t, locale: 'fa', width: width);
        expectRtl(t);
        await _tap(t, 'sendFab');
        expect(find.text(fa.sendSheetText), findsOneWidget);
        await _tap(t, 'sendText');
        expect(find.text(fa.sendTextTitle), findsOneWidget);
        expect(find.text(fa.sendTextPaste), findsOneWidget);
        expect(find.text('Paste'), findsNothing);
        // The field follows the text: Persian is right to left, a link left
        // to right.
        await t.enterText(find.byKey(const Key('sendTextField')), 'سلام دنیا');
        await t.pump();
        expect(
            t.widget<TextField>(find.byKey(const Key('sendTextField')))
                .textDirection,
            TextDirection.rtl);
        await t.enterText(
            find.byKey(const Key('sendTextField')), 'https://example.com');
        await t.pump();
        expect(
            t.widget<TextField>(find.byKey(const Key('sendTextField')))
                .textDirection,
            TextDirection.ltr);
        expect(t.takeException(), isNull);
        await t.tap(find.text(fa.commonCancel));
        await t.pumpAndSettle();

        // Mixed Persian and Latin text from a Persian-named device.
        const mixed = 'گزارش final نسخهٔ 2 آماده است: report-v2.pdf';
        core.simulateIncomingText(mixed, from: FakeCore.persianPeer);
        await t.pumpAndSettle();
        expect(find.text(fa.textFromTitle(iso('لپ‌تاپ سارا'))), findsOneWidget);
        final content =
            t.widget<SelectableText>(find.byKey(const Key('textContent')));
        expect(content.data, mixed);
        expect(content.textDirection, TextDirection.rtl);
        expect(find.text(fa.textCopy), findsOneWidget);
        expect(find.text(fa.textSaveFile), findsOneWidget);
        expect(find.text('Copy'), findsNothing);
        expect(t.takeException(), isNull);
        await _tap(t, 'textClose');

        // An English text keeps its own direction inside the RTL dialog.
        core.simulateIncomingText('Meeting at 10, room B',
            from: FakeCore.persianPeer);
        await t.pumpAndSettle();
        final en1 =
            t.widget<SelectableText>(find.byKey(const Key('textContent')));
        expect(en1.textDirection, TextDirection.ltr);
        expect(en1.textAlign, TextAlign.right);
        expect(t.takeException(), isNull);
      });
    }
  });
}
