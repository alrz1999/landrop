// Nearby shares security tests (docs/NEARBY_PLAN.md section 5). Step 1 covers
// the browser side: C1 (browser part), C17, plus Host and access gates.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/core/api.dart';
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
}
