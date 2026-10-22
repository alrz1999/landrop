import 'package:flutter/material.dart';

import '../core/api.dart';
import '../l10n/app_localizations.dart';
import 'app_controller.dart';
import 'file_opener.dart';
import 'home_page.dart';
import 'hotspot_service.dart';
import 'onboarding.dart';
import 'share_target.dart';
import 'storage_access.dart';
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
    this.fileOpener,
    this.storageAccess,
    this.historyStore,
    this.onboardingPlatform,
    this.shareTarget,
    this.permissionAccess,
  });

  /// Android runtime permissions behind their explanations (test seam).
  final PermissionAccess? permissionAccess;

  /// Android share-sheet intake (test seam); default [ShareTargetService].
  final ShareTargetApi? shareTarget;

  /// Android "All files access" (test seam).
  final StorageAccess? storageAccess;

  /// Transfer history (test seam); default: the [store]'s.
  final HistoryStore? historyStore;

  /// Platform for the onboarding's permission lines (test seam).
  final String? onboardingPlatform;

  /// "Open" / "Show in folder" for received files (test seam).
  final FileOpener? fileOpener;

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
      fileOpener: widget.fileOpener,
      storageAccess: widget.storageAccess,
      historyStore: widget.historyStore,
      permissionAccess: widget.permissionAccess,
    );
    controller.addListener(_onControllerChanged);
    controller.init();
  }

  /// MaterialApp itself only depends on the language and the theme;
  /// everything else listens through [AppScope].
  Locale? _locale;
  ThemeMode _themeMode = ThemeMode.system;
  void _onControllerChanged() {
    if (controller.locale != _locale ||
        controller.themeMode != _themeMode) {
      setState(() {
        _locale = controller.locale;
        _themeMode = controller.themeMode;
      });
    }
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: _locale, // null = follow the system
        localeResolutionCallback: resolveAppLocale,
        debugShowCheckedModeBanner: false,
        themeMode: _themeMode,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: seed),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: seed, brightness: Brightness.dark),
          useMaterial3: true,
        ),
        home: ShareTargetHost(
          service: widget.shareTarget,
          pickFiles: widget.pickFiles,
          pickFolder: widget.pickFolder,
          child: _Root(
            home: HomePage(
                pickFiles: widget.pickFiles, pickFolder: widget.pickFolder),
            onboardingPlatform: widget.onboardingPlatform,
          ),
        ),
      ),
    );
  }
}

/// Waits for the settings, then shows the first-run onboarding once
/// (UX.md 3.6) or [home].
class _Root extends StatelessWidget {
  const _Root({required this.home, this.onboardingPlatform});
  final Widget home;
  final String? onboardingPlatform;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    if (!c.settingsLoaded) return const Scaffold();
    if (!c.onboarded) return OnboardingPage(platform: onboardingPlatform);
    return home;
  }
}

/// The supported locale with [device]'s language, else English. Persian
/// (fa) makes MaterialApp lay out right to left.
Locale resolveAppLocale(Locale? device, Iterable<Locale> supported) =>
    supported.firstWhere((l) => l.languageCode == device?.languageCode,
        orElse: () => const Locale('en'));
