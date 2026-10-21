import '../core/api.dart';
import '../l10n/app_localizations.dart';
import 'ltr_text.dart';

/// The user-facing texts of a [Finding] in the current language.
class FindingText {
  const FindingText(this.title, this.detail, this.fix);
  final String title;
  final String detail;

  /// '' when there is nothing to do.
  final String fix;
}

/// Localized title/detail/fix of [f], built from [Finding.code] and
/// [Finding.params]. English keeps the finding's own texts (byte-identical
/// with the core, the report and the tests). A field without a translation
/// for the code (or a missing parameter) falls back to the English field;
/// an empty English detail/fix stays empty. [Finding.technical] is never
/// translated (it is for support).
FindingText localizeFinding(AppLocalizations l, Finding f) {
  if (l.localeName == 'en' || l.localeName.startsWith('en_')) {
    return FindingText(f.title, f.detail, f.fix);
  }
  final (title, detail, fix) = _texts(l, f);
  return FindingText(
    title ?? f.title,
    f.detail.isEmpty ? '' : (detail ?? f.detail),
    f.fix.isEmpty ? '' : (fix ?? f.fix),
  );
}

String? _param(Finding f, String key) {
  final v = f.params[key];
  return v == null ? null : '$v';
}

(String?, String?, String?) _texts(AppLocalizations l, Finding f) {
  switch (f.code) {
    case 'server-down':
      return (l.diagServerDownTitle, l.diagServerDownDetail, l.diagServerDownFix);
    case 'discovery-failed':
      return (
        l.diagDiscoveryFailedTitle,
        l.diagDiscoveryFailedDetail,
        l.diagDiscoveryFailedFix
      );
    case 'no-lan':
      return (l.diagNoLanTitle, l.diagNoLanDetail, l.diagNoLanFix);
    case 'link-local-only':
      return (l.diagLinkLocalOnlyTitle, l.diagLinkLocalOnlyDetail, null);
    case 'vpn-active':
      return (l.diagVpnActiveTitle, l.diagVpnActiveDetail, l.diagVpnActiveFix);
    case 'announce-blocked':
      return (
        l.diagAnnounceBlockedTitle,
        l.diagAnnounceBlockedDetail,
        l.diagAnnounceBlockedFix
      );
    case 'some-peers-silent':
      return (l.diagSomePeersSilentTitle, l.diagSomePeersSilentDetail, null);
    case 'probe-refused':
      return (
        l.diagProbeRefusedTitle,
        l.diagProbeRefusedDetail,
        l.diagProbeRefusedFix
      );
    case 'probe-timeout':
      return (
        l.diagProbeTimeoutTitle,
        l.diagProbeTimeoutDetail,
        l.diagProbeTimeoutFix
      );
    case 'probe-unreachable':
      return (
        l.diagProbeUnreachableTitle,
        l.diagProbeUnreachableDetail,
        l.diagProbeUnreachableFix
      );
    case 'probe-fingerprint-mismatch':
      return (
        l.diagProbeFingerprintMismatchTitle,
        l.diagProbeFingerprintMismatchDetail,
        l.diagProbeFingerprintMismatchFix
      );
    case 'probe-not-landrop':
      return (
        l.diagProbeNotLandropTitle,
        l.diagProbeNotLandropDetail,
        l.diagProbeNotLandropFix
      );
    case 'probe-ok':
      final alias = _param(f, 'alias');
      return (
        l.diagProbeOkTitle,
        alias == null ? null : l.diagProbeOkDetail(iso(alias)),
        null
      );
    case 'different-subnet':
      return (
        l.diagDifferentSubnetTitle,
        l.diagDifferentSubnetDetail,
        l.diagDifferentSubnetFix
      );
    case 'hotspot-likely-fix':
      return (
        l.diagHotspotLikelyFixTitle,
        l.diagHotspotLikelyFixDetail,
        l.diagHotspotLikelyFixFix
      );
    case 'mdns-only':
      return (l.diagMdnsOnlyTitle, l.diagMdnsOnlyDetail, null);
    case 'mdns-visible-unreachable':
      final reason = switch (_param(f, 'failure')) {
        'timeout' => l.diagMdnsReasonTimeout,
        'refused' => l.diagMdnsReasonRefused,
        'fingerprint-mismatch' => l.diagMdnsReasonFingerprintMismatch,
        _ => l.diagMdnsReasonOther,
      };
      return (
        l.diagMdnsVisibleUnreachableTitle,
        l.diagMdnsVisibleUnreachableDetail(reason),
        l.diagMdnsVisibleUnreachableFix
      );
    case 'udp-only-no-mdns':
      return (l.diagUdpOnlyNoMdnsTitle, l.diagUdpOnlyNoMdnsDetail, null);
    case 'mdns-unavailable':
      return (
        l.diagMdnsUnavailableTitle,
        f.params['discoveryFailed'] == true
            ? l.diagMdnsUnavailableDetailBoth
            : l.diagMdnsUnavailableDetail,
        l.diagMdnsUnavailableFix
      );
    case 'all-good':
      return (l.diagAllGoodTitle, l.diagAllGoodDetail, l.diagAllGoodFix);
    case 'network':
      return (l.diagNetworkTitle, l.diagNetworkDetail, null);
    case 'search-failed':
      return (l.diagSearchFailedTitle, null, null);
  }
  return (null, null, null);
}

/// Localized message for a failed send ([SendResult.errorCode]); null code
/// is treated as [SendErrorCode.unknown].
String localizeSendError(AppLocalizations l, SendErrorCode? code) =>
    switch (code ?? SendErrorCode.unknown) {
      SendErrorCode.declined => l.sendErrorDeclined,
      SendErrorCode.busy => l.sendErrorBusy,
      SendErrorCode.unreachable => l.sendErrorUnreachable,
      SendErrorCode.cancelled => l.sendErrorCancelled,
      SendErrorCode.timeout => l.sendErrorTimeout,
      SendErrorCode.fingerprintMismatch => l.sendErrorFingerprintMismatch,
      SendErrorCode.diskError => l.sendErrorDiskError,
      SendErrorCode.unknown => l.sendErrorUnknown,
    };

/// [localizeSendError] for a [SendResult]; null when it succeeded.
String? localizeSendResult(AppLocalizations l, SendResult r) =>
    r.ok ? null : localizeSendError(l, r.errorCode);

/// [localizeSendError] for a stored code name (`SendErrorCode.name`), e.g.
/// from settings or a log; unknown names map to [SendErrorCode.unknown].
String localizeSendErrorName(AppLocalizations l, String? name) =>
    localizeSendError(
        l,
        SendErrorCode.values
            .where((c) => c.name == name)
            .firstOrNull);
