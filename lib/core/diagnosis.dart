// Guided diagnosis (DESIGN.md 3.7): pure rules over what the core observed.
// No I/O and no Flutter, so every rule is unit-testable with plain data.
import 'util.dart' show isLinkLocalIPv4, isVirtualInterface, isVpnInterface;

enum Severity { info, warn, problem }

/// [Finding.action] that opens the hotspot wizard ("Connect without Wi-Fi").
const hotspotWizardAction = 'hotspot-wizard';

/// [Finding.action] that opens the cable wizard ("Connect with a cable").
const cableWizardAction = 'cable-wizard';

class Finding {
  final Severity severity;

  /// Stable machine code, e.g. `probe-refused` (used by tests and reports).
  final String code;

  /// Short, plain-language headline.
  final String title;

  /// What it means, in plain words.
  final String detail;

  /// What to do about it ('' when nothing needs doing).
  final String fix;

  /// Optional technical detail, shown second (error text, addresses).
  final String? technical;

  /// Optional UI action that helps with this finding, e.g.
  /// [hotspotWizardAction]. The UI shows a button for actions it knows.
  final String? action;

  const Finding(this.severity, this.code, this.title, this.detail,
      {this.fix = '', this.technical, this.action});

  @override
  String toString() => '${severity.name}:$code';
}

class InterfaceObservation {
  final String name;
  final List<String> addresses; // IPv4, dotted
  const InterfaceObservation(this.name, this.addresses);
  bool get isVpn => isVpnInterface(name);

  /// Docker/VM bridge, AWDL and similar: never counts as a network.
  bool get isVirtual => isVirtualInterface(name);
}

enum TcpOutcome { connected, refused, timeout, unreachable }

class ProbeObservation {
  final String ip;
  final int port;
  final TcpOutcome tcp;

  /// TLS handshake and GET /info worked (null when not tried).
  final bool? infoOk;

  /// The certificate presented differs from the one pinned for this address,
  /// or from the fingerprint the device claims in its info.
  final bool fingerprintMismatch;
  final String? expectedFingerprint;
  final String? presentedFingerprint;

  /// Alias reported by /info, when it worked.
  final String? alias;
  final String? error;

  const ProbeObservation({
    required this.ip,
    required this.port,
    required this.tcp,
    this.infoOk,
    this.fingerprintMismatch = false,
    this.expectedFingerprint,
    this.presentedFingerprint,
    this.alias,
    this.error,
  });

  bool get ok => tcp == TcpOutcome.connected && infoOk == true &&
      !fingerprintMismatch;
}

/// Ways a peer can be found (DeviceInfo.foundVia).
const autoDiscoveryVias = {'multicast', 'broadcast', 'announce', 'register'};

class PeerObservation {
  final String alias;
  final String ip;
  final Set<String> foundVia;
  const PeerObservation(this.alias, this.ip, this.foundVia);
  bool get foundAutomatically => foundVia.any(autoDiscoveryVias.contains);
}

class DiagnosisInput {
  /// Why UDP discovery could not start (null when it runs or is disabled).
  final String? discoveryError;

  /// UDP discovery is configured at all (false: announce rules are skipped).
  final bool discoveryEnabled;
  final List<InterfaceObservation> interfaces;
  final bool serverListening;
  final int? serverPort;
  final List<PeerObservation> peers;
  final ProbeObservation? probe;

  const DiagnosisInput({
    this.discoveryError,
    this.discoveryEnabled = true,
    this.interfaces = const [],
    this.serverListening = true,
    this.serverPort,
    this.peers = const [],
    this.probe,
  });
}

typedef DiagnosisRule = List<Finding> Function(DiagnosisInput input);

// ------------------------------------------------------------------ helpers

List<int>? _octets(String ip) {
  final p = ip.split('.');
  if (p.length != 4) return null;
  final o = p.map(int.tryParse).toList();
  if (o.any((x) => x == null || x < 0 || x > 255)) return null;
  return o.cast<int>();
}

bool isPrivateIPv4(String ip) {
  final b = _octets(ip);
  if (b == null) return false;
  return b[0] == 10 ||
      (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
      (b[0] == 192 && b[1] == 168);
}

String? _slash24(String ip) {
  final b = _octets(ip);
  return b == null ? null : '${b[0]}.${b[1]}.${b[2]}';
}

/// Private IPv4 addresses on real (non-VPN, non-virtual) interfaces.
List<String> lanAddresses(DiagnosisInput i) => [
      for (final f in i.interfaces)
        if (!f.isVpn && !f.isVirtual)
          for (final a in f.addresses)
            if (isPrivateIPv4(a)) a
    ];

/// 169.254.x.x addresses on real interfaces (direct cable, no DHCP).
List<String> linkLocalAddresses(DiagnosisInput i) => [
      for (final f in i.interfaces)
        if (!f.isVpn && !f.isVirtual)
          for (final a in f.addresses)
            if (isLinkLocalIPv4(a)) a
    ];

String shortFp(String? fp) {
  if (fp == null || fp.isEmpty) return '?';
  if (fp.length <= 16) return fp.toUpperCase();
  return '${fp.substring(0, 8)}…${fp.substring(fp.length - 8)}'.toUpperCase();
}

// ------------------------------------------------------------------ rules

List<Finding> ruleServerNotListening(DiagnosisInput i) => i.serverListening
    ? const []
    : [
        Finding(Severity.problem, 'server-down',
            'This device cannot receive files right now',
            'LanDrop on this device is not accepting connections, so other '
                'devices cannot see it or send to it.',
            fix: 'Use "Restart service" in Settings, or close and reopen '
                'LanDrop.',
            technical: i.serverPort == null
                ? 'HTTPS server not running'
                : 'HTTPS server not answering on port ${i.serverPort}'),
      ];

List<Finding> ruleDiscoveryFailed(DiagnosisInput i) => i.discoveryError == null
    ? const []
    : [
        Finding(Severity.problem, 'discovery-failed',
            'Automatic discovery is off',
            'LanDrop could not start looking for nearby devices, so they will '
                'not appear on their own. Sending by IP still works.',
            fix: 'Use "Rescan network" or "Add by IP". Restarting LanDrop or '
                'allowing local network access may fix it.',
            technical: i.discoveryError),
      ];

List<Finding> ruleNoLan(DiagnosisInput i) =>
    lanAddresses(i).isNotEmpty || linkLocalAddresses(i).isNotEmpty
    ? const []
    : [
        Finding(Severity.problem, 'no-lan', 'Not connected to Wi-Fi or a LAN',
            'This device has no local network address, so it cannot reach '
                'other devices nearby.',
            fix: 'Connect to the same Wi-Fi as the other device, plug in an '
                'Ethernet cable, or turn on a hotspot on one device and join '
                'it from the other.',
            technical: i.interfaces.isEmpty
                ? 'no IPv4 interfaces'
                : 'no private IPv4 on a non-VPN interface',
            action: hotspotWizardAction),
      ];

/// Only 169.254.x.x addresses: a direct cable between two computers, or a
/// network without DHCP. Works, but both ends must be connected to each other.
List<Finding> ruleLinkLocalOnly(DiagnosisInput i) {
  if (lanAddresses(i).isNotEmpty) return const [];
  final ll = linkLocalAddresses(i);
  if (ll.isEmpty) return const [];
  return [
    Finding(Severity.info, 'link-local-only', 'Direct cable or no DHCP',
        'This looks like a direct cable or a network without DHCP. LanDrop '
            'works, but both devices must be connected to each other; give '
            'both devices a moment to get addresses.',
        technical: ll.join(', '),
        action: cableWizardAction),
  ];
}

List<Finding> ruleVpnActive(DiagnosisInput i) {
  final vpns = [
    for (final f in i.interfaces)
      if (f.isVpn && f.addresses.isNotEmpty) f
  ];
  if (vpns.isEmpty) return const [];
  return [
    Finding(Severity.warn, 'vpn-active', 'A VPN is on',
        'VPNs often hide the local network, so nearby devices cannot reach '
            'each other.',
        fix: 'Turn the VPN off, or allow "local network access" in its '
            'settings, then try again.',
        technical: vpns
            .map((f) => '${f.name} ${f.addresses.join(', ')}')
            .join('; ')),
  ];
}

List<Finding> ruleAnnounceBlocked(DiagnosisInput i) {
  if (!i.discoveryEnabled || i.discoveryError != null || i.peers.isEmpty) {
    return const [];
  }
  final silent = i.peers.where((p) => !p.foundAutomatically).toList();
  if (silent.isEmpty) return const [];
  final names = silent.map((p) => '${p.alias} (${p.ip})').join(', ');
  if (silent.length == i.peers.length) {
    return [
      Finding(Severity.warn, 'announce-blocked',
          'Devices only show up after a scan',
          'Your router seems to block the messages devices use to find each '
              'other (multicast and broadcast). Transfers still work by IP.',
          fix: 'Use "Rescan network" or "Add by IP". To fix it for good, turn '
              'on multicast / turn off "AP isolation" in the router.',
          technical: 'found only by scan/manual: $names',
          action: hotspotWizardAction),
    ];
  }
  return [
    Finding(Severity.info, 'some-peers-silent',
        'Some devices did not announce themselves',
        'Other devices were found automatically, but these only by scan or '
            'IP. They may be on another part of the network or have '
            'discovery turned off.',
        technical: 'found only by scan/manual: $names'),
  ];
}

List<Finding> ruleProbeRefused(DiagnosisInput i) {
  final p = i.probe;
  if (p == null || p.tcp != TcpOutcome.refused) return const [];
  return [
    Finding(Severity.problem, 'probe-refused',
        'The device is there, but LanDrop is not answering',
        'The other device answered, but nothing accepted the connection. '
            'LanDrop is probably closed there, or it uses a different port.',
        fix: 'Open LanDrop on the other device and keep it in front. Check '
            'the address and port shown on its screen.',
        technical: 'TCP connect to ${p.ip}:${p.port} refused'),
  ];
}

List<Finding> ruleProbeTimeout(DiagnosisInput i) {
  final p = i.probe;
  if (p == null || p.tcp != TcpOutcome.timeout) return const [];
  return [
    Finding(Severity.problem, 'probe-timeout', 'No answer from that address',
        'Nothing came back. A firewall, "AP / client isolation" on the router, '
            'or being on a different network can cause this.',
        fix: 'Check both devices are on the same Wi-Fi (not a guest network). '
            'Allow LanDrop in the firewall. If it still fails, turn on a '
            'hotspot on one device and join it from the other.',
        technical: 'TCP connect to ${p.ip}:${p.port} timed out'
            '${p.error == null ? '' : ' (${p.error})'}',
        action: hotspotWizardAction),
  ];
}

List<Finding> ruleProbeUnreachable(DiagnosisInput i) {
  final p = i.probe;
  if (p == null || p.tcp != TcpOutcome.unreachable) return const [];
  return [
    Finding(Severity.problem, 'probe-unreachable',
        'That address cannot be reached from here',
        'This device has no way to reach that address. It is probably on a '
            'different network, or the address is wrong.',
        fix: 'Check the address on the other device, and connect both to the '
            'same Wi-Fi or hotspot.',
        technical: 'TCP connect to ${p.ip}:${p.port} failed'
            '${p.error == null ? '' : ': ${p.error}'}'),
  ];
}

List<Finding> ruleProbeFingerprintMismatch(DiagnosisInput i) {
  final p = i.probe;
  if (p == null || !p.fingerprintMismatch) return const [];
  return [
    Finding(Severity.problem, 'probe-fingerprint-mismatch',
        'A different device is at this address',
        'The device at this address is not the one LanDrop knew before. '
            'Either another device took the address, or LanDrop was '
            'reinstalled there and made a new security key.',
        fix: 'Check the fingerprint shown in Settings on the other device. '
            'If it is right, remove and add the device again.',
        technical: 'expected ${shortFp(p.expectedFingerprint)}, got '
            '${shortFp(p.presentedFingerprint)}'),
  ];
}

List<Finding> ruleProbeNotLanDrop(DiagnosisInput i) {
  final p = i.probe;
  if (p == null ||
      p.tcp != TcpOutcome.connected ||
      p.infoOk != false ||
      p.fingerprintMismatch) {
    return const [];
  }
  return [
    Finding(Severity.warn, 'probe-not-landrop',
        'Something answered, but it is not LanDrop',
        'A program accepted the connection on that port, but it did not '
            'respond like LanDrop or LocalSend.',
        fix: 'Check the port shown in LanDrop on the other device.',
        technical: '${p.ip}:${p.port} connected; TLS or /info failed'
            '${p.error == null ? '' : ': ${p.error}'}'),
  ];
}

List<Finding> ruleProbeOk(DiagnosisInput i) {
  final p = i.probe;
  if (p == null || !p.ok) return const [];
  return [
    Finding(Severity.info, 'probe-ok', 'The device answers',
        '${p.alias ?? 'LanDrop'} at this address is reachable and working.',
        technical: '${p.ip}:${p.port} fingerprint '
            '${shortFp(p.presentedFingerprint)}'),
  ];
}

List<Finding> ruleDifferentSubnet(DiagnosisInput i) {
  final p = i.probe;
  if (p == null || p.ok || !isPrivateIPv4(p.ip)) return const [];
  final own = lanAddresses(i);
  if (own.isEmpty) return const []; // ruleNoLan covers it
  final target = _slash24(p.ip);
  if (own.any((a) => _slash24(a) == target)) return const [];
  return [
    Finding(Severity.warn, 'different-subnet',
        'The devices seem to be on different networks',
        'The addresses do not match, so the devices may be on different '
            'Wi-Fi networks, or one is on a guest network.',
        fix: 'Connect both devices to the same Wi-Fi (not a guest network).',
        technical: 'this device ${own.join(', ')} vs target ${p.ip} '
            '(compared as /24)',
        action: hotspotWizardAction),
  ];
}

/// Nothing found at all, though this device is on a LAN and listening: the
/// most common cause is a network that keeps devices apart, which a hotspot
/// gets around. Only without a probe (a probe has its own findings).
List<Finding> ruleHotspotLikelyFix(DiagnosisInput i) {
  if (!i.serverListening ||
      i.probe != null ||
      i.peers.isNotEmpty ||
      lanAddresses(i).isEmpty) {
    return const [];
  }
  return const [
    Finding(Severity.info, 'hotspot-likely-fix', 'No other device found yet',
        'If LanDrop is open on the other device and it still does not show '
        'up, this network probably keeps devices apart (common on guest, '
        'office, school and hotel Wi-Fi). Connecting both devices through a '
        'hotspot from a phone or laptop usually fixes it, and needs no '
        'router.',
        fix: 'Tap "Connect with a hotspot" for step-by-step help, or use '
            '"Add by IP" if you know the other device\'s address.',
        action: hotspotWizardAction),
  ];
}

/// All rules, in display order within a severity.
const List<DiagnosisRule> diagnosisRules = [
  ruleServerNotListening,
  ruleDiscoveryFailed,
  ruleNoLan,
  ruleLinkLocalOnly,
  ruleVpnActive,
  ruleProbeRefused,
  ruleProbeTimeout,
  ruleProbeUnreachable,
  ruleProbeFingerprintMismatch,
  ruleProbeNotLanDrop,
  ruleDifferentSubnet,
  ruleAnnounceBlocked,
  ruleHotspotLikelyFix,
  ruleProbeOk,
];

/// Findings for [input]: problems first, then warnings, then info. Ends with
/// 'all-good' when nothing is wrong and a 'network' summary of interfaces.
List<Finding> diagnose(DiagnosisInput input) {
  final out = [for (final r in diagnosisRules) ...r(input)];
  if (!out.any((f) =>
      f.severity != Severity.info ||
      f.code == 'hotspot-likely-fix' ||
      f.code == 'link-local-only')) {
    out.add(const Finding(Severity.info, 'all-good', 'No problems found',
        'This device is on a local network and ready to send and receive.',
        fix: 'If a device is still missing, make sure LanDrop is open on it, '
            'then use "Rescan network" or "Add by IP".'));
  }
  // Stable sort: by severity (problem first), rule order otherwise.
  final indexed = out.asMap().entries.toList()
    ..sort((a, b) {
      final s = b.value.severity.index - a.value.severity.index;
      return s != 0 ? s : a.key - b.key;
    });
  return [
    for (final e in indexed) e.value,
    networkSummary(input),
  ];
}

Finding networkSummary(DiagnosisInput i) {
  final lines = [
    for (final f in i.interfaces)
      '${f.name}${f.isVpn ? ' (VPN)' : f.isVirtual ? ' (virtual)' : ''}: '
          '${f.addresses.isEmpty ? '-' : f.addresses.join(', ')}',
    if (i.interfaces.isEmpty) 'no network interfaces',
    i.serverListening
        ? 'LanDrop listening on port ${i.serverPort ?? '?'}'
        : 'LanDrop not listening',
    'automatic discovery: ${!i.discoveryEnabled ? 'disabled' : i.discoveryError == null ? 'on' : 'failed'}',
    'devices found: ${i.peers.length}',
    for (final p in i.peers)
      '  ${p.alias} ${p.ip} via ${(p.foundVia.toList()..sort()).join('+')}',
  ];
  return Finding(Severity.info, 'network', 'Your network',
      'Addresses this device has, for reference.',
      technical: lines.join('\n'));
}

/// Plain-text report (for "Copy report"). Contains no tokens or secrets;
/// fingerprints in findings are already shortened.
String formatDiagnosisReport(List<Finding> findings,
    {DateTime? at, String? target}) {
  final sb = StringBuffer('LanDrop connection report');
  if (at != null) sb.write(' (${at.toIso8601String()})');
  sb.writeln();
  if (target != null) sb.writeln('Checked address: $target');
  for (final f in findings) {
    sb.writeln();
    sb.writeln('[${f.severity.name.toUpperCase()}] ${f.title}');
    if (f.detail.isNotEmpty) sb.writeln(f.detail);
    if (f.fix.isNotEmpty) sb.writeln('Fix: ${f.fix}');
    if (f.technical != null && f.technical!.isNotEmpty) {
      sb.writeln('Details: ${f.technical}');
    }
  }
  return sb.toString();
}
