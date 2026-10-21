// Contract between core (lib/core/**) and UI (lib/ui/**). Do not change
// signatures without updating both sides.
import 'dart:async';

import 'diagnosis.dart';

export 'diagnosis.dart' show Finding, Severity, formatDiagnosisReport;

/// One way to reach a device, from its capability record (DESIGN.md 3.3).
class TransportCapability {
  final String id; // e.g. lan-https
  final List<String> addrs;
  final int? port;
  const TransportCapability(this.id, {this.addrs = const [], this.port});

  Map<String, dynamic> toJson() =>
      {'id': id, 'addrs': addrs, 'port': ?port};
}

/// The `landrop` field of a peer's info response (LanDrop peers only).
class PeerCapabilities {
  final int version;
  final List<TransportCapability> transports;
  final Set<String> features;
  const PeerCapabilities(
      {this.version = 1, this.transports = const [], this.features = const {}});

  Map<String, dynamic> toJson() => {
        'v': version,
        'transports': [for (final t in transports) t.toJson()],
        'features': features.toList(),
      };

  /// Tolerant parser: unknown or malformed parts are skipped. Null when [j]
  /// is not a capability record.
  static PeerCapabilities? fromJson(Object? j) {
    if (j is! Map) return null;
    final v = j['v'];
    final ts = <TransportCapability>[];
    final rawTs = j['transports'];
    if (rawTs is List) {
      for (final t in rawTs) {
        if (t is! Map || t['id'] is! String) continue;
        final addrs = t['addrs'];
        final port = t['port'];
        ts.add(TransportCapability(t['id'] as String,
            addrs: addrs is List ? addrs.whereType<String>().toList() : const [],
            port: port is int ? port : null));
      }
    }
    final f = j['features'];
    return PeerCapabilities(
      version: v is int ? v : 1,
      transports: ts,
      features: f is List ? f.whereType<String>().toSet() : const {},
    );
  }
}

class DeviceInfo {
  final String alias;
  final String deviceType; // mobile|desktop|web|headless|server
  final String? deviceModel;
  final String fingerprint; // sha256 hex of cert DER
  final String ip;
  final int port;

  /// Capability record from the peer's info (null for non-LanDrop peers).
  final PeerCapabilities? capabilities;

  /// How this peer was found: multicast, broadcast, announce (UDP, kind
  /// unknown), register, scan, manual. Empty for [LanDropCore.self].
  final Set<String> foundVia;
  const DeviceInfo({
    required this.alias,
    required this.deviceType,
    this.deviceModel,
    required this.fingerprint,
    required this.ip,
    this.port = 53317,
    this.capabilities,
    this.foundVia = const {},
  });

  DeviceInfo copyWith(
          {PeerCapabilities? capabilities, Set<String>? foundVia}) =>
      DeviceInfo(
        alias: alias,
        deviceType: deviceType,
        deviceModel: deviceModel,
        fingerprint: fingerprint,
        ip: ip,
        port: port,
        capabilities: capabilities ?? this.capabilities,
        foundVia: foundVia ?? this.foundVia,
      );
}

class FileOffer {
  final String id;
  final String fileName;
  final int size;
  final String fileType; // mime
  const FileOffer(this.id, this.fileName, this.size, this.fileType);
}

class IncomingRequest {
  final String sessionId;
  final DeviceInfo sender;
  final List<FileOffer> files;
  final Completer<bool> decision = Completer<bool>(); // UI completes true/false
  IncomingRequest(this.sessionId, this.sender, this.files);
}

class TransferProgress {
  final String sessionId;
  final String fileId;
  final int sentBytes;
  final int totalBytes;
  final bool done;
  final String? error;

  /// Name (relative path with '/' for folder transfers) of the file, when
  /// known. Lets the UI label a file without matching on sizes.
  final String? fileName;
  const TransferProgress(this.sessionId, this.fileId, this.sentBytes,
      this.totalBytes,
      {this.done = false, this.error, this.fileName});
}

/// Something to send: a file, or a directory (sent recursively, keeping
/// relative paths under the directory's name).
class SendItem {
  final String path;

  /// Name to use on the receiver instead of the base name of [path]. For a
  /// directory this is the top-level folder name.
  final String? name;
  const SendItem(this.path, {this.name});
}

class SendResult {
  /// True when the receiver accepted and every file was uploaded.
  final bool ok;

  /// Session id assigned by the receiver (null if it never accepted).
  final String? sessionId;
  final String? error;
  const SendResult({required this.ok, this.sessionId, this.error});
}

abstract class LanDropCore {
  /// Start HTTPS server, multicast discovery. Received files go to [saveDir].
  Future<void> start({required String alias, required String saveDir});
  Future<void> stop();

  DeviceInfo get self;

  /// Live list of peers (emits full list on every change).
  Stream<List<DeviceInfo>> get peers;

  /// Incoming transfer requests awaiting accept/decline.
  Stream<IncomingRequest> get incoming;

  /// Progress for both directions.
  Stream<TransferProgress> get progress;

  /// Probe a manually entered IP and add it to peers.
  Future<DeviceInfo?> addPeerByIp(String ip, {int port = 53317});

  /// Re-scan /24 subnet (fallback when multicast is blocked).
  Future<void> scanSubnet();

  /// Why automatic (UDP) discovery could not start, or null when it runs (or
  /// is disabled). Rescan and manual IP still work when this is set.
  String? get discoveryError;

  /// Send local file paths. Returns true when receiver accepted and all uploaded.
  /// Thin wrapper around [sendFiles].
  Future<bool> send(DeviceInfo to, List<String> paths);

  /// Send files and/or directories. [onSession] is called with the session id
  /// as soon as the receiver accepts, before any progress for that session is
  /// emitted, so callers can attribute [progress] events by session id.
  Future<SendResult> sendFiles(DeviceInfo to, List<SendItem> items,
      {void Function(String sessionId)? onSession});

  /// Guided diagnosis (DESIGN.md 3.7): gathers what this device observes
  /// and, when [targetIp] is given, probes that address (TCP, then TLS +
  /// info). [targetPort] defaults to the known peer's port, else 53317.
  Future<List<Finding>> runDiagnosis({String? targetIp, int? targetPort});
}
