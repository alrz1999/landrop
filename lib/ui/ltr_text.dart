import 'package:flutter/material.dart';

// Bidi helpers (UX.md 4.5): technical values and user names inside Persian
// (RTL) text.

const _lri = '\u2066'; // LEFT-TO-RIGHT ISOLATE
const _fsi = '\u2068'; // FIRST STRONG ISOLATE
const _pdi = '\u2069'; // POP DIRECTIONAL ISOLATE

/// Wraps a technical value (IP, port, URL, path, code) in an LTR isolate so
/// it keeps its order inside an RTL sentence: `192.168.1.10:53317` never
/// becomes `53317:192.168.1.10`.
String ltr(String s) => '$_lri$s$_pdi';

/// Wraps a user-generated name (device alias, file name) in a first-strong
/// isolate: it takes its own direction without disturbing the sentence.
String iso(String s) => '$_fsi$s$_pdi';

/// Removes the isolates added by [ltr] / [iso] (e.g. before copying).
String stripIsolates(String s) =>
    s.replaceAll(RegExp('[\u2066-\u2069]'), '');

/// Shortens [name] to at most [max] characters by cutting the middle, so the
/// end and the file extension stay visible: `holiday-in-…inal.jpg`.
String middleEllipsis(String name, {int max = 32}) {
  final chars = name.characters;
  if (max < 3 || chars.length <= max) return name;
  final dot = name.lastIndexOf('.');
  final extLen = dot > 0 && name.length - dot <= 10
      ? name.substring(dot).characters.length
      : 0;
  var tail = extLen > 8 ? extLen : 8;
  if (tail > max - 2) tail = max - 2;
  final head = max - 1 - tail;
  return '${chars.take(head)}…${chars.skip(chars.length - tail)}';
}

final _firstStrong = RegExp(
    '[A-Za-zÀ-ɏͰ-֏֐-ࣿיִ-﷿ﹰ-﻿]');

/// Direction of the first strong character of [s] (UX.md 4.5 rule 3); null
/// when there is none (digits and punctuation only).
TextDirection? firstStrongDirection(String s) {
  final m = _firstStrong.firstMatch(s);
  if (m == null) return null;
  final c = m[0]!.codeUnitAt(0);
  return c >= 0x0590 ? TextDirection.rtl : TextDirection.ltr;
}

/// A user-generated name (device alias, file name, browser) shown on its
/// own: it takes the direction of its first strong character, so `لپ‌تاپ
/// Ali` and `report-final.pdf` both read correctly in either layout, and
/// stays aligned to the start of the surrounding layout. With [fileName]
/// a long name is shortened in the middle, keeping the extension.
class AutoDirText extends StatelessWidget {
  const AutoDirText(this.data,
      {super.key,
      this.style,
      this.maxLines,
      this.overflow,
      this.fileName = false,
      this.maxChars = 40});

  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool fileName;
  final int maxChars;

  @override
  Widget build(BuildContext context) {
    final outer = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final own = firstStrongDirection(data) ?? outer;
    final text = fileName ? middleEllipsis(data, max: maxChars) : data;
    return Text(text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textDirection: own,
        textAlign:
            outer == TextDirection.rtl ? TextAlign.right : TextAlign.left);
  }
}

/// A technical value (IP, URL, fingerprint, pairing code, path) that must
/// always read left to right, aligned to the start of the surrounding layout
/// (right in RTL, left in LTR).
class LtrText extends StatelessWidget {
  const LtrText(this.data,
      {super.key,
      this.style,
      this.selectable = false,
      this.maxLines,
      this.overflow});

  final String data;
  final TextStyle? style;
  final bool selectable;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final outer = Directionality.maybeOf(context) ?? TextDirection.ltr;
    // In LTR text, TextAlign.right is the start of an RTL layout.
    final align =
        outer == TextDirection.rtl ? TextAlign.right : TextAlign.left;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: selectable
          ? SelectableText(data,
              style: style,
              maxLines: maxLines,
              textAlign: align,
              textDirection: TextDirection.ltr)
          : Text(data,
              style: style,
              maxLines: maxLines,
              overflow: overflow,
              textAlign: align,
              textDirection: TextDirection.ltr),
    );
  }
}
