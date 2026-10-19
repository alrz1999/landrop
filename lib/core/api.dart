// Contract between core (lib/core/**) and UI (lib/ui/**). Do not change
// signatures without updating both sides.
import 'dart:async';

class DeviceInfo {
  final String alias;
  final String deviceType; // mobile|desktop|web|headless|server
  final String? deviceModel;
  final String fingerprint; // sha256 hex of cert DER
  final String ip;
  final int port;
  const DeviceInfo({
    required this.alias,
    required this.deviceType,
    this.deviceModel,
    required this.fingerprint,
    required this.ip,
    this.port = 53317,
  });
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
  const TransferProgress(this.sessionId, this.fileId, this.sentBytes,
      this.totalBytes,
      {this.done = false, this.error});
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

  /// Send local file paths. Returns true when receiver accepted and all uploaded.
  Future<bool> send(DeviceInfo to, List<String> paths);
}
