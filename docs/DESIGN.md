# LanDrop design document

Status: living document. Last updated 2026-10-21.
Scope: everything built so far, plus the proposed next steps (transport negotiation and a browser / local stream server mode).

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
- `lib/core/discovery.dart`: pluggable discovery transport. The default is UDP multicast and broadcast. Tests inject an in-memory one.
- `lib/core/identity.dart`: self-signed RSA-2048 certificate, generated in Dart, stored under `<saveDir>/.landrop/`.
- `lib/core/util.dart`: file name sanitising, unique names, MIME guessing, local IPv4 lookup, VPN interface filter.
- `lib/core/web_server.dart`, `lib/core/web_assets.dart`: browser access (section 4.8).
- `lib/ui/`: Material 3 UI (home, settings, dialogs), `AppController` (a `ChangeNotifier`), a fake core for UI tests, and the Android helpers (`multicast_lock.dart`, `background_service.dart`, `storage_access.dart`).
- `android/app/src/main/kotlin/.../MainActivity.kt` and `LanDropService.kt`: multicast lock, foreground service.
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

A peer is added only after its certificate fingerprint matches what it claims in its info response. A peer not seen for 20 seconds is re-probed once and then dropped. VPN and tunnel interfaces (`utun*`, `tun*`, `wg*`, `ppp*` and similar) are skipped for announcing, joining and scanning, because they made one machine appear under two addresses.

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
- Permissions: INTERNET, ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE, CHANGE_WIFI_MULTICAST_STATE, FOREGROUND_SERVICE (data sync), POST_NOTIFICATIONS, WAKE_LOCK, MANAGE_EXTERNAL_STORAGE, and WRITE_EXTERNAL_STORAGE up to API 29.
- A `WifiManager.MulticastLock` must be held or Android drops incoming multicast.
- A foreground service (`LanDropService`) keeps the process and the server alive when the app is in the background or the screen is off. It also holds a Wi-Fi lock, which cut Wi-Fi latency. Without it Android froze the app and the server stopped answering.
- Swiping the app away stops the service and kills the process, so the server really stops.
- Settings has a "Keep running in background" switch and a "Quit LanDrop" button.
- Received files go to `Downloads/LanDrop` when the "All files access" permission is granted, so they show in the Files app. Otherwise they go to the app's hidden external folder. Only a folder chosen by the user is saved in settings, so the default can still change in later versions.
- `permission_handler` is pinned to 12.x because 13.x needs compileSdk 37 while the Android Gradle plugin in use stops at 36.

iOS (not built): needs `NSLocalNetworkUsageDescription` and `NSBonjourServices` in `Info.plist`, and the multicast networking entitlement for raw multicast. It also limits background execution, so the foreground-service approach does not carry over.

Windows, Linux (not built): the firewall must allow TCP and UDP on 53317. On Linux, `ufw` or `firewalld` may block it.

### 2.7 What has been verified, and how

- 17 automated tests pass (`flutter test`): a 20 MB transfer between two cores with a SHA-256 comparison, decline path, wrong fingerprint, path traversal, busy (409) handling, port fallback, discovery over an in-memory transport, and UI widget tests against a fake core. `flutter analyze` is clean.
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

### 3.5 Candidate transports

| Transport | Needs | Typical speed | Notes |
|---|---|---|---|
| lan-https | Shared IP network, not isolated | Wi-Fi speed | The default and the baseline. |
| hotspot | One device creates a hotspot, the other joins | Wi-Fi speed | Solves client isolation. Joining automatically needs OS APIs (Android local-only hotspot, iOS Network Extension); otherwise the app guides the user through it by hand. |
| wifi-direct | Android and Windows (Apple has its own peer-to-peer Wi-Fi) | Wi-Fi speed | No router at all. Platform code per OS, fragile across vendors. |
| ble | Bluetooth Low Energy | Under 100 KB/s | Rendezvous and handshake only, for example to exchange the hotspot name or IP. Not for bulk data. |
| relay / WebRTC | Internet and a signalling server | Varies | For devices on different networks. Out of scope until needed. |

### 3.6 Selection algorithm

1. Rendezvous by every available method at once (multicast, broadcast, scan, BLE). Merge peers by fingerprint, not by address.
2. For a chosen peer, compute the intersection of its advertised transports and the local ones that `isAvailable()`.
3. Probe the top candidates in parallel with a short timeout (similar to "happy eyeballs"): open a link and time a small request. Prefer the lowest round trip among those that work, with `basePriority` as the tie-break.
4. Cache the winner per peer fingerprint, with an expiry, so the next transfer starts immediately.
5. During a transfer, if no bytes move for N seconds, fall back to the next candidate and continue from the last confirmed byte. This needs resumable uploads (section 5).

### 3.7 Guided diagnosis

When no transport reaches a peer, run rules over what was observed and show the cause in plain words:

- Peer seen over BLE but not on the LAN: "Both devices are near, but Wi-Fi is blocked between them. Try a hotspot."
- Ping works but the HTTPS port does not answer: "The other app is not running or its firewall blocks port 53317."
- Peer visible only by manual IP, never by announce: "Your router blocks multicast and broadcast. Transfers still work with the IP."
- A VPN interface is active: "Turn off the VPN or allow local network access."
- Discovery socket failed to start: show the error that is currently only written to stderr.

This turns the troubleshooting list from the start of the project into code.

### 3.8 Implemented (2026-10-21): capability record and guided diagnosis, LAN only

- Capability record (3.3) is served in the info JSON (`landrop`) and at `GET /api/landrop/v1/capabilities`, with one transport (`lan-https`, local non-VPN IPv4 addresses, port) and the features `resume`, `folders`. Peers' records are parsed into `DeviceInfo.capabilities`. No transport selection yet (3.4-3.6 not started).
- Each peer records how it was found in `DeviceInfo.foundVia`: `multicast` / `broadcast` (LanDrop tags its datagrams with `landropVia`; the receive API cannot see the destination), `announce` (untagged, e.g. LocalSend), `register`, `scan`, `manual`.
- `lib/core/diagnosis.dart`: pure rules over a `DiagnosisInput` (discovery error, interfaces, own server listening, peers and how found, optional probe of a target IP: TCP connected / refused / timeout / unreachable, then TLS + info and fingerprint check). Rules: server down, discovery failed, no LAN address, VPN active, peers only by scan/manual (router blocks multicast and broadcast), probe refused, timeout, unreachable, fingerprint mismatch, not LanDrop, different /24, probe ok, all good; plus a network summary.
- `LanDropCore.runDiagnosis({targetIp, targetPort})` gathers the observations and runs the rules. The UI shows it from the empty peer list ("Why can't I see my device?"), from Settings ("Diagnose connection") and after a failed Add by IP ("Diagnose this IP"), with "Run again" and "Copy report" (plain text, fingerprints shortened).
- Not done: BLE and ping-based rules (no BLE, no ICMP from Dart without privileges); the subnet rule assumes /24 netmasks.

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

- Android: the foreground service already keeps the server alive, so a share stays reachable with the screen off. The notification should say when a share is active.
- iOS: the server stops when the app is suspended, so browser mode works only while the app is open.
- Desktop: works as is. A headless mode (no UI) becomes possible later because the core has no Flutter dependency.

### 4.7 Relationship to transport negotiation

The browser is just another client of the `lan-https` transport. It cannot use Wi-Fi Direct or BLE (browsers expose Web Bluetooth only partially, and not on iOS), so negotiation does not apply to it. The guided diagnosis from 3.7 still helps: if a browser cannot load the page, the same "AP isolation, VPN, firewall" explanation applies.

### 4.8 Implemented (2026-10-21): web page, pairing, browser upload, shares, range streaming, plain HTTP opt-in

Where it differs from 4.1-4.6 (wire details in PROTOCOL.md, "Browser access"):

- `lib/core/web_server.dart` (`WebService`) and `lib/core/web_assets.dart` (the page as a Dart string). The core only routes web paths to it and lends it its receive pipeline: `prepare-upload` was split so `_prepareIncoming` (sanitising, Accept dialog, sessions) serves both LocalSend senders and browsers, and the upload handler takes an optional browser-session owner. No upload safety logic is duplicated.
- Browser uploads do not call `prepare-upload`/`upload` directly (4.3) but `web/upload-prepare` and `web/upload`, which require a paired browser session and then run the same code. The owner still sees the normal Accept dialog ("Browser <ip>") and the transfer in the normal list.
- Pairing (4.5): no token in the QR fragment. The browser asks (`web/pair`), both screens show a 4-digit code, the owner approves. Result: a 1-hour HttpOnly, SameSite=Strict cookie (also usable as a Bearer token), bound to the browser's IP. 60 s timeout, at most 5 pairings waiting, one per IP, and a per-IP limit of 10 failed attempts a minute (429).
- Shares: `createShare` (files or folders, folders keep relative paths), expiry (15 min / 1 h / 24 h / until stopped) and a download limit (unlimited / 1 / 5) in the UI. Links are `https://ip:port/#s=<token>` with the token in the fragment. Range requests as in 4.2 mode 3, so `<video>`/`<audio>` previews seek. A limited share counts one download per client per file; ranges are charged at the first partial request, so they cannot be used to bypass the limit (rule in PROTOCOL.md and on `WebService`). Shares live in memory only and do not survive an app restart.
- The plain HTTP listener (4.4 option 2) exists as an opt-in Settings switch with a confirmation dialog, off by default, on port 53320 (or a free one). It serves only the page, the web endpoints and shares, never the LocalSend device API, and its cookie is not `Secure`.
- UI: "Share with a browser" section and a Shares screen (app bar) with link, QR, copy, remaining time and downloads, Stop sharing; a "Use from a browser" card with the address, QR and how to get past the certificate warning; the pairing dialog is queued with incoming requests.
- Verified: `flutter test` (web_test.dart: ranges incl. 5 MB reassembly by sha256, identical 404s, traversal, limits, pairing, rate limit, timeout, HTTP listener, page static checks, a 30 MB two-core end-to-end run) and one manual run in a Chromium-based browser pane over the plain HTTP listener on loopback: page, audio preview, pairing and a 3 MB upload, byte-identical.
- Not done: the Android notification does not mention active shares (4.6); no live streaming (mode 4); no logout endpoint (sessions just expire); not tried on real phones, Safari, Firefox, or over HTTPS with a real certificate warning; no scripted headless-browser test (section 7).

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
3. Transport interface with `lan-https` as the only implementation, capability record, guided diagnosis.
4. Browser mode: web page, shares, range streaming, pairing.
5. Hotspot assist, then Wi-Fi Direct (Android first), then BLE rendezvous.
6. iOS build and the iOS-specific permissions.
7. Relay or WebRTC, only if there is real demand.

Steps 3 and 4 are independent and can be built in parallel.

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
