# LanDrop security

Status: review of 2026-10-22 (work in progress; the table below says what is fixed).
This document describes what LanDrop defends against, what was found in a review of the
code as an attacker on the same network would see it, and what is accepted.

## 1. Threat model

LanDrop runs an HTTPS server (port 53317, LocalSend v2 compatible), UDP discovery
(224.0.0.167:53317 multicast + broadcast), mDNS (`_landrop._tcp`), and optionally a plain
HTTP listener for browsers. The repository is public, so attackers know the protocol.

Attackers considered:

- **Unauthenticated LAN attacker**: can send any TCP/UDP traffic to the device, spoof UDP
  source addresses, run its own TLS servers with any certificate, and read plain HTTP.
- **Malicious sender**: speaks valid LanDrop/LocalSend and tries to abuse a receiver (file
  names, sizes, paths, text, trust/auto-accept, resource use).
- **Malicious receiver**: tries to abuse a sender (replaying its signed proof, wrong answers).
- **Browser user with a pairing session**: has a valid web session token.
- **Malicious web page** in another tab on the same machine or LAN: CSRF and DNS rebinding
  against the web endpoints.
- **Malicious local app on Android**: shares crafted content URIs to LanDrop.

Out of scope: an attacker with code execution as the same OS user (can read the identity
key and settings anyway), a stolen device key (it then *is* that device), physical access,
and the security of the operating system's file opener.

Security properties that hold (with the test or code reference):

- Peers are identified by the SHA-256 fingerprint of their TLS certificate; the sender pins it
  (`_newClient`, `_checkPeerCert` in `lib/core/landrop_core.dart`; test "wrong pinned
  fingerprint" in `test/core_test.dart`).
- The receiver must accept every request; trust/auto-accept needs a signed proof
  (`landropProof`, `_senderProven`; `test/trust_test.dart`).
- Uploads need the 128-bit per-file token from the accepted session (`_authFile`).
- Received names are sanitised and every directory is checked with symlinks resolved
  (`sanitizeRelativePath`, `isWithinDir`).

## 2. Findings

Severity: High (remote, unauthenticated, real impact), Medium, Low, Info.
Status: fixed (with the test that covers it), accepted (reason in section 3), open.

| ID | Severity | Component | Description | Status | Test |
|----|----------|-----------|-------------|--------|------|
| S1 | High | HTTPS server, HTTP listener | No limit on concurrent connections, no TLS handshake timeout, no timeout while a request body arrives: a few slow sockets hold the server forever (slowloris) and can exhaust file descriptors. | fixed | security_a_test.dart: S1 connection limits (6 tests) |
| S2 | Medium | web endpoints | No Host header check: DNS rebinding lets a web page on another origin talk to the web API as same-origin (the Origin check compares Origin with an attacker-chosen Host). | fixed | security_a_test.dart: S2 Host header |
| S3 | Medium | prepare-upload proof | `landropProof` is verified with the key in an attacker-supplied certificate; a huge modulus or public exponent makes the pure-Dart RSA verify take seconds to minutes on the UI isolate (unauthenticated CPU DoS). | fixed | security_a_test.dart: S3 sender proof key size (2 tests) |
| S4 | Medium | discovery, mDNS, register | Each UDP announce, mDNS record or register call makes the device open an outbound TLS connection to an attacker-chosen address and port, without any throttle (spoofed UDP turns the device into a connection flooder); unverified mDNS observations and the peer table grow without bound. | fixed | security_a_test.dart: S4 discovery abuse (5 tests) |
| S5 | Medium | prepare-upload | No cap on the number of files (16 MB body), file id/name/type length, or size; sizes can overflow the 64-bit total, which bypasses the 2 GB auto-accept limit for a trusted device. | fixed | security_a_test.dart: S5 prepare-upload limits (2 tests) |
| S6 | Medium | file names, aliases | Unicode bidi overrides/isolates and other invisible format characters in received file names and peer aliases allow spoofing (`invoice‮fdp.exe`); Windows reserved names (`CON`, `NUL.txt`) are kept; the 200-character cap can exceed 255 UTF-8 bytes. | fixed | `test/security_b_test.dart` "S6 names and aliases" (4 tests) |
| S7 | Low | text messages | `isWebLink` accepts bidi/format characters, so "Open link" can open a different URL than the one displayed. | fixed | `test/security_b_test.dart` "S7 isWebLink"; `test/text_test.dart` |
| S8 | Medium | FileOpener | "Open" on a received executable, script or app bundle (e.g. a folder `Evil.app`) runs it. | fixed | `test/security_b_test.dart` "S8 FileOpener" (3 tests, fake runner) |
| S9 | Medium | Android manifest | `allowBackup` defaults to true: the identity key and settings go into device/cloud backups and can be restored elsewhere (cloned identity). | fixed | none (manifest + `res/xml/data_extraction_rules.xml`; compiled in CI only) |
| S10 | Medium | Android share target | `content:` URIs of LanDrop's own providers are copied (confused deputy: another app can make LanDrop read its own private files). | fixed | none (Kotlin `isOwnProvider`, compiled in CI only; `file:` and non-`content:` refused) |
| S11 | Low | identity | `key.pem` is written with the default mode and only then `chmod 600` (short window where it is world-readable on desktops). | fixed | `test/security_b_test.dart` "S11 key.pem mode" |
| S12 | Low | shares | A shared file swapped for a symlink after sharing is followed when served. | fixed | `test/security_b_test.dart` "a share file swapped for a symlink is not served" |
| S13 | Low | receive | The `.part` file is opened following symlinks. | fixed | `test/security_b_test.dart` "reserveUniqueFile never writes through an existing symlink" (the `.part` check in `_handleUpload` is defence in depth) |
| S14 | Low | web page | CSP allows `script-src 'unsafe-inline'`. | fixed | `test/security_b_test.dart` "S14 CSP"; `test/web_test.dart` `_expectSecurityHeaders` (changed: hash instead of `unsafe-inline`) |
| S15 | Low | prepare-upload, upload | No per-IP limit on repeated declined requests (dialog spam) or failed token attempts on upload/upload-status/cancel. | fixed | security_a_test.dart: S15 per-IP attempt limit (2 tests) |
| S16 | Low | logs | The share store parse error printed to stderr can contain part of the file (share tokens). | fixed | none (log line prints the error type only) |
| S17 | Info | web sessions, shares | Tokens are looked up in a hash map keyed by the token itself (not a constant-time comparison). | fixed | `test/security_b_test.dart` "S17 token keys" (`webTokenKey`: lookup by SHA-256 of the token) |
| S18 | Low | receive | No free-space check before accepting a transfer. | fixed | security_a_test.dart: S18 free space |
| S19 | Low | peer data | Capability record lists/strings, alias, device model and type from peers are not length-capped. | fixed | security_a_test.dart: S19 peer data lengths (2 tests) |
| S20 | Info | sender proof | No nonce or timestamp; the proof does not cover file contents or the text preview. | accepted | |
| S21 | Info | TLS | TLS 1.2 non-forward-secret RSA key exchange and CBC ciphers are accepted if a client asks; certificate valid 10 years, no rotation. | accepted | |
| S22 | Info | /info, /capabilities | Unauthenticated: alias, model, fingerprint, LAN addresses, hotspot SSID. | accepted | |
| S23 | Info | plain HTTP listener | Traffic (pairing code, session cookie, share tokens) is readable on the network. | accepted | |
| S24 | High | nearby list (app protocol) | The nearby listing must not be a CPU DoS (RSA verify on attacker certs) or an oracle for who is trusted: nonce first (single use, bound to fingerprint and IP, 30 s), then fingerprint of the cert, then signature (bound to path and receiver); a denied, untrusted or empty answer is one constant body. | fixed | security_c_test.dart: C2, C3, C4, C5, C6, C7 |
| S25 | Medium | nearby challenge | Challenge endpoint abuse: unlimited nonces, rate. | fixed | security_c_test.dart: C8, C9, C10 |
| S26 | Medium | nearby tickets | Download tickets: hashed storage, 10 min fixed life, bound to IP, header only, re-checked on every request (revoked on stop sharing, toggle off, untrust). | fixed | security_c_test.dart: C12, C13, C14, C15, C16 |
| S27 | Medium | nearby endpoints | Listing caps (50 shares, 1000 files), Host check (421), HTTPS only (plain HTTP gives the unknown-path 404), no path or token in the listing. | fixed | security_c_test.dart: C11, C18, C19 (C1 for the browser listing) |

## 3. Accepted risks and out of scope

- **S20 sender proof without nonce/timestamp.** The proof only decides trust and
  auto-accept; the receiver still shows every unknown request. A nonce would break
  LocalSend compatibility (the protocol has no challenge step). Accepted.
- **S21 TLS 1.2 RSA key exchange / CBC.** Dart's `SecurityContext` does not expose cipher
  selection, and LocalSend peers vary in what they speak. Identity is pinned by
  certificate fingerprint, so a downgrade needs the private key. Accepted.
- **S22 public `/info` and `/capabilities`.** Discovery needs them (LocalSend v2 clients
  call `/info` before anything else) and the same data is multicast anyway. They hold no
  secret. Accepted.
- **S23 plain HTTP listener.** The browser feature is opt-in, off by default, and meant for
  a trusted LAN, because browsers cannot pin a self-signed certificate without warnings.
  Pairing needs approval on the device, session cookies are `HttpOnly` and expire, share
  tokens are 128-bit and can be time and download limited. Use the HTTPS port where the
  browser accepts the certificate. Accepted.
- **Known gaps of S12:** shares persisted before the fix store unresolved paths and are
  dropped at load when the path involves a symlink (macOS `/var`); re-share them.
  A TOCTOU window between the symlink check and open remains (needs write access to the
  shared folder, out of scope).

## 4. Reporting a vulnerability

Please report vulnerabilities privately through GitHub's private security advisories for
this repository: <https://github.com/alrz1999/landrop/security/advisories/new>. Do not open a
public issue for a vulnerability. Include the version or commit, the platform, and steps to
reproduce.
