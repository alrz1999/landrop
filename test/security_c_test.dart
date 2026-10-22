// Nearby shares security tests (docs/NEARBY_PLAN.md section 5). Step 1 covers
// the browser side: C1 (browser part), C17, plus Host and access gates.
import 'package:flutter_test/flutter_test.dart';

import 'helpers/nearby_harness.dart';

void main() {
  final env = NearbyEnv();
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
}
