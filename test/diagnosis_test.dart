// Unit tests for the pure diagnosis rules (lib/core/diagnosis.dart).
import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/core/diagnosis.dart';

const _wifi = InterfaceObservation('en0', ['192.168.1.10']);
const _vpn = InterfaceObservation('utun4', ['10.8.0.2']);

DiagnosisInput _in({
  String? discoveryError,
  bool discoveryEnabled = true,
  List<InterfaceObservation> interfaces = const [_wifi],
  bool serverListening = true,
  List<PeerObservation> peers = const [],
  ProbeObservation? probe,
}) =>
    DiagnosisInput(
      discoveryError: discoveryError,
      discoveryEnabled: discoveryEnabled,
      interfaces: interfaces,
      serverListening: serverListening,
      serverPort: 53317,
      peers: peers,
      probe: probe,
    );

ProbeObservation _probe(TcpOutcome tcp,
        {String ip = '192.168.1.20',
        bool? infoOk,
        bool mismatch = false,
        String? expected,
        String? presented}) =>
    ProbeObservation(
        ip: ip,
        port: 53317,
        tcp: tcp,
        infoOk: infoOk,
        fingerprintMismatch: mismatch,
        expectedFingerprint: expected,
        presentedFingerprint: presented);

List<String> _codes(List<Finding> f) => f.map((x) => x.code).toList();

void main() {
  test('server not listening', () {
    expect(ruleServerNotListening(_in()), isEmpty);
    final f = ruleServerNotListening(_in(serverListening: false)).single;
    expect(f.code, 'server-down');
    expect(f.severity, Severity.problem);
  });

  test('discovery socket failed', () {
    expect(ruleDiscoveryFailed(_in()), isEmpty);
    final f = ruleDiscoveryFailed(_in(discoveryError: 'bind failed')).single;
    expect(f.code, 'discovery-failed');
    expect(f.severity, Severity.problem);
    expect(f.technical, 'bind failed');
  });

  test('no private IPv4 on a real interface', () {
    expect(ruleNoLan(_in()), isEmpty);
    expect(ruleNoLan(_in(interfaces: const [])).single.code, 'no-lan');
    // A VPN address or a public address does not count as a LAN.
    expect(ruleNoLan(_in(interfaces: const [_vpn])).single.code, 'no-lan');
    expect(
        ruleNoLan(_in(interfaces: const [
          InterfaceObservation('en0', ['8.8.4.4'])
        ])),
        hasLength(1));
    expect(
        ruleNoLan(_in(interfaces: const [
          InterfaceObservation('wlan0', ['172.20.3.4'])
        ])),
        isEmpty);
  });

  test('VPN interface active', () {
    expect(ruleVpnActive(_in()), isEmpty);
    // A VPN-like interface without an address (macOS utun0) is ignored.
    expect(
        ruleVpnActive(
            _in(interfaces: const [_wifi, InterfaceObservation('utun0', [])])),
        isEmpty);
    final f = ruleVpnActive(_in(interfaces: const [_wifi, _vpn])).single;
    expect(f.code, 'vpn-active');
    expect(f.severity, Severity.warn);
    expect(f.technical, contains('utun4'));
  });

  test('peers only by scan/manual means multicast+broadcast are blocked', () {
    const scanned = PeerObservation('Bob', '192.168.1.20', {'scan'});
    const manual = PeerObservation('Eve', '192.168.1.21', {'manual'});
    const announced =
        PeerObservation('Carol', '192.168.1.22', {'multicast', 'scan'});
    expect(ruleAnnounceBlocked(_in()), isEmpty);
    expect(ruleAnnounceBlocked(_in(peers: const [announced])), isEmpty);
    final f = ruleAnnounceBlocked(_in(peers: const [scanned, manual])).single;
    expect(f.code, 'announce-blocked');
    expect(f.severity, Severity.warn);
    expect(f.detail, contains('Transfers still work by IP'));
    // Mixed: some announce, others only by scan -> informational.
    final g =
        ruleAnnounceBlocked(_in(peers: const [announced, scanned])).single;
    expect(g.code, 'some-peers-silent');
    expect(g.severity, Severity.info);
    // Our own discovery broken or disabled: not the router's fault.
    expect(
        ruleAnnounceBlocked(
            _in(peers: const [scanned], discoveryError: 'no socket')),
        isEmpty);
    expect(
        ruleAnnounceBlocked(
            _in(peers: const [scanned], discoveryEnabled: false)),
        isEmpty);
    // 'register' (they called us back) counts as automatic.
    expect(
        ruleAnnounceBlocked(_in(peers: const [
          PeerObservation('D', '192.168.1.5', {'register'})
        ])),
        isEmpty);
  });

  test('probe refused', () {
    expect(ruleProbeRefused(_in()), isEmpty);
    expect(ruleProbeRefused(_in(probe: _probe(TcpOutcome.timeout))), isEmpty);
    final f = ruleProbeRefused(_in(probe: _probe(TcpOutcome.refused))).single;
    expect(f.code, 'probe-refused');
    expect(f.detail, contains('LanDrop is probably closed'));
  });

  test('probe timeout', () {
    expect(ruleProbeTimeout(_in(probe: _probe(TcpOutcome.refused))), isEmpty);
    final f = ruleProbeTimeout(_in(probe: _probe(TcpOutcome.timeout))).single;
    expect(f.code, 'probe-timeout');
    expect(f.fix, contains('hotspot'));
    expect(f.detail, contains('isolation'));
  });

  test('probe unreachable', () {
    expect(ruleProbeUnreachable(_in(probe: _probe(TcpOutcome.timeout))),
        isEmpty);
    expect(
        ruleProbeUnreachable(_in(probe: _probe(TcpOutcome.unreachable)))
            .single
            .code,
        'probe-unreachable');
  });

  test('probe fingerprint mismatch shortens fingerprints', () {
    final ok = _probe(TcpOutcome.connected, infoOk: true);
    expect(ruleProbeFingerprintMismatch(_in(probe: ok)), isEmpty);
    final f = ruleProbeFingerprintMismatch(_in(
            probe: _probe(TcpOutcome.connected,
                infoOk: true,
                mismatch: true,
                expected: 'ab' * 32,
                presented: 'cd' * 32)))
        .single;
    expect(f.code, 'probe-fingerprint-mismatch');
    expect(f.detail, contains('reinstalled'));
    expect(f.technical, contains('ABABABAB…ABABABAB'));
    expect(f.technical, isNot(contains('ab' * 32)));
  });

  test('probe connected but not LanDrop / probe ok', () {
    final f = ruleProbeNotLanDrop(
            _in(probe: _probe(TcpOutcome.connected, infoOk: false)))
        .single;
    expect(f.code, 'probe-not-landrop');
    expect(
        ruleProbeNotLanDrop(
            _in(probe: _probe(TcpOutcome.connected, infoOk: true))),
        isEmpty);
    expect(
        ruleProbeOk(_in(probe: _probe(TcpOutcome.connected, infoOk: true)))
            .single
            .code,
        'probe-ok');
    expect(
        ruleProbeOk(_in(
            probe: _probe(TcpOutcome.connected, infoOk: true, mismatch: true))),
        isEmpty);
  });

  test('different /24 subnet between this device and the target', () {
    // Same /24: nothing.
    expect(ruleDifferentSubnet(_in(probe: _probe(TcpOutcome.timeout))),
        isEmpty);
    final f = ruleDifferentSubnet(
            _in(probe: _probe(TcpOutcome.timeout, ip: '192.168.0.20')))
        .single;
    expect(f.code, 'different-subnet');
    expect(f.detail, contains('guest network'));
    expect(f.technical, contains('192.168.1.10'));
    // Reachable anyway (routed network): no warning.
    expect(
        ruleDifferentSubnet(_in(
            probe: _probe(TcpOutcome.connected,
                ip: '192.168.0.20', infoOk: true))),
        isEmpty);
    // Public target or no LAN address of our own: not this rule's business.
    expect(
        ruleDifferentSubnet(
            _in(probe: _probe(TcpOutcome.timeout, ip: '8.8.8.8'))),
        isEmpty);
    expect(
        ruleDifferentSubnet(_in(
            interfaces: const [],
            probe: _probe(TcpOutcome.timeout, ip: '192.168.0.20'))),
        isEmpty);
  });

  test('everything fine', () {
    final f = diagnose(_in(peers: const [
      PeerObservation('Bob', '192.168.1.20', {'multicast'})
    ]));
    expect(_codes(f), ['all-good', 'network']);
    expect(f.last.technical, contains('en0: 192.168.1.10'));
    expect(f.last.technical, contains('Bob 192.168.1.20 via multicast'));
  });

  test('diagnose orders problems first and drops all-good', () {
    final f = diagnose(_in(
      interfaces: const [_wifi, _vpn],
      discoveryError: 'x',
      probe: _probe(TcpOutcome.timeout, ip: '192.168.0.9'),
    ));
    expect(_codes(f), [
      'discovery-failed',
      'probe-timeout',
      'vpn-active',
      'different-subnet',
      'network',
    ]);
  });

  test('findings a hotspot can fix carry the hotspot-wizard action', () {
    String? actionOf(List<Finding> f, String code) =>
        f.firstWhere((x) => x.code == code).action;
    final timeout = diagnose(
        _in(probe: _probe(TcpOutcome.timeout, ip: '192.168.0.9')));
    expect(actionOf(timeout, 'probe-timeout'), hotspotWizardAction);
    expect(actionOf(timeout, 'different-subnet'), hotspotWizardAction);
    final blocked = diagnose(_in(peers: const [
      PeerObservation('Bob', '192.168.1.20', {'scan'})
    ]));
    expect(actionOf(blocked, 'announce-blocked'), hotspotWizardAction);
    expect(actionOf(diagnose(_in(interfaces: const [])), 'no-lan'),
        hotspotWizardAction);
    // Nothing a hotspot would fix: no action.
    final refused = diagnose(_in(probe: _probe(TcpOutcome.refused)));
    expect(actionOf(refused, 'probe-refused'), isNull);
    expect(refused.map((f) => f.code), isNot(contains('hotspot-likely-fix')));
  });

  test('hotspot-likely-fix when nothing at all was found', () {
    final f = ruleHotspotLikelyFix(_in()).single;
    expect(f.code, 'hotspot-likely-fix');
    expect(f.severity, Severity.info);
    expect(f.action, hotspotWizardAction);
    expect(f.detail, contains('hotspot'));
    expect(f.fix, contains('Connect with a hotspot'));
    // It replaces "No problems found" (which would contradict it).
    expect(_codes(diagnose(_in())), ['hotspot-likely-fix', 'network']);
    // Not when devices were found, a target was probed, there is no LAN,
    // or this device itself is not listening.
    expect(
        ruleHotspotLikelyFix(_in(peers: const [
          PeerObservation('Bob', '192.168.1.20', {'multicast'})
        ])),
        isEmpty);
    expect(ruleHotspotLikelyFix(_in(probe: _probe(TcpOutcome.timeout))),
        isEmpty);
    expect(ruleHotspotLikelyFix(_in(interfaces: const [])), isEmpty);
    expect(ruleHotspotLikelyFix(_in(serverListening: false)), isEmpty);
  });

  test('report is plain text with every finding', () {
    final f = diagnose(_in(probe: _probe(TcpOutcome.refused)));
    final r = formatDiagnosisReport(f, target: '192.168.1.20:53317');
    expect(r, startsWith('LanDrop connection report'));
    expect(r, contains('Checked address: 192.168.1.20:53317'));
    expect(r, contains('[PROBLEM] The device is there, but LanDrop is not '
        'answering'));
    expect(r, contains('Fix: Open LanDrop'));
    expect(r, contains('[INFO] Your network'));
    expect(r, contains('en0: 192.168.1.10'));
  });
}
