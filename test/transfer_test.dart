// Transfer cards (docs/UX.md 3.8, step U6): states, speed and time left,
// cancel, Open / Show in folder behind the FileOpener seam.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/core/api.dart';
import 'package:landrop/ui/app.dart';
import 'package:landrop/ui/app_controller.dart';
import 'package:landrop/ui/fake_core.dart';
import 'package:landrop/ui/file_opener.dart';
import 'package:landrop/ui/widgets.dart';

/// Records what would be opened; [canOpen] picks desktop or phone UI.
class _FakeOpener implements FileOpener {
  _FakeOpener({this.canOpen = true, this.result = true});
  @override
  final bool canOpen;
  final bool result;
  final List<String> opened = [];
  final List<String> revealed = [];
  @override
  Future<bool> open(String path) async {
    opened.add(path);
    return result;
  }

  @override
  Future<bool> reveal(String path) async {
    revealed.add(path);
    return result;
  }

  @override
  Future<bool> openLink(String url) async => result;
}

final _t0 = DateTime(2026, 10, 22, 12);

TransferSession _session({
  bool incoming = false,
  String id = 's1',
  List<(String, int, int)> files = const [],
  bool? result,
  SendErrorCode? code,
}) {
  final s = TransferSession(
      sessionId: id,
      incoming: incoming,
      peerAlias: 'Pixel 9',
      peerFingerprint: 'aa11',
      savedTo: incoming ? '/home/me/Downloads' : null);
  for (final (name, sent, total) in files) {
    s.files[name] = FileTransfer(name, name, total)..sent = sent;
  }
  s.result = result;
  s.errorCode = code;
  return s;
}

Future<AppController> _pumpCard(WidgetTester t, TransferSession s,
    {FileOpener? opener}) async {
  final c = AppController(
      core: FakeCore(simulateDelay: Duration.zero),
      store: MemorySettingsStore(),
      initialSaveDir: '/home/me/Downloads',
      fileOpener: opener ?? _FakeOpener());
  addTearDown(c.dispose);
  t.view.physicalSize = const Size(400, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(AppScope(
      controller: c,
      child: MaterialApp(
          home: Scaffold(
              body: ListView(children: [TransferSessionCard(session: s)])))));
  return c;
}

String _text(WidgetTester t, String key) =>
    t.widget<Text>(find.byKey(Key(key))).data!;

IconData _icon(WidgetTester t, String sid) =>
    t.widget<Icon>(find.byKey(Key('stateIcon-$sid'))).icon!;

void main() {
  group('speed meter', () {
    test('smoothed over the window; null until half a second', () {
      final m = SpeedMeter();
      expect(m.bytesPerSecond, isNull);
      m.add(_t0, 0);
      m.add(_t0.add(const Duration(milliseconds: 200)), 100000);
      expect(m.bytesPerSecond, isNull, reason: 'too short to tell');
      m.add(_t0.add(const Duration(seconds: 1)), 1000000);
      expect(m.bytesPerSecond, closeTo(1000000, 1));
      m.add(_t0.add(const Duration(seconds: 2)), 3000000);
      expect(m.bytesPerSecond, closeTo(1500000, 1));
      // Older samples leave the 3 s window: only the last ~3 s count.
      m.add(_t0.add(const Duration(seconds: 5)), 3000000);
      m.add(_t0.add(const Duration(seconds: 6)), 3000000);
      expect(m.bytesPerSecond, closeTo(0, 1), reason: 'stalled');
      // A restart from zero (resume elsewhere) starts over.
      m.add(_t0.add(const Duration(seconds: 7)), 0);
      expect(m.bytesPerSecond, isNull);
    });

    test('time left from the smoothed speed', () {
      final s = _session(files: [('a.bin', 0, 10 << 20)]);
      s.meter.add(_t0, 0);
      s.files['a.bin']!.sent = 2 << 20;
      s.meter.add(_t0.add(const Duration(seconds: 2)), 2 << 20);
      expect(s.state, TransferState.running);
      expect(s.speed, closeTo(1 << 20, 1));
      expect(s.timeLeft, const Duration(seconds: 8));
      s.result = true;
      expect(s.speed, isNull);
      expect(s.timeLeft, isNull);
    });

    test('controller feeds the meter from progress events', () async {
      var now = _t0;
      final core = FakeCore(simulateDelay: Duration.zero);
      final c = AppController(
          core: core,
          store: MemorySettingsStore(),
          initialSaveDir: '/tmp/landrop-test',
          clock: () => now);
      await c.init();
      final req = core.simulateIncoming(autoProgress: false, files: const [
        FileOffer('f1', 'a.bin', 4000000, 'application/octet-stream'),
      ]);
      await Future<void>.delayed(Duration.zero);
      c.respond(req, true);
      core.emitProgress(TransferProgress(req.sessionId, 'f1', 0, 4000000));
      await Future<void>.delayed(Duration.zero);
      now = now.add(const Duration(seconds: 1));
      core.emitProgress(
          TransferProgress(req.sessionId, 'f1', 1000000, 4000000));
      await Future<void>.delayed(Duration.zero);
      final s = c.sessions.single;
      expect(s.speed, closeTo(1000000, 1));
      expect(s.timeLeft, const Duration(seconds: 3));
      c.dispose();
    });
  });

  group('card states', () {
    testWidgets('waiting: hourglass, waiting text, Cancel', (t) async {
      final s = _session(id: '');
      await _pumpCard(t, s);
      expect(_text(t, 'status-'), 'Waiting for Pixel 9 to accept…');
      expect(_icon(t, ''), Icons.hourglass_empty);
      expect(find.byKey(const Key('cancel-')), findsOneWidget);
    });

    testWidgets('running: percent, speed, time left, per-file and overall',
        (t) async {
      final s = _session(files: [('a.bin', 1 << 20, 4 << 20), ('b.bin', 0, 1 << 20)]);
      s.meter.add(_t0, 0);
      s.meter.add(_t0.add(const Duration(seconds: 2)), 1 << 20);
      await _pumpCard(t, s);
      expect(_text(t, 'title-s1'), 'To Pixel 9');
      expect(_text(t, 'status-s1'), '20% · 512 KB/s');
      expect(_text(t, 'timeLeft-s1'), '8 s left');
      expect(find.byKey(const Key('progress-s1')), findsOneWidget); // overall
      expect(find.byKey(const Key('progress-s1-a.bin')), findsOneWidget);
      expect(find.byKey(const Key('progress-s1-b.bin')), findsOneWidget);
      expect(find.byKey(const Key('cancel-s1')), findsOneWidget);
      expect(find.byKey(const Key('open-s1')), findsNothing);
    });

    testWidgets('Cancel calls the core and then shows "Cancelling…"',
        (t) async {
      final s = _session(files: [('a.bin', 1, 10)]);
      final c = await _pumpCard(t, s);
      await t.tap(find.byKey(const Key('cancel-s1')));
      await t.pump();
      expect((c.core as FakeCore).cancelCalls, ['s1']);
      expect(_text(t, 'status-s1'), 'Cancelling…');
      expect(find.byKey(const Key('cancel-s1')), findsNothing);
    });

    final finals = <(String, TransferSession, String, IconData)>[
      (
        'done (sent)',
        _session(files: [('a.bin', 10, 10)], result: true),
        'Done',
        Icons.check_circle
      ),
      (
        'declined',
        _session(result: false, code: SendErrorCode.declined),
        'Declined by Pixel 9',
        Icons.block
      ),
      (
        'cancelled',
        _session(
            files: [('a.bin', 3, 10)],
            result: false,
            code: SendErrorCode.cancelled),
        'Cancelled',
        Icons.cancel_outlined
      ),
      (
        'failed',
        _session(
            files: [('a.bin', 3, 10)],
            result: false,
            code: SendErrorCode.unreachable),
        'Failed: Could not reach the other device. Check that both are on '
            'the same network.',
        Icons.error_outline
      ),
    ];
    for (final (name, s, status, icon) in finals) {
      testWidgets('$name: own icon and text, no Cancel', (t) async {
        await _pumpCard(t, s);
        expect(_text(t, 'status-s1'), status);
        expect(_icon(t, 's1'), icon);
        expect(find.byKey(const Key('cancel-s1')), findsNothing);
        expect(_text(t, 'title-s1'),
            name.startsWith('done') ? 'Sent to Pixel 9' : 'To Pixel 9');
        // Sending side: nothing to open.
        expect(find.byKey(const Key('open-s1')), findsNothing);
      });
    }
    // Every final state looks different.
    test('final states have distinct icons and texts', () {
      expect({for (final f in finals) f.$3}, hasLength(finals.length));
      expect({for (final f in finals) f.$4}, hasLength(finals.length));
    });

    testWidgets('received: Open and Show in folder on desktops', (t) async {
      final s = _session(incoming: true, files: [('a.jpg', 10, 10)]);
      s.files['a.jpg']!
        ..done = true
        ..savedPath = '/home/me/Downloads/a (1).jpg';
      final opener = _FakeOpener();
      await _pumpCard(t, s, opener: opener);
      expect(_text(t, 'title-s1'), 'Received from Pixel 9');
      expect(_text(t, 'status-s1'), 'Done');
      await t.tap(find.byKey(const Key('open-s1')));
      await t.tap(find.byKey(const Key('reveal-s1')));
      await t.pump();
      expect(opener.opened, ['/home/me/Downloads/a (1).jpg']);
      expect(opener.revealed, ['/home/me/Downloads/a (1).jpg']);
      expect(find.byKey(const Key('copyPath-s1')), findsNothing);
    });

    testWidgets('received folder: Open opens the folder; failure explained',
        (t) async {
      final s = _session(
          incoming: true, files: [('x', 10, 10), ('y', 10, 10)]);
      s.files['x']!
        ..done = true
        ..savedPath = '/home/me/Downloads/Photos (1)/a.jpg';
      s.files['y']!
        ..done = true
        ..savedPath = '/home/me/Downloads/Photos (1)/2024/b.jpg';
      final opener = _FakeOpener(result: false);
      await _pumpCard(t, s, opener: opener);
      await t.tap(find.byKey(const Key('open-s1')));
      await t.pumpAndSettle();
      expect(opener.opened, ['/home/me/Downloads/Photos (1)']);
      expect(
          find.text("Couldn't open it. The files are in "
              '/home/me/Downloads/Photos (1).'),
          findsOneWidget);
    });

    testWidgets('received on a phone: full path and Copy, no Open',
        (t) async {
      String? copied;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(() => t.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      final s = _session(incoming: true, files: [('a.jpg', 10, 10)]);
      s.files['a.jpg']!
        ..done = true
        ..savedPath = '/storage/emulated/0/Download/LanDrop/a.jpg';
      await _pumpCard(t, s, opener: _FakeOpener(canOpen: false));
      expect(find.byKey(const Key('open-s1')), findsNothing);
      expect(find.byKey(const Key('reveal-s1')), findsNothing);
      expect(
          t.widget<SelectableText>(find.byKey(const Key('savedTo-s1'))).data,
          'Saved to /storage/emulated/0/Download/LanDrop/a.jpg');
      await t.tap(find.byKey(const Key('copyPath-s1')));
      await t.pumpAndSettle();
      expect(copied, '/storage/emulated/0/Download/LanDrop/a.jpg');
      expect(find.text('Path copied'), findsOneWidget);
    });

    testWidgets('received but cancelled by the sender', (t) async {
      final s = _session(incoming: true, files: [('a.jpg', 3, 10)]);
      s.files['a.jpg']!
        ..done = true
        ..error = 'cancelled by sender'
        ..errorCode = SendErrorCode.cancelled;
      await _pumpCard(t, s);
      expect(_text(t, 'status-s1'), 'Cancelled');
      expect(_text(t, 'title-s1'), 'From Pixel 9');
      expect(find.byKey(const Key('open-s1')), findsNothing);
    });

    testWidgets('received but failed (timeout): localized reason', (t) async {
      final s = _session(incoming: true, files: [('a.jpg', 3, 10)]);
      s.files['a.jpg']!
        ..done = true
        ..error = 'timed out'
        ..errorCode = SendErrorCode.timeout;
      await _pumpCard(t, s);
      expect(_text(t, 'status-s1'),
          'Failed: The other device stopped responding.');
      expect(_icon(t, 's1'), Icons.error_outline);
    });
  });

  group('cancel through the app', () {
    Future<FakeCore> pump(WidgetTester t,
        {Future<List<String>> Function()? pick}) async {
      // Tall, so the cards are not under the Send button.
      t.view.physicalSize = const Size(400, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final core = FakeCore(simulateDelay: const Duration(milliseconds: 50));
      await t.pumpWidget(LanDropApp(
        core: core,
        store: MemorySettingsStore(),
        initialSaveDir: '/tmp/landrop-test',
        initialAlias: 'Tester',
        pickFiles: pick ?? () async => <String>[],
        pickFolder: () async => null,
        fileOpener: _FakeOpener(),
      ));
      await t.pumpAndSettle();
      return core;
    }

    testWidgets('sender cancels: card and snackbar say cancelled',
        (t) async {
      final core = await pump(t, pick: () async => ['/x/a.txt', '/x/b.txt']);
      await t.tap(find.byKey(const Key('send-aa11')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      expect(find.byKey(const Key('cancel-out-1')), findsOneWidget);
      await t.tap(find.byKey(const Key('cancel-out-1')));
      await t.pumpAndSettle();
      expect(core.cancelCalls, ['out-1']);
      expect(_text(t, 'status-out-1'), 'Cancelled');
      expect(find.text('The transfer was cancelled.'), findsOneWidget);
    });

    testWidgets('receiver cancels an accepted transfer', (t) async {
      final core = await pump(t);
      final req = core.simulateIncoming(autoProgress: false);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('incomingAccept')));
      await t.pumpAndSettle();
      core.emitProgress(
          TransferProgress(req.sessionId, 'f1', 1000, 2400000));
      await t.pump();
      await t.ensureVisible(find.byKey(Key('cancel-${req.sessionId}')));
      await t.tap(find.byKey(Key('cancel-${req.sessionId}')));
      await t.pumpAndSettle();
      expect(core.cancelCalls, [req.sessionId]);
      expect(_text(t, 'status-${req.sessionId}'), 'Cancelled');
      expect(_icon(t, req.sessionId), Icons.cancel_outlined);
    });

    testWidgets('history keeps the newest finished transfers; Clear finished',
        (t) async {
      final core = await pump(t, pick: () async => ['/x/a.txt']);
      final c = AppScope.read(t.element(find.byType(Scaffold).first));
      core.failSends['aa11'] = SendErrorCode.declined;
      for (var i = 0; i < AppController.maxHistory + 3; i++) {
        await t.runAsync(() => c.send(FakeCore.defaultPeers.first, ['/x/a']));
      }
      await t.pumpAndSettle();
      expect(c.sessions, hasLength(AppController.maxHistory));
      await t.scrollUntilVisible(find.byKey(const Key('clearFinished')), 200,
          scrollable: find.byType(Scrollable).first);
      await t.tap(find.byKey(const Key('clearFinished')));
      await t.pumpAndSettle();
      expect(c.sessions, isEmpty);
    });
  });

  group('FileOpener seam', () {
    List<String> calls = [];
    ProcessRunner runner(int exitCode) => (exe, args) async {
          calls.add([exe, ...args].join(' | '));
          return ProcessResult(0, exitCode, '', '');
        };
    setUp(() => calls = []);

    test('macOS: open and open -R', () async {
      final o = SystemFileOpener(os: 'macos', run: runner(0));
      expect(o.canOpen, isTrue);
      expect(await o.open('/Users/me/Downloads/a b.txt'), isTrue);
      expect(await o.reveal('/Users/me/Downloads/a b.txt'), isTrue);
      expect(calls, [
        'open | /Users/me/Downloads/a b.txt',
        'open | -R | /Users/me/Downloads/a b.txt',
      ]);
    });

    test('Windows: explorer and explorer /select, (exit code ignored)',
        () async {
      final o = SystemFileOpener(os: 'windows', run: runner(1));
      expect(await o.open(r'C:\Users\me\Downloads\a.txt'), isTrue);
      expect(await o.reveal(r'C:\Users\me\Downloads\a.txt'), isTrue);
      expect(calls, [
        r'explorer | C:\Users\me\Downloads\a.txt',
        r'explorer | /select, | C:\Users\me\Downloads\a.txt',
      ]);
    });

    test('Linux: xdg-open the file, or its folder to show it', () async {
      final o = SystemFileOpener(os: 'linux', run: runner(0));
      await o.open('/home/me/a.txt');
      await o.reveal('/home/me/a.txt');
      expect(calls, [
        'xdg-open | /home/me/a.txt',
        'xdg-open | /home/me',
      ]);
      // A failing command is reported.
      final failing = SystemFileOpener(os: 'linux', run: runner(4));
      expect(await failing.open('/home/me/a.txt'), isFalse);
    });

    test('phones are not supported; relative paths are refused', () async {
      for (final os in ['android', 'ios']) {
        final o = SystemFileOpener(os: os, run: runner(0));
        expect(o.canOpen, isFalse);
        expect(await o.open('/storage/a.txt'), isFalse);
      }
      final mac = SystemFileOpener(os: 'macos', run: runner(0));
      expect(await mac.open('-a Terminal'), isFalse);
      expect(calls, isEmpty);
      // A runner that throws (program missing) is a failure, not a crash.
      final broken = SystemFileOpener(
          os: 'linux', run: (_, _) async => throw const ProcessException('x', []));
      expect(await broken.open('/home/me/a.txt'), isFalse);
    });

    test('commonDirectory', () {
      expect(commonDirectory(['/a/b/c.txt', '/a/b/d/e.txt']), '/a/b');
      expect(commonDirectory([r'C:\x\y.txt', r'C:\x\z.txt']), r'C:\x');
      expect(commonDirectory(['/a.txt', '/b.txt']), isNull);
    });
  });
}
