// Integration tests for the real core: two instances talking HTTPS over
// loopback. Uses plain `test()` (no widget binding) so real sockets work.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/core/api.dart';
import 'package:landrop/core/discovery.dart';
import 'package:landrop/core/landrop_core.dart';

/// In-memory "LAN" so discovery can be exercised without real multicast.
class _Hub {
  final List<_HubTransport> members = [];
}

class _HubTransport implements DiscoveryTransport {
  final _Hub hub;
  DiscoveryMessageHandler? _handler;
  _HubTransport(this.hub);
  @override
  Future<void> start(DiscoveryMessageHandler onMessage) async {
    _handler = onMessage;
    hub.members.add(this);
  }

  @override
  Future<void> broadcast(Map<String, dynamic> message) async {
    final copy = jsonDecode(jsonEncode(message)) as Map<String, dynamic>;
    for (final m in List.of(hub.members)) {
      m._handler?.call(copy, InternetAddress.loopbackIPv4);
    }
  }

  @override
  Future<void> close() async => hub.members.remove(this);
}

LanDropCoreOptions _opts(int port, {DiscoveryTransport? transport}) =>
    LanDropCoreOptions(
      port: port,
      bindAddress: InternetAddress.loopbackIPv4,
      advertiseIp: '127.0.0.1',
      multicastEnabled: false,
      discoveryTransport: transport,
      persistIdentity: false,
      decisionTimeout: const Duration(seconds: 10),
      announceInterval: const Duration(milliseconds: 300),
      peerTimeout: const Duration(seconds: 2),
    );

Future<String> _sha(File f) async =>
    (await sha256.bind(f.openRead()).first).toString();

/// Raw HTTPS call into a core, accepting its self-signed cert.
Future<(int, Map<String, dynamic>?)> _raw(
    String method, DeviceInfo to, String path,
    {Map<String, String>? query, Object? json, List<int>? bytes}) async {
  final c = HttpClient()..badCertificateCallback = (_, _, _) => true;
  try {
    final req = await c.openUrl(
        method,
        Uri(
            scheme: 'https',
            host: to.ip,
            port: to.port,
            path: '/api/localsend/v2$path',
            queryParameters: query));
    if (json != null) req.add(utf8.encode(jsonEncode(json)));
    if (bytes != null) req.add(bytes);
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

void main() {
  late Directory tmp;
  late LanDropCoreImpl a;
  late LanDropCoreImpl b;
  late Directory dirA;
  late Directory dirB;
  StreamSubscription<IncomingRequest>? autoAnswer;

  // Both ask for the same port: the second must fall back to a nearby one.
  final basePort = 40000 + Random().nextInt(20000);

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('landrop_test');
    dirA = await Directory('${tmp.path}/a').create();
    dirB = await Directory('${tmp.path}/b').create();
    a = LanDropCoreImpl(_opts(basePort));
    b = LanDropCoreImpl(_opts(basePort));
    await a.start(alias: 'Alice', saveDir: dirA.path);
    await b.start(alias: 'Bob', saveDir: dirB.path);
  });

  tearDown(() async {
    await autoAnswer?.cancel();
    autoAnswer = null;
    await a.dispose();
    await b.dispose();
    await tmp.delete(recursive: true);
  });

  void answerB(bool accept) {
    autoAnswer = b.incoming.listen((r) => r.decision.complete(accept));
  }

  test('ports differ (fallback) and fingerprints are cert sha256', () {
    expect(a.self.port, isNot(equals(b.self.port)));
    expect(b.self.port, inInclusiveRange(basePort, basePort + 20));
    expect(a.self.fingerprint, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(a.self.fingerprint, isNot(b.self.fingerprint));
  });

  test('addPeerByIp probes and pins the peer', () async {
    final seen = a.peers.firstWhere((l) => l.isNotEmpty);
    final info = await a.addPeerByIp('127.0.0.1', port: b.self.port);
    expect(info, isNotNull);
    expect(info!.alias, 'Bob');
    expect(info.fingerprint, b.self.fingerprint);
    expect(info.port, b.self.port);
    final list = await seen.timeout(const Duration(seconds: 2));
    expect(list.single.fingerprint, b.self.fingerprint);
    // Probing ourselves is ignored.
    expect(await a.addPeerByIp('127.0.0.1', port: a.self.port), isNull);
    // Nothing listening -> null.
    expect(await a.addPeerByIp('127.0.0.1', port: 1), isNull);
  });

  test('sends a 20MB file byte-identically with progress on both sides',
      () async {
    final src = File('${tmp.path}/big.bin');
    final rnd = Random(42);
    final sink = src.openWrite();
    for (var i = 0; i < 20; i++) {
      sink.add(List<int>.generate(1 << 20, (_) => rnd.nextInt(256)));
    }
    await sink.close();
    expect(await src.length(), 20 << 20);

    final sendProg = <TransferProgress>[];
    final recvProg = <TransferProgress>[];
    final s1 = a.progress.listen(sendProg.add);
    final s2 = b.progress.listen(recvProg.add);
    IncomingRequest? got;
    autoAnswer = b.incoming.listen((r) {
      got = r;
      r.decision.complete(true);
    });

    final peer = (await a.addPeerByIp('127.0.0.1', port: b.self.port))!;
    final ok = await a.send(peer, [src.path]);
    expect(ok, isTrue);
    expect(got!.sender.alias, 'Alice');
    expect(got!.sender.fingerprint, a.self.fingerprint);
    expect(got!.files.single.fileName, 'big.bin');
    expect(got!.files.single.size, 20 << 20);

    final dst = File('${dirB.path}/big.bin');
    expect(await dst.exists(), isTrue);
    expect(await dst.length(), 20 << 20);
    expect(await _sha(dst), await _sha(src));

    await Future<void>.delayed(const Duration(milliseconds: 50));
    await s1.cancel();
    await s2.cancel();
    for (final p in [sendProg, recvProg]) {
      expect(p.length, greaterThan(10), reason: 'incremental progress');
      expect(p.last.done, isTrue);
      expect(p.last.error, isNull);
      expect(p.last.sentBytes, 20 << 20);
      expect(p.last.sessionId, got!.sessionId);
    }

    // Second send of same name -> unique name, receiver no longer busy.
    expect(await a.send(peer, [src.path]), isTrue);
    expect(await File('${dirB.path}/big (1).bin').exists(), isTrue);
  });

  test('decline returns false and writes nothing', () async {
    final src = File('${tmp.path}/x.txt')..writeAsStringSync('hello');
    answerB(false);
    final peer = (await a.addPeerByIp('127.0.0.1', port: b.self.port))!;
    expect(await a.send(peer, [src.path]), isFalse);
    expect(File('${dirB.path}/x.txt').existsSync(), isFalse);
    // Receiver is free again afterwards.
    await autoAnswer!.cancel();
    answerB(true);
    expect(await a.send(peer, [src.path]), isTrue);
    expect(File('${dirB.path}/x.txt').readAsStringSync(), 'hello');
  });

  test('send to a peer with a wrong pinned fingerprint fails', () async {
    final src = File('${tmp.path}/x.txt')..writeAsStringSync('hello');
    var asked = false;
    autoAnswer = b.incoming.listen((r) {
      asked = true;
      r.decision.complete(true);
    });
    final fake = DeviceInfo(
        alias: 'Bob',
        deviceType: 'desktop',
        fingerprint: 'ab' * 32,
        ip: '127.0.0.1',
        port: b.self.port);
    expect(await a.send(fake, [src.path]), isFalse);
    expect(asked, isFalse);
  });

  test('path-traversal file names are sanitized; tokens are enforced',
      () async {
    answerB(true);
    final evil = '../../evil.txt';
    final (status, body) = await _raw('POST', b.self, '/prepare-upload', json: {
      'info': {
        'alias': 'Mallory',
        'version': '2.1',
        'deviceType': 'desktop',
        'fingerprint': 'cd' * 32,
        'port': 1,
        'protocol': 'https',
      },
      'files': {
        'f1': {
          'id': 'f1',
          'fileName': evil,
          'size': 3,
          'fileType': 'text/plain'
        },
      },
    });
    expect(status, 200);
    final sid = body!['sessionId'] as String;
    final token = (body['files'] as Map)['f1'] as String;

    // Wrong token / session are rejected.
    expect(
        (await _raw('POST', b.self, '/upload',
                query: {'sessionId': sid, 'fileId': 'f1', 'token': 'nope'},
                bytes: [1, 2, 3]))
            .$1,
        403);
    expect(
        (await _raw('POST', b.self, '/upload',
                query: {'sessionId': 'x', 'fileId': 'f1', 'token': token},
                bytes: [1, 2, 3]))
            .$1,
        403);

    final (up, _) = await _raw('POST', b.self, '/upload',
        query: {'sessionId': sid, 'fileId': 'f1', 'token': token},
        bytes: utf8.encode('pwn'));
    expect(up, 200);
    expect(File('${dirB.path}/evil.txt').readAsStringSync(), 'pwn');
    expect(File('${tmp.path}/evil.txt').existsSync(), isFalse);
    expect(File('${dirB.parent.parent.path}/evil.txt').existsSync(), isFalse);

    expect(sanitizeFileName('../../etc/passwd'), 'passwd');
    expect(sanitizeFileName(r'..\..\win.ini'), 'win.ini');
    expect(sanitizeFileName('..'), 'file');
    expect(sanitizeFileName('/abs/path/a.txt'), 'a.txt');
    expect(sanitizeFileName('a\u0000b<c>.txt'), 'a_b_c_.txt');
    expect(sanitizeFileName('.hidden'), 'hidden');
  });

  test('second prepare-upload while one is pending gets 409', () async {
    final pending = Completer<IncomingRequest>();
    autoAnswer = b.incoming.listen(pending.complete);
    Map<String, dynamic> prep(String n) => {
          'info': {'alias': n, 'fingerprint': 'ef' * 32, 'port': 1},
          'files': {
            'f': {'id': 'f', 'fileName': 'a.txt', 'size': 1, 'fileType': 'x'}
          },
        };
    final first = _raw('POST', b.self, '/prepare-upload', json: prep('one'));
    final req = await pending.future;
    final (second, _) =
        await _raw('POST', b.self, '/prepare-upload', json: prep('two'));
    expect(second, 409);
    req.decision.complete(false);
    expect((await first).$1, 403);
  });

  test('info endpoint matches presented certificate', () async {
    final (status, body) = await _raw('GET', a.self, '/info');
    expect(status, 200);
    expect(body!['fingerprint'], a.self.fingerprint);
    expect(body['alias'], 'Alice');
    expect(body['protocol'], 'https');
    expect(body['version'], '2.1');
  });

  test('discovery via injected transport finds both peers', () async {
    final hub = _Hub();
    final dir = await Directory('${tmp.path}/disc').create();
    final c = LanDropCoreImpl(_opts(0, transport: _HubTransport(hub)));
    final d = LanDropCoreImpl(_opts(0, transport: _HubTransport(hub)));
    try {
      await c.start(alias: 'Carol', saveDir: '${dir.path}/c');
      final cSeesD = c.peers.firstWhere((l) => l.isNotEmpty);
      await d.start(alias: 'Dave', saveDir: '${dir.path}/d');
      final dSeesC = d.peers.firstWhere((l) => l.isNotEmpty);
      final l1 = await cSeesD.timeout(const Duration(seconds: 5));
      final l2 = await dSeesC.timeout(const Duration(seconds: 5));
      expect(l1.single.fingerprint, d.self.fingerprint);
      expect(l1.single.port, d.self.port);
      expect(l2.single.fingerprint, c.self.fingerprint);

      // When d goes away, c drops it after the peer timeout.
      await d.stop();
      final gone = await c.peers
          .firstWhere((l) => l.isEmpty)
          .timeout(const Duration(seconds: 10));
      expect(gone, isEmpty);
    } finally {
      await c.dispose();
      await d.dispose();
    }
  });
}
