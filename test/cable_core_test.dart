// A peer whose capability record holds only a 169.254 (link-local) address
// next to a reachable one: candidates include it, the unreachable entry is
// skipped, and the certificate fingerprint is still enforced.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/core/api.dart';
import 'package:landrop/core/landrop_core.dart';

void main() {
  group('capability record with only a link-local address', () {
    test('candidate list contains it; fingerprint is still enforced', () async {
      Future<LanDropCoreImpl> start(String alias) async {
        final c = LanDropCoreImpl(
          LanDropCoreOptions(
            port: 0,
            bindAddress: InternetAddress.loopbackIPv4,
            advertiseIp: '127.0.0.1',
            multicastEnabled: false,
            persistIdentity: false,
          ),
        );
        await c.start(
          alias: alias,
          saveDir: Directory.systemTemp.createTempSync('landrop_cable').path,
        );
        return c;
      }

      final a = await start('Alice');
      final b = await start('Bob');
      addTearDown(() async {
        await a.dispose();
        await b.dispose();
      });
      DeviceInfo peer(String fp, int port) => DeviceInfo(
        alias: 'Bob',
        deviceType: 'desktop',
        fingerprint: fp,
        ip: '169.254.7.7',
        port: port,
        capabilities: PeerCapabilities(
          transports: [
            TransportCapability(
              'lan-https',
              addrs: ['169.254.7.7', '127.0.0.1'],
              port: port,
            ),
          ],
        ),
      );
      final bob = peer(b.self.fingerprint, b.self.port);
      expect(LanHttpsTransport.candidateEndpoints(bob), [
        ('169.254.7.7', b.self.port),
        ('127.0.0.1', b.self.port),
      ]);
      // The unreachable link-local entry is skipped, the loopback one wins.
      final l = await LanHttpsTransport().open(
        bob,
        timeout: const Duration(milliseconds: 800),
      );
      expect(l, isNotNull);
      expect(l!.host, '127.0.0.1');
      expect(l.fingerprint, b.self.fingerprint);
      // Another device's certificate at the reachable address: rejected.
      final impostor = peer(b.self.fingerprint, a.self.port);
      expect(
        await LanHttpsTransport().open(
          impostor,
          timeout: const Duration(milliseconds: 800),
        ),
        isNull,
      );
    });
  });
}
