// Self-signed TLS identity (certificate + key) for the HTTPS server.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/asn1.dart';

/// Hex SHA-256 of DER bytes (the protocol's device fingerprint).
String fingerprintOfDer(List<int> der) => sha256.convert(der).toString();

/// The RSA public key in a DER certificate, or null when [der] is not an
/// RSA certificate this parser understands.
RSAPublicKey? rsaPublicKeyOfCert(List<int> der) {
  try {
    final cert = ASN1Parser(Uint8List.fromList(der)).nextObject();
    if (cert is! ASN1Sequence) return null;
    final tbs = cert.elements?.first;
    if (tbs is! ASN1Sequence) return null;
    // subjectPublicKeyInfo: SEQUENCE { algorithm SEQUENCE, key BIT STRING }.
    for (final e in tbs.elements ?? const <ASN1Object>[]) {
      if (e is ASN1Sequence &&
          e.elements?.length == 2 &&
          e.elements![0] is ASN1Sequence &&
          e.elements![1] is ASN1BitString) {
        return CryptoUtils.rsaPublicKeyFromDERBytes(e.encodedBytes!);
      }
    }
  } catch (_) {}
  return null;
}

/// True when [signature] is a SHA-256/RSA signature of [data] by the key of
/// the certificate [certDer]. Never throws.
bool verifyCertSignature(
    List<int> certDer, List<int> data, List<int> signature) {
  final key = rsaPublicKeyOfCert(certDer);
  if (key == null) return false;
  try {
    return CryptoUtils.rsaVerify(key, Uint8List.fromList(data),
        Uint8List.fromList(signature));
  } catch (_) {
    return false;
  }
}

/// What a sender signs in prepare-upload (PROTOCOL.md "Sender proof"):
/// binds the request to this receiver ([receiverFp]), the claimed sender
/// ([senderFp]) and the offered files ([files]: id, name and size).
List<int> senderProofMessage(String receiverFp, String senderFp,
    Iterable<(String id, String name, int size)> files) {
  final sorted = files.toList()..sort((a, b) => a.$1.compareTo(b.$1));
  final digest = sha256
      .convert(utf8.encode([
        for (final (id, name, size) in sorted) '$id\t$name\t$size\n'
      ].join()))
      .toString();
  return utf8.encode('landrop-prepare-v1\n$receiverFp\n$senderFp\n$digest');
}

class TlsIdentity {
  final String certPem;
  final String keyPem;
  final Uint8List certDer;
  final String fingerprint;

  TlsIdentity._(this.certPem, this.keyPem, this.certDer)
      : fingerprint = fingerprintOfDer(certDer);

  factory TlsIdentity.fromPem(String certPem, String keyPem) {
    final der = CryptoUtils.getBytesFromPEMString(certPem);
    return TlsIdentity._(certPem, keyPem, der);
  }

  /// Generates a fresh RSA-2048 self-signed certificate (valid 10 years).
  factory TlsIdentity.generate({String commonName = 'LanDrop'}) {
    final pair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
    final priv = pair.privateKey as RSAPrivateKey;
    final pub = pair.publicKey as RSAPublicKey;
    final dn = {'CN': commonName, 'O': 'LanDrop'};
    final csr = X509Utils.generateRsaCsrPem(dn, priv, pub);
    final serial =
        BigInt.from(DateTime.now().microsecondsSinceEpoch).toString();
    final certPem = X509Utils.generateSelfSignedCertificate(priv, csr, 3650,
        serialNumber: serial,
        notBefore: DateTime.now().subtract(const Duration(days: 1)));
    final keyPem = CryptoUtils.encodeRSAPrivateKeyToPemPkcs1(priv);
    return TlsIdentity.fromPem(certPem, keyPem);
  }

  /// Loads the identity stored in [dir], or generates and persists a new one.
  /// If [dir] is null, a fresh identity is generated for this run only.
  static Future<TlsIdentity> loadOrCreate(String? dir) async {
    if (dir != null) {
      final certFile = File('$dir${Platform.pathSeparator}cert.pem');
      final keyFile = File('$dir${Platform.pathSeparator}key.pem');
      if (await certFile.exists() && await keyFile.exists()) {
        try {
          final id = TlsIdentity.fromPem(
              await certFile.readAsString(), await keyFile.readAsString());
          id.securityContext(); // validate it is usable
          return id;
        } catch (_) {
          // fall through and regenerate
        }
      }
      final id = TlsIdentity.generate();
      await Directory(dir).create(recursive: true);
      await certFile.writeAsString(id.certPem);
      await keyFile.writeAsString(id.keyPem);
      return id;
    }
    return TlsIdentity.generate();
  }

  RSAPrivateKey? _key;

  /// SHA-256/RSA (PKCS#1 v1.5) signature of [data] with this identity's key.
  Uint8List sign(List<int> data) {
    final key = _key ??= CryptoUtils.rsaPrivateKeyFromPemPkcs1(keyPem);
    return CryptoUtils.rsaSign(key, Uint8List.fromList(data));
  }

  SecurityContext securityContext() {
    final ctx = SecurityContext(withTrustedRoots: false);
    ctx.useCertificateChainBytes(utf8.encode(certPem));
    ctx.usePrivateKeyBytes(utf8.encode(keyPem));
    return ctx;
  }
}
