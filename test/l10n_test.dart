// Localization infrastructure (docs/UX.md section 4, steps L1/L5/R1, L4).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/core/api.dart';
import 'package:landrop/core/diagnosis.dart';
import 'package:landrop/l10n/app_localizations.dart';
import 'package:landrop/ui/app_controller.dart';
import 'package:landrop/ui/cable_wizard.dart';
import 'package:landrop/ui/connect_helper.dart';
import 'package:landrop/ui/digits.dart';
import 'package:landrop/ui/fake_core.dart';
import 'package:landrop/ui/file_opener.dart';
import 'package:landrop/ui/finding_text.dart';
import 'package:landrop/ui/format.dart';
import 'package:landrop/ui/dialogs.dart' show shortFolder;
import 'package:landrop/ui/hotspot_service.dart';
import 'package:landrop/ui/hotspot_wizard.dart';
import 'package:landrop/ui/l10n.dart' show BidiL10n;
import 'package:landrop/ui/ltr_text.dart';
import 'package:landrop/ui/wifi_direct_page.dart';
import 'package:landrop/ui/wifi_direct_service.dart';
import 'package:landrop/ui/wifi_join_page.dart';
import 'package:landrop/ui/wifi_join_service.dart';
import 'package:landrop/ui/widgets.dart' show AppScope, TransferSessionCard;
import 'package:landrop/ui/wifi_qr.dart';

import 'helpers/pump_localized.dart';

final en = lookupAppLocalizations(const Locale('en'));
final fa = lookupAppLocalizations(const Locale('fa'));

Map<String, dynamic> _arb(String lang) =>
    jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
        as Map<String, dynamic>;

/// Top-level placeholder names used in an ICU message.
Set<String> _placeholders(String message) =>
    {for (final m in RegExp(r'\{(\w+)[,}]').allMatches(message)) m[1]!};

/// Findings covering many codes, as the real rules produce them.
List<Finding> _sampleFindings() => diagnose(const DiagnosisInput(
      interfaces: [
        InterfaceObservation('en0', ['192.168.1.10']),
        InterfaceObservation('utun3', ['10.8.0.2']),
      ],
      serverPort: 53317,
      probe: ProbeObservation(
          ip: '192.168.1.20', port: 53317, tcp: TcpOutcome.timeout),
      mdnsEnabled: true,
      mdnsStarted: true,
      mdnsPeers: [
        MdnsPeerObservation('لپ‌تاپ سارا', 'ab12cd34ef56ab12cd34', '192.168.1.30', 53317,
            failure: 'timeout'),
      ],
    ));

/// Wi-Fi Direct without a radio: the test pushes peers and states.
class _FakeWifiDirect implements WifiDirectApi {
  final peersC = StreamController<List<WifiDirectPeer>>.broadcast();
  final statesC = StreamController<WifiDirectState>.broadcast();
  final errorsC = StreamController<WifiDirectException>.broadcast();
  @override
  bool get supported => true;
  @override
  Stream<List<WifiDirectPeer>> get peers => peersC.stream;
  @override
  Stream<WifiDirectState> get states => statesC.stream;
  @override
  Stream<WifiDirectException> get errors => errorsC.stream;
  @override
  Future<void> checkAvailable() async {}
  @override
  Future<void> discover() async {}
  @override
  Future<void> stopDiscover() async {}
  @override
  Future<void> connect(String address, {int? groupOwnerIntent}) async {}
  @override
  Future<void> createGroup() async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<WifiDirectState> info() async => WifiDirectState.disconnected;
  @override
  void dispose() {}
}

/// Joining a network without a radio; [camera] decides the permission.
class _FakeWifiJoin implements WifiJoinApi {
  _FakeWifiJoin({this.camera = true});
  final bool camera;
  final lostC = StreamController<WifiJoinException>.broadcast();
  @override
  bool get supported => true;
  @override
  Stream<WifiJoinException> get lost => lostC.stream;
  @override
  Future<bool> requestCamera() async => camera;
  @override
  Future<WifiJoinResult> join(WifiCredentials c) async =>
      WifiJoinResult(c.ssid, gateway: '192.168.43.1');
  @override
  Future<void> leave() async {}
  @override
  void dispose() {}
}

Future<void> _push(WidgetTester t, Widget page) async {
  t.state<NavigatorState>(find.byType(Navigator).first)
      .push(MaterialPageRoute(builder: (_) => page));
  await t.pumpAndSettle();
}

Future<void> _openSettings(WidgetTester t) async {
  // The tooltip is translated ("Settings" / "تنظیمات"); the icon is not.
  await t.tap(find.byIcon(Icons.settings_outlined));
  await t.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  if (f.evaluate().isEmpty) {
    await t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  }
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> _openAdvanced(WidgetTester t) async {
  await _openSettings(t);
  await _tapKey(t, 'advancedSettings');
}

Future<void> _openDiagnosis(WidgetTester t) async {
  await _openAdvanced(t);
  await _tapKey(t, 'diagnoseSettings');
}

/// No "Open" on phones (narrow tests), "Open" on desktops.
class _NoOpener implements FileOpener {
  _NoOpener({required this.canOpen});
  @override
  final bool canOpen;
  @override
  Future<bool> open(String path) async => true;
  @override
  Future<bool> reveal(String path) async => true;

  @override
  Future<bool> openLink(String url) async => true;
}

void main() {
  group('ARB files', () {
    test('every key exists in both languages with the same placeholders', () {
      final enArb = _arb('en'), faArb = _arb('fa');
      final enKeys = enArb.keys.where((k) => !k.startsWith('@')).toSet();
      final faKeys = faArb.keys.where((k) => !k.startsWith('@')).toSet();
      expect(faKeys.difference(enKeys), isEmpty, reason: 'only in fa');
      expect(enKeys.difference(faKeys), isEmpty, reason: 'only in en');
      for (final k in enKeys) {
        final enPh = _placeholders(enArb[k] as String);
        expect(_placeholders(faArb[k] as String), enPh, reason: k);
        final declared =
            ((enArb['@$k'] as Map?)?['placeholders'] as Map?)?.keys.toSet() ??
                <String>{};
        expect(declared, enPh, reason: '@$k placeholders');
        final faDeclared =
            ((faArb['@$k'] as Map?)?['placeholders'] as Map?)?.keys.toSet();
        if (faDeclared != null) expect(faDeclared, enPh, reason: 'fa @$k');
      }
    });

    test('every English entry has a description; fa notes start REVIEW:', () {
      final enArb = _arb('en'), faArb = _arb('fa');
      for (final k in enArb.keys.where((k) => !k.startsWith('@'))) {
        expect((enArb['@$k'] as Map?)?['description'], isA<String>(),
            reason: k);
      }
      for (final e in faArb.entries.where((e) => e.key.startsWith('@') &&
          e.key != '@@locale')) {
        final d = (e.value as Map)['description'];
        if (d != null) expect(d, startsWith('REVIEW:'), reason: e.key);
      }
    });

    test('Persian keeps the zero-width non-joiner', () {
      expect(fa.settingsLanguageSystem, contains('‌'));
      expect(fa.settingsLanguageSystem, 'پیش‌فرض سیستم');
    });
  });

  group('language setting', () {
    testWidgets('choosing فارسی in Settings switches to RTL Persian',
        (t) async {
      final store = MemorySettingsStore();
      await pumpApp(t, localizedApp(store: store), width: 400, height: 900);
      expectLtr(t);
      await _openSettings(t);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('System default'), findsOneWidget); // current choice
      await t.tap(find.byKey(const Key('languageSettings')));
      await t.pumpAndSettle();
      final dialog = find.byKey(const Key('languageDialog'));
      expect(dialog, findsOneWidget);
      for (final name in ['System default', 'English', 'فارسی']) {
        expect(find.descendant(of: dialog, matching: find.text(name)),
            findsOneWidget);
      }
      await t.tap(find.byKey(const Key('language-fa')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('languageDialog')), findsNothing);
      expectRtl(t);
      expect(find.text('زبان'), findsOneWidget);
      expect(find.text('تنظیمات'), findsOneWidget);
      expect(find.text('فارسی'), findsOneWidget);
      expect(store.stored['locale'], 'fa');

      // And back to the system language (English in tests).
      await t.tap(find.byKey(const Key('languageSettings')));
      await t.pumpAndSettle();
      expect(find.text('پیش‌فرض سیستم'), findsOneWidget);
      await t.tap(find.byKey(const Key('language-system')));
      await t.pumpAndSettle();
      expectLtr(t);
      expect(find.text('System default'), findsOneWidget);
      expect(store.stored['locale'], 'system');
    });

    testWidgets('a stored fa locale starts the app right to left', (t) async {
      await pumpLocalized(t, locale: const Locale('fa'));
      expectRtl(t);
      await _openSettings(t);
      expect(find.text('زبان'), findsOneWidget);
    });

    testWidgets('locale round trip through MemorySettingsStore', (t) async {
      final store = MemorySettingsStore({'alias': 'Kept'});
      final a = AppController(
          core: FakeCore(),
          store: store,
          initialSaveDir: '/tmp/landrop-test',
          statusNotifier: (_, _) async {});
      await a.init();
      expect(a.locale, isNull);
      await a.setLocale(const Locale('fa', 'IR'));
      expect(a.locale, const Locale('fa'));
      expect(store.stored['locale'], 'fa');
      expect(store.stored['alias'], 'Kept');
      a.dispose();

      final b = AppController(
          core: FakeCore(),
          store: store,
          initialSaveDir: '/tmp/landrop-test',
          statusNotifier: (_, _) async {});
      await b.init();
      expect(b.locale, const Locale('fa'));
      await b.setLocale(null);
      expect(store.stored['locale'], 'system');
      b.dispose();

      final c = AppController(
          core: FakeCore(),
          store: MemorySettingsStore({'locale': 'system'}),
          initialSaveDir: '/tmp/landrop-test',
          statusNotifier: (_, _) async {});
      await c.init();
      expect(c.locale, isNull);
      c.dispose();
      await t.pump(const Duration(milliseconds: 50));
    });

    test('unsupported device languages resolve to English', () {
      expect(AppLocalizations.supportedLocales,
          containsAll(const [Locale('en'), Locale('fa')]));
    });
  });

  group('diagnosis findings', () {
    for (final width in [375.0, 1000.0]) {
      testWidgets('dialog in fa shows Persian findings at ${width.toInt()} px',
          (t) async {
        final core = FakeCore(simulateDelay: const Duration(milliseconds: 10))
          ..diagnosisFindings = _sampleFindings();
        await pumpLocalized(t,
            locale: const Locale('fa'), width: width, height: 800, core: core);
        await _openDiagnosis(t);
        expect(find.byKey(const Key('diagnosisDialog')), findsOneWidget);
        expectRtl(t);
        expect(find.byKey(const Key('finding-probe-timeout')), findsOneWidget);
        expect(find.text(fa.diagProbeTimeoutTitle), findsOneWidget);
        expect(find.text(fa.diagVpnActiveTitle), findsOneWidget);
        expect(find.text(fa.diagMdnsVisibleUnreachableTitle), findsOneWidget);
        expect(find.text(fa.diagWhatToDo(fa.diagVpnActiveFix)),
            findsOneWidget);
        expect(find.text('A VPN is on'), findsNothing);
        // Technical details stay English, collapsed under "Details".
        expect(find.textContaining('TCP connect to 192.168.1.20:53317'),
            findsNothing);
        await _tapKey(t, 'findingDetails-probe-timeout');
        expect(find.textContaining('TCP connect to 192.168.1.20:53317'),
            findsOneWidget);
        expect(find.byKey(const Key('copyReport')), findsOneWidget);
        expect(find.byKey(const Key('runAgain')), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('dialog in en keeps the core English texts', (t) async {
      final core = FakeCore(simulateDelay: const Duration(milliseconds: 10))
        ..diagnosisFindings = _sampleFindings();
      await pumpLocalized(t, width: 375, core: core);
      await _openDiagnosis(t);
      expect(find.text('A VPN is on'), findsOneWidget);
      expect(
          find.text('What to do: Turn the VPN off, or allow "local network '
              'access" in its settings, then try again.'),
          findsOneWidget);
    });

    test('rules carry structured params', () {
      final byCode = {for (final f in _sampleFindings()) f.code: f};
      expect(byCode['probe-timeout']!.params,
          containsPair('address', '192.168.1.20:53317'));
      expect(byCode['probe-timeout']!.params, containsPair('port', 53317));
      expect(byCode['vpn-active']!.params, containsPair('interfaces', 'utun3'));
      expect(byCode['mdns-visible-unreachable']!.params,
          containsPair('failure', 'timeout'));
      expect(byCode['mdns-visible-unreachable']!.params,
          containsPair('alias', 'لپ‌تاپ سارا'));
      expect(byCode['network']!.params, containsPair('interfaceCount', 2));
    });

    test('every finding code has a Persian title; unknown codes fall back',
        () {
      const codes = [
        'server-down', 'discovery-failed', 'no-lan', 'link-local-only',
        'vpn-active', 'announce-blocked', 'some-peers-silent',
        'probe-refused', 'probe-timeout', 'probe-unreachable',
        'probe-fingerprint-mismatch', 'probe-not-landrop', 'probe-ok',
        'different-subnet', 'hotspot-likely-fix', 'mdns-only',
        'mdns-visible-unreachable', 'udp-only-no-mdns', 'mdns-unavailable',
        'all-good', 'network', 'search-failed',
      ];
      for (final code in codes) {
        final f = Finding(Severity.info, code, 'EN', 'EN',
            fix: 'EN', params: const {'alias': 'Pixel 9'});
        final x = localizeFinding(fa, f);
        expect(x.title, isNot('EN'), reason: code);
        expect(x.title, contains(RegExp('[؀-ۿ]')), reason: code);
        expect(localizeFinding(en, f).title, 'EN', reason: code);
      }
      const unknown = Finding(Severity.warn, 'brand-new', 'T', 'D', fix: 'F');
      final u = localizeFinding(fa, unknown);
      expect((u.title, u.detail, u.fix), ('T', 'D', 'F'));
      // No fix in English: none in Persian either.
      const noFix = Finding(Severity.info, 'vpn-active', 'T', 'D');
      expect(localizeFinding(fa, noFix).fix, '');
      // A missing param falls back to English for that field only.
      const ok = Finding(Severity.info, 'probe-ok', 'T', 'Pixel at x');
      expect(localizeFinding(fa, ok).detail, 'Pixel at x');
      expect(localizeFinding(fa, ok).title, fa.diagProbeOkTitle);
    });

    test('mdns-unavailable picks the detail that matches the params', () {
      const one = Finding(Severity.info, 'mdns-unavailable', 'T', 'D',
          params: {'discoveryFailed': false});
      const both = Finding(Severity.warn, 'mdns-unavailable', 'T', 'D',
          fix: 'F', params: {'discoveryFailed': true});
      expect(localizeFinding(fa, one).detail, fa.diagMdnsUnavailableDetail);
      expect(localizeFinding(fa, both).detail,
          fa.diagMdnsUnavailableDetailBoth);
      expect(localizeFinding(fa, both).fix, fa.diagMdnsUnavailableFix);
    });

    test('send error codes are localized', () {
      final texts = {
        for (final c in SendErrorCode.values) localizeSendError(fa, c)
      };
      expect(texts, hasLength(SendErrorCode.values.length));
      expect(localizeSendError(en, SendErrorCode.declined),
          'The other device declined.');
      expect(localizeSendError(fa, null), fa.sendErrorUnknown);
      expect(localizeSendErrorName(fa, 'busy'), fa.sendErrorBusy);
      expect(localizeSendErrorName(fa, 'nope'), fa.sendErrorUnknown);
      expect(localizeSendResult(fa, const SendResult(ok: true)), isNull);
      expect(
          localizeSendResult(
              fa,
              const SendResult(
                  ok: false,
                  error: 'declined',
                  errorCode: SendErrorCode.declined)),
          fa.sendErrorDeclined);
    });
  });

  group('Persian screens (UX.md 6: L2, L3, R1)', () {
    // English texts of every plain (placeholder-free) message that has a
    // different Persian text: none may show up on a Persian screen. Platform
    // names ("Windows", "Android") are skipped: they are also device data
    // (a peer's model), which is never translated.
    final englishOnly = () {
      final enArb = _arb('en'), faArb = _arb('fa');
      return {
        for (final k in enArb.keys)
          if (!k.startsWith('@') &&
              !k.startsWith('platform') &&
              !(enArb[k] as String).contains('{') &&
              enArb[k] != faArb[k])
            enArb[k] as String
      };
    }();

    /// Every visible text on screen (Text, RichText-based Text,
    /// SelectableText).
    List<String> visibleTexts(WidgetTester t) => [
          for (final w in t.widgetList<Text>(find.byType(Text)))
            w.data ?? w.textSpan?.toPlainText() ?? '',
          for (final w
              in t.widgetList<SelectableText>(find.byType(SelectableText)))
            w.data ?? w.textSpan?.toPlainText() ?? '',
        ];

    void expectNoEnglish(WidgetTester t, String where) {
      final leaked = [
        for (final s in visibleTexts(t))
          if (englishOnly.contains(s)) s
      ];
      expect(leaked, isEmpty, reason: 'English on $where');
    }

    void expectLtrValue(WidgetTester t, Key key) {
      final f = find.descendant(
          of: find.byKey(key),
          matching: find.byWidgetPredicate(
              (w) => w is Text || w is SelectableText));
      final w = t.widget(f.first);
      final dir = w is Text ? w.textDirection : (w as SelectableText).textDirection;
      expect(dir, TextDirection.ltr, reason: '$key');
      expect(Directionality.of(t.element(f.first)), TextDirection.ltr,
          reason: '$key');
    }

    FakeCore persianCore({List<DeviceInfo>? peers}) => FakeCore(
        simulateDelay: const Duration(milliseconds: 10),
        initialPeers:
            peers ?? [FakeCore.persianPeer, FakeCore.defaultPeers.first]);

    for (final width in [375.0, 1000.0]) {
      final w = width.toInt();

      testWidgets('home with devices, empty, transfers, incoming at $w px',
          (t) async {
        final core = persianCore();
        await pumpLocalized(t,
            locale: const Locale('fa'), width: width, core: core);
        expectRtl(t);
        expect(find.text(fa.homeNearbyDevices), findsOneWidget);
        expect(find.text(fa.selfStatusReady), findsOneWidget);
        expect(find.text('لپ‌تاپ سارا'), findsOneWidget);
        expect(find.text('${fa.deviceKindComputer} · ${iso('Windows')}'),
            findsOneWidget);
        expect(find.text('Send'), findsNothing);
        expect(find.text(fa.homeSend), findsNWidgets(3)); // FAB + 2 rows
        expectNoEnglish(t, 'home');
        // IP and port stay left to right inside the Persian line.
        final addr = t.widget<SelectableText>(
            find.byKey(const Key('selfAddress')));
        expect(addr.data, fa.selfAddress(ltr('192.168.1.10'), ltr('53317')));
        // A Latin name keeps its own direction, aligned to the RTL start.
        final pixel = t.widget<Text>(find.text('Pixel 9'));
        expect(pixel.textDirection, TextDirection.ltr);
        expect(pixel.textAlign, TextAlign.right);
        expect(t.widget<Text>(find.text('لپ‌تاپ سارا')).textDirection,
            TextDirection.rtl);
        // The Send button sits on the left in RTL.
        expect(t.getCenter(find.byKey(const Key('sendFab'))).dx,
            lessThan(width / 2));
        expect(t.takeException(), isNull);

        // Details sheet: Persian labels, address left to right.
        await t.tap(find.byKey(const Key('details-fa77')));
        await t.pumpAndSettle();
        expect(find.text(fa.securityCode), findsOneWidget);
        expect(find.text(fa.detailsCableLink), findsNothing); // Wi-Fi IP
        expectLtrValue(t, const Key('peerAddress'));
        expectLtrValue(t, const Key('peerSecurityCode'));
        expectNoEnglish(t, 'details sheet');
        expect(t.takeException(), isNull);
        await t.tapAt(const Offset(10, 10));
        await t.pumpAndSettle();

        // Incoming dialog with a Persian sender and mixed file names.
        core.simulateIncoming(
            from: FakeCore.persianPeer,
            files: FakeCore.mixedFiles,
            autoProgress: false);
        await t.pumpAndSettle();
        expect(find.text(fa.incomingTitle(iso('لپ‌تاپ سارا'), 3)),
            findsOneWidget);
        expect(find.text('${fa.deviceKindComputer} · ${iso('Windows')}'),
            findsNWidgets(2)); // dialog + device row
        final pdf = t.widget<Text>(find.text(FakeCore.mixedFiles[0].fileName));
        expect(pdf.textDirection, TextDirection.rtl); // starts with Persian
        expect(find.text('عکس‌ها/'), findsOneWidget);
        expect(find.text(fa.fileCount(1)), findsOneWidget);
        expect(fa.fileCount(1), '۱ فایل');
        expect(find.text('۳٫۱ مگابایت'), findsOneWidget); // Persian digits
        expect(find.text(fa.incomingSavesTo(ltr('/tmp/landrop-test'))),
            findsOneWidget);
        expectNoEnglish(t, 'incoming dialog');
        expect(t.takeException(), isNull);
        await t.tap(find.text(fa.commonAccept));
        await t.pumpAndSettle();
        core.emitProgress(const TransferProgress('in-1', 'm1', 1000, 3250585,
            fileName: 'گزارش-final-نسخه-نهایی-2024.pdf'));
        await t.pump();
        await t.pump();
        expect(find.text(fa.homeActivity), findsOneWidget);
        expect(find.text(fa.transferFrom(iso('لپ‌تاپ سارا'))), findsOneWidget);
        expect(find.textContaining('مگابایت'), findsWidgets);
        expectNoEnglish(t, 'transfers');
        expect(t.takeException(), isNull);
        await t.pumpAndSettle();

        // Empty state.
        core.setPeers(const []);
        await t.pumpAndSettle();
        expect(find.text(fa.emptyTitle), findsOneWidget);
        expect(find.text(fa.emptyWhy), findsOneWidget);
        expectNoEnglish(t, 'empty home');
        expect(t.takeException(), isNull);
      });

      testWidgets('transfer cards in fa at $w px (U6)', (t) async {
        final c = AppController(
            core: FakeCore(simulateDelay: Duration.zero),
            store: MemorySettingsStore(),
            initialSaveDir: '/tmp/landrop-test',
            fileOpener: _NoOpener(canOpen: w > 400));
        addTearDown(c.dispose);
        final t0 = DateTime(2026, 10, 22);
        TransferSession make(String id,
            {bool incoming = true, bool? result, SendErrorCode? code}) {
          final s = TransferSession(
              sessionId: id,
              incoming: incoming,
              peerAlias: 'لپ‌تاپ سارا',
              peerFingerprint: 'fa77',
              savedTo: incoming ? '/tmp/landrop-test' : null,
              autoAccepted: id == 'auto');
          for (final f in FakeCore.mixedFiles) {
            s.files[f.id] = FileTransfer(f.id, f.fileName, f.size);
          }
          s.result = result;
          s.errorCode = code;
          return s;
        }

        final running = make('run')..files['m1']!.sent = 1000000;
        running.meter
          ..add(t0, 0)
          ..add(t0.add(const Duration(seconds: 2)), 1000000);
        final done = make('done');
        for (final f in done.files.values) {
          f
            ..sent = f.total
            ..done = true
            ..savedPath = '/tmp/landrop-test/${f.name}';
        }
        final auto = make('auto');
        final cancelled = make('cancel');
        for (final f in cancelled.files.values) {
          f
            ..done = true
            ..error = 'cancelled'
            ..errorCode = SendErrorCode.cancelled;
        }
        final sessions = [
          make('wait', incoming: false)..files.clear(),
          running,
          done,
          auto,
          cancelled,
          make('declined',
              incoming: false, result: false, code: SendErrorCode.declined),
          make('failed',
              incoming: false, result: false, code: SendErrorCode.unreachable),
          make('sent', incoming: false, result: true),
        ];
        t.view.physicalSize = Size(width, 4000);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(AppScope(
            controller: c,
            child: MaterialApp(
                locale: const Locale('fa'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                    body: ListView(children: [
                  for (final s in sessions) TransferSessionCard(session: s)
                ])))));
        // The waiting card's bar animates forever: no pumpAndSettle.
        await t.pump();
        await t.pump(const Duration(milliseconds: 100));
        expectRtl(t);
        String text(String key) => t.widget<Text>(find.byKey(Key(key))).data!;
        final name = iso('لپ‌تاپ سارا');
        expect(text('status-wait'), fa.transferWaiting(name));
        expect(text('status-run'),
            fa.transferPercentSpeed('۱۷', formatSpeed(500000, fa)));
        expect(text('timeLeft-run'),
            fa.transferTimeLeft(formatDuration(const Duration(seconds: 10), fa)));
        expect(text('title-done'), fa.transferReceivedFrom(name));
        expect(text('status-done'), fa.transferDone);
        expect(text('status-cancel'), fa.transferCancelled);
        expect(text('status-declined'), fa.transferDeclined(name));
        expect(text('status-failed'),
            fa.transferFailed(fa.sendErrorUnreachable));
        expect(text('title-sent'), fa.transferSentTo(name));
        expect(text('autoAccepted-auto'), fa.transferAutoAccepted);
        expect(find.text(fa.transferCancelAction), findsNWidgets(3));
        if (w > 400) {
          expect(find.byKey(const Key('open-done')), findsOneWidget);
          expect(find.text(fa.transferShowInFolder), findsOneWidget);
        } else {
          // Phone: the full path, left to right, with Copy.
          expect(find.byKey(const Key('copyPath-done')), findsOneWidget);
          expect(
              t.widget<SelectableText>(find.byKey(const Key('savedTo-done')))
                  .data,
              fa.transferSavedTo(ltr('/tmp/landrop-test')));
        }
        expectNoEnglish(t, 'transfer cards');
        expect(t.takeException(), isNull);
      });

      testWidgets('incoming dialog trust states in fa at $w px (U7)',
          (t) async {
        final core = persianCore();
        await pumpApp(
            t,
            localizedApp(
                locale: const Locale('fa'),
                core: core,
                store: MemorySettingsStore({
                  'locale': 'fa',
                  'trustedDevices': [
                    {
                      'fingerprint': 'aa11',
                      'alias': 'لپ‌تاپ سارا',
                      'trustedAt': '2026-10-01T10:00:00.000Z',
                      'autoAccept': false,
                    }
                  ],
                })),
            width: width,
            height: 900);
        // First time, and it uses the name of a trusted device.
        core.simulateIncoming(
            from: FakeCore.persianPeer,
            files: FakeCore.mixedFiles,
            autoProgress: false);
        await t.pumpAndSettle();
        expectRtl(t);
        expect(find.text(fa.incomingFirstTime), findsOneWidget);
        expect(find.text(fa.incomingAliasWarning(iso('لپ‌تاپ سارا'))),
            findsOneWidget);
        // No "Always accept" next to the name warning.
        expect(find.text(fa.incomingAlwaysAccept), findsNothing);
        expect(find.text(fa.incomingChangeFolder), findsOneWidget);
        await t.ensureVisible(find.byKey(const Key('incomingDetails')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('incomingDetails')));
        await t.pumpAndSettle();
        expectLtrValue(t, const Key('incomingAddress'));
        expectLtrValue(t, const Key('incomingSecurityCode'));
        expectNoEnglish(t, 'incoming dialog (first time, warning)');
        expect(t.takeException(), isNull);
        await t.tap(find.byKey(const Key('incomingDecline')));
        await t.pumpAndSettle();
        // Trusted device, then an unproven sender.
        core.simulateIncoming(autoProgress: false); // Pixel 9 = aa11
        await t.pumpAndSettle();
        expect(find.text(fa.incomingTrusted), findsOneWidget);
        expect(find.byKey(const Key('alwaysAccept')), findsNothing);
        expectNoEnglish(t, 'incoming dialog (trusted)');
        await t.tap(find.byKey(const Key('incomingDecline')));
        await t.pumpAndSettle();
        core.simulateIncoming(autoProgress: false, verified: false);
        await t.pumpAndSettle();
        expect(find.text(fa.incomingUnverified), findsOneWidget);
        expectNoEnglish(t, 'incoming dialog (unverified)');
        expect(t.takeException(), isNull);
        await t.tap(find.byKey(const Key('incomingDecline')));
        await t.pumpAndSettle();
      });

      testWidgets('trusted devices page and auto-accept notice in fa at $w px',
          (t) async {
        final core = persianCore();
        await pumpApp(
            t,
            localizedApp(
                locale: const Locale('fa'),
                core: core,
                store: MemorySettingsStore({
                  'locale': 'fa',
                  'trustedDevices': [
                    {
                      'fingerprint': 'fa77',
                      'alias': 'لپ‌تاپ سارا',
                      'displayName': 'Sara laptop',
                      'trustedAt': '2026-10-01T10:00:00.000Z',
                      'autoAccept': true,
                    }
                  ],
                })),
            width: width,
            height: 900);
        // Auto-accepted: no dialog, a Persian snackbar with Stop.
        core.simulateIncoming(
            from: FakeCore.persianPeer,
            files: FakeCore.mixedFiles,
            autoProgress: false);
        await t.pumpAndSettle();
        expect(find.byKey(const Key('incomingDialog')), findsNothing);
        expect(find.text(fa.autoAcceptedSnack(iso('لپ‌تاپ سارا'))),
            findsOneWidget);
        expect(find.text(fa.autoAcceptStop), findsWidgets);
        expectNoEnglish(t, 'auto-accept snackbar');
        expect(t.takeException(), isNull);
        ScaffoldMessenger.of(t.element(find.byType(Scaffold).first))
            .removeCurrentSnackBar();
        await t.pumpAndSettle();

        await _openSettings(t);
        expect(find.text(fa.settingsTrustedDevices), findsOneWidget);
        expect(find.text(fa.settingsTrustedDevicesSub(1)), findsOneWidget);
        await _tapKey(t, 'trustedDevicesSettings');
        expectRtl(t);
        expect(find.text('Sara laptop'), findsOneWidget);
        expect(find.text(fa.trustedDeviceName(iso('لپ‌تاپ سارا'))),
            findsOneWidget);
        expect(find.text(fa.trustedAutoAccept), findsOneWidget);
        expectLtrValue(t, const Key('trustedCode-fa77'));
        expectNoEnglish(t, 'trusted devices');
        expect(t.takeException(), isNull);
      });

      testWidgets('send sheet and device picker in fa at $w px', (t) async {
        await pumpLocalized(t,
            locale: const Locale('fa'),
            width: width,
            core: persianCore(),
            pickFiles: () async => ['/x/a.txt', '/x/b.txt']);
        await t.tap(find.byKey(const Key('sendFab')));
        await t.pumpAndSettle();
        expect(find.text(fa.sendSheetTitle), findsOneWidget);
        expectNoEnglish(t, 'send sheet');
        await t.tap(find.byKey(const Key('sendFiles')));
        await t.pumpAndSettle();
        expect(find.text(fa.sendPickerTitleFiles(2)), findsOneWidget);
        expect(fa.sendPickerTitleFiles(2), 'ارسال ۲ فایل به…');
        expectNoEnglish(t, 'device picker');
        expect(t.takeException(), isNull);
      });

      testWidgets('Settings and Advanced in fa at $w px', (t) async {
        await pumpLocalized(t,
            locale: const Locale('fa'), width: width, height: 900);
        await _openSettings(t);
        expectRtl(t);
        expect(find.text(fa.settingsSectionDevice), findsOneWidget);
        expect(find.text(fa.settingsAdvanced), findsOneWidget);
        expectLtrValue(t, const Key('saveFolderPath'));
        expectNoEnglish(t, 'Settings');
        expect(t.takeException(), isNull);
        await _tapKey(t, 'advancedSettings');
        expect(find.text(fa.securityCode), findsOneWidget);
        expect(find.text(fa.qrForLanDrop), findsOneWidget);
        expectLtrValue(t, const Key('selfUrl'));
        expectLtrValue(t, const Key('securityCodeValue'));
        expect(find.text(fa.serviceRunning), findsOneWidget);
        expectNoEnglish(t, 'Advanced (top)');
        await t.scrollUntilVisible(find.byKey(const Key('cableSettings')), 200,
            scrollable: find.byType(Scrollable).first);
        await t.pumpAndSettle();
        expect(find.text(fa.connectCableTitle), findsOneWidget);
        expectNoEnglish(t, 'Advanced (bottom)');
        expect(t.takeException(), isNull);
      });

      testWidgets('Shares page and share options in fa at $w px', (t) async {
        final core = await pumpLocalized(t,
            locale: const Locale('fa'),
            width: width,
            pickFiles: () async => ['/x/گزارش-final.pdf', '/x/notes.txt']);
        await t.tap(find.byKey(const Key('sharesAction')));
        await t.pumpAndSettle();
        expectRtl(t);
        expect(find.text(fa.sharesTitle), findsOneWidget);
        expect(find.text(fa.shareSendLinkTitle), findsOneWidget);
        expectNoEnglish(t, 'Shares page');
        expect(t.takeException(), isNull);
        await t.tap(find.byKey(const Key('shareFiles')));
        await t.pumpAndSettle();
        expect(find.text(fa.shareOptionsTitleFiles(2)), findsOneWidget);
        expect(find.text('۱۵ دقیقه'), findsOneWidget);
        expect(find.text('۵'), findsOneWidget);
        expectNoEnglish(t, 'share options');
        expect(t.takeException(), isNull);
        await t.tap(find.byKey(const Key('ttl-15m')));
        await t.tap(find.byKey(const Key('confirmShare')));
        await t.pumpAndSettle();
        final s = core.shares.single;
        expect(find.textContaining('گزارش-final.pdf'), findsOneWidget);
        expectLtrValue(t, Key('shareUrl-${s.id}'));
        expect(find.textContaining('دیگر تمام می‌شود'), findsOneWidget);
        await t.scrollUntilVisible(find.byKey(const Key('webUrl')), 200,
            scrollable: find.byType(Scrollable).first);
        await t.pumpAndSettle();
        expectLtrValue(t, const Key('webUrl'));
        expect(find.text(fa.browserSectionTitle), findsOneWidget);
        expectNoEnglish(t, 'Shares page with a share');
        expect(t.takeException(), isNull);
      });
    }

    // L4 / U4: the connection helper and every wizard in Persian.
    Future<void> scrollTo(WidgetTester t, String key) async {
      final f = find.byKey(Key(key));
      if (f.evaluate().isEmpty) {
        await t.scrollUntilVisible(f, 200,
            scrollable: find.byType(Scrollable).first);
      }
      await t.ensureVisible(f);
      await t.pumpAndSettle();
    }

    Future<void> tapKey(WidgetTester t, String key) async {
      await scrollTo(t, key);
      await t.tap(find.byKey(Key(key)));
      await t.pumpAndSettle();
    }

    String textOf(WidgetTester t, String key) {
      final w = t.widget(find.byKey(Key(key)));
      return w is Text ? w.data! : (w as SelectableText).data!;
    }

    for (final width in [375.0, 1000.0]) {
      final w = width.toInt();

      testWidgets('connection helper in fa at $w px', (t) async {
        final core = FakeCore(
            simulateDelay: const Duration(milliseconds: 10), initialPeers: [])
          ..scanFindsDevice = false
          ..diagnosisFindings = _sampleFindings();
        await pumpLocalized(t,
            locale: const Locale('fa'), width: width, height: 900, core: core);
        await _push(
            t,
            ConnectHelperPage(
                platform: HotspotPlatform.android,
                localAddresses: () async => ['192.168.43.20']));
        expectRtl(t);
        expect(find.text(fa.helperTitle), findsOneWidget);
        expect(find.byKey(const Key('helperResult')), findsOneWidget);
        expect(find.text(fa.helperQ1), findsOneWidget);
        expectNoEnglish(t, 'helper check');
        expect(t.takeException(), isNull);

        // Same Wi-Fi: checklist, nothing found, "connect directly".
        await tapKey(t, 'q1-same');
        expect(find.text(fa.helperChecklist), findsOneWidget);
        await tapKey(t, 'findDevice');
        expect(find.text(fa.findNothingTitle), findsOneWidget);
        await scrollTo(t, 'helperBlocked');
        expect(find.text(fa.helperBlocked), findsOneWidget);
        expectNoEnglish(t, 'helper same Wi-Fi');
        expect(t.takeException(), isNull);
        await tapKey(t, 'helperConnectDirectly');
        expect(find.text(fa.helperQ2), findsOneWidget);
        expectNoEnglish(t, 'helper question 2');

        // Android to Android: this phone shares a hotspot.
        await tapKey(t, 'q2-android');
        expect(find.text(fa.helperMethodShareQrTitle), findsOneWidget);
        expect(find.text(fa.helperRecommended), findsOneWidget);
        expect(textOf(t, 'helper-step-0'), fa.hotspotShareAndroid1);
        expectNoEnglish(t, 'helper method (top)');
        await scrollTo(t, 'alt-wifiDirect');
        expectNoEnglish(t, 'helper method (bottom)');
        expect(t.takeException(), isNull);
        await tapKey(t, 'alt-joinByQr');
        expect(find.text(fa.helperMethodJoinQrTitle), findsOneWidget);
        expectNoEnglish(t, 'helper QR join');

        // Try another way: a cable (USB tethering on a phone).
        await tapKey(t, 'helperTryAnother');
        await tapKey(t, 'q1-cable');
        expect(textOf(t, 'cable-step-0'), fa.cableUsbAndroid1);
        expectNoEnglish(t, 'helper cable');
        expect(t.takeException(), isNull);
      });

      testWidgets('hotspot wizard and hotspot card in fa at $w px',
          (t) async {
        const channel = MethodChannel(HotspotService.channelName);
        t.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
            (call) async {
          return switch (call.method) {
            'sdkInt' => 33,
            'start' => {
                'ssid': 'AndroidShare_7',
                'password': 'x;y12345',
                'gateway': '192.168.49.1'
              },
            _ => true,
          };
        });
        addTearDown(() => t.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null));
        await pumpLocalized(t,
            locale: const Locale('fa'),
            width: width,
            height: 900,
            hotspotService: HotspotService(
                android: true, requestPermission: (_) async => true));
        await _push(t, const HotspotWizardPage(platform: HotspotPlatform.linux));
        expectRtl(t);
        expect(find.text(fa.hotspotWizardTitle), findsOneWidget);
        expect(find.text(fa.wizardOnThisDevice(fa.platformLinux)),
            findsOneWidget);
        // The command stays a left-to-right island in the Persian step.
        expect(textOf(t, 'step-0'),
            fa.hotspotJoinLinux1(ltr(linuxJoinCommand)));
        expectNoEnglish(t, 'hotspot wizard');
        await tapKey(t, 'otherDevice');
        expect(find.text(fa.platformIos), findsOneWidget);
        expectNoEnglish(t, 'hotspot wizard, other device');
        await scrollTo(t, 'cableInstead');
        expectNoEnglish(t, 'hotspot wizard (bottom)');
        expect(t.takeException(), isNull);
        t.state<NavigatorState>(find.byType(Navigator).first).pop();
        await t.pumpAndSettle();

        await _push(
            t, const HotspotWizardPage(platform: HotspotPlatform.android));
        await tapKey(t, 'roleShare');
        await tapKey(t, 'startHotspot');
        // The controller waits a moment for the hotspot's address.
        await t.pump(const Duration(seconds: 2));
        await t.pumpAndSettle();
        expect(find.text(fa.hotspotOn), findsOneWidget);
        expect(textOf(t, 'hotspotSsid'), fa.hotspotName(ltr('AndroidShare_7')));
        expect(textOf(t, 'hotspotPassword'),
            fa.hotspotPassword(ltr('x;y12345')));
        expectNoEnglish(t, 'hotspot card');
        expect(t.takeException(), isNull);
      });

      testWidgets('cable wizard in fa at $w px', (t) async {
        final core = FakeCore(
            simulateDelay: const Duration(milliseconds: 10), initialPeers: [])
          ..scanFindsDevice = false
          ..diagnosisFindings = const [];
        await pumpLocalized(t,
            locale: const Locale('fa'), width: width, height: 900, core: core);
        await _push(
            t,
            CableWizardPage(
                platform: HotspotPlatform.windows,
                localAddresses: () async => ['169.254.3.4']));
        expectRtl(t);
        expect(find.text(fa.connectCableTitle), findsWidgets);
        expect(textOf(t, 'cable-step-1'), fa.cableEthWindows2(ltr('169.254')));
        expectNoEnglish(t, 'cable wizard');
        await tapKey(t, 'kindUsb');
        expect(find.text(fa.cableTetherHint), findsOneWidget);
        expectNoEnglish(t, 'cable wizard, USB');
        await tapKey(t, 'findDevice');
        expect(find.text(fa.cableNothingHint), findsOneWidget);
        expectNoEnglish(t, 'cable wizard, nothing found');
        expect(t.takeException(), isNull);
      });

      testWidgets('Wi-Fi Direct page in fa at $w px', (t) async {
        final svc = _FakeWifiDirect();
        final core = await pumpLocalized(t,
            locale: const Locale('fa'), width: width, height: 900);
        await _push(t, WifiDirectPage(service: svc));
        expectRtl(t);
        expect(find.text(fa.wifiDirectTitle), findsOneWidget);
        expect(find.text(fa.wifiDirectEmpty), findsOneWidget);
        expectNoEnglish(t, 'Wi-Fi Direct (empty)');
        svc.peersC.add(const [
          WifiDirectPeer('Pixel 9', 'aa:bb', 'available'),
          WifiDirectPeer('گوشی سارا', 'cc:dd', 'invited'),
        ]);
        await t.pumpAndSettle();
        expect(find.text(fa.wifiDirectStatusAvailable), findsOneWidget);
        expect(find.text(fa.wifiDirectInvited), findsOneWidget);
        expectNoEnglish(t, 'Wi-Fi Direct (peers)');
        svc.errorsC.add(wifiDirectError('busy'));
        await t.pumpAndSettle();
        expect(find.text(fa.errWifiDirectBusy), findsOneWidget);
        expectNoEnglish(t, 'Wi-Fi Direct (error)');
        core.probeAnswers['192.168.49.1'] = FakeCore.persianPeer;
        svc.statesC.add(const WifiDirectState(
            connected: true,
            ownerAddress: '192.168.49.1',
            ssid: 'DIRECT-xy-Pixel'));
        await t.pumpAndSettle();
        expect(find.text(fa.wifiDirectConnected), findsOneWidget);
        expect(textOf(t, 'wifiDirectHost'),
            fa.wifiDirectHost(ltr('192.168.49.1')));
        expect(textOf(t, 'wifiDirectSsid'),
            fa.wifiDirectNetwork(ltr('DIRECT-xy-Pixel')));
        expectNoEnglish(t, 'Wi-Fi Direct (connected)');
        expect(t.takeException(), isNull);
      });

      testWidgets('Join by QR page in fa at $w px', (t) async {
        await pumpLocalized(t,
            locale: const Locale('fa'), width: width, height: 900);
        await _push(
            t,
            WifiJoinPage(
                service: _FakeWifiJoin(camera: false),
                scannerBuilder: (_, _) => const SizedBox(),
                localAddresses: () async => ['192.168.43.20']));
        expectRtl(t);
        expect(find.text(fa.connectWifiJoinTitle), findsOneWidget);
        expect(find.text(fa.errWifiJoinCamera), findsOneWidget);
        expectNoEnglish(t, 'Join by QR (camera denied)');
        await tapKey(t, 'manualToggle');
        // Technical inputs: left to right, Persian digits become Latin.
        for (final k in ['manualSsid', 'manualPassword']) {
          expect(t.widget<TextField>(find.byKey(Key(k))).textDirection,
              TextDirection.ltr, reason: k);
        }
        await t.enterText(find.byKey(const Key('manualSsid')), 'Home ۴۲');
        await t.enterText(
            find.byKey(const Key('manualPassword')), 'pass۱۲۳۴۵');
        await t.pump();
        expect(
            t.widget<TextField>(find.byKey(const Key('manualSsid')))
                .controller!
                .text,
            'Home 42');
        expectNoEnglish(t, 'Join by QR (manual)');
        await tapKey(t, 'manualContinue');
        expect(textOf(t, 'joinConfirmTitle'),
            fa.wifiJoinConfirmTitle(ltr('Home 42')));
        expectNoEnglish(t, 'Join by QR (confirm)');
        await tapKey(t, 'joinButton');
        expect(textOf(t, 'joinedTitle'), fa.wifiJoinJoined(ltr('Home 42')));
        expectNoEnglish(t, 'Join by QR (joined)');
        expect(t.takeException(), isNull);
      });
    }

    test('service messages: English unchanged, Persian from the ARB', () {
      expect(hotspotMessage('busy'), 'A hotspot is already starting.');
      expect(hotspotMessage('permission', 'denied'),
          'Android refused: denied. On Android 12 and older, Location must '
          'also be switched on.');
      expect(hotspotMessage('permission'), contains('permission missing'));
      expect(hotspotMessage('weird', 'x'), 'The hotspot could not start: x.');
      expect(hotspotMessage('busy', null, fa), fa.errHotspotBusy);
      expect(
          const HotspotException('unsupported', 'x',
                  messageCode: 'permission-nearby')
              .localized(fa),
          fa.errHotspotPermissionNearby);
      expect(wifiJoinMessage('failed', 'boom'),
          'Could not join the network (boom). Try again, or join it in the '
          'Wi-Fi settings.');
      expect(wifiJoinError('timeout').localized(fa), fa.errWifiJoinTimeout);
      expect(wifiDirectMessage('error'),
          'Wi-Fi Direct failed. Turn Wi-Fi off and on, and try again.');
      expect(wifiDirectError('wifi-off').localized(fa), fa.errWifiDirectWifiOff);
      // A raw event-channel error stays as it is (technical).
      expect(const WifiDirectException('error', 'boom', detail: 'boom')
          .localized(fa), 'boom');
      expect(hotspotPlatformName(HotspotPlatform.ios), 'iPhone / iPad');
      expect(hotspotPlatformName(HotspotPlatform.ios, fa), fa.platformIos);
      expect(hotspotSteps(HotspotPlatform.windows, HotspotRole.share, fa),
          [fa.hotspotShareWindows1, fa.hotspotShareWindows2]);
      expect(cableSteps(HotspotPlatform.linux, CableKind.ethernet, fa)[1],
          fa.cableEthLinux2(ltr(linuxLinkLocalCommand)));
      // English steps keep the plain command (no isolates).
      expect(cableSteps(HotspotPlatform.linux, CableKind.ethernet)[1],
          endsWith('Or run: $linuxLinkLocalCommand'));
    });

    testWidgets('Add by IP: LTR field, Persian digits become Latin',
        (t) async {
      final core = await pumpLocalized(t,
          locale: const Locale('fa'), width: 375);
      await _tapKey(t, 'addByIp');
      expect(find.text(fa.addByIpTitle), findsOneWidget);
      final field = find.byKey(const Key('addByIpField'));
      expect(t.widget<TextField>(field).textDirection, TextDirection.ltr);
      await t.enterText(field, '۱۹۲٫۱۶۸٫۱٫۷');
      await t.pump();
      expect(t.widget<TextField>(field).controller!.text, '192.168.1.7');
      await t.tap(find.text(fa.addByIpAdd));
      await t.pumpAndSettle();
      expect(core.started, isTrue);
      expect(find.text('Device at 192.168.1.7'), findsOneWidget);
    });

    testWidgets('pairing dialog in fa keeps the code Latin and LTR',
        (t) async {
      final core = await pumpLocalized(t, locale: const Locale('fa'), width: 375);
      core.simulatePairing();
      await t.pumpAndSettle();
      expect(find.text(fa.pairingTitle), findsOneWidget);
      expect(find.text('4821'), findsOneWidget);
      expectLtrValue(t, const Key('pairingCode'));
      expectNoEnglish(t, 'pairing dialog');
      expect(t.takeException(), isNull);
    });

    test('copied report stays English with one Persian line on top', () {
      expect(fa.diagReportNote, contains('انگلیسی'));
      expect(en.diagReportNote, isNot(fa.diagReportNote));
    });
  });

  group('formatters', () {
    test('English output is unchanged', () {
      expect(formatBytes(500), '500 B');
      expect(formatBytes(1288490189), '1.2 GB');
      expect(formatBytes(500, en), '500 B');
      expect(formatBytes(1288490189, en), '1.2 GB');
      expect(formatBytes(250 * 1024 * 1024, en), '250 MB');
      expect(formatSpeed(3250585), '3.1 MB/s');
      expect(formatSpeed(3250585, en), '3.1 MB/s');
      expect(formatDuration(const Duration(seconds: 45)), '45 s');
      expect(formatDuration(const Duration(minutes: 5, seconds: 9), en),
          '5 min');
      expect(formatDuration(const Duration(hours: 1, minutes: 20)),
          '1 h 20 min');
      expect(formatDuration(const Duration(hours: 2), en), '2 h');
    });

    test('Persian units and digits', () {
      expect(formatBytes(500, fa), '۵۰۰ بایت');
      expect(formatBytes(3250585, fa), '۳٫۱ مگابایت');
      expect(formatBytes(2048, fa), '۲٫۰ کیلوبایت');
      expect(formatBytes(1288490189, fa), '۱٫۲ گیگابایت');
      expect(formatSpeed(3250585, fa), '۳٫۱ مگابایت بر ثانیه');
      expect(formatDuration(const Duration(seconds: 45), fa), '۴۵ ثانیه');
      expect(formatDuration(const Duration(minutes: 12), fa), '۱۲ دقیقه');
      expect(formatDuration(const Duration(hours: 1, minutes: 20), fa),
          '۱ ساعت و ۲۰ دقیقه');
      expect(formatDuration(const Duration(hours: 3), fa), '۳ ساعت');
    });

    test('transfer progress, speed and time left in en and fa (U6)', () {
      expect(formatTransferProgress(0.64, null), '64%');
      expect(formatTransferProgress(0.64, null, en), '64%');
      expect(formatTransferProgress(0.999, 4404019, en), '99% · 4.2 MB/s');
      expect(formatTransferProgress(1, 512 * 1024.0, en), '100% · 512 KB/s');
      expect(formatTimeLeft(const Duration(seconds: 80)), '1 min left');
      expect(formatTimeLeft(const Duration(seconds: 80), en), '1 min left');
      expect(formatTimeLeft(const Duration(seconds: 9), en), '9 s left');
      expect(formatTimeLeft(const Duration(hours: 1, minutes: 5), en),
          '1 h 5 min left');
      expect(formatTransferProgress(0.64, null, fa), '٪۶۴');
      expect(formatTransferProgress(0.999, 4404019, fa),
          '٪۹۹ · ۴٫۲ مگابایت بر ثانیه');
      expect(formatTimeLeft(const Duration(seconds: 80), fa), '۱ دقیقه مانده');
      expect(formatTimeLeft(const Duration(seconds: 9), fa), '۹ ثانیه مانده');
      expect(formatTimeLeft(const Duration(hours: 1, minutes: 5), fa),
          '۱ ساعت و ۵ دقیقه مانده');
      // Clamped: never below 0 or above 100.
      expect(formatTransferProgress(1.7, null, en), '100%');
      expect(formatTransferProgress(-1, null, fa), '٪۰');
    });

    test('localizeDigits only changes Persian', () {
      expect(localizeDigits('12 files, 3.5', const Locale('en')),
          '12 files, 3.5');
      expect(localizeDigits('12 فایل', const Locale('fa')), '۱۲ فایل');
      expect(localizeDigits('3.5', const Locale('fa')), '۳٫۵');
      expect(localizeDigits('end.', const Locale('fa')), 'end.');
    });

    test('normalizeDigits makes typed Persian/Arabic digits Latin', () {
      expect(normalizeDigits('۱۹۲.۱۶۸.۱.۱۰'), '192.168.1.10');
      expect(normalizeDigits('٥٣٣١٧'), '53317');
      expect(normalizeDigits('۱۹۲٫۱۶۸٫۱٫۱۰:۵۳۳۱۷'), '192.168.1.10:53317');
      expect(normalizeDigits('Pixel 9'), 'Pixel 9');
      expect(normalizeDigits('کد ۴۸۲۱'), 'کد 4821');
    });
  });

  group('bidi helpers', () {
    testWidgets('LtrText is left to right inside an RTL layout', (t) async {
      await t.pumpWidget(const Directionality(
        textDirection: TextDirection.rtl,
        child: Column(children: [
          LtrText('192.168.1.10:53317', key: Key('ip')),
          LtrText('https://192.168.1.10:53317',
              key: Key('url'), selectable: true),
        ]),
      ));
      final text = t.widget<Text>(
          find.descendant(of: find.byKey(const Key('ip')), matching: find.byType(Text)));
      expect(text.textDirection, TextDirection.ltr);
      expect(text.textAlign, TextAlign.right); // start of the RTL layout
      expect(
          Directionality.of(t.element(find.byType(Text).first)),
          TextDirection.ltr);
      final sel = t.widget<SelectableText>(find.byType(SelectableText));
      expect(sel.textDirection, TextDirection.ltr);
    });

    testWidgets('LtrText aligns left in an LTR layout', (t) async {
      await t.pumpWidget(const Directionality(
          textDirection: TextDirection.ltr, child: LtrText('10.0.0.8')));
      expect(t.widget<Text>(find.byType(Text)).textAlign, TextAlign.left);
    });

    test('ltr / iso wrap in isolates; stripIsolates removes them', () {
      expect(ltr('10.0.0.8:5000'), '\u206610.0.0.8:5000\u2069');
      expect(iso('لپ‌تاپ Ali'), '\u2068لپ‌تاپ Ali\u2069');
      expect(stripIsolates('x ${ltr('1.2.3.4')} ${iso('a')}'), 'x 1.2.3.4 a');
    });

    test('ltrValue / isoName isolate only where needed; digits', () {
      expect(en.ltrValue('10.0.0.8:5000'), '10.0.0.8:5000');
      expect(fa.ltrValue('10.0.0.8:5000'), ltr('10.0.0.8:5000'));
      expect(en.isoName('Pixel 9'), 'Pixel 9');
      // A Persian name is isolated even inside English text.
      expect(en.isoName('لپ‌تاپ سارا'), iso('لپ‌تاپ سارا'));
      expect(fa.isoName('Pixel 9'), iso('Pixel 9'));
      expect(en.digits(12), '12');
      expect(fa.digits(12), '۱۲');
      expect(fa.isRtl, isTrue);
      expect(en.isRtl, isFalse);
    });

    test('firstStrongDirection and shortFolder', () {
      expect(firstStrongDirection('گزارش-final.pdf'), TextDirection.rtl);
      expect(firstStrongDirection('2024-گزارش.pdf'), TextDirection.rtl);
      expect(firstStrongDirection('report-نهایی.pdf'), TextDirection.ltr);
      expect(firstStrongDirection('2024.txt'), TextDirection.ltr);
      expect(firstStrongDirection('123'), isNull);
      expect(shortFolder('/storage/emulated/0/Download/LanDrop'),
          'Download/LanDrop');
      expect(shortFolder(r'C:\Users\sara\Downloads'), 'sara/Downloads');
      expect(shortFolder('/tmp'), '/tmp');
    });

    testWidgets('AutoDirText: own direction, start of the outer layout, '
        'middle ellipsis for file names', (t) async {
      final long = 'holiday-in-kish-with-family-2024-final-version.jpg';
      await t.pumpWidget(Directionality(
        textDirection: TextDirection.rtl,
        child: Column(children: [
          const AutoDirText('Work Laptop', key: Key('latin')),
          const AutoDirText('لپ‌تاپ سارا', key: Key('persian')),
          AutoDirText(long, key: const Key('file'), fileName: true, maxChars: 20),
        ]),
      ));
      Text text(String k) => t.widget<Text>(find.descendant(
          of: find.byKey(Key(k)), matching: find.byType(Text)));
      expect(text('latin').textDirection, TextDirection.ltr);
      expect(text('latin').textAlign, TextAlign.right);
      expect(text('persian').textDirection, TextDirection.rtl);
      expect(text('file').data, middleEllipsis(long, max: 20));
      expect(text('file').data, endsWith('.jpg'));
    });

    test('middleEllipsis keeps the extension visible', () {
      expect(middleEllipsis('short.txt', max: 20), 'short.txt');
      final m = middleEllipsis('holiday-in-kish-2024-final.jpg', max: 20);
      expect(m.length, 20);
      expect(m, startsWith('holiday-in-'));
      expect(m, endsWith('inal.jpg'));
      expect(m, contains('…'));
      final noExt = middleEllipsis('a' * 40, max: 12);
      expect(noExt.length, 12);
      expect(noExt, contains('…'));
      final longExt = middleEllipsis('report-2024-final.markdown', max: 16);
      expect(longExt, endsWith('.markdown'));
      expect(longExt.length, 16);
      // Never splits a surrogate pair / grapheme.
      final emoji = middleEllipsis('😀' * 30, max: 10);
      expect(emoji.characters.length, 10);
      expect(emoji.characters.every((c) => c == '😀' || c == '…'), isTrue);
    });
  });
}
