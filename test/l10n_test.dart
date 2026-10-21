// Localization infrastructure (docs/UX.md section 4, steps L1/L5/R1).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/core/api.dart';
import 'package:landrop/core/diagnosis.dart';
import 'package:landrop/l10n/app_localizations.dart';
import 'package:landrop/ui/app_controller.dart';
import 'package:landrop/ui/digits.dart';
import 'package:landrop/ui/fake_core.dart';
import 'package:landrop/ui/finding_text.dart';
import 'package:landrop/ui/format.dart';
import 'package:landrop/ui/ltr_text.dart';

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

Future<void> _openSettings(WidgetTester t) async {
  await t.tap(find.byTooltip('Settings'));
  await t.pumpAndSettle();
}

Future<void> _openDiagnosis(WidgetTester t) async {
  await _openSettings(t);
  await t.ensureVisible(find.byKey(const Key('diagnoseSettings')));
  await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('diagnoseSettings')));
  await t.pumpAndSettle();
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
        // Technical details stay English.
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
