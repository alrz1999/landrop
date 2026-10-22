import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'digits.dart';

/// "3.1 MB". With [l] the unit and digits follow its locale
/// ("۳٫۱ مگابایت" in fa); without it the output is English.
String formatBytes(int bytes, [AppLocalizations? l]) {
  final (value, unit) = _scaleBytes(bytes);
  if (l == null) return '$value ${const ['B', 'KB', 'MB', 'GB', 'TB'][unit]}';
  final v = localizeDigits(value, Locale(l.localeName));
  return switch (unit) {
    0 => l.sizeBytes(v),
    1 => l.sizeKB(v),
    2 => l.sizeMB(v),
    3 => l.sizeGB(v),
    _ => l.sizeTB(v),
  };
}

/// (number, unit index 0=B..4=TB).
(String, int) _scaleBytes(int bytes) {
  if (bytes < 1024) return ('$bytes', 0);
  double v = bytes / 1024;
  var i = 1;
  while (v >= 1024 && i < 4) {
    v /= 1024;
    i++;
  }
  return (v.toStringAsFixed(v >= 100 ? 0 : 1), i);
}

/// "3.1 MB/s" / "۳٫۱ مگابایت بر ثانیه".
String formatSpeed(double bytesPerSecond, [AppLocalizations? l]) {
  final size = formatBytes(
      bytesPerSecond.isFinite && bytesPerSecond > 0 ? bytesPerSecond.round() : 0,
      l);
  return l == null ? '$size/s' : l.speedPerSecond(size);
}

/// "45 s", "5 min", "1 h 20 min", "2 h" (seconds only under a minute,
/// minutes rounded down). fa: "۴۵ ثانیه", "۱ ساعت و ۲۰ دقیقه".
String formatDuration(Duration d, [AppLocalizations? l]) {
  final total = d.isNegative ? 0 : d.inSeconds;
  String n(int x) =>
      l == null ? '$x' : localizeDigits('$x', Locale(l.localeName));
  if (total < 60) return l == null ? '$total s' : l.durationSeconds(n(total));
  final minutes = total ~/ 60;
  if (minutes < 60) {
    return l == null ? '$minutes min' : l.durationMinutes(n(minutes));
  }
  final h = minutes ~/ 60, m = minutes % 60;
  if (m == 0) return l == null ? '$h h' : l.durationHours(n(h));
  return l == null ? '$h h $m min' : l.durationHoursMinutes(n(h), n(m));
}

/// Running transfer status: "64%" or, with a [bytesPerSecond], "64% · 4.2
/// MB/s" (fa: "٪۶۴ · ۴٫۲ مگابایت بر ثانیه"). Rounded down, so 100% means
/// every byte arrived.
String formatTransferProgress(double fraction, double? bytesPerSecond,
    [AppLocalizations? l]) {
  final raw = '${(fraction.clamp(0, 1) * 100).floor()}';
  if (l == null) {
    return bytesPerSecond == null
        ? '$raw%'
        : '$raw% · ${formatSpeed(bytesPerSecond)}';
  }
  final p = localizeDigits(raw, Locale(l.localeName));
  return bytesPerSecond == null
      ? l.transferPercent(p)
      : l.transferPercentSpeed(p, formatSpeed(bytesPerSecond, l));
}

/// "1 min left" / "۱ دقیقه مانده".
String formatTimeLeft(Duration d, [AppLocalizations? l]) =>
    l == null ? '${formatDuration(d)} left' : l.transferTimeLeft(formatDuration(d, l));

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
