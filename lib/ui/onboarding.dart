import 'dart:io';

import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'l10n.dart';
import 'widgets.dart';

/// First-run onboarding (UX.md 3.6, step U8): at most three screens, shown
/// once (`onboarded` in the settings JSON), skippable. 1: what LanDrop
/// does; 2: how devices find each other; 3: this device's name and the
/// permissions this platform may ask for, explained but not requested
/// (Android "All files access" is asked later, with its own explanation).
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, this.platform});

  /// `Platform.operatingSystem` value (test seam): picks the permission
  /// lines of screen 3.
  final String? platform;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const _pages = 3;
  final _pager = PageController();
  TextEditingController? _alias;
  int _page = 0;
  bool _finishing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _alias ??= TextEditingController(text: AppScope.read(context).alias);
  }

  @override
  void dispose() {
    _pager.dispose();
    _alias?.dispose();
    super.dispose();
  }

  Future<void> _finish({required bool keepName}) async {
    if (_finishing) return;
    _finishing = true;
    await AppScope.read(context)
        .completeOnboarding(alias: keepName ? _alias!.text : null);
  }

  void _next() {
    if (_page >= _pages - 1) {
      _finish(keepName: true);
      return;
    }
    _pager.nextPage(
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  /// The permission lines for this platform (UX.md 3.6).
  List<(IconData, String)> _permissions(AppLocalizations l) {
    final os = widget.platform ?? Platform.operatingSystem;
    return switch (os) {
      'android' => [(Icons.folder_outlined, l.onboardingStorageAndroid)],
      'macos' => [(Icons.lan_outlined, l.onboardingLocalNetworkComputer)],
      'ios' => [(Icons.lan_outlined, l.onboardingLocalNetworkPhone)],
      'windows' => [(Icons.shield_outlined, l.onboardingFirewallWindows)],
      _ => [(Icons.check_circle_outline, l.onboardingNothingToAllow)],
    };
  }

  Widget _screen(BuildContext context,
      {required int index,
      required IconData icon,
      required String title,
      required String body,
      List<Widget> extra = const []}) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        key: Key('onboardingPage-$index'),
        padding: const EdgeInsetsDirectional.fromSTEB(24, 16, 24, 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(icon, size: 72, color: scheme.primary),
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(title,
                    style: t.headlineSmall, textAlign: TextAlign.center),
              ),
              const SizedBox(height: 12),
              Text(body, style: t.bodyLarge, textAlign: TextAlign.center),
              ...extra,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final last = _page == _pages - 1;
    return Scaffold(
      key: const Key('onboarding'),
      body: SafeArea(
        child: Semantics(
          label: l.onboardingSemantics,
          explicitChildNodes: true,
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 0),
                  child: last
                      ? const SizedBox(height: 48)
                      : TextButton(
                          key: const Key('onboardingSkip'),
                          onPressed: () => _finish(keepName: false),
                          child: Text(l.onboardingSkip),
                        ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pager,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    _screen(context,
                        index: 0,
                        icon: Icons.send_to_mobile_outlined,
                        title: l.onboarding1Title,
                        body: l.onboarding1Body),
                    _screen(context,
                        index: 1,
                        icon: Icons.wifi,
                        title: l.onboarding2Title,
                        body: l.onboarding2Body),
                    _screen(context,
                        index: 2,
                        icon: Icons.badge_outlined,
                        title: l.onboarding3Title,
                        body: l.onboarding3Body,
                        extra: [
                          const SizedBox(height: 16),
                          TextField(
                            key: const Key('onboardingAlias'),
                            controller: _alias,
                            maxLength: 40,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _finish(keepName: true),
                            decoration: InputDecoration(
                                labelText: l.aliasLabel,
                                border: const OutlineInputBorder()),
                          ),
                          const SizedBox(height: 16),
                          Text(l.onboardingPermissions,
                              key: const Key('onboardingPermissions'),
                              style: t.titleSmall),
                          for (final (icon, text) in _permissions(l))
                            Padding(
                              padding:
                                  const EdgeInsetsDirectional.only(top: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(icon,
                                      size: 20,
                                      color: scheme.onSurfaceVariant),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child:
                                          Text(text, style: t.bodyMedium)),
                                ],
                              ),
                            ),
                        ]),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 16),
                child: Row(
                  children: [
                    Semantics(
                      label: l.onboardingStep(_page + 1, _pages),
                      child: ExcludeSemantics(
                        child: Row(
                          key: const Key('onboardingDots'),
                          children: [
                            for (var i = 0; i < _pages; i++)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsetsDirectional.only(
                                    end: 6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: i == _page
                                      ? scheme.primary
                                      : scheme.outlineVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      key: Key(last ? 'onboardingStart' : 'onboardingNext'),
                      onPressed: _next,
                      child:
                          Text(last ? l.onboardingStart : l.onboardingNext),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Android: explains "All files access" before the system screen (UX.md
/// 3.6). True for "Allow", false for "Not now" (or dismissed).
Future<bool> showStorageExplanation(BuildContext context) async {
  final res = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final l = ctx.l;
      final t = Theme.of(ctx).textTheme;
      return SafeArea(
        child: Semantics(
          label: l.storageTitle,
          explicitChildNodes: true,
          child: SingleChildScrollView(
            key: const Key('storageSheet'),
            padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.folder_open,
                    size: 40, color: Theme.of(ctx).colorScheme.primary),
                const SizedBox(height: 12),
                Semantics(
                    header: true,
                    child: Text(l.storageTitle, style: t.titleLarge)),
                const SizedBox(height: 12),
                Text(l.storageBody, style: t.bodyMedium),
                const SizedBox(height: 8),
                Text(l.storageLater, style: t.bodySmall),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      key: const Key('storageNotNow'),
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(l.storageNotNow),
                    ),
                    FilledButton(
                      key: const Key('storageAllow'),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(l.storageAllow),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return res ?? false;
}

/// The explanation, then (on "Allow") the system screen; tells the user
/// where files go now. With [firstTime] the answer is remembered (asked
/// once from the receive flow); Settings' "Use Downloads" asks every time.
Future<void> askStorageAccess(BuildContext context, AppController c,
    {bool firstTime = false}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l = context.l;
  final allow = await showStorageExplanation(context);
  final ok = firstTime
      ? await c.answerStorageExplanation(allow)
      : allow && await c.useDownloadsFolder();
  messenger?.showSnackBar(SnackBar(
      key: const Key('storageResult'),
      content: Text(ok
          ? l.storageGranted(l.ltrValue('Downloads/LanDrop'))
          : l.storageKeptPrivate)));
}
