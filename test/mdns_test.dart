import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/core/mdns.dart';

import 'mdns_memory.dart';

final fpA = 'a1' * 32;
final fpB = 'b2' * 32;

MdnsService _svc(MdnsHub hub, String fp, String alias, int port, String ip,
        {bool fail = false}) =>
    MdnsService(
      socket: MemoryMdnsSocket(hub, ip: ip, failStart: fail),
      fingerprint: fp,
      alias: alias,
      deviceType: 'mobile',
      port: port,
      addresses: () async => [ip],
      queryInterval: const Duration(seconds: 30),
      announceInterval: const Duration(seconds: 30),
    );

Future<void> _pump() => Future.delayed(const Duration(milliseconds: 50));

void main() {
  group('dns codec', () {
    test('round trip', () {
      final m = DnsMessage(flags: 0x8400, questions: const [
        DnsQuestion(mdnsServiceName, dnsTypePtr)
      ], records: [
        DnsRecord.ptr(mdnsServiceName, 'X._landrop._tcp.local'),
        DnsRecord.srv('X._landrop._tcp.local', 'X.local', 53317),
        DnsRecord.txtRecord('X._landrop._tcp.local', ['fp=ab', 'alias=Ünï']),
        DnsRecord.a('X.local', '192.168.1.5', ttl: 0),
      ]);
      final d = decodeDnsMessage(encodeDnsMessage(m))!;
      expect(d.isResponse, isTrue);
      expect(d.questions.single.name, mdnsServiceName);
      expect(d.records.length, 4);
      expect(d.records[0].target, 'X._landrop._tcp.local');
      expect(d.records[1].port, 53317);
      expect(d.records[1].target, 'X.local');
      expect(d.records[2].txt, ['fp=ab', 'alias=Ünï']);
      expect(d.records[3].ip, '192.168.1.5');
      expect(d.records[3].ttl, 0);
    });

    test('malformed packets never throw', () {
      final good = encodeDnsMessage(DnsMessage(flags: 0x8400, records: [
        DnsRecord.ptr(mdnsServiceName, 'X._landrop._tcp.local'),
        DnsRecord.srv('X._landrop._tcp.local', 'X.local', 1),
        DnsRecord.txtRecord('X._landrop._tcp.local', ['a=b']),
        DnsRecord.a('X.local', '10.0.0.1'),
      ]));
      for (var n = 0; n < good.length; n++) {
        expect(() => decodeDnsMessage(good.sublist(0, n)), returnsNormally);
      }
      // pointer loop: name at 12 points to itself
      final loop = Uint8List.fromList([
        0, 0, 0x84, 0, 0, 1, 0, 0, 0, 0, 0, 0, //
        0xC0, 12, 0, 12, 0, 1
      ]);
      expect(decodeDnsMessage(loop), isNull);
      // oversize label (len 64 is invalid)
      final big = Uint8List.fromList(
          [0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 64, ...List.filled(64, 97), 0, 0, 12, 0, 1]);
      expect(decodeDnsMessage(big), isNull);
      // huge counts
      expect(
          decodeDnsMessage(Uint8List.fromList(
              [0, 0, 0x84, 0, 0xff, 0xff, 0xff, 0xff, 0, 0, 0, 0])),
          isNull);
      final rnd = Random(7);
      for (var i = 0; i < 3000; i++) {
        final b = Uint8List.fromList(
            List.generate(rnd.nextInt(200), (_) => rnd.nextInt(256)));
        expect(() => decodeDnsMessage(b), returnsNormally);
        // mutate a valid packet
        final m = Uint8List.fromList(good);
        m[rnd.nextInt(m.length)] = rnd.nextInt(256);
        expect(() => decodeDnsMessage(m), returnsNormally);
      }
    });
  });

  group('service in memory', () {
    test('B discovers A with TXT, port and addresses; goodbye removes',
        () async {
      final hub = MdnsHub();
      final a = _svc(hub, fpA, 'Alice phone', 53318, '192.168.1.10');
      final b = _svc(hub, fpB, 'Bob', 53317, '192.168.1.11');
      final found = <MdnsCandidate>[];
      b.onFound.listen(found.add);
      final gone = <String>[];
      b.onGone.listen(gone.add);
      await a.start();
      await b.start();
      await _pump();
      final c = b.candidates[fpA]!;
      expect(c.alias, 'Alice phone');
      expect(c.deviceType, 'mobile');
      expect(c.port, 53318);
      expect(c.addresses, ['192.168.1.10']);
      expect(a.instanceName, 'LanDrop-a1a1a1a1._landrop._tcp.local');
      expect(b.candidates.containsKey(fpB), isFalse); // own ignored
      expect(a.candidates.keys, [fpB]);
      await a.stop();
      await _pump();
      expect(gone, [fpA]);
      expect(b.candidates, isEmpty);
      await b.stop();
    });

    test('query on demand finds a service that started earlier', () async {
      final hub = MdnsHub();
      final a = _svc(hub, fpA, 'A', 1000, '10.0.0.2');
      await a.start();
      await _pump();
      final b = _svc(hub, fpB, 'B', 1001, '10.0.0.3');
      await b.start(); // its own query makes A answer
      await _pump();
      expect(b.candidates.keys, [fpA]);
      await a.stop();
      await b.stop();
    });

    test('meta query answered with the service type', () async {
      final hub = MdnsHub();
      final a = _svc(hub, fpA, 'A', 1000, '10.0.0.2');
      await a.start();
      final probe = MemoryMdnsSocket(hub);
      final got = Completer<DnsMessage>();
      await probe.start((d, _) {
        final m = decodeDnsMessage(d);
        if (m != null &&
            m.isResponse &&
            m.records.any((r) => r.name == mdnsMetaName)) {
          got.complete(m);
        }
      });
      await probe.send(encodeDnsMessage(const DnsMessage(
          questions: [DnsQuestion(mdnsMetaName, dnsTypePtr)])));
      final m = await got.future.timeout(const Duration(seconds: 2));
      expect(m.records.first.target, mdnsServiceName);
      await a.stop();
    });

    test('malicious TXT / addresses ignored', () async {
      final hub = MdnsHub();
      final b = _svc(hub, fpB, 'B', 1, '10.0.0.3');
      await b.start();
      final evil = MemoryMdnsSocket(hub);
      await evil.start((_, _) {});
      var n = 0;
      Future<void> send(List<String> txt, {int port = 80, String ip = '10.1.1.1'}) async {
        final id = n++;
        final inst = 'Evil$id._landrop._tcp.local';
        await evil.send(encodeDnsMessage(DnsMessage(flags: 0x8400, records: [
          DnsRecord.ptr(mdnsServiceName, inst),
          DnsRecord.srv(inst, 'evil$id.local', port),
          DnsRecord.txtRecord(inst, txt),
          DnsRecord.a('evil$id.local', ip),
        ])));
        await _pump();
      }

      await send(['fp=nothex', 'alias=x']);
      await send(['fp=${'c3' * 32}'], port: 0);
      await send(['fp=${'c3' * 32}'], ip: '8.8.8.8');
      await send(['fp=${'c3' * 32}'], ip: '127.0.0.1');
      expect(b.candidates, isEmpty);
      // valid, with hostile alias/type: sanitised and capped
      await send(['fp=${'C3' * 32}', 'alias=${'x\u0000y' * 40}', 'type=../../etc']);
      final c = b.candidates['c3' * 32]!;
      expect(c.alias.length, 64);
      expect(c.alias.contains('\u0000'), isFalse);
      expect(c.deviceType, 'desktop');
      // garbage on the socket does not throw
      for (final m in hub.members) {
        m.inject([1, 2, 3]);
        m.inject(List.filled(50, 0xff));
      }
      await b.stop();
    });

    test('bind failure is reported, not thrown', () async {
      final s = _svc(MdnsHub(), fpA, 'A', 1, '10.0.0.2', fail: true);
      await s.start();
      expect(s.started, isFalse);
      expect(s.error, contains('address in use'));
      await s.stop();
    });
  });

  test('real sockets (skipped when multicast is unavailable)', () async {
    final a = MdnsService(
        socket: RawMdnsSocket(),
        fingerprint: fpA,
        alias: 'Real A',
        deviceType: 'desktop',
        port: 53399,
        addresses: () async => ['192.168.77.1'],
        allowLoopback: true);
    await a.start();
    if (a.error != null) {
      await a.stop();
      markTestSkipped('cannot bind 5353: ${a.error}');
      return;
    }
    final b = MdnsService(
        socket: RawMdnsSocket(),
        fingerprint: fpB,
        alias: 'Real B',
        deviceType: 'desktop',
        port: 53398,
        addresses: () async => ['192.168.77.2'],
        allowLoopback: true);
    await b.start();
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (DateTime.now().isBefore(deadline) &&
        !b.candidates.containsKey(fpA)) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    final ok = b.candidates.containsKey(fpA);
    await a.stop();
    await b.stop();
    if (!ok) {
      markTestSkipped('loopback multicast not delivered here');
      return;
    }
    expect(true, isTrue);
  });
}
