import 'dart:ui' show Locale;

const _persianDigits = '۰۱۲۳۴۵۶۷۸۹';

/// Latin digits to Persian digits (and the decimal point between digits to
/// the Persian decimal separator `٫`) when [locale] is Persian; unchanged
/// otherwise. Only for values that are read, never typed or compared with
/// another device: counts, sizes, speeds, times (UX.md 4.6). IPs, ports,
/// pairing codes and fingerprints stay Latin.
String localizeDigits(String s, Locale locale) {
  if (locale.languageCode != 'fa') return s;
  return s
      .replaceAllMapped(RegExp(r'(?<=[0-9])\.(?=[0-9])'), (_) => '٫')
      .replaceAllMapped(
          RegExp('[0-9]'), (m) => _persianDigits[m[0]!.codeUnitAt(0) - 48]);
}

/// Persian (۰-۹) and Arabic-Indic (٠-٩) digits to Latin digits, and the
/// Persian/Arabic decimal separator `٫` to `.`, for text typed into technical
/// fields (IP, port, pairing code) on a Persian keyboard.
String normalizeDigits(String s) {
  final sb = StringBuffer();
  for (final c in s.runes) {
    if (c >= 0x06F0 && c <= 0x06F9) {
      sb.writeCharCode(0x30 + c - 0x06F0);
    } else if (c >= 0x0660 && c <= 0x0669) {
      sb.writeCharCode(0x30 + c - 0x0660);
    } else if (c == 0x066B) {
      sb.write('.');
    } else {
      sb.writeCharCode(c);
    }
  }
  return sb.toString();
}
