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
    // Peer data: every list and string is bounded (SECURITY.md S19).
    bool short(Object? s, int max) => s is String && s.length <= max;
    String? clean(Object? s, int max) => short(s, max) &&
            !RegExp('[\u0000-\u001F\u007F-\u009F\u202A-\u202E\u2066-\u2069]')
                .hasMatch(s as String)
        ? s
        : null;
    final v = j['v'];
    final ts = <TransportCapability>[];
    final rawTs = j['transports'];
    if (rawTs is List) {
      for (final t in rawTs.take(16)) {
        if (t is! Map || !short(t['id'], 32)) continue;
        final addrs = t['addrs'];
        final port = t['port'];
        ts.add(TransportCapability(t['id'] as String,
            addrs: addrs is List
                ? addrs
                    .where((a) => short(a, 64))
                    .cast<String>()
                    .take(16)
                    .toList()
                : const [],
            port: port is int && port > 0 && port <= 65535 ? port : null,
            ssid: clean(t['ssid'], 64),
            gateway: clean(t['gateway'], 64)));
      }
    }
    final f = j['features'];
    return PeerCapabilities(
      version: v is int ? v : 1,
      transports: ts,
      features: f is List
          ? f.where((x) => short(x, 32)).cast<String>().take(32).toSet()
          : const {},
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

/// Largest text a text message may carry in the LocalSend `preview` field
/// (UTF-8 bytes). Longer text is not sent; a received `preview` above it is
/// ignored (the offer is then an ordinary file).
const maxTextBytes = 64 * 1024;

/// File name used on the wire for a text message (PROTOCOL.md "Text
/// messages").
const textMessageFileName = 'message.txt';

class FileOffer {
  final String id;
  final String fileName;
  final int size;
  final String fileType; // mime

  /// LocalSend v2 `preview`: for a text message, the text itself. Plain
  /// text, never markup; already stripped of control characters by the
  /// core. Null for ordinary files.
  final String? preview;
  const FileOffer(this.id, this.fileName, this.size, this.fileType,
      {this.preview});
}

class IncomingRequest {
  final String sessionId;
  final DeviceInfo sender;
  final List<FileOffer> files;
  final Completer<bool> decision = Completer<bool>(); // UI completes true/false

  /// The text of a text message: exactly one `text/plain` offer with a
  /// `preview` (PROTOCOL.md "Text messages"). Accepting it writes nothing
  /// to disk; the core answers the sender 204 (nothing to upload).
  String? get text {
    if (files.length != 1) return null;
    final f = files.single;
    if (f.preview == null || !f.fileType.startsWith('text/plain')) return null;
    return f.preview;
  }

  bool get isText => text != null;

  /// True when the sender proved that it holds the key of
  /// [DeviceInfo.fingerprint] (signed prepare-upload, PROTOCOL.md "Sender
  /// proof"). Only then may the fingerprint be used for trust decisions
  /// such as auto-accept; otherwise it is just a claim. Always false for
  /// browsers and plain LocalSend senders.
  final bool verified;

  /// Set by the core when the request ended without an answer from this
  /// device ([decision] is then completed with false), so the UI can close
  /// its dialog and say why.
  IncomingRequestEnd? endedBy;
  IncomingRequest(this.sessionId, this.sender, this.files,
      {this.verified = false});
}

/// Why an [IncomingRequest] ended before this device answered.
enum IncomingRequestEnd {
  /// Nobody answered within `decisionTimeout`.
  timeout,

  /// The sender cancelled (withdrew) the request, or the browser left.
  withdrawn,

  /// This device's server stopped.
  stopped,
}

class TransferProgress {
  final String sessionId;
  final String fileId;
  final int sentBytes;
  final int totalBytes;
  final bool done;

  /// English technical reason (logs); null unless the file failed.
  final String? error;

  /// Why the file failed, for the UI ([SendErrorCode.cancelled] after
  /// [LanDropCore.cancelSession] on either side); null when unknown or ok.
  final SendErrorCode? errorCode;

  /// Name (relative path with '/' for folder transfers) of the file, when
  /// known. Lets the UI label a file without matching on sizes.
  final String? fileName;

  /// Receiving side, final event of a completed file: where it was saved
  /// (the unique name actually used, e.g. `a (1).txt`).
  final String? savedPath;
  const TransferProgress(this.sessionId, this.fileId, this.sentBytes,
      this.totalBytes,
      {this.done = false,
      this.error,
      this.errorCode,
      this.fileName,
      this.savedPath});
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
  /// When [withdraw] completes while the receiver has not answered yet, the
  /// request is withdrawn (its dialog closes there, PROTOCOL.md "Withdraw")
  /// and the result is [SendErrorCode.cancelled].
  Future<SendResult> sendFiles(DeviceInfo to, List<SendItem> items,
      {void Function(String sessionId)? onSession, Future<void>? withdraw});

  /// Sends [text] (a note or a link) as a text message (PROTOCOL.md "Text
  /// messages"): one `message.txt` offer of type `text/plain` whose
  /// `preview` holds the text, so LocalSend clients show it too. A receiver
  /// that shows it answers 204 and nothing is uploaded ([SendResult.ok]
  /// with no session id); one that wants the file gets it uploaded through
  /// the normal pipeline. Empty text or more than [maxTextBytes] is refused
  /// without contacting the receiver.
  Future<SendResult> sendText(DeviceInfo to, String text,
      {void Function(String sessionId)? onSession, Future<void>? withdraw});

  /// Changes the folder for transfers accepted from now on, without a
  /// restart (used when Android grants "All files access" while a request
  /// waits for its answer). A transfer already accepted keeps the folder it
  /// was accepted into. Without an explicit identity folder the TLS
  /// identity is copied to the new folder, so the security code stays.
  Future<void> setSaveDir(String saveDir);

  /// Stops a running transfer, in either direction (UX.md 3.8). Sending:
  /// aborts the upload and tells the receiver (`/cancel` with the
  /// `cancelSecret`); [sendFiles] then returns [SendErrorCode.cancelled].
  /// Receiving: ends the session, deletes its `.part` files and refuses
  /// further uploads, so the sender stops with [SendErrorCode.cancelled].
  /// Either way every unfinished file gets a final [progress] event with
  /// `errorCode` [SendErrorCode.cancelled]. Unknown or finished ids are
  /// ignored.
  Future<void> cancelSession(String sessionId);

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
