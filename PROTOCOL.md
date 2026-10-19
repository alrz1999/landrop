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
    -> 200 { sessionId, files: { id: token } } | 403 declined | 409 busy
- POST /api/localsend/v2/upload?sessionId=&fileId=&token=   body = raw bytes
- POST /api/localsend/v2/cancel?sessionId=

## Trust
Cert fingerprint pinned on first contact (TOFU) and shown in UI; receiver must accept each incoming request.
