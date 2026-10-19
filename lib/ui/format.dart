import 'package:flutter/material.dart';

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  double v = bytes / 1024;
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${units[i]}';
}

IconData deviceIcon(String type) => switch (type) {
      'mobile' => Icons.smartphone,
      'web' => Icons.public,
      'headless' || 'server' => Icons.dns,
      _ => Icons.computer,
    };

String shortFingerprint(String fp) {
  if (fp.length <= 16) return fp.toUpperCase();
  return '${fp.substring(0, 8)}…${fp.substring(fp.length - 8)}'.toUpperCase();
}
