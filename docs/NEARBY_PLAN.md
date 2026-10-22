# Nearby shares: implementation plan

Status: plan (written by a read-only planning agent, 2026-10-22). Decision from the product
owner: an owner can mark a share "Show to nearby devices" (default OFF). Only **connected or
trusted** devices can list it: (a) a LanDrop app that proves its identity with a signed request
AND is in the owner's trusted-devices store (or is approved by the owner for a while), (b) a
browser with an approved pairing session. Everyone else gets exactly the same response as "no
shares".

New endpoints live under `/api/landrop/v1/`; nothing under `/api/localsend/v2` changes.

Facts about the code this plan relies on:

- `lib/core/web_server.dart`: `webTokenKey` (l.38); shares/sessions are maps keyed by it; `_Share`
  (l.245) has `toJson`/`fromJson`, files carry `path`; `WebService.handle` (l.848) checks
  `validWebHost`, then `_limited(ip)`, then `_sameOrigin` for non-GET, then switches on path
  segments after `/api/landrop/v1`; `handles()` (l.823) covers `web/` and `shares/`;
  `_file(req, ip, token, fileId, head:)` serves files with the download counting rule;
  `_sessionOf(req, ip)`; `revokeSession(id)`; `_fail(ip)`/`_limited(ip)` (10 failures/min).
- `lib/core/landrop_core.dart`: `_handle` sends any `_web.handles(path)` to
  `_web.handle(req, secure: true)` first; `_senderProven` (cert <= 16384 b64 chars, sig <= 1024,
  `fingerprintOfDer(cert) == claimed`, then `verifyCertSignature`); client side `_newClient(expectFp:)`
  and `_checkPeerCert`; `AttemptLimiter` is in `lib/core/util.dart`; `sanitizeFileName`,
  `sanitizeDisplayText`, `reserveUniqueFile` also in util.dart.
- `lib/core/identity.dart`: `verifyCertSignature(certDer, data, sig)`, `senderProofMessage(...)`,
  `TlsIdentity.sign(data)`.
- `lib/ui/app_controller.dart`: `_trusted` (`Map<String, TrustedDevice>`), `trustedDevices`,
  `trustedDevice(fp)`, `removeTrusted(fp)`, accept-and-trust path, `createShare` forwarding.
- The trusted store lives in the UI layer, so the controller pushes the set of trusted
  fingerprints into the core.
- Browser page: `lib/core/web_assets.dart` (own en/fa string tables). The CSP script hash is
  computed automatically.

## 1. Protocol

Handled inside `WebService.handle`. Extend `handles()` with `path.startsWith('$webApiBase/nearby/')`.
The existing Host check (S2, 421), per-IP failure limit and Origin check then apply.

On the plain-HTTP listener (`secure == false`) every `nearby/*` path returns 404 "not found", the
same as an unknown path. App-to-app traffic is HTTPS only. The app endpoints must work when
browser access is OFF (let `nearby/*` through any "enabled" gate on the HTTPS server; the browser
endpoints `web/nearby*` keep the existing gate).

### 1.1 Signed message (identity.dart, next to `senderProofMessage`)

```dart
List<int> nearbyProofMessage(String receiverFp, String requesterFp,
        String method, String path, String nonce) =>
    utf8.encode('landrop-nearby-v1\n$receiverFp\n$requesterFp\n$method $path\n$nonce');
```

Fingerprints are lowercase hex SHA-256 of the cert DER (64 chars). `path` is exactly
`/api/landrop/v1/nearby/list`, `method` is `POST`. Signature SHA-256/RSA via `TlsIdentity.sign`.

### 1.2 `POST /api/landrop/v1/nearby/challenge`

- Body JSON <= 1024 bytes (`_readJson(req, max: 1024)`, larger gives 413):
  `{"fingerprint": "<64 lowercase hex>"}`. Must match `^[0-9a-f]{64}$` and not be our own
  fingerprint, else 400 "invalid fingerprint".
- Rate limit: `AttemptLimiter _nearbyLimiter = AttemptLimiter(limit: 20, window: 1 min, maxKeys: 1024)`
  keyed by IP. EVERY challenge call is a hit. If already limited answer 429 "too many attempts"
  before reading the body.
- Nonce store `_nearbyNonces: Map<webTokenKey(nonce), _NearbyNonce{fp, ip, expires}>`. Lives 30 s.
  Global cap 64, at most 4 per IP. Prune expired first; if still full answer 503 "busy". Also prune
  in the existing 15 s `_prune` timer.
- 200: `{"nonce": "<randomToken(32)>", "expiresIn": 30}`

### 1.3 `POST /api/landrop/v1/nearby/list`

Body <= 24576 bytes (413 above):
`{"fingerprint": "<hex64>", "nonce": "<str <=128>", "cert": "<b64 DER <=16384 chars>", "sig": "<b64 <=1024>", "alias": "<optional <=64>"}`.
Wrong type/length gives 400 "invalid body" and `_nearbyLimiter.hit(ip)`.

Check order (do NOT reorder; protects against the S3 CPU DoS):
1. Look up `webTokenKey(nonce)` in `_nearbyNonces` and REMOVE it at once (single use, even on failure).
2. Missing, expired, `n.fp != fingerprint` or `n.ip != ip` -> DENY.
3. `fingerprintOfDer(base64Decode(cert)) != fingerprint` -> DENY.
4. `!verifyCertSignature(cert, nearbyProofMessage(selfFp, fingerprint, 'POST', '/api/landrop/v1/nearby/list', nonce), sig)` -> DENY.
5. Proven. Allowed if `fingerprint` is in `_nearbyAllowed` (trusted set pushed from the UI) or has an
   unexpired grant in `_nearbyGrants` (`Map<fp, DateTime expiry>`).
6. Proven but not allowed: maybe raise the owner prompt (1.6), then DENY.

DENY = `_nearbyLimiter.hit(ip)` for steps 2-4 only (not step 6), then respond with the EMPTY body,
which must be byte-identical in every case (denied, allowed with no nearby shares, ...), built from
one `static const _emptyNearby`:
`{"shares":[],"ticket":null,"ticketExpiresIn":0}`

ALLOWED with at least one live share whose `nearby == true`: issue a ticket (1.4), respond 200:

```json
{"shares":[{"id":"<share id>","createdAt":"<iso utc>","expiresAt":"<iso utc>|null",
            "downloadsLeft":<int>|null,"truncated":false,
            "files":[{"id":"<file id>","name":"<name>","size":<int>,"mime":"<mime>"}]}],
 "ticket":"<ticket>","ticketExpiresIn":600}
```

Never include `token`, `path`, `url` or any local path. Write a dedicated `_Share.toNearbyJson()`;
do NOT reuse `toJson` or `_snapshot`. Caps: at most 50 shares (newest first), at most 1000 files per
share (if cut, `truncated: true`); skip expired shares and shares with no download slots left.

### 1.4 Ticket

- Format `"lt1." + randomToken(32)`; sent as header `Authorization: LanDrop-Ticket <ticket>`, never in
  the URL. Header value at most 256 chars, otherwise 404.
- Stored as `_nearbyTickets: Map<webTokenKey(ticket), _NearbyTicket{fp, ip, expires}>`. Lifetime 10 min
  fixed (no sliding). A running transfer is not cut when the ticket expires; the check is at request
  start. Caps: 4 tickets per fp (evict oldest), 256 globally (evict oldest). Prune in `_prune`.
- Re-checked on EVERY file request: ticket exists and unexpired; `ticket.ip == ip`; `ticket.fp` still
  in `_nearbyAllowed` or has an unexpired grant; the share exists, is live and has `nearby == true`.
  Any failure -> 404 "not found" (same as a wrong share token) and `_fail(ip)`.

### 1.5 `GET|HEAD /api/landrop/v1/nearby/shares/<shareId>/files/<fileId>`

Header `Authorization: LanDrop-Ticket <ticket>`. Refactor `_file(...)` into a shared
`_serveFile(HttpRequest req, String ip, _Share s, String fileId, {required bool head})`: the token
route resolves `_liveShare(token)`, the ticket route resolves `_nearbyShare(shareId)`; both call
`_serveFile`, so Range handling, per-IP download counting, the S12 symlink re-check and 404/416
behaviour stay identical. Add an id lookup (secondary map `id -> _Share` kept in create, revoke,
restore, or iterate the map).

### 1.6 Owner approval prompt (requester proven but not allowed)

Raise a `NearbyAccessRequest` on `nearbyRequests` ONLY IF: the stream has a listener, at least one
live nearby share exists, no prompt is pending for this fp, the fp is not in the deny cooldown, and
fewer than 3 prompts are pending globally. The requester still gets the EMPTY body. A prompt expires
after 60 s (treated as deny, no cooldown). `alias` shown to the owner:
`sanitizeDisplayText(knownPeerAlias ?? bodyAlias ?? '', max: 64)` plus the first 8 hex of the fp.
Decisions: deny -> 10 min cooldown for that fp; allowOnce -> `_nearbyGrants[fp] = now + 1 h`;
alwaysAllow -> the core adds a 1 h grant and the controller adds the device to the trusted store
(which re-pushes the set). The requester sees results after it refreshes (no push channel).

### 1.7 Browser endpoints (paired session = approved pairing)

- `GET /api/landrop/v1/web/nearby`: no/invalid session -> `_fail(ip)` and 401 "not paired". 200: same
  shape as 1.3 without `ticket`/`ticketExpiresIn`: `{"shares":[...]}` (empty list when none).
- `GET|HEAD /api/landrop/v1/web/nearby/<shareId>/files/<fileId>`: session via cookie (so `<video src>`
  and `<a download>` work). No session 401; not nearby/unknown/expired 404; otherwise `_serveFile`.
- Disconnect revocation: `revokeSession` already deletes the session; in-flight streams finish their
  current response only.

### 1.8 Status codes

200 OK (including the denied empty body); 206/416 Range unchanged; 400 malformed; 401 browser without
session; 404 unknown/unauthorized/expired file or ticket, or plain HTTP; 413 body too big; 421 bad
Host; 429 rate limited; 503 nonce store full.

## 2. Data model

- `_Share` (web_server.dart): add mutable `bool nearby` (default false); `toJson` adds `'nearby'`,
  `fromJson` reads `j['nearby'] == true` (missing or non-bool gives false); add `toNearbyJson()`.
- `Share` (api.dart): add `final bool nearby;` filled in `_snapshot`.
- New in api.dart: `NearbyFile{id,name,mime,size}`; `NearbyShare{id, createdAt, expiresAt,
  downloadsLeft, truncated, files}`; `NearbyListing{peerFingerprint, shares, ticket, ticketExpires}`
  (ticket kept in memory only, never logged or persisted); `NearbyAccessRequest{id, fingerprint, alias,
  remoteIp, at}`; `enum NearbyDecision { deny, allowOnce, alwaysAllow }`.
- `WebService` in-memory state (never persisted; grants and tickets die on restart):
  `_nearbyAllowed`, `_nearbyGrants`, `_nearbyDenyUntil`, `_nearbyPending`, `_nearbyNonces`,
  `_nearbyTickets`, `_nearbyLimiter`.
- Settings: nothing new (the trusted store in app_controller is the source of truth).

## 3. Core API

`WebService`: `Share createShare(paths, {ttl, maxDownloads, bool nearby = false})`;
`void setShareNearby(String id, bool on)` (emits shares and persists); `void setNearbyAllowed(Set<String>)`
(replaces the set, drops grants/tickets/pending prompts of removed fps); `void revokeNearbyAccess(fp)`;
`Stream<NearbyAccessRequest> get nearbyRequests`; `void respondNearbyAccess(id, NearbyDecision)`;
`@visibleForTesting Iterable<String> get debugNearbyTicketKeys`; injectable clock (reuse the existing
one or add `DateTime Function() now`).

`LanDropCore`: the forwards above plus the client side:
- `Future<NearbyListing> listNearbyShares(DeviceInfo peer)`: uses `_newClient(expectFp: peer.fingerprint)`
  and `_checkPeerCert` (a mismatch throws, no list request sent); `StateError` when `identity == null`.
  Step 1 POST challenge `{"fingerprint": identity.fingerprint}`; step 2 POST list with cert
  `base64Encode(identity.certDer)`, sig `identity.sign(nearbyProofMessage(peer.fingerprint,
  identity.fingerprint, 'POST', '/api/landrop/v1/nearby/list', nonce))` and alias. Read at most 4 MB.
  Validate types, drop malformed entries, names through `sanitizeDisplayText`. 10 s timeout per call.
- `Future<void> downloadNearby(DeviceInfo peer, NearbyListing listing, List<(String shareId, String fileId)> items)`:
  ticket header, pinned client; save into the normal receive directory with
  `reserveUniqueFile(dir, sanitizeFileName(name))` (S6/S13); folder-style names keep relative structure
  with each segment sanitised (reuse the receive path's logic); check free space first (S18 helper);
  write `.part` then rename; abort if more bytes arrive than listed; report progress through the SAME
  `TransferProgress` stream/objects the receive path uses (peer as sender) so existing transfer cards,
  cancel and open work unchanged; cancel closes the request and deletes `.part`; a 404 mid-way
  (revoked) marks the file failed.
- App streaming is NOT in v1 (platform players reject the self-signed cert); streaming is a browser
  feature (Range + cookie).

`AppController`: `setShareNearby(id, on)`; `createShare(..., {bool nearby = false})`;
`_syncNearbyTrust()` = `core.setNearbyTrusted(_trusted.keys.toSet())` called after settings load, at the
end of `removeTrusted`, after the accept-and-trust path, and after alwaysAllow; subscribe to
`core.nearbyRequests` and expose a queue (`pendingNearbyRequest`); `answerNearbyRequest(id, decision)`
(on alwaysAllow add a `TrustedDevice(fingerprint, alias, trustedAt, alwaysAccept: false)`, persist, and
`_syncNearbyTrust()`).

## 4. UI

- Share options sheet (Grep `maxDownloads` in lib/ui): `SwitchListTile` "Show to nearby devices"
  (default OFF) passed to `createShare(nearby:)`; the same toggle on an active share card/menu calling
  `setShareNearby`. Subtitle: "Only devices you trust and browsers you approved can see it."
- Device Details sheet: new section "Nearby shares". On open, if the peer has a fingerprint and is a
  LanDrop app, call `listNearbyShares(peer)` with a spinner; list shares, each expandable with file
  checkboxes (name, size); buttons "Download selected ({count})" and "Refresh". Empty/error: "Nothing
  shared with you" + hint. Downloads show in the existing transfer cards. Re-list automatically before
  downloading when the ticket has expired.
- Owner prompt dialog when `pendingNearbyRequest != null`: title "{alias} wants to see your nearby
  shares", shows the fp prefix; buttons Deny / Allow for 1 hour / Always allow (trust).
- Strings (add to app_en.arb and app_fa.arb, then `flutter gen-l10n`):
  `shareShowNearby` "Show to nearby devices" / «نمایش به دستگاه‌های نزدیک»;
  `shareShowNearbyHint` "Only devices you trust and browsers you approved can see it." / «فقط دستگاه‌های مورد اعتماد و مرورگرهای تأییدشده آن را می‌بینند.»;
  `nearbySharesTitle` "Nearby shares" / «اشتراک‌های نزدیک»;
  `nearbyEmpty` "Nothing shared with you" / «چیزی با شما به اشتراک گذاشته نشده»;
  `nearbyEmptyHint` "If you expected files, the owner may need to allow this device." / «اگر انتظار فایلی داشتید، شاید صاحب دستگاه باید این دستگاه را مجاز کند.»;
  `nearbyDownloadSelected` "Download selected ({count})" / «دانلود موارد انتخاب‌شده ({count})»;
  `nearbyRefresh` "Refresh" / «تازه‌سازی»;
  `nearbyTruncated` "Some files are not listed" / «برخی فایل‌ها نمایش داده نشده‌اند»;
  `nearbyAccessTitle` "{alias} wants to see your nearby shares" / «{alias} می‌خواهد اشتراک‌های نزدیک شما را ببیند»;
  `nearbyAccessDeny` "Deny" / «رد»; `nearbyAccessOnce` "Allow for 1 hour" / «اجازه برای ۱ ساعت»;
  `nearbyAccessAlways` "Always allow (trust)" / «همیشه اجازه بده (اعتماد)».
- Browser page (`web_assets.dart`): after pairing, fetch `web/nearby`; if shares exist render a
  "Shared with this browser" section with per-file "Download" (`<a download href>`) and, for `video/*`
  and `audio/*`, "Play" (inline `<video controls src>`). Only `textContent`, never `innerHTML`. Page
  strings (en/fa tables): `nearbyTitle` "Shared with this browser" / «به اشتراک گذاشته‌شده با این مرورگر»;
  `nearbyNone` "Nothing shared yet" / «هنوز چیزی به اشتراک گذاشته نشده»; `nearbyPlay` "Play" / «پخش»;
  `nearbyDownload` "Download" / «دانلود»; `nearbyRefresh` "Refresh" / «تازه‌سازی».

## 5. Tests (names and what they assert)

Functional (`test/nearby_test.dart`):
- N1 nearby flag persists (restore; missing key restores false). N2 trusted app lists nearby shares
  (correct names/sizes, non-null ticket). N3 non-nearby shares hidden. N4 download via ticket (identical
  bytes, TransferProgress, unique name on collision). N5 Range via ticket (206, right bytes). N6 download
  limit applies (`maxDownloads: 1`; second full read 404). N7 owner prompt (one request, only when a
  nearby share exists; allowOnce lets next list succeed; deny gives no new prompt for 10 min, fake clock).
  N8 alwaysAllow trusts (TrustedDevice added, allowed set contains fp). N9 browser lists and streams
  (paired session; unpaired 401). N10 LocalSend v2 unaffected (existing suite green).

Security (`test/security_c_test.dart`):
- C1 listing leaks no path or token (list response and `web/nearby` contain no share token, `"path"`,
  temp dir path, `url`). C2 denied response is byte-identical in four cases (unproven, proven but
  untrusted, trusted with no nearby shares, bad signature) and equals the empty body. C3 nonce single use
  (replay gives empty). C4 nonce bound to fingerprint. C5 signature bound to path and receiver. C6 nonce
  expires (clock +31 s). C7 cert/fp mismatch and oversize (cert of 16385 chars gives empty without
  verifying; huge modulus under 50 ms). C8 challenge rate limit (21st in a minute 429). C9 nonce store cap
  (5th outstanding per IP 503; global 64). C10 body caps (challenge > 1 KB and list > 24 KB give 413).
  C11 listing caps (60 shares list 50; 1001 files list 1000 with `truncated: true`). C12 ticket keys are
  hashed (`debugNearbyTicketKeys` lacks the raw ticket, has `webTokenKey(ticket)`). C13 ticket revoked on
  stop sharing / toggle off / untrust. C14 ticket expires (clock +601 s). C15 ticket bound to IP. C16
  ticket not accepted in URL (`?ticket=` 404). C17 browser disconnect revokes (401 afterwards). C18 Host
  header (`evil.example` gives 421). C19 plain HTTP has no app nearby endpoints (404). C20 client pins peer
  cert (fingerprint mismatch throws, no list request sent). C21 downloaded names sanitised (bidi override,
  `CON.txt`; never through a pre-existing symlink).

Docs: add S24-S27 rows to docs/SECURITY.md (all fixed with test names); add a "Nearby shares" section to
PROTOCOL.md with the exact signed bytes from 1.1.

## 6. Implementation order (each step ends with `flutter analyze --no-pub` clean and `flutter test --no-pub` green)

1. Model and browser side: `_Share.nearby` + persistence, `Share.nearby`, `createShare(nearby:)`,
   `setShareNearby`, `toNearbyJson`; the `_serveFile` refactor (existing share tests stay green as proof);
   `web/nearby` routes; browser page section and strings. Tests: N1, N3 (browser variant), N9, C1 (browser
   part), C17.
2. App protocol, server side: `nearbyProofMessage`; challenge, list, ticket and files routes; limiter,
   caps, nonces, tickets, allowed set, grants, prompts, pruning; the `secure` gate and enabled-gate bypass.
   Tests (hand-built client that signs with a test `TlsIdentity`): C2-C16, C18, C19, N5, N6.
3. Client side and controller: `listNearbyShares`, `downloadNearby`, forwards; `_syncNearbyTrust` hooks;
   prompt queue and `answerNearbyRequest`. Tests: N2, N4, N7, N8, C20, C21.
4. App UI and docs: share-options toggle, Details sheet section, owner dialog, ARB keys (en and fa) and
   gen-l10n; PROTOCOL.md and SECURITY.md S24-S27; full suite again (N10).

## 7. Risks and what NOT to do

- Do NOT reuse `_Share.toJson()` or the `Share` snapshot for listings (they contain `path`, `token`, `url`).
- Do NOT put tickets, nonces or tokens in URLs, query strings, logs or the shares store file. Never log
  the request body.
- Do NOT verify the RSA signature before the nonce passes (S3 CPU DoS would return).
- Do NOT return 401/403 or any distinct status/body for "untrusted" vs "no shares"; one constant body, no
  "pending" flag.
- Do NOT treat share ids in a ticket as authority: re-check share liveness, `nearby` and trust on every
  request.
- Do NOT serve `nearby/*` app endpoints over plain HTTP, and do not let the browser cookie authorise the
  app ticket route (or the reverse).
- Do NOT touch `/api/localsend/v2/*` handlers, `_limitedPaths` semantics or `senderProofMessage`.
- Do NOT persist grants or tickets. Do NOT auto-trust on allowOnce. Do NOT key any new map by a raw secret
  (always `webTokenKey`).
- Risk: `_handle` dispatches `_web.handles` first, so keep all new paths under `nearby/`.
- Risk: owner prompt spam (mitigated by per-fp pending limit, 10 min deny cooldown, 3 global pending, per-IP
  limiter; prompts appear only when a nearby share exists).
- Risk: IP binding breaks if the requester switches interface; accepted, the client re-lists once on 404.
- Risk: clock checks must use the injectable clock in tests or C6/C14 flake.
- Risk: the `_serveFile` refactor can regress the download counting rule; keep existing web tests green
  before adding nearby routes (step 1).
