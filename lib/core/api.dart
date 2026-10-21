// Contract between core (lib/core/**) and UI (lib/ui/**). Do not change
// signatures without updating both sides.
import 'dart:async';

import 'diagnosis.dart';

export 'diagnosis.dart'
    show
        Finding,
        Severity,
        formatDiagnosisReport,
        hotspotWizardAction,
        cableWizardAction;

/// One way to reach a device, from its capability record (DESIGN.md 3.3).
class TransportCapability {
  final String id; // e.g. lan-https, hotspot
  final List<String> addrs;
  final int? port;

  /// `hotspot` entry only: the network this device is sharing right now and
  /// its own address on it (never the password).
  final String? ssid;
  final String? gateway;
  const TransportCapability(this.id,
      {this.addrs = const [], this.port, this.ssid, this.gateway});

  Map<String, dynamic> toJson() => {
        'id': id,
        if (addrs.isNotEmpty) 'addrs': addrs,
        'port': ?port,
        'ssid': ?ssid,
        'gateway': ?gateway,
      };
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
        final ssid = t['ssid'];
        final gateway = t['gateway'];
        ts.add(TransportCapability(t['id'] as String,
            addrs: addrs is List ? addrs.whereType<String>().toList() : const [],
            port: port is int ? port : null,
            ssid: ssid is String ? ssid : null,
            gateway: gateway is String ? gateway : null));
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

  /// Every address this peer was verified at (same fingerprint), [ip] first,
  /// e.g. its Wi-Fi and its hotspot interface. The real core always fills
  /// it; empty means only [ip] is known.
  final List<String> addresses;
  const DeviceInfo({
    required this.alias,
    required this.deviceType,
    this.deviceModel,
    required this.fingerprint,
    required this.ip,
    this.port = 53317,
    this.capabilities,
    this.foundVia = const {},
    this.addresses = const [],
  });

  DeviceInfo copyWith(
          {String? ip,
          PeerCapabilities? capabilities,
          Set<String>? foundVia,
          List<String>? addresses}) =>
      DeviceInfo(
        alias: alias,
        deviceType: deviceType,
        deviceModel: deviceModel,
        fingerprint: fingerprint,
        ip: ip ?? this.ip,
        port: port,
        capabilities: capabilities ?? this.capabilities,
        foundVia: foundVia ?? this.foundVia,
        addresses: addresses ?? this.addresses,
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

  /// English technical reason (logs, reports); null when [ok].
  final String? error;

  /// Stable reason for the UI to show a localized message; null when [ok].
  final SendErrorCode? errorCode;
  const SendResult(
      {required this.ok, this.sessionId, this.error, this.errorCode});
}

/// Why a send failed, stable across versions (see [SendResult.errorCode]).
enum SendErrorCode {
  /// The receiver declined the request.
  declined,

  /// The receiver is busy with another transfer.
  busy,

  /// The receiver could not be reached (connection failed).
  unreachable,

  /// The transfer was cancelled (by either side) or the session ended.
  cancelled,

  /// The receiver stopped answering (decision wait or upload stalled).
  timeout,

  /// The receiver presented a different certificate than expected.
  fingerprintMismatch,

  /// A file could not be read here or written on the receiver.
  diskError,

  /// Anything else.
  unknown,
}

/// A browser asking to be allowed to send files (DESIGN.md 4.5). The page
/// shows the same [code]; the owner completes [decision] with true (approve)
/// or false (decline). The core completes it with false on timeout.
class WebPairingRequest {
  final String id;
  final String code; // 4 digits
  final String userAgent; // short summary, e.g. "Chrome on Android"
  final String remoteIp;
  final Completer<bool> decision = Completer<bool>();
  WebPairingRequest(this.id, this.code, this.userAgent, this.remoteIp);
}

/// A paired browser (DESIGN.md 4.5), as shown under "Connected browsers".
class WebSessionInfo {
  /// Opaque id for [LanDropCore.revokeWebSession] (not the session token).
  final String id;
  final String remoteIp;
  final String userAgent; // short summary, e.g. "Chrome on Android"
  final DateTime pairedAt;

  /// Last request made with this session.
  final DateTime lastSeen;
  const WebSessionInfo({
    required this.id,
    required this.remoteIp,
    required this.userAgent,
    required this.pairedAt,
    required this.lastSeen,
  });
}

/// One file of a [Share]. [id] is opaque (never a path).
class SharedFile {
  final String id;

  /// Base name, or a relative path with '/' for files from a shared folder.
  final String name;
  final int size;
  final String mime;
  const SharedFile(this.id, this.name, this.size, this.mime);
}

/// Files the owner offers to browsers through an unguessable link.
class Share {
  final String id;

  /// 128-bit random, URL-safe. The only credential for the share.
  final String token;
  final List<SharedFile> files;

  /// Null: until the owner stops it.
  final DateTime? expiresAt;

  /// Null: unlimited.
  final int? maxDownloads;
  final int? downloadsLeft;

  /// `https://<ip>:<port>/#s=<token>` (token in the fragment, so it is never
  /// sent in a request line or a Referer).
  final String url;

  /// Same link on the plain HTTP listener, when that is on.
  final String? httpUrl;
  final DateTime createdAt;

  const Share({
    required this.id,
    required this.token,
    required this.files,
    required this.url,
    required this.createdAt,
    this.expiresAt,
    this.maxDownloads,
    this.downloadsLeft,
    this.httpUrl,
  });

  int get totalBytes => files.fold(0, (a, f) => a + f.size);
  bool get expired =>
      expiresAt != null && !DateTime.now().isBefore(expiresAt!);
  bool get exhausted => downloadsLeft != null && downloadsLeft! <= 0;
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

  /// Re-reads the network interfaces (e.g. after joining or starting a
  /// hotspot), restarts UDP discovery on them (rebind, rejoin multicast)
  /// and announces at once. Updates [self] and the capability record.
  Future<void> restartDiscovery();

  /// Probes each of [ips] (on [port], else 53317 and the configured port)
  /// with a verified info request, adds what answers to [peers] and returns
  /// it. Used by the hotspot wizard for likely gateway addresses.
  Future<List<DeviceInfo>> probeAddresses(List<String> ips, {int? port});

  /// Advertises that this device shares a hotspot (`hotspot` entry in the
  /// capability record). [ssid] null: no hotspot.
  void setHotspotInfo(String? ssid, {String? gateway});

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

  // ------------------------------------------------ browser access (DESIGN 4)

  /// Browsers asking to be paired (allowed to send files).
  Stream<WebPairingRequest> get webPairing;

  /// Active shares (expired ones are left out).
  List<Share> get shares;

  /// Emits [shares] whenever a share is created, used, revoked or expires.
  Stream<List<Share>> get sharesChanged;

  /// Shares files and/or folders (folders recursively, keeping relative
  /// paths). [ttl] null = until revoked; [maxDownloads] null = unlimited.
  /// Throws [ArgumentError] when nothing can be shared.
  Share createShare(List<String> paths, {Duration? ttl, int? maxDownloads});
  void revokeShare(String id);

  /// Whether shares are saved and restored across restarts (only when the
  /// core has a store, e.g. `LanDropCoreOptions.sharesStorePath`). Turning it
  /// off deletes the stored file; turning it on saves the current shares.
  bool get sharesPersistence;
  void setSharesPersistence(bool enabled);

  /// Paired browsers whose session is still valid.
  List<WebSessionInfo> get webSessions;

  /// Emits [webSessions] when a browser pairs, signs out, is disconnected or
  /// its session expires (and, at most every 30 s, when it is seen again).
  Stream<List<WebSessionInfo>> get webSessionsChanged;

  /// Ends a browser session at once: its token stops working and a browser
  /// upload prepared under it is cancelled. Unknown ids are ignored.
  void revokeWebSession(String id);

  /// The web page on the HTTPS server, `https://<ip>:<port>/`. Null when the
  /// core is not running.
  String? get webUrl;

  /// Optional plain HTTP listener for browsers only (no certificate warning,
  /// no encryption). Off by default.
  bool get webHttpEnabled;
  Future<void> setWebHttpEnabled(bool enabled);
  int? get webHttpPort;

  /// `http://<ip>:<webHttpPort>/` while the HTTP listener runs, else null.
  String? get webHttpUrl;
}
