// Transfer history (docs/UX.md 6, "History"): recording, the 100-entry
// cap, privacy switch, the page with Today/Yesterday groups and details.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/core/api.dart';
import 'package:landrop/l10n/app_localizations.dart';
import 'package:landrop/ui/app.dart';
import 'package:landrop/ui/app_controller.dart';
import 'package:landrop/ui/fake_core.dart';
import 'package:landrop/ui/file_opener.dart';
import 'package:landrop/ui/format.dart';

import 'helpers/pump_localized.dart';

final en = lookupAppLocalizations(const Locale('en'));
final fa = lookupAppLocalizations(const Locale('fa'));

class _Opener implements FileOpener {
  _Opener({required this.canOpen});
  @override
  final bool canOpen;
  final List<String> opened = [], revealed = [];
  @override
  Future<bool> open(String path) async {
    opened.add(path);
    return true;
  }

  @override
  Future<bool> reveal(String path) async {
    revealed.add(path);
    return true;
  }

  @override
  Future<bool> openLink(String url) async => true;
}

Map<String, dynamic> _entry(String id,
        {required DateTime at,
        bool incoming = true,
        String peer = 'Pixel 9',
        List<String> files = const ['holiday.jpg'],
        int count = 1,
        String state = 'done',
        String? savedPath,
        bool text = false}) =>
    HistoryEntry(
      id: id,
      incoming: incoming,
      peerAlias: peer,
      fileNames: files,
      fileCount: count,
      totalBytes: 3250585,
      state: state,
      at: at,
      savedPath: savedPath,
      text: text,
    ).toJson();

Future<(AppController, MemorySettingsStore)> _pump(WidgetTester t,
    {String locale = 'en',
    double width = 400,
    bool desktop = true,
    List<Map<String, dynamic>>? history,
    _Opener? opener}) async {
  t.view.physicalSize = Size(width, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final store = MemorySettingsStore({'locale': locale});
  store.history.stored = history;
  await t.pumpWidget(LanDropApp(
    core: FakeCore(simulateDelay: const Duration(milliseconds: 10)),
    store: store,
    initialSaveDir: '/tmp/landrop-test',
    initialAlias: 'Tester',
    pickFiles: () async => <String>[],
    pickFolder: () async => null,
    fileOpener: opener ?? _Opener(canOpen: desktop),
  ));
  await t.pumpAndSettle();
  final c = (t.state(find.byType(LanDropApp)) as dynamic).controller
      as AppController;
  return (c, store);
}

Future<void> _tap(WidgetTester t, String key) async {
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

void main() {
  group('controller', () {
    test('records sends, failures and received files; survives a restart',
        () async {
      final core = FakeCore(simulateDelay: Duration.zero);
      core.failSends['bb22'] = SendErrorCode.declined;
      final store = MemorySettingsStore();
      final c = AppController(
          core: core, store: store, initialSaveDir: '/tmp/landrop-test');
      await c.init();
      await c.sendWithResult(FakeCore.defaultPeers.first, ['/tmp/a.jpg']);
      await c.sendWithResult(FakeCore.defaultPeers.last, ['/tmp/b.pdf']);
      final req = core.simulateIncoming(files: const [
        FileOffer('f1', 'x.bin', 10, 'application/octet-stream'),
      ]);
      await Future<void>.delayed(Duration.zero);
      c.respond(req, true);
      for (var i = 0; i < 20 && c.history.length < 3; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final h = c.history;
      expect(h, hasLength(3));
      expect(h[0].incoming, isTrue);
      expect(h[0].fileNames, ['x.bin']);
      expect(h[0].savedPath, '/tmp/landrop-test/x.bin');
      expect(h[0].state, 'done');
      expect(h[1].state, 'declined');
      expect(h[1].peerAlias, 'Work Laptop');
      expect(h[1].fileNames, ['b.pdf']);
      expect(h[2].state, 'done');
      expect(h[2].incoming, isFalse);
      expect(store.history.stored, hasLength(3));
      c.dispose();

      final c2 = AppController(
          core: FakeCore(simulateDelay: Duration.zero),
          store: store,
          initialSaveDir: '/tmp/landrop-test');
      await c2.init();
      expect(c2.history.map((e) => e.id), h.map((e) => e.id));
      c2.dispose();
    });

    test('keeps the last 100 entries', () async {
      final core = FakeCore(simulateDelay: Duration.zero);
      final store = MemorySettingsStore();
      final c = AppController(
          core: core, store: store, initialSaveDir: '/tmp/landrop-test');
      await c.init();
      for (var i = 0; i < HistoryStore.maxEntries + 5; i++) {
        await c.sendText(FakeCore.defaultPeers.first, 'n$i');
      }
      expect(c.history, hasLength(HistoryStore.maxEntries));
      expect(store.history.stored, hasLength(HistoryStore.maxEntries));
      c.dispose();
    });

    test('"Keep history" off deletes it and stops recording', () async {
      final core = FakeCore(simulateDelay: Duration.zero);
      final store = MemorySettingsStore();
      final c = AppController(
          core: core, store: store, initialSaveDir: '/tmp/landrop-test');
      await c.init();
      await c.sendText(FakeCore.defaultPeers.first, 'one');
      expect(c.history, hasLength(1));
      await c.setKeepHistory(false);
      expect(c.history, isEmpty);
      expect(store.history.stored, isNull);
      expect(store.history.clears, 1);
      expect(store.stored['keepHistory'], isFalse);
      await c.sendText(FakeCore.defaultPeers.first, 'two');
      expect(c.history, isEmpty);
      expect(store.history.stored, isNull);
      await c.setKeepHistory(true);
      await c.sendText(FakeCore.defaultPeers.first, 'three');
      expect(c.history, hasLength(1));
      await c.clearHistory();
      expect(c.history, isEmpty);
      c.dispose();
    });

    test('JSON round trip; broken entries are skipped', () {
      final at = DateTime(2026, 10, 20, 9, 30);
      final e = HistoryEntry.fromJson(_entry('x',
          at: at, savedPath: '/s/a.jpg', count: 3, files: ['a', 'b', 'c']))!;
      expect(e.at, at);
      expect(e.savedPath, '/s/a.jpg');
      expect(e.fileCount, 3);
      expect(HistoryEntry.fromJson({'id': 1}), isNull);
      expect(HistoryEntry.fromJson('x'), isNull);
      expect(
          HistoryEntry.fromJson({
            'id': 'a',
            'peer': 'p',
            'state': 'done',
            'at': 'not a date'
          }),
          isNull);
    });

    test('formatDay: Today, Yesterday, else a localized date', () {
      final now = DateTime(2026, 10, 22, 12);
      expect(formatDay(now, en, now: now), 'Today');
      expect(formatDay(DateTime(2026, 10, 21, 23, 59), en, now: now),
          'Yesterday');
      // Without date symbols loaded (no delegates), an ISO-like date.
      final old = formatDay(DateTime(2026, 10, 2), fa, now: now);
      expect(old, isNot(contains(RegExp('[0-9]'))));
      expect(old, contains(RegExp('[۰-۹]')));
    });
  });

  group('page', () {
    testWidgets('home ▸ History: groups, privacy note, details, Open',
        (t) async {
      final dir = await t.runAsync(
          () => Directory.systemTemp.createTemp('landrop_history'));
      addTearDown(() => dir!.deleteSync(recursive: true));
      final file = File('${dir!.path}/holiday.jpg')..writeAsStringSync('x');
      final now = DateTime.now();
      final opener = _Opener(canOpen: true);
      await _pump(t, opener: opener, history: [
        _entry('in-1', at: now, savedPath: file.path),
        _entry('out-2',
            at: now.subtract(const Duration(days: 1)),
            incoming: false,
            peer: 'Work Laptop',
            files: ['a.pdf', 'b.pdf'],
            count: 2,
            state: 'failed'),
        _entry('in-3',
            at: now.subtract(const Duration(days: 9)),
            savedPath: '${dir.path}/gone.txt'),
        _entry('in-4',
            at: now.subtract(const Duration(days: 9)), text: true),
      ]);
      await _tap(t, 'historyAction');
      expect(find.byKey(const Key('historyPage')), findsOneWidget);
      expect(find.byKey(const Key('historyPrivacy')), findsOneWidget);
      expect(find.text(en.historyPrivacy), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text(formatDay(now.subtract(const Duration(days: 9)), en)),
          findsOneWidget);
      expect(find.text('From Pixel 9'), findsNWidgets(3));
      expect(find.text('To Work Laptop'), findsOneWidget);
      expect(find.textContaining('a.pdf and 1 more'), findsOneWidget);
      expect(find.textContaining(en.textMessage), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(en.transferFailedPlain)), findsOneWidget);

      await _tap(t, 'history-in-1');
      expect(find.byKey(const Key('historyDetails')), findsOneWidget);
      expect(find.byKey(const Key('historySavedPath')), findsOneWidget);
      await _tap(t, 'historyOpen');
      expect(opener.opened, [file.path]);
      await _tap(t, 'historyReveal');
      expect(opener.revealed, [file.path]);
      await t.tapAt(const Offset(10, 10));
      await t.pumpAndSettle();

      // Files moved away: no Open, says so.
      await t.scrollUntilVisible(find.byKey(const Key('history-in-3')), 100,
          scrollable: find.byType(Scrollable).first);
      await _tap(t, 'history-in-3');
      expect(find.byKey(const Key('historyGone')), findsOneWidget);
      expect(find.byKey(const Key('historyOpen')), findsNothing);
    });

    testWidgets('phones: the path with Copy instead of Open', (t) async {
      final dir = await t.runAsync(
          () => Directory.systemTemp.createTemp('landrop_history'));
      addTearDown(() => dir!.deleteSync(recursive: true));
      final file = File('${dir!.path}/a.txt')..writeAsStringSync('x');
      await _pump(t,
          desktop: false,
          history: [_entry('in-1', at: DateTime.now(), savedPath: file.path)]);
      await _tap(t, 'historyAction');
      await _tap(t, 'history-in-1');
      expect(find.byKey(const Key('historyCopyPath')), findsOneWidget);
      expect(find.byKey(const Key('historyOpen')), findsNothing);
    });

    testWidgets('Clear history asks first', (t) async {
      final (c, store) = await _pump(t,
          history: [_entry('in-1', at: DateTime.now())]);
      await _tap(t, 'historyAction');
      await _tap(t, 'clearHistory');
      expect(find.byKey(const Key('confirmClearHistory')), findsOneWidget);
      await t.tap(find.text(en.commonCancel));
      await t.pumpAndSettle();
      expect(c.history, hasLength(1));
      await _tap(t, 'clearHistory');
      await _tap(t, 'confirmClearHistoryOk');
      expect(c.history, isEmpty);
      expect(store.history.stored, isNull);
      expect(find.byKey(const Key('historyEmpty')), findsOneWidget);
      expect(find.text(en.historyCleared), findsOneWidget);
    });

    testWidgets('Settings: History row and "Keep history" off', (t) async {
      final (c, store) = await _pump(t,
          history: [_entry('in-1', at: DateTime.now())]);
      await t.tap(find.byTooltip('Settings'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('keepHistorySwitch')));
      await t.pumpAndSettle();
      await _tap(t, 'keepHistorySwitch');
      expect(c.keepHistory, isFalse);
      expect(c.history, isEmpty);
      expect(store.history.stored, isNull);
      await _tap(t, 'historySettings');
      expect(find.text(en.historyOff), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.byKey(const Key('historyAction')), findsNothing);
    });
  });

  group('Persian', () {
    for (final width in [375.0, 1000.0]) {
      testWidgets('history page in fa at ${width.toInt()} px', (t) async {
        final now = DateTime.now();
        final old = now.subtract(const Duration(days: 9));
        await _pump(t, locale: 'fa', width: width, history: [
          _entry('in-1',
              at: now,
              peer: 'لپ‌تاپ سارا',
              files: ['گزارش-final-نسخه-نهایی-2024.pdf', 'b.jpg'],
              count: 2),
          _entry('out-2',
              at: old, incoming: false, state: 'cancelled', text: true),
        ]);
        await _tap(t, 'historyAction');
        expectRtl(t);
        expect(find.text(fa.historyTitle), findsOneWidget);
        expect(find.text(fa.historyToday), findsOneWidget);
        final day = formatDay(old, fa, now: now);
        expect(find.text(day), findsOneWidget);
        expect(day, contains(RegExp('[۰-۹]')), reason: 'Persian digits');
        expect(day, isNot(contains(RegExp('[0-9]'))));
        expect(find.text('History'), findsNothing);
        expect(find.textContaining('۳٫۱ مگابایت'), findsNWidgets(2));
        expect(t.takeException(), isNull);
        await _tap(t, 'history-in-1');
        expect(find.text(fa.historyWhen), findsOneWidget);
        expect(find.text(fa.transferDone), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  });
}
