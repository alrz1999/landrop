// Nearby shares (docs/NEARBY_PLAN.md). Step 1: model, persistence and the
// browser side.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/core/api.dart';
import 'package:landrop/core/landrop_core.dart';
import 'package:landrop/l10n/app_localizations.dart';
import 'package:landrop/ui/app_controller.dart';
import 'package:landrop/ui/fake_core.dart';

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

  group('app protocol (server side)', () {
    final id0 = testIdentity(0);
    setUpAll(() => testIdentity(0));

    test('N5 Range through a ticket gives 206 with the right bytes', () async {
      final bytes = List<int>.generate(256, (i) => i);
      final a = await env.startCore(nearbyOpts());
      final s = a.createShare([env.file('r.bin', bytes).path], nearby: true);
      a.setNearbyTrusted({id0.fingerprint});
      final r = await nearbyList(env.base(a), a, id0);
      final ticket = r.json!['ticket'] as String;
      final url = nearbyFileUrl(env.base(a), s.id, s.files.single.id);
      final part = await ncall(
        'GET',
        url,
        headers: {...ticketHeader(ticket), 'range': 'bytes=10-19'},
      );
      expect(part.status, 206);
      expect(part.body, bytes.sublist(10, 20));
      expect(part.h('content-range'), 'bytes 10-19/256');
      final whole = await ncall('GET', url, headers: ticketHeader(ticket));
      expect(whole.status, 200);
      expect(whole.body, bytes);
      final bad = await ncall(
        'GET',
        url,
        headers: {...ticketHeader(ticket), 'range': 'bytes=999-'},
      );
      expect(bad.status, 416);
    });

    test('N6 the download limit applies to ticket downloads', () async {
      final a = await env.startCore(nearbyOpts());
      final s = a.createShare(
        [env.file('l.bin', [5, 6, 7]).path],
        nearby: true,
        maxDownloads: 1,
      );
      a.setNearbyTrusted({id0.fingerprint});
      final ticket =
          (await nearbyList(env.base(a), a, id0)).json!['ticket'] as String;
      final url = nearbyFileUrl(env.base(a), s.id, s.files.single.id);
      final first = await ncall('GET', url, headers: ticketHeader(ticket));
      expect(first.status, 200);
      expect(first.body, [5, 6, 7]);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(
        (await ncall('GET', url, headers: ticketHeader(ticket))).status,
        404,
      );
      // Used up: no longer listed either.
      expect(
        (await nearbyList(env.base(a), a, id0)).text,
        emptyNearbyBody,
      );
    });

    group('N7 owner prompt (server part)', () {
      late DateTime now;
      setUp(() => now = DateTime.now());

      Future<(dynamic, List<NearbyAccessRequest>)> setup({
        bool nearby = true,
      }) async {
        final a = await env.startCore(nearbyOpts(clock: () => now));
        a.createShare([env.file('p.bin', [1, 2]).path], nearby: nearby);
        final asked = <NearbyAccessRequest>[];
        final sub = a.nearbyRequests.listen(asked.add);
        addTearDown(sub.cancel);
        return (a, asked);
      }

      Future<void> settle() =>
          Future<void>.delayed(const Duration(milliseconds: 30));

      test('asks once; allowOnce lets the next list succeed', () async {
        final (a0, asked) = await setup();
        final a = a0 as LanDropCoreImpl;
        final base = env.base(a);
        expect((await nearbyList(base, a, id0, alias: 'Tester')).text,
            emptyNearbyBody);
        await settle();
        expect(asked, hasLength(1));
        expect(asked.single.fingerprint, id0.fingerprint);
        expect(asked.single.alias, 'Tester');
        expect(asked.single.remoteIp, '127.0.0.1');
        // Still pending: no second prompt, still the empty body.
        expect((await nearbyList(base, a, id0)).text, emptyNearbyBody);
        await settle();
        expect(asked, hasLength(1));
        a.respondNearbyAccess(asked.single.id, NearbyDecision.allowOnce);
        final r = await nearbyList(base, a, id0);
        expect(r.json!['ticket'], isNotNull);
        expect(r.json!['shares'], hasLength(1));
        // The grant is one hour: gone after that.
        now = now.add(const Duration(hours: 1, seconds: 1));
        expect((await nearbyList(base, a, id0)).text, emptyNearbyBody);
        await settle();
        expect(asked, hasLength(2)); // asks again
      });

      test('no prompt without a nearby share', () async {
        final (a0, asked) = await setup(nearby: false);
        final a = a0 as LanDropCoreImpl;
        expect((await nearbyList(env.base(a), a, id0)).text, emptyNearbyBody);
        await settle();
        expect(asked, isEmpty);
      });

      test('no prompt without a listener', () async {
        final a = await env.startCore(nearbyOpts(clock: () => now));
        a.createShare([env.file('q.bin', [1]).path], nearby: true);
        expect((await nearbyList(env.base(a), a, id0)).text, emptyNearbyBody);
        // Someone starts listening later: still nothing was queued.
        final asked = <NearbyAccessRequest>[];
        final sub = a.nearbyRequests.listen(asked.add);
        await settle();
        expect(asked, isEmpty);
        await sub.cancel();
      });

      test('deny: silent for 10 minutes, then asks again', () async {
        final (a0, asked) = await setup();
        final a = a0 as LanDropCoreImpl;
        final base = env.base(a);
        await nearbyList(base, a, id0);
        await settle();
        a.respondNearbyAccess(asked.single.id, NearbyDecision.deny);
        now = now.add(const Duration(minutes: 9));
        expect((await nearbyList(base, a, id0)).text, emptyNearbyBody);
        await settle();
        expect(asked, hasLength(1));
        now = now.add(const Duration(minutes: 2));
        expect((await nearbyList(base, a, id0)).text, emptyNearbyBody);
        await settle();
        expect(asked, hasLength(2));
      });

      test('at most 3 prompts pending', () async {
        final (a0, asked) = await setup();
        final a = a0 as LanDropCoreImpl;
        for (var i = 0; i < 4; i++) {
          final id = testIdentity(i);
          await nearbyList(env.base(a), a, id);
        }
        await settle();
        expect(asked, hasLength(3));
      });
    });
  });

  group('app client (step 3)', () {
    Future<(LanDropCoreImpl, LanDropCoreImpl)> twoCores({
      DateTime Function()? clock,
      Future<int?> Function(String dir)? freeSpace,
      bool trust = true,
    }) async {
      final a = await env.startCore(nearbyOpts(clock: clock), name: 'a');
      final b = await env.startCore(nearbyOpts(freeSpace: freeSpace), name: 'b');
      if (trust) a.setNearbyTrusted({b.self.fingerprint});
      return (a, b);
    }

    Directory saveOf(String name) => Directory('${env.tmp.path}/$name-save');

    List<String> names(Directory d) => [
      for (final e in d.listSync(recursive: true, followLinks: false))
        e.path.substring(d.path.length + 1),
    ]..sort();

    /// Downloads every file of [listing]; returns the session id and events.
    Future<(String, List<TransferProgress>)> downloadAll(
      LanDropCoreImpl b,
      DeviceInfo peer,
      NearbyListing listing,
    ) async {
      final events = <TransferProgress>[];
      final sub = b.progress.listen(events.add);
      String? sid;
      await b.downloadNearby(peer, listing, [
        for (final sh in listing.shares)
          for (final f in sh.files) (sh.id, f.id),
      ], onSession: (id) => sid = id);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();
      return (sid!, events.where((e) => e.sessionId == sid).toList());
    }

    test('N2 a trusted app lists the nearby shares (names, sizes, ticket)',
        () async {
      final (a, b) = await twoCores();
      final s = a.createShare([
        env.file('one.txt', [1, 2, 3]).path,
        env.file('two.bin', List.filled(70000, 7)).path,
      ], nearby: true);
      a.createShare([env.file('private.txt', [9]).path]); // not nearby
      final l = await b.listNearbyShares(a.self);
      expect(l.peerFingerprint, a.self.fingerprint);
      expect(l.ticket, isNotNull);
      expect(l.ticket, startsWith('lt1.'));
      expect(l.ticketExpires, isNotNull);
      expect(l.shares, hasLength(1));
      expect(l.shares.single.id, s.id);
      expect(l.shares.single.truncated, isFalse);
      final files = {for (final f in l.shares.single.files) f.name: f.size};
      expect(files, {'one.txt': 3, 'two.bin': 70000});
      expect(l.shares.single.files.map((f) => f.mime).toSet(),
          contains('text/plain'));
    });

    test('listNearbyShares without an identity is a StateError', () async {
      final c = LanDropCoreImpl(nearbyOpts());
      addTearDown(c.dispose);
      await expectLater(
          c.listNearbyShares(const DeviceInfo(
              alias: 'x',
              deviceType: 'desktop',
              fingerprint:
                  'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
              ip: '127.0.0.1')),
          throwsStateError);
    });

    test('N4 download via ticket: same bytes, progress, unique names, no .part',
        () async {
      final (a, b) = await twoCores();
      final rnd = Random(4);
      final big = List<int>.generate(1500000, (_) => rnd.nextInt(256));
      final small = [1, 2, 3];
      a.createShare([
        env.file('big.bin', big).path,
        env.file('small.txt', small).path,
      ], nearby: true);
      // A file with the same name already exists in B's save folder.
      File('${saveOf('b').path}/small.txt').writeAsBytesSync([42]);
      final l = await b.listNearbyShares(a.self);
      final (sid, ev) = await downloadAll(b, a.self, l);
      final done = ev.where((e) => e.done).toList();
      expect(done, hasLength(2));
      expect(done.every((e) => e.error == null), isTrue);
      expect(ev.any((e) => !e.done && e.sentBytes > 0), isTrue);
      expect(ev.every((e) => e.sessionId == sid), isTrue);
      final saved = {
        for (final e in done) e.fileName!: File(e.savedPath!).readAsBytesSync()
      };
      expect(saved['big.bin'], big);
      expect(saved['small.txt'], small);
      expect(File('${saveOf('b').path}/small.txt').readAsBytesSync(), [42]);
      expect(names(saveOf('b')),
          unorderedEquals(['big.bin', 'small.txt', 'small (1).txt']));
      expect(names(saveOf('b')).where((n) => n.endsWith('.part')), isEmpty);
    });

    test('N4 folder-style names keep their structure; a second copy gets a new top folder',
        () async {
      final (a, b) = await twoCores();
      final dir = Directory('${env.tmp.path}/Album/sub')..createSync(recursive: true);
      File('${dir.path}/x.bin').writeAsBytesSync([1, 1]);
      File('${env.tmp.path}/Album/y.bin').writeAsBytesSync([2]);
      a.createShare(['${env.tmp.path}/Album'], nearby: true);
      final l = await b.listNearbyShares(a.self);
      expect(l.shares.single.files.map((f) => f.name),
          unorderedEquals(['Album/sub/x.bin', 'Album/y.bin']));
      await downloadAll(b, a.self, l);
      expect(names(saveOf('b')), unorderedEquals([
        'Album', 'Album/sub', 'Album/sub/x.bin', 'Album/y.bin',
      ]));
      expect(File('${saveOf('b').path}/Album/sub/x.bin').readAsBytesSync(), [1, 1]);
      await downloadAll(b, a.self, await b.listNearbyShares(a.self));
      expect(names(saveOf('b')).where((n) => n.startsWith('Album (1)')),
          unorderedEquals(['Album (1)', 'Album (1)/sub', 'Album (1)/sub/x.bin', 'Album (1)/y.bin']));
    });

    test('N4 not enough free space: every file fails with diskError, nothing written',
        () async {
      final (a, b) = await twoCores(freeSpace: (_) async => 1000);
      a.createShare([env.file('f.bin', [1, 2, 3]).path], nearby: true);
      final l = await b.listNearbyShares(a.self);
      final (_, ev) = await downloadAll(b, a.self, l);
      final done = ev.where((e) => e.done).single;
      expect(done.errorCode, SendErrorCode.diskError);
      expect(names(saveOf('b')), isEmpty);
    });

    group('N7 owner prompt (client half)', () {
      test('an untrusted app triggers one prompt and gets nothing; allowOnce then shows the share',
          () async {
        final (a, b) = await twoCores(trust: false);
        a.createShare([env.file('p.txt', [1, 2]).path], nearby: true);
        final asked = <NearbyAccessRequest>[];
        final sub = a.nearbyRequests.listen(asked.add);
        addTearDown(sub.cancel);
        final first = await b.listNearbyShares(a.self);
        expect(first.shares, isEmpty);
        expect(first.ticket, isNull);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(asked, hasLength(1));
        expect(asked.single.fingerprint, b.self.fingerprint);
        expect(asked.single.alias, 'Core b');
        // Still pending: still empty, no second prompt.
        expect((await b.listNearbyShares(a.self)).shares, isEmpty);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(asked, hasLength(1));
        a.respondNearbyAccess(asked.single.id, NearbyDecision.allowOnce);
        final l = await b.listNearbyShares(a.self);
        expect(l.shares, hasLength(1));
        expect(l.ticket, isNotNull);
      });
    });

    group('N8 controller', () {
      Future<(AppController, MemorySettingsStore)> controller(
          LanDropCore core,
          {Map<String, dynamic>? stored,
          String saveDir = '/tmp/landrop-test'}) async {
        final store = MemorySettingsStore(stored);
        final c = AppController(
            core: core, store: store, initialSaveDir: saveDir);
        addTearDown(c.dispose);
        await c.init();
        return (c, store);
      }

      final owner = NearbyAccessRequest(
          id: 'r1',
          fingerprint:
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          alias: 'Laptop',
          remoteIp: '10.0.0.2',
          at: _t0);

      test('stored trusted devices are pushed to the core after settings load',
          () async {
        final core = FakeCore(simulateDelay: Duration.zero);
        await controller(core, stored: {
          'trustedDevices': [
            {
              'fingerprint': 'aa11',
              'alias': 'Pixel',
              'trustedAt': '2026-10-01T10:00:00.000Z',
              'autoAccept': false,
            }
          ]
        });
        expect(core.nearbyTrusted, {'aa11'});
      });

      test('alwaysAllow trusts the device and syncs; removeTrusted revokes',
          () async {
        final core = FakeCore(simulateDelay: Duration.zero);
        final (c, store) = await controller(core);
        expect(c.pendingNearbyRequest, isNull);
        core.emitNearbyRequest(owner);
        core.emitNearbyRequest(NearbyAccessRequest(
            id: 'r2',
            fingerprint: 'c' * 64,
            alias: '',
            remoteIp: '10.0.0.3',
            at: owner.at));
        await Future<void>.delayed(Duration.zero);
        expect(c.pendingNearbyRequest!.id, 'r1');
        await c.answerNearbyRequest('r1', NearbyDecision.alwaysAllow);
        expect(core.nearbyAnswers, [('r1', NearbyDecision.alwaysAllow)]);
        expect(c.pendingNearbyRequest!.id, 'r2'); // queue moves on
        final t = c.trustedDevice(owner.fingerprint)!;
        expect(t.alias, 'Laptop');
        expect(t.autoAccept, isFalse);
        expect(core.nearbyTrusted, {owner.fingerprint});
        expect((store.stored['trustedDevices'] as List), hasLength(1));
        // allowOnce and deny do not trust.
        await c.answerNearbyRequest('r2', NearbyDecision.allowOnce);
        expect(c.trustedDevice('c' * 64), isNull);
        expect(core.nearbyTrusted, {owner.fingerprint});
        expect(c.pendingNearbyRequest, isNull);
        await c.removeTrusted(owner.fingerprint);
        expect(core.nearbyTrusted, isEmpty);
      });

      test('with real cores: alwaysAllow lets the app list, removeTrusted stops it',
          () async {
        final a = LanDropCoreImpl(nearbyOpts());
        env.cores.add(a);
        final b = await env.startCore(nearbyOpts(), name: 'b');
        final dir = await Directory('${env.tmp.path}/a-save').create();
        final (c, _) = await controller(a, saveDir: dir.path);
        a.createShare([env.file('z.txt', [1]).path], nearby: true);
        expect((await b.listNearbyShares(a.self)).shares, isEmpty);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        final req = c.pendingNearbyRequest!;
        expect(req.fingerprint, b.self.fingerprint);
        await c.answerNearbyRequest(req.id, NearbyDecision.alwaysAllow);
        expect(c.trustedDevice(b.self.fingerprint), isNotNull);
        expect((await b.listNearbyShares(a.self)).shares, hasLength(1));
        await c.removeTrusted(b.self.fingerprint);
        expect((await b.listNearbyShares(a.self)).shares, isEmpty);
      });

      test('downloadNearby shows a received transfer card and a history entry',
          () async {
        final (a, b) = await twoCores();
        a.createShare([env.file('card.txt', [5, 5, 5]).path], nearby: true);
        final store = MemorySettingsStore();
        final c = AppController(
            core: b, store: store, initialSaveDir: saveOf('b').path);
        addTearDown(() {
          // The controller must not stop the shared test core twice.
          c.dispose();
        });
        await c.init();
        final peer = a.self;
        final l = await c.listNearby(peer);
        expect(l.shares, hasLength(1));
        await c.downloadNearby(peer, l, [(l.shares.single.id, l.shares.single.files.single.id)]);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final s = c.sessions.first;
        expect(s.incoming, isTrue);
        expect(s.peerAlias, 'Core a');
        expect(s.state, TransferState.done);
        expect(File(s.openPath!).readAsBytesSync(), [5, 5, 5]);
        expect(c.history.first.incoming, isTrue);
        expect(c.history.first.savedPath, s.openPath);
        // The ticket is nowhere in what the controller keeps.
        final ticket = l.ticket!;
        expect(jsonEncode([for (final h in c.history) h.toJson()]), isNot(contains(ticket)));
        expect(s.report(), isNot(contains(ticket)));
        expect(jsonEncode(store.stored), isNot(contains(ticket)));
      });

      test('listNearby and downloadNearby never throw (empty listing, failed card)',
          () async {
        final core = FakeCore(simulateDelay: Duration.zero);
        final (c, _) = await controller(core);
        const peer = DeviceInfo(
            alias: 'P', deviceType: 'desktop', fingerprint: 'aa', ip: '10.0.0.9');
        core.failNearbyList.add('aa');
        final l = await c.listNearby(peer);
        expect(l.shares, isEmpty);
        expect(l.ticket, isNull);
        // Nothing to download: no card.
        await c.downloadNearby(peer, l, [('x', 'y')]);
        expect(c.sessions, isEmpty);
        // The fake core downloads: the card ends done with the shared id.
        final listing = NearbyListing(
            peerFingerprint: 'aa',
            ticket: 'lt1.x',
            shares: [
              NearbyShare(id: 's', createdAt: DateTime(2026), files: const [
                NearbyFile('f', 'a.txt', 'text/plain', 100)
              ])
            ]);
        await c.downloadNearby(peer, listing, [('s', 'f')]);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(core.downloadNearbyCalls, hasLength(1));
        expect(c.sessions.single.state, TransferState.done);
      });
    });
  });
}

final _t0 = DateTime.utc(2026, 10, 22);
