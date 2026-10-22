// Nearby shares (docs/NEARBY_PLAN.md). Step 1: model, persistence and the
// browser side.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/l10n/app_localizations.dart';

import 'helpers/nearby_harness.dart';
import 'helpers/pump_localized.dart' as pl;

void main() {
  final env = NearbyEnv();
  // The widget binding replaces HttpClient with a stub that answers 400.
  setUpAll(() => HttpOverrides.global = null);
  setUp(env.setUp);
  tearDown(env.tearDown);

  group('N1 nearby flag', () {
    test(
      'persists across a restart; a missing or non-bool key restores false',
      () async {
        final store = '${env.tmp.path}/shares.json';
        final a = await env.startCore(nearbyOpts(sharesStorePath: store));
        final f = env.file('a.txt', [1, 2, 3]);
        final on = a.createShare([f.path], nearby: true);
        final off = a.createShare([f.path]);
        expect(on.nearby, isTrue);
        expect(off.nearby, isFalse);
        await env.drop(a);

        final b = await env.startCore(
          nearbyOpts(sharesStorePath: store),
          name: 'b',
        );
        expect(b.shares.firstWhere((s) => s.id == on.id).nearby, isTrue);
        expect(b.shares.firstWhere((s) => s.id == off.id).nearby, isFalse);
        // The other three: toggled later, key removed, wrong type.
        b.setShareNearby(off.id, true);
        await env.drop(b);
        final json = jsonDecode(File(store).readAsStringSync()) as Map;
        final list = json['shares'] as List;
        expect(list.every((s) => s['nearby'] == true), isTrue);
        (list[0] as Map).remove('nearby');
        (list[1] as Map)['nearby'] = 'yes';
        File(store).writeAsStringSync(jsonEncode(json));

        final c = await env.startCore(
          nearbyOpts(sharesStorePath: store),
          name: 'c',
        );
        expect(c.shares, hasLength(2));
        expect(c.shares.every((s) => !s.nearby), isTrue);
      },
    );
  });

  group('browser side', () {
    test('N3 non-nearby shares are hidden from the browser list', () async {
      final a = await env.startCore(nearbyOpts());
      final token = await env.pair(a);
      final f = env.file('hidden.txt', [1]);
      final g = env.file('shown.txt', [2, 2]);
      final hidden = a.createShare([f.path]);
      final shown = a.createShare([g.path], nearby: true);
      final r = await ncall(
        'GET',
        '${env.base(a)}$nearbyApi/web/nearby',
        headers: cookie(token),
      );
      expect(r.status, 200);
      final shares = r.json!['shares'] as List;
      expect(shares.map((s) => s['id']), [shown.id]);
      expect(r.text, isNot(contains('hidden.txt')));
      // The hidden share's file is not reachable through the nearby route.
      final hf = await ncall(
        'GET',
        '${env.base(a)}$nearbyApi/web/nearby/${hidden.id}/files/${hidden.files.single.id}',
        headers: cookie(token),
      );
      expect(hf.status, 404);
    });

    test(
      'N9 paired session lists and streams with Range; unpaired gets 401',
      () async {
        final a = await env.startCore(nearbyOpts());
        final token = await env.pair(a);
        final data = List<int>.generate(5000, (i) => i % 251);
        final f = env.file('clip.mp4', data);
        final s = a.createShare([f.path], nearby: true);
        final list = await ncall(
          'GET',
          '${env.base(a)}$nearbyApi/web/nearby',
          headers: cookie(token),
        );
        expect(list.status, 200);
        final entry = (list.json!['shares'] as List).single as Map;
        expect(entry['truncated'], isFalse);
        final file = (entry['files'] as List).single as Map;
        expect(file['name'], 'clip.mp4');
        expect(file['size'], 5000);
        expect(file['mime'], startsWith('video/'));

        final url =
            '${env.base(a)}$nearbyApi/web/nearby/${s.id}/files/${file['id']}';
        final full = await ncall('GET', url, headers: cookie(token));
        expect(full.status, 200);
        expect(full.body, data);
        final part = await ncall(
          'GET',
          url,
          headers: {...cookie(token), 'range': 'bytes=100-199'},
        );
        expect(part.status, 206);
        expect(part.h('content-range'), 'bytes 100-199/5000');
        expect(part.body, data.sublist(100, 200));
        final bad = await ncall(
          'GET',
          url,
          headers: {...cookie(token), 'range': 'bytes=9000-'},
        );
        expect(bad.status, 416);
        final head = await ncall('HEAD', url, headers: cookie(token));
        expect(head.status, 200);
        expect(head.body, isEmpty);

        // Unpaired: 401 for both.
        expect(
          (await ncall('GET', '${env.base(a)}$nearbyApi/web/nearby')).status,
          401,
        );
        expect((await ncall('GET', url)).status, 401);
        expect(
          (await ncall('GET', url, headers: cookie('not-a-session'))).status,
          401,
        );
      },
    );

    test('toggling setShareNearby(false) hides a share at once, true shows it', () async {
      final a = await env.startCore(nearbyOpts());
      final token = await env.pair(a);
      final s = a.createShare([
        env.file('t.txt', [1, 2]).path,
      ], nearby: true);
      final url =
          '${env.base(a)}$nearbyApi/web/nearby/${s.id}/files/${s.files.single.id}';
      Future<int> listed() async =>
          ((await ncall(
                    'GET',
                    '${env.base(a)}$nearbyApi/web/nearby',
                    headers: cookie(token),
                  )).json!['shares']
                  as List)
              .length;
      expect(await listed(), 1);
      expect((await ncall('GET', url, headers: cookie(token))).status, 200);
      a.setShareNearby(s.id, false);
      expect(a.shares.single.nearby, isFalse);
      expect(await listed(), 0);
      expect((await ncall('GET', url, headers: cookie(token))).status, 404);
      a.setShareNearby(s.id, true);
      expect(await listed(), 1);
      // The normal token link is independent of the flag.
      expect(
        (await ncall(
          'GET',
          '${env.base(a)}$nearbyApi/shares/${s.token}/files/${s.files.single.id}',
        )).status,
        200,
      );
    });

    test('revoked shares are not listed', () async {
      final a = await env.startCore(nearbyOpts());
      final token = await env.pair(a);
      final f = env.file('u.txt', [1]);
      final s = a.createShare([f.path], nearby: true);
      a.revokeShare(s.id);
      a.createShare([f.path], nearby: true, ttl: const Duration(hours: 1));
      final r = await ncall(
        'GET',
        '${env.base(a)}$nearbyApi/web/nearby',
        headers: cookie(token),
      );
      expect((r.json!['shares'] as List), hasLength(1));
    });
  });

  group('share options toggle', () {
    for (final code in ['en', 'fa']) {
      testWidgets('default OFF, creates nearby share when on ($code, 375 px)', (
        t,
      ) async {
        final l = lookupAppLocalizations(Locale(code));
        final core = await pl.pumpLocalized(
          t,
          locale: Locale(code),
          width: 375,
          height: 800,
          pickFiles: () async => ['/x/a.txt'],
        );
        await t.tap(find.byKey(const Key('sharesAction')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('shareFiles')));
        await t.pumpAndSettle();
        final toggle = find.byKey(const Key('shareNearbyToggle'));
        await t.ensureVisible(toggle);
        expect(find.text(l.shareShowNearby), findsOneWidget);
        expect(find.text(l.shareShowNearbyHint), findsOneWidget);
        expect(t.widget<SwitchListTile>(toggle).value, isFalse);
        await t.tap(toggle);
        await t.pump();
        expect(t.widget<SwitchListTile>(toggle).value, isTrue);
        await t.tap(find.byKey(const Key('confirmShare')));
        await t.pumpAndSettle();
        expect(core.shareNearbyCalls, [true]);
        expect(core.shares.single.nearby, isTrue);

        // The same switch on the active share turns it off again.
        final card = find.byKey(Key('nearbyToggle-${core.shares.single.id}'));
        await t.ensureVisible(card);
        expect(t.widget<SwitchListTile>(card).value, isTrue);
        await t.tap(card);
        await t.pumpAndSettle();
        expect(core.shares.single.nearby, isFalse);
      });
    }

    testWidgets('left alone it creates a normal share (nearby false)', (
      t,
    ) async {
      final core = await pl.pumpLocalized(
        t,
        width: 375,
        height: 800,
        pickFiles: () async => ['/x/a.txt'],
      );
      await t.tap(find.byKey(const Key('sharesAction')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('shareFiles')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('confirmShare')));
      await t.pumpAndSettle();
      expect(core.shareNearbyCalls, [false]);
      expect(core.shares.single.nearby, isFalse);
    });
  });
}
