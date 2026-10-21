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

LanDropCoreOptions _opts(int port,
        {DiscoveryTransport? transport,
        bool Function(String, int, int)? kill}) =>
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
      retryBackoff: const Duration(milliseconds: 50),
      stallTimeout: const Duration(seconds: 5),
      debugKillUpload: kill,
    );

Future<File> _randomFile(String path, int bytes, int seed) async {
  final f = File(path);
  await f.parent.create(recursive: true);
  final rnd = Random(seed);
  final sink = f.openWrite();
  for (var left = bytes; left > 0; left -= 1 << 20) {
    sink.add(List<int>.generate(min(left, 1 << 20), (_) => rnd.nextInt(256)));
  }
  await sink.close();
  return f;
}

/// Every file below [dir] (relative paths with '/'), following no links.
List<String> _tree(Directory dir) => [
      for (final e in dir.listSync(recursive: true, followLinks: false))
        if (e is File)
          e.path.substring(dir.path.length + 1).replaceAll('\\', '/')
    ]..sort();

Map<String, dynamic> _mallory(Map<String, Object> files) => {
      'info': {
        'alias': 'Mallory',
        'version': '2.1',
        'deviceType': 'desktop',
        'fingerprint': 'cd' * 32,
        'port': 1,
        'protocol': 'https',
      },
      'files': {
        for (final e in files.entries)
          e.key: {
            'id': e.key,
            'fileName': e.value,
            'size': 3,
            'fileType': 'text/plain'
          },
      },
    };

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

Future<(int, Map<String, dynamic>?)> _rawStatus(
    DeviceInfo to, String sid, String fileId, String token) async {
  final c = HttpClient()..badCertificateCallback = (_, _, _) => true;
  try {
    final req = await c.getUrl(Uri.https('${to.ip}:${to.port}',
        '/api/landrop/v1/upload-status',
        {'sessionId': sid, 'fileId': fileId, 'token': token}));
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    Map<String, dynamic>? body;
    try {
      body = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {}
    return (res.statusCode, body);
  } finally {
    c.close(force: true);
  }
}

class _FailingTransport implements DiscoveryTransport {
  @override
  Future<void> start(DiscoveryMessageHandler onMessage) async =>
      throw const SocketException('no multicast here');
  @override
  Future<void> broadcast(Map<String, dynamic> message) async {}
  @override
  Future<void> close() async {}
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

  test('resume: upload socket killed mid-file twice, transfer completes',
      () async {
    final attempts = <int, int>{}; // attempt -> first sentBytes seen
    final c = LanDropCoreImpl(_opts(0, kill: (fileId, sent, attempt) {
      attempts.putIfAbsent(attempt, () => sent);
      return (attempt == 0 && sent >= 5 << 20) ||
          (attempt == 1 && sent >= 12 << 20);
    }));
    await c.start(alias: 'Carol', saveDir: '${tmp.path}/c');
    try {
      final src = await _randomFile('${tmp.path}/resume.bin', 20 << 20, 7);
      answerB(true);
      final prog = <TransferProgress>[];
      final sub = c.progress.listen(prog.add);
      final peer = (await c.addPeerByIp('127.0.0.1', port: b.self.port))!;
      String? announced;
      final r = await c.sendFiles(peer, [SendItem(src.path)],
          onSession: (sid) => announced = sid);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      expect(r.ok, isTrue, reason: r.error);
      expect(r.sessionId, announced);
      // Three connections; the 2nd and 3rd continued from an offset.
      expect(attempts.keys, containsAll([0, 1, 2]));
      expect(attempts[1], greaterThan(1 << 20));
      expect(attempts[2], greaterThan(attempts[1]!));
      final dst = File('${dirB.path}/resume.bin');
      expect(await dst.length(), 20 << 20);
      expect(await _sha(dst), await _sha(src));
      expect(_tree(dirB), ['resume.bin'], reason: 'no .part left behind');
      expect(prog.last.done, isTrue);
      expect(prog.last.error, isNull);
      expect(prog.every((p) => p.sessionId == r.sessionId), isTrue);
    } finally {
      await c.dispose();
    }
  });

  test('resume gives up after the retry limit and cleans up', () async {
    final c = LanDropCoreImpl(_opts(0, kill: (_, sent, _) => sent >= 1 << 20));
    await c.start(alias: 'Carol', saveDir: '${tmp.path}/c');
    try {
      final src = await _randomFile('${tmp.path}/fail.bin', 3 << 20, 8);
      answerB(true);
      final peer = (await c.addPeerByIp('127.0.0.1', port: b.self.port))!;
      final r = await c.sendFiles(peer, [SendItem(src.path)]);
      expect(r.ok, isFalse);
      expect(r.sessionId, isNotNull);
      // The sender cancelled with its secret: part deleted, receiver free.
      for (var i = 0; i < 50 && _tree(dirB).isNotEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(_tree(dirB), isEmpty);
      final small = File('${tmp.path}/ok.txt')..writeAsStringSync('ok');
      expect(await c.send(peer, [small.path]), isTrue);
    } finally {
      await c.dispose();
    }
  });

  test('.part file hides partial data; removed on cancel and decline',
      () async {
    // Decline: nothing at all is written.
    answerB(false);
    final x = File('${tmp.path}/x.txt')..writeAsStringSync('hello');
    final peer = (await a.addPeerByIp('127.0.0.1', port: b.self.port))!;
    expect(await a.send(peer, [x.path]), isFalse);
    expect(_tree(dirB), isEmpty);
    await autoAnswer!.cancel();
    answerB(true);

    final (status, body) = await _raw('POST', b.self, '/prepare-upload',
        json: {
          ..._mallory({'f1': 'movie.bin'}),
          'files': {
            'f1': {'id': 'f1', 'fileName': 'movie.bin', 'size': 1 << 20}
          },
        });
    expect(status, 200);
    final sid = body!['sessionId'] as String;
    final token = (body['files'] as Map)['f1'] as String;
    final secret = body['cancelSecret'] as String;

    final client = HttpClient()..badCertificateCallback = (_, _, _) => true;
    try {
      final req = await client.postUrl(Uri.parse(
          'https://127.0.0.1:${b.self.port}/api/localsend/v2/upload'
          '?sessionId=$sid&fileId=f1&token=$token'));
      req.contentLength = 1 << 20;
      req.add(List<int>.filled(100 * 1024, 7));
      await req.flush();
      List<String> tree = [];
      for (var i = 0; i < 100; i++) {
        tree = _tree(dirB);
        if (tree.isNotEmpty &&
            File('${dirB.path}/${tree.single}').lengthSync() >= 100 * 1024) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(tree, ['.movie.bin.part']);
      expect(File('${dirB.path}/movie.bin').existsSync(), isFalse);

      // upload-status reports the bytes in the .part file.
      final st = await _rawStatus(b.self, sid, 'f1', token);
      expect(st.$1, 200);
      expect(st.$2!['received'], 100 * 1024);
      expect(st.$2!['active'], isTrue);

      expect((await _raw('POST', b.self, '/cancel',
              query: {'sessionId': sid, 'cancelSecret': secret}))
          .$1, 200);
      for (var i = 0; i < 50 && _tree(dirB).isNotEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(_tree(dirB), isEmpty);
      req.abort();
    } finally {
      client.close(force: true);
    }
  });

  test('upload with a wrong offset gets 409 with the real length', () async {
    answerB(true);
    final (_, body) = await _raw('POST', b.self, '/prepare-upload',
        json: _mallory({'f1': 'r.txt'}));
    final sid = body!['sessionId'] as String;
    final token = (body['files'] as Map)['f1'] as String;
    final q = {'sessionId': sid, 'fileId': 'f1', 'token': token};
    // Short body: receiver keeps 2 bytes in the .part file.
    final c = HttpClient()..badCertificateCallback = (_, _, _) => true;
    final req = await c.postUrl(Uri.https('127.0.0.1:${b.self.port}',
        '/api/localsend/v2/upload', {...q, 'offset': '0'}));
    req.add([1, 2]);
    expect((await req.close()).statusCode, 400);
    c.close(force: true);
    expect((await _rawStatus(b.self, sid, 'f1', token)).$2!['received'], 2);
    final (bad, badBody) = await _raw('POST', b.self, '/upload',
        query: {...q, 'offset': '1'}, bytes: [2, 3]);
    expect(bad, 409);
    expect(badBody!['received'], 2);
    final (good, _) = await _raw('POST', b.self, '/upload',
        query: {...q, 'offset': '2'}, bytes: [3]);
    expect(good, 200);
    expect(File('${dirB.path}/r.txt').readAsBytesSync(), [1, 2, 3]);
    expect(_tree(dirB), ['r.txt']);
    // Wrong token on upload-status.
    expect((await _rawStatus(b.self, sid, 'f1', 'nope')).$1, 403);
  });

  test('cancel requires the session cancel secret', () async {
    answerB(true);
    final (_, body) = await _raw('POST', b.self, '/prepare-upload',
        json: _mallory({'f1': 'c.txt'}));
    final sid = body!['sessionId'] as String;
    final token = (body['files'] as Map)['f1'] as String;
    final secret = body['cancelSecret'] as String;
    expect(secret, matches(RegExp(r'^[0-9a-f]{32}$')));

    expect((await _raw('POST', b.self, '/cancel', query: {'sessionId': sid}))
        .$1, 403);
    expect((await _raw('POST', b.self, '/cancel',
            query: {'sessionId': sid, 'cancelSecret': 'wrong'}))
        .$1, 403);
    expect((await _raw('POST', b.self, '/cancel',
            query: {'sessionId': 'other', 'cancelSecret': secret}))
        .$1, 403);
    // Session still alive after the rejected cancels.
    expect((await _rawStatus(b.self, sid, 'f1', token)).$1, 200);

    expect((await _raw('POST', b.self, '/cancel',
            query: {'sessionId': sid, 'cancelSecret': secret}))
        .$1, 200);
    // Session ended: uploads rejected, receiver free for a new request.
    expect((await _raw('POST', b.self, '/upload',
            query: {'sessionId': sid, 'fileId': 'f1', 'token': token},
            bytes: [1, 2, 3]))
        .$1, 403);
    expect((await _raw('POST', b.self, '/prepare-upload',
            json: _mallory({'f1': 'd.txt'})))
        .$1, 200);
  });

  test('folder transfer recreates nested dirs byte-identically', () async {
    final root = Directory('${tmp.path}/src/Photos');
    final files = {
      'a.jpg': await _randomFile('${root.path}/a.jpg', 300000, 1),
      '2024/b.bin': await _randomFile('${root.path}/2024/b.bin', 1 << 20, 2),
      '2024/deep/c.txt':
          await _randomFile('${root.path}/2024/deep/c.txt', 10, 3),
      'empty.txt': await _randomFile('${root.path}/empty.txt', 0, 4),
    };
    IncomingRequest? got;
    autoAnswer = b.incoming.listen((r) {
      got = r;
      r.decision.complete(true);
    });
    final peer = (await a.addPeerByIp('127.0.0.1', port: b.self.port))!;
    final r = await a.sendFiles(peer, [SendItem(root.path)]);
    expect(r.ok, isTrue, reason: r.error);
    expect(got!.files.map((f) => f.fileName).toSet(),
        {for (final k in files.keys) 'Photos/$k'});
    expect(_tree(dirB), [for (final k in files.keys) 'Photos/$k']..sort());
    for (final e in files.entries) {
      expect(await _sha(File('${dirB.path}/Photos/${e.key}')),
          await _sha(e.value));
    }

    // Same folder again: goes to "Photos (1)", the first copy is untouched.
    File('${dirB.path}/Photos/a.jpg').writeAsStringSync('mine');
    expect((await a.sendFiles(peer, [SendItem(root.path)])).ok, isTrue);
    expect(File('${dirB.path}/Photos/a.jpg').readAsStringSync(), 'mine');
    expect(await _sha(File('${dirB.path}/Photos (1)/2024/deep/c.txt')),
        await _sha(files['2024/deep/c.txt']!));
    expect(_tree(dirB).where((p) => p.endsWith('.part')), isEmpty);
  });

  test('hostile relative paths cannot escape saveDir', () async {
    final outside = _tree(tmp).where((p) => !p.startsWith('b/')).toList();
    // A symlink inside saveDir pointing outside must not be followed.
    final escape = await Directory('${tmp.path}/escape').create();
    Link('${dirB.path}/Evil').createSync(escape.path);
    answerB(true);
    final names = {
      'f1': '../x',
      'f2': 'a/../../x',
      'f3': '/abs',
      'f4': r'C:\x',
      'f5': 'a//b',
      'f6': r'..\..\..\win.ini',
      'f7': 'Evil/payload',
      'f8': '../../../../../../../../tmp/landrop_pwned',
    };
    final (status, body) = await _raw('POST', b.self, '/prepare-upload',
        json: _mallory(names));
    expect(status, 200);
    final sid = body!['sessionId'] as String;
    final tokens = body['files'] as Map;
    for (final id in names.keys) {
      final (up, _) = await _raw('POST', b.self, '/upload',
          query: {'sessionId': sid, 'fileId': id, 'token': tokens[id]},
          bytes: utf8.encode('pwn'));
      expect(up, 200, reason: names[id]);
    }
    final inside = _tree(dirB);
    expect(inside, hasLength(names.length));
    expect(inside, containsAll(['x', 'a/x', 'abs', 'a/b', 'win.ini']));
    expect(inside, contains('Evil (1)/payload'));
    expect(escape.listSync(), isEmpty);
    expect(_tree(tmp).where((p) => !p.startsWith('b/')).toList(), outside);
    expect(File('/tmp/landrop_pwned').existsSync(), isFalse);

    expect(sanitizeRelativePath('../x'), ['x']);
    expect(sanitizeRelativePath('a/../../x'), ['a', 'x']);
    expect(sanitizeRelativePath('/abs'), ['abs']);
    expect(sanitizeRelativePath(r'C:\x'), ['x']);
    expect(sanitizeRelativePath('a//b'), ['a', 'b']);
    expect(sanitizeRelativePath('./.git/config'), ['git', 'config']);
    expect(sanitizeRelativePath('..'), ['file']);
    expect(sanitizeRelativePath(''), ['file']);
  });

  test('two concurrent sends to different peers keep progress separate',
      () async {
    final c = LanDropCoreImpl(_opts(0));
    await c.start(alias: 'Carol', saveDir: '${tmp.path}/c');
    final toC = c.incoming.listen((r) async {
      // Accept later than b, so session ids arrive out of call order.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      r.decision.complete(true);
    });
    try {
      answerB(true);
      final f1 = await _randomFile('${tmp.path}/for-c.bin', 2 << 20, 5);
      final f2 = await _randomFile('${tmp.path}/for-b.bin', 3 << 20, 6);
      final prog = <TransferProgress>[];
      final sub = a.progress.listen(prog.add);
      final peerC = (await a.addPeerByIp('127.0.0.1', port: c.self.port))!;
      final peerB = (await a.addPeerByIp('127.0.0.1', port: b.self.port))!;
      final order = <String>[];
      final rs = await Future.wait([
        a.sendFiles(peerC, [SendItem(f1.path)],
            onSession: (s) => order.add('c:$s')),
        a.sendFiles(peerB, [SendItem(f2.path)],
            onSession: (s) => order.add('b:$s')),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      expect(rs.every((r) => r.ok), isTrue);
      expect(order.first, startsWith('b:'), reason: 'b accepted first');
      final sidC = rs[0].sessionId!, sidB = rs[1].sessionId!;
      expect(sidC, isNot(sidB));
      final forC = prog.where((p) => p.sessionId == sidC).toList();
      final forB = prog.where((p) => p.sessionId == sidB).toList();
      expect(forC.length + forB.length, prog.length);
      expect(forC.every((p) => p.fileName == 'for-c.bin'), isTrue);
      expect(forB.every((p) => p.fileName == 'for-b.bin'), isTrue);
      expect(forC.last.sentBytes, 2 << 20);
      expect(forB.last.sentBytes, 3 << 20);
    } finally {
      await toC.cancel();
      await c.dispose();
    }
  });

  test('discovery startup failure is reported, not swallowed', () async {
    final c = LanDropCoreImpl(_opts(0, transport: _FailingTransport()));
    try {
      await c.start(alias: 'Carol', saveDir: '${tmp.path}/c');
      expect(c.discoveryError, contains('no multicast here'));
      expect(a.discoveryError, isNull);
    } finally {
      await c.dispose();
    }
  });

  // ---------------------------------------------- capabilities + diagnosis

  test('capability record in info and at /api/landrop/v1/capabilities',
      () async {
    final (status, info) = await _raw('GET', a.self, '/info');
    expect(status, 200);
    final c = HttpClient()..badCertificateCallback = (_, _, _) => true;
    Map<String, dynamic> caps;
    try {
      final req = await c.getUrl(Uri.https(
          '${a.self.ip}:${a.self.port}', '/api/landrop/v1/capabilities'));
      final res = await req.close();
      expect(res.statusCode, 200);
      caps = jsonDecode(await res.transform(utf8.decoder).join())
          as Map<String, dynamic>;
    } finally {
      c.close(force: true);
    }
    expect(caps, info!['landrop']);
    expect(caps['v'], 1);
    expect(caps['features'], containsAll(['resume', 'folders']));
    final t = (caps['transports'] as List).single as Map<String, dynamic>;
    expect(t['id'], 'lan-https');
    expect(t['port'], a.self.port);
    expect(t['addrs'], contains('127.0.0.1'));
    // The plain LocalSend fields are untouched.
    expect(info['fingerprint'], a.self.fingerprint);
  });

  test('capabilities parsed into the peer; manual recorded in foundVia',
      () async {
    final info = await a.addPeerByIp('127.0.0.1', port: b.self.port);
    expect(info!.foundVia, {'manual'});
    final caps = info.capabilities!;
    expect(caps.version, 1);
    expect(caps.features, containsAll({'resume', 'folders'}));
    expect(caps.transports.single.id, 'lan-https');
    expect(caps.transports.single.port, b.self.port);
    final peer = a.currentPeers.single;
    expect(peer.foundVia, {'manual'});
    expect(peer.capabilities!.transports.single.addrs, contains('127.0.0.1'));
    expect(PeerCapabilities.fromJson('junk'), isNull);
    expect(PeerCapabilities.fromJson({'transports': [1, {}]})!.transports,
        isEmpty);
  });

  test('scan recorded in foundVia (loopback scan)', () async {
    final c = LanDropCoreImpl(LanDropCoreOptions(
      port: a.self.port, // busy: c falls back, but scans a's port
      bindAddress: InternetAddress.loopbackIPv4,
      advertiseIp: '127.0.0.1',
      multicastEnabled: false,
      persistIdentity: false,
      scanHosts: const ['127.0.0.1'],
    ));
    try {
      await c.start(alias: 'Carol', saveDir: '${tmp.path}/c');
      await c.scanSubnet();
      final found =
          c.currentPeers.where((p) => p.fingerprint == a.self.fingerprint);
      expect(found.single.foundVia, {'scan'});
      // Adding the same peer by IP adds a second way.
      await c.addPeerByIp('127.0.0.1', port: a.self.port);
      expect(
          c.currentPeers
              .singleWhere((p) => p.fingerprint == a.self.fingerprint)
              .foundVia,
          {'scan', 'manual'});
    } finally {
      await c.dispose();
    }
  });

  test('announce and register recorded in foundVia', () async {
    final hub = _Hub();
    final dir = await Directory('${tmp.path}/disc2').create();
    final c = LanDropCoreImpl(_opts(0, transport: _HubTransport(hub)));
    final d = LanDropCoreImpl(_opts(0, transport: _HubTransport(hub)));
    try {
      await c.start(alias: 'Carol', saveDir: '${dir.path}/c');
      await d.start(alias: 'Dave', saveDir: '${dir.path}/d');
      final l = await c.peers
          .firstWhere((l) => l.isNotEmpty)
          .timeout(const Duration(seconds: 5));
      // The in-memory hub does not tag datagrams, so "announce" (or
      // "register" when d answered first).
      expect(l.single.foundVia, isNotEmpty);
      expect({'announce', 'register'}.containsAll(l.single.foundVia), isTrue);
      final f = await c.runDiagnosis();
      expect(f.map((x) => x.code), isNot(contains('announce-blocked')));
    } finally {
      await c.dispose();
      await d.dispose();
    }
  });

  test('runDiagnosis against a live second core', () async {
    await a.addPeerByIp('127.0.0.1', port: b.self.port);
    final f = await a.runDiagnosis(targetIp: '127.0.0.1');
    final codes = f.map((x) => x.code).toList();
    expect(codes, contains('probe-ok'));
    expect(codes, isNot(contains('server-down')));
    expect(codes, isNot(contains('probe-fingerprint-mismatch')));
    // Manual only, but discovery is disabled here: no router warning.
    expect(codes, isNot(contains('announce-blocked')));
    expect(codes.last, 'network');
    expect(f.last.technical, contains('listening on port ${a.self.port}'));
  });

  test('runDiagnosis against a closed port reports refused', () async {
    final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final closed = s.port;
    await s.close();
    final f = await a.runDiagnosis(targetIp: '127.0.0.1', targetPort: closed);
    expect(f.first.code, 'probe-refused');
    expect(f.first.severity, Severity.problem);
  });

  test('runDiagnosis reports a fingerprint mismatch after a reinstall',
      () async {
    await a.addPeerByIp('127.0.0.1', port: b.self.port);
    final port = b.self.port;
    await b.stop();
    // A "reinstalled" device (new certificate) on the same address.
    final e = LanDropCoreImpl(LanDropCoreOptions(
      port: port,
      portFallbackRange: 0,
      bindAddress: InternetAddress.loopbackIPv4,
      advertiseIp: '127.0.0.1',
      multicastEnabled: false,
      persistIdentity: false,
    ));
    try {
      await e.start(alias: 'Bob', saveDir: '${tmp.path}/e');
      expect(e.self.port, port);
      final f = await a.runDiagnosis(targetIp: '127.0.0.1', targetPort: port);
      final m = f.firstWhere((x) => x.code == 'probe-fingerprint-mismatch');
      expect(m.technical, isNot(contains(e.self.fingerprint)));
      expect(m.technical,
          contains(e.self.fingerprint.substring(0, 8).toUpperCase()));
    } finally {
      await e.dispose();
    }
  });

  test('runDiagnosis against a blackhole address reports a timeout',
      () async {
    final c = LanDropCoreImpl(const LanDropCoreOptions(
      port: 0,
      multicastEnabled: false,
      persistIdentity: false,
      probeTimeout: Duration(milliseconds: 400),
    ));
    try {
      await c.start(alias: 'Carol', saveDir: '${tmp.path}/c');
      final sw = Stopwatch()..start();
      // 10.255.255.1: routable but nothing answers (TCP SYN is dropped).
      final f = await c.runDiagnosis(targetIp: '10.255.255.1');
      expect(sw.elapsed, lessThan(const Duration(seconds: 3)));
      expect(f.map((x) => x.code), contains('probe-timeout'));
      expect(f.map((x) => x.code), isNot(contains('server-down')));
    } finally {
      await c.dispose();
    }
  });

  test('runDiagnosis on a stopped core reports the server down', () async {
    await b.stop();
    final f = await b.runDiagnosis();
    expect(f.first.code, 'server-down');
  });
}
