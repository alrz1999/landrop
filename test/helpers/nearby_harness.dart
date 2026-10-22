// Shared helpers for the nearby-share tests: real cores over loopback and a
// tiny HTTPS client that accepts the self-signed certificate.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/core/identity.dart';
import 'package:landrop/core/landrop_core.dart';

const nearbyApi = '/api/landrop/v1';

LanDropCoreOptions nearbyOpts({
  String? sharesStorePath,
  int rateLimit = 1000,
  DateTime Function()? clock,
  int? httpPort,
}) => LanDropCoreOptions(
  sharesStorePath: sharesStorePath,
  webClock: clock,
  httpPort: httpPort,
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

// ---------------------------------------------------------------- app client

final _identities = <int, TlsIdentity>{};

/// A test identity (RSA key generation is slow, so each is made once).
TlsIdentity testIdentity([int i = 0]) =>
    _identities[i] ??= TlsIdentity.generate(commonName: 'Test $i');

const nearbyListPath = '$nearbyApi/nearby/list';

/// The exact bytes of a denied or empty listing.
const emptyNearbyBody = '{"shares":[],"ticket":null,"ticketExpiresIn":0}';

/// POST nearby/challenge for [fp]; the nonce on success.
Future<String> nearbyNonce(String base, String fp) async {
  final r = await ncall(
    'POST',
    '$base$nearbyApi/nearby/challenge',
    json: {'fingerprint': fp},
  );
  expect(r.status, 200);
  return r.json!['nonce'] as String;
}

/// The body of POST nearby/list, signed by [id] (overrides let a test sign
/// the wrong thing or claim another fingerprint).
Map<String, dynamic> nearbyListBody(
  LanDropCoreImpl c,
  TlsIdentity id,
  String nonce, {
  String? receiverFp,
  String path = nearbyListPath,
  String? claimFp,
  String? alias = 'Tester',
  TlsIdentity? signer,
}) {
  final sig = (signer ?? id).sign(
    nearbyProofMessage(
      receiverFp ?? c.self.fingerprint,
      claimFp ?? id.fingerprint,
      'POST',
      path,
      nonce,
    ),
  );
  return {
    'fingerprint': claimFp ?? id.fingerprint,
    'nonce': nonce,
    'cert': base64Encode(id.certDer),
    'sig': base64Encode(sig),
    'alias': ?alias,
  };
}

/// Challenge plus signed list, as a LanDrop app does it.
Future<NResp> nearbyList(
  String base,
  LanDropCoreImpl c,
  TlsIdentity id, {
  String? receiverFp,
  String path = nearbyListPath,
  String? alias = 'Tester',
}) async {
  final nonce = await nearbyNonce(base, id.fingerprint);
  return ncall(
    'POST',
    '$base$nearbyApi/nearby/list',
    json: nearbyListBody(
      c,
      id,
      nonce,
      receiverFp: receiverFp,
      path: path,
      alias: alias,
    ),
  );
}

Map<String, String> ticketHeader(String ticket) => {
  'authorization': 'LanDrop-Ticket $ticket',
};

String nearbyFileUrl(String base, String shareId, String fileId) =>
    '$base$nearbyApi/nearby/shares/$shareId/files/$fileId';
