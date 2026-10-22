// Nearby shares security tests (docs/NEARBY_PLAN.md section 5). Step 1 covers
// the browser side: C1 (browser part), C17, plus Host and access gates.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/core/api.dart';
import 'package:landrop/core/util.dart' show HttpStatusError;
import 'package:landrop/core/landrop_core.dart';
import 'package:landrop/core/web_server.dart' show webTokenKey;
import 'package:pointycastle/asn1.dart';

import 'helpers/nearby_harness.dart';

void main() {
  final env = NearbyEnv();
  setUpAll(() {
    testIdentity(0);
    testIdentity(1);
  });
  setUp(env.setUp);
  tearDown(env.tearDown);

  test('C1 browser listing leaks no token, path, temp dir or url', () async {
    final a = await env.startCore(nearbyOpts());
    final token = await env.pair(a);
    final s = a.createShare(
      [
        env.file('movie.mp4', [1, 2, 3]).path,
      ],
      nearby: true,
      maxDownloads: 3,
    );
    final r = await ncall(
      'GET',
      '${env.base(a)}$nearbyApi/web/nearby',
      headers: cookie(token),
    );
    expect(r.status, 200);
    expect(r.json!['shares'], hasLength(1));
    expect(r.text, isNot(contains(s.token)));
    expect(r.text, isNot(contains('"path"')));
    expect(r.text, isNot(contains('"token"')));
    expect(r.text, isNot(contains(env.tmp.path)));
    expect(r.text, isNot(contains('url')));
    expect(r.text, isNot(contains(token)));
    // Only the documented keys.
    final share = (r.json!['shares'] as List).single as Map;
    expect(share.keys.toSet(), {
      'id',
      'createdAt',
      'expiresAt',
      'downloadsLeft',
      'truncated',
      'files',
    });
    expect((share['files'] as List).single.keys.toSet(), {
      'id',
      'name',
      'size',
      'mime',
    });
  });

  test(
    'C17 after the browser is disconnected, list and file give 401',
    () async {
      final a = await env.startCore(nearbyOpts());
      final token = await env.pair(a);
      final s = a.createShare([
        env.file('x.bin', [9, 9]).path,
      ], nearby: true);
      final list = '${env.base(a)}$nearbyApi/web/nearby';
      final file = '$list/${s.id}/files/${s.files.single.id}';
      expect((await ncall('GET', list, headers: cookie(token))).status, 200);
      expect((await ncall('GET', file, headers: cookie(token))).status, 200);
      a.revokeWebSession(a.webSessions.single.id);
      expect((await ncall('GET', list, headers: cookie(token))).status, 401);
      expect((await ncall('GET', file, headers: cookie(token))).status, 401);
      expect((await ncall('HEAD', file, headers: cookie(token))).status, 401);
    },
  );

  test('browser nearby routes obey Host check and per-IP failure limit', () async {
    final a = await env.startCore(nearbyOpts());
    final token = await env.pair(a);
    final list = '${env.base(a)}$nearbyApi/web/nearby';
    final bad = await ncall(
      'GET',
      list,
      headers: {...cookie(token), 'host': 'evil.example'},
    );
    expect(bad.status, 421);
    // The shared failure counter: 401s without a session count and lead to 429.
    final b = await env.startCore(nearbyOpts(rateLimit: 3), name: 'b');
    final lb = '${env.base(b)}$nearbyApi/web/nearby';
    for (var i = 0; i < 3; i++) {
      expect((await ncall('GET', lb)).status, 401);
    }
    expect((await ncall('GET', lb)).status, 429);
  });

  // ------------------------------------------------- app protocol (step 2)

  final id0 = testIdentity(0);
  final id1 = testIdentity(1);

  /// A core with one nearby share, trusting [trusted].
  Future<(LanDropCoreImpl, Share)> nearbyCore({
    Set<TlsIdentity> trusted = const {},
    DateTime Function()? clock,
    int? httpPort,
    int? maxDownloads,
    List<int> bytes = const [1, 2, 3, 4],
    String name = 'a',
  }) async {
    final c = await env.startCore(
      nearbyOpts(clock: clock, httpPort: httpPort),
      name: name,
    );
    final s = c.createShare(
      [env.file('$name.bin', bytes).path],
      nearby: true,
      maxDownloads: maxDownloads,
    );
    c.setNearbyTrusted({for (final t in trusted) t.fingerprint});
    return (c, s);
  }

  void expectEmpty(NResp r) {
    expect(r.status, 200);
    expect(r.text, emptyNearbyBody);
  }

  Future<String> ticketOf(LanDropCoreImpl c, TlsIdentity id) async {
    final r = await nearbyList(env.base(c), c, id);
    expect(r.status, 200);
    final t = r.json!['ticket'];
    expect(t, isA<String>());
    return t as String;
  }

  test('C2 every denial is byte-identical and equals the empty body', () async {
    final (a, _) = await nearbyCore(trusted: {id0});
    final base = env.base(a);
    // Trusted with no nearby shares.
    final (b, _) = await (() async {
      final c = await env.startCore(nearbyOpts(), name: 'b');
      final s = c.createShare([env.file('p.bin', [1]).path]); // not nearby
      c.setNearbyTrusted({id0.fingerprint});
      return (c, s);
    })();

    final unproven = await ncall(
      'POST',
      '$base$nearbyApi/nearby/list',
      json: nearbyListBody(a, id0, 'no-such-nonce'),
    );
    final untrusted = await nearbyList(base, a, id1);
    final noShares = await nearbyList(env.base(b), b, id0);
    final badSig = await ncall(
      'POST',
      '$base$nearbyApi/nearby/list',
      json: nearbyListBody(
        a,
        id0,
        await nearbyNonce(base, id0.fingerprint),
        signer: id1,
      ),
    );
    final cases = [unproven, untrusted, noShares, badSig];
    for (final r in cases) {
      expectEmpty(r);
      expect(r.body, cases.first.body);
      expect(r.h('content-type'), cases.first.h('content-type'));
      expect(r.h('content-length'), cases.first.h('content-length'));
    }
    // The control: trusted with a nearby share gets a listing.
    expect((await nearbyList(base, a, id0)).json!['ticket'], isNotNull);
  });

  test('C3 a nonce works once; a replay gets the empty body', () async {
    final (a, _) = await nearbyCore(trusted: {id0});
    final base = env.base(a);
    final nonce = await nearbyNonce(base, id0.fingerprint);
    final body = nearbyListBody(a, id0, nonce);
    final url = '$base$nearbyApi/nearby/list';
    expect((await ncall('POST', url, json: body)).json!['ticket'], isNotNull);
    expectEmpty(await ncall('POST', url, json: body));
  });

  test('C3 the nonce is spent even when the proof fails', () async {
    final (a, _) = await nearbyCore(trusted: {id0});
    final base = env.base(a);
    final nonce = await nearbyNonce(base, id0.fingerprint);
    final url = '$base$nearbyApi/nearby/list';
    expectEmpty(
      await ncall(
        'POST',
        url,
        json: nearbyListBody(a, id0, nonce, signer: id1),
      ),
    );
    expectEmpty(await ncall('POST', url, json: nearbyListBody(a, id0, nonce)));
  });

  test('C4 a nonce issued for one fingerprint is useless for another', () async {
    final (a, _) = await nearbyCore(trusted: {id0, id1});
    final base = env.base(a);
    final nonceForId1 = await nearbyNonce(base, id1.fingerprint);
    final r = await ncall(
      'POST',
      '$base$nearbyApi/nearby/list',
      json: nearbyListBody(a, id0, nonceForId1),
    );
    expectEmpty(r);
  });

  test('C5 the signature is bound to the path and to the receiver', () async {
    final (a, _) = await nearbyCore(trusted: {id0});
    final base = env.base(a);
    expectEmpty(
      await nearbyList(base, a, id0, path: '$nearbyApi/nearby/challenge'),
    );
    expectEmpty(await nearbyList(base, a, id0, receiverFp: id1.fingerprint));
    expect((await nearbyList(base, a, id0)).json!['ticket'], isNotNull);
  });

  test('C6 a nonce expires after 30 seconds', () async {
    var now = DateTime.now();
    final (a, _) = await nearbyCore(trusted: {id0}, clock: () => now);
    final base = env.base(a);
    final url = '$base$nearbyApi/nearby/list';
    final late = await nearbyNonce(base, id0.fingerprint);
    final fresh = await nearbyNonce(base, id0.fingerprint);
    now = now.add(const Duration(seconds: 29));
    expect(
      (await ncall('POST', url, json: nearbyListBody(a, id0, fresh)))
          .json!['ticket'],
      isNotNull,
    );
    now = now.add(const Duration(seconds: 2)); // 31 s after issue
    expectEmpty(await ncall('POST', url, json: nearbyListBody(a, id0, late)));
  });

  group('C7 no RSA work for a bad certificate', () {
    Uint8List certWith(BigInt n, BigInt e) {
      final rsaKey = ASN1Sequence(elements: [ASN1Integer(n), ASN1Integer(e)]);
      final bits = ASN1BitString(stringValues: rsaKey.encode());
      final alg = ASN1Sequence(
        elements: [
          ASN1ObjectIdentifier.fromIdentifierString('1.2.840.113549.1.1.1'),
          ASN1Null(),
        ],
      );
      final tbs = ASN1Sequence(elements: [ASN1Sequence(elements: [alg, bits])]);
      return ASN1Sequence(elements: [tbs]).encode();
    }

    test('certificate of another fingerprint: empty, fast', () async {
      final (a, _) = await nearbyCore(trusted: {id0});
      final base = env.base(a);
      final nonce = await nearbyNonce(base, id0.fingerprint);
      final body = nearbyListBody(a, id0, nonce)
        ..['cert'] = base64Encode(id1.certDer);
      final sw = Stopwatch()..start();
      final r = await ncall('POST', '$base$nearbyApi/nearby/list', json: body);
      expectEmpty(r);
      expect(sw.elapsedMilliseconds, lessThan(50));
    });

    test('certificate over 16384 characters: refused before any work', () async {
      final (a, _) = await nearbyCore(trusted: {id0});
      final base = env.base(a);
      final nonce = await nearbyNonce(base, id0.fingerprint);
      final body = nearbyListBody(a, id0, nonce)..['cert'] = 'A' * 16385;
      final sw = Stopwatch()..start();
      final r = await ncall('POST', '$base$nearbyApi/nearby/list', json: body);
      expect(r.status, 400); // invalid body (plan 1.3), never a listing
      expect(r.text, isNot(contains('ticket')));
      expect(sw.elapsedMilliseconds, lessThan(50));
    });

    test('huge modulus under the right fingerprint: empty, fast', () async {
      final rnd = Random(3);
      final n = (BigInt.one << 79999) | BigInt.one;
      var v = n;
      for (var i = 1; i < 79990; i += 30) {
        v |= BigInt.from(rnd.nextInt(1 << 30)) << i;
      }
      final der = certWith(v, BigInt.from(65537));
      final fp = fingerprintOfDer(der);
      expect(base64Encode(der).length, lessThan(16384));
      final (a, _) = await nearbyCore(trusted: {id0});
      a.setNearbyTrusted({fp});
      final base = env.base(a);
      final nonce = await nearbyNonce(base, fp);
      final sw = Stopwatch()..start();
      final r = await ncall(
        'POST',
        '$base$nearbyApi/nearby/list',
        json: {
          'fingerprint': fp,
          'nonce': nonce,
          'cert': base64Encode(der),
          'sig': base64Encode(List.filled(256, 7)),
        },
      );
      expectEmpty(r);
      expect(sw.elapsedMilliseconds, lessThan(50));
    });
  });

  test('C8 the 21st challenge within a minute gets 429', () async {
    final (a, _) = await nearbyCore();
    final url = '${env.base(a)}$nearbyApi/nearby/challenge';
    final body = {'fingerprint': id0.fingerprint};
    for (var i = 0; i < 20; i++) {
      final r = await ncall('POST', url, json: body);
      expect(r.status, anyOf(200, 503)); // 503: nonce cap, still a hit
    }
    expect((await ncall('POST', url, json: body)).status, 429);
  });

  group('C9 nonce store caps', () {
    test('the 5th outstanding nonce of an address gets 503', () async {
      final (a, _) = await nearbyCore();
      final url = '${env.base(a)}$nearbyApi/nearby/challenge';
      for (var i = 0; i < 4; i++) {
        expect(
          (await ncall('POST', url, json: {'fingerprint': id0.fingerprint}))
              .status,
          200,
        );
      }
      final r = await ncall('POST', url, json: {
        'fingerprint': id0.fingerprint,
      });
      expect(r.status, 503);
    });

    test('64 nonces in all, then 503; expired ones free the room', () async {
      var now = DateTime.now();
      final (a, _) = await nearbyCore(clock: () => now);
      for (var i = 0; i < 64; i++) {
        a.debugWeb.debugAddNonce('n$i', id0.fingerprint, '10.0.0.${i + 1}');
      }
      final url = '${env.base(a)}$nearbyApi/nearby/challenge';
      final body = {'fingerprint': id0.fingerprint};
      expect((await ncall('POST', url, json: body)).status, 503);
      now = now.add(const Duration(seconds: 31));
      expect((await ncall('POST', url, json: body)).status, 200);
    });
  });

  test('C10 oversize bodies get 413', () async {
    final (a, _) = await nearbyCore(trusted: {id0});
    final base = env.base(a);
    final big = await ncall(
      'POST',
      '$base$nearbyApi/nearby/challenge',
      json: {'fingerprint': id0.fingerprint, 'pad': 'x' * 2000},
    );
    expect(big.status, 413);
    // Under the cap the body is read and judged (400: not a valid request).
    final url = '$base$nearbyApi/nearby/list';
    final under = await ncall('POST', url, json: {'pad': 'x' * 24000});
    expect(under.status, 400);
    // Over it the server answers 413 and closes without reading the rest; a
    // body of several TLS records can see the connection reset first.
    try {
      final over = await ncall('POST', url, json: {'pad': 'x' * 24600});
      expect(over.status, 413);
    } on IOException {
      // refused by closing the connection
    }
    // The server is still fine afterwards.
    expect((await nearbyList(base, a, id0)).json!['ticket'], isNotNull);
  });

  test('C10 wrong field types and lengths get 400', () async {
    final (a, _) = await nearbyCore(trusted: {id0});
    final base = env.base(a);
    final url = '$base$nearbyApi/nearby/list';
    final nonce = await nearbyNonce(base, id0.fingerprint);
    final good = nearbyListBody(a, id0, nonce);
    for (final bad in <Map<String, dynamic>>[
      {...good, 'fingerprint': 'ABC'},
      {...good, 'nonce': 5},
      {...good, 'nonce': 'n' * 129},
      {...good, 'sig': 'S' * 1025},
      {...good, 'alias': 'a' * 65},
      {...good, 'alias': 7},
    ]) {
      expect((await ncall('POST', url, json: bad)).status, 400);
    }
    final challenge = '$base$nearbyApi/nearby/challenge';
    for (final bad in <Object>['X', 3, 'a' * 64 + 'b']) {
      expect(
        (await ncall('POST', challenge, json: {'fingerprint': bad})).status,
        400,
      );
    }
    expect(
      (await ncall(
        'POST',
        challenge,
        json: {'fingerprint': a.self.fingerprint},
      )).status,
      400,
    );
  });

  test('C11 a listing has at most 50 shares and 1000 files per share', () async {
    final (a, _) = await nearbyCore(trusted: {id0});
    final f = env.file('many.bin', [1]);
    for (var i = 0; i < 59; i++) {
      a.createShare([f.path], nearby: true);
    }
    final r = await nearbyList(env.base(a), a, id0);
    expect(r.status, 200);
    expect(r.json!['shares'], hasLength(50));

    final (b, _) = await nearbyCore(trusted: {id0}, name: 'b');
    final dir = Directory('${env.tmp.path}/big')..createSync();
    for (var i = 0; i < 1001; i++) {
      File('${dir.path}/f$i.txt').writeAsStringSync('$i');
    }
    b.createShare([dir.path], nearby: true);
    final r2 = await nearbyList(env.base(b), b, id0);
    final shares = r2.json!['shares'] as List;
    final big = shares.firstWhere((s) => (s['files'] as List).length > 1);
    expect(big['files'], hasLength(1000));
    expect(big['truncated'], isTrue);
  });

  test('C12 tickets are stored by hash, never raw', () async {
    final (a, _) = await nearbyCore(trusted: {id0});
    final ticket = await ticketOf(a, id0);
    expect(ticket, startsWith('lt1.'));
    final keys = a.debugWeb.debugNearbyTicketKeys.toList();
    expect(keys, [webTokenKey(ticket)]);
    expect(keys, isNot(contains(ticket)));
  });

  group('C13 a ticket stops working when access ends', () {
    Future<void> expectEnds(
      Future<void> Function(LanDropCoreImpl a, Share s) end,
    ) async {
      final (a, s) = await nearbyCore(trusted: {id0});
      final ticket = await ticketOf(a, id0);
      final url = nearbyFileUrl(env.base(a), s.id, s.files.single.id);
      expect((await ncall('GET', url, headers: ticketHeader(ticket))).status,
          200);
      await end(a, s);
      expect((await ncall('GET', url, headers: ticketHeader(ticket))).status,
          404);
    }

    test('share revoked', () => expectEnds((a, s) async => a.revokeShare(s.id)));
    test(
      'show-to-nearby switched off',
      () => expectEnds((a, s) async => a.setShareNearby(s.id, false)),
    );
    test(
      'device no longer trusted',
      () => expectEnds((a, s) async => a.setNearbyTrusted({})),
    );
    test(
      'access revoked',
      () => expectEnds(
        (a, s) async => a.revokeNearbyAccess(id0.fingerprint),
      ),
    );
  });

  test('C14 a ticket lives 10 minutes, fixed', () async {
    var now = DateTime.now();
    final (a, s) = await nearbyCore(trusted: {id0}, clock: () => now);
    final ticket = await ticketOf(a, id0);
    final url = nearbyFileUrl(env.base(a), s.id, s.files.single.id);
    now = now.add(const Duration(seconds: 599));
    expect(
      (await ncall('GET', url, headers: ticketHeader(ticket))).status,
      200,
    );
    // Use did not extend it.
    now = now.add(const Duration(seconds: 2));
    expect(
      (await ncall('GET', url, headers: ticketHeader(ticket))).status,
      404,
    );
  });

  test('C15 a ticket only works from the address it was issued to', () async {
    final (a, s) = await nearbyCore(trusted: {id0});
    final url = nearbyFileUrl(env.base(a), s.id, s.files.single.id);
    final other = a.debugWeb.debugIssueTicket(id0.fingerprint, '10.9.9.9');
    expect((await ncall('GET', url, headers: ticketHeader(other))).status, 404);
    final mine = a.debugWeb.debugIssueTicket(id0.fingerprint, '127.0.0.1');
    expect((await ncall('GET', url, headers: ticketHeader(mine))).status, 200);
  });

  test('C16 a ticket in the URL is not accepted', () async {
    final (a, s) = await nearbyCore(trusted: {id0});
    final ticket = await ticketOf(a, id0);
    final url = nearbyFileUrl(env.base(a), s.id, s.files.single.id);
    expect((await ncall('GET', '$url?ticket=$ticket')).status, 404);
    expect(
      (await ncall('GET', '$url?ticket=$ticket', headers: cookie('x'))).status,
      404,
    );
    expect((await ncall('GET', url)).status, 404);
    // Wrong scheme, extra whitespace-only and oversize headers.
    expect(
      (await ncall('GET', url, headers: {'authorization': 'Bearer $ticket'}))
          .status,
      404,
    );
    expect(
      (await ncall(
        'GET',
        url,
        headers: ticketHeader('${'x' * 300}$ticket'),
      )).status,
      404,
    );
  });

  test('C18 an unknown Host header gets 421 on every nearby route', () async {
    final (a, s) = await nearbyCore(trusted: {id0});
    final base = env.base(a);
    final evil = {'host': 'evil.example'};
    expect(
      (await ncall('POST', '$base$nearbyApi/nearby/challenge',
              headers: evil, json: {'fingerprint': id0.fingerprint}))
          .status,
      421,
    );
    expect(
      (await ncall('POST', '$base$nearbyApi/nearby/list',
              headers: evil, json: {'x': 1}))
          .status,
      421,
    );
    final ticket = await ticketOf(a, id0);
    expect(
      (await ncall(
        'GET',
        nearbyFileUrl(base, s.id, s.files.single.id),
        headers: {...evil, ...ticketHeader(ticket)},
      )).status,
      421,
    );
  });

  test('C19 the plain HTTP listener has no app nearby endpoints', () async {
    final (a, s) = await nearbyCore(trusted: {id0}, httpPort: 0);
    final http = 'http://127.0.0.1:${a.webHttpPort}';
    final ticket = await ticketOf(a, id0); // over HTTPS
    final unknown = await ncall('GET', '$http$nearbyApi/nope');
    expect(unknown.status, 404);
    final nonce = await nearbyNonce(env.base(a), id0.fingerprint);
    final calls = [
      await ncall('POST', '$http$nearbyApi/nearby/challenge',
          json: {'fingerprint': id0.fingerprint}),
      await ncall('POST', '$http$nearbyApi/nearby/list',
          json: nearbyListBody(a, id0, nonce)),
      await ncall('GET', nearbyFileUrl(http, s.id, s.files.single.id),
          headers: ticketHeader(ticket)),
      await ncall('GET', '$http$nearbyApi/nearby/anything'),
    ];
    for (final r in calls) {
      expect(r.status, 404);
      expect(r.body, unknown.body);
    }
    // The nonce was not spent by the plain HTTP call.
    expect(
      (await ncall('POST', '${env.base(a)}$nearbyApi/nearby/list',
              json: nearbyListBody(a, id0, nonce)))
          .json!['ticket'],
      isNotNull,
    );
  });

  group('app client (step 3)', () {
    Future<(LanDropCoreImpl, LanDropCoreImpl)> twoCores(
        {DateTime Function()? clock}) async {
      final a = await env.startCore(nearbyOpts(clock: clock), name: 'a');
      final b = await env.startCore(nearbyOpts(), name: 'b');
      a.setNearbyTrusted({b.self.fingerprint});
      return (a, b);
    }

    Directory saveOf(String name) => Directory('${env.tmp.path}/$name-save');
    List<String> names(Directory d) => [
          for (final e in d.listSync(recursive: true, followLinks: false))
            e.path.substring(d.path.length + 1),
        ]..sort();

    Future<List<TransferProgress>> download(
        LanDropCoreImpl b, DeviceInfo peer, NearbyListing l) async {
      final events = <TransferProgress>[];
      final sub = b.progress.listen(events.add);
      await b.downloadNearby(peer, l, [
        for (final sh in l.shares)
          for (final f in sh.files) (sh.id, f.id),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();
      return events;
    }

    /// A spy peer (certificate of test identity 1) that lists [files] and
    /// serves them as [serve] says (default: the listed bytes).
    Future<SpyPeer> spyWith(
      List<(String, String, int)> files, {
      Future<void> Function(SpyPeer, HttpRequest)? file,
    }) =>
        SpyPeer.start(testIdentity(1), (spy, req, body) async {
          final path = req.uri.path;
          if (path.endsWith('/nearby/challenge')) {
            return SpyPeer.reply(req, 200, '{"nonce":"spynonce","expiresIn":30}');
          }
          if (path.endsWith('/nearby/list')) {
            return SpyPeer.reply(req, 200, SpyPeer.listing(files));
          }
          if (path.contains('/nearby/shares/') && file != null) {
            return file(spy, req);
          }
          return SpyPeer.reply(req, 404, '{}');
        });

    test('C20 the client pins the peer certificate: a different one throws and receives no request',
        () async {
      final b = await env.startCore(nearbyOpts(), name: 'b');
      final rogue = await spyWith([('f1', 'a.txt', 1)]);
      addTearDown(rogue.close);
      // The peer is known by the fingerprint of identity 0, but identity 1
      // answers at that address.
      final peer = DeviceInfo(
          alias: 'Spy',
          deviceType: 'desktop',
          fingerprint: id0.fingerprint,
          ip: '127.0.0.1',
          port: rogue.server.port);
      await expectLater(
          b.listNearbyShares(peer), throwsA(isA<HandshakeException>()));
      expect(rogue.requests, isEmpty);
      // The same for a download with a (stolen) ticket.
      final listing = NearbyListing(
          peerFingerprint: id0.fingerprint,
          ticket: 'lt1.stolen',
          shares: [
            NearbyShare(id: 'share1', createdAt: DateTime(2026), files: const [
              NearbyFile('f1', 'a.txt', 'text/plain', 1)
            ])
          ]);
      final ev = await download(b, peer, listing);
      expect(ev.where((e) => e.done).single.errorCode,
          SendErrorCode.fingerprintMismatch);
      expect(rogue.requests, isEmpty);
      expect(names(saveOf('b')), isEmpty);
    });

    test('C21 downloaded names are sanitised, go through reserveUniqueFile, never through a symlink',
        () async {
      final (a, b) = await twoCores();
      final bidi = env.file('x\u202Etxt.exe', [1, 2]);
      final con = env.file('CON.txt', [3, 4]);
      a.createShare([bidi.path, con.path], nearby: true);
      final save = saveOf('b');
      // Symlinks planted where the files and their .part files would go.
      final victim = File('${env.tmp.path}/victim.txt')..writeAsStringSync('orig');
      Link('${save.path}/_CON.txt').createSync(victim.path);
      Link('${save.path}/._CON.txt.part').createSync(victim.path);
      Link('${save.path}/xtxt.exe').createSync('${env.tmp.path}/nowhere.bin');
      final l = await b.listNearbyShares(a.self);
      expect(l.shares.single.files.map((f) => f.name).join(),
          isNot(matches(RegExp('[\u202A-\u202E]'))));
      final ev = await download(b, a.self, l);
      final done = ev.where((e) => e.done).toList();
      expect(done, hasLength(2));
      expect(done.every((e) => e.error == null), isTrue);
      expect(victim.readAsStringSync(), 'orig');
      expect(File('${env.tmp.path}/nowhere.bin').existsSync(), isFalse);
      final saved = {for (final e in done) e.savedPath!.split('/').last};
      expect(saved, {'_CON (1).txt', 'xtxt (1).exe'});
      for (final n in names(save)) {
        expect(RegExp('[\u202A-\u202E]').hasMatch(n), isFalse);
      }
      for (final e in done) {
        expect(FileSystemEntity.typeSync(e.savedPath!, followLinks: false),
            FileSystemEntityType.file);
      }
    });

    test('hostile folder-style names cannot leave the save folder', () async {
      final b = await env.startCore(nearbyOpts(), name: 'b');
      final spy = await spyWith([
        ('f1', '../../escape.txt', 2),
        ('f2', r'a/..\..\b/../c.txt', 2),
        ('f3', '/etc/abs.txt', 2),
      ], file: (spy, req) async {
        req.response.add([7, 7]);
        await req.response.close();
      });
      addTearDown(spy.close);
      final l = await b.listNearbyShares(spy.peer);
      final ev = await download(b, spy.peer, l);
      expect(ev.where((e) => e.done && e.error == null), hasLength(3));
      for (final e in ev.where((e) => e.done)) {
        expect(e.savedPath!.startsWith('${saveOf('b').absolute.path}/'), isTrue,
            reason: e.savedPath);
      }
      expect(File('${env.tmp.path}/escape.txt').existsSync(), isFalse);
      expect(File('${env.tmp.path}/a-save/escape.txt').existsSync(), isFalse);
    });

    test('malformed or hostile listing JSON is ignored without throwing', () {
      NearbyListing p(Object? v) => LanDropCoreImpl.parseNearbyListing(
          v is String ? utf8.encode(v) : utf8.encode(jsonEncode(v)), 'f' * 64);
      Map<String, dynamic> share(Object? files, {Object? id = 's1'}) => {
            'id': id,
            'createdAt': '2026-10-22T10:00:00Z',
            'expiresAt': null,
            'downloadsLeft': null,
            'truncated': false,
            'files': files,
          };
      Map<String, dynamic> file({Object? id = 'f1', Object? name = 'a.txt', Object? size = 1}) =>
          {'id': id, 'name': name, 'size': size, 'mime': 'text/plain'};
      Map<String, dynamic> body(List shares, {Object? ticket = 'lt1.abc'}) =>
          {'shares': shares, 'ticket': ticket, 'ticketExpiresIn': 600};

      for (final junk in <Object?>[
        'not json', '', '[]', '42', 'null', '{"shares": "x"}', '{"shares": [1,2,null]}',
        '{"shares": [], "ticket": null}', '\u0000\u0001', '{"shares": {"a": 1}}',
        List.generate(100, (i) => [i]), '{"shares":[{"id":5}],"ticket":"lt1.a"}',
      ]) {
        final l = p(junk);
        expect(l.shares, isEmpty, reason: '$junk');
        expect(l.ticket, isNull);
      }
      // Valid base case.
      expect(p(body([share([file()])])).shares.single.files.single.name, 'a.txt');
      // Bad ticket (header injection, spaces, too long, wrong type).
      for (final t in ['lt1.a\r\nX: y', 'a b', 'x' * 300, 5, null, '']) {
        expect(p(body([share([file()])], ticket: t)).shares, isEmpty, reason: '$t');
      }
      // Malformed shares and files are dropped, the good ones stay.
      final l = p(body([
        share([file(), file(id: '../x'), file(size: -1), file(size: '3'),
            file(name: 5), file(id: 'f2', name: 'b.txt', size: 2)]),
        share([file()], id: '../evil'),
        share([file()], id: 7),
        share([]),
        share('x'),
        {...share([file()]), 'createdAt': 'yesterday'},
        {...share([file()]), 'downloadsLeft': 'many'},
        {...share([file()]), 'expiresAt': 5},
        'junk',
        share([file()], id: 's2'),
      ]));
      expect(l.shares.map((s) => s.id), ['s1', 's2']);
      expect(l.shares.first.files.map((f) => f.name), ['a.txt', 'b.txt']);
      // At most 50 shares and 1000 files.
      expect(p(body([for (var i = 0; i < 80; i++) share([file()], id: 's$i')])).shares,
          hasLength(50));
      expect(
          p(body([share([for (var i = 0; i < 1500; i++) file(id: 'f$i')])]))
              .shares.single.files,
          hasLength(1000));
      // Names are cleaned for display; control characters and bidi marks go.
      final n = p(body([share([file(name: 'a\u202Eb\u0007c\n d.txt'), file(id: 'f9', name: '\u202E')])]));
      expect(n.shares.single.files.first.name, 'ab c d.txt');
      expect(n.shares.single.files.last.name, 'file');
    });

    test('a listing answer bigger than 4 MB is rejected', () async {
      final b = await env.startCore(nearbyOpts(), name: 'b');
      for (final chunked in [false, true]) {
        final spy = await SpyPeer.start(testIdentity(1), (spy, req, body) async {
          if (req.uri.path.endsWith('/nearby/challenge')) {
            return SpyPeer.reply(req, 200, '{"nonce":"n","expiresIn":30}');
          }
          final pad = ' ' * ((4 << 20) + 10);
          final text = '{"shares":[],"ticket":null,"pad":"$pad"}';
          req.response.headers.contentType = ContentType.json;
          if (chunked) {
            req.response.headers.chunkedTransferEncoding = true;
            for (var i = 0; i < text.length; i += 65536) {
              req.response.write(text.substring(i, min(text.length, i + 65536)));
            }
          } else {
            req.response.write(text);
          }
          await req.response.close();
        });
        addTearDown(spy.close);
        await expectLater(b.listNearbyShares(spy.peer),
            throwsA(isA<HttpStatusError>().having((e) => e.status, 'status', 413)),
            reason: 'chunked: $chunked');
      }
    });

    test('the ticket is never in logs, sessions or history, and travels only in the header',
        () async {
      final (a, b) = await twoCores();
      a.createShare([env.file('t.txt', [1, 2, 3]).path], nearby: true);
      final log = <String>[];
      late NearbyListing l;
      late List<TransferProgress> ev;
      await runZoned(() async {
        l = await b.listNearbyShares(a.self);
        ev = await download(b, a.self, l);
        // Also a failing download.
        await b.downloadNearby(a.self, l, [('nope', 'nope')]).catchError((_) {});
      }, zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => log.add(line)));
      final ticket = l.ticket!;
      expect(ev.where((e) => e.done).single.error, isNull);
      expect(log.join('\n'), isNot(contains(ticket)));
      for (final e in ev) {
        expect('${e.error}${e.fileName}${e.savedPath}', isNot(contains(ticket)));
      }
      // Against a spy: the ticket and nonce are never in a URL or a body.
      final spy = await spyWith([('f1', 'a.txt', 1)], file: (spy, req) async {
        req.response.add([1]);
        await req.response.close();
      });
      addTearDown(spy.close);
      final sl = await b.listNearbyShares(spy.peer);
      await download(b, spy.peer, sl);
      final nearby = spy.nearbyRequests;
      expect(nearby.map((r) => r.uri.path.split('/').last).toList(),
          ['challenge', 'list', 'f1']);
      for (final r in nearby) {
        expect(r.uri.hasQuery, isFalse);
        expect('${r.uri}', isNot(contains('lt1.')));
        expect('${r.uri}', isNot(contains('spynonce')));
      }
      expect(nearby[0].body, isNot(contains('spynonce')));
      expect(nearby[1].body, contains('spynonce')); // only to the list call
      expect(nearby[2].headers['authorization'], 'LanDrop-Ticket lt1.spyticket');
      expect(nearby[2].body, isEmpty);
    });

    test('no ticket or nonce goes to another host: redirects are not followed',
        () async {
      final b = await env.startCore(nearbyOpts(), name: 'b');
      final other = await SpyPeer.start(
          testIdentity(0), (spy, req, body) => SpyPeer.reply(req, 200, 'x'));
      addTearDown(other.close);
      final spy = await spyWith([('f1', 'a.txt', 1)], file: (spy, req) async {
        req.response.statusCode = 302;
        req.response.headers
            .set('location', 'https://127.0.0.1:${other.server.port}/steal');
        await req.response.close();
      });
      addTearDown(spy.close);
      final l = await b.listNearbyShares(spy.peer);
      final ev = await download(b, spy.peer, l);
      expect(ev.where((e) => e.done).single.error, isNotNull);
      expect(other.requests, isEmpty);
      expect(names(saveOf('b')), isEmpty);
    });

    test('more bytes than listed, or fewer, fail the file and leave nothing behind',
        () async {
      final b = await env.startCore(nearbyOpts(), name: 'b');
      final spy = await spyWith([
        ('f1', 'long.bin', 10),
        ('f2', 'short.bin', 10),
        ('f3', 'ok.bin', 10),
      ], file: (spy, req) async {
        final id = req.uri.pathSegments.last;
        req.response.headers.chunkedTransferEncoding = true;
        req.response.add(List.filled(id == 'f1' ? 25 : (id == 'f2' ? 4 : 10), 9));
        await req.response.close();
      });
      addTearDown(spy.close);
      final l = await b.listNearbyShares(spy.peer);
      final ev = await download(b, spy.peer, l);
      final done = {for (final e in ev.where((e) => e.done)) e.fileName!: e};
      expect(done['long.bin']!.error, isNotNull);
      expect(done['short.bin']!.error, isNotNull);
      expect(done['ok.bin']!.error, isNull);
      expect(names(saveOf('b')), ['ok.bin']);
    });

    test('cancelSession during a download stops it and deletes the .part',
        () async {
      final (a, b) = await twoCores();
      final big = List<int>.filled(40 << 20, 3);
      a.createShare([env.file('huge.bin', big).path], nearby: true);
      final l = await b.listNearbyShares(a.self);
      final events = <TransferProgress>[];
      var partSeen = false;
      late StreamSubscription<TransferProgress> sub;
      sub = b.progress.listen((e) {
        events.add(e);
        if (!e.done && e.sentBytes > 0 && !partSeen) {
          partSeen = names(saveOf('b')).any((n) => n.endsWith('.part'));
          b.cancelSession(e.sessionId);
        }
      });
      await b.downloadNearby(a.self, l, [
        (l.shares.single.id, l.shares.single.files.single.id),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      expect(partSeen, isTrue);
      final last = events.last;
      expect(last.done, isTrue);
      expect(last.errorCode, SendErrorCode.cancelled);
      expect(names(saveOf('b')), isEmpty);
    });

    test('a ticket 404 re-lists exactly once and retries with the new ticket',
        () async {
      final b = await env.startCore(nearbyOpts(), name: 'b');
      var lists = 0;
      final spy = await SpyPeer.start(testIdentity(1), (spy, req, body) async {
        final path = req.uri.path;
        if (path.endsWith('/nearby/challenge')) {
          return SpyPeer.reply(req, 200, '{"nonce":"n","expiresIn":30}');
        }
        if (path.endsWith('/nearby/list')) {
          lists++;
          return SpyPeer.reply(req, 200,
              SpyPeer.listing([('f1', 'a.txt', 2), ('f2', 'b.txt', 2)], ticket: 'lt1.t$lists'));
        }
        if (path.contains('/nearby/shares/')) {
          final ok = req.headers.value('authorization') == 'LanDrop-Ticket lt1.t2';
          if (!ok) return SpyPeer.reply(req, 404, '{}');
          req.response.add([5, 6]);
          return req.response.close();
        }
        return SpyPeer.reply(req, 404, '{}');
      });
      addTearDown(spy.close);
      final l = await b.listNearbyShares(spy.peer);
      expect(lists, 1);
      final ev = await download(b, spy.peer, l);
      expect(lists, 2); // one re-list for both files
      final done = ev.where((e) => e.done).toList();
      expect(done, hasLength(2));
      expect(done.every((e) => e.error == null), isTrue);
      // The first file's retry used the new ticket; the second went straight on.
      final used = [
        for (final r in spy.requests.where((r) => r.uri.path.contains('/shares/')))
          r.headers['authorization']
      ];
      expect(used, [
        'LanDrop-Ticket lt1.t1',
        'LanDrop-Ticket lt1.t2',
        'LanDrop-Ticket lt1.t2',
      ]);
    });

    test('a file that stays 404 fails as no longer shared after one re-list only',
        () async {
      final b = await env.startCore(nearbyOpts(), name: 'b');
      var lists = 0;
      final spy = await SpyPeer.start(testIdentity(1), (spy, req, body) async {
        final path = req.uri.path;
        if (path.endsWith('/nearby/challenge')) {
          return SpyPeer.reply(req, 200, '{"nonce":"n","expiresIn":30}');
        }
        if (path.endsWith('/nearby/list')) {
          lists++;
          return SpyPeer.reply(req, 200,
              SpyPeer.listing([('f1', 'a.txt', 2), ('f2', 'b.txt', 2)]));
        }
        return SpyPeer.reply(req, 404, '{}');
      });
      addTearDown(spy.close);
      final l = await b.listNearbyShares(spy.peer);
      final ev = await download(b, spy.peer, l);
      expect(lists, 2);
      final done = ev.where((e) => e.done).toList();
      expect(done, hasLength(2));
      expect(done.every((e) => e.errorCode == SendErrorCode.declined), isTrue);
      expect(names(saveOf('b')), isEmpty);
    });

    test('a real expired ticket (clock +11 min) is renewed automatically',
        () async {
      var now = DateTime.now();
      final (a, b) = await twoCores(clock: () => now);
      a.createShare([env.file('e.txt', [4, 4]).path], nearby: true);
      final l = await b.listNearbyShares(a.self);
      now = now.add(const Duration(minutes: 11));
      final ev = await download(b, a.self, l);
      final done = ev.where((e) => e.done).single;
      expect(done.error, isNull);
      expect(File(done.savedPath!).readAsBytesSync(), [4, 4]);
    });
  });
}
