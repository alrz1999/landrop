// Test helpers for localized widget tests (docs/UX.md section 6).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/ui/app.dart';
import 'package:landrop/ui/app_controller.dart';
import 'package:landrop/ui/fake_core.dart';
import 'package:landrop/ui/hotspot_service.dart';

/// Pumps [app] in a [width] x [height] logical-pixel window and settles.
/// A `RenderFlex overflowed` during layout fails the test.
Future<void> pumpApp(WidgetTester t, Widget app,
    {double width = 1000, double height = 800}) async {
  t.view.physicalSize = Size(width, height);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(app);
  await t.pumpAndSettle();
}

/// [LanDropApp] on a [FakeCore] with the language stored in settings
/// (`'system'`, `'en'` or `'fa'`), like a user who picked it in Settings.
LanDropApp localizedApp(
    {Locale? locale = const Locale('en'),
    FakeCore? core,
    MemorySettingsStore? store,
    Future<List<String>> Function()? pickFiles,
    Future<String?> Function()? pickFolder,
    HotspotService? hotspotService}) {
  return LanDropApp(
    core: core ?? FakeCore(simulateDelay: const Duration(milliseconds: 10)),
    store: store ??
        MemorySettingsStore({'locale': locale?.languageCode ?? 'system'}),
    initialSaveDir: '/tmp/landrop-test',
    initialAlias: 'Tester',
    pickFiles: pickFiles ?? () async => <String>[],
    pickFolder: pickFolder ?? () async => null,
    hotspotService: hotspotService,
  );
}

/// Pumps [localizedApp] for [locale] at [width] x [height].
Future<FakeCore> pumpLocalized(WidgetTester t,
    {Locale locale = const Locale('en'),
    double width = 1000,
    double height = 800,
    FakeCore? core,
    Future<List<String>> Function()? pickFiles,
    Future<String?> Function()? pickFolder,
    HotspotService? hotspotService}) async {
  core ??= FakeCore(simulateDelay: const Duration(milliseconds: 10));
  await pumpApp(
      t,
      localizedApp(
          locale: locale,
          core: core,
          pickFiles: pickFiles,
          pickFolder: pickFolder,
          hotspotService: hotspotService),
      width: width, height: height);
  return core;
}

TextDirection _direction(WidgetTester t) =>
    Directionality.of(t.element(find.byType(Scaffold).first));

void expectRtl(WidgetTester t) => expect(_direction(t), TextDirection.rtl);

void expectLtr(WidgetTester t) => expect(_direction(t), TextDirection.ltr);
