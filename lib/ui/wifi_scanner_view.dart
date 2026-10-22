import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'l10n.dart';

/// Camera preview that reports every QR code text through [onCode]. Only
/// built on Android (wifi_join_page.dart); tests inject their own scanner.
class WifiScannerView extends StatelessWidget {
  const WifiScannerView({super.key, required this.onCode});
  final void Function(String code) onCode;

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      controller: MobileScannerController(
        formats: const [BarcodeFormat.qrCode],
        detectionSpeed: DetectionSpeed.noDuplicates,
      ),
      onDetect: (capture) {
        for (final b in capture.barcodes) {
          final v = b.rawValue;
          if (v != null && v.isNotEmpty) {
            onCode(v);
            return;
          }
        }
      },
      errorBuilder: (context, error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(context.l.wifiJoinCameraFailed),
        ),
      ),
    );
  }
}
