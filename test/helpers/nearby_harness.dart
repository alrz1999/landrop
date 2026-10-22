// Shared helpers for the nearby-share tests: real cores over loopback and a
// tiny HTTPS client that accepts the self-signed certificate.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/core/landrop_core.dart';

const nearbyApi = '/api/landrop/v1';

LanDropCoreOptions nearbyOpts({
  String? sharesStorePath,
  int rateLimit = 1000,
}) => LanDropCoreOptions(
  sharesStorePath: sharesStorePath,
  port: 0,
  bindAddress: InternetAddress.loopbackIPv4,
  advertiseIp: '127.0.0.1',
  multicastEnabled: false,
  persistIdentity: false,
  decisionTimeout: const Duration(seconds: 10),
  webRateLimit: rateLimit,
);

class NResp {
  final int status;
  final HttpHeaders headers;
  final Uint8List body;
  NResp(this.status, this.headers, this.body);
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

Future<NResp> ncall(
  String method,
  String url, {
  Map<String, String> headers = const {},
  Object? json,
}) async {
  final c = HttpClient()..badCertificateCallback = (_, _, _) => true;
  try {
    final req = await c.openUrl(method, Uri.parse(url));
    headers.forEach(req.headers.set);
    if (json != null) {
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode(json)));
    }
    final res = await req.close();
    final b = BytesBuilder(copy: false);
    await for (final ch in res) {
      b.add(ch);
    }
    return NResp(res.statusCode, res.headers, b.takeBytes());
  } finally {
    c.close(force: true);
  }
}

/// Temp dir plus the cores started in a test, disposed afterwards.
class NearbyEnv {
  late Directory tmp;
  final cores = <LanDropCoreImpl>[];

  Future<void> setUp() async {
    tmp = await Directory.systemTemp.createTemp('landrop_nearby_test');
  }

  Future<void> tearDown() async {
    for (final c in cores) {
      await c.dispose();
    }
    cores.clear();
    await tmp.delete(recursive: true);
  }

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

  Future<void> drop(LanDropCoreImpl c) async {
    cores.remove(c);
    await c.dispose();
  }

  String base(LanDropCoreImpl c) => 'https://127.0.0.1:${c.self.port}';

  /// Pairs a browser (auto-approved); returns its session token.
  Future<String> pair(LanDropCoreImpl c) async {
    final sub = c.webPairing.listen((r) => r.decision.complete(true));
    try {
      final p = await ncall('POST', '${base(c)}$nearbyApi/web/pair', json: {});
      expect(p.status, 200);
      final st = await ncall(
        'GET',
        '${base(c)}$nearbyApi/web/pair/${p.json!['id']}',
      );
      expect(st.status, 200);
      return st.json!['token'] as String;
    } finally {
      await sub.cancel();
    }
  }

  File file(String name, List<int> bytes) =>
      File('${tmp.path}/$name')..writeAsBytesSync(bytes);
}

Map<String, String> cookie(String token) => {
  'cookie': 'landrop_session=$token',
};
