// Security review batch A (docs/SECURITY.md S1-S5, S15, S18, S19): resource
// limits and abuse resistance of the real core over loopback sockets.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/core/api.dart';
import 'package:landrop/core/discovery.dart';
import 'package:landrop/core/identity.dart';
import 'package:landrop/core/landrop_core.dart';
import 'package:landrop/core/util.dart';
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart' show RSAPublicKey;

import 'mdns_memory.dart';

import 'package:landrop/core/mdns.dart';

class _Transport implements DiscoveryTransport {
  DiscoveryMessageHandler? handler;
  @override
  Future<void> start(DiscoveryMessageHandler onMessage) async =>
      handler = onMessage;
  @override
  Future<void> broadcast(Map<String, dynamic> message) async {}
  @override
  Future<void> close() async {}
}

LanDropCoreOptions _opts({
  ServerLimits serverLimits = const ServerLimits(),
  int maxPeers = 256,
  int maxOfferFiles = 10000,
  int maxOfferBytes = 1 << 50,
  int requestRateLimit = 10,
  Future<int?> Function(String)? freeSpace,
  int? httpPort,
  DiscoveryTransport? transport,
  Duration probeTimeout = const Duration(seconds: 3),
  MdnsHub? mdns,
}) => LanDropCoreOptions(
  port: 0,
  bindAddress: InternetAddress.loopbackIPv4,
  advertiseIp: '127.0.0.1',
  multicastEnabled: false,
  discoveryTransport: transport,
  persistIdentity: false,
  decisionTimeout: const Duration(seconds: 5),
  probeTimeout: probeTimeout,
  httpPort: httpPort,
  serverLimits: serverLimits,
  maxPeers: maxPeers,
  maxOfferFiles: maxOfferFiles,
  maxOfferBytes: maxOfferBytes,
  requestRateLimit: requestRateLimit,
  freeSpace: freeSpace,
  mdnsEnabled: mdns != null,
  mdnsAllowLoopback: true,
  mdnsSocketFactory: mdns == null ? null : () => MemoryMdnsSocket(mdns),
);

Future<(int, Map<String, dynamic>?)> _call(
  DeviceInfo to,
  String method,
  String path, {
  Object? json,
  Map<String, String>? query,
}) async {
  final c = HttpClient()..badCertificateCallback = (_, _, _) => true;
  try {
    final req = await c.openUrl(
      method,
      Uri(
        scheme: 'https',
        host: to.ip,
        port: to.port,
        path: path,
        queryParameters: query,
      ),
    );
    if (json != null) req.add(utf8.encode(jsonEncode(json)));
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    Map<String, dynamic>? body;
    try {
      final d = jsonDecode(text);
      if (d is Map<String, dynamic>) body = d;
    } catch (_) {}
    return (res.statusCode, body);
  } finally {
    c.close(force: true);
  }
}

Future<(int, Map<String, dynamic>?)> _prepare(
  DeviceInfo to,
  Object? files, {
  Map<String, dynamic>? info,
  Map<String, dynamic>? extra,
}) => _call(
  to,
  'POST',
  '/api/localsend/v2/prepare-upload',
  json: {'info': info ?? _mallory, 'files': files, ...?extra},
);

const _mallory = {
  'alias': 'Mallory',
  'version': '2.1',
  'deviceType': 'desktop',
  'fingerprint':
      'cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd',
  'port': 1,
  'protocol': 'https',
};

Map<String, dynamic> _file(
  String id,
  int size, {
  String? name,
  String type = 'application/octet-stream',
}) => {'id': id, 'fileName': name ?? '$id.bin', 'size': size, 'fileType': type};

String _hex64(int i) => sha256.convert(utf8.encode('fp$i')).toString();

/// Reads from [s] until it is closed or [within] passes; true when closed.
Future<bool> _closedWithin(Socket s, Duration within) async {
  final c = Completer<bool>();
  s.listen(
    (_) {},
    onDone: () => c.complete(true),
    onError: (_) {
      if (!c.isCompleted) c.complete(true);
    },
  );
  return c.future.timeout(within, onTimeout: () => false);
}

/// A TCP listener that accepts and holds connections: the "attacker-chosen
/// address" a victim is tricked into connecting to.
class _Listener {
  late final ServerSocket server;
  final accepted = <Socket>[];
  Future<void> start() async {
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(accepted.add);
  }

  Future<void> close() async {
    for (final s in accepted) {
      s.destroy();
    }
    await server.close();
  }
}

void main() {
  late Directory tmp;
  final cores = <LanDropCoreImpl>[];
  final listeners = <_Listener>[];
  StreamSubscription<IncomingRequest>? answer;

  Future<LanDropCoreImpl> startCore(
    LanDropCoreOptions o, {
    String alias = 'Bob',
  }) async {
    final c = LanDropCoreImpl(o);
    cores.add(c);
    await c.start(alias: alias, saveDir: '${tmp.path}/${cores.length}');
    return c;
  }

  setUp(() async => tmp = await Directory.systemTemp.createTemp('secA'));
  tearDown(() async {
    await answer?.cancel();
    answer = null;
    for (final c in cores) {
      await c.dispose();
    }
    cores.clear();
    for (final l in listeners) {
      await l.close();
    }
    listeners.clear();
    await tmp.delete(recursive: true);
  });

  Future<_Listener> listener() async {
    final l = _Listener();
    await l.start();
    listeners.add(l);
    return l;
  }

  // ------------------------------------------------------------------ S1
  group('S1 connection limits', () {
    const limits = ServerLimits(
      maxConnections: 8,
      maxConnectionsPerIp: 4,
      handshakeTimeout: Duration(milliseconds: 600),
      idleTimeout: Duration(milliseconds: 800),
    );

    test('idle sockets beyond the per-IP cap are dropped at once', () async {
      final b = await startCore(_opts(serverLimits: limits));
      final socks = [
        for (var i = 0; i < 12; i++)
          await Socket.connect('127.0.0.1', b.self.port),
      ];
      final closed = await Future.wait([
        for (final s in socks)
          _closedWithin(s, const Duration(milliseconds: 300)),
      ]);
      // 4 may stay (until their handshake times out), the other 8 are cut.
      expect(closed.where((c) => c).length, greaterThanOrEqualTo(8));
      for (final s in socks) {
        s.destroy();
      }
    });

    test(
      'a TLS handshake that never completes is cut after the timeout',
      () async {
        final b = await startCore(_opts(serverLimits: limits));
        final s = await Socket.connect('127.0.0.1', b.self.port);
        expect(await _closedWithin(s, const Duration(seconds: 3)), isTrue);
        // The slot is free again: a normal request works.
        final (st, _) = await _call(b.self, 'GET', '/api/localsend/v2/info');
        expect(st, 200);
      },
    );

    test('slots are released: more sockets than the cap over time', () async {
      final b = await startCore(_opts(serverLimits: limits));
      for (var round = 0; round < 3; round++) {
        final socks = [
          for (var i = 0; i < 4; i++)
            await Socket.connect('127.0.0.1', b.self.port),
        ];
        for (final s in socks) {
          expect(await _closedWithin(s, const Duration(seconds: 3)), isTrue);
        }
      }
      final (st, _) = await _call(b.self, 'GET', '/api/localsend/v2/info');
      expect(st, 200);
    });

    test('a request whose headers never finish is cut (HTTPS)', () async {
      final b = await startCore(_opts(serverLimits: limits));
      final s = await SecureSocket.connect(
        '127.0.0.1',
        b.self.port,
        onBadCertificate: (_) => true,
      );
      s.write('GET /api/localsend/v2/info HTTP/1.1\r\nHost: 127.0.0.1\r\nX-A:');
      expect(await _closedWithin(s, const Duration(seconds: 4)), isTrue);
    });

    test(
      'plain HTTP listener: idle and half-sent requests are cut, cap holds',
      () async {
        final b = await startCore(_opts(serverLimits: limits, httpPort: 0));
        final port = b.webHttpPort!;
        final idle = [
          for (var i = 0; i < 12; i++) await Socket.connect('127.0.0.1', port),
        ];
        final closed = await Future.wait([
          for (final s in idle)
            _closedWithin(s, const Duration(milliseconds: 300)),
        ]);
        expect(closed.where((c) => c).length, greaterThanOrEqualTo(8));
        for (final s in idle) {
          s.destroy();
        }
        final slow = await Socket.connect('127.0.0.1', port);
        slow.write('GET / HTTP/1.1\r\nHost: 127.0.0.1\r\nX-A:');
        expect(await _closedWithin(slow, const Duration(seconds: 4)), isTrue);
        final r = await HttpClient().getUrl(
          Uri.parse('http://127.0.0.1:$port/'),
        );
        expect((await r.close()).statusCode, 200);
      },
    );

    test('request bodies are read within a total time and size', () async {
      final c = StreamController<List<int>>();
      final slow = readBodyBounded(
        c.stream,
        max: 100,
        timeout: const Duration(milliseconds: 200),
      );
      c.add([1, 2, 3]);
      await expectLater(
        slow,
        throwsA(isA<HttpStatusError>().having((e) => e.status, 's', 408)),
      );
      final c2 = StreamController<List<int>>();
      final big = readBodyBounded(c2.stream, max: 10);
      c2.add(List.filled(11, 0));
      await expectLater(
        big,
        throwsA(isA<HttpStatusError>().having((e) => e.status, 's', 413)),
      );
      await c.close();
      await c2.close();
    });
  });

  // ------------------------------------------------------------------ S2
  group('S2 Host header', () {
    Future<int> status(int port, String host, {bool tls = true}) async {
      final Socket s = tls
          ? await SecureSocket.connect(
              '127.0.0.1',
              port,
              onBadCertificate: (_) => true,
            )
          : await Socket.connect('127.0.0.1', port);
      s.write(
        'GET /api/landrop/v1/web/info HTTP/1.1\r\nHost: $host\r\n'
        'Connection: close\r\n\r\n',
      );
      final text = await utf8.decoder.bind(s).join();
      s.destroy();
      return int.parse(text.split(' ')[1]);
    }

    test(
      'web endpoints refuse names other than IPs, localhost, .local',
      () async {
        final b = await startCore(_opts(httpPort: 0));
        for (final tls in [true, false]) {
          final port = tls ? b.self.port : b.webHttpPort!;
          for (final good in [
            '127.0.0.1:$port',
            '192.168.1.5',
            'localhost:$port',
            'my-laptop.local',
            '[::1]:$port',
          ]) {
            expect(
              await status(port, good, tls: tls),
              200,
              reason: 'tls=$tls $good',
            );
          }
          for (final bad in [
            'evil.example',
            'evil.example:$port',
            '127.0.0.1.evil.example',
            'localhost.evil.example',
            'x.local.evil.example',
            '',
          ]) {
            expect(
              await status(port, bad, tls: tls),
              anyOf(421, 400),
              reason: 'tls=$tls "$bad"',
            );
          }
        }
      },
    );
  });

  // ------------------------------------------------------------------ S3
  group('S3 sender proof key size', () {
    RSAPublicKey key(BigInt n, BigInt e) => RSAPublicKey(n, e);
    final rnd = Random(7);
    BigInt randomOdd(int bits) {
      var v = BigInt.one << (bits - 1);
      for (var i = 0; i < bits - 2; i += 30) {
        v |= BigInt.from(rnd.nextInt(1 << 30)) << i;
      }
      return (v & ((BigInt.one << bits) - BigInt.one)) |
          (BigInt.one << (bits - 1)) |
          BigInt.one;
    }

    test('only 2048-4096 bit moduli and small odd exponents are accepted', () {
      final e = BigInt.from(65537);
      expect(acceptableRsaKey(key(randomOdd(2048), e)), isTrue);
      expect(acceptableRsaKey(key(randomOdd(4096), e)), isTrue);
      expect(acceptableRsaKey(key(randomOdd(1024), e)), isFalse);
      expect(acceptableRsaKey(key(randomOdd(4097), e)), isFalse);
      expect(acceptableRsaKey(key(randomOdd(100000), e)), isFalse);
      expect(
        acceptableRsaKey(
          key(randomOdd(2048), (BigInt.one << 100000) + BigInt.one),
        ),
        isFalse,
      );
      expect(
        acceptableRsaKey(key(randomOdd(2048), BigInt.from(65536))),
        isFalse,
      );
      expect(acceptableRsaKey(key(randomOdd(2048), BigInt.one)), isFalse);
    });

    Uint8List certWith(BigInt n, BigInt e) {
      final rsaKey = ASN1Sequence(elements: [ASN1Integer(n), ASN1Integer(e)]);
      final bits = ASN1BitString(stringValues: rsaKey.encode());
      final alg = ASN1Sequence(
        elements: [
          ASN1ObjectIdentifier.fromIdentifierString('1.2.840.113549.1.1.1'),
          ASN1Null(),
        ],
      );
      final spki = ASN1Sequence(elements: [alg, bits]);
      final tbs = ASN1Sequence(elements: [spki]);
      return ASN1Sequence(elements: [tbs]).encode();
    }

    test(
      'prepare-upload with a huge-exponent certificate answers quickly',
      () async {
        final b = await startCore(_opts());
        answer = b.incoming.listen((r) {
          expect(r.verified, isFalse);
          r.decision.complete(false);
        });
        final der = certWith(
          randomOdd(2048),
          (BigInt.one << 300000) + BigInt.one,
        );
        final info = {..._mallory, 'fingerprint': fingerprintOfDer(der)};
        final sw = Stopwatch()..start();
        final (st, _) = await _prepare(
          b.self,
          {'f': _file('f', 3)},
          info: info,
          extra: {
            'landropProof': {
              'cert': base64Encode(der),
              'sig': base64Encode(List.filled(256, 1)),
            },
          },
        );
        expect(st, 403); // declined by the answer above
        expect(sw.elapsedMilliseconds, lessThan(1500));
        // And an oversized proof is not even decoded.
        final (st2, _) = await _prepare(
          b.self,
          {'f': _file('f', 3)},
          extra: {
            'landropProof': {'cert': 'A' * 100000, 'sig': 'A' * 100000},
          },
        );
        expect(st2, 403);
      },
    );
  });

  // ------------------------------------------------------------------ S4
  group('S4 discovery abuse', () {
    test(
      'register calls cause a bounded number of outbound connections',
      () async {
        final l = await listener();
        final b = await startCore(_opts());
        for (var i = 0; i < 40; i++) {
          final (st, _) = await _call(
            b.self,
            'POST',
            '/api/localsend/v2/register',
            json: {
              'alias': 'x',
              'fingerprint': _hex64(i),
              'port': l.server.port,
            },
          );
          expect(st, 200);
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
        expect(l.accepted.length, lessThanOrEqualTo(4));
        expect(l.accepted, isNotEmpty);
      },
    );

    test(
      'spoofed UDP announces cause a bounded number of connections',
      () async {
        final l = await listener();
        final t = _Transport();
        await startCore(_opts(transport: t));
        for (var i = 0; i < 60; i++) {
          t.handler!({
            'alias': 'x',
            'fingerprint': _hex64(i),
            'port': l.server.port,
            'announce': true,
          }, InternetAddress.loopbackIPv4);
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
        expect(l.accepted.length, lessThanOrEqualTo(4));
        // Same claim again while it is checked or just failed: nothing new.
        final before = l.accepted.length;
        for (var i = 0; i < 60; i++) {
          t.handler!({
            'alias': 'x',
            'fingerprint': _hex64(0),
            'port': l.server.port,
            'announce': true,
          }, InternetAddress.loopbackIPv4);
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(l.accepted.length, before);
      },
    );

    test('datagrams with a bad fingerprint or port are ignored', () async {
      final l = await listener();
      final t = _Transport();
      await startCore(_opts(transport: t));
      for (final m in [
        {'fingerprint': 'abc', 'port': l.server.port},
        {'fingerprint': _hex64(1), 'port': 0},
        {'fingerprint': _hex64(1), 'port': 70000},
        {'fingerprint': _hex64(1), 'port': 'x'},
        {'fingerprint': 'A' * 200, 'port': l.server.port},
      ]) {
        t.handler!(m, InternetAddress.loopbackIPv4);
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(l.accepted, isEmpty);
    });

    test('the peer table is bounded', () async {
      final b = await startCore(_opts(maxPeers: 2));
      final others = <LanDropCoreImpl>[];
      for (var i = 0; i < 4; i++) {
        others.add(await startCore(_opts(), alias: 'P$i'));
      }
      for (final o in others) {
        await b.addPeerByIp('127.0.0.1', port: o.self.port);
      }
      expect(b.currentPeers.length, 2);
    });

    test('mDNS observations are bounded', () async {
      final hub = MdnsHub();
      final b = await startCore(_opts(mdns: hub));
      final evil = MemoryMdnsSocket(hub);
      await evil.start((_, _) {});
      for (var i = 0; i < 150; i++) {
        final inst = 'F$i._landrop._tcp.local';
        await evil.send(
          encodeDnsMessage(
            DnsMessage(
              flags: 0x8400,
              records: [
                DnsRecord.ptr(mdnsServiceName, inst),
                DnsRecord.srv(inst, 'f$i.local', 1),
                DnsRecord.txtRecord(inst, ['fp=${_hex64(i)}', 'alias=F$i']),
                DnsRecord.a('f$i.local', '127.0.0.1'),
              ],
            ),
          ),
        );
        if (i % 10 == 9) {
          await Future<void>.delayed(const Duration(milliseconds: 60));
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 800));
      final d = await b.observe();
      expect(d.mdnsPeers.length, lessThanOrEqualTo(64));
      await evil.close();
    });
  });

  // ------------------------------------------------------------------ S5
  group('S5 prepare-upload limits', () {
    test('file count, id, name and type lengths are capped', () async {
      final b = await startCore(_opts(maxOfferFiles: 5));
      answer = b.incoming.listen((r) => r.decision.complete(false));
      final (many, _) = await _prepare(b.self, {
        for (var i = 0; i < 6; i++) 'f$i': _file('f$i', 1),
      });
      expect(many, 413);
      final (longId, _) = await _prepare(b.self, {'f': _file('x' * 129, 1)});
      expect(longId, 400);
      final (longName, _) = await _prepare(b.self, {
        'f': _file('f', 1, name: 'n' * 5000),
      });
      expect(longName, 400);
      // A long type is dropped, not fatal; the request is then declined by
      // the answer above (403 = it reached the dialog).
      final (longType, _) = await _prepare(b.self, {
        'f': _file('f', 1, type: 't' * 500),
      });
      expect(longType, 403);
    });

    test('sizes are capped per file and in total, without overflow', () async {
      final b = await startCore(_opts(maxOfferBytes: 1000));
      answer = b.incoming.listen((r) => r.decision.complete(false));
      expect((await _prepare(b.self, {'f': _file('f', 1001)})).$1, 413);
      expect(
        (await _prepare(b.self, {
          'a': _file('a', 600),
          'b': _file('b', 600),
        })).$1,
        413,
      );
      expect(
        (await _prepare(b.self, {
          'a': _file('a', 500),
          'b': _file('b', 500),
        })).$1,
        403,
      ); // reaches the dialog
      expect((await _prepare(b.self, {'f': _file('f', -1)})).$1, 400);

      // A limit near 2^63: three files of 2^62 would wrap the 64-bit total.
      final big = await startCore(_opts(maxOfferBytes: 0x7fffffffffffffff));
      answer = big.incoming.listen((r) => r.decision.complete(false));
      final huge = 1 << 62;
      expect(
        (await _prepare(big.self, {
          'a': _file('a', huge),
          'b': _file('b', huge),
          'c': _file('c', huge),
        })).$1,
        413,
      );
    });
  });

  // ----------------------------------------------------------------- S15
  group('S15 per-IP attempt limit', () {
    test('repeated declined requests get 429 without a dialog', () async {
      final b = await startCore(_opts(requestRateLimit: 3));
      var dialogs = 0;
      answer = b.incoming.listen((r) {
        dialogs++;
        r.decision.complete(false);
      });
      final codes = <int>[];
      for (var i = 0; i < 6; i++) {
        codes.add((await _prepare(b.self, {'f': _file('f', 1)})).$1);
      }
      expect(codes, [403, 403, 403, 429, 429, 429]);
      expect(dialogs, 3);
    });

    test('failed upload tokens get 429', () async {
      final b = await startCore(_opts(requestRateLimit: 3));
      answer = b.incoming.listen((r) => r.decision.complete(true));
      final (st, body) = await _prepare(b.self, {'f': _file('f', 3)});
      expect(st, 200);
      final sid = body!['sessionId'] as String;
      final codes = <int>[];
      for (var i = 0; i < 6; i++) {
        codes.add(
          (await _call(
            b.self,
            'POST',
            '/api/localsend/v2/upload',
            query: {'sessionId': sid, 'fileId': 'f', 'token': 'wrong$i'},
          )).$1,
        );
      }
      expect(codes.take(3), everyElement(403));
      expect(codes.skip(3), everyElement(429));
      // Even the right token is refused for now from this address.
      final token = (body['files'] as Map)['f'] as String;
      final (ok, _) = await _call(
        b.self,
        'POST',
        '/api/localsend/v2/upload',
        query: {'sessionId': sid, 'fileId': 'f', 'token': token},
      );
      expect(ok, 429);
    });
  });

  // ----------------------------------------------------------------- S18
  group('S18 free space', () {
    test('a transfer larger than the free space is refused with 507', () async {
      var free = 100 << 20;
      final b = await startCore(_opts(freeSpace: (_) async => free));
      var dialogs = 0;
      answer = b.incoming.listen((r) {
        dialogs++;
        r.decision.complete(false);
      });
      expect((await _prepare(b.self, {'f': _file('f', 200 << 20)})).$1, 507);
      expect(dialogs, 0);
      // The margin stays free: 100 MB free, 64 MB kept.
      expect((await _prepare(b.self, {'f': _file('f', 50 << 20)})).$1, 507);
      expect((await _prepare(b.self, {'f': _file('f', 30 << 20)})).$1, 403);
      expect(dialogs, 1);
      // Unknown free space (null) never blocks.
      final c = await startCore(_opts(freeSpace: (_) async => null));
      answer = c.incoming.listen((r) => r.decision.complete(false));
      expect((await _prepare(c.self, {'f': _file('f', 200 << 20)})).$1, 403);
    });
  });

  // ----------------------------------------------------------------- S19
  group('S19 peer data lengths', () {
    test('capability records are bounded', () {
      final caps = PeerCapabilities.fromJson({
        'v': 1,
        'transports': [
          for (var i = 0; i < 100; i++)
            {
              'id': 'lan',
              'addrs': [for (var j = 0; j < 100; j++) '10.0.0.$j'],
              'ssid': 's' * 1000,
              'gateway': 'g\u202E',
              'port': 99999,
            },
          {'id': 'x' * 500},
        ],
        'features': [for (var i = 0; i < 500; i++) 'f$i', 'y' * 500],
      })!;
      expect(caps.transports.length, lessThanOrEqualTo(16));
      for (final t in caps.transports) {
        expect(t.addrs.length, lessThanOrEqualTo(16));
        expect(t.ssid, isNull);
        expect(t.gateway, isNull);
        expect(t.port, isNull);
      }
      expect(caps.features.length, lessThanOrEqualTo(32));
      expect(caps.features.every((f) => f.length <= 32), isTrue);
    });

    test('alias, model and type of a sender are bounded and cleaned', () async {
      final b = await startCore(_opts());
      IncomingRequest? seen;
      answer = b.incoming.listen((r) {
        seen = r;
        r.decision.complete(false);
      });
      await _prepare(
        b.self,
        {'f': _file('f', 1)},
        info: {
          ..._mallory,
          'alias': 'A' * 5000,
          'deviceModel': 'M\u202E' * 5000,
          'deviceType': 'x' * 500,
        },
      );
      expect(seen!.sender.alias.length, lessThanOrEqualTo(64));
      expect(seen!.sender.deviceModel!.length, lessThanOrEqualTo(64));
      expect(seen!.sender.deviceModel, isNot(contains('\u202E')));
      expect(seen!.sender.deviceType, 'desktop');
    });
  });
}
