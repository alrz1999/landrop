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

  /// Button: retry after an error.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonTryAgain;

  /// Button: hide a banner.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get commonDismiss;

  /// Button: close a dialog.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// Button: show more about a banner.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get commonShow;

  /// Button: stop something (e.g. the hotspot).
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get commonStop;

  /// Button: decline a request.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get commonDecline;

  /// Button: accept an incoming transfer.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get commonAccept;

  /// Button: save a dialog.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// Kind of device shown under its name.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get deviceKindPhone;

  /// Kind of device shown under its name.
  ///
  /// In en, this message translates to:
  /// **'Computer'**
  String get deviceKindComputer;

  /// Kind of device shown under its name (a web browser).
  ///
  /// In en, this message translates to:
  /// **'Browser'**
  String get deviceKindBrowser;

  /// Home status line: this device can receive.
  ///
  /// In en, this message translates to:
  /// **'Visible to nearby devices'**
  String get selfStatusReady;

  /// Home status line while starting.
  ///
  /// In en, this message translates to:
  /// **'Getting ready…'**
  String get selfStatusStarting;

  /// Home status line when the service is stopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get selfStatusStopped;

  /// Home status line when the service failed; a Try again button follows.
  ///
  /// In en, this message translates to:
  /// **'Can\'t receive right now.'**
  String get selfStatusError;

  /// Tooltip of the edit button next to the device name.
  ///
  /// In en, this message translates to:
  /// **'Rename device'**
  String get selfRename;

  /// Small muted line under the status: IP and port (technical, Latin digits).
  ///
  /// In en, this message translates to:
  /// **'{ip} · port {port}'**
  String selfAddress(String ip, String port);

  /// Same line when the IP is not known.
  ///
  /// In en, this message translates to:
  /// **'IP unknown · port {port}'**
  String selfAddressUnknown(String port);

  /// Tooltip / title: technical details of a device.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get peerDetails;

  /// Device details: label of the IP address and port.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get detailsAddress;

  /// Device details: label of how it is connected.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get detailsConnection;

  /// Device details: it is reached over a direct cable (169.254.x.x).
  ///
  /// In en, this message translates to:
  /// **'Direct cable link'**
  String get detailsCableLink;

  /// Device details: other addresses of the same device.
  ///
  /// In en, this message translates to:
  /// **'Other addresses'**
  String get detailsOtherAddresses;

  /// Device details: model or operating system.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get detailsModel;

  /// The certificate fingerprint, in plain words.
  ///
  /// In en, this message translates to:
  /// **'Security code'**
  String get securityCode;

  /// Explains the security code.
  ///
  /// In en, this message translates to:
  /// **'Compare this code with the other device to be sure it\'s really yours.'**
  String get securityCodeHint;

  /// Home, no devices: headline.
  ///
  /// In en, this message translates to:
  /// **'No devices found yet'**
  String get emptyTitle;

  /// Home, no devices: what to check.
  ///
  /// In en, this message translates to:
  /// **'Make sure LanDrop is open on the other device and both are on the same Wi-Fi.'**
  String get emptyBody;

  /// Home, no devices: main button, opens the connection check.
  ///
  /// In en, this message translates to:
  /// **'Why can\'t I see my device?'**
  String get emptyWhy;

  /// Opens the hotspot wizard.
  ///
  /// In en, this message translates to:
  /// **'Connect without Wi-Fi / router'**
  String get connectHotspotTitle;

  /// Subtitle of the hotspot wizard entry.
  ///
  /// In en, this message translates to:
  /// **'Use a hotspot from a phone or laptop, step by step'**
  String get connectHotspotSub;

  /// Opens the cable wizard; also a diagnosis button.
  ///
  /// In en, this message translates to:
  /// **'Connect with a cable'**
  String get connectCableTitle;

  /// Subtitle of the cable wizard entry.
  ///
  /// In en, this message translates to:
  /// **'Ethernet cable between two computers, or USB tethering'**
  String get connectCableSub;

  /// Opens the Wi-Fi Direct page (Android).
  ///
  /// In en, this message translates to:
  /// **'Connect with Wi-Fi Direct'**
  String get connectWifiDirectTitle;

  /// Subtitle of the Wi-Fi Direct entry.
  ///
  /// In en, this message translates to:
  /// **'Phone to phone without a router (Android)'**
  String get connectWifiDirectSub;

  /// Opens the join-by-QR page (Android).
  ///
  /// In en, this message translates to:
  /// **'Join a hotspot by QR'**
  String get connectWifiJoinTitle;

  /// Subtitle of the join-by-QR entry.
  ///
  /// In en, this message translates to:
  /// **'Scan the QR code of another phone\'s LanDrop hotspot'**
  String get connectWifiJoinSub;

  /// Caption of the QR with this device address (only LanDrop can use it).
  ///
  /// In en, this message translates to:
  /// **'For another LanDrop app'**
  String get qrForLanDrop;

  /// Shown instead of a QR code before the address is known.
  ///
  /// In en, this message translates to:
  /// **'Address not available yet'**
  String get addressNotAvailable;

  /// Screen reader label of the QR code.
  ///
  /// In en, this message translates to:
  /// **'QR code with this device\'s address'**
  String get qrSelfSemantics;

  /// Transfer card with many files: files finished so far.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} files'**
  String transferSummary(int done, int total);

  /// Transfer card status: the receiver declined.
  ///
  /// In en, this message translates to:
  /// **'Declined by {name}'**
  String transferDeclined(String name);

  /// Transfer card status with the reason.
  ///
  /// In en, this message translates to:
  /// **'Failed: {reason}'**
  String transferFailed(String reason);

  /// Transfer card status without a reason.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get transferFailedPlain;

  /// Transfer card status.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get transferDone;

  /// Transfer card status before the receiver accepted.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {name} to accept…'**
  String transferWaiting(String name);

  /// Transfer card status.
  ///
  /// In en, this message translates to:
  /// **'Transferring'**
  String get transferRunning;

  /// Transfer card title, incoming.
  ///
  /// In en, this message translates to:
  /// **'From {name}'**
  String transferFrom(String name);

  /// Transfer card title, outgoing.
  ///
  /// In en, this message translates to:
  /// **'To {name}'**
  String transferTo(String name);

  /// Where received files were saved (path stays left to right).
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String transferSavedTo(String path);

  /// Incoming request dialog title.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to send you {count, plural, =1{1 file} other{{count} files}}'**
  String incomingTitle(String name, int count);

  /// Incoming request from a browser: its IP.
  ///
  /// In en, this message translates to:
  /// **'Web browser at {ip}'**
  String incomingFromBrowser(String ip);

  /// Incoming request from a browser: IP and browser name.
  ///
  /// In en, this message translates to:
  /// **'Web browser at {ip} · {model}'**
  String incomingFromBrowserModel(String ip, String model);

  /// A number of files.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file} other{{count} files}}'**
  String fileCount(int count);

  /// Incoming dialog: total size.
  ///
  /// In en, this message translates to:
  /// **'Total: {size}'**
  String incomingTotal(String size);

  /// Incoming dialog: the folder files will be saved in.
  ///
  /// In en, this message translates to:
  /// **'Saves to {folder}'**
  String incomingSavesTo(String folder);

  /// Browser pairing dialog title.
  ///
  /// In en, this message translates to:
  /// **'Allow a browser to send you files?'**
  String get pairingTitle;

  /// Label above the pairing code.
  ///
  /// In en, this message translates to:
  /// **'Code shown in the browser'**
  String get pairingCodeLabel;

  /// Screen reader label: the pairing code digit by digit.
  ///
  /// In en, this message translates to:
  /// **'Pairing code {digits}'**
  String pairingCodeSemantics(String digits);

  /// Browser pairing dialog explanation.
  ///
  /// In en, this message translates to:
  /// **'Approve only if the browser shows the same code. For the next hour it can then offer you files; you still accept every transfer.'**
  String get pairingBody;

  /// Button: approve a browser.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get pairingApprove;

  /// Add by IP dialog title.
  ///
  /// In en, this message translates to:
  /// **'Add device by IP'**
  String get addByIpTitle;

  /// Add by IP text field label.
  ///
  /// In en, this message translates to:
  /// **'IP address'**
  String get addByIpLabel;

  /// Add by IP hint with two example addresses.
  ///
  /// In en, this message translates to:
  /// **'{example} or {exampleWithPort}'**
  String addByIpHint(String example, String exampleWithPort);

  /// Add by IP: the text is not an address.
  ///
  /// In en, this message translates to:
  /// **'Enter an IPv4 address, e.g. {example}'**
  String addByIpInvalid(String example);

  /// Add by IP: confirm button.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addByIpAdd;

  /// Snackbar: a device was added by IP.
  ///
  /// In en, this message translates to:
  /// **'Added {name}'**
  String addByIpAdded(String name);

  /// Add by IP failed: nothing answered.
  ///
  /// In en, this message translates to:
  /// **'No LanDrop device answered at {address}.'**
  String addByIpNoAnswer(String address);

  /// Add by IP failed with an error (technical, English).
  ///
  /// In en, this message translates to:
  /// **'Could not reach {address} — {error}'**
  String addByIpError(String address, String error);

  /// Add by IP failed: dialog title.
  ///
  /// In en, this message translates to:
  /// **'Device not found'**
  String get addFailedTitle;

  /// Add by IP failed: button that runs the connection check for the address.
  ///
  /// In en, this message translates to:
  /// **'Diagnose this IP'**
  String get addFailedDiagnose;

  /// Choose device dialog without devices.
  ///
  /// In en, this message translates to:
  /// **'No devices found yet.'**
  String get pickerEmpty;

  /// Choose device dialog without devices: opens the connection check.
  ///
  /// In en, this message translates to:
  /// **'Help me connect'**
  String get pickerHelp;

  /// Choose device dialog title.
  ///
  /// In en, this message translates to:
  /// **'Send {count, plural, =1{1 file} other{{count} files}} to…'**
  String sendPickerTitleFiles(int count);

  /// Choose device dialog title for a folder.
  ///
  /// In en, this message translates to:
  /// **'Send folder \"{name}\" to…'**
  String sendPickerTitleFolder(String name);

  /// Device name dialog: text field label.
  ///
  /// In en, this message translates to:
  /// **'Name shown to others'**
  String get aliasLabel;

  /// Settings row and dialog title.
  ///
  /// In en, this message translates to:
  /// **'Device name'**
  String get settingsDeviceName;

  /// The main Send button and the Send button of each device.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get homeSend;

  /// Home section title.
  ///
  /// In en, this message translates to:
  /// **'Nearby devices'**
  String get homeNearbyDevices;

  /// Home button: search the network again.
  ///
  /// In en, this message translates to:
  /// **'Rescan network'**
  String get homeRescan;

  /// Home button: add a device by its address.
  ///
  /// In en, this message translates to:
  /// **'Add by IP'**
  String get homeAddByIp;

  /// Banner when automatic discovery could not start.
  ///
  /// In en, this message translates to:
  /// **'Automatic search is off on this device.'**
  String get homeDiscoveryOff;

  /// Button: opens the connection check.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get homeHelp;

  /// Banner while this phone shares a hotspot (name stays as is).
  ///
  /// In en, this message translates to:
  /// **'Sharing hotspot \"{ssid}\"'**
  String homeHotspotBanner(String ssid);

  /// Home section title: transfers.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get homeActivity;

  /// Button: remove finished transfers from the list.
  ///
  /// In en, this message translates to:
  /// **'Clear finished'**
  String get homeClearFinished;

  /// App bar: opens the Shares page.
  ///
  /// In en, this message translates to:
  /// **'Share link'**
  String get homeShareLink;

  /// Home row while links are shared; opens the Shares page.
  ///
  /// In en, this message translates to:
  /// **'Sharing {count, plural, =1{1 link} other{{count} links}}'**
  String homeActiveShares(int count);

  /// Snackbar after accepting a transfer.
  ///
  /// In en, this message translates to:
  /// **'Receiving {count, plural, =1{1 file} other{{count} files}} from {name}'**
  String homeReceiving(int count, String name);

  /// Snackbar after Rescan network.
  ///
  /// In en, this message translates to:
  /// **'Scan finished: {count, plural, =1{1 device} other{{count} devices}} found'**
  String homeScanFinished(int count);

  /// Snackbar when Rescan network failed (technical error, English).
  ///
  /// In en, this message translates to:
  /// **'Scan failed: {error}'**
  String homeScanFailed(String error);

  /// Send sheet title.
  ///
  /// In en, this message translates to:
  /// **'What do you want to send?'**
  String get sendSheetTitle;

  /// Send sheet: send files.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get sendSheetFiles;

  /// Send sheet: send a folder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get sendSheetFolder;

  /// Snackbar: the transfer finished.
  ///
  /// In en, this message translates to:
  /// **'Sent to {name}.'**
  String sendSent(String name);

  /// Snackbar: the receiver declined.
  ///
  /// In en, this message translates to:
  /// **'{name} declined.'**
  String sendDeclined(String name);

  /// Snackbar: the send failed; a Help button follows.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach {name}. Is LanDrop still open there?'**
  String sendFailed(String name);

  /// Error snackbar (technical error, English).
  ///
  /// In en, this message translates to:
  /// **'Could not open file picker: {error}'**
  String errorFilePicker(String error);

  /// Error snackbar (technical error, English).
  ///
  /// In en, this message translates to:
  /// **'Could not open folder picker: {error}'**
  String errorFolderPicker(String error);

  /// Error snackbar (technical error, English).
  ///
  /// In en, this message translates to:
  /// **'Could not open the picker: {error}'**
  String errorPicker(String error);

  /// Shares page title.
  ///
  /// In en, this message translates to:
  /// **'Shares'**
  String get sharesTitle;

  /// Shares page: section where others download from this device.
  ///
  /// In en, this message translates to:
  /// **'Send a link'**
  String get shareSendLinkTitle;

  /// Shares page: explains Send a link.
  ///
  /// In en, this message translates to:
  /// **'Anyone on this Wi-Fi with the link can download the files from a browser.'**
  String get shareSendLinkBody;

  /// Button: share files as a link.
  ///
  /// In en, this message translates to:
  /// **'Share files'**
  String get shareFiles;

  /// Button: share a folder as a link.
  ///
  /// In en, this message translates to:
  /// **'Share folder'**
  String get shareFolder;

  /// Shares page when nothing is shared.
  ///
  /// In en, this message translates to:
  /// **'Nothing shared. A share gives you a link and QR code that opens in any browser on this network, no app needed.'**
  String get shareNothingShared;

  /// Shares page: section where browsers send files to this device.
  ///
  /// In en, this message translates to:
  /// **'Use from a browser'**
  String get browserSectionTitle;

  /// Shares page: explains Use from a browser.
  ///
  /// In en, this message translates to:
  /// **'Open this address on another phone or computer to send files here. Nothing to install.'**
  String get browserSectionBody;

  /// Remaining time of a share.
  ///
  /// In en, this message translates to:
  /// **'less than a minute'**
  String get shareLessThanMinute;

  /// Share option: link works for 1 hour.
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get shareTtl1h;

  /// Share option: link works for 24 hours.
  ///
  /// In en, this message translates to:
  /// **'24 hours'**
  String get shareTtl24h;

  /// Share option: no expiry.
  ///
  /// In en, this message translates to:
  /// **'Until I stop'**
  String get shareTtlNone;

  /// Share option: any number of downloads.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get shareUnlimited;

  /// Share options: label of the time choices.
  ///
  /// In en, this message translates to:
  /// **'Link works for'**
  String get shareLinkWorksFor;

  /// Share options: label of the download limit choices.
  ///
  /// In en, this message translates to:
  /// **'Downloads allowed'**
  String get shareDownloadsAllowed;

  /// Share options: note under the choices.
  ///
  /// In en, this message translates to:
  /// **'Anyone on this network who has the link can download while it works. Playing a video counts as one download.'**
  String get shareOptionsNote;

  /// Share options: confirm button.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareConfirm;

  /// Share options dialog title.
  ///
  /// In en, this message translates to:
  /// **'Share {count, plural, =1{1 file} other{{count} files}}'**
  String shareOptionsTitleFiles(int count);

  /// Share options dialog title for a folder.
  ///
  /// In en, this message translates to:
  /// **'Share folder \"{name}\"'**
  String shareOptionsTitleFolder(String name);

  /// Snackbar after creating a share.
  ///
  /// In en, this message translates to:
  /// **'Sharing {count, plural, =1{1 file} other{{count} files}}. Open the link on the other device.'**
  String shareCreatedFiles(int count);

  /// Snackbar after sharing a folder.
  ///
  /// In en, this message translates to:
  /// **'Sharing folder \"{name}\". Open the link on the other device.'**
  String shareCreatedFolder(String name);

  /// Error snackbar (technical error, English).
  ///
  /// In en, this message translates to:
  /// **'Could not share: {error}'**
  String errorShare(String error);

  /// Share card: no expiry.
  ///
  /// In en, this message translates to:
  /// **'Until you stop it'**
  String get shareUntilStopped;

  /// Share card: the link expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get shareExpired;

  /// Share card: remaining time.
  ///
  /// In en, this message translates to:
  /// **'Ends in {time}'**
  String shareEndsIn(String time);

  /// Share card: no download limit.
  ///
  /// In en, this message translates to:
  /// **'Unlimited downloads'**
  String get shareUnlimitedDownloads;

  /// Share card: no downloads left.
  ///
  /// In en, this message translates to:
  /// **'Download limit reached'**
  String get shareLimitReached;

  /// Share card: downloads left.
  ///
  /// In en, this message translates to:
  /// **'{left} of {max} downloads left'**
  String shareDownloadsLeft(int left, int max);

  /// Share card title with several files.
  ///
  /// In en, this message translates to:
  /// **'{first} and {count} more'**
  String shareTitleMore(String first, int count);

  /// Screen reader label of the share QR code.
  ///
  /// In en, this message translates to:
  /// **'QR code for the share link'**
  String get shareQrSemantics;

  /// Share card warning when plain HTTP is on.
  ///
  /// In en, this message translates to:
  /// **'Plain HTTP link: not encrypted.'**
  String get shareHttpWarning;

  /// Snackbar after copying a link.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get shareLinkCopied;

  /// Share card button.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get shareCopyLink;

  /// Share card button.
  ///
  /// In en, this message translates to:
  /// **'Stop sharing'**
  String get shareStop;

  /// Title of the connected browsers card.
  ///
  /// In en, this message translates to:
  /// **'Connected browsers'**
  String get browsersTitle;

  /// Connected browsers card when empty.
  ///
  /// In en, this message translates to:
  /// **'No browser is paired. A paired browser can send you files until it signs out, you disconnect it, or an hour passes.'**
  String get browsersNone;

  /// Connected browser: address, pairing time, last activity.
  ///
  /// In en, this message translates to:
  /// **'{ip} · paired {time} · last seen {ago}'**
  String browserSessionSubtitle(String ip, String time, String ago);

  /// Relative time.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get agoJustNow;

  /// Relative time in minutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min ago'**
  String agoMinutes(String minutes);

  /// Relative time in hours.
  ///
  /// In en, this message translates to:
  /// **'{hours} h ago'**
  String agoHours(String hours);

  /// Snackbar after disconnecting a browser.
  ///
  /// In en, this message translates to:
  /// **'{name} disconnected'**
  String browserDisconnected(String name);

  /// Button: disconnect a browser.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get browserDisconnect;

  /// Caption of the browser address QR (any camera can open it).
  ///
  /// In en, this message translates to:
  /// **'For any phone camera or browser'**
  String get webQrCaption;

  /// Screen reader label of the browser QR code.
  ///
  /// In en, this message translates to:
  /// **'QR code for the browser address'**
  String get webQrSemantics;

  /// Note between the plain HTTP and the secure address.
  ///
  /// In en, this message translates to:
  /// **'Plain HTTP is on (Settings): no warning, but not encrypted. Secure address:'**
  String get webHttpOnNote;

  /// Collapsed help about the certificate warning.
  ///
  /// In en, this message translates to:
  /// **'The browser shows a warning?'**
  String get webWarningTitle;

  /// Steps for the certificate warning, per browser.
  ///
  /// In en, this message translates to:
  /// **'The browser will first warn that the connection is not private. That is expected: LanDrop uses its own certificate instead of one bought from a certificate company. Choose \"Advanced\" then \"Proceed\" (Chrome, Edge), or \"Show details\" then \"visit this website\" (Safari). Then tap \"Pair this browser\" and approve here if both show the same code.'**
  String get webWarningBody;

  /// Settings section title.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get settingsSectionDevice;

  /// Settings row: received files folder.
  ///
  /// In en, this message translates to:
  /// **'Save received files to'**
  String get settingsSaveFolder;

  /// Settings: no folder chosen.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get settingsNotSet;

  /// Tooltip: go back to the default folder.
  ///
  /// In en, this message translates to:
  /// **'Use default folder'**
  String get settingsUseDefaultFolder;

  /// Android: received files are in the app own folder.
  ///
  /// In en, this message translates to:
  /// **'Only visible inside LanDrop.'**
  String get settingsPrivateFolder;

  /// Android: button that asks for "All files access" to save in Downloads.
  ///
  /// In en, this message translates to:
  /// **'Use Downloads'**
  String get settingsUseDownloads;

  /// Settings section title.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get settingsSectionConnect;

  /// Settings row: opens the connection check.
  ///
  /// In en, this message translates to:
  /// **'Can\'t find the other device?'**
  String get settingsConnectHelp;

  /// Subtitle of the row above.
  ///
  /// In en, this message translates to:
  /// **'Check the connection and see what to do'**
  String get settingsConnectHelpSub;

  /// Settings row: opens the Shares page.
  ///
  /// In en, this message translates to:
  /// **'Shares and browsers'**
  String get settingsShares;

  /// Subtitle of the row above.
  ///
  /// In en, this message translates to:
  /// **'Links you share and browsers that can send you files'**
  String get settingsSharesSub;

  /// Settings section title (Android).
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get settingsSectionApp;

  /// Android switch.
  ///
  /// In en, this message translates to:
  /// **'Keep running in background'**
  String get settingsBackground;

  /// Subtitle of the switch above.
  ///
  /// In en, this message translates to:
  /// **'Stays reachable with the screen off. Shows a notification.'**
  String get settingsBackgroundSub;

  /// Android: quit the app.
  ///
  /// In en, this message translates to:
  /// **'Quit LanDrop'**
  String get settingsQuit;

  /// Subtitle of the row above.
  ///
  /// In en, this message translates to:
  /// **'Stops receiving and closes the app'**
  String get settingsQuitSub;

  /// Settings row and Advanced page title.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get settingsAdvanced;

  /// Subtitle of the Advanced row.
  ///
  /// In en, this message translates to:
  /// **'Address, security code, connection methods'**
  String get settingsAdvancedSub;

  /// Advanced section: this device address and QR.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get advancedSectionAddress;

  /// Advanced row: restart the service.
  ///
  /// In en, this message translates to:
  /// **'Restart LanDrop service'**
  String get advancedRestart;

  /// Service status.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get serviceRunning;

  /// Service status; also shown while an address is not ready.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get serviceStarting;

  /// Service status.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get serviceStopped;

  /// Service status after an error.
  ///
  /// In en, this message translates to:
  /// **'Not running'**
  String get serviceError;

  /// Advanced section title.
  ///
  /// In en, this message translates to:
  /// **'Browsers'**
  String get advancedSectionBrowsers;

  /// Plain HTTP switch title.
  ///
  /// In en, this message translates to:
  /// **'Allow browsers without a warning (not encrypted)'**
  String get webHttpTitle;

  /// Plain HTTP switch subtitle.
  ///
  /// In en, this message translates to:
  /// **'Off is safer. When on, browser traffic is not encrypted: anyone on this network can see the files and pairing codes. Only for networks you trust.'**
  String get webHttpSub;

  /// Row with the plain HTTP address.
  ///
  /// In en, this message translates to:
  /// **'Browser address (plain HTTP)'**
  String get webHttpUrlTitle;

  /// Confirmation dialog title.
  ///
  /// In en, this message translates to:
  /// **'Turn on plain HTTP for browsers?'**
  String get webHttpConfirmTitle;

  /// Confirmation dialog text.
  ///
  /// In en, this message translates to:
  /// **'Browsers will open LanDrop without a certificate warning, but nothing is encrypted: anyone on this Wi-Fi can read the files, share links and pairing codes, and could pretend to be this device. Use it only on a network you trust, such as your home Wi-Fi, never on public or work networks.'**
  String get webHttpConfirmBody;

  /// Confirmation dialog button.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get webHttpConfirmOn;

  /// Error snackbar (technical error, English).
  ///
  /// In en, this message translates to:
  /// **'Could not change plain HTTP: {error}'**
  String errorWebHttp(String error);

  /// Switch title.
  ///
  /// In en, this message translates to:
  /// **'Keep share links after restart'**
  String get keepSharesTitle;

  /// Switch subtitle.
  ///
  /// In en, this message translates to:
  /// **'Share links keep working after LanDrop restarts, as long as they have not expired and the files are unchanged. The list of shared files is stored on this device. Off deletes it.'**
  String get keepSharesSub;

  /// Advanced section title.
  ///
  /// In en, this message translates to:
  /// **'Troubleshooting'**
  String get advancedSectionTroubleshoot;

  /// Advanced row: runs the connection check.
  ///
  /// In en, this message translates to:
  /// **'Connection report'**
  String get advancedReport;

  /// Subtitle of the row above.
  ///
  /// In en, this message translates to:
  /// **'Find out why devices cannot connect'**
  String get advancedReportSub;

  /// Advanced section title.
  ///
  /// In en, this message translates to:
  /// **'All connection methods'**
  String get advancedSectionMethods;

  /// Diagnosis finding button: opens the hotspot wizard.
  ///
  /// In en, this message translates to:
  /// **'Connect with a hotspot'**
  String get diagActionHotspot;

  /// Diagnosis dialog title.
  ///
  /// In en, this message translates to:
  /// **'Connection check'**
  String get diagTitle;

  /// Diagnosis dialog title for one address.
  ///
  /// In en, this message translates to:
  /// **'Checking {target}'**
  String diagTitleTarget(String target);

  /// Diagnosis dialog while running.
  ///
  /// In en, this message translates to:
  /// **'Checking the network…'**
  String get diagRunning;

  /// Diagnosis failed (technical error, English).
  ///
  /// In en, this message translates to:
  /// **'Could not run the check: {error}'**
  String diagError(String error);

  /// Snackbar after Copy report.
  ///
  /// In en, this message translates to:
  /// **'Report copied'**
  String get diagReportCopied;

  /// Diagnosis dialog button; the report itself stays English.
  ///
  /// In en, this message translates to:
  /// **'Copy report'**
  String get diagCopyReport;

  /// Diagnosis dialog button.
  ///
  /// In en, this message translates to:
  /// **'Run again'**
  String get diagRunAgain;

  /// Collapsed technical details of a finding.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get diagDetails;

  /// First line of the copied report in Persian only.
  ///
  /// In en, this message translates to:
  /// **'This report is in English so support can read it.'**
  String get diagReportNote;
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
