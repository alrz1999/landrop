import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/core/api.dart';
import 'package:landrop/ui/app.dart';
import 'package:landrop/ui/app_controller.dart';
import 'package:landrop/ui/fake_core.dart';
import 'package:landrop/ui/settings_page.dart';
import 'package:landrop/ui/widgets.dart';

Future<FakeCore> pumpApp(WidgetTester tester,
    {Size size = const Size(400, 900),
    Future<List<String>> Function()? pick,
    Future<String?> Function()? pickFolder,
    FakeCore? core}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  core ??= FakeCore(simulateDelay: const Duration(milliseconds: 10));
  await tester.pumpWidget(LanDropApp(
    core: core,
    store: MemorySettingsStore(),
    initialSaveDir: '/tmp/landrop-test',
    initialAlias: 'Tester',
    pickFiles: pick ?? () async => <String>[],
    pickFolder: pickFolder ?? () async => null,
  ));
  await tester.pumpAndSettle();
  return core;
}

/// Settings ▸ Advanced (U3), where the technical rows live now.
Future<void> openAdvanced(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Settings'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('advancedSettings')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('advancedSettings')));
  await tester.pumpAndSettle();
}

/// Scrolls the current page until the widget with [key] is built and
/// visible (long lists build their rows lazily).
Future<void> showKey(WidgetTester tester, Key key) async {
  final f = find.byKey(key);
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(f, 200,
        scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('peer list renders with own address', (tester) async {
    await pumpApp(tester);
    expect(find.text('Pixel 9'), findsOneWidget);
    expect(find.text('Work Laptop'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Send'), findsNWidgets(2));
    expect(find.text('Tester'), findsOneWidget);
    expect(find.text('192.168.1.10 · port 53317'), findsOneWidget);
  });

  testWidgets('empty state shows help text', (tester) async {
    final core = await pumpApp(tester);
    core.setPeers(const []);
    await tester.pumpAndSettle();
    // Short empty state (UX.md 7, quick win 3): technical causes such as
    // "AP isolation" are explained by the connection check only.
    expect(find.text('No devices found yet'), findsOneWidget);
    expect(
        find.text('Make sure LanDrop is open on the other device and both '
            'are on the same Wi-Fi.'),
        findsOneWidget);
    expect(find.textContaining('AP isolation'), findsNothing);
    // "Why can't I see my device?" is the only filled button.
    expect(find.byType(FilledButton), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const Key('whyNoDevices')),
            matching: find.text("Why can't I see my device?")),
        findsOneWidget);
  });

  testWidgets('empty state opens the helper; dialog renders findings',
      (tester) async {
    final core = await pumpApp(tester);
    expect(find.byKey(const Key('whyNoDevices')), findsNothing);
    core.setPeers(const []);
    await tester.pumpAndSettle();
    expect(find.text("Why can't I see my device?"), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('whyNoDevices')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('whyNoDevices')));
    await tester.pumpAndSettle();
    // The connection helper (UX.md 3.4) runs the check and shows one result.
    expect(find.byKey(const Key('connectHelper')), findsOneWidget);
    expect(core.diagnosisCalls, [(null, null)]);
    expect(find.byKey(const Key('finding-announce-blocked')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // The full report is the dialog in Settings ▸ Advanced.
    await openAdvanced(tester);
    await showKey(tester, const Key('diagnoseSettings'));
    await tester.tap(find.byKey(const Key('diagnoseSettings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('diagnosisDialog')), findsOneWidget);
    expect(core.diagnosisCalls, hasLength(2));
    expect(find.text('Devices only show up after a scan'), findsOneWidget);
    expect(find.byKey(const Key('finding-announce-blocked')), findsOneWidget);
    expect(find.text('What to do: Use "Rescan network" or "Add by IP".'),
        findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    // The "Your network" summary is only in the copied report (U5).
    expect(find.text('Your network'), findsNothing);
    expect(find.byKey(const Key('finding-network')), findsNothing);

    await tester.tap(find.byKey(const Key('runAgain')));
    await tester.pumpAndSettle();
    expect(core.diagnosisCalls, hasLength(3));
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('diagnosisDialog')), findsNothing);
  });

  testWidgets('copy report puts every finding on the clipboard',
      (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    final core = FakeCore(simulateDelay: const Duration(milliseconds: 10))
      ..diagnosisFindings = const [
        Finding(Severity.problem, 'probe-refused',
            'The device is there, but LanDrop is not answering',
            'LanDrop is probably closed there.',
            fix: 'Open LanDrop on the other device.',
            technical: 'TCP connect to 192.168.1.20:53317 refused'),
        Finding(Severity.info, 'network', 'Your network', 'For reference.',
            technical: 'en0: 192.168.1.10'),
      ];
    await pumpApp(tester, core: core);
    await openAdvanced(tester);
    await showKey(tester, const Key('diagnoseSettings'));
    await tester.tap(find.byKey(const Key('diagnoseSettings')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    // Technical text is collapsed under "Details".
    expect(find.textContaining('TCP connect to'), findsNothing);
    await tester.tap(find.byKey(const Key('findingDetails-probe-refused')));
    await tester.pumpAndSettle();
    expect(find.text('TCP connect to 192.168.1.20:53317 refused'),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('copyReport')));
    await tester.pumpAndSettle();
    expect(copied, startsWith('LanDrop connection report'));
    expect(copied, contains('[PROBLEM] The device is there, but LanDrop is '
        'not answering'));
    expect(copied, contains('Fix: Open LanDrop on the other device.'));
    expect(copied, contains('Details: TCP connect to 192.168.1.20:53317'));
    expect(copied, contains('[INFO] Your network'));
    expect(copied, contains('en0: 192.168.1.10'));
    expect(find.text('Report copied'), findsOneWidget);
  });

  testWidgets('failed add by IP offers "Diagnose this IP"', (tester) async {
    final core = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('addByIp')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '10.0.0.8:5000');
    core.addPeerFails = true;
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('addFailedDialog')), findsOneWidget);
    expect(find.text('No LanDrop device answered at 10.0.0.8:5000.'),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('diagnoseIp')));
    await tester.pumpAndSettle();
    expect(core.diagnosisCalls, [('10.0.0.8', 5000)]);
    expect(find.text('Checking 10.0.0.8:5000'), findsOneWidget);
    expect(find.text('No answer from that address'), findsOneWidget);
  });

  testWidgets('wide layout renders peers and the self card, no QR',
      (tester) async {
    await pumpApp(tester, size: const Size(1280, 800));
    expect(find.text('Pixel 9'), findsOneWidget);
    expect(find.byKey(const Key('selfAddress')), findsOneWidget);
    // The address QR moved to Settings ▸ Advanced (U1).
    expect(find.byKey(const Key('selfUrl')), findsNothing);
    expect(find.text('https://192.168.1.10:53317'), findsNothing);
    expect(find.text('Share link'), findsOneWidget); // labelled app bar action
  });

  testWidgets('incoming dialog accepts and progress renders', (tester) async {
    final core = await pumpApp(tester);
    final req = core.simulateIncoming(autoProgress: false);
    await tester.pumpAndSettle();

    expect(find.text('Pixel 9 wants to send you 2 files'), findsOneWidget);
    expect(find.text('holiday.jpg'), findsOneWidget);
    expect(find.text('notes.pdf'), findsOneWidget);

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(req.decision.isCompleted, isTrue);
    expect(await req.decision.future, isTrue);

    core.emitProgress(
        TransferProgress(req.sessionId, 'f1', 1200000, 2400000));
    await tester.pump();
    await tester.pump();
    final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(Key('progress-${req.sessionId}-f1')));
    expect(bar.value, closeTo(0.5, 0.001));
    expect(find.text('From Pixel 9'), findsOneWidget);
    expect(find.textContaining('Saved to /tmp/landrop-test'), findsOneWidget);
    await tester.pumpAndSettle(); // let snackbar finish
  });

  testWidgets('incoming dialog decline completes false', (tester) async {
    final core = await pumpApp(tester);
    final req = core.simulateIncoming(autoProgress: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    expect(await req.decision.future, isFalse);
    expect(find.text('From Pixel 9'), findsNothing);
  });

  testWidgets('send flow shows progress and success snackbar', (tester) async {
    final core =
        await pumpApp(tester, pick: () async => ['/nonexistent/a.txt']);
    await tester.tap(find.byKey(const Key('send-aa11')));
    await tester.pump();
    expect(find.text('To Pixel 9'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 15));
    expect(find.byType(LinearProgressIndicator), findsWidgets);
    await tester.pumpAndSettle();
    expect(core.sent.single.$1.alias, 'Pixel 9');
    expect(find.text('Sent to Pixel 9.'), findsOneWidget);
  });

  testWidgets('add by IP adds a peer', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('addByIp')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '10.0.0.7');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Device at 10.0.0.7'), findsOneWidget);
  });

  testWidgets('discovery error shows a dismissible banner', (tester) async {
    final core = FakeCore(simulateDelay: const Duration(milliseconds: 10))
      ..discoveryError = 'Failed to create datagram socket';
    await pumpApp(tester, core: core);
    expect(find.byKey(const Key('discoveryBanner')), findsOneWidget);
    // One plain line; the raw error is left to the connection check.
    expect(find.text('Automatic search is off on this device.'),
        findsOneWidget);
    expect(find.textContaining('datagram'), findsNothing);
    expect(find.byKey(const Key('discoveryHelp')), findsOneWidget);
    await tester.tap(find.byKey(const Key('dismissDiscoveryBanner')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('discoveryBanner')), findsNothing);
  });

  testWidgets('no discovery banner when discovery works', (tester) async {
    await pumpApp(tester);
    expect(find.byKey(const Key('discoveryBanner')), findsNothing);
  });

  testWidgets('incoming dialog summarises folders', (tester) async {
    final core = await pumpApp(tester);
    final req = core.simulateIncoming(autoProgress: false, files: [
      for (var i = 0; i < 124; i++)
        FileOffer('p$i', 'Photos/2024/img$i.jpg', 10 * 1024 * 1024, 'image/jpeg'),
      const FileOffer('d1', 'Docs/a.pdf', 1024, 'application/pdf'),
      const FileOffer('n1', 'notes.txt', 2048, 'text/plain'),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Pixel 9 wants to send you 126 files'), findsOneWidget);
    expect(find.text('Photos/'), findsOneWidget);
    expect(find.text('124 files'), findsOneWidget);
    expect(find.text('1.2 GB'), findsOneWidget);
    expect(find.text('Docs/'), findsOneWidget);
    expect(find.text('1 file'), findsOneWidget);
    expect(find.text('notes.txt'), findsOneWidget);
    expect(find.textContaining('img1.jpg'), findsNothing);

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(await req.decision.future, isTrue);
    // Many files: one summary bar instead of 126 rows.
    expect(find.byKey(Key('progress-${req.sessionId}')), findsOneWidget);
    expect(find.text('0 of 126 files'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('send folder flow sends the picked directory', (tester) async {
    final core = await pumpApp(tester,
        pickFolder: () async => '/nonexistent/Holiday');
    await tester.tap(find.byKey(const Key('sendFab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sendFolder')));
    await tester.pumpAndSettle();
    expect(find.text('Send folder "Holiday" to…'), findsOneWidget);
    await tester.tap(find.descendant(
        of: find.byType(SimpleDialog), matching: find.text('Work Laptop')));
    await tester.pumpAndSettle();
    expect(core.sent.single.$1.alias, 'Work Laptop');
    expect(core.sent.single.$2, ['/nonexistent/Holiday']);
    expect(find.text('Sent to Work Laptop.'), findsOneWidget);
  });

  testWidgets('concurrent sends attribute progress by session id',
      (tester) async {
    final core = FakeCore(simulateDelay: const Duration(milliseconds: 10));
    // Pixel 9 accepts much later, so Work Laptop's session starts first.
    core.acceptDelays['aa11'] = const Duration(milliseconds: 200);
    final c = AppController(
        core: core,
        store: MemorySettingsStore(),
        initialSaveDir: '/tmp/landrop-test');
    await tester.runAsync(c.init);
    final pixel = FakeCore.defaultPeers[0];
    final laptop = FakeCore.defaultPeers[1];
    late List<bool> results;
    await tester.runAsync(() async {
      results = await Future.wait([
        c.send(pixel, ['/x/for-pixel.txt']),
        c.send(laptop, ['/x/for-laptop-1.txt', '/x/for-laptop-2.txt']),
      ]);
    });
    expect(results, [true, true]);
    final toPixel = c.sessions.singleWhere((s) => s.peerAlias == 'Pixel 9');
    final toLaptop =
        c.sessions.singleWhere((s) => s.peerAlias == 'Work Laptop');
    expect(toPixel.sessionId, isNot(toLaptop.sessionId));
    expect(toPixel.files.values.map((f) => f.name), ['for-pixel.txt']);
    expect(toLaptop.files.values.map((f) => f.name),
        ['for-laptop-1.txt', 'for-laptop-2.txt']);
    expect(toPixel.files.values.every((f) => f.done), isTrue);
    expect(toLaptop.files.values.every((f) => f.done), isTrue);
    c.dispose();
  });

  // ------------------------------------------------------ browser access

  Future<void> scrollTo(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(f, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
  }

  testWidgets('pairing dialog shows the code; approve completes true',
      (tester) async {
    final core = await pumpApp(tester);
    final r = core.simulatePairing();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pairingDialog')), findsOneWidget);
    expect(find.text('Allow a browser to send you files?'), findsOneWidget);
    expect(find.text('4821'), findsOneWidget);
    expect(find.text('Safari on iPhone · 192.168.1.77'), findsOneWidget);
    await tester.tap(find.byKey(const Key('approvePairing')));
    await tester.pumpAndSettle();
    expect(await r.decision.future, isTrue);
    expect(find.byKey(const Key('pairingDialog')), findsNothing);
  });

  testWidgets('pairing dialog decline completes false', (tester) async {
    final core = await pumpApp(tester);
    final r = core.simulatePairing(code: '0007');
    await tester.pumpAndSettle();
    expect(find.text('0007'), findsOneWidget);
    await tester.tap(find.byKey(const Key('declinePairing')));
    await tester.pumpAndSettle();
    expect(await r.decision.future, isFalse);
    expect(find.byKey(const Key('pairingDialog')), findsNothing);
  });

  testWidgets('pairings queue behind incoming requests; timeout closes',
      (tester) async {
    final core = await pumpApp(tester);
    final req = core.simulateIncoming(autoProgress: false);
    final p1 = core.simulatePairing(code: '1111');
    final p2 = core.simulatePairing(code: '2222');
    await tester.pumpAndSettle();
    expect(find.text('Pixel 9 wants to send you 2 files'), findsOneWidget);
    expect(find.byKey(const Key('pairingDialog')), findsNothing);
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(await req.decision.future, isTrue);
    expect(find.text('1111'), findsOneWidget);
    // The core times the first pairing out while it is on screen.
    p1.decision.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('1111'), findsNothing);
    expect(find.text('2222'), findsOneWidget);
    await tester.tap(find.byKey(const Key('approvePairing')));
    await tester.pumpAndSettle();
    expect(await p2.decision.future, isTrue);
    expect(find.byKey(const Key('pairingDialog')), findsNothing);
  });

  testWidgets('browser upload uses the normal incoming dialog and list',
      (tester) async {
    final core = await pumpApp(tester);
    final req = core.simulateIncoming(
        autoProgress: false,
        from: const DeviceInfo(
            alias: 'Browser 192.168.1.77',
            deviceType: 'web',
            deviceModel: 'Safari on iPhone',
            fingerprint: '',
            ip: '192.168.1.77',
            port: 0));
    await tester.pumpAndSettle();
    expect(find.text('Browser 192.168.1.77 wants to send you 2 files'),
        findsOneWidget);
    expect(find.text('Web browser at 192.168.1.77 · Safari on iPhone'),
        findsOneWidget);
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(await req.decision.future, isTrue);
    expect(find.text('From Browser 192.168.1.77'), findsOneWidget);
  });

  testWidgets('share flow: pick, choose limits, card with copy and stop',
      (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    final core = await pumpApp(tester,
        pick: () async => ['/x/movie.mp4', '/x/notes.txt']);
    await tester.tap(find.byKey(const Key('sharesAction')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shareFiles')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shareOptionsDialog')), findsOneWidget);
    expect(find.text('Share 2 files'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ttl-15m')));
    await tester.tap(find.byKey(const Key('max-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirmShare')));
    await tester.pumpAndSettle();

    final (paths, ttl, max) = core.shareCalls.single;
    expect(paths, ['/x/movie.mp4', '/x/notes.txt']);
    expect(ttl, const Duration(minutes: 15));
    expect(max, 1);
    final share = core.shares.single;
    await scrollTo(tester, find.byKey(Key('stopShare-${share.id}')));
    expect(find.text('movie.mp4 and 1 more'), findsOneWidget);
    expect(find.text('1 of 1 downloads left'), findsOneWidget);
    expect(find.textContaining('Ends in 1'), findsOneWidget);
    expect(find.text(share.url), findsOneWidget);
    expect(share.url, startsWith('https://192.168.1.10:53317/#s='));

    core.simulateDownload(share.id);
    await tester.pumpAndSettle();
    expect(find.text('Download limit reached'), findsOneWidget);

    await scrollTo(tester, find.byKey(Key('copyShare-${share.id}')));
    await tester.tap(find.byKey(Key('copyShare-${share.id}')));
    await tester.pumpAndSettle();
    expect(copied, share.url);
    // The "Sharing ..." snackbar from creating the share goes first.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Link copied'), findsOneWidget);

    await tester.tap(find.byKey(Key('stopShare-${share.id}')));
    await tester.pumpAndSettle();
    expect(core.shares, isEmpty);
    expect(find.byKey(Key('share-${share.id}')), findsNothing);
  });

  testWidgets('shares page from the app bar: folder share, browser card',
      (tester) async {
    final core = await pumpApp(tester,
        pickFolder: () async => '/x/Holiday');
    await tester.tap(find.byKey(const Key('sharesAction')));
    await tester.pumpAndSettle();
    expect(find.text('Shares'), findsOneWidget);
    expect(find.textContaining('Nothing shared'), findsOneWidget);
    await tester.tap(find.byKey(const Key('shareFolder')));
    await tester.pumpAndSettle();
    expect(find.text('Share folder "Holiday"'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ttl-none')));
    await tester.tap(find.byKey(const Key('confirmShare')));
    await tester.pumpAndSettle();
    final (paths, ttl, max) = core.shareCalls.single;
    expect(paths, ['/x/Holiday']);
    expect(ttl, isNull);
    expect(max, isNull);
    final id = core.shares.single.id;
    expect(find.byKey(Key('share-$id')), findsOneWidget);
    expect(find.text('Until you stop it'), findsOneWidget);
    expect(find.text('Unlimited downloads'), findsOneWidget);
    await scrollTo(tester, find.byKey(const Key('webUrl')));
    expect(find.text('https://192.168.1.10:53317/'), findsOneWidget);
    // The certificate warning is explained only when asked (U2).
    expect(find.textContaining('not private'), findsNothing);
    await scrollTo(tester, find.byKey(const Key('certWarningHelp')));
    await tester.tap(find.byKey(const Key('certWarningHelp')));
    await tester.pumpAndSettle();
    expect(find.textContaining('not private'), findsOneWidget);
  });

  testWidgets('Shares page has the browser card; home does not',
      (tester) async {
    await pumpApp(tester);
    // U1: no browser card, connected browsers or QR on home any more.
    for (final k in ['webAccessCard', 'connectedBrowsersCard', 'selfUrl']) {
      expect(find.byKey(Key(k), skipOffstage: false), findsNothing, reason: k);
    }
    await tester.tap(find.byKey(const Key('sharesAction')));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const Key('webUrl')));
    expect(find.text('https://192.168.1.10:53317/'), findsOneWidget);
    expect(find.text('For any phone camera or browser'), findsOneWidget);
    await scrollTo(tester, find.byKey(const Key('certWarningHelp')));
    await tester.tap(find.byKey(const Key('certWarningHelp')));
    await tester.pumpAndSettle();
    expect(find.textContaining('"Advanced" then "Proceed"'), findsOneWidget);
    expect(find.byKey(const Key('webHttpUrl')), findsNothing);
  });

  for (final width in [375.0, 1000.0]) {
    testWidgets('one Send button on home at ${width.toInt()} px',
        (tester) async {
      await pumpApp(tester, size: Size(width, 800));
      expect(tester.takeException(), isNull); // no overflow
      final f = find.byKey(const Key('sendFab'));
      expect(f, findsOneWidget);
      expect(find.descendant(of: f, matching: find.text('Send')),
          findsOneWidget);
      final r = tester.getRect(f);
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(width));
      expect(r.bottom, lessThanOrEqualTo(800));
      // The other FABs and the home share section are gone (U1).
      for (final k in ['shareFab', 'sendFolderFab', 'shareFiles']) {
        expect(find.byKey(Key(k)), findsNothing, reason: k);
      }
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byKey(const Key('sharesAction')), findsOneWidget);
    });
  }

  testWidgets('send sheet: "Files" picks files, then the device',
      (tester) async {
    var picked = 0;
    final core = await pumpApp(tester, size: const Size(375, 800),
        pick: () async {
      picked++;
      return ['/x/a.txt', '/x/b.txt'];
    });
    await tester.tap(find.byKey(const Key('sendFab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sendSheet')), findsOneWidget);
    expect(find.text('What do you want to send?'), findsOneWidget);
    expect(find.text('Files'), findsOneWidget);
    expect(find.text('Folder'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sendFiles')));
    await tester.pumpAndSettle();
    expect(picked, 1);
    expect(find.byKey(const Key('sendSheet')), findsNothing);
    expect(find.text('Send 2 files to…'), findsOneWidget);
    // The picker shows the device kind, never the address.
    expect(
        find.descendant(
            of: find.byType(SimpleDialog), matching: find.text('Phone')),
        findsOneWidget);
    expect(find.textContaining('192.168.1.21'), findsNothing);
    await tester.tap(find.descendant(
        of: find.byType(SimpleDialog), matching: find.text('Pixel 9')));
    await tester.pumpAndSettle();
    expect(core.sent.single.$2, ['/x/a.txt', '/x/b.txt']);
    expect(find.text('Sent to Pixel 9.'), findsOneWidget);
  });

  testWidgets('send sheet dismissed: nothing is picked or sent',
      (tester) async {
    var picked = 0;
    final core = await pumpApp(tester, pick: () async {
      picked++;
      return ['/x/a.txt'];
    });
    await tester.tap(find.byKey(const Key('sendFab')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(200, 50)); // the scrim
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sendSheet')), findsNothing);
    expect(picked, 0);
    expect(core.sent, isEmpty);
  });

  testWidgets('choose device without devices offers help, not a dead end',
      (tester) async {
    final core = await pumpApp(tester, pick: () async => ['/x/a.txt']);
    core.setPeers(const []);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sendFab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sendFiles')));
    await tester.pumpAndSettle();
    expect(find.text('No devices found yet.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pickerHelp')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('peerPicker')), findsNothing);
    expect(find.byKey(const Key('connectHelper')), findsOneWidget);
    expect(core.sent, isEmpty);
  });

  testWidgets('declined and failed sends are told apart', (tester) async {
    final core = FakeCore(simulateDelay: const Duration(milliseconds: 10))
      ..failSends['aa11'] = SendErrorCode.declined
      ..failSends['bb22'] = SendErrorCode.unreachable;
    await pumpApp(tester, core: core, pick: () async => ['/x/a.txt']);
    await tester.tap(find.byKey(const Key('send-aa11')));
    await tester.pumpAndSettle();
    expect(find.text('Pixel 9 declined.'), findsOneWidget);
    expect(find.text('Declined by Pixel 9'), findsOneWidget); // card
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('send-bb22')));
    await tester.pumpAndSettle();
    expect(
        find.text("Couldn't reach Work Laptop. Is LanDrop still open there?"),
        findsOneWidget);
    expect(find.widgetWithText(SnackBarAction, 'Help'), findsOneWidget);
  });

  testWidgets('device row: kind instead of address; Details sheet has it',
      (tester) async {
    final core = FakeCore(
        simulateDelay: const Duration(milliseconds: 10),
        initialPeers: const [FakeCore.persianPeer]);
    await pumpApp(tester, core: core);
    expect(find.text('لپ‌تاپ سارا'), findsOneWidget);
    expect(find.text('Computer · Windows'), findsOneWidget);
    expect(find.textContaining('192.168.1.42'), findsNothing);
    expect(find.textContaining('cable'), findsNothing);
    await tester.tap(find.byKey(const Key('details-fa77')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('peerDetailsSheet')), findsOneWidget);
    expect(find.text('192.168.1.42:53317'), findsOneWidget);
    expect(find.text('169.254.10.20'), findsOneWidget);
    expect(find.text('FA77'), findsOneWidget); // security code
    expect(find.text('Security code'), findsOneWidget);
    // Technical values are left to right.
    final addr = tester.widget<SelectableText>(find.descendant(
        of: find.byKey(const Key('peerAddress')),
        matching: find.byType(SelectableText)));
    expect(addr.textDirection, TextDirection.ltr);
    await tester.tapAt(const Offset(200, 50));
    await tester.pumpAndSettle();
    // Long press opens it too.
    await tester.longPress(find.text('لپ‌تاپ سارا'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('peerDetailsSheet')), findsOneWidget);
  });

  testWidgets('incoming dialog: device kind, no security code, save folder',
      (tester) async {
    final core = await pumpApp(tester);
    core.simulateIncoming(autoProgress: false);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('incomingSender'))).data,
        'Phone · Google');
    expect(find.textContaining('fingerprint'), findsNothing);
    expect(find.textContaining('192.168.1.21'), findsNothing);
    expect(find.text('Saves to /tmp/landrop-test'), findsOneWidget);
    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
  });

  testWidgets('active shares show as one row on home', (tester) async {
    final core = await pumpApp(tester);
    expect(find.byKey(const Key('activeSharesRow')), findsNothing);
    core.createShare(['/x/a.txt']);
    core.createShare(['/x/b.txt']);
    await tester.pumpAndSettle();
    expect(find.text('Sharing 2 links'), findsOneWidget);
    await tester.tap(find.byKey(const Key('activeSharesRow')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sendLinkSection')), findsOneWidget);
    expect(find.byKey(const Key('share-share-1')), findsOneWidget);
  });

  testWidgets('Shares page: "Send a link" and "Use from a browser"',
      (tester) async {
    final core = await pumpApp(tester,
        size: const Size(375, 800), pick: () async => ['/x/a.txt']);
    await tester.tap(find.byKey(const Key('sharesAction')));
    await tester.pumpAndSettle();
    final link = find.byKey(const Key('sendLinkSection'));
    final browser = find.byKey(const Key('browserSection'), skipOffstage: false);
    expect(link, findsOneWidget);
    expect(find.descendant(of: link, matching: find.text('Send a link')),
        findsOneWidget);
    expect(find.descendant(of: link, matching: find.byKey(const Key('shareFiles'))),
        findsOneWidget);
    expect(find.descendant(of: link, matching: find.byKey(const Key('shareFolder'))),
        findsOneWidget);
    for (final k in ['webAccessCard', 'connectedBrowsersCard']) {
      expect(
          find.descendant(
              of: browser, matching: find.byKey(Key(k), skipOffstage: false)),
          findsOneWidget,
          reason: k);
    }
    expect(
        find.descendant(
            of: browser,
            matching: find.text('Use from a browser', skipOffstage: false)),
        findsOneWidget);
    expect(tester.getRect(link).top,
        lessThan(tester.getRect(browser).top)); // links first
    await tester.tap(find.byKey(const Key('shareFiles')));
    await tester.pumpAndSettle();
    expect(find.text('Share 1 file'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmShare')));
    await tester.pumpAndSettle();
    expect(core.shareCalls.single.$1, ['/x/a.txt']);
    expect(core.shares, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Shares page: connected browsers card lists sessions; Disconnect',
      (tester) async {
    final core = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('sharesAction')));
    await tester.pumpAndSettle();
    final card = find.byKey(const Key('connectedBrowsersCard'));
    await scrollTo(tester, card);
    expect(find.textContaining('No browser is paired'), findsOneWidget);
    final s1 = core.simulateWebSession();
    final s2 = core.simulateWebSession(
        userAgent: 'Chrome on Windows', ip: '192.168.1.80');
    await tester.pumpAndSettle();
    expect(find.text('Safari on iPhone'), findsOneWidget);
    expect(find.text('Chrome on Windows'), findsOneWidget);
    expect(find.textContaining('192.168.1.80 · paired '), findsOneWidget);
    expect(find.textContaining('last seen just now'), findsNWidgets(2));
    await scrollTo(tester, find.byKey(Key('disconnect-${s1.id}')));
    await tester.tap(find.byKey(Key('disconnect-${s1.id}')));
    await tester.pumpAndSettle();
    expect(core.revokedWebSessions, [s1.id]);
    expect(find.byKey(Key('webSession-${s1.id}')), findsNothing);
    expect(find.byKey(Key('webSession-${s2.id}')), findsOneWidget);
    expect(find.text('Safari on iPhone disconnected'), findsOneWidget);
  });

  testWidgets('settings: Shares and browsers row opens the Shares page',
      (tester) async {
    final core = await pumpApp(tester);
    final s = core.simulateWebSession(userAgent: 'Firefox on Linux');
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('connectedBrowsersCard')), findsNothing);
    await tester.tap(find.byKey(const Key('sharesSettings')));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(Key('disconnect-${s.id}')));
    expect(find.text('Firefox on Linux'), findsOneWidget);
    await tester.tap(find.byKey(Key('disconnect-${s.id}')));
    await tester.pumpAndSettle();
    expect(core.revokedWebSessions, [s.id]);
    expect(find.text('Firefox on Linux'), findsNothing);
    expect(find.textContaining('No browser is paired'), findsOneWidget);
  });

  testWidgets('settings: grouped; technical rows moved to Advanced',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    for (final k in [
      'aliasSettings', 'saveFolderSettings', 'resetFolder',
      'languageSettings', 'connectHelpSettings', 'sharesSettings',
      'advancedSettings',
    ]) {
      expect(find.byKey(Key(k)), findsOneWidget, reason: k);
    }
    expect(find.text('This device'), findsOneWidget);
    for (final k in [
      'webHttpSwitch', 'keepSharesSwitch', 'diagnoseSettings',
      'hotspotSettings', 'cableSettings', 'securityCode',
    ]) {
      expect(find.byKey(Key(k), skipOffstage: false), findsNothing, reason: k);
    }
    expect(find.text('Certificate fingerprint'), findsNothing);
    await tester.tap(find.byKey(const Key('connectHelpSettings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('connectHelper')), findsOneWidget);
  });

  testWidgets('advanced page: address QR, security code, all methods',
      (tester) async {
    await pumpApp(tester);
    await openAdvanced(tester);
    expect(find.text('Advanced'), findsOneWidget);
    expect(find.text('For another LanDrop app'), findsOneWidget);
    expect(find.text('https://192.168.1.10:53317'), findsOneWidget);
    final url = tester.widget<SelectableText>(find.descendant(
        of: find.byKey(const Key('selfUrl')),
        matching: find.byType(SelectableText)));
    expect(url.textDirection, TextDirection.ltr);
    expect(find.text('Security code'), findsOneWidget);
    expect(find.text('FAKE-SELF'), findsOneWidget);
    // Plain status instead of the enum name (quick win 9).
    expect(find.text('Restart LanDrop service'), findsOneWidget);
    expect(find.text('Running'), findsOneWidget);
    expect(find.text('running'), findsNothing);
    for (final k in [
      'restartService', 'webHttpSwitch', 'keepSharesSwitch',
      'diagnoseSettings', 'hotspotSettings', 'cableSettings',
    ]) {
      await scrollTo(tester, find.byKey(Key(k)));
      expect(find.byKey(Key(k)), findsOneWidget, reason: k);
    }
    expect(find.text('Allow browsers without a warning (not encrypted)'),
        findsOneWidget);
  });

  testWidgets('advanced page: Android-only methods', (tester) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final android in [true, false]) {
      final c = AppController(
          core: FakeCore(simulateDelay: Duration.zero),
          store: MemorySettingsStore(),
          initialSaveDir: '/tmp/landrop-test',
          initialAlias: 'Tester');
      await c.init();
      await tester.pumpWidget(MaterialApp(
          key: ValueKey(android),
          home: AppScope(
              controller: c,
              child: AdvancedSettingsPage(isAndroid: android))));
      await tester.pumpAndSettle();
      for (final k in ['wifiDirectSettings', 'wifiJoinSettings']) {
        expect(find.byKey(Key(k), skipOffstage: false),
            android ? findsOneWidget : findsNothing,
            reason: '$k android=$android');
      }
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await tester.pump(const Duration(milliseconds: 20));
    }
  });

  testWidgets('settings: "Keep shares after restart" is on; off is saved',
      (tester) async {
    final store = MemorySettingsStore();
    final core = FakeCore(simulateDelay: const Duration(milliseconds: 10));
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(LanDropApp(
      core: core,
      store: store,
      initialSaveDir: '/tmp/landrop-test',
      initialAlias: 'Tester',
    ));
    await tester.pumpAndSettle();
    expect(core.sharesPersistence, isTrue);
    await openAdvanced(tester);
    final sw = find.byKey(const Key('keepSharesSwitch'));
    await scrollTo(tester, sw);
    expect(tester.widget<SwitchListTile>(sw).value, isTrue);
    await tester.tap(sw);
    await tester.pumpAndSettle();
    expect(core.sharesPersistence, isFalse);
    expect(store.stored['keepShares'], isFalse);
    expect(tester.widget<SwitchListTile>(sw).value, isFalse);
  });

  test('keepShares off in settings is applied before the core starts',
      () async {
    final core = FakeCore(simulateDelay: Duration.zero);
    final c = AppController(
        core: core,
        store: MemorySettingsStore({'keepShares': false}),
        initialSaveDir: '/tmp/landrop-test');
    await c.init();
    expect(c.keepShares, isFalse);
    expect(core.sharesPersistence, isFalse);
    c.dispose();
  });

  test('share and browser counts go to the service notification on change',
      () async {
    final calls = <(int, int)>[];
    final core = FakeCore(simulateDelay: Duration.zero);
    final c = AppController(
        core: core,
        store: MemorySettingsStore(),
        initialSaveDir: '/tmp/landrop-test',
        statusNotifier: (s, b) async => calls.add((s, b)));
    await c.init();
    expect(calls, [(0, 0)]);
    final share = c.createShare(['/x/a.txt']);
    c.createShare(['/x/b.txt']);
    final web = core.simulateWebSession();
    await Future<void>.delayed(Duration.zero);
    c.revokeShare(share.id);
    c.revokeWebSession(web.id);
    await Future<void>.delayed(Duration.zero);
    expect(calls, [(0, 0), (1, 0), (2, 0), (2, 1), (1, 1), (1, 0)]);
    // Unrelated changes do not repeat the call.
    c.dismissDiscoveryError();
    expect(calls, hasLength(6));
    // Background off: nothing is sent (there is no service).
    await c.setBackground(false);
    c.createShare(['/x/c.txt']);
    expect(calls, hasLength(6));
    c.dispose();
  });

  testWidgets('settings: plain HTTP switch is off, asks before turning on',
      (tester) async {
    final core = await pumpApp(tester);
    await openAdvanced(tester);
    final sw = find.byKey(const Key('webHttpSwitch'));
    await scrollTo(tester, sw);
    expect(tester.widget<SwitchListTile>(sw).value, isFalse);
    expect(find.textContaining('Off is safer'), findsOneWidget);

    // Cancel keeps it off.
    await tester.tap(sw);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('confirmWebHttp')), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(core.webHttpEnabled, isFalse);

    await tester.tap(sw);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmWebHttpOn')));
    await tester.pumpAndSettle();
    expect(core.webHttpEnabled, isTrue);
    expect(tester.widget<SwitchListTile>(sw).value, isTrue);
    await scrollTo(tester, find.byKey(const Key('webHttpUrlTile')));
    expect(find.text('http://192.168.1.10:53320/'), findsOneWidget);

    // Turning it off needs no confirmation.
    // (Scrolled just above the viewport by the previous step.)
    await tester.ensureVisible(
        find.byKey(const Key('webHttpSwitch'), skipOffstage: false));
    await tester.pumpAndSettle();
    await tester.tap(sw);
    await tester.pumpAndSettle();
    expect(core.webHttpEnabled, isFalse);
    expect(find.byKey(const Key('webHttpUrlTile')), findsNothing);
  });
}
