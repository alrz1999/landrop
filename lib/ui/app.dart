import 'package:flutter/material.dart';

import '../core/api.dart';
import 'app_controller.dart';
import 'home_page.dart';
import 'hotspot_service.dart';
import 'widgets.dart';

class LanDropApp extends StatefulWidget {
  const LanDropApp({
    super.key,
    required this.core,
    this.store,
    this.initialSaveDir,
    this.initialAlias,
    this.pickFiles = defaultPickFiles,
    this.pickFolder = defaultPickFolder,
    this.hotspotService,
  });

  final LanDropCore core;

  /// Android hotspot (test seam); default [HotspotService].
  final HotspotService? hotspotService;
  final SettingsStore? store;
  final String? initialSaveDir;
  final String? initialAlias;
  final FilesPicker pickFiles;
  final FolderPicker pickFolder;

  @override
  State<LanDropApp> createState() => _LanDropAppState();
}

class _LanDropAppState extends State<LanDropApp> {
  late final AppController controller;

  @override
  void initState() {
    super.initState();
    controller = AppController(
      core: widget.core,
      store: widget.store,
      initialSaveDir: widget.initialSaveDir,
      initialAlias: widget.initialAlias,
      hotspotService: widget.hotspotService,
    );
    controller.init();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF00897B);
    return AppScope(
      controller: controller,
      child: MaterialApp(
        title: 'LanDrop',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: seed),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: seed, brightness: Brightness.dark),
          useMaterial3: true,
        ),
        home: HomePage(
            pickFiles: widget.pickFiles, pickFolder: widget.pickFolder),
      ),
    );
  }
}
