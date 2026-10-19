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

  /// Every call to [send], recorded for tests.
  final List<(DeviceInfo, List<String>)> sent = [];

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
        if (ok) _simulate(req.sessionId, req.files.map((f) => (f.id, f.size)));
      });
    }
    return req;
  }

  @override
  Future<DeviceInfo?> addPeerByIp(String ip, {int port = 53317}) async {
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
  Future<bool> send(DeviceInfo to, List<String> paths) async {
    sent.add((to, paths));
    final files = <(String, int)>[];
    for (var i = 0; i < paths.length; i++) {
      var size = 1000000;
      try {
        final f = File(paths[i]);
        if (f.existsSync()) size = f.lengthSync();
      } catch (_) {}
      files.add(('file$i', size));
    }
    await _simulate('out-${++_session}', files);
    return true;
  }

  Future<void> _simulate(String sid, Iterable<(String, int)> files) async {
    for (final (id, size) in files) {
      for (var step = 1; step <= 4; step++) {
        await Future<void>.delayed(simulateDelay);
        _progressCtrl.add(TransferProgress(
          sid,
          id,
          size * step ~/ 4,
          size,
          done: step == 4,
        ));
      }
    }
  }
}
