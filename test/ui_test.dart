import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/core/api.dart';
import 'package:landrop/ui/app.dart';
import 'package:landrop/ui/app_controller.dart';
import 'package:landrop/ui/fake_core.dart';

Future<FakeCore> pumpApp(WidgetTester tester,
    {Size size = const Size(400, 900),
    Future<List<String>> Function()? pick}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final core = FakeCore(simulateDelay: const Duration(milliseconds: 10));
  await tester.pumpWidget(LanDropApp(
    core: core,
    store: MemorySettingsStore(),
    initialSaveDir: '/tmp/landrop-test',
    initialAlias: 'Tester',
    pickFiles: pick ?? () async => <String>[],
  ));
  await tester.pumpAndSettle();
  return core;
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
    expect(find.text('No nearby devices yet'), findsOneWidget);
    expect(find.textContaining('AP isolation'), findsOneWidget);
  });

  testWidgets('wide layout renders peers and QR', (tester) async {
    await pumpApp(tester, size: const Size(1280, 800));
    expect(find.text('Pixel 9'), findsOneWidget);
    expect(find.text('https://192.168.1.10:53317'), findsOneWidget);
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
    expect(find.text('Sent 1 file(s) to Pixel 9'), findsOneWidget);
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
}
