# LanDrop design document

Status: living document. Last updated 2026-10-21.
Scope: everything built so far (including transport selection and hotspot assist, 3.9), plus the proposed next steps.

## 1. Goal

One app, on every common OS, that moves files between devices on a local network with no accounts, no cloud and no cables. It should work even when the obvious path (same Wi-Fi, multicast discovery) does not, and it should tell the user why when nothing works.

Non-goals for now: internet transfers through a relay, sync of folders, background auto-upload.

## 2. What exists today

### 2.1 Platforms and stack

- Flutter 3.47.7, one codebase for Android, iOS, macOS, Windows and Linux. Only macOS and Android have been built and run. Windows, Linux and iOS projects are scaffolded but never built.
- The networking core is pure Dart (`dart:io` only, no Flutter imports), so it can be tested with `flutter test` without a UI and could later run as a headless CLI or server.
- Repository: github.com/alrz1999/landrop (private). CI builds a macOS app and an Android APK on every push to `main` (`.github/workflows/build.yml`). The macOS build is unsigned, so macOS blocks it until `xattr -cr landrop.app` is run.

### 2.2 Layout

- `lib/core/api.dart`: the contract between core and UI (`LanDropCore`, `DeviceInfo`, `FileOffer`, `IncomingRequest`, `TransferProgress`).
- `lib/core/landrop_core.dart`: HTTPS server and client, peer table, discovery orchestration, transfer logic.
- `lib/core/transport.dart`: `Transport`, `Link`, `LanHttpsTransport` and `TransportSelector` (section 3.9): how a send reaches a known peer.
- `lib/core/discovery.dart`: pluggable discovery transport. The default is UDP multicast and broadcast. Tests inject an in-memory one.
- `lib/core/identity.dart`: self-signed RSA-2048 certificate, generated in Dart, stored under `<saveDir>/.landrop/`.
- `lib/core/util.dart`: file name sanitising, unique names, MIME guessing, local IPv4 lookup, VPN interface filter.
- `lib/core/web_server.dart`, `lib/core/web_assets.dart`: browser access (section 4.8).
- `lib/ui/`: Material 3 UI (home, settings, dialogs), `AppController` (a `ChangeNotifier`), a fake core for UI tests, and the Android helpers (`multicast_lock.dart`, `background_service.dart`, `storage_access.dart`, `hotspot_service.dart`). `hotspot_wizard.dart` is the "Connect without Wi-Fi" wizard (3.9).
- `android/app/src/main/kotlin/.../MainActivity.kt`, `LanDropService.kt` and `HotspotManager.kt`: multicast lock, foreground service, local-only hotspot.
- `PROTOCOL.md`: the wire protocol summary.

### 2.3 Wire protocol (LocalSend v2 compatible subset)

Port 53317 (TCP for HTTPS, UDP for discovery). If the port is busy the core tries the next 20 ports, then any free port, and reports the one it bound in `self.port`.

HTTPS endpoints, all with a self-signed certificate:

- `GET /api/localsend/v2/info` returns the device info: alias, version, device type, certificate fingerprint, port, protocol.
- `POST /api/localsend/v2/register` is the reply to an announce: the announcer is called back and its certificate is verified before it is added as a peer.
- `POST /api/localsend/v2/prepare-upload` carries the sender's file list. It surfaces as an incoming request in the UI. The response is 200 with a session id and one token per file, 403 if declined or not answered in time, 409 if another request or session is active.
- `POST /api/localsend/v2/upload?sessionId=&fileId=&token=` streams the raw bytes to disk. The session id, file id and token are all checked.
- `POST /api/localsend/v2/cancel?sessionId=` cancels a session.

Because the field names match LocalSend, the official LocalSend apps can talk to this app on the same network. This is claimed from the protocol document, not verified against a real LocalSend client.

### 2.4 Discovery

Discovery is how a device learns that a peer exists. Four methods, tried together:

1. UDP multicast to `224.0.0.167:53317`, on start and every 5 seconds, sent out of every real network interface (using `IP_MULTICAST_IF`).
2. UDP broadcast to each interface's `x.x.x.255` (assumes a /24) and to `255.255.255.255`. Many routers drop multicast but pass broadcast.
3. Subnet scan: probe every address of the local /24 on the HTTPS port with a 2.5 second timeout and 64 parallel workers. Triggered by the Rescan button.
4. Manual: type an IP, or scan a QR code that holds `https://<ip>:<port>`.

A peer is added only after its certificate fingerprint matches what it claims in its info response. A peer not seen for 20 seconds is re-probed once and then dropped. VPN and tunnel interfaces (`utun*`, `tun*`, `wg*`, `ppp*` and similar) are skipped for announcing, joining and scanning, because they made one machine appear under two addresses. Virtual interfaces (Docker, VM bridges, AWDL, see 3.10) are skipped too. Link-local 169.254.x.x addresses (direct cable) are used, ranked after private ones.

### 2.4a mDNS / Bonjour as a second discovery channel (2026-10-21)

LanDrop also advertises and browses the DNS-SD service `_landrop._tcp` on `224.0.0.251:5353` (`lib/core/mdns.dart`, pure Dart, no native plugin). Some networks drop LanDrop's own multicast and broadcast datagrams but let standard mDNS through (devices such as printers must keep working), so a second channel finds peers there, and the two channels act as independent signals in the diagnosis (3.8).

- Responder: instance `LanDrop-<first 8 hex of fingerprint>`, host `<same>.local`, SRV port = HTTPS port, A records = non-VPN IPv4 addresses, TXT `fp`, `v=1`, `alias`, `type`, `port`. Answers PTR queries for `_landrop._tcp.local` and the `_services._dns-sd._udp.local` meta query; announces on start and every 60 s, sends a goodbye (TTL 0) on stop. TTL 120 s.
- Browser: queries every 15 s and on demand (start, `restartDiscovery`), and also learns passively from unsolicited announcements. Received data is untrusted: bounded decoder (pointer-loop protection, size caps), fingerprint must be 64 hex chars, port 1..65535, addresses must be private or link-local IPv4, alias and type are sanitised and capped.
- Trust: an mDNS record is only a hint. The core verifies it over HTTPS `/info` against the claimed fingerprint, like a UDP announce, then adds the peer with `foundVia` `mdns`. A candidate whose fingerprint does not match is dropped and shows up in the diagnosis.
- Failure to bind 5353 (another process without port sharing, no permission) never breaks the app: `MdnsService.error` is shown by the rule `mdns-unavailable`.
- Diagnosis rules: `mdns-only`, `mdns-visible-unreachable` (the strongest evidence of a firewall: the device announces itself but its LanDrop port cannot be reached), `udp-only-no-mdns`, `mdns-unavailable`; `announce-blocked` no longer fires for peers mDNS found.
- Limits: the UDP announce stays the primary channel (it carries more and is what LocalSend uses). Browsers cannot use mDNS. iOS needs the multicast networking entitlement or a native Bonjour plugin (`NWBrowser`) before this socket works there. Android may need a multicast lock. Not tested against Bonjour/Avahi clients or a real router; the real-socket unit test only checks two instances on one host.

### 2.5 Security

- Transport is TLS with a per-device self-signed certificate. There is no certificate authority, so trust is by fingerprint.
- The sender pins the receiver's fingerprint from the first info response and rejects a different certificate later. A test covers a wrong pinned fingerprint.
- The receiver must accept every incoming request. With nobody listening it declines.
- File names are sanitised: path separators removed, leading dots stripped, a unique name chosen on collision. A test covers `../../evil.txt`.
- Known weakness: the receiver cannot verify who the sender is for an upload (no client certificates). Any device that knows a session id and token can upload, and anyone who knows a session id can cancel it.
- Folders are flattened to file names. There is no resume.

### 2.6 Platform specifics

macOS:
- App sandbox is on. The entitlements `network.server`, `network.client`, `files.user-selected.read-write` and `files.downloads.read-write` are required in both the debug and release entitlement files. The default Flutter template has only `network.server` in debug and nothing in release, which would have broken sending silently.
- macOS asks once for local network access. Declining it breaks discovery.
- Building needs full Xcode (not just the command line tools), CocoaPods, and an accepted licence. This was set up with Xcode 27.1.

Android:
- Permissions: INTERNET, ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE, CHANGE_WIFI_MULTICAST_STATE, FOREGROUND_SERVICE (data sync), POST_NOTIFICATIONS, WAKE_LOCK, MANAGE_EXTERNAL_STORAGE, and WRITE_EXTERNAL_STORAGE up to API 29. For the local-only hotspot (3.9): CHANGE_WIFI_STATE, ACCESS_FINE_LOCATION and ACCESS_COARSE_LOCATION up to API 32 (Android 12 ignores a fine-location request without coarse), NEARBY_WIFI_DEVICES with `neverForLocation` (API 33+). They are only requested at runtime when the user taps "Start hotspot".
- A `WifiManager.MulticastLock` must be held or Android drops incoming multicast.
- A foreground service (`LanDropService`) keeps the process and the server alive when the app is in the background or the screen is off. It also holds a Wi-Fi lock, which cut Wi-Fi latency. Without it Android froze the app and the server stopped answering.
- Swiping the app away stops the service and kills the process, so the server really stops.
- Settings has a "Keep running in background" switch and a "Quit LanDrop" button.
- Received files go to `Downloads/LanDrop` when the "All files access" permission is granted, so they show in the Files app. Otherwise they go to the app's hidden external folder. Only a folder chosen by the user is saved in settings, so the default can still change in later versions.
- `permission_handler` is pinned to 12.x because 13.x needs compileSdk 37 while the Android Gradle plugin in use stops at 36.
- The service notification shows what is active: "Ready to receive files on your network", or e.g. "Ready to receive · 2 active shares · 1 browser connected". Dart calls `update` on the `dev.landrop/service` channel (`BackgroundService.update`, from `AppController` whenever the share or browser count changes, only while "Keep running in background" is on); the service re-posts its notification under the same id if it is running and keeps the counts for a later start. The service now also builds its notification and starts itself in a way that is valid on API 24-25 (`Notification.Builder(Context)` and `startService` below API 26).

iOS (prepared, not built): `ios/Runner/Info.plist` has `NSLocalNetworkUsageDescription` (the text shown in the local network prompt) and `NSBonjourServices` with `_landrop._tcp` (declared for a future Bonjour/mDNS discovery; the app does not advertise or browse that service yet). Nothing else under `ios/` was changed, and the iOS app has never been built or run, so none of this is verified. Still missing: the multicast networking entitlement (`com.apple.developer.networking.multicast`, which needs Apple's approval) for raw UDP multicast; without it discovery would rely on scan and manual IP. iOS also limits background execution, so the foreground-service approach does not carry over.

Windows, Linux (not built): the firewall must allow TCP and UDP on 53317. On Linux, `ufw` or `firewalld` may block it.

### 2.7 What has been verified, and how

- 17 automated tests passed when this section was written (103 after 4.9, 139 after 3.9; `flutter test`): a 20 MB transfer between two cores with a SHA-256 comparison, decline path, wrong fingerprint, path traversal, busy (409) handling, port fallback, discovery over an in-memory transport, and UI widget tests against a fake core. `flutter analyze` is clean.
- On a Mac, with the real app and a headless peer: real UDP multicast discovery, manual probe, subnet scan and a 5 MB transfer into the running app, byte-identical.
- Mac and an Android phone on the same Wi-Fi: transfers in both directions, discovery by multicast and broadcast without a subnet scan, the server staying reachable with the screen off, and the server being gone after the app was swiped away.

Not verified: Windows, Linux, iOS; a router that blocks multicast and broadcast; a VPN on the phone; the "Quit" button and the "background off" setting; interoperability with a real LocalSend client; transfers of several GB; two simultaneous sends (progress may be attributed to the wrong card because `send()` does not return a session id).

### 2.8 Defects found along the way (for the record)

- Entitlements missing, so sending would fail silently on macOS.
- Discovery startup failures were swallowed silently. One run had a TCP listener but no UDP socket. Failures are now written to stderr, but the UI still does not show them.
- The phone reported itself as a desktop.
- The same Mac appeared under its VPN address as well as its Wi-Fi address.
- Announces left only the default interface.
- A dependency bump (`permission_handler` 13) broke the Android build.
- The Android app was frozen in the background, so the server stopped.
- A persisted default folder would have blocked later default changes.

### 2.9 Changes (2026-10-21, stabilise + resume + folders)

Implemented from section 5 and roadmap steps 1 and 2, where it differs from the text above:

- Progress is keyed by session id: `sendFiles()` reports the id through `onSession` and returns it; `send()` is a wrapper.
- Received data goes to a hidden `.<name>.part` file, renamed on completion. Resume (`offset` on upload, `GET /api/landrop/v1/upload-status`) works only while the receiver keeps the session (idle timeout); `.part` files are deleted on cancel, timeout or stop, so there is no resume across restarts. No SHA-256 check, only the final size.
- Folders are sent with relative paths and recreated under the save folder (2.5's "flattened" no longer holds). The top-level folder gets a unique name instead of merging.
- `cancel` needs the `cancelSecret` from `prepare-upload`. This is a compatibility change: an official LocalSend sender cannot cancel a LanDrop receiver any more (the session then idles out).
- Uploads are still authenticated only by the per-file token; no client certificates.
- A discovery startup failure is shown as a dismissible banner on the home page.

## 3. Next step A: negotiate the best transport

### 3.1 Problem

Today there is one path: TCP over a shared IP network. When that is blocked (router client isolation, guest network, no router at all) the user must work it out alone. The idea is that two apps first find each other by whatever works, exchange what each can do, and then choose the best available way to move the data. If nothing works, the app explains why.

### 3.2 Concepts

- Rendezvous: how two devices first learn about each other. This can use a cheap, low-bandwidth channel.
- Transport: how the bytes actually move. Higher bandwidth, higher setup cost.
- Capabilities: what a device can offer, advertised during rendezvous.

Splitting rendezvous from transport is the key change. Bluetooth Low Energy is good for the first and bad for the second. Wi-Fi is the reverse.

### 3.3 Capability record

Added to the existing info response as an extra field (clients that do not know it ignore it, so LocalSend compatibility stays):

```
"landrop": {
  "v": 1,
  "transports": [
    {"id": "lan-https",  "addrs": ["192.168.1.103"], "port": 53317},
    {"id": "hotspot",    "ssid": "...", "needsJoin": true},
    {"id": "wifi-direct","supported": true},
    {"id": "relay",      "supported": false}
  ],
  "features": ["resume", "folders", "browser-ui"]
}
```

It is also reachable at a new `GET /api/landrop/v1/capabilities`.

### 3.4 Transport interface

```
abstract class Transport {
  String get id;
  int get basePriority;                     // tie-break when measurements are equal
  Future<bool> isAvailable();               // radio present, permission granted
  Stream<Peer> discover();                  // optional: rendezvous
  Future<Link?> open(Peer peer);            // returns a connected, authenticated link
}
```

A `Link` offers the same HTTPS-style request interface the core already uses, so `send()` and the receiver do not care which transport carries them. The existing LAN path becomes the first implementation (`lan-https`) with no behaviour change.

Implemented (3.9), smaller than sketched: no `discover()` (rendezvous stays in `discovery.dart`), `open(DeviceInfo peer, {timeout, exclude})`, and a `Link` is an HTTPS endpoint (host, port, pinned fingerprint, measured round trip) rather than a request interface.

### 3.5 Candidate transports

| Transport | Needs | Typical speed | Notes |
|---|---|---|---|
| lan-https | Shared IP network, not isolated | Wi-Fi speed | The default and the baseline. |
| ethernet | Cable to a router or switch | Up to 1 Gbit/s | Same as `lan-https`: nothing special. Works as soon as both devices have an address. |
| direct cable | Ethernet cable between two computers, no router | Link speed | Both ends get 169.254.x.x (link-local) addresses without DHCP. Covered by `lan-https`, see 3.10. |
| usb-tether | Phone shares its connection over USB (Android USB tethering, iPhone Personal Hotspot) | USB speed | The computer gets a new adapter (`rndis*`, `usb*`, `enx*`, `enN`), often in 192.168.42.x or 172.20.10.x. Covered by `lan-https`, see 3.10. |
| hotspot | One device creates a hotspot, the other joins | Wi-Fi speed | Solves client isolation. Joining is automatic on Android (scan the hotspot QR code, below); iOS would need a Network Extension and is not done; macOS, Windows and Linux join by hand, guided by the app. |
| wifi-direct | Android and Windows (Apple has its own peer-to-peer Wi-Fi) | Wi-Fi speed | No router at all. Platform code per OS, fragile across vendors. |
| ble | Bluetooth Low Energy | Under 100 KB/s | Rendezvous and handshake only, for example to exchange the hotspot name or IP. Not for bulk data. |
| relay / WebRTC | Internet and a signalling server | Varies | For devices on different networks. Out of scope until needed. |

Implemented (3.9): `lan-https` only. The hotspot is not a transport of its own: once both devices are on the hotspot, `lan-https` carries the data. LanDrop guides the user through it, and on Android it can create the hotspot itself (local-only hotspot with a join QR code). Joining is automatic on Android only, by QR code (next paragraph); everywhere else it is manual. Wi-Fi Direct, BLE and relay are not started.

Join a hotspot by QR (Android, `wifi_qr.dart`, `wifi_join_service.dart`, `wifi_join_page.dart`, `wifi_scanner_view.dart`, `WifiJoinManager.kt`, channels `dev.landrop/wifijoin` and `dev.landrop/wifijoin/events`): the phone scans the `WIFI:` QR code that another LanDrop hotspot shows (or any Wi-Fi QR code), or the user types name and password, confirms "Join <name>?", and Android joins the network. `parseWifiQr` is the inverse of `wifiQrPayload` (escapes, quoted values, any field order, optional trailing `;;`; it rejects an empty or over-32-byte name, control characters, secured networks without password and payloads over 1 KB). On Android 10+ the native side uses `WifiNetworkSpecifier` with `requestNetwork` (WPA3 passphrase only on API 30+, open networks without passphrase) and binds the app process to the network; API 24-28 uses the deprecated `addNetwork/enableNetwork`, best effort. After joining, the page reuses `FindDevicePanel` (`restartDiscovery`, gateway probes including the reported gateway, subnet scan, diagnosis). Entry points: the "Scan the hotspot QR code" button in the hotspot wizard's "this device joins" branch and Settings > Advanced > "Join a hotspot by QR", both Android only. The camera is requested with permission_handler when the page opens; the scanner is `mobile_scanner` 7.4.x (compileSdk 36, minSdk 23). Limits: Android 10+ always shows its own confirmation dialog; the network is temporary and private to LanDrop (other apps do not use it) and disappears when the user taps "Leave network" or the app is killed; the phone may have no internet while joined; WEP is not supported on Android 10+; iOS is not done; macOS, Windows and Linux are manual; untested on real hardware; the Kotlin file is compiled only in CI (it could not be built where it was written).

Wi-Fi Direct (Android, assist model, `wifi_direct_page.dart`, `wifi_direct_service.dart`, `WifiDirectManager.kt`, channels `dev.landrop/wifidirect` and `dev.landrop/wifidirect/events`): LanDrop only forms the Wi-Fi P2P group (discover peers, connect, or create a group on this device). The other device sees the Android system invitation dialog and must accept it. Once the group exists both devices share a normal IP link (owner usually 192.168.49.1), so the page calls `restartDiscovery()` and `probeAddresses` for the owner address and `lan-https` carries the data unchanged. Entry: Settings > Advanced > "Connect with Wi-Fi Direct", Android only. It uses the same permissions as the hotspot (NEARBY_WIFI_DEVICES on 33+, fine location up to 32) and declares `android.hardware.wifi.direct` as not required. Leaving the page keeps the group; Disconnect (or closing the app) removes it. Limits: not iOS or macOS (Apple uses AWDL, which apps cannot access); Windows only when the other side is Android and the user pairs by hand from Windows' own settings; the Kotlin code was written without an Android SDK and is compiled only in CI; never tested on hardware, and vendors differ (some phones refuse to be group owner, or drop the group when the screen turns off). Unit and widget tests cover the Dart side with a mocked channel and a fake service.

### 3.6 Selection algorithm

1. Rendezvous by every available method at once (multicast, broadcast, scan, BLE). Merge peers by fingerprint, not by address.
2. For a chosen peer, compute the intersection of its advertised transports and the local ones that `isAvailable()`.
3. Probe the top candidates in parallel with a short timeout (similar to "happy eyeballs"): open a link and time a small request. Prefer the lowest round trip among those that work, with `basePriority` as the tie-break.
4. Cache the winner per peer fingerprint, with an expiry, so the next transfer starts immediately.
5. During a transfer, if no bytes move for N seconds, fall back to the next candidate and continue from the last confirmed byte. This needs resumable uploads (section 5).

Implemented (3.9): steps 3 to 5. Peers are merged by fingerprint (step 1 for the LAN methods only, no BLE). Step 2 has nothing to intersect yet with one transport: every transport whose `isAvailable()` is true is tried.

### 3.7 Guided diagnosis

When no transport reaches a peer, run rules over what was observed and show the cause in plain words:

- Peer seen over BLE but not on the LAN: "Both devices are near, but Wi-Fi is blocked between them. Try a hotspot."
- Ping works but the HTTPS port does not answer: "The other app is not running or its firewall blocks port 53317."
- Peer visible only by manual IP, never by announce: "Your router blocks multicast and broadcast. Transfers still work with the IP."
- A VPN interface is active: "Turn off the VPN or allow local network access."
- Discovery socket failed to start: show the error that is currently only written to stderr.

This turns the troubleshooting list from the start of the project into code.

Implemented: see 3.8 (rules) and 3.9 (findings that a hotspot can fix carry an action that opens the hotspot wizard). The BLE rule is not possible without BLE.

### 3.8 Implemented (2026-10-21): capability record and guided diagnosis, LAN only

- Capability record (3.3) is served in the info JSON (`landrop`) and at `GET /api/landrop/v1/capabilities`, with one transport (`lan-https`, local non-VPN IPv4 addresses, port) and the features `resume`, `folders`. Peers' records are parsed into `DeviceInfo.capabilities`. Transport selection (3.4-3.6) followed in 3.9, which also added the optional `hotspot` entry.
- Each peer records how it was found in `DeviceInfo.foundVia`: `multicast` / `broadcast` (LanDrop tags its datagrams with `landropVia`; the receive API cannot see the destination), `announce` (untagged, e.g. LocalSend), `register`, `scan`, `manual`.
- `lib/core/diagnosis.dart`: pure rules over a `DiagnosisInput` (discovery error, interfaces, own server listening, peers and how found, optional probe of a target IP: TCP connected / refused / timeout / unreachable, then TLS + info and fingerprint check). Rules: server down, discovery failed, no LAN address, VPN active, peers only by scan/manual (router blocks multicast and broadcast), probe refused, timeout, unreachable, fingerprint mismatch, not LanDrop, different /24, probe ok, all good; plus a network summary.
- `LanDropCore.runDiagnosis({targetIp, targetPort})` gathers the observations and runs the rules. The connection helper (`lib/ui/connect_helper.dart`, UX.md 3.4 / U4: empty peer list "Why can't I see my device?", discovery banner "Help", the device picker's "Help me connect", Settings "Can't find the other device?" and Settings > Advanced) runs it automatically together with a rescan and shows one finding. The full dialog opens from Settings > Advanced > "Connection report" and after a failed Add by IP ("Diagnose this IP"), with "Run again" and "Copy report" (plain text, fingerprints shortened). The dialog hides the "network" summary (it stays in the report) and collapses each finding's technical text under "Details" (UX.md U5).
- Not done: BLE and ping-based rules (no BLE, no ICMP from Dart without privileges); the subnet rule assumes /24 netmasks.

### 3.9 Implemented (2026-10-21): transport interface, link selection with fallback, multi-address peers, hotspot assist

Roadmap step 3 (rest) and the hotspot assist of step 5. Wire details are in PROTOCOL.md.

Transport (`lib/core/transport.dart`):
- `Transport { id, basePriority, isAvailable(), open(peer, {timeout, exclude}) }` returns a `Link`: host, port, pinned fingerprint, the measured round trip, and a `key` (`transport|host|port`) used to exclude a failed endpoint.
- `LanHttpsTransport` (the only real one) collects the candidate endpoints: `DeviceInfo.ip`, `DeviceInfo.addresses`, then the `lan-https.addrs` of the peer's capability record (at most 8). It probes all of them in parallel with `GET /info`. The TLS certificate must have the peer's fingerprint, and the info must claim the same fingerprint. The first endpoint that passes wins, and its time is the RTT. An address with another fingerprint is never used.
- `TransportSelector` opens every available transport in parallel (`selectTimeout`, default 2 s). When the first link arrives, the others get 100 ms of grace. Links are ranked by RTT, where differences under 10 ms count as equal, and then by `basePriority`. A link whose fingerprint differs from the peer's is dropped. The winner is cached per fingerprint (`linkCacheTtl`, default 5 min). `next(peer, exclude)` returns the best link that is not excluded, which is how fallback works. `LanDropCoreOptions.transports` (default `[LanHttpsTransport()]`) lets tests inject fakes.
- `sendFiles` uses the selector for every request: prepare-upload, upload, upload-status and cancel. When nothing answers in time, it sends to `DeviceInfo.ip` as before, and the certificate is still pinned. Two kinds of failure lead to another link. A prepare-upload whose connection cannot be made (refused, timeout, wrong certificate) is retried on the next link. An upload that breaks or stalls (`stallTimeout`) moves to the next link, excluding the ones that failed, and the existing resume logic then asks `upload-status` on that link and continues from the receiver's byte count. When no other link answers, the retries stay on the current one (the earlier behaviour). A failed send clears the cached link. The receiver needs no change: it authenticates uploads by session token, not by source address.
- Verified by `test/transport_test.dart` (16 tests). Fake transports cover RTT ranking, the priority tie-break, a slow transport losing after the grace period, failing, hanging and unavailable transports, cache hit, expiry and invalidate, `next()` fallback and a link with the wrong fingerprint. A parallel address race with an injected probe picks the fastest of four addresses. Two cores on loopback cover: the real fingerprint check (a second core's endpoint is rejected); a refused best link falling back before prepare-upload; and a TCP proxy that stops forwarding after 1 MB, so the upload stalls, moves to the direct link and resumes, and the 4 MB file arrives with the same SHA-256 and no `.part` left.

Peer table:
- The same fingerprint seen at several addresses is one peer. `DeviceInfo.addresses` (new, additive) lists every verified address, `ip` first. `ip` stays the current best one: it changes only when the current address has not been seen for `peerTimeout`, so the display does not flip between interfaces. Announces and register calls from any known address refresh the peer without a new probe. The prune step re-probes all addresses of a silent peer, keeps the ones that answer, and drops the peer only when none answers. Addresses not seen for 3 x `peerTimeout` are dropped while others are alive. The UI shows one row per device (name and device kind, no address); the device's Details sheet lists its address, the other addresses and its security code; `AppController` also de-duplicates by fingerprint.

Capability record: an optional `{"id": "hotspot", "ssid": ..., "gateway": ...}` entry, present only while this device shares a hotspot created from LanDrop (`LanDropCore.setHotspotInfo`). The password is never advertised. `v` stays 1, and the existing fields are unchanged.

Diagnosis: `Finding.action` (optional). `probe-timeout`, `announce-blocked`, `different-subnet` and `no-lan` carry `hotspot-wizard`. A new rule, `hotspot-likely-fix` (info), fires when this device is on a LAN and listening, no target was probed and no device was found at all. It replaces "No problems found" in that case. The diagnosis dialog shows "Connect with a hotspot" for these findings, which closes the dialog and opens the connection helper at "What is the other device?" (a `cable-wizard` action opens the helper's cable steps); inside the helper the same buttons move to those steps.

Hotspot assist:
- `HotspotWizardPage` ("Connect without Wi-Fi") opens from that button, from Settings > Advanced ("Connect without Wi-Fi / router") and from the empty peer list. The user picks a role: "This device shares the hotspot" or "This device joins it". The wizard then shows steps for this OS (Android: Settings > Hotspot & tethering, or the in-app button; iPhone: Personal Hotspot; macOS: Internet Sharing, though joining the other device's hotspot is recommended; Windows: Mobile hotspot; Linux: GNOME "Turn On Wi-Fi Hotspot", NetworkManager Hotspot mode or `nmcli`). A collapsible section shows the other role's steps for every OS, for the other device.
- "I'm connected, find the other device" does four things. (a) `restartDiscovery()` (new core API) re-reads the interfaces, updates `self.ip` and the capability addresses, rebinds the discovery socket, rejoins multicast and announces. (b) `probeAddresses()` (new) probes the usual hotspot gateway addresses (192.168.43.1, 172.20.10.1, 192.168.2.1, 192.168.137.1) plus the `.1` of each own non-VPN /24, minus this device's own addresses, with the normal verified info probe. (c) It runs a subnet scan. (d) It lists what was found, or, when nothing was found, runs the diagnosis again and shows the findings in the wizard.
- Android: "Start hotspot" asks for the runtime permission (Nearby devices on API 33+, location below; `permission_handler` stays 12.x). It then calls `start` on the `dev.landrop/hotspot` channel. `HotspotManager.kt` uses `WifiManager.startLocalOnlyHotspot` (API 26+, guarded; minSdk 24 gets "unsupported"), keeps the reservation and releases it on Stop and in `onDestroy`. It returns the SSID and password, plus the hotspot interface's address when it can find one (interface name `ap*`, `swlan*` or `softap*`). The wizard shows the name, the password and a `WIFI:T:WPA;S:…;P:…;;` QR code (with `\ ; , : "` escaped) that phone cameras can join from, plus "Stop hotspot". Starting and stopping update the capability record and call `restartDiscovery` (after 1 s, so the interface has its address). While the hotspot runs, the home screen shows a banner with Show and Stop.
- Verified by `test/hotspot_test.dart` (18 tests): QR escaping, probe targets, permission choice per API level through an injectable permission function, mocked channel calls and error codes, steps per platform, the wizard with an injected platform (steps, find, results, empty state with diagnosis), the diagnosis action button, and the entry points from Settings and the empty state. Also 2 new diagnosis tests.
- Not verified: the Kotlin code and the manifest changes were not compiled here (no Android SDK). They are only built in CI. The local-only hotspot, the permission prompts, the QR join and the gateway lookup have never run on a device. Nothing was tried on real networks with two interfaces. Known limits: Android may drop the phone's Wi-Fi while the local-only hotspot runs (devices without concurrent AP and station mode); a local-only hotspot gives no internet to joiners; joining a hotspot is always manual (no OS API is used to join).

### 3.10 Implemented (2026-10-21): wired links (Ethernet, direct cable, USB tethering)

Not new transports: `lan-https` carries the data, and discovery now works on these links.

- Interface classification (`lib/core/util.dart`): `isVirtualInterface(name)` marks Docker/LXC/libvirt/VirtualBox/VMware bridges (`docker*`, `br-*`, `veth*` incl. Hyper-V `vEthernet`, `vmnet*`, `vboxnet*`, `virbr*`, `lxcbr*`), Apple `awdl*`, `llw*`, `bridge*`, `anpi*` and loopback. `isRealInterface` = not VPN and not virtual. `isVpnInterface` is unchanged. USB tether adapters (`rndis*`, `usb*`, `enx*`, `en5`...), `eth*`, `enp*`, `wlan*`, `en0`, `Ethernet`, `Wi-Fi` are real. Announcing, joining multicast, scanning, the capability addresses and the diagnosis ignore the others.
- Address ranking (`rankedIPv4`, used by `localIPv4Addresses`): private (RFC 1918) first, other addresses next, link-local 169.254.x.x last (stable within a class). Normal networks therefore behave as before. Link-local addresses are now announced on (multicast and `169.254.x.255` broadcast), scanned (the /24 of the address), advertised in `lan-https.addrs`, and become `self.ip` only when nothing else exists. When a real address appears later, `restartDiscovery` moves `self.ip` off the link-local one.
- Diagnosis: `link-local-only` (info, action `cable-wizard`): the only usable addresses are 169.254.x.x. `no-lan` is no longer reported then. "No problems found" is not added next to it. Interfaces marked virtual no longer count as a LAN (a Docker bridge used to hide `no-lan`).
- Cable wizard (`lib/ui/cable_wizard.dart`): "Connect with a cable" from Settings > Advanced, the empty device list and the hotspot wizard; the `cable-wizard` finding action opens the same steps (`CableSetup`, shared with the page) inside the connection helper. Per-OS steps for an Ethernet cable between two computers (macOS Network settings with DHCP, Windows Ethernet settings, Linux NetworkManager "Link-Local") and for USB tethering (Android, iPhone). "Find the other device" is the same `FindDevicePanel` as in the hotspot wizard (`restartDiscovery`, `probeAddresses`, scan, diagnosis), with the usual tether gateways added to the probe list: 192.168.42.129, 192.168.42.1 (Android USB), 172.20.10.1 (iPhone). No `.1` gateway is guessed for a 169.254 address.
- A peer at a 169.254 address shows "direct cable link" in its row. Which kind of link (Wi-Fi, Ethernet, USB) a peer is on is not shown: it would need the local interface of each peer.
- Verified by `test/cable_test.dart` and `test/cable_core_test.dart`: name lists, ranking with link-local last, VPN/virtual/loopback skipped, probe targets, the diagnosis rules, wizard steps and search with `FakeCore`, entry points, and a loopback core test where a capability record holds an unreachable 169.254 address next to a reachable one (candidate listed, the reachable one wins, a wrong certificate is rejected).
- Not verified: nothing was run on real hardware. No Ethernet cable, direct cable, USB tether or real 169.254 link was tried; the OS settings paths in the wizard are written from documentation and may differ by version and brand. Windows and macOS firewall prompts, multicast on link-local links, `IP_MULTICAST_IF` with a 169.254 address and the 169.254.x.255 broadcast are untested. Some USB tethers use a /30 or other masks where the /24 scan and broadcast guess are off; the gateway probe covers the common cases. Android USB tethering on macOS needs a third-party driver.

## 4. Next step B: browser access and local stream server

### 4.1 Idea

The app already runs an HTTPS server on the device. The same server can serve a small web page, so any device with a browser can use LanDrop with nothing installed: scan a QR code, open the page, send files to the device or download files the device shares. The same mechanism can stream media from the device, for example a video, to a browser on the local network.

LocalSend's protocol already reserves a `web` device type and a `download` flag in the info response (currently `false`), so this fits the existing model.

### 4.2 Modes

1. Browser to device (upload): the page lets the user pick files and sends them to `prepare-upload` and `upload`. The device owner still sees the Accept dialog.
2. Device to browser (share and download): the device owner selects files and starts a share. The app creates one URL per share with an unguessable token. A browser opens it, sees the file list and downloads. Shares expire after a time or after the first download, whichever the owner chooses.
3. Streaming: media files are served with HTTP range requests (`Accept-Ranges: bytes`, `206 Partial Content`, correct `Content-Type`), so a browser `<video>` or `<audio>` element can seek without downloading the whole file. This works with the same share URLs.
4. Live streaming (camera, screen): later. It needs WebRTC or MSE, a different mechanism from file streaming.

### 4.3 Endpoints (proposed, version-prefixed)

- `GET /` serves the web page (embedded assets, no external requests).
- `GET /api/landrop/v1/shares/{token}` lists a share. `GET /api/landrop/v1/shares/{token}/files/{id}` returns the bytes with range support.
- Existing `prepare-upload` and `upload` are reused for browser uploads.
- A session endpoint for browser pairing (4.5).

### 4.4 The certificate problem

A self-signed certificate makes browsers show a full-page warning, which is bad for the main use case (a friend scans a QR code). Options:

1. Keep HTTPS with a self-signed certificate and explain the warning on the page that shows the QR code. Works everywhere, poor first impression, and some browsers block features.
2. Offer an optional plain HTTP port for the browser only. No warning, but anything on the network can read the traffic. Acceptable on a trusted home network with a per-session token, and it must be an explicit opt-in with a visible notice.
3. A local certificate authority installed on the browsing device. Smooth afterwards, but too heavy for a casual guest.
4. A real hostname with a real certificate (for example a name that resolves to the device's LAN address). Needs a domain and a service to issue certificates, which breaks the "no accounts, no cloud" goal.

Recommendation: option 1 by default, option 2 as an opt-in toggle in Settings, option 3 and 4 not planned. Note that browsers treat only HTTPS and `localhost` as secure contexts, so features such as the clipboard API or service workers will not work on the plain HTTP page. The page must not depend on them.

### 4.5 Authorising browsers

A browser cannot hold a pinned certificate fingerprint, so authorisation moves to the application layer:

- The QR code or link carries a one-time pairing token in the URL fragment.
- The owner sees a 4 to 6 digit confirmation code on both screens, or must accept the new browser, before it can do anything.
- Shares use their own tokens, scoped to specific files, with an expiry and optional download limit.
- Rate-limit failed token attempts. Never list shares without a valid token.

### 4.6 Platform notes

- Android: the foreground service already keeps the server alive, so a share stays reachable with the screen off. The notification says when shares are active and browsers are connected (4.9).
- iOS: the server stops when the app is suspended, so browser mode works only while the app is open.
- Desktop: works as is. A headless mode (no UI) becomes possible later because the core has no Flutter dependency.

### 4.7 Relationship to transport negotiation

The browser is just another client of the `lan-https` transport. It cannot use Wi-Fi Direct or BLE (browsers expose Web Bluetooth only partially, and not on iOS), so negotiation does not apply to it. The guided diagnosis from 3.7 still helps: if a browser cannot load the page, the same "AP isolation, VPN, firewall" explanation applies.

### 4.8 Implemented (2026-10-21): web page, pairing, browser upload, shares, range streaming, plain HTTP opt-in

Where it differs from 4.1-4.6 (wire details in PROTOCOL.md, "Browser access"):

- `lib/core/web_server.dart` (`WebService`) and `lib/core/web_assets.dart` (the page as a Dart string). The core only routes web paths to it and lends it its receive pipeline: `prepare-upload` was split so `_prepareIncoming` (sanitising, Accept dialog, sessions) serves both LocalSend senders and browsers, and the upload handler takes an optional browser-session owner. No upload safety logic is duplicated.
- Browser uploads do not call `prepare-upload`/`upload` directly (4.3) but `web/upload-prepare` and `web/upload`, which require a paired browser session and then run the same code. The owner still sees the normal Accept dialog ("Browser <ip>") and the transfer in the normal list.
- Pairing (4.5): no token in the QR fragment. The browser asks (`web/pair`), both screens show a 4-digit code, the owner approves. Result: a 1-hour HttpOnly, SameSite=Strict cookie (also usable as a Bearer token), bound to the browser's IP. 60 s timeout, at most 5 pairings waiting, one per IP, and a per-IP limit of 10 failed attempts a minute (429).
- Shares: `createShare` (files or folders, folders keep relative paths), expiry (15 min / 1 h / 24 h / until stopped) and a download limit (unlimited / 1 / 5) in the UI. Links are `https://ip:port/#s=<token>` with the token in the fragment. Range requests as in 4.2 mode 3, so `<video>`/`<audio>` previews seek. A limited share counts one download per client per file; ranges are charged at the first partial request, so they cannot be used to bypass the limit (rule in PROTOCOL.md and on `WebService`). Shares are kept across restarts (4.9).
- The plain HTTP listener (4.4 option 2) exists as an opt-in switch in Settings > Advanced with a confirmation dialog, off by default, on port 53320 (or a free one). It serves only the page, the web endpoints and shares, never the LocalSend device API, and its cookie is not `Secure`.
- UI: a Shares screen (app bar "Share link", and Settings > "Shares and browsers") with two sections: "Send a link" (share files or a folder; link, QR, copy, remaining time and downloads, Stop sharing) and "Use from a browser" (the address, QR, a collapsed "The browser shows a warning?" help, and connected browsers); the pairing dialog is queued with incoming requests. Home shows active links only as one "Sharing N links" row that opens the Shares screen (UX.md U1, U2).
- Verified: `flutter test` (web_test.dart: ranges incl. 5 MB reassembly by sha256, identical 404s, traversal, limits, pairing, rate limit, timeout, HTTP listener, page static checks, a 30 MB two-core end-to-end run) and one manual run in a Chromium-based browser pane over the plain HTTP listener on loopback: page, audio preview, pairing and a 3 MB upload, byte-identical.
- Not done: no live streaming (mode 4); not tried on real phones, Safari, Firefox, or over HTTPS with a real certificate warning; no scripted headless-browser test (section 7).

### 4.9 Implemented (2026-10-21): share button, browser sessions, persistent shares, notification

- Home screen (UX.md U1): one "Send" button opens a sheet with "Files" and "Folder"; sharing is on the Shares screen only (app bar), which runs `startShareFlow`. Widget tests check the single button at 375 and 1000 px.
- Sign out: `POST /api/landrop/v1/web/logout` ends the caller's session and clears the cookie (`Max-Age=0`); the token then gets 401. The page has a "Sign out" button once paired.
- Connected browsers: `LanDropCore.webSessions` / `webSessionsChanged` / `revokeWebSession(id)` (`WebSessionInfo`: opaque id, IP, user-agent summary, paired at, last seen; last seen is refreshed on every request but only announced every 30 s). A "Connected browsers" card on the Shares screen (reachable from Settings too) lists them with "Disconnect". Ending a session (sign out or Disconnect) invalidates the token at once and cancels the receive session it prepared, so later uploads with its file tokens get 403, a running upload is aborted and its `.part` deleted, and a prepare still waiting for the Accept dialog gets 401.
- Persistent shares (opt-out): with `LanDropCoreOptions.sharesStorePath` set (the app uses `landrop_shares.json` next to the settings file in the app support directory; null, as in the tests by default, keeps shares in memory only), every change to the shares (create, stop, download charged, expiry) rewrites the file: a temporary file, `chmod 600` where a `chmod` binary exists (macOS, Linux, Android; not Windows or iOS, whose app data folders are per user anyway), then rename. It holds id, token, expiry, download limit and downloads left, and per file its id, name, local path, size and MIME type. On the first start the core restores the shares that have not expired, have downloads left, and whose files all still exist with the stored size; the rest are dropped and the file is rewritten. A corrupt file is ignored (and replaced at the next change). Links are rebuilt from the current address, so a share keeps working when the port changed; the token is the credential. Settings > Advanced has "Keep share links after restart" (default on); off deletes the file at once and stops writing it (the shares stay active until the app stops).
- Android notification: see 2.6.
- Not verified: the Kotlin changes were not compiled (no Android SDK on the machine they were written on); the notification text, the API 24-25 paths and `chmod` on Android are untested on a device.

## 5. Protocol work needed for both steps

- Resumable uploads: a way to ask "how many bytes do you have for this file" and continue from there. Needed for fallback during transfers and for large files over weak Wi-Fi.
- Return a session id from `send()` and key progress by it, which fixes the progress mix-up with simultaneous sends.
- Write to a temporary name and rename on completion, so a half-received file is not visible under its final name.
- Folder transfer that keeps relative paths (with traversal checks).
- Tie `cancel` to the session owner.
- Client authentication for uploads (a per-session secret exchanged in `prepare-upload`, or client certificates).
- A feature flag list in the capability record, so older apps are never sent something they cannot understand.

## 6. Roadmap

1. Stabilise what exists: verify Quit and the background switch, show discovery failures in the UI, add progress keyed by session, temporary file names, unit tests for the new Android logic where possible. Add Windows and Linux builds to CI.
2. Resume support and folder transfer.
3. Transport interface with `lan-https` as the only implementation, capability record, guided diagnosis. Done (3.8, 3.9).
4. Browser mode: web page, shares, range streaming, pairing. Done (4.8, 4.9).
5. Hotspot assist, then Wi-Fi Direct (Android first), then BLE rendezvous. Hotspot assist done (3.9: guided wizard for every OS, Android local-only hotspot with a join QR code, joining by hand). Wi-Fi Direct and BLE not started.
6. iOS build and the iOS-specific permissions (the `Info.plist` keys are in place, 2.6; the build and the multicast entitlement are not).
7. Relay or WebRTC, only if there is real demand.

Steps 3 and 4 are independent and can be built in parallel.

Known gaps after 3.9: there is no Wi-Fi Direct, BLE or relay transport, so `lan-https` is the only implementation and the selector chooses between a peer's addresses. Joining a hotspot is manual on every OS. The only exception is a hotspot created by the Android app, which other phones can join by scanning its QR code. iOS has no in-app hotspot or join (it would need the NEHotspotConfiguration entitlement). Address probing assumes /24 networks (the `.1` gateway guess, the subnet scan). The Android hotspot code has not run on a device.

## 7. Test plan additions

- Unit: capability intersection and ranking, selection with fake transports that succeed, fail or stall, resume offsets, share token expiry and limits, range request parsing.
- Integration on one machine: two cores on loopback with a fake transport that drops mid-transfer, to prove fallback and resume.
- Browser: a scripted browser (headless) opens a share URL, seeks in a video, uploads a file, and is refused with a wrong token.
- Device matrix: every OS pair, plus the cases "router blocks multicast", "client isolation on", "VPN on", "phone screen off", "app swiped away".
- Large files: several GB, to check memory use (the core streams to disk and should stay flat).

## 8. Open questions

- Should plain HTTP for browsers exist at all, given the risk on shared networks? It is now implemented as an opt-in (4.8): off by default, a warning in Settings and a confirmation before it turns on, only the browser endpoints on that port, sessions bound to the browser's IP. Still open: anyone on the network can read the traffic, see share tokens and pairing codes, and pretend to be the device while it is on. Options to decide: keep it, limit it to a time window (turn off automatically after an hour), or drop it once option 1's warning proves acceptable to real users.
- Is "All files access" on Android acceptable, or should received files use the system storage access framework and avoid the restricted permission (which would also allow a Google Play release)?
- Is compatibility with official LocalSend clients a hard requirement, or only a convenience? If it is only a convenience, the protocol could move to its own authenticated session design sooner.
- How much of this should a non-technical person ever see? The diagnosis messages in 3.7 are the main user-facing part and need wording review.
