import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/core/diagnosis.dart';
import 'package:landrop/core/landrop_core.dart';
import 'package:landrop/core/mdns.dart';

import 'mdns_memory.dart';

LanDropCoreOptions _opts(MdnsHub hub, {bool fail = false}) => LanDropCoreOptions(
      port: 0,
      bindAddress: InternetAddress.loopbackIPv4,
      advertiseIp: '127.0.0.1',
      multicastEnabled: false,
      mdnsEnabled: true,
      mdnsAllowLoopback: true,
      mdnsSocketFactory: () => MemoryMdnsSocket(hub, failStart: fail),
      persistIdentity: false,
      probeTimeout: const Duration(seconds: 2),
    );

void main() {
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('mdnscore'));
  tearDown(() async => tmp.delete(recursive: true));

  test('peer found through mDNS gets foundVia mdns; diagnosis says mdns-only',
      () async {
    final hub = MdnsHub();
    final a = LanDropCoreImpl(_opts(hub));
    final b = LanDropCoreImpl(_opts(hub));
    try {
      await a.start(alias: 'Alice', saveDir: '${tmp.path}/a');
      await b.start(alias: 'Bob', saveDir: '${tmp.path}/b');
      final l = await a.peers
          .firstWhere((l) => l.isNotEmpty)
          .timeout(const Duration(seconds: 5));
      expect(l.single.fingerprint, b.self.fingerprint);
      expect(l.single.alias, 'Bob');
      expect(l.single.port, b.self.port);
      expect(l.single.foundVia, contains('mdns'));
      final codes = (await a.runDiagnosis()).map((f) => f.code);
      expect(codes, contains('mdns-only'));
      expect(codes, isNot(contains('announce-blocked')));
      // restartDiscovery re-binds, re-announces and re-queries.
      await a.restartDiscovery();
      final d = await a.observe();
      expect(d.mdnsStarted, isTrue);
      expect(hub.members.length, 2);
    } finally {
      await a.dispose();
      await b.dispose();
    }
    expect(hub.members, isEmpty);
  });

  test('candidate whose fingerprint does not match HTTPS /info is rejected',
      () async {
    final hub = MdnsHub();
    final a = LanDropCoreImpl(_opts(hub));
    final b = LanDropCoreImpl(_opts(hub));
    final evil = MemoryMdnsSocket(hub);
    try {
      await a.start(alias: 'Alice', saveDir: '${tmp.path}/a');
      await b.start(alias: 'Bob', saveDir: '${tmp.path}/b');
      await a.peers
          .firstWhere((l) => l.isNotEmpty)
          .timeout(const Duration(seconds: 5));
      await evil.start((_, _) {});
      const fakeFp =
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
      const inst = 'Fake._landrop._tcp.local';
      await evil.send(encodeDnsMessage(DnsMessage(flags: 0x8400, records: [
        DnsRecord.ptr(mdnsServiceName, inst),
        DnsRecord.srv(inst, 'fake.local', b.self.port),
        DnsRecord.txtRecord(inst, ['fp=$fakeFp', 'alias=Mallory']),
        DnsRecord.a('fake.local', '127.0.0.1'),
      ])));
      await Future.delayed(const Duration(milliseconds: 800));
      expect(a.currentPeers.map((p) => p.fingerprint),
          [b.self.fingerprint]); // Mallory not added
      final d = await a.observe();
      final m = d.mdnsPeers.singleWhere((p) => p.alias == 'Mallory');
      expect(m.failure, 'fingerprint-mismatch');
    } finally {
      await evil.close();
      await a.dispose();
      await b.dispose();
    }
  });

  test('mDNS bind failure does not break the app and shows in diagnosis',
      () async {
    final a = LanDropCoreImpl(_opts(MdnsHub(), fail: true));
    try {
      await a.start(alias: 'Alice', saveDir: '${tmp.path}/a');
      final d = await a.observe();
      expect(d.mdnsEnabled, isTrue);
      expect(d.mdnsStarted, isFalse);
      expect(d.mdnsError, contains('address in use'));
      final codes = diagnose(d).map((f) => f.code);
      expect(codes, contains('mdns-unavailable'));
      expect(codes, isNot(contains('server-down')));
    } finally {
      await a.dispose();
    }
  });
}
