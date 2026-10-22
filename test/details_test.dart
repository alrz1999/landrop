// "Details" on failed / cancelled / declined transfer cards, the device
// picker order and trusted badge, and the "First time" badge from the
// recent devices (docs/UX.md 3.3, 3.7, 3.8).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/core/api.dart';
import 'package:landrop/l10n/app_localizations.dart';
import 'package:landrop/ui/app_controller.dart';
import 'package:landrop/ui/dialogs.dart';
import 'package:landrop/ui/fake_core.dart';
import 'package:landrop/ui/widgets.dart';

final en = lookupAppLocalizations(const Locale('en'));
final fa = lookupAppLocalizations(const Locale('fa'));

const _pixel = DeviceInfo(
    alias: 'Pixel 9',
    deviceType: 'mobile',
    fingerprint: 'aa11',
    ip: '192.168.1.21');

TransferSession _failed(
    {SendErrorCode code = SendErrorCode.unreachable, bool incoming = false}) {
  final s = TransferSession(
    sessionId: 's1',
    incoming: incoming,
    peerAlias: 'Pixel 9',
    peerFingerprint: 'aa11',
    peer: incoming ? null : _pixel,
    paths: incoming ? const [] : const ['/nope/a.txt'],
    senderAddress: incoming ? '192.168.1.21:53317' : null,
  );
  s.files['f1'] = FileTransfer('f1', 'a.txt', 10);
  if (incoming) {
    s.files['f1']!
      ..error = 'cancelled'
      ..errorCode = code;
  } else {
    s.result = false;
    s.errorCode = code;
    s.error = 'SocketException: No route to host';
  }
  return s;
}

Future<AppController> _pumpCard(WidgetTester t, TransferSession s,
    {Locale locale = const Locale('en'), double width = 400}) async {
  final c = AppController(
      core: FakeCore(simulateDelay: Duration.zero),
      store: MemorySettingsStore(),
      initialSaveDir: '/home/me/Downloads');
  addTearDown(c.dispose);
  t.view.physicalSize = Size(width, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(AppScope(
      controller: c,
      child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
              body: ListView(children: [TransferSessionCard(session: s)])))));
  await t.pumpAndSettle();
  return c;
}

Map<String, dynamic> _recent(String fp, String alias,
        {String? lastUsed, String firstSeen = '2026-10-01T10:00:00.000Z'}) =>
    {
      'fingerprint': fp,
      'alias': alias,
      'deviceType': 'desktop',
      'lastSeen': '2026-10-02T10:00:00.000Z',
      'firstSeen': firstSeen,
      'lastUsed': ?lastUsed,
    };

void main() {
  group('transfer details', () {
    testWidgets('failed send: reason, code, address, time, English report',
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
      await _pumpCard(t, _failed());
      await t.tap(find.byKey(const Key('failDetails-s1')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('transferDetails-s1')), findsOneWidget);
      expect(
          t.widget<Text>(find.byKey(const Key('detailsReason-s1'))).data,
          en.transferFailed(en.sendErrorUnreachable));
      expect(find.text('unreachable'), findsOneWidget);
      expect(find.text('192.168.1.21:53317'), findsOneWidget);
      expect(find.byKey(const Key('detailsWhen-s1')), findsOneWidget);
      await t.tap(find.byKey(const Key('copyTransferReport-s1')));
      await t.pumpAndSettle();
      expect(copied, contains('LanDrop transfer report'));
      expect(copied, contains('Direction: sent to Pixel 9'));
      expect(copied, contains('Address: 192.168.1.21:53317'));
      expect(copied, contains('Result: failed'));
      expect(copied, contains('Error code: unreachable'));
      expect(copied, contains('Error: SocketException: No route to host'));
      expect(find.text(en.diagReportCopied), findsOneWidget);
    });

    testWidgets('declined and cancelled have Details; done and running not',
        (t) async {
      await _pumpCard(t, _failed(code: SendErrorCode.declined));
      expect(find.byKey(const Key('failDetails-s1')), findsOneWidget);
      await t.tap(find.byKey(const Key('failDetails-s1')));
      await t.pumpAndSettle();
      expect(find.text('declined'), findsOneWidget);
      Navigator.of(t.element(find.byKey(const Key('transferDetails-s1'))))
          .pop();
      await t.pumpAndSettle();

      await _pumpCard(t,
          _failed(code: SendErrorCode.cancelled, incoming: true));
      expect(find.byKey(const Key('failDetails-s1')), findsOneWidget);
      await t.tap(find.byKey(const Key('failDetails-s1')));
      await t.pumpAndSettle();
      expect(find.text('cancelled'), findsOneWidget);
      expect(find.text('192.168.1.21:53317'), findsOneWidget);
      Navigator.of(t.element(find.byKey(const Key('transferDetails-s1'))))
          .pop();
      await t.pumpAndSettle();

      final done = _failed()
        ..result = true
        ..errorCode = null;
      await _pumpCard(t, done);
      expect(find.byKey(const Key('failDetails-s1')), findsNothing);
    });

    test('the report says when the address is unknown', () {
      final s = TransferSession(
          sessionId: 'x', incoming: true, peerAlias: 'Browser');
      s.files['f'] = FileTransfer('f', 'b.bin', 5)
        ..error = 'stalled'
        ..errorCode = SendErrorCode.timeout;
      final r = s.report();
      expect(r, contains('Address: unknown'));
      expect(r, contains('Fingerprint: not verified'));
      expect(r, contains('Error code: timeout'));
      expect(r, contains('b.bin: timeout (stalled)'));
    });

    for (final width in [375.0, 1000.0]) {
      testWidgets('fa at ${width.toInt()} px: Persian sheet, LTR values',
          (t) async {
        await _pumpCard(t, _failed(),
            locale: const Locale('fa'), width: width);
        expect(find.text(fa.transferDetails), findsOneWidget);
        await t.tap(find.byKey(const Key('failDetails-s1')));
        await t.pumpAndSettle();
        final sheet = find.byKey(const Key('transferDetails-s1'));
        expect(Directionality.of(t.element(sheet)), TextDirection.rtl);
        expect(find.text(fa.transferDetailsTitle), findsOneWidget);
        expect(find.text(fa.diagCopyReport), findsOneWidget);
        expect(find.text(en.transferDetailsTitle), findsNothing);
        final code = find.byKey(const Key('detailsCode-s1'));
        expect(
            Directionality.of(t.element(find.descendant(
                of: code, matching: find.text('unreachable')))),
            TextDirection.ltr);
      });
    }
  });

  group('picker and recent devices', () {
    Future<AppController> controller(Map<String, dynamic> stored,
        {List<DeviceInfo>? peers}) async {
      final core = FakeCore(simulateDelay: Duration.zero, initialPeers: peers);
      final c = AppController(
          core: core,
          store: MemorySettingsStore(stored),
          initialSaveDir: '/tmp/landrop-test');
      await c.init();
      return c;
    }

    const a = DeviceInfo(
        alias: 'Alpha', deviceType: 'desktop', fingerprint: 'f1', ip: '10.0.0.1');
    const b = DeviceInfo(
        alias: 'Beta', deviceType: 'mobile', fingerprint: 'f2', ip: '10.0.0.2');
    const d = DeviceInfo(
        alias: 'Delta', deviceType: 'desktop', fingerprint: 'f3', ip: '10.0.0.3');

    test('used most recently first, then trusted, then as found', () async {
      final c = await controller({
        'recentDevices': [
          _recent('f3', 'Delta', lastUsed: '2026-10-05T10:00:00.000Z'),
          _recent('f1', 'Alpha', lastUsed: '2026-10-01T10:00:00.000Z'),
        ],
        'trustedDevices': [
          {
            'fingerprint': 'f2',
            'alias': 'Beta',
            'trustedAt': '2026-10-01T10:00:00.000Z',
            'autoAccept': false,
          }
        ],
      });
      expect(c.pickerOrder([a, b, d]).map((p) => p.alias),
          ['Delta', 'Alpha', 'Beta']);
      const e = DeviceInfo(
          alias: 'Echo', deviceType: 'desktop', fingerprint: 'f4', ip: '10.0.0.4');
      expect(c.pickerOrder([e, b]).map((p) => p.alias), ['Beta', 'Echo']);
      c.dispose();
    });

    testWidgets('the picker shows that order and the trusted badge',
        (t) async {
      final c = await controller({
        'recentDevices': [
          _recent('f3', 'Delta', lastUsed: '2026-10-05T10:00:00.000Z'),
        ],
        'trustedDevices': [
          {
            'fingerprint': 'f2',
            'alias': 'Beta',
            'trustedAt': '2026-10-01T10:00:00.000Z',
            'autoAccept': false,
          }
        ],
      });
      addTearDown(c.dispose);
      for (final (locale, width) in [
        (const Locale('en'), 1000.0),
        (const Locale('fa'), 375.0),
        (const Locale('fa'), 1000.0),
      ]) {
        t.view.physicalSize = Size(width, 900);
        t.view.devicePixelRatio = 1;
        await t.pumpWidget(AppScope(
            controller: c,
            child: MaterialApp(
                locale: locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Builder(
                    builder: (ctx) => Scaffold(
                        body: TextButton(
                            onPressed: () =>
                                showPeerPicker(ctx, [a, b, d], title: 'To…'),
                            child: const Text('open')))))));
        await t.tap(find.text('open'));
        await t.pumpAndSettle();
        final rows = find.byWidgetPredicate((w) =>
            w is SimpleDialogOption &&
            (w.key as ValueKey<String>?)?.value.startsWith('pick-') == true);
        expect(
            t.widgetList(rows).map((w) => (w.key as ValueKey<String>).value),
            ['pick-f3', 'pick-f2', 'pick-f1']);
        expect(find.byKey(const Key('pickerTrusted-f2')), findsOneWidget);
        expect(find.byKey(const Key('pickerTrusted-f1')), findsNothing);
        if (locale.languageCode == 'fa') {
          expect(
              Directionality.of(
                  t.element(find.byKey(const Key('peerPicker')))),
              TextDirection.rtl);
        }
        await t.tapAt(const Offset(5, 5));
        await t.pumpAndSettle();
      }
      t.view.reset();
    });

    test('"First time" only for devices not in the recent list', () async {
      IncomingRequest req(DeviceInfo from) => IncomingRequest(
          'r-${from.fingerprint}', from,
          [const FileOffer('f', 'a.txt', 1, 'text/plain')],
          verified: true);
      final c = await controller({
        // Seen in an earlier run (firstSeen before this start).
        'recentDevices': [_recent('f1', 'Alpha')],
      }, peers: [d]);
      // Alpha: seen before, never accepted.
      expect(c.trustOf(req(a)), SenderTrust.known);
      // Delta is nearby now, but was first seen in this run.
      await Future<void>.delayed(Duration.zero);
      expect(c.seenBefore('f3'), isFalse);
      expect(c.trustOf(req(d)), SenderTrust.firstTime);
      // Beta: never seen.
      expect(c.trustOf(req(b)), SenderTrust.firstTime);
      // Accepting remembers the device (recent "used", and trusted).
      c.respond(req(b), true);
      expect(c.seenBefore('f2'), isTrue);
      expect(c.trustOf(req(b)), SenderTrust.trusted);
      // Sending to a device also counts as "used".
      await c.sendWithResult(d, const []);
      expect(c.seenBefore('f3'), isTrue);
      expect(c.trustOf(req(d)), SenderTrust.known);
      c.dispose();
    });

    testWidgets('the incoming dialog shows "Seen before" and offers Always '
        'accept', (t) async {
      final req = IncomingRequest(
          'r1', a, [const FileOffer('f', 'a.txt', 1, 'text/plain')],
          verified: true);
      for (final (locale, width) in [
        (const Locale('en'), 1000.0),
        (const Locale('fa'), 375.0),
      ]) {
        t.view.physicalSize = Size(width, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
                builder: (ctx) => Scaffold(
                    body: TextButton(
                        onPressed: () => showIncomingDecision(ctx, req,
                            trust: SenderTrust.known),
                        child: const Text('open'))))));
        await t.tap(find.text('open'));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('incomingBadge-known')), findsOneWidget);
        final l = locale.languageCode == 'fa' ? fa : en;
        expect(find.text(l.incomingKnown), findsOneWidget);
        expect(find.byKey(const Key('alwaysAccept')), findsOneWidget);
        await t.tap(find.byKey(const Key('incomingDecline')));
        await t.pumpAndSettle();
      }
    });
  });
}
