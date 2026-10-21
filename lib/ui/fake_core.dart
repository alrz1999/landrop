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

  @override
  Future<void> scanSubnet() async {
    await Future<void>.delayed(simulateDelay);
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
                fix: 'Check both devices are on the same Wi-Fi.'),
          const Finding(Severity.warn, 'announce-blocked',
              'Devices only show up after a scan',
              'Your router seems to block discovery messages.',
              fix: 'Use "Rescan network" or "Add by IP".'),
          const Finding(Severity.info, 'network', 'Your network',
              'Addresses this device has, for reference.',
              technical: 'en0: 192.168.1.10\nLanDrop listening on port 53317'),
        ];
  }

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
