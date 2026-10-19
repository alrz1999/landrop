import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/ui/app.dart';
import 'package:landrop/ui/app_controller.dart';
import 'package:landrop/ui/fake_core.dart';

void main() {
  testWidgets('app smoke test with FakeCore', (tester) async {
    await tester.pumpWidget(LanDropApp(
      core: FakeCore(simulateDelay: Duration.zero),
      store: MemorySettingsStore(),
      initialSaveDir: '/tmp',
    ));
    await tester.pumpAndSettle();
    expect(find.text('LanDrop'), findsOneWidget);
  });
}
