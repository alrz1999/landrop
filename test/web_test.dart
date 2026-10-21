// Browser access (DESIGN.md 4): web page, pairing, browser uploads, shares
// with range streaming, plain HTTP listener. Real cores over loopback.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/core/api.dart';
import 'package:landrop/core/landrop_core.dart';
import 'package:landrop/core/web_assets.dart';
import 'package:landrop/core/web_server.dart';

LanDropCoreOptions _opts({
  int? httpPort,
  int rateLimit = 1000,
  Duration pairingTimeout = const Duration(seconds: 10),
  Duration streamWindow = const Duration(minutes: 30),
  String? sharesStorePath,
}) => LanDropCoreOptions(
  sharesStorePath: sharesStorePath,
  port: 0,
  bindAddress: InternetAddress.loopbackIPv4,
  advertiseIp: '127.0.0.1',
  multicastEnabled: false,
  persistIdentity: false,
  decisionTimeout: const Duration(seconds: 10),
  httpPort: httpPort,
  webRateLimit: rateLimit,
  webPairingTimeout: pairingTimeout,
  webStreamWindow: streamWindow,
);

class _Resp {
  final int status;
  final HttpHeaders headers;
  final Uint8List body;
  _Resp(this.status, this.headers, this.body);
  String get text => utf8.decode(body, allowMalformed: true);
  Map<String, dynamic>? get json {
    try {
      final v = jsonDecode(text);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }

  String? h(String name) => headers.value(name);
}

Future<_Resp> _call(
  String method,
  String url, {
  Map<String, String> headers = const {},
  Object? json,
  List<int>? bytes,
}) async {
  final c = HttpClient()..badCertificateCallback = (_, _, _) => true;
  try {
    final req = await c.openUrl(method, Uri.parse(url));
    headers.forEach(req.headers.set);
    if (json != null) {
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode(json)));
    }
    if (bytes != null) {
      req.contentLength = bytes.length;
      req.add(bytes);
    }
    final res = await req.close();
    final b = BytesBuilder(copy: false);
    await for (final ch in res) {
      b.add(ch);
    }
    return _Resp(res.statusCode, res.headers, b.takeBytes());
  } finally {
    c.close(force: true);
  }
}

Uint8List _randomBytes(int n, int seed) {
  final r = Random(seed);
  return Uint8List.fromList(List<int>.generate(n, (_) => r.nextInt(256)));
}

String _sha(List<int> b) => sha256.convert(b).toString();

const _api = '/api/landrop/v1';

/// A full read is charged when the server has finished writing, which can be
/// a moment after the client has read the last byte.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 100));

void _expectSecurityHeaders(_Resp r) {
  expect(r.h('content-security-policy'), webCsp);
  expect(
    r.h('content-security-policy'),
    "default-src 'self'; style-src 'self' 'unsafe-inline'; "
    "script-src 'self' 'unsafe-inline'; img-src 'self' data:; "
    "media-src 'self'; frame-ancestors 'none'",
  );
  expect(r.h('referrer-policy'), 'no-referrer');
  expect(r.h('x-frame-options'), 'DENY');
  expect(r.h('x-content-type-options'), 'nosniff');
  expect(r.h('cache-control'), 'no-store');
}

void main() {
  late Directory tmp;
  final cores = <LanDropCoreImpl>[];

  Future<LanDropCoreImpl> startCore(
    LanDropCoreOptions o, {
    String name = 'a',
  }) async {
    final c = LanDropCoreImpl(o);
    cores.add(c);
    final dir = await Directory('${tmp.path}/$name-save').create();
    await c.start(alias: 'Core $name', saveDir: dir.path);
    return c;
  }

  String base(LanDropCore c) => 'https://127.0.0.1:${c.self.port}';

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('landrop_web_test');
  });

  tearDown(() async {
    for (final c in cores) {
      await c.dispose();
    }
    cores.clear();
    await tmp.delete(recursive: true);
  });

  /// Pairs a browser (auto-approved) and returns its session token.
  Future<String> pair(LanDropCoreImpl c, {String? url}) async {
    final b = url ?? base(c);
    final sub = c.webPairing.listen((r) => r.decision.complete(true));
    try {
      final p = await _call('POST', '$b$_api/web/pair', json: {});
      expect(p.status, 200);
      final st = await _call('GET', '$b$_api/web/pair/${p.json!['id']}');
      expect(st.status, 200);
      return st.json!['token'] as String;
    } finally {
      await sub.cancel();
    }
  }

  group('parseRange', () {
    test('forms, clamping, ignored and unsatisfiable', () {
      String? r(String? h, [int size = 1000]) =>
          parseRange(h, size)?.toString();
      expect(r(null), isNull);
      expect(r('bytes=0-99'), '0-99');
      expect(r('bytes=100-'), '100-999');
      expect(r('bytes=-50'), '950-999');
      expect(r('bytes=-5000'), '0-999'); // suffix longer than file: whole
      expect(r('bytes=990-5000'), '990-999'); // end clamped
      expect(r('BYTES=1-2'), '1-2');
      expect(r('items=0-5'), isNull); // unknown unit ignored
      expect(r('bytes=0-1,5-6'), isNull); // multi-range ignored (full 200)
      for (final bad in [
        'bytes=1000-',
        'bytes=5000-6000',
        'bytes=5-2',
        'bytes=abc',
        'bytes=-',
        'bytes=-0',
        'bytes=1-2-3',
        'bytes=99999999999999999999999-',
      ]) {
        expect(
          () => parseRange(bad, 1000),
          throwsA(isA<RangeNotSatisfiable>()),
          reason: bad,
        );
      }
      expect(
        () => parseRange('bytes=0-', 0),
        throwsA(isA<RangeNotSatisfiable>()),
      );
    });

    test('content disposition is RFC 5987 encoded', () {
      expect(
        contentDisposition('a b.txt', inline: false),
        "attachment; filename=\"a b.txt\"; filename*=UTF-8''a%20b.txt",
      );
      expect(
        contentDisposition('é"(1).mp4', inline: true),
        "inline; filename=\"__(1).mp4\"; "
        "filename*=UTF-8''%C3%A9%22%281%29.mp4",
      );
    });
  });

  test(
    'range requests on a 5 MB file: 200, 206, 416, HEAD, reassembly',
    () async {
      final a = await startCore(_opts());
      final data = _randomBytes(5 << 20, 7);
      final f = File('${tmp.path}/clip.mp4')..writeAsBytesSync(data);
      final share = a.createShare([f.path]);
      expect(share.url, '${base(a)}/#s=${share.token}');
      expect(share.token, matches(RegExp(r'^[A-Za-z0-9_-]{22}$')));
      final fileId = share.files.single.id;
      final url = '${base(a)}$_api/shares/${share.token}/files/$fileId';
      const size = 5 << 20;

      final list = await _call('GET', '${base(a)}$_api/shares/${share.token}');
      expect(list.status, 200);
      _expectSecurityHeaders(list);
      final lf = (list.json!['files'] as List).single as Map;
      expect(lf['name'], 'clip.mp4');
      expect(lf['mime'], 'video/mp4');
      expect(lf['size'], size);

      final full = await _call('GET', url);
      expect(full.status, 200);
      _expectSecurityHeaders(full);
      expect(full.h('accept-ranges'), 'bytes');
      expect(full.h('content-type'), 'video/mp4');
      expect(full.h('content-length'), '$size');
      expect(full.h('content-range'), isNull);
      expect(
        full.h('content-disposition'),
        "attachment; filename=\"clip.mp4\"; filename*=UTF-8''clip.mp4",
      );
      expect(_sha(full.body), _sha(data));

      final r1 = await _call('GET', url, headers: {'Range': 'bytes=0-99'});
      expect(r1.status, 206);
      expect(r1.h('content-range'), 'bytes 0-99/$size');
      expect(r1.h('content-length'), '100');
      expect(r1.body, data.sublist(0, 100));

      final r2 = await _call('GET', url, headers: {'Range': 'bytes=100-'});
      expect(r2.status, 206);
      expect(r2.h('content-range'), 'bytes 100-${size - 1}/$size');
      expect(r2.h('content-length'), '${size - 100}');
      expect(_sha(r2.body), _sha(data.sublist(100)));

      final r3 = await _call('GET', url, headers: {'Range': 'bytes=-50'});
      expect(r3.status, 206);
      expect(r3.h('content-range'), 'bytes ${size - 50}-${size - 1}/$size');
      expect(r3.body, data.sublist(size - 50));

      final r4 = await _call('GET', url, headers: {'Range': 'bytes=$size-'});
      expect(r4.status, 416);
      expect(r4.h('content-range'), 'bytes */$size');
      _expectSecurityHeaders(r4);
      final r5 = await _call('GET', url, headers: {'Range': 'bytes=9-3'});
      expect(r5.status, 416);

      // Multi-range is ignored: full 200 body.
      final mr = await _call('GET', url, headers: {'Range': 'bytes=0-1,4-5'});
      expect(mr.status, 200);
      expect(mr.body.length, size);

      final head = await _call('HEAD', url);
      expect(head.status, 200);
      expect(head.h('content-length'), '$size');
      expect(head.h('accept-ranges'), 'bytes');
      expect(head.body, isEmpty);
      final headR = await _call('HEAD', url, headers: {'Range': 'bytes=10-19'});
      expect(headR.status, 206);
      expect(headR.h('content-range'), 'bytes 10-19/$size');
      expect(headR.h('content-length'), '10');
      expect(headR.body, isEmpty);

      final inline = await _call(
        'GET',
        '$url?inline=1',
        headers: {'Range': 'bytes=0-0'},
      );
      expect(inline.h('content-disposition'), startsWith('inline;'));

      // Reassemble from odd-sized ranges: byte-identical.
      final parts = BytesBuilder(copy: false);
      const step = 777777;
      for (var s = 0; s < size; s += step) {
        final e = min(s + step, size) - 1;
        final r = await _call('GET', url, headers: {'Range': 'bytes=$s-$e'});
        expect(r.status, 206);
        expect(r.h('content-range'), 'bytes $s-$e/$size');
        parts.add(r.body);
      }
      expect(_sha(parts.takeBytes()), _sha(data));
    },
  );

  test('HTML/SVG are never served inline; text gets a charset', () async {
    final a = await startCore(_opts());
    final h = File('${tmp.path}/page.html')
      ..writeAsStringSync('<script>1</script>');
    final t = File('${tmp.path}/notes.txt')..writeAsStringSync('hi');
    final s = a.createShare([h.path, t.path]);
    String u(SharedFile f) =>
        '${base(a)}$_api/shares/${s.token}/files/${f.id}?inline=1';
    final hr = await _call('GET', u(s.files[0]));
    expect(hr.h('content-disposition'), startsWith('attachment;'));
    expect(hr.h('x-content-type-options'), 'nosniff');
    final tr = await _call('GET', u(s.files[1]));
    expect(tr.h('content-disposition'), startsWith('inline;'));
    expect(tr.h('content-type'), 'text/plain; charset=utf-8');
  });

  test('wrong, expired, revoked and exhausted tokens give identical 404s', () async {
    final a = await startCore(_opts());
    final f = File('${tmp.path}/x.bin')
      ..writeAsBytesSync(_randomBytes(1000, 1));
    final expired = a.createShare([
      f.path,
    ], ttl: const Duration(milliseconds: 150));
    final revoked = a.createShare([f.path]);
    final exhausted = a.createShare([f.path], maxDownloads: 1);
    final good = a.createShare([f.path]);

    final dl = await _call(
      'GET',
      '${base(a)}$_api/shares/${exhausted.token}/files/${exhausted.files.single.id}',
    );
    expect(dl.status, 200);
    a.revokeShare(revoked.id);
    expect(a.shares.map((s) => s.id), isNot(contains(revoked.id)));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(a.shares.map((s) => s.id), isNot(contains(expired.id)));

    final ref = await _call('GET', '${base(a)}$_api/shares/${'A' * 22}');
    expect(ref.status, 404);
    _expectSecurityHeaders(ref);
    for (final s in [expired, revoked, exhausted]) {
      final l = await _call('GET', '${base(a)}$_api/shares/${s.token}');
      expect(l.status, 404, reason: s.id);
      expect(l.body, ref.body);
      expect(l.h('content-type'), ref.h('content-type'));
      expect(l.h('content-length'), ref.h('content-length'));
      final b = await _call(
        'GET',
        '${base(a)}$_api/shares/${s.token}/files/${s.files.single.id}',
      );
      expect(b.status, 404);
      expect(b.body, ref.body);
    }
    // A wrong file id under a good token: same 404.
    final wf = await _call(
      'GET',
      '${base(a)}$_api/shares/${good.token}/files/${'0' * 16}',
    );
    expect(wf.status, 404);
    expect(wf.body, ref.body);
    expect(
      (await _call('GET', '${base(a)}$_api/shares/${good.token}')).status,
      200,
    );
  });

  test('file ids are opaque; traversal in ids and paths is refused', () async {
    final a = await startCore(_opts());
    final dir = await Directory('${tmp.path}/Album/sub')
        .create(recursive: true);
    File('${dir.path}/b.txt').writeAsStringSync('bbb');
    File('${tmp.path}/Album/a.txt').writeAsStringSync('aaa');
    final secret = File('${tmp.path}/secret.txt')..writeAsStringSync('secret');
    final s = a.createShare(['${tmp.path}/Album']);
    expect(s.files.map((f) => f.name), ['Album/a.txt', 'Album/sub/b.txt']);
    for (final f in s.files) {
      expect(f.id, matches(RegExp(r'^[0-9a-f]{16}$')));
    }
    final l = await _call('GET', '${base(a)}$_api/shares/${s.token}');
    expect(l.text, isNot(contains(tmp.path)));
    final b = await _call(
      'GET',
      '${base(a)}$_api/shares/${s.token}/files/${s.files[1].id}',
    );
    expect(b.text, 'bbb');
    expect(b.h('content-disposition'), contains('filename="b.txt"'));

    final enc = Uri.encodeComponent;
    for (final id in [
      '../secret.txt',
      '../../secret.txt',
      secret.path,
      'sub/b.txt',
      'Album/a.txt',
      '%2e%2e%2fsecret.txt',
      '',
    ]) {
      final r = await _call(
        'GET',
        '${base(a)}$_api/shares/${s.token}/files/${enc(id)}',
      );
      expect(r.status, 404, reason: id);
      expect(r.text, isNot(contains('secret')));
    }
    for (final p in [
      '$_api/shares/${enc('../')}${s.token}/files/${s.files[0].id}',
      '$_api/shares/${s.token}/files/${s.files[0].id}/${enc('../../secret.txt')}',
      '$_api/shares/${s.token}%2F..%2F..%2Fsecret.txt',
    ]) {
      final r = await _call('GET', '${base(a)}$p');
      expect(r.status, 404, reason: p);
      expect(r.text, isNot(contains('secret')));
    }
    // The file changed size after sharing: no longer served.
    File('${tmp.path}/Album/a.txt').writeAsStringSync('changed!');
    final ch = await _call(
      'GET',
      '${base(a)}$_api/shares/${s.token}/files/${s.files[0].id}',
    );
    expect(ch.status, 404);
  });

  test('maxDownloads is honoured; ranges cannot bypass it', () async {
    final a = await startCore(_opts(streamWindow: Duration.zero));
    final data = _randomBytes(5 << 20, 3);
    final f = File('${tmp.path}/m.bin')..writeAsBytesSync(data);

    // Two full downloads allowed, the third is refused.
    final s2 = a.createShare([f.path], maxDownloads: 2);
    String url(Share s) =>
        '${base(a)}$_api/shares/${s.token}/files/${s.files.single.id}';
    expect((await _call('GET', url(s2))).status, 200);
    await _settle();
    expect(a.shares.firstWhere((x) => x.id == s2.id).downloadsLeft, 1);
    // HEAD is never charged.
    expect((await _call('HEAD', url(s2))).status, 200);
    expect(a.shares.firstWhere((x) => x.id == s2.id).downloadsLeft, 1);
    expect((await _call('GET', url(s2))).status, 200);
    await _settle();
    expect(a.shares.firstWhere((x) => x.id == s2.id).downloadsLeft, 0);
    expect((await _call('GET', url(s2))).status, 404);
    expect(
      (await _call('GET', url(s2), headers: {'Range': 'bytes=5-9'})).status,
      404,
    );

    // A partial range is charged at once (first request of a sequence).
    final s1 = a.createShare([f.path], maxDownloads: 1);
    final p1 = await _call('GET', url(s1), headers: {'Range': 'bytes=0-9'});
    expect(p1.status, 206);
    expect(a.shares.firstWhere((x) => x.id == s1.id).downloadsLeft, 0);
    // With the sequence window closed (0 here), more ranges are refused, so
    // the file cannot be reassembled range by range.
    final p2 = await _call('GET', url(s1), headers: {'Range': 'bytes=10-19'});
    expect(p2.status, 404);
    expect(
      (await _call('GET', '${base(a)}$_api/shares/${s1.token}')).status,
      404,
    );

    // Concurrent full reads cannot exceed the limit (slot reserved in flight).
    final sc = a.createShare([f.path], maxDownloads: 1);
    final both = await Future.wait([
      _call('GET', url(sc)),
      _call('GET', url(sc)),
    ]);
    expect(both.map((r) => r.status).toList()..sort(), [200, 404]);
  });

  test('range sequence window lets a player seek after the charge', () async {
    final a = await startCore(_opts());
    final data = _randomBytes(1 << 20, 4);
    final f = File('${tmp.path}/v.mp4')..writeAsBytesSync(data);
    final s = a.createShare([f.path], maxDownloads: 1);
    final url = '${base(a)}$_api/shares/${s.token}/files/${s.files.single.id}';
    expect(
      (await _call('GET', url, headers: {'Range': 'bytes=1000-'})).status,
      206,
    );
    expect(a.shares.single.downloadsLeft, 0);
    // Same client, same file: seeking keeps working without a new charge.
    final r = await _call('GET', url, headers: {'Range': 'bytes=0-'});
    expect(r.status, 206);
    expect(_sha(r.body), _sha(data));
    expect(a.shares.single.downloadsLeft, 0);
    // A new client would get the 404 (listing reflects that).
    expect(
      (await _call('GET', '${base(a)}$_api/shares/${s.token}')).status,
      404,
    );
  });

  test(
    'pairing: 401 without session, decline 403, approve -> upload works',
    () async {
      final a = await startCore(_opts());
      final b = base(a);
      // No session: upload endpoints refuse.
      expect((await _call('GET', '$b$_api/web/session')).status, 401);
      expect(
        (await _call(
          'POST',
          '$b$_api/web/upload-prepare',
          json: {
            'files': [
              {'id': '0', 'fileName': 'a.txt', 'size': 1},
            ],
          },
        )).status,
        401,
      );
      expect(
        (await _call(
          'POST',
          '$b$_api/web/upload?sessionId=x&fileId=0&token=y',
          bytes: [1, 2, 3],
        )).status,
        401,
      );
      expect(
        (await _call(
          'POST',
          '$b$_api/web/upload-prepare',
          headers: {'Authorization': 'Bearer nope'},
          json: {'files': []},
        )).status,
        401,
      );

      // Decline.
      final seen = <WebPairingRequest>[];
      var answer = false;
      final sub = a.webPairing.listen((r) {
        seen.add(r);
        r.decision.complete(answer);
      });
      final p = await _call(
        'POST',
        '$b$_api/web/pair',
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/129.0 Mobile Safari/537.36',
        },
        json: {},
      );
      expect(p.status, 200);
      _expectSecurityHeaders(p);
      expect(p.json!['code'], matches(RegExp(r'^\d{4}$')));
      final declined = await _call('GET', '$b$_api/web/pair/${p.json!['id']}');
      expect(declined.status, 403);
      expect(declined.json!['status'], 'declined');
      expect(declined.headers['set-cookie'], isNull);
      expect(seen.single.code, p.json!['code']);
      expect(seen.single.remoteIp, '127.0.0.1');
      expect(seen.single.userAgent, 'Chrome on Android');
      // The pairing id is single use.
      expect(
        (await _call('GET', '$b$_api/web/pair/${p.json!['id']}')).status,
        404,
      );

      // Approve.
      answer = true;
      final p2 = await _call('POST', '$b$_api/web/pair', json: {});
      final ok = await _call('GET', '$b$_api/web/pair/${p2.json!['id']}');
      expect(ok.status, 200);
      expect(ok.json!['status'], 'approved');
      final token = ok.json!['token'] as String;
      expect(token.length, greaterThanOrEqualTo(40));
      final cookie = ok.headers['set-cookie']!.single;
      expect(cookie, startsWith('landrop_session=$token;'));
      for (final part in [
        'HttpOnly',
        'SameSite=Strict',
        'Path=/',
        'Max-Age=3600',
        'Secure',
      ]) {
        expect(cookie, contains(part));
      }
      await sub.cancel();
      expect(
        (await _call(
          'GET',
          '$b$_api/web/session',
          headers: {'Cookie': 'other=1; landrop_session=$token'},
        )).status,
        200,
      );
      final auth = {'Authorization': 'Bearer $token'};
      expect(
        (await _call('GET', '$b$_api/web/session', headers: auth)).status,
        200,
      );

      // Browser upload through the normal Accept dialog and receive pipeline.
      final data = _randomBytes(1536 * 1024 + 7, 9);
      IncomingRequest? got;
      final inSub = a.incoming.listen((r) {
        got = r;
        r.decision.complete(true);
      });
      final prep = await _call(
        'POST',
        '$b$_api/web/upload-prepare',
        headers: {'Cookie': 'landrop_session=$token'},
        json: {
          'files': [
            {
              'id': '0',
              'fileName': '../../photo.bin',
              'size': data.length,
              'fileType': 'application/octet-stream',
            },
          ],
        },
      );
      expect(prep.status, 200);
      _expectSecurityHeaders(prep);
      expect(got!.sender.alias, 'Browser 127.0.0.1');
      expect(got!.sender.deviceType, 'web');
      expect(got!.files.single.fileName, 'photo.bin'); // sanitised
      final sid = prep.json!['sessionId'] as String;
      final ftok = (prep.json!['files'] as Map)['0'] as String;
      final q = 'sessionId=$sid&fileId=0&token=$ftok';

      // Another browser session cannot use these tokens.
      final other = await pair(a);
      final stolen = await _call(
        'POST',
        '$b$_api/web/upload?$q',
        headers: {'Authorization': 'Bearer $other'},
        bytes: data,
      );
      expect(stolen.status, 403);

      final up = await _call(
        'POST',
        '$b$_api/web/upload?$q',
        headers: auth,
        bytes: data,
      );
      expect(up.status, 200);
      _expectSecurityHeaders(up);
      final dst = File('${tmp.path}/a-save/photo.bin');
      expect(dst.existsSync(), isTrue);
      expect(_sha(dst.readAsBytesSync()), _sha(data));

      // Owner declines a second batch -> 403.
      await inSub.cancel();
      final decSub = a.incoming.listen((r) => r.decision.complete(false));
      final dec = await _call(
        'POST',
        '$b$_api/web/upload-prepare',
        headers: auth,
        json: {
          'files': [
            {'id': '0', 'fileName': 'x.txt', 'size': 1},
          ],
        },
      );
      expect(dec.status, 403);
      await decSub.cancel();

      // A cross-site POST (foreign Origin) is refused.
      final xs = await _call(
        'POST',
        '$b$_api/web/pair',
        headers: {'Origin': 'http://evil.test'},
        json: {},
      );
      expect(xs.status, 403);
    },
  );

  test('pairing times out; duplicate is 409; rate limit gives 429', () async {
    final a = await startCore(
      _opts(rateLimit: 4, pairingTimeout: const Duration(milliseconds: 300)),
    );
    final b = base(a);
    final got = <WebPairingRequest>[];
    final sub = a.webPairing.listen(got.add); // never answers
    final p = await _call('POST', '$b$_api/web/pair', json: {}); // attempt 1
    expect(p.status, 200);
    final dup = await _call('POST', '$b$_api/web/pair', json: {}); // 2
    expect(dup.status, 409);
    final st = await _call('GET', '$b$_api/web/pair/${p.json!['id']}'); // 3
    expect(st.status, 403);
    expect(st.json!['status'], 'expired');
    expect(got.single.decision.isCompleted, isTrue);
    expect(await got.single.decision.future, isFalse);
    await sub.cancel();

    final f = File('${tmp.path}/r.txt')..writeAsStringSync('r');
    final good = a.createShare([f.path]);
    // The timeout counted as attempt 3; one wrong token reaches the limit.
    expect((await _call('GET', '$b$_api/shares/${'B' * 22}')).status, 404);
    final limited = await _call('GET', '$b$_api/shares/${good.token}');
    expect(limited.status, 429);
    _expectSecurityHeaders(limited);
    expect((await _call('POST', '$b$_api/web/pair', json: {})).status, 429);
    // The page itself is still served.
    expect((await _call('GET', '$b/')).status, 200);
  });

  test(
    'HTTP listener: off by default; page and shares only; no Secure',
    () async {
      final a = await startCore(_opts());
      expect(a.webHttpEnabled, isFalse);
      expect(a.webHttpPort, isNull);
      expect(a.webHttpUrl, isNull);
      expect(a.webUrl, '${base(a)}/');

      final f = File('${tmp.path}/h.txt')..writeAsStringSync('hello http');
      final s = a.createShare([f.path]);
      expect(s.httpUrl, isNull);

      final changes = <List<Share>>[];
      final sub = a.sharesChanged.listen(changes.add);
      await a.setWebHttpEnabled(true);
      final port = a.webHttpPort!;
      final hb = 'http://127.0.0.1:$port';
      expect(a.webHttpUrl, '$hb/');
      await Future<void>.delayed(Duration.zero);
      expect(changes.last.single.httpUrl, '$hb/#s=${s.token}');
      await sub.cancel();

      final page = await _call('GET', '$hb/');
      expect(page.status, 200);
      expect(page.h('content-type'), startsWith('text/html'));
      expect(page.text, webPageHtml);
      _expectSecurityHeaders(page);
      final l = await _call('GET', '$hb$_api/shares/${s.token}');
      expect(l.status, 200);
      final fb = await _call(
        'GET',
        '$hb$_api/shares/${s.token}/files/${s.files.single.id}',
        headers: {'Range': 'bytes=6-'},
      );
      expect(fb.status, 206);
      expect(fb.text, 'http');

      // Never the device API over plain HTTP.
      for (final (m, p) in [
        ('GET', '/api/localsend/v2/info'),
        ('POST', '/api/localsend/v2/register'),
        ('POST', '/api/localsend/v2/prepare-upload'),
        ('POST', '/api/localsend/v2/upload'),
        ('POST', '/api/localsend/v2/cancel'),
        ('GET', '/api/landrop/v1/capabilities'),
        ('GET', '/api/landrop/v1/upload-status'),
      ]) {
        final r = await _call(m, '$hb$p', json: m == 'POST' ? {} : null);
        expect(r.status, 404, reason: p);
        _expectSecurityHeaders(r);
      }

      // Pairing over HTTP: cookie without Secure.
      final sub2 = a.webPairing.listen((r) => r.decision.complete(true));
      final p = await _call('POST', '$hb$_api/web/pair', json: {});
      final ok = await _call('GET', '$hb$_api/web/pair/${p.json!['id']}');
      await sub2.cancel();
      final cookie = ok.headers['set-cookie']!.single;
      expect(cookie, contains('HttpOnly'));
      expect(cookie, contains('SameSite=Strict'));
      expect(cookie, isNot(contains('Secure')));

      await a.setWebHttpEnabled(false);
      expect(a.webHttpPort, isNull);
      await expectLater(
        Socket.connect('127.0.0.1', port),
        throwsA(isA<SocketException>()),
      );
    },
  );

  test('HTTP listener can be on from the start (options.httpPort)', () async {
    final a = await startCore(_opts(httpPort: 0));
    expect(a.webHttpEnabled, isTrue);
    final r = await _call('GET', 'http://127.0.0.1:${a.webHttpPort}/');
    expect(r.status, 200);
  });

  test(
    'page asset: no external URLs, no markup sinks, served with headers',
    () async {
      expect(
        RegExp(r'https?://', caseSensitive: false).hasMatch(webPageHtml),
        isFalse,
      );
      expect(
        RegExp(r'''(src|href|action)\s*=\s*["']?\s*//''').hasMatch(webPageHtml),
        isFalse,
      );
      expect(webPageHtml, isNot(contains('@import')));
      expect(webPageHtml, isNot(contains('url(')));
      for (final sink in [
        'innerHTML',
        'outerHTML',
        'insertAdjacentHTML',
        'document.write',
        'eval(',
        'new Function',
      ]) {
        expect(webPageHtml, isNot(contains(sink)), reason: sink);
      }
      expect(webPageHtml, contains('textContent'));
      expect(
        webPageHtml,
        contains('<meta name="referrer" content="no-referrer">'),
      );
      expect(webPageHtml, contains('prefers-color-scheme: dark'));
      // Media previews are created as elements, not markup.
      expect(webPageHtml, contains("el(kind, 'preview')"));

      final a = await startCore(_opts());
      final page = await _call('GET', '${base(a)}/');
      expect(page.status, 200);
      expect(page.h('content-type'), startsWith('text/html'));
      expect(page.text, webPageHtml);
      _expectSecurityHeaders(page);
      final head = await _call('HEAD', '${base(a)}/');
      expect(head.status, 200);
      expect(head.body, isEmpty);
      // The device API is unaffected on HTTPS.
      expect(
        (await _call('GET', '${base(a)}/api/localsend/v2/info')).status,
        200,
      );
    },
  );

  test('hostile file names travel as JSON data only', () async {
    final a = await startCore(_opts());
    const evil = '<img src=x onerror=alert(1)>.txt';
    final f = File('${tmp.path}/$evil')..writeAsStringSync('x');
    final s = a.createShare([f.path]);
    final l = await _call('GET', '${base(a)}$_api/shares/${s.token}');
    expect(l.status, 200);
    expect(l.h('content-type'), startsWith('application/json'));
    expect(l.h('x-content-type-options'), 'nosniff');
    expect((l.json!['files'] as List).single['name'], evil);
    // The page renders names with textContent / attributes only.
    expect(webPageHtml, contains("nameSpan(f.name)"));
    expect(webPageHtml, contains("var s = el('span', 'name', name);"));
    final file = await _call(
      'GET',
      '${base(a)}$_api/shares/${s.token}/files/${s.files.single.id}',
    );
    expect(
      file.h('content-disposition'),
      contains(
        "filename*=UTF-8''%3Cimg%20src%3Dx%20onerror%3Dalert%281%29%3E.txt",
      ),
    );
  });

  test('end to end: two cores, 30 MB share fetched by ranges, re-uploaded '
      'through the browser API', () async {
    final a = await startCore(_opts(), name: 'a');
    final b = await startCore(_opts(), name: 'b');
    final data = _randomBytes(30 << 20, 30);
    final f = File('${tmp.path}/big.bin')..writeAsBytesSync(data);
    final s = a.createShare([f.path], maxDownloads: 1);
    final url = '${base(a)}$_api/shares/${s.token}/files/${s.files.single.id}';
    const size = 30 << 20;
    const chunk = 4 << 20;
    final out = BytesBuilder(copy: false);
    final c = HttpClient()..badCertificateCallback = (_, _, _) => true;
    try {
      for (var st = 0; st < size; st += chunk) {
        final e = min(st + chunk, size) - 1;
        final req = await c.getUrl(Uri.parse(url));
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=$st-$e');
        final res = await req.close();
        expect(res.statusCode, 206);
        expect(res.headers.value('content-range'), 'bytes $st-$e/$size');
        await for (final ch in res) {
          out.add(ch);
        }
      }
    } finally {
      c.close(force: true);
    }
    final got = out.takeBytes();
    expect(got.length, size);
    expect(_sha(got), _sha(data));
    expect(a.shares.single.downloadsLeft, 0); // one download for the sequence

    final token = await pair(b);
    final inSub = b.incoming.listen((r) => r.decision.complete(true));
    final auth = {'Authorization': 'Bearer $token'};
    final prep = await _call(
      'POST',
      '${base(b)}$_api/web/upload-prepare',
      headers: auth,
      json: {
        'files': [
          {'id': 'f', 'fileName': 'big.bin', 'size': size},
        ],
      },
    );
    expect(prep.status, 200);
    final q =
        'sessionId=${prep.json!['sessionId']}&fileId=f'
        '&token=${(prep.json!['files'] as Map)['f']}';
    final up = await _call(
      'POST',
      '${base(b)}$_api/web/upload?$q',
      headers: auth,
      bytes: got,
    );
    expect(up.status, 200);
    await inSub.cancel();
    final dst = File('${tmp.path}/b-save/big.bin');
    expect(_sha(await dst.readAsBytes()), _sha(data));
  }, timeout: const Timeout(Duration(minutes: 2)));

  // ------------------------------------------------ browser sessions

  test(
    'logout ends the session, clears the cookie and is idempotent',
    () async {
      final a = await startCore(_opts());
      final b = base(a);
      final changes = <List<WebSessionInfo>>[];
      final sub = a.webSessionsChanged.listen(changes.add);
      final token = await pair(a);
      final auth = {'Authorization': 'Bearer $token'};
      expect(a.webSessions, hasLength(1));
      final info = a.webSessions.single;
      expect(info.remoteIp, '127.0.0.1');
      expect(info.userAgent, 'Dart client');
      expect(info.id, isNot(token));
      expect(info.pairedAt.isAfter(info.lastSeen), isFalse);
      expect(changes.last.single.id, info.id);

      // A foreign Origin cannot sign the browser out (CSRF).
      final xs = await _call(
        'POST',
        '$b$_api/web/logout',
        headers: {...auth, 'Origin': 'http://evil.test'},
        json: {},
      );
      expect(xs.status, 403);
      expect(
        (await _call('GET', '$b$_api/web/session', headers: auth)).status,
        200,
      );

      final out = await _call(
        'POST',
        '$b$_api/web/logout',
        headers: {'Cookie': 'landrop_session=$token'},
        json: {},
      );
      expect(out.status, 200);
      _expectSecurityHeaders(out);
      final cookie = out.headers['set-cookie']!.single;
      expect(cookie, startsWith('landrop_session=;'));
      for (final part in [
        'Max-Age=0',
        'Path=/',
        'HttpOnly',
        'SameSite=Strict',
        'Secure',
      ]) {
        expect(cookie, contains(part));
      }
      expect(a.webSessions, isEmpty);
      await Future<void>.delayed(Duration.zero);
      expect(changes.last, isEmpty);
      await sub.cancel();

      // The token is dead, by header and by cookie.
      expect(
        (await _call('GET', '$b$_api/web/session', headers: auth)).status,
        401,
      );
      expect(
        (await _call(
          'GET',
          '$b$_api/web/session',
          headers: {'Cookie': 'landrop_session=$token'},
        )).status,
        401,
      );
      expect(
        (await _call(
          'POST',
          '$b$_api/web/upload-prepare',
          headers: auth,
          json: {
            'files': [
              {'id': '0', 'fileName': 'a.txt', 'size': 1},
            ],
          },
        )).status,
        401,
      );
      // Signing out twice (or without a session) is fine.
      expect((await _call('POST', '$b$_api/web/logout', json: {})).status, 200);
    },
  );

  test('logout over plain HTTP clears the cookie without Secure', () async {
    final a = await startCore(_opts(httpPort: 0));
    final hb = 'http://127.0.0.1:${a.webHttpPort}';
    final token = await pair(a, url: hb);
    final out = await _call(
      'POST',
      '$hb$_api/web/logout',
      headers: {'Authorization': 'Bearer $token'},
      json: {},
    );
    expect(out.status, 200);
    final cookie = out.headers['set-cookie']!.single;
    expect(cookie, contains('Max-Age=0'));
    expect(cookie, isNot(contains('Secure')));
    expect(a.webSessions, isEmpty);
  });

  test(
    'revoking a browser: token dies, prepared uploads are refused',
    () async {
      final a = await startCore(_opts());
      final b = base(a);
      final token = await pair(a);
      final auth = {'Authorization': 'Bearer $token'};
      final inSub = a.incoming.listen((r) => r.decision.complete(true));
      final prep = await _call(
        'POST',
        '$b$_api/web/upload-prepare',
        headers: auth,
        json: {
          'files': [
            {'id': '0', 'fileName': 'one.txt', 'size': 3},
            {'id': '1', 'fileName': 'two.txt', 'size': 3},
          ],
        },
      );
      expect(prep.status, 200);
      final sid = prep.json!['sessionId'] as String;
      final toks = prep.json!['files'] as Map;
      String q(String id) => 'sessionId=$sid&fileId=$id&token=${toks[id]}';
      expect(
        (await _call(
          'POST',
          '$b$_api/web/upload?${q('0')}',
          headers: auth,
          bytes: [1, 2, 3],
        )).status,
        200,
      );

      final changes = <List<WebSessionInfo>>[];
      final sub = a.webSessionsChanged.listen(changes.add);
      a.revokeWebSession(a.webSessions.single.id);
      a.revokeWebSession('unknown'); // ignored
      expect(a.webSessions, isEmpty);
      await Future<void>.delayed(Duration.zero);
      expect(changes.single, isEmpty);
      await sub.cancel();

      expect(
        (await _call('GET', '$b$_api/web/session', headers: auth)).status,
        401,
      );
      // Upload after revoke: the browser token is refused ...
      final after = await _call(
        'POST',
        '$b$_api/web/upload?${q('1')}',
        headers: auth,
        bytes: [4, 5, 6],
      );
      expect(after.status, 401);
      // ... and so is the receive session itself, even with its file token.
      final direct = await _call(
        'POST',
        '$b/api/localsend/v2/upload?${q('1')}',
        bytes: [4, 5, 6],
      );
      expect(direct.status, 403);
      expect(File('${tmp.path}/a-save/one.txt').existsSync(), isTrue);
      expect(File('${tmp.path}/a-save/two.txt').existsSync(), isFalse);
      await inSub.cancel();
    },
  );

  test('revoking a browser aborts its upload in flight', () async {
    final a = await startCore(_opts());
    final b = base(a);
    final token = await pair(a);
    final auth = {'Authorization': 'Bearer $token'};
    final inSub = a.incoming.listen((r) => r.decision.complete(true));
    const size = 4 << 20;
    final prep = await _call(
      'POST',
      '$b$_api/web/upload-prepare',
      headers: auth,
      json: {
        'files': [
          {'id': '0', 'fileName': 'big.bin', 'size': size},
        ],
      },
    );
    expect(prep.status, 200);
    final sid = prep.json!['sessionId'] as String;
    final ftok = (prep.json!['files'] as Map)['0'];
    final started = a.progress.firstWhere(
      (p) => p.sessionId == sid && p.error == null,
    );
    final errored = a.progress.firstWhere(
      (p) => p.sessionId == sid && p.error != null,
    );

    final c = HttpClient()..badCertificateCallback = (_, _, _) => true;
    int? status;
    try {
      final req = await c.postUrl(
        Uri.parse('$b$_api/web/upload?sessionId=$sid&fileId=0&token=$ftok'),
      );
      req.headers.set('Authorization', 'Bearer $token');
      req.contentLength = size;
      final data = _randomBytes(size, 11);
      req.add(data.sublist(0, 256 << 10));
      await req.flush();
      await started; // the receiver is writing
      a.revokeWebSession(a.webSessions.single.id);
      req.add(data.sublist(256 << 10));
      final res = await req.close();
      status = res.statusCode;
      await res.drain<void>();
    } catch (_) {
      status = null; // the receiver may cut the connection instead
    } finally {
      c.close(force: true);
    }
    expect(status, isNot(200));
    final err = await errored.timeout(const Duration(seconds: 5));
    expect(err.done, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final left = Directory('${tmp.path}/a-save')
        .listSync()
        .map((e) => e.path.split(Platform.pathSeparator).last)
        .toList();
    expect(left, isNot(contains('big.bin')));
    expect(left.where((n) => n.endsWith('.part')), isEmpty);
    await inSub.cancel();
  });

  test('a browser disconnected while the owner decides gets 401', () async {
    final a = await startCore(_opts());
    final token = await pair(a);
    final inSub = a.incoming.listen((r) {
      a.revokeWebSession(a.webSessions.single.id);
      r.decision.complete(true);
    });
    final prep = await _call(
      'POST',
      '${base(a)}$_api/web/upload-prepare',
      headers: {'Authorization': 'Bearer $token'},
      json: {
        'files': [
          {'id': '0', 'fileName': 'x.txt', 'size': 1},
        ],
      },
    );
    expect(prep.status, 401);
    await inSub.cancel();
  });

  test('page has a Sign out button that calls logout', () {
    expect(webPageHtml, contains('id="signout-btn"'));
    expect(webPageHtml, contains(">Sign out<"));
    expect(webPageHtml, contains("API + '/web/logout'"));
  });

  group('page i18n', () {
    // Keys of one language block of `var T = {en: {...}, fa: {...}}`.
    Set<String> dictKeys(String lang) {
      final start = webPageHtml.indexOf('\n    $lang: {');
      expect(start, greaterThan(0), reason: lang);
      final end = webPageHtml.indexOf('\n    }', start);
      final block = webPageHtml.substring(start, end);
      return RegExp(
        r'^      (\w+):',
        multiLine: true,
      ).allMatches(block).map((m) => m.group(1)!).toSet();
    }

    String scriptAfterDictionary() {
      final i = webPageHtml.indexOf(
        '// ------------------------------------------------------------ language',
      );
      expect(i, greaterThan(0));
      return webPageHtml.substring(i);
    }

    test('en and fa dictionaries have the same keys', () {
      final en = dictKeys('en');
      final fa = dictKeys('fa');
      expect(en.length, greaterThan(40));
      expect(en.difference(fa), isEmpty, reason: 'missing in fa');
      expect(fa.difference(en), isEmpty, reason: 'missing in en');
    });

    test('every key the page uses exists, and every key is used', () {
      final keys = dictKeys('en');
      final js = scriptAfterDictionary();
      final html = webPageHtml.substring(0, webPageHtml.indexOf('<script>'));
      final used = <String>{};
      void add(RegExp r, {String suffix = ''}) {
        for (final m in r.allMatches(js)) {
          used.add(m.group(1)! + suffix);
        }
      }

      add(RegExp(r"\bt\('(\w+)'\)"));
      add(RegExp(r"\btx\([^,()]+, '(\w+)'"));
      add(RegExp(r"\btel\('\w+', '[^']*', '(\w+)'"));
      add(RegExp(r"\bax\([^,()]+, '(\w+)'"));
      add(RegExp(r"\bsetMsg\('[\w-]+', '(\w+)'"));
      add(RegExp(r"\bshowPair\('(\w+)'"));
      add(RegExp(r"\bfinish\('(\w+)'"));
      add(RegExp(r"\btn\('(\w+)'"), suffix: '1');
      add(RegExp(r"\btn\('(\w+)'"), suffix: 'N');
      // Keys chosen by ternaries.
      for (final m in RegExp(
        r"\? '(\w+)'|: '(\w+)'|\? \['(\w+)'|: \['(\w+)'",
      ).allMatches(js)) {
        for (var g = 1; g <= 4; g++) {
          final k = m.group(g);
          if (k != null && keys.contains(k)) used.add(k);
        }
      }
      for (final m in RegExp(r'data-ta?="(\w+)"').allMatches(html)) {
        used.add(m.group(1)!);
      }
      expect(used.difference(keys), isEmpty, reason: 'used but undefined');
      expect(keys.difference(used), isEmpty, reason: 'defined but unused');
    });

    test('no user-visible English is hard-coded in the script', () {
      final js = scriptAfterDictionary();
      for (final bad in [
        "'Download'",
        "'Open '",
        "'Sending ",
        "'Sent '",
        "' B'",
        "'Show'",
        "'Play'",
      ]) {
        expect(js, isNot(contains(bad)), reason: bad);
      }
    });

    test('lang/dir handling, toggle, persistence and bidi isolation', () {
      expect(webPageHtml, contains('document.documentElement'));
      expect(webPageHtml, contains("root.dir = lang === 'fa' ? 'rtl' : 'ltr'"));
      expect(webPageHtml, contains('root.lang = lang'));
      expect(webPageHtml, contains('navigator.language'));
      expect(webPageHtml, contains(r"/^fa/i"));
      expect(webPageHtml, contains("localStorage.getItem('landrop-lang')"));
      expect(webPageHtml, contains("localStorage.setItem('landrop-lang'"));
      // Storage is guarded: a throwing localStorage must not break the page.
      expect(
        RegExp(r'try \{[^}]*localStorage\.getItem').hasMatch(webPageHtml),
        isTrue,
      );
      expect(
        RegExp(r'try \{ localStorage\.setItem').hasMatch(webPageHtml),
        isTrue,
      );
      expect(webPageHtml, contains('function fmtNum'));
      expect(webPageHtml, contains('0x06F0'));
      expect(webPageHtml, contains("el('bdi'"));
      expect(webPageHtml, contains('unicode-bidi: isolate'));
      expect(webPageHtml, contains('id="pair-code" class="code" dir="ltr"'));
      expect(webPageHtml, contains("setAttribute('dir', 'auto')"));
      // RTL support uses logical properties only.
      expect(
        RegExp(r'(margin|padding)-(left|right)|text-align:\s*(left|right)')
            .hasMatch(webPageHtml),
        isFalse,
      );
      expect(webPageHtml, contains('REVIEW:'));
    });

    test('the served page contains the language toggle', () async {
      final a = await startCore(_opts());
      final page = await _call('GET', '${base(a)}/');
      expect(page.status, 200);
      expect(page.text, contains('id="lang-btn"'));
      expect(page.text, contains('landrop-lang'));
    });
  });

  // ------------------------------------------------ share persistence

  group('share store', () {
    late String store;
    setUp(() => store = '${tmp.path}/support/landrop_shares.json');

    Future<void> drop(LanDropCoreImpl c) async {
      cores.remove(c);
      await c.dispose();
    }

    test('shares survive a restart with the same tokens, limits and a new '
        'port', () async {
      final a = await startCore(_opts(sharesStorePath: store), name: 'a');
      final data = _randomBytes(100000, 21);
      final f = File('${tmp.path}/keep.bin')..writeAsBytesSync(data);
      final limited = a.createShare(
        [f.path],
        ttl: const Duration(hours: 1),
        maxDownloads: 3,
      );
      final forever = a.createShare([f.path]);
      final url =
          '${base(a)}$_api/shares/${limited.token}/files/${limited.files.single.id}';
      expect((await _call('GET', url)).status, 200);
      await _settle();
      expect(a.shares.firstWhere((s) => s.id == limited.id).downloadsLeft, 2);
      final file = File(store);
      expect(file.existsSync(), isTrue);
      expect(File('$store.tmp').existsSync(), isFalse);
      if (Platform.isMacOS || Platform.isLinux) {
        expect(file.statSync().mode & 0x3f, 0, reason: 'owner-only');
      }
      await drop(a);

      final b = await startCore(_opts(sharesStorePath: store), name: 'b');
      expect(b.self.port, isNot(0));
      final got = {for (final s in b.shares) s.id: s};
      expect(got.keys.toSet(), {limited.id, forever.id});
      final l = got[limited.id]!;
      expect(l.token, limited.token);
      expect(l.downloadsLeft, 2);
      expect(l.maxDownloads, 3);
      expect(
        l.expiresAt!.difference(limited.expiresAt!).inSeconds.abs(),
        lessThan(1),
      );
      expect(l.files.single.id, limited.files.single.id);
      expect(l.files.single.name, 'keep.bin');
      expect(got[forever.id]!.expiresAt, isNull);
      expect(got[forever.id]!.downloadsLeft, isNull);
      // The link is rebuilt for the current address; the token is what counts.
      expect(l.url, '${base(b)}/#s=${limited.token}');
      final again = await _call(
        'GET',
        '${base(b)}$_api/shares/${l.token}/files/${l.files.single.id}',
      );
      expect(again.status, 200);
      expect(_sha(again.body), _sha(data));
      await _settle();
      expect(b.shares.firstWhere((s) => s.id == limited.id).downloadsLeft, 1);
      // And the new count is stored too.
      final stored = jsonDecode(File(store).readAsStringSync()) as Map;
      final row = (stored['shares'] as List).cast<Map>().firstWhere(
        (s) => s['id'] == limited.id,
      );
      expect(row['downloadsLeft'], 1);
    });

    test('expired, missing and changed files are dropped on restore', () async {
      final a = await startCore(_opts(sharesStorePath: store), name: 'a');
      File mk(String n) => File('${tmp.path}/$n')..writeAsStringSync('12345');
      final expired = a.createShare([
        mk('e.txt').path,
      ], ttl: const Duration(milliseconds: 300));
      final missing = a.createShare([mk('m.txt').path]);
      final changed = a.createShare([mk('c.txt').path]);
      final dir = await Directory('${tmp.path}/Album').create();
      File('${dir.path}/1.txt').writeAsStringSync('1');
      File('${dir.path}/2.txt').writeAsStringSync('2');
      final folderPartlyGone = a.createShare([dir.path]);
      final good = a.createShare([mk('g.txt').path], maxDownloads: 1);
      final storedTokens = File(store).readAsStringSync();
      for (final s in [expired, missing, changed, folderPartlyGone, good]) {
        expect(storedTokens, contains(s.token));
      }
      await drop(a);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      File('${tmp.path}/m.txt').deleteSync();
      File('${tmp.path}/c.txt').writeAsStringSync('123456'); // new size
      File('${dir.path}/2.txt').deleteSync();

      final b = await startCore(_opts(sharesStorePath: store), name: 'b');
      expect(b.shares.map((s) => s.id), [good.id]);
      expect(b.shares.single.downloadsLeft, 1);
      final after = File(store).readAsStringSync();
      expect(after, contains(good.token));
      for (final s in [expired, missing, changed, folderPartlyGone]) {
        expect(after, isNot(contains(s.token)), reason: s.id);
        expect(
          (await _call('GET', '${base(b)}$_api/shares/${s.token}')).status,
          404,
        );
      }
    });

    test('a used-up share is not restored', () async {
      final a = await startCore(_opts(sharesStorePath: store), name: 'a');
      final f = File('${tmp.path}/once.txt')..writeAsStringSync('once');
      final s = a.createShare([f.path], maxDownloads: 1);
      expect(
        (await _call(
          'GET',
          '${base(a)}$_api/shares/${s.token}/files/${s.files.single.id}',
        )).status,
        200,
      );
      await _settle();
      await drop(a);
      final b = await startCore(_opts(sharesStorePath: store), name: 'b');
      expect(b.shares, isEmpty);
    });

    test(
      'turning persistence off deletes the store and stops writing',
      () async {
        final a = await startCore(_opts(sharesStorePath: store), name: 'a');
        expect(a.sharesPersistence, isTrue);
        final f = File('${tmp.path}/p.txt')..writeAsStringSync('p');
        final s1 = a.createShare([f.path]);
        expect(File(store).existsSync(), isTrue);
        a.setSharesPersistence(false);
        expect(a.sharesPersistence, isFalse);
        expect(File(store).existsSync(), isFalse);
        a.createShare([f.path]);
        a.revokeShare(s1.id);
        expect(File(store).existsSync(), isFalse);
        expect(a.shares, hasLength(1)); // still active until the app stops
        a.setSharesPersistence(true);
        expect(File(store).existsSync(), isTrue);
        expect(
          (jsonDecode(File(store).readAsStringSync())['shares'] as List),
          hasLength(1),
        );
      },
    );

    test(
      'off before start: the stored shares are deleted, not restored',
      () async {
        final a = await startCore(_opts(sharesStorePath: store), name: 'a');
        final f = File('${tmp.path}/q.txt')..writeAsStringSync('q');
        a.createShare([f.path]);
        await drop(a);
        final b = LanDropCoreImpl(_opts(sharesStorePath: store));
        cores.add(b);
        b.setSharesPersistence(false);
        await b.start(
          alias: 'b',
          saveDir: (await Directory('${tmp.path}/b-save').create()).path,
        );
        expect(b.shares, isEmpty);
        expect(File(store).existsSync(), isFalse);
      },
    );

    test('a corrupt store is ignored without crashing', () async {
      await File(store).create(recursive: true);
      for (final (i, junk) in [
        '{not json',
        '[1, 2]',
        '{"v": 1, "shares": "nope"}',
        '{"v": 1, "shares": [42, {"id": 1}, {"id": "x", "token": "../..", '
            '"files": []}]}',
      ].indexed) {
        File(store).writeAsStringSync(junk);
        final c = await startCore(_opts(sharesStorePath: store), name: 'c$i');
        expect(c.shares, isEmpty, reason: junk);
        final f = File('${tmp.path}/ok$i.txt')..writeAsStringSync('ok');
        final s = c.createShare([f.path]);
        final stored = jsonDecode(File(store).readAsStringSync()) as Map;
        expect((stored['shares'] as List).single['token'], s.token);
        await drop(c);
      }
    });

    test('no store path: nothing is written', () async {
      final a = await startCore(_opts(), name: 'a');
      final f = File('${tmp.path}/n.txt')..writeAsStringSync('n');
      a.createShare([f.path]);
      expect(Directory('${tmp.path}/support').existsSync(), isFalse);
    });
  });
}
