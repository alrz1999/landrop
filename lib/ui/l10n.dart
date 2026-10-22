import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';
import 'digits.dart';
import 'ltr_text.dart' as bidi;

export '../l10n/app_localizations.dart';

/// English strings, for texts built without a [BuildContext] (service
/// messages, logs).
AppLocalizations get englishStrings => lookupAppLocalizations(const Locale('en'));

extension L10nX on BuildContext {
  /// The app's strings for this context. Falls back to English when no
  /// [AppLocalizations] delegate is installed (a bare `MaterialApp` in
  /// tests), so widgets never crash outside [LanDropApp].
  AppLocalizations get l =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      englishStrings;
}

final _rtlChar = RegExp('[֐-ࣿיִ-﷿ﹰ-﻿]');

/// Bidi and digit helpers bound to the current language (UX.md 4.5, 4.6).
/// In English the text stays byte-identical (no isolates), except that a
/// right-to-left name is still isolated so it cannot disturb the sentence.
extension BidiL10n on AppLocalizations {
  bool get isRtl => localeName == 'fa' || localeName.startsWith('fa_');

  /// A technical value (IP, port, URL, path, code) placed inside a sentence.
  String ltrValue(String s) => isRtl ? bidi.ltr(s) : s;

  /// A user-generated name (device alias, file name, browser) placed inside
  /// a sentence.
  String isoName(String s) =>
      isRtl || _rtlChar.hasMatch(s) ? bidi.iso(s) : s;

  /// Persian digits for read-only numbers (counts, sizes, times) in fa.
  String digits(Object n) => localizeDigits('$n', Locale(localeName));
}
