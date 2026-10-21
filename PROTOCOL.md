# Transfer protocol (LocalSend v2 compatible subset)

Port: 53317 (TCP HTTPS + UDP multicast). Multicast group: 224.0.0.167.

## Device info (JSON)
{ "alias": str, "version": "2.1", "deviceModel": str?, "deviceType": "mobile|desktop|web|headless|server",
  "fingerprint": str (sha256 hex of device cert), "port": 53317, "protocol": "https", "download": false }

## Discovery
1. UDP multicast: send device info + `"announce": true` to 224.0.0.167:53317 on start and every 5 s.
   Receivers reply via HTTP: POST /api/localsend/v2/register with own device info.
2. Fallback: scan the local /24 with GET /api/localsend/v2/info, manual IP entry.

## Endpoints (all HTTPS, self-signed cert)
- GET  /api/localsend/v2/info -> device info
- POST /api/localsend/v2/register -> device info (response = own info)
- POST /api/localsend/v2/prepare-upload  body { info, files: { id: {id,fileName,size,fileType,sha256?} } }
    -> 200 { sessionId, files: { id: token }, cancelSecret } | 403 declined | 409 busy
    `cancelSecret` (LanDrop extra field) is a per-session secret; only the sender gets it.
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

## LanDrop extensions (ignored by LocalSend clients)
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
