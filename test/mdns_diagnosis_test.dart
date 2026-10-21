import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/core/diagnosis.dart';

DiagnosisInput _in(
        {List<PeerObservation> peers = const [],
        List<MdnsPeerObservation> mdnsPeers = const [],
        bool started = true,
        String? error,
        String? discoveryError}) =>
    DiagnosisInput(
      interfaces: const [
        InterfaceObservation('en0', ['192.168.1.5'])
      ],
      serverPort: 53317,
      peers: peers,
      mdnsEnabled: true,
      mdnsStarted: started,
      mdnsError: error,
      mdnsPeers: mdnsPeers,
      discoveryError: discoveryError,
    );

void main() {
  const viaMdns = PeerObservation('Bob', '192.168.1.20', {'mdns'});
  const viaUdp = PeerObservation('Carol', '192.168.1.21', {'multicast'});
  const both = PeerObservation('Dan', '192.168.1.22', {'multicast', 'mdns'});

  test('mdns-only: found via mDNS, never via announce', () {
    final f = ruleMdnsOnly(_in(peers: const [viaMdns])).single;
    expect(f.code, 'mdns-only');
    expect(f.severity, Severity.info);
    expect(f.detail, contains('Transfers will work'));
    expect(f.technical, contains('Bob'));
    expect(ruleMdnsOnly(_in(peers: const [both])), isEmpty);
    expect(ruleMdnsOnly(_in(peers: const [viaUdp])), isEmpty);
  });

  test('announce-blocked does not claim full block when mDNS found peers', () {
    const scanned = PeerObservation('Eve', '192.168.1.23', {'scan'});
    expect(ruleAnnounceBlocked(_in(peers: const [viaMdns])), isEmpty);
    final g = ruleAnnounceBlocked(_in(peers: const [viaMdns, scanned])).single;
    expect(g.code, 'some-peers-silent');
    final h = ruleAnnounceBlocked(_in(peers: const [scanned])).single;
    expect(h.code, 'announce-blocked');
    expect(h.technical, contains('mDNS found nothing either'));
    final codes = diagnose(_in(peers: const [viaMdns])).map((f) => f.code);
    expect(codes, contains('mdns-only'));
    expect(codes, isNot(contains('announce-blocked')));
  });

  test('mdns-visible-unreachable: timeout vs refused wording', () {
    List<Finding> r(String why) => ruleMdnsVisibleUnreachable(_in(mdnsPeers: [
          MdnsPeerObservation('Bob', 'ab' * 32, '192.168.1.20', 53317,
              failure: why)
        ]));
    final t = r('timeout').single;
    expect(t.code, 'mdns-visible-unreachable');
    expect(t.severity, Severity.problem);
    expect(t.detail, contains('firewall'));
    expect(t.detail, contains('timeout'));
    expect(t.technical, contains('192.168.1.20:53317 timeout'));
    expect(r('refused').single.detail, contains('refused'));
    expect(r('fingerprint-mismatch').single.detail,
        contains('different security key'));
    // verified ones and peers already known are not reported
    expect(
        ruleMdnsVisibleUnreachable(_in(mdnsPeers: [
          MdnsPeerObservation('Bob', 'ab' * 32, '192.168.1.20', 53317)
        ])),
        isEmpty);
    expect(
        ruleMdnsVisibleUnreachable(_in(peers: const [
          viaMdns
        ], mdnsPeers: [
          MdnsPeerObservation('Bob', 'ab' * 32, '192.168.1.20', 1,
              failure: 'refused')
        ])),
        isEmpty);
  });

  test('udp-only-no-mdns', () {
    final f = ruleUdpOnlyNoMdns(_in(peers: const [viaUdp])).single;
    expect(f.code, 'udp-only-no-mdns');
    expect(f.severity, Severity.info);
    expect(f.detail, contains('not a problem for LanDrop'));
    expect(ruleUdpOnlyNoMdns(_in(peers: const [viaUdp], started: false)),
        isEmpty);
    expect(ruleUdpOnlyNoMdns(_in(peers: const [both])), isEmpty);
    expect(
        ruleUdpOnlyNoMdns(_in(peers: const [
          viaUdp
        ], mdnsPeers: [
          MdnsPeerObservation('X', 'cd' * 32, '192.168.1.30', 1)
        ])),
        isEmpty);
  });

  test('mdns-unavailable', () {
    final f = ruleMdnsUnavailable(
        _in(started: false, error: 'address in use')).single;
    expect(f.code, 'mdns-unavailable');
    expect(f.severity, Severity.info);
    expect(f.technical, 'address in use');
    expect(
        ruleMdnsUnavailable(_in(
                started: false, error: 'x', discoveryError: 'no socket'))
            .single
            .severity,
        Severity.warn);
    expect(ruleMdnsUnavailable(_in()), isEmpty);
    expect(ruleMdnsUnavailable(const DiagnosisInput(mdnsError: 'x')), isEmpty);
  });

  test('network summary mentions mDNS', () {
    final f = diagnose(_in(peers: const [viaMdns])).last;
    expect(f.technical, contains('mDNS: on, seen 0'));
    expect(f.technical, contains('via mdns'));
  });
}
