# Transfer protocol (LocalSend v2 compatible subset)

Port: 53317 (TCP HTTPS + UDP multicast). Multicast group: 224.0.0.167.

## Device info (JSON)
{ "alias": str, "version": "2.1", "deviceModel": str?, "deviceType": "mobile|desktop|web|headless|server",
  "fingerprint": str (sha256 hex of device cert), "port": 53317, "protocol": "https", "download": false,
  "landrop": { capability record, see below; LanDrop extra field, ignored by LocalSend } }

## Discovery
1. UDP multicast: send device info + `"announce": true` to 224.0.0.167:53317 on start and every 5 s.
   LanDrop also sends the same datagram as UDP broadcast (`x.x.x.255` per interface and
   255.255.255.255) and tags each copy with `"landropVia": "multicast" | "broadcast"` (extra field),
   so the receiver knows which path got through. Untagged datagrams count as `announce`.
   Receivers reply via HTTP: POST /api/localsend/v2/register with own device info.
2. mDNS / DNS-SD (LanDrop extension, ignored by LocalSend): service type `_landrop._tcp.local` on
   224.0.0.251:5353. Instance `LanDrop-<first 8 hex of fingerprint>`, host `<instance>.local`, SRV port =
   HTTPS port, A records = IPv4 addresses, TTL 120 s, re-announced every 60 s, goodbye = TTL 0.
   TXT keys: `fp` (sha256 hex, 64 chars), `v` (=1), `alias`, `type` (deviceType), `port`.
   Trust rule: mDNS data is only a hint. A peer is added only after HTTPS GET /info presents the
   certificate whose fingerprint equals the claimed `fp`; the fingerprint in /info decides, never the TXT.
   The peer is then marked `foundVia: mdns`.
3. Fallback: scan the local /24 with GET /api/localsend/v2/info, manual IP entry.

## Endpoints (all HTTPS, self-signed cert)
- GET  /api/localsend/v2/info -> device info
- POST /api/localsend/v2/register -> device info (response = own info)
- POST /api/localsend/v2/prepare-upload  body { info, files: { id: {id,fileName,size,fileType,sha256?,
    preview?} }, landropProof? }
    -> 200 { sessionId, files: { id: token }, cancelSecret } | 204 text message shown (nothing to
       upload, see "Text messages") | 403 declined | 409 busy
    `cancelSecret` (LanDrop extra field) is a per-session secret; only the sender gets it.
    `landropProof` (LanDrop extra field, "Sender proof"): { cert: base64 DER of the sender's TLS
    certificate, sig: base64 RSA PKCS#1 v1.5 SHA-256 signature }. Signed bytes = UTF-8 of
    `landrop-prepare-v1\n<receiver fingerprint>\n<sender fingerprint>\n<digest>` where digest =
    lowercase hex SHA-256 of the files sorted by id, each as `<id>\t<fileName>\t<size>\n` (the
    values as sent, before any sanitising). The receiver treats the sender's fingerprint as proven
    only when sha256(cert) equals `info.fingerprint` and the signature verifies; a missing or wrong
    proof is not an error (the request is handled as from an unverified sender, e.g. LocalSend),
    but only proven fingerprints count for trust and auto-accept.
    `fileName` may be a relative path with `/` (folder transfer, e.g. `Photos/2024/a.jpg`).
- POST /api/localsend/v2/upload?sessionId=&fileId=&token=[&offset=N]   body = raw bytes
    -> 200 | 400 (short or oversized body) | 403 bad session/token | 409 { received } (offset mismatch,
       upload of this file still running, or already uploaded)
    `offset` (LanDrop extra): append from byte N; must equal the bytes the receiver already holds.
    Without `offset` the file is (re)written from byte 0 (plain LocalSend behaviour).
- POST /api/localsend/v2/cancel?sessionId=&cancelSecret=
    -> 200 | 403 when the session is unknown or the secret is missing/wrong.
    (A sender that does not know `cancelSecret`, e.g. an official LocalSend client, cannot cancel;
    the receiver then drops the session after its idle timeout.)
    The receiver can also end a session itself (its user pressed Cancel): the running upload is
    answered 409 (or the connection drops) at the next chunk, and every later upload and
    upload-status of that session gets 403, which a LanDrop sender reports as "cancelled".
- Withdraw (LanDrop extra, 2026-10-22): a LanDrop sender adds `landropWithdraw` (a random secret,
  at least 16 characters) to its prepare-upload body. While that request still waits for the
  receiver's answer, `POST /api/localsend/v2/cancel?withdrawSecret=<it>` ends it: the receiver
  closes its dialog, answers the waiting prepare-upload 403 and the cancel 200 (403 when nothing
  with that secret is waiting). The sender reports "cancelled". If the receiver had accepted just
  before, the sender cancels the new session with its `cancelSecret`. A receiver also ends a
  waiting request itself after `decisionTimeout` (default 2 min, 403 to the sender) and closes its
  dialog.

## Text messages (LocalSend v2 `preview`)
A short text or link is sent as a normal prepare-upload with exactly one file entry:
`{ id, fileName: "message.txt", size: <UTF-8 bytes of the text>, fileType: "text/plain", preview: <the text> }`,
so official LocalSend clients show it as a message too. The sender refuses an empty text or more
than 64 KiB (65536 UTF-8 bytes) without contacting the receiver. `landropProof` is the same as for
files (it signs id, fileName and size; `preview` travels inside the same pinned TLS connection).
- Receiver (LanDrop): a request is a text message only when it has one entry, its `fileType` starts
  with `text/plain` and `preview` is a non-empty string of at most 64 KiB; it never applies to
  browser uploads. Control characters other than tab and line breaks are removed; the text is shown
  as plain selectable text (never markup, never a clickable link; "Open link" appears only when the
  whole text is one `http`/`https` URL, and only on desktops). The request goes through the same
  decision as files: when the user sees it (or at once for a proven, trusted device with "Always
  accept"; never for an unverified sender) the receiver answers **204** and creates no session;
  nothing is written to disk unless the user picks "Save as file" (a unique `message.txt` in the
  save folder). Declined or unanswered: 403 as for files. Any other `preview` (too long, another
  type, several entries) is ignored and the entry is an ordinary file offer.
- Sender (LanDrop): 204 means delivered (`SendResult.ok`, no session id). A receiver that does not
  show previews answers 200 with a token, and `message.txt` is uploaded like any file (same
  pipeline, resume, cancel).

## LanDrop extensions (ignored by LocalSend clients)
- Capability record, in the info JSON as `landrop` and at GET /api/landrop/v1/capabilities:
    { "v": 1,
      "transports": [ { "id": "lan-https", "addrs": ["192.168.1.103", "192.168.43.1"], "port": 53317 },
                      { "id": "hotspot", "ssid": "AndroidShare_1234", "gateway": "192.168.43.1" } ],
      "features": ["resume", "folders", "browser-ui"] }
    `addrs` = the advertised IP plus the local IPv4 addresses on real interfaces (not VPN, not
    virtual such as Docker/VM bridges), ranked private first and link-local 169.254.x.x last
    (a direct cable has only those); receivers just try each, so they can be unreachable; re-read when discovery restarts (after joining or starting a hotspot).
    `hotspot` is present only while this device shares a hotspot it started from LanDrop (Android
    local-only hotspot): `ssid` = its network name, `gateway` = this device's address on it (omitted
    when unknown). The password is never sent. Parsers must ignore unknown transports, fields and
    features; a missing record means a plain LocalSend peer.

## Addresses and link selection (LanDrop sender)
- A peer is identified by its fingerprint. The same fingerprint seen at several addresses is one peer
  with several addresses; each address is verified (TLS certificate + info fingerprint) before use.
- To send, the sender probes every candidate endpoint in parallel with GET /api/localsend/v2/info:
  the peer's current IP, its other known addresses, then its `lan-https.addrs` (port = `lan-https.port`).
  An endpoint counts only when the presented certificate and the info's `fingerprint` both equal the
  peer's fingerprint. The fastest verified endpoint is used and remembered for 5 minutes.
- If an upload breaks or stalls, the sender switches to the next verified endpoint and resumes there
  with `upload-status` + `offset` (below). Receivers do not check the source address of uploads:
  `sessionId` + per-file `token` authenticate them, so a session may continue from another address.
- GET /api/landrop/v1/upload-status?sessionId=&fileId=&token=
    -> 200 { received, size, active, done } | 403 bad session/token
    `received` = bytes held in the temporary file; `active` = an upload connection for this file is
    still open on the receiver (the sender waits for it to end before resuming).

## Receiving
- Each file is written to a hidden temporary file `.<name>.part` in its target directory and renamed
  to a unique final name (`a (1).txt`) only after exactly `size` bytes arrived.
- A broken upload keeps its `.part`; the sender asks `upload-status` and resumes with `offset`
  (default: up to 3 retries, backoff 0.5 s doubling; an upload with no progress for 15 s counts as broken).
  The receiver keeps the session for `sessionIdleTimeout` (2 min) of inactivity. Cancel, idle timeout,
  a fatal error or stopping the receiver deletes the `.part` files (no resume across restarts).
- Folder paths: `\` counts as `/`; empty, `.` and `..` segments and a leading drive (`C:`) are dropped;
  each segment is sanitised like a file name (leading dots stripped). The top-level folder gets a
  unique name (`Photos (1)`) when it already exists, so folders never merge. Every directory created
  is checked (symlinks resolved) to be inside the save directory.

## Trust
Cert fingerprint pinned on first contact (TOFU) and shown in UI; receiver must accept each incoming request.

## Browser access (LanDrop only; DESIGN.md section 4)
Served on the HTTPS port and, when the owner turns it on, on a separate plain HTTP port
(default 53320, else a free port, same bind address). The HTTP listener serves only the paths
below; every other path, including all of `/api/localsend/v2/*`, `capabilities` and
`upload-status`, is 404 there. The info `landrop.features` list contains `browser-ui`.

Headers on every web response (page, JSON, file bytes, errors):
`Content-Security-Policy: default-src 'self'; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'; img-src 'self' data:; media-src 'self'; frame-ancestors 'none'`,
`Referrer-Policy: no-referrer`, `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`,
`Cache-Control: no-store`. JSON errors are `{ "message": ... }`.

- GET|HEAD /  (also /index.html) -> the self-contained page (inline CSS/JS, no external requests)
- GET  /api/landrop/v1/web/info -> { alias }
- GET  /api/landrop/v1/web/session -> 200 { paired: true, expiresIn } | 401
- POST /api/landrop/v1/web/logout  (cookie or Bearer token; Origin rule below applies)
    -> 200 { paired: false } + `Set-Cookie: landrop_session=; Max-Age=0; Path=/; HttpOnly;
       SameSite=Strict` (`; Secure` on HTTPS). Ends the caller's session if it has one (always
       200, so calling it twice is fine); afterwards the token gets 401 everywhere. The owner can
       also end a session from the app ("Connected browsers", Disconnect) with the same effect.
       Ending a session also cancels a receive session it prepared: its pending and running
       uploads are refused (403 on upload; a running upload is aborted with 409 or a closed
       connection and its `.part` deleted), and an
       upload-prepare still waiting for the owner's decision answers 401.
- POST /api/landrop/v1/web/pair -> 200 { id, code (4 digits), expiresIn } | 409 a pairing from this IP
    is already waiting | 429 rate limited or 5 pairings already waiting | 403 nobody to ask
    The app shows the same code with the browser summary ("Chrome on Android") and IP; the owner
    approves or declines. Unanswered pairings expire after 60 s.
- GET  /api/landrop/v1/web/pair/{id}  (long poll, up to 20 s; only from the IP that asked)
    -> 200 { status: "pending" } | 200 { status: "approved", token, expiresIn } + Set-Cookie
       | 403 { status: "declined" | "expired" } | 404 unknown id. The token is handed out once.
    Cookie: `landrop_session=<token>; Max-Age=3600; Path=/; HttpOnly; SameSite=Strict` plus `; Secure`
    on HTTPS only. The token (256-bit random) also works as `Authorization: Bearer <token>`. A
    session is valid for 1 h and only from the IP that paired.
- POST /api/landrop/v1/web/upload-prepare  (session required, else 401)
    body { files: [ { id, fileName, size, fileType? } ] } -> exactly the prepare-upload answer:
    200 { sessionId, files: { id: token }, cancelSecret } | 403 declined | 409 busy.
    Runs the same code as prepare-upload (Accept dialog with sender "Browser <ip>", device type
    `web`; names sanitised; folders get unique names). The receive session is bound to the browser
    session.
- POST /api/landrop/v1/web/upload?sessionId=&fileId=&token=[&offset=]  (session required, else 401)
    body = raw bytes; same handler and answers as /api/localsend/v2/upload (`.part` file, size check,
    unique final name), plus 403 when the receive session belongs to another browser session.
- GET  /api/landrop/v1/shares/{token} -> 200 { alias, files: [ { id, name, size, mime } ],
    expiresAt, expiresIn, maxDownloads, downloadsLeft } (null = no expiry / unlimited)
- GET|HEAD /api/landrop/v1/shares/{token}/files/{fileId}[?inline=1] -> the bytes, streamed from disk.
  Shares need no browser session: the token (128-bit random, base64url, 22 chars) is the credential.
  Unknown, expired, revoked and exhausted tokens, unknown file ids and files that changed size or
  disappeared since sharing all get the same 404 `{ "message": "not found" }`. File ids are random
  (16 hex), never paths. Share links are `https://<ip>:<port>/#s=<token>`: the token is in the
  fragment, so it is not sent in a request line, and `no-referrer` keeps it out of Referer.
  Range: `Accept-Ranges: bytes`; one range per request: `bytes=a-b` (end clamped), `bytes=a-`,
  `bytes=-n` -> 206 with `Content-Range: bytes a-b/size` and `Content-Length`; malformed, `b < a`,
  start >= size, `bytes=-0` -> 416 with `Content-Range: bytes */size`; several ranges
  (`bytes=0-1,5-6`) or a unit other than bytes -> the Range header is ignored and the whole file is
  sent with 200. `Content-Type` from the file extension (text types get `; charset=utf-8`).
  `Content-Disposition: attachment; filename="<ascii>"; filename*=UTF-8''<pct-encoded>`, or
  `inline` with `?inline=1` for video/*, audio/*, PNG/JPEG/GIF/WebP/AVIF/BMP, PDF and plain text/CSV/
  Markdown only (HTML, SVG, XML and other types are always attachments).
- Download counting (shares with a limit). A download is one client IP reading one file:
  1. A request from an IP with an open range sequence for that file (its last request less than
     30 min ago) is served free and keeps the sequence open (a `<video>` seeking).
  2. Otherwise, when no download is left (charged + full reads in flight >= limit): the 404 above.
  3. A partial range (anything but byte 0 to the last byte) starts a sequence and is charged at once.
     So rebuilding a file from ranges always costs a download.
  4. A full read (no Range, or a Range from 0 to the last byte) holds a slot while it runs and is
     charged only after every byte was written to the socket; an aborted full read is not charged.
  HEAD is never charged. The listing returns 404 once no download is left.
- Shares survive an app restart when "Keep shares after restart" is on (default): the same token
  works at the device's current address and port (the link in the app is rebuilt), with the
  remaining downloads and the original expiry. A share is dropped at restart when it expired,
  has no downloads left, or any of its files is gone or changed size.
- Rate limit, per remote IP: pairing requests, declined or expired pairings, unknown pairing ids,
  401s on upload endpoints, unknown/expired/exhausted share tokens or file ids count as attempts;
  at 10 within 1 minute every web API request from that IP gets 429 (the page itself still loads).
- Requests other than GET/HEAD with an `Origin` header whose host:port differs from `Host` get 403.

## Nearby shares (LanDrop apps only; docs/NEARBY_PLAN.md)

An owner can mark a share "Show to nearby devices". Trusted LanDrop apps (or apps the owner
approves for an hour) list it with a signed request; everyone else gets the same answer as
"no shares". HTTPS only: on the plain HTTP listener every `/api/landrop/v1/nearby/*` path is
the same 404 as an unknown path. Nothing under `/api/localsend/v2` is affected.

1. `POST /api/landrop/v1/nearby/challenge`, body `{"fingerprint": "<64 lowercase hex>"}`
   (at most 1024 bytes, not the receiver's own fingerprint). Answer
   `{"nonce": "<random>", "expiresIn": 30}`. The nonce is single use, bound to that
   fingerprint and the caller's address, valid 30 s. At most 20 challenges per minute per
   address (429), 4 outstanding nonces per address and 64 in all (503).
2. `POST /api/landrop/v1/nearby/list`, body (at most 24576 bytes)
   `{"fingerprint", "nonce", "cert": "<base64 DER, <=16384 chars>", "sig": "<base64, <=1024 chars>", "alias": "<optional, <=64>"}`.
   The signature is SHA-256/RSA (PKCS#1 v1.5) by the key of `cert` over these exact UTF-8 bytes
   (`\n` is a line feed; no trailing newline):

   ```
   landrop-nearby-v1\n<receiverFp>\n<requesterFp>\nPOST /api/landrop/v1/nearby/list\n<nonce>
   ```

   with `receiverFp` = fingerprint of the listing device, `requesterFp` = lowercase hex SHA-256
   of `cert`. The receiver removes the nonce first, then checks nonce/fingerprint/address,
   then `sha256(cert) == fingerprint`, then the signature (RSA key 2048 to 4096 bit), then
   whether the requester is trusted or granted. Any failure, an untrusted requester, and a
   trusted requester with nothing to list all get status 200 and exactly this body:
   `{"shares":[],"ticket":null,"ticketExpiresIn":0}`. A listing:
   `{"shares":[{"id","createdAt","expiresAt","downloadsLeft","truncated","files":[{"id","name","size","mime"}]}],"ticket":"lt1.<random>","ticketExpiresIn":600}`
   (at most 50 shares, 1000 files per share; never a path or share token).
3. `GET|HEAD /api/landrop/v1/nearby/shares/<shareId>/files/<fileId>` with the header
   `Authorization: LanDrop-Ticket <ticket>` (never in the URL). Range and the download limit
   work as for browsers. The ticket lives 10 minutes (fixed), belongs to the requester's
   address, and every request re-checks that the requester is still allowed and the share is
   still live and nearby. Any failure is `404 {"message":"not found"}`.
