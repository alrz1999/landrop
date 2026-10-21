import 'dart:async';
import 'dart:io';

import '../core/api.dart';

/// In-memory [LanDropCore] with fake peers and simulated transfers.
/// Used for UI development and widget tests.
class FakeCore implements LanDropCore {
  FakeCore({
    this.simulateDelay = const Duration(milliseconds: 120),
    this.initialPeers,
  });

  /// Delay between simulated progress ticks. Use [Duration.zero] in tests.
  final Duration simulateDelay;

  /// Peers emitted on start. Defaults to two fake devices.
  final List<DeviceInfo>? initialPeers;

  final _peersCtrl = StreamController<List<DeviceInfo>>.broadcast();
  final _incomingCtrl = StreamController<IncomingRequest>.broadcast();
  final _progressCtrl = StreamController<TransferProgress>.broadcast();

  final List<DeviceInfo> _peers = [];
  DeviceInfo _self = const DeviceInfo(
    alias: 'This device',
    deviceType: 'desktop',
    fingerprint: 'fake-self',
    ip: '192.168.1.10',
  );
  bool started = false;
  String? saveDir;
  int _session = 0;

  /// Every call to [send] / [sendFiles], recorded for tests.
  final List<(DeviceInfo, List<String>)> sent = [];

  /// Test hook: extra wait before a peer (by fingerprint) "accepts" a send,
  /// so concurrent sends can get their session ids out of order.
  final Map<String, Duration> acceptDelays = {};

  /// Test hook: value of [discoveryError] (null = discovery is fine).
  @override
  String? discoveryError;

  static const List<DeviceInfo> defaultPeers = [
    DeviceInfo(
      alias: 'Pixel 9',
      deviceType: 'mobile',
      deviceModel: 'Google',
      fingerprint: 'aa11',
      ip: '192.168.1.21',
    ),
    DeviceInfo(
      alias: 'Work Laptop',
      deviceType: 'desktop',
      deviceModel: 'Linux',
      fingerprint: 'bb22',
      ip: '192.168.1.34',
    ),
  ];

  @override
  Future<void> start({required String alias, required String saveDir}) async {
    started = true;
    this.saveDir = saveDir;
    _self = DeviceInfo(
      alias: alias,
      deviceType: _self.deviceType,
      fingerprint: _self.fingerprint,
      ip: _self.ip,
      port: _self.port,
    );
    _peers
      ..clear()
      ..addAll(initialPeers ?? defaultPeers);
    _emitPeers();
  }

  @override
  Future<void> stop() async {
    started = false;
  }

  @override
  DeviceInfo get self => _self;

  @override
  Stream<List<DeviceInfo>> get peers => _peersCtrl.stream;

  @override
  Stream<IncomingRequest> get incoming => _incomingCtrl.stream;

  @override
  Stream<TransferProgress> get progress => _progressCtrl.stream;

  void _emitPeers() => _peersCtrl.add(List.unmodifiable(_peers));

  /// Test hook: replace the peer list.
  void setPeers(List<DeviceInfo> peers) {
    _peers
      ..clear()
      ..addAll(peers);
    _emitPeers();
  }

  /// Test hook: push a progress event.
  void emitProgress(TransferProgress p) => _progressCtrl.add(p);

  /// Test/demo hook: simulate an incoming request. If accepted, simulated
  /// progress is emitted for each file.
  IncomingRequest simulateIncoming({
    DeviceInfo? from,
    List<FileOffer>? files,
    bool autoProgress = true,
  }) {
    final req = IncomingRequest(
      'in-${++_session}',
      from ?? defaultPeers.first,
      files ??
          const [
            FileOffer('f1', 'holiday.jpg', 2400000, 'image/jpeg'),
            FileOffer('f2', 'notes.pdf', 180000, 'application/pdf'),
          ],
    );
    _incomingCtrl.add(req);
    if (autoProgress) {
      req.decision.future.then((ok) {
        if (ok) {
          _simulate(req.sessionId,
              req.files.map((f) => (f.id, f.size, f.fileName)));
        }
      });
    }
    return req;
  }

  /// Test hook: [addPeerByIp] finds nothing (as if no device answered).
  bool addPeerFails = false;

  @override
  Future<DeviceInfo?> addPeerByIp(String ip, {int port = 53317}) async {
    if (addPeerFails) return null;
    if (!RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(ip)) return null;
    final d = DeviceInfo(
      alias: 'Device at $ip',
      deviceType: 'desktop',
      fingerprint: 'manual-$ip',
      ip: ip,
      port: port,
    );
    _peers.removeWhere((p) => p.ip == ip && p.port == port);
    _peers.add(d);
    _emitPeers();
    return d;
  }

  /// Test hook: [scanSubnet] finds "Living Room PC" (default) or nothing.
  bool scanFindsDevice = true;

  /// Number of [restartDiscovery] calls, for tests.
  int restartDiscoveryCalls = 0;

  /// Every [probeAddresses] call, for tests.
  final List<List<String>> probeCalls = [];

  /// Test hook: devices "answering" [probeAddresses], by IP.
  final Map<String, DeviceInfo> probeAnswers = {};

  /// Last [setHotspotInfo] value (ssid, gateway), for tests.
  (String?, String?) hotspotInfo = (null, null);

  @override
  Future<void> restartDiscovery() async {
    restartDiscoveryCalls++;
    await Future<void>.delayed(simulateDelay);
  }

  @override
  Future<List<DeviceInfo>> probeAddresses(List<String> ips,
      {int? port}) async {
    probeCalls.add(List.of(ips));
    await Future<void>.delayed(simulateDelay);
    final found = [
      for (final ip in ips)
        if (probeAnswers[ip] != null) probeAnswers[ip]!
    ];
    for (final d in found) {
      _peers.removeWhere((p) => p.fingerprint == d.fingerprint);
      _peers.add(d);
    }
    if (found.isNotEmpty) _emitPeers();
    return found;
  }

  @override
  void setHotspotInfo(String? ssid, {String? gateway}) =>
      hotspotInfo = (ssid, ssid == null ? null : gateway);

  @override
  Future<void> scanSubnet() async {
    await Future<void>.delayed(simulateDelay);
    if (!scanFindsDevice) return;
    if (!_peers.any((p) => p.fingerprint == 'cc33')) {
      _peers.add(const DeviceInfo(
        alias: 'Living Room PC',
        deviceType: 'desktop',
        fingerprint: 'cc33',
        ip: '192.168.1.50',
      ));
      _emitPeers();
    }
  }

  @override
  Future<bool> send(DeviceInfo to, List<String> paths) async =>
      (await sendFiles(to, [for (final p in paths) SendItem(p)])).ok;

  @override
  Future<SendResult> sendFiles(DeviceInfo to, List<SendItem> items,
      {void Function(String sessionId)? onSession}) async {
    sent.add((to, [for (final i in items) i.path]));
    final files = <(String, int, String)>[];
    for (final item in items) {
      final base = item.name ??
          item.path.split(RegExp(r'[\\/]')).lastWhere((s) => s.isNotEmpty,
              orElse: () => 'file');
      try {
        final d = Directory(item.path);
        if (d.existsSync()) {
          for (final f in d.listSync(recursive: true).whereType<File>()) {
            final rel = f.path
                .substring(d.path.length)
                .replaceAll('\\', '/')
                .replaceAll(RegExp(r'^/+'), '');
            files.add(('file${files.length}', f.lengthSync(), '$base/$rel'));
          }
          continue;
        }
      } catch (_) {}
      var size = 1000000;
      try {
        final f = File(item.path);
        if (f.existsSync()) size = f.lengthSync();
      } catch (_) {}
      files.add(('file${files.length}', size, base));
    }
    final sid = 'out-${++_session}';
    await Future<void>.delayed(acceptDelays[to.fingerprint] ?? Duration.zero);
    onSession?.call(sid);
    await _simulate(sid, files);
    return SendResult(ok: true, sessionId: sid);
  }

  /// Test hook: findings returned by [runDiagnosis] (canned when null).
  List<Finding>? diagnosisFindings;

  /// Every [runDiagnosis] call as (targetIp, targetPort), for tests.
  final List<(String?, int?)> diagnosisCalls = [];

  @override
  Future<List<Finding>> runDiagnosis({String? targetIp, int? targetPort}) async {
    diagnosisCalls.add((targetIp, targetPort));
    await Future<void>.delayed(simulateDelay);
    return diagnosisFindings ??
        [
          if (targetIp != null)
            Finding(Severity.problem, 'probe-timeout',
                'No answer from that address',
                'Nothing came back from $targetIp.',
                fix: 'Check both devices are on the same Wi-Fi.',
                action: hotspotWizardAction),
          const Finding(Severity.warn, 'announce-blocked',
              'Devices only show up after a scan',
              'Your router seems to block discovery messages.',
              fix: 'Use "Rescan network" or "Add by IP".',
              action: hotspotWizardAction),
          const Finding(Severity.info, 'network', 'Your network',
              'Addresses this device has, for reference.',
              technical: 'en0: 192.168.1.10\nLanDrop listening on port 53317'),
        ];
  }

  // ------------------------------------------------------ browser access

  final _pairingCtrl = StreamController<WebPairingRequest>.broadcast();
  final _sharesCtrl = StreamController<List<Share>>.broadcast();
  final List<Share> _shares = [];
  int _shareSeq = 0;
  int _pairSeq = 0;
  bool _webHttp = false;

  /// Every [createShare] call as (paths, ttl, maxDownloads), for tests.
  final List<(List<String>, Duration?, int?)> shareCalls = [];

  /// Test hook: a browser asks to pair.
  WebPairingRequest simulatePairing(
      {String code = '4821',
      String userAgent = 'Safari on iPhone',
      String ip = '192.168.1.77'}) {
    final r = WebPairingRequest('pair-${++_pairSeq}', code, userAgent, ip);
    _pairingCtrl.add(r);
    return r;
  }

  /// Test hook: a browser downloaded from share [id] once.
  void simulateDownload(String id) {
    final i = _shares.indexWhere((s) => s.id == id);
    if (i < 0) return;
    final s = _shares[i];
    if (s.downloadsLeft == null) return;
    _shares[i] = _copyShare(s, downloadsLeft: s.downloadsLeft! - 1);
    _sharesCtrl.add(shares);
  }

  Share _copyShare(Share s, {int? downloadsLeft}) => Share(
        id: s.id,
        token: s.token,
        files: s.files,
        url: _shareUrl(s.token),
        httpUrl: _webHttp ? _shareUrl(s.token, http: true) : null,
        createdAt: s.createdAt,
        expiresAt: s.expiresAt,
        maxDownloads: s.maxDownloads,
        downloadsLeft: downloadsLeft ?? s.downloadsLeft,
      );

  String _shareUrl(String token, {bool http = false}) => http
      ? 'http://${_self.ip}:53320/#s=$token'
      : 'https://${_self.ip}:${_self.port}/#s=$token';

  @override
  Stream<WebPairingRequest> get webPairing => _pairingCtrl.stream;

  @override
  List<Share> get shares => List.unmodifiable(_shares.where((s) => !s.expired));

  @override
  Stream<List<Share>> get sharesChanged => _sharesCtrl.stream;

  @override
  Share createShare(List<String> paths, {Duration? ttl, int? maxDownloads}) {
    shareCalls.add((paths, ttl, maxDownloads));
    if (paths.isEmpty) throw ArgumentError('nothing to share');
    final token = 'tok${++_shareSeq}abcdefghijklmnop';
    final s = Share(
      id: 'share-$_shareSeq',
      token: token,
      files: [
        for (final (i, p) in paths.indexed)
          SharedFile(
              'f$i',
              p.split(RegExp(r'[\\/]')).lastWhere((x) => x.isNotEmpty,
                  orElse: () => 'file'),
              1000000,
              'application/octet-stream'),
      ],
      url: _shareUrl(token),
      httpUrl: _webHttp ? _shareUrl(token, http: true) : null,
      createdAt: DateTime.now(),
      expiresAt: ttl == null ? null : DateTime.now().add(ttl),
      maxDownloads: maxDownloads,
      downloadsLeft: maxDownloads,
    );
    _shares.add(s);
    _sharesCtrl.add(shares);
    return s;
  }

  @override
  void revokeShare(String id) {
    _shares.removeWhere((s) => s.id == id);
    _sharesCtrl.add(shares);
  }

  @override
  bool sharesPersistence = true;

  @override
  void setSharesPersistence(bool enabled) => sharesPersistence = enabled;

  final _sessionsCtrl = StreamController<List<WebSessionInfo>>.broadcast();
  final List<WebSessionInfo> _webSessions = [];
  int _webSessionSeq = 0;

  /// Every [revokeWebSession] call, for tests.
  final List<String> revokedWebSessions = [];

  /// Test hook: a browser finished pairing.
  WebSessionInfo simulateWebSession(
      {String userAgent = 'Safari on iPhone', String ip = '192.168.1.77'}) {
    final now = DateTime.now();
    final s = WebSessionInfo(
        id: 'web-${++_webSessionSeq}',
        remoteIp: ip,
        userAgent: userAgent,
        pairedAt: now,
        lastSeen: now);
    _webSessions.add(s);
    _sessionsCtrl.add(webSessions);
    return s;
  }

  @override
  List<WebSessionInfo> get webSessions => List.unmodifiable(_webSessions);

  @override
  Stream<List<WebSessionInfo>> get webSessionsChanged => _sessionsCtrl.stream;

  @override
  void revokeWebSession(String id) {
    revokedWebSessions.add(id);
    _webSessions.removeWhere((s) => s.id == id);
    _sessionsCtrl.add(webSessions);
  }

  @override
  String? get webUrl => started ? 'https://${_self.ip}:${_self.port}/' : null;

  @override
  bool get webHttpEnabled => _webHttp;

  @override
  Future<void> setWebHttpEnabled(bool enabled) async {
    _webHttp = enabled;
    for (var i = 0; i < _shares.length; i++) {
      _shares[i] = _copyShare(_shares[i]);
    }
    _sharesCtrl.add(shares);
  }

  @override
  int? get webHttpPort => _webHttp && started ? 53320 : null;

  @override
  String? get webHttpUrl =>
      _webHttp && started ? 'http://${_self.ip}:53320/' : null;

  Future<void> _simulate(
      String sid, Iterable<(String, int, String?)> files) async {
    for (final (id, size, name) in files) {
      for (var step = 1; step <= 4; step++) {
        await Future<void>.delayed(simulateDelay);
        _progressCtrl.add(TransferProgress(
          sid,
          id,
          size * step ~/ 4,
          size,
          done: step == 4,
          fileName: name,
        ));
      }
    }
  }
}
