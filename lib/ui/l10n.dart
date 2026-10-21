import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

export '../l10n/app_localizations.dart';

extension L10nX on BuildContext {
  /// The app's strings for this context. Falls back to English when no
  /// [AppLocalizations] delegate is installed (a bare `MaterialApp` in
  /// tests), so widgets never crash outside [LanDropApp].
  AppLocalizations get l =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      lookupAppLocalizations(const Locale('en'));
}
