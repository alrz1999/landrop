import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fa.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fa'),
  ];

  /// App name (brand, never translated).
  ///
  /// In en, this message translates to:
  /// **'LanDrop'**
  String get appTitle;

  /// Settings page title and tooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Settings row and dialog title for the app language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// Language option: follow the device language.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystem;

  /// Name of the English language, always written in English.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Name of the Persian language, always written in Persian.
  ///
  /// In en, this message translates to:
  /// **'فارسی'**
  String get languagePersian;

  /// Generic cancel button.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// File size in bytes; value is pre-formatted.
  ///
  /// In en, this message translates to:
  /// **'{value} B'**
  String sizeBytes(String value);

  /// File size in kilobytes.
  ///
  /// In en, this message translates to:
  /// **'{value} KB'**
  String sizeKB(String value);

  /// File size in megabytes.
  ///
  /// In en, this message translates to:
  /// **'{value} MB'**
  String sizeMB(String value);

  /// File size in gigabytes.
  ///
  /// In en, this message translates to:
  /// **'{value} GB'**
  String sizeGB(String value);

  /// File size in terabytes.
  ///
  /// In en, this message translates to:
  /// **'{value} TB'**
  String sizeTB(String value);

  /// Transfer speed; size is a formatted size such as "3.1 MB".
  ///
  /// In en, this message translates to:
  /// **'{size}/s'**
  String speedPerSecond(String size);

  /// Short duration in seconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String durationSeconds(String seconds);

  /// Short duration in minutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String durationMinutes(String minutes);

  /// Duration in whole hours.
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String durationHours(String hours);

  /// Duration in hours and minutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String durationHoursMinutes(String hours, String minutes);

  /// Send failed: the receiver declined (SendErrorCode.declined).
  ///
  /// In en, this message translates to:
  /// **'The other device declined.'**
  String get sendErrorDeclined;

  /// Send failed: receiver busy.
  ///
  /// In en, this message translates to:
  /// **'The other device is busy with another transfer. Try again in a moment.'**
  String get sendErrorBusy;

  /// Send failed: connection failed.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the other device. Check that both are on the same network.'**
  String get sendErrorUnreachable;

  /// Send failed: cancelled by either side.
  ///
  /// In en, this message translates to:
  /// **'The transfer was cancelled.'**
  String get sendErrorCancelled;

  /// Send failed: timeout or stalled upload.
  ///
  /// In en, this message translates to:
  /// **'The other device stopped responding.'**
  String get sendErrorTimeout;

  /// Send failed: certificate fingerprint differs from the pinned one.
  ///
  /// In en, this message translates to:
  /// **'The other device\'s security code has changed. Search again before sending.'**
  String get sendErrorFingerprintMismatch;

  /// Send failed: file system error on either side.
  ///
  /// In en, this message translates to:
  /// **'A file could not be read or saved.'**
  String get sendErrorDiskError;

  /// Send failed for another reason.
  ///
  /// In en, this message translates to:
  /// **'Sending failed.'**
  String get sendErrorUnknown;

  /// Prefix before the fix of a diagnosis finding.
  ///
  /// In en, this message translates to:
  /// **'What to do: {fix}'**
  String diagWhatToDo(String fix);

  /// Diagnosis finding "server-down": headline.
  ///
  /// In en, this message translates to:
  /// **'This device cannot receive files right now'**
  String get diagServerDownTitle;

  /// Diagnosis finding "server-down": what it means.
  ///
  /// In en, this message translates to:
  /// **'LanDrop on this device is not accepting connections, so other devices cannot see it or send to it.'**
  String get diagServerDownDetail;

  /// Diagnosis finding "server-down": what to do.
  ///
  /// In en, this message translates to:
  /// **'Use \"Restart service\" in Settings, or close and reopen LanDrop.'**
  String get diagServerDownFix;

  /// Diagnosis finding "discovery-failed": headline.
  ///
  /// In en, this message translates to:
  /// **'Automatic discovery is off'**
  String get diagDiscoveryFailedTitle;

  /// Diagnosis finding "discovery-failed": what it means.
  ///
  /// In en, this message translates to:
  /// **'LanDrop could not start looking for nearby devices, so they will not appear on their own. Sending by IP still works.'**
  String get diagDiscoveryFailedDetail;

  /// Diagnosis finding "discovery-failed": what to do.
  ///
  /// In en, this message translates to:
  /// **'Use \"Rescan network\" or \"Add by IP\". Restarting LanDrop or allowing local network access may fix it.'**
  String get diagDiscoveryFailedFix;

  /// Diagnosis finding "no-lan": headline.
  ///
  /// In en, this message translates to:
  /// **'Not connected to Wi-Fi or a LAN'**
  String get diagNoLanTitle;

  /// Diagnosis finding "no-lan": what it means.
  ///
  /// In en, this message translates to:
  /// **'This device has no local network address, so it cannot reach other devices nearby.'**
  String get diagNoLanDetail;

  /// Diagnosis finding "no-lan": what to do.
  ///
  /// In en, this message translates to:
  /// **'Connect to the same Wi-Fi as the other device, plug in an Ethernet cable, or turn on a hotspot on one device and join it from the other.'**
  String get diagNoLanFix;

  /// Diagnosis finding "link-local-only": headline.
  ///
  /// In en, this message translates to:
  /// **'Direct cable or no DHCP'**
  String get diagLinkLocalOnlyTitle;

  /// Diagnosis finding "link-local-only": what it means.
  ///
  /// In en, this message translates to:
  /// **'This looks like a direct cable or a network without DHCP. LanDrop works, but both devices must be connected to each other; give both devices a moment to get addresses.'**
  String get diagLinkLocalOnlyDetail;

  /// Diagnosis finding "vpn-active": headline.
  ///
  /// In en, this message translates to:
  /// **'A VPN is on'**
  String get diagVpnActiveTitle;

  /// Diagnosis finding "vpn-active": what it means.
  ///
  /// In en, this message translates to:
  /// **'VPNs often hide the local network, so nearby devices cannot reach each other.'**
  String get diagVpnActiveDetail;

  /// Diagnosis finding "vpn-active": what to do.
  ///
  /// In en, this message translates to:
  /// **'Turn the VPN off, or allow \"local network access\" in its settings, then try again.'**
  String get diagVpnActiveFix;

  /// Diagnosis finding "announce-blocked": headline.
  ///
  /// In en, this message translates to:
  /// **'Devices only show up after a scan'**
  String get diagAnnounceBlockedTitle;

  /// Diagnosis finding "announce-blocked": what it means.
  ///
  /// In en, this message translates to:
  /// **'Your router seems to block the messages devices use to find each other (multicast and broadcast). Transfers still work by IP.'**
  String get diagAnnounceBlockedDetail;

  /// Diagnosis finding "announce-blocked": what to do.
  ///
  /// In en, this message translates to:
  /// **'Use \"Rescan network\" or \"Add by IP\". To fix it for good, turn on multicast / turn off \"AP isolation\" in the router.'**
  String get diagAnnounceBlockedFix;

  /// Diagnosis finding "some-peers-silent": headline.
  ///
  /// In en, this message translates to:
  /// **'Some devices did not announce themselves'**
  String get diagSomePeersSilentTitle;

  /// Diagnosis finding "some-peers-silent": what it means.
  ///
  /// In en, this message translates to:
  /// **'Other devices were found automatically, but these only by scan or IP. They may be on another part of the network or have discovery turned off.'**
  String get diagSomePeersSilentDetail;

  /// Diagnosis finding "probe-refused": headline.
  ///
  /// In en, this message translates to:
  /// **'The device is there, but LanDrop is not answering'**
  String get diagProbeRefusedTitle;

  /// Diagnosis finding "probe-refused": what it means.
  ///
  /// In en, this message translates to:
  /// **'The other device answered, but nothing accepted the connection. LanDrop is probably closed there, or it uses a different port.'**
  String get diagProbeRefusedDetail;

  /// Diagnosis finding "probe-refused": what to do.
  ///
  /// In en, this message translates to:
  /// **'Open LanDrop on the other device and keep it in front. Check the address and port shown on its screen.'**
  String get diagProbeRefusedFix;

  /// Diagnosis finding "probe-timeout": headline.
  ///
  /// In en, this message translates to:
  /// **'No answer from that address'**
  String get diagProbeTimeoutTitle;

  /// Diagnosis finding "probe-timeout": what it means.
  ///
  /// In en, this message translates to:
  /// **'Nothing came back. A firewall, \"AP / client isolation\" on the router, or being on a different network can cause this.'**
  String get diagProbeTimeoutDetail;

  /// Diagnosis finding "probe-timeout": what to do.
  ///
  /// In en, this message translates to:
  /// **'Check both devices are on the same Wi-Fi (not a guest network). Allow LanDrop in the firewall. If it still fails, turn on a hotspot on one device and join it from the other.'**
  String get diagProbeTimeoutFix;

  /// Diagnosis finding "probe-unreachable": headline.
  ///
  /// In en, this message translates to:
  /// **'That address cannot be reached from here'**
  String get diagProbeUnreachableTitle;

  /// Diagnosis finding "probe-unreachable": what it means.
  ///
  /// In en, this message translates to:
  /// **'This device has no way to reach that address. It is probably on a different network, or the address is wrong.'**
  String get diagProbeUnreachableDetail;

  /// Diagnosis finding "probe-unreachable": what to do.
  ///
  /// In en, this message translates to:
  /// **'Check the address on the other device, and connect both to the same Wi-Fi or hotspot.'**
  String get diagProbeUnreachableFix;

  /// Diagnosis finding "probe-fingerprint-mismatch": headline.
  ///
  /// In en, this message translates to:
  /// **'A different device is at this address'**
  String get diagProbeFingerprintMismatchTitle;

  /// Diagnosis finding "probe-fingerprint-mismatch": what it means.
  ///
  /// In en, this message translates to:
  /// **'The device at this address is not the one LanDrop knew before. Either another device took the address, or LanDrop was reinstalled there and made a new security key.'**
  String get diagProbeFingerprintMismatchDetail;

  /// Diagnosis finding "probe-fingerprint-mismatch": what to do.
  ///
  /// In en, this message translates to:
  /// **'Check the fingerprint shown in Settings on the other device. If it is right, remove and add the device again.'**
  String get diagProbeFingerprintMismatchFix;

  /// Diagnosis finding "probe-not-landrop": headline.
  ///
  /// In en, this message translates to:
  /// **'Something answered, but it is not LanDrop'**
  String get diagProbeNotLandropTitle;

  /// Diagnosis finding "probe-not-landrop": what it means.
  ///
  /// In en, this message translates to:
  /// **'A program accepted the connection on that port, but it did not respond like LanDrop or LocalSend.'**
  String get diagProbeNotLandropDetail;

  /// Diagnosis finding "probe-not-landrop": what to do.
  ///
  /// In en, this message translates to:
  /// **'Check the port shown in LanDrop on the other device.'**
  String get diagProbeNotLandropFix;

  /// Diagnosis finding "probe-ok": headline.
  ///
  /// In en, this message translates to:
  /// **'The device answers'**
  String get diagProbeOkTitle;

  /// Diagnosis finding "probe-ok": what it means.
  ///
  /// In en, this message translates to:
  /// **'{alias} at this address is reachable and working.'**
  String diagProbeOkDetail(String alias);

  /// Diagnosis finding "different-subnet": headline.
  ///
  /// In en, this message translates to:
  /// **'The devices seem to be on different networks'**
  String get diagDifferentSubnetTitle;

  /// Diagnosis finding "different-subnet": what it means.
  ///
  /// In en, this message translates to:
  /// **'The addresses do not match, so the devices may be on different Wi-Fi networks, or one is on a guest network.'**
  String get diagDifferentSubnetDetail;

  /// Diagnosis finding "different-subnet": what to do.
  ///
  /// In en, this message translates to:
  /// **'Connect both devices to the same Wi-Fi (not a guest network).'**
  String get diagDifferentSubnetFix;

  /// Diagnosis finding "hotspot-likely-fix": headline.
  ///
  /// In en, this message translates to:
  /// **'No other device found yet'**
  String get diagHotspotLikelyFixTitle;

  /// Diagnosis finding "hotspot-likely-fix": what it means.
  ///
  /// In en, this message translates to:
  /// **'If LanDrop is open on the other device and it still does not show up, this network probably keeps devices apart (common on guest, office, school and hotel Wi-Fi). Connecting both devices through a hotspot from a phone or laptop usually fixes it, and needs no router.'**
  String get diagHotspotLikelyFixDetail;

  /// Diagnosis finding "hotspot-likely-fix": what to do.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Connect with a hotspot\" for step-by-step help, or use \"Add by IP\" if you know the other device\'s address.'**
  String get diagHotspotLikelyFixFix;

  /// Diagnosis finding "mdns-only": headline.
  ///
  /// In en, this message translates to:
  /// **'Standard device discovery works'**
  String get diagMdnsOnlyTitle;

  /// Diagnosis finding "mdns-only": what it means.
  ///
  /// In en, this message translates to:
  /// **'LanDrop\'s own announcements are blocked on this network, but standard device discovery (mDNS / Bonjour) works. Transfers will work.'**
  String get diagMdnsOnlyDetail;

  /// Diagnosis finding "mdns-visible-unreachable": headline.
  ///
  /// In en, this message translates to:
  /// **'The device is on your network, but LanDrop cannot reach it'**
  String get diagMdnsVisibleUnreachableTitle;

  /// Diagnosis finding "mdns-visible-unreachable": what it means.
  ///
  /// In en, this message translates to:
  /// **'The device is on your network and announces itself, but LanDrop\'s port cannot be reached: a firewall on that device or this one, or the app is closing. {reason}'**
  String diagMdnsVisibleUnreachableDetail(String reason);

  /// Diagnosis finding "mdns-visible-unreachable": what to do.
  ///
  /// In en, this message translates to:
  /// **'Allow LanDrop in the firewall on both devices, keep LanDrop open on the other device, then use \"Rescan network\".'**
  String get diagMdnsVisibleUnreachableFix;

  /// Reason inserted as {reason} in diagMdnsVisibleUnreachableDetail: timeout.
  ///
  /// In en, this message translates to:
  /// **'Nothing answered on LanDrop\'s port (timeout), which usually means a firewall is dropping it.'**
  String get diagMdnsReasonTimeout;

  /// Reason inserted as {reason}: connection refused.
  ///
  /// In en, this message translates to:
  /// **'The port refused the connection, which usually means LanDrop is closing or not running there.'**
  String get diagMdnsReasonRefused;

  /// Reason inserted as {reason}: certificate fingerprint differs.
  ///
  /// In en, this message translates to:
  /// **'Something answered, but with a different security key than the device announced.'**
  String get diagMdnsReasonFingerprintMismatch;

  /// Reason inserted as {reason}: any other failure.
  ///
  /// In en, this message translates to:
  /// **'The connection or the check of its identity failed.'**
  String get diagMdnsReasonOther;

  /// Diagnosis finding "udp-only-no-mdns": headline.
  ///
  /// In en, this message translates to:
  /// **'Standard discovery (mDNS) is blocked'**
  String get diagUdpOnlyNoMdnsTitle;

  /// Diagnosis finding "udp-only-no-mdns": what it means.
  ///
  /// In en, this message translates to:
  /// **'Devices were found with LanDrop\'s own announcements, but not through standard discovery (mDNS / Bonjour). This is not a problem for LanDrop.'**
  String get diagUdpOnlyNoMdnsDetail;

  /// Diagnosis finding "mdns-unavailable": headline.
  ///
  /// In en, this message translates to:
  /// **'Standard device discovery could not start'**
  String get diagMdnsUnavailableTitle;

  /// Diagnosis finding "mdns-unavailable": what it means.
  ///
  /// In en, this message translates to:
  /// **'LanDrop could not start mDNS / Bonjour on this device, so it relies on its own announcements. Sending by IP still works.'**
  String get diagMdnsUnavailableDetail;

  /// Diagnosis finding "mdns-unavailable": what to do.
  ///
  /// In en, this message translates to:
  /// **'Use \"Rescan network\" or \"Add by IP\".'**
  String get diagMdnsUnavailableFix;

  /// Diagnosis finding "mdns-unavailable" when automatic discovery failed too: what it means.
  ///
  /// In en, this message translates to:
  /// **'LanDrop could not start mDNS / Bonjour on this device, so it relies on its own announcements. Those failed too, so devices will not appear on their own. Sending by IP still works.'**
  String get diagMdnsUnavailableDetailBoth;

  /// Diagnosis finding "all-good": headline.
  ///
  /// In en, this message translates to:
  /// **'No problems found'**
  String get diagAllGoodTitle;

  /// Diagnosis finding "all-good": what it means.
  ///
  /// In en, this message translates to:
  /// **'This device is on a local network and ready to send and receive.'**
  String get diagAllGoodDetail;

  /// Diagnosis finding "all-good": what to do.
  ///
  /// In en, this message translates to:
  /// **'If a device is still missing, make sure LanDrop is open on it, then use \"Rescan network\" or \"Add by IP\".'**
  String get diagAllGoodFix;

  /// Diagnosis finding "network": headline.
  ///
  /// In en, this message translates to:
  /// **'Your network'**
  String get diagNetworkTitle;

  /// Diagnosis finding "network": what it means.
  ///
  /// In en, this message translates to:
  /// **'Addresses this device has, for reference.'**
  String get diagNetworkDetail;

  /// Hotspot wizard finding "search-failed": headline.
  ///
  /// In en, this message translates to:
  /// **'The search failed'**
  String get diagSearchFailedTitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fa'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fa':
      return AppLocalizationsFa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
