// Self-signed TLS identity (certificate + key) for the HTTPS server.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart';

/// Hex SHA-256 of DER bytes (the protocol's device fingerprint).
String fingerprintOfDer(List<int> der) => sha256.convert(der).toString();

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

  SecurityContext securityContext() {
    final ctx = SecurityContext(withTrustedRoots: false);
    ctx.useCertificateChainBytes(utf8.encode(certPem));
    ctx.usePrivateKeyBytes(utf8.encode(keyPem));
    return ctx;
  }
}
