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

  /// Platform name in wizard headings.
  ///
  /// In en, this message translates to:
  /// **'Android'**
  String get platformAndroid;

  /// Platform name in wizard headings.
  ///
  /// In en, this message translates to:
  /// **'iPhone / iPad'**
  String get platformIos;

  /// Platform name in wizard headings.
  ///
  /// In en, this message translates to:
  /// **'Mac'**
  String get platformMac;

  /// Platform name in wizard headings.
  ///
  /// In en, this message translates to:
  /// **'Windows'**
  String get platformWindows;

  /// Platform name in wizard headings.
  ///
  /// In en, this message translates to:
  /// **'Linux'**
  String get platformLinux;

  /// Platform name: any other device.
  ///
  /// In en, this message translates to:
  /// **'Other devices'**
  String get platformOther;

  /// Hotspot wizard, Android shares, step 1.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Start hotspot\" below: LanDrop makes a private hotspot (no mobile data is shared) and shows a QR code the other device can scan to join. This phone may leave its Wi-Fi while it runs.'**
  String get hotspotShareAndroid1;

  /// Hotspot wizard, Android shares, step 2 (Android menu path).
  ///
  /// In en, this message translates to:
  /// **'Or use the normal hotspot: Settings > Network & internet > Hotspot & tethering > Wi-Fi hotspot (names differ a little by brand). Turn it on and note its name and password.'**
  String get hotspotShareAndroid2;

  /// Hotspot wizard, iPhone shares, step 1 (iOS menu path).
  ///
  /// In en, this message translates to:
  /// **'Open Settings > Personal Hotspot and turn on \"Allow Others to Join\". (Your mobile plan must allow hotspot use.)'**
  String get hotspotShareIos1;

  /// Hotspot wizard, iPhone shares, step 2.
  ///
  /// In en, this message translates to:
  /// **'Keep that screen open until the other device has joined: it shows the Wi-Fi password.'**
  String get hotspotShareIos2;

  /// Hotspot wizard, Mac shares, step 1; quotes the hotspotRoleJoin button.
  ///
  /// In en, this message translates to:
  /// **'Easiest: do it the other way round. Let the other device share a hotspot and join it from this Mac (choose \"This device joins it\" above).'**
  String get hotspotShareMac1;

  /// Hotspot wizard, Mac shares, step 2 (macOS menu path).
  ///
  /// In en, this message translates to:
  /// **'To share from this Mac anyway: System Settings > General > Sharing, click (i) next to Internet Sharing, share your connection (for example Ethernet) to computers using Wi-Fi, set a network name and password, then turn Internet Sharing on.'**
  String get hotspotShareMac2;

  /// Hotspot wizard, Windows shares, step 1 (Windows menu path).
  ///
  /// In en, this message translates to:
  /// **'Open Settings > Network & internet > Mobile hotspot.'**
  String get hotspotShareWindows1;

  /// Hotspot wizard, Windows shares, step 2.
  ///
  /// In en, this message translates to:
  /// **'Turn on \"Mobile hotspot\". The network name and password are shown on that page.'**
  String get hotspotShareWindows2;

  /// Hotspot wizard, Linux shares, step 1; command is a shell command, never translated.
  ///
  /// In en, this message translates to:
  /// **'Open Settings > Wi-Fi, open the menu (⋮) and choose \"Turn On Wi-Fi Hotspot…\". On other desktops use NetworkManager: create a new Wi-Fi network with mode \"Hotspot\", or run: {command}'**
  String hotspotShareLinux1(String command);

  /// Hotspot wizard, Linux shares, step 2.
  ///
  /// In en, this message translates to:
  /// **'Note the network name and password.'**
  String get hotspotShareLinux2;

  /// Hotspot wizard, other device shares.
  ///
  /// In en, this message translates to:
  /// **'Turn on the hotspot (\"tethering\") in this device\'s network settings and note its name and password.'**
  String get hotspotShareOther1;

  /// Hotspot wizard, Android joins (Android menu path).
  ///
  /// In en, this message translates to:
  /// **'Open Settings > Wi-Fi and pick the other device\'s hotspot, then enter its password. Or tap the QR icon next to \"Add network\" and scan the code shown on the other device.'**
  String get hotspotJoinAndroid1;

  /// Hotspot wizard, iPhone joins (iOS menu path).
  ///
  /// In en, this message translates to:
  /// **'Open Settings > Wi-Fi and pick the other device\'s hotspot, then enter its password. Or point the Camera at the QR code shown on the other device and tap \"Join network\".'**
  String get hotspotJoinIos1;

  /// Hotspot wizard, Mac joins.
  ///
  /// In en, this message translates to:
  /// **'Click the Wi-Fi icon in the menu bar (or Control Center), pick the other device\'s hotspot and enter its password.'**
  String get hotspotJoinMac1;

  /// Hotspot wizard, Windows joins.
  ///
  /// In en, this message translates to:
  /// **'Click the network icon in the taskbar, open the Wi-Fi list, pick the other device\'s hotspot and enter its password.'**
  String get hotspotJoinWindows1;

  /// Hotspot wizard, Linux joins; command is a shell command, never translated.
  ///
  /// In en, this message translates to:
  /// **'Open the network menu (top right) > Wi-Fi > Select network, pick the other device\'s hotspot and enter its password. Or run: {command}'**
  String hotspotJoinLinux1(String command);

  /// Hotspot wizard, other device joins.
  ///
  /// In en, this message translates to:
  /// **'Open the Wi-Fi settings, pick the other device\'s hotspot and enter its password.'**
  String get hotspotJoinOther1;

  /// Hotspot wizard step after sharing.
  ///
  /// In en, this message translates to:
  /// **'On the other device, join this hotspot like any Wi-Fi network (see below).'**
  String get hotspotStepShareOther;

  /// Hotspot wizard step after joining.
  ///
  /// In en, this message translates to:
  /// **'Turn off any VPN. Mobile data can stay on.'**
  String get hotspotStepVpn;

  /// Hotspot wizard last step; quotes hotspotFindLabel.
  ///
  /// In en, this message translates to:
  /// **'Open LanDrop on both devices, then tap \"I\'m connected, find the other device\".'**
  String get hotspotStepOpenBoth;

  /// Hotspot wizard page title.
  ///
  /// In en, this message translates to:
  /// **'Connect without Wi-Fi'**
  String get hotspotWizardTitle;

  /// Hotspot wizard introduction.
  ///
  /// In en, this message translates to:
  /// **'No router needed: one device shares a Wi-Fi hotspot, the other joins it, and LanDrop finds the other device on that network. This also helps when the Wi-Fi keeps devices apart (guest, office or hotel networks). Files go directly between the two devices and do not use mobile data.'**
  String get hotspotIntro;

  /// Hotspot wizard role button.
  ///
  /// In en, this message translates to:
  /// **'This device shares the hotspot'**
  String get hotspotRoleShare;

  /// Hotspot wizard role button.
  ///
  /// In en, this message translates to:
  /// **'This device joins it'**
  String get hotspotRoleJoin;

  /// Wizard section header; platform is a platform name.
  ///
  /// In en, this message translates to:
  /// **'On this device ({platform})'**
  String wizardOnThisDevice(String platform);

  /// Button: opens the QR join page (Android).
  ///
  /// In en, this message translates to:
  /// **'Scan the hotspot QR code'**
  String get hotspotScanQr;

  /// Hotspot wizard: expandable steps for the other device.
  ///
  /// In en, this message translates to:
  /// **'On the other device: join the hotspot'**
  String get hotspotOtherJoin;

  /// Hotspot wizard: expandable steps for the other device.
  ///
  /// In en, this message translates to:
  /// **'On the other device: share a hotspot'**
  String get hotspotOtherShare;

  /// Button that searches for the other device after connecting.
  ///
  /// In en, this message translates to:
  /// **'I\'m connected, find the other device'**
  String get hotspotFindLabel;

  /// Hotspot wizard: link to the cable wizard.
  ///
  /// In en, this message translates to:
  /// **'Using a cable instead? Ethernet or USB'**
  String get hotspotCableInstead;

  /// Button (Android): start the LanDrop hotspot.
  ///
  /// In en, this message translates to:
  /// **'Start hotspot'**
  String get hotspotStart;

  /// Hotspot card title while it runs.
  ///
  /// In en, this message translates to:
  /// **'Hotspot is on'**
  String get hotspotOn;

  /// Hotspot network name (technical, LTR).
  ///
  /// In en, this message translates to:
  /// **'Name: {ssid}'**
  String hotspotName(String ssid);

  /// Hotspot without a password.
  ///
  /// In en, this message translates to:
  /// **'No password'**
  String get hotspotNoPassword;

  /// Hotspot password (technical, LTR).
  ///
  /// In en, this message translates to:
  /// **'Password: {password}'**
  String hotspotPassword(String password);

  /// Hotspot card hint under the QR code.
  ///
  /// In en, this message translates to:
  /// **'Scan with the other device\'s camera to join (Android 10+, iPhone). The hotspot stops when you tap Stop or close LanDrop.'**
  String get hotspotScanHint;

  /// Button: stop the hotspot.
  ///
  /// In en, this message translates to:
  /// **'Stop hotspot'**
  String get hotspotStop;

  /// Screen reader label of the hotspot QR code.
  ///
  /// In en, this message translates to:
  /// **'QR code to join this hotspot'**
  String get hotspotQrSemantics;

  /// Search progress line.
  ///
  /// In en, this message translates to:
  /// **'Looking at the new network…'**
  String get findPhaseNetwork;

  /// Search progress line.
  ///
  /// In en, this message translates to:
  /// **'Checking the usual hotspot addresses…'**
  String get findPhaseProbeHotspot;

  /// Search progress line.
  ///
  /// In en, this message translates to:
  /// **'Scanning the network…'**
  String get findPhaseScan;

  /// Search progress line.
  ///
  /// In en, this message translates to:
  /// **'Nothing found. Checking why…'**
  String get findPhaseWhy;

  /// Search found nothing (hotspot).
  ///
  /// In en, this message translates to:
  /// **'Check that both devices are on the same hotspot and LanDrop is open on both. Then try again, or use \"Add by IP\" with the address shown on the other device.'**
  String get findNothingHintHotspot;

  /// Search result header.
  ///
  /// In en, this message translates to:
  /// **'Found {count, plural, =1{1 device} other{{count} devices}}'**
  String findFound(int count);

  /// Button after a successful search.
  ///
  /// In en, this message translates to:
  /// **'Back to devices'**
  String get findBackToDevices;

  /// Search found nothing: title.
  ///
  /// In en, this message translates to:
  /// **'No device found yet'**
  String get findNothingTitle;

  /// Cable wizard, Ethernet on a Mac, step 1.
  ///
  /// In en, this message translates to:
  /// **'Plug the Ethernet cable into both computers (a USB or Thunderbolt Ethernet adapter is fine). Cable or router: the same steps.'**
  String get cableEthMac1;

  /// Cable wizard, Ethernet on a Mac, step 2.
  ///
  /// In en, this message translates to:
  /// **'Open System Settings > Network. If the adapter is not listed, click \"…\" > \"Add Service…\" (or the + button), pick the Ethernet adapter and click Create.'**
  String get cableEthMac2;

  /// Cable wizard, Ethernet on a Mac, step 3; prefix is an address prefix (169.254).
  ///
  /// In en, this message translates to:
  /// **'Select it and set \"Configure IPv4\" to \"Using DHCP\". With no router the Mac gives itself an address starting with {prefix}. That is normal.'**
  String cableEthMac3(String prefix);

  /// Cable wizard, Ethernet on Windows/Linux, step 1.
  ///
  /// In en, this message translates to:
  /// **'Plug the Ethernet cable into both computers.'**
  String get cableEthPlugBoth;

  /// Cable wizard, Ethernet on Windows, step 2; prefix is an address prefix (169.254).
  ///
  /// In en, this message translates to:
  /// **'Open Settings > Network & internet > Ethernet. It should say \"No Internet\" or \"Unidentified network\": that is fine, Windows gives itself an address starting with {prefix}.'**
  String cableEthWindows2(String prefix);

  /// Cable wizard, Ethernet on Windows, step 3.
  ///
  /// In en, this message translates to:
  /// **'Under \"IP assignment\" keep \"Automatic (DHCP)\". On the Windows Firewall prompt, allow LanDrop on Private networks. If the network is marked \"Public\", set it to Private.'**
  String get cableEthWindows3;

  /// Cable wizard, Ethernet on Linux, step 2; command is a shell command, never translated.
  ///
  /// In en, this message translates to:
  /// **'Open Settings > Network, pick the wired connection and open its settings > IPv4. Choose the \"Link-Local Only\" method and apply. Or run: {command}'**
  String cableEthLinux2(String command);

  /// Cable wizard, Ethernet on Linux, step 3.
  ///
  /// In en, this message translates to:
  /// **'Turn the connection off and on so it gets an address.'**
  String get cableEthLinux3;

  /// Cable wizard, Ethernet on other devices.
  ///
  /// In en, this message translates to:
  /// **'Plug an Ethernet cable (with an adapter if needed) into both computers, and make sure the wired network uses automatic addresses (DHCP or \"link-local\").'**
  String get cableEthOther1;

  /// Cable wizard, USB tethering on Android, step 1.
  ///
  /// In en, this message translates to:
  /// **'This phone is the one sharing: connect it to the computer with a USB cable.'**
  String get cableUsbAndroid1;

  /// Cable wizard, USB tethering on Android, step 2 (Android menu path).
  ///
  /// In en, this message translates to:
  /// **'Open Settings > Network & internet > Hotspot & tethering (names differ a little by brand), then turn on \"USB tethering\". It only switches on while a computer is plugged in.'**
  String get cableUsbAndroid2;

  /// Cable wizard, USB on iPhone, step 1.
  ///
  /// In en, this message translates to:
  /// **'Connect the iPhone to the computer with a USB cable and tap \"Trust\" if asked.'**
  String get cableUsbIos1;

  /// Cable wizard, USB on iPhone, step 2.
  ///
  /// In en, this message translates to:
  /// **'Open Settings > Personal Hotspot and turn on \"Allow Others to Join\". On a Windows PC, iTunes or the Apple Devices app must be installed.'**
  String get cableUsbIos2;

  /// Cable wizard, USB on a Mac, step 1.
  ///
  /// In en, this message translates to:
  /// **'Connect the phone to this Mac with a USB cable. On the phone turn on Personal Hotspot (iPhone) or USB tethering (Android).'**
  String get cableUsbMac1;

  /// Cable wizard, USB on a Mac, step 2.
  ///
  /// In en, this message translates to:
  /// **'The Mac shows a new network adapter in System Settings > Network (for example \"iPhone USB\" or \"RNDIS/Ethernet Gadget\"). Android USB tethering needs a driver on a Mac, which is not built in; an iPhone works out of the box.'**
  String get cableUsbMac2;

  /// Cable wizard, USB on Windows, step 1.
  ///
  /// In en, this message translates to:
  /// **'Connect the phone to this PC with a USB cable. On the phone turn on USB tethering (Android) or Personal Hotspot (iPhone).'**
  String get cableUsbWindows1;

  /// Cable wizard, USB on Windows, step 2.
  ///
  /// In en, this message translates to:
  /// **'Windows adds a new adapter (shown in Settings > Network & internet > Advanced network settings). Wait until it says Connected.'**
  String get cableUsbWindows2;

  /// Cable wizard, USB on Linux, step 1.
  ///
  /// In en, this message translates to:
  /// **'Connect the phone to this computer with a USB cable. On the phone turn on USB tethering (Android) or Personal Hotspot (iPhone).'**
  String get cableUsbLinux1;

  /// Cable wizard, USB on Linux, step 2.
  ///
  /// In en, this message translates to:
  /// **'A new wired connection appears (named like usb0, enx… or eth1). It usually connects by itself.'**
  String get cableUsbLinux2;

  /// Cable wizard, USB on other devices.
  ///
  /// In en, this message translates to:
  /// **'Connect the phone with a USB cable and turn on USB tethering or Personal Hotspot; the computer then has a new network adapter.'**
  String get cableUsbOther1;

  /// Cable wizard step (Ethernet).
  ///
  /// In en, this message translates to:
  /// **'Wait a few seconds: with no router it takes up to a minute for both computers to get their addresses.'**
  String get cableStepWait;

  /// Cable wizard step (USB tethering).
  ///
  /// In en, this message translates to:
  /// **'Turn off any VPN. The other device now shares its connection to this one.'**
  String get cableStepVpn;

  /// Cable wizard last step; quotes cableFindLabel.
  ///
  /// In en, this message translates to:
  /// **'Open LanDrop on both devices, then tap \"The cable is connected, find the other device\".'**
  String get cableStepOpenBoth;

  /// Cable wizard introduction.
  ///
  /// In en, this message translates to:
  /// **'No Wi-Fi or router needed: connect the two devices with a cable and LanDrop finds the other device on that link. Files go directly over the cable.'**
  String get cableIntro;

  /// Cable wizard choice.
  ///
  /// In en, this message translates to:
  /// **'Ethernet cable'**
  String get cableKindEthernet;

  /// Cable wizard choice.
  ///
  /// In en, this message translates to:
  /// **'USB tethering'**
  String get cableKindUsb;

  /// Cable wizard hint for the phone (menu paths).
  ///
  /// In en, this message translates to:
  /// **'On the phone: Android > Settings > Network & internet > Hotspot & tethering > USB tethering. iPhone > Settings > Personal Hotspot.'**
  String get cableTetherHint;

  /// Cable wizard search button.
  ///
  /// In en, this message translates to:
  /// **'The cable is connected, find the other device'**
  String get cableFindLabel;

  /// Search progress line (cable).
  ///
  /// In en, this message translates to:
  /// **'Checking the usual cable and USB addresses…'**
  String get cablePhaseProbe;

  /// Search found nothing (cable).
  ///
  /// In en, this message translates to:
  /// **'Check the cable, that the adapter shows as connected, and that LanDrop is open on both devices. A direct cable can take up to a minute to get addresses. Then try again, or use \"Add by IP\" with the address shown on the other device.'**
  String get cableNothingHint;

  /// Wi-Fi Direct page title.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi Direct'**
  String get wifiDirectTitle;

  /// Wi-Fi Direct introduction.
  ///
  /// In en, this message translates to:
  /// **'Connect two devices directly, without a router. Once connected, send files as usual.'**
  String get wifiDirectIntro;

  /// Wi-Fi Direct error card hint.
  ///
  /// In en, this message translates to:
  /// **'Try: Wi-Fi on, accept the invitation on the other device, keep both screens on and close together.'**
  String get wifiDirectTry;

  /// Wi-Fi Direct connected.
  ///
  /// In en, this message translates to:
  /// **'This device hosts the group.'**
  String get wifiDirectRoleOwner;

  /// Wi-Fi Direct connected.
  ///
  /// In en, this message translates to:
  /// **'Joined the other device\'s group.'**
  String get wifiDirectRoleClient;

  /// Wi-Fi Direct connected card title.
  ///
  /// In en, this message translates to:
  /// **'Connected via Wi-Fi Direct'**
  String get wifiDirectConnected;

  /// Wi-Fi Direct group name (technical).
  ///
  /// In en, this message translates to:
  /// **'Network: {ssid}'**
  String wifiDirectNetwork(String ssid);

  /// Wi-Fi Direct owner IP (technical).
  ///
  /// In en, this message translates to:
  /// **'Host address: {address}'**
  String wifiDirectHost(String address);

  /// Wi-Fi Direct search progress.
  ///
  /// In en, this message translates to:
  /// **'Looking for LanDrop devices…'**
  String get wifiDirectLooking;

  /// Wi-Fi Direct: no LanDrop device found.
  ///
  /// In en, this message translates to:
  /// **'No LanDrop device answered yet. Make sure LanDrop is open on the other device, then search again.'**
  String get wifiDirectNone;

  /// Wi-Fi Direct button.
  ///
  /// In en, this message translates to:
  /// **'Search again'**
  String get wifiDirectSearchAgain;

  /// Wi-Fi Direct button.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get wifiDirectDisconnect;

  /// Wi-Fi Direct peer list hint.
  ///
  /// In en, this message translates to:
  /// **'Tap a device to connect. The other device gets an Android invitation dialog and must accept it.'**
  String get wifiDirectTapHint;

  /// Wi-Fi Direct: searching.
  ///
  /// In en, this message translates to:
  /// **'Looking…'**
  String get wifiDirectLookingShort;

  /// Wi-Fi Direct: empty list.
  ///
  /// In en, this message translates to:
  /// **'No devices found yet. Open Wi-Fi Direct on the other device too.'**
  String get wifiDirectEmpty;

  /// Wi-Fi Direct peer status: invited.
  ///
  /// In en, this message translates to:
  /// **'Invitation sent. Accept it on the other device.'**
  String get wifiDirectInvited;

  /// Wi-Fi Direct peer status.
  ///
  /// In en, this message translates to:
  /// **'connected'**
  String get wifiDirectStatusConnected;

  /// Wi-Fi Direct peer status.
  ///
  /// In en, this message translates to:
  /// **'failed'**
  String get wifiDirectStatusFailed;

  /// Wi-Fi Direct peer status.
  ///
  /// In en, this message translates to:
  /// **'available'**
  String get wifiDirectStatusAvailable;

  /// Wi-Fi Direct peer status.
  ///
  /// In en, this message translates to:
  /// **'unavailable'**
  String get wifiDirectStatusUnavailable;

  /// Wi-Fi Direct button.
  ///
  /// In en, this message translates to:
  /// **'Create group here'**
  String get wifiDirectCreateGroup;

  /// Wi-Fi Direct hint; quotes wifiDirectCreateGroup.
  ///
  /// In en, this message translates to:
  /// **'\"Create group here\" makes this device the host, so the other device can find and join it from its own Wi-Fi Direct screen. Keep both screens on.'**
  String get wifiDirectCreateHint;

  /// Join by QR: wrong QR code.
  ///
  /// In en, this message translates to:
  /// **'That QR code is not a Wi-Fi code. Scan the code shown by the other phone\'s LanDrop hotspot.'**
  String get wifiJoinNotWifiQr;

  /// Join by QR: manual entry invalid.
  ///
  /// In en, this message translates to:
  /// **'Enter the network name (up to 32 characters) and its password (8 to 63 characters, or none for an open network).'**
  String get wifiJoinManualInvalid;

  /// Join by QR: what to do on the other phone (quotes in-app labels).
  ///
  /// In en, this message translates to:
  /// **'On the other phone, open LanDrop > Connect without Wi-Fi > \"This device shares the hotspot\" > Start hotspot. Then point this camera at the QR code it shows.'**
  String get wifiJoinScanIntro;

  /// Join by QR: button.
  ///
  /// In en, this message translates to:
  /// **'Allow the camera'**
  String get wifiJoinAllowCamera;

  /// Join by QR: manual entry toggle.
  ///
  /// In en, this message translates to:
  /// **'Enter name and password'**
  String get wifiJoinManualToggle;

  /// Join by QR: field label.
  ///
  /// In en, this message translates to:
  /// **'Network name'**
  String get wifiJoinNetworkName;

  /// Join by QR: field label.
  ///
  /// In en, this message translates to:
  /// **'Password (empty for an open network)'**
  String get wifiJoinPasswordLabel;

  /// Join by QR: checkbox.
  ///
  /// In en, this message translates to:
  /// **'Hidden network'**
  String get wifiJoinHidden;

  /// Join by QR: button.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get wifiJoinContinue;

  /// Join by QR: confirm title; ssid is technical.
  ///
  /// In en, this message translates to:
  /// **'Join {ssid}?'**
  String wifiJoinConfirmTitle(String ssid);

  /// Join by QR: explanation before joining.
  ///
  /// In en, this message translates to:
  /// **'LanDrop will ask Android to join this Wi-Fi network. Android will ask you to confirm. While joined, this phone may lose its internet connection. Only LanDrop uses this network; other apps keep using your normal connection where Android allows it.'**
  String get wifiJoinExplain;

  /// Join by QR: button.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get wifiJoinJoin;

  /// Join by QR: progress.
  ///
  /// In en, this message translates to:
  /// **'Joining {ssid}… Confirm the Android prompt when it appears.'**
  String wifiJoinJoining(String ssid);

  /// Join by QR: button.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get wifiJoinScanAgain;

  /// Join by QR: joined title.
  ///
  /// In en, this message translates to:
  /// **'Joined {ssid}'**
  String wifiJoinJoined(String ssid);

  /// Join by QR: section and button.
  ///
  /// In en, this message translates to:
  /// **'Find the other device'**
  String get wifiJoinFindTitle;

  /// Join by QR: button.
  ///
  /// In en, this message translates to:
  /// **'Leave network'**
  String get wifiJoinLeave;

  /// Hotspot error.
  ///
  /// In en, this message translates to:
  /// **'Only Android can start a hotspot from LanDrop.'**
  String get errHotspotUnsupportedPlatform;

  /// Hotspot error (Android 7).
  ///
  /// In en, this message translates to:
  /// **'This Android version cannot start a hotspot from an app. Use Settings > Hotspot instead.'**
  String get errHotspotUnsupportedSdk;

  /// Hotspot error.
  ///
  /// In en, this message translates to:
  /// **'LanDrop needs the \"Nearby devices\" permission to start a hotspot.'**
  String get errHotspotPermissionNearby;

  /// Hotspot error.
  ///
  /// In en, this message translates to:
  /// **'LanDrop needs the location permission to start a hotspot (Android requires it for Wi-Fi features; LanDrop does not use your location).'**
  String get errHotspotPermissionLocation;

  /// Hotspot error.
  ///
  /// In en, this message translates to:
  /// **'The hotspot started but Android did not report its name.'**
  String get errHotspotNoName;

  /// Hotspot error.
  ///
  /// In en, this message translates to:
  /// **'Starting a hotspot is not available here.'**
  String get errHotspotUnavailable;

  /// Hotspot error; detail is a technical reason (English).
  ///
  /// In en, this message translates to:
  /// **'Android refused: {detail}. On Android 12 and older, Location must also be switched on.'**
  String errHotspotRefused(String detail);

  /// Default reason inserted into errHotspotRefused.
  ///
  /// In en, this message translates to:
  /// **'permission missing'**
  String get errHotspotPermissionMissing;

  /// Hotspot error.
  ///
  /// In en, this message translates to:
  /// **'Android cannot start it right now, usually because the normal hotspot or tethering is on. Turn that off, or use it instead.'**
  String get errHotspotIncompatible;

  /// Hotspot error.
  ///
  /// In en, this message translates to:
  /// **'Hotspots are not allowed on this device (for example by a work profile or the carrier).'**
  String get errHotspotDisallowed;

  /// Hotspot error.
  ///
  /// In en, this message translates to:
  /// **'No free Wi-Fi channel. Try again in a moment.'**
  String get errHotspotNoChannel;

  /// Hotspot error.
  ///
  /// In en, this message translates to:
  /// **'A hotspot is already starting.'**
  String get errHotspotBusy;

  /// Hotspot error.
  ///
  /// In en, this message translates to:
  /// **'The hotspot was stopped.'**
  String get errHotspotCancelled;

  /// Hotspot error.
  ///
  /// In en, this message translates to:
  /// **'The hotspot could not start.'**
  String get errHotspotFailed;

  /// Hotspot error; detail is technical (English).
  ///
  /// In en, this message translates to:
  /// **'The hotspot could not start: {detail}.'**
  String errHotspotFailedDetail(String detail);

  /// Hotspot error; error is technical (English).
  ///
  /// In en, this message translates to:
  /// **'The hotspot could not start: {error}'**
  String errHotspotStartError(String error);

  /// Wi-Fi Direct error.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi Direct is not available on this device.'**
  String get errWifiDirectUnsupported;

  /// Wi-Fi Direct error.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi is off. Turn Wi-Fi on (no router needed), then try again.'**
  String get errWifiDirectWifiOff;

  /// Wi-Fi Direct error.
  ///
  /// In en, this message translates to:
  /// **'LanDrop needs permission to find nearby devices. Allow it, and on Android 12 and older also switch Location on.'**
  String get errWifiDirectPermission;

  /// Wi-Fi Direct error.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi Direct is busy. Wait a moment and try again, or tap Disconnect first.'**
  String get errWifiDirectBusy;

  /// Wi-Fi Direct error.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi Direct is not ready yet. Try again.'**
  String get errWifiDirectNotReady;

  /// Wi-Fi Direct error.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi Direct failed. Turn Wi-Fi off and on, and try again.'**
  String get errWifiDirectFailed;

  /// Wi-Fi Direct error; detail is technical (English).
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi Direct failed ({detail}). Turn Wi-Fi off and on, and try again.'**
  String errWifiDirectFailedDetail(String detail);

  /// Join by QR error.
  ///
  /// In en, this message translates to:
  /// **'Joining a Wi-Fi network from LanDrop needs Android 7 or newer. Join it in the Wi-Fi settings instead.'**
  String get errWifiJoinUnsupported;

  /// Join by QR error.
  ///
  /// In en, this message translates to:
  /// **'LanDrop needs the camera to scan the QR code. Allow it in the app settings, or type the name and password instead.'**
  String get errWifiJoinCamera;

  /// Join by QR error.
  ///
  /// In en, this message translates to:
  /// **'Android did not join the network. Check that the other phone\'s hotspot is on and close by, that the password is right, and that you did not decline the Android prompt. Then try again.'**
  String get errWifiJoinTimeout;

  /// Join by QR error.
  ///
  /// In en, this message translates to:
  /// **'The network went away. Check that the hotspot is still on, then scan again.'**
  String get errWifiJoinLost;

  /// Join by QR error.
  ///
  /// In en, this message translates to:
  /// **'This network uses an old security type (WEP) that Android no longer lets apps join. Join it in the Wi-Fi settings instead.'**
  String get errWifiJoinUnsupportedSecurity;

  /// Join by QR error.
  ///
  /// In en, this message translates to:
  /// **'Android did not allow LanDrop to change the network. Join it in the Wi-Fi settings instead.'**
  String get errWifiJoinPermission;

  /// Join by QR error.
  ///
  /// In en, this message translates to:
  /// **'Could not join the network. Try again, or join it in the Wi-Fi settings.'**
  String get errWifiJoinFailed;

  /// Join by QR error; detail is technical (English).
  ///
  /// In en, this message translates to:
  /// **'Could not join the network ({detail}). Try again, or join it in the Wi-Fi settings.'**
  String errWifiJoinFailedDetail(String detail);

  /// Advanced: last error when plain HTTP failed to start; error is technical (English).
  ///
  /// In en, this message translates to:
  /// **'Plain HTTP for browsers could not start: {error}'**
  String errorWebHttpStart(String error);

  /// System file picker window title.
  ///
  /// In en, this message translates to:
  /// **'Choose files to send'**
  String get pickFilesTitle;

  /// System folder picker window title.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder to send'**
  String get pickFolderTitle;

  /// Connection helper page title.
  ///
  /// In en, this message translates to:
  /// **'Help me connect'**
  String get helperTitle;

  /// Helper: automatic check running.
  ///
  /// In en, this message translates to:
  /// **'Checking your connection…'**
  String get helperChecking;

  /// Helper: a device appeared; name is the device name.
  ///
  /// In en, this message translates to:
  /// **'Found {name}!'**
  String helperFound(String name);

  /// Helper: the check found nothing to fix.
  ///
  /// In en, this message translates to:
  /// **'Nothing looks wrong on this device.'**
  String get helperCheckFine;

  /// Helper question 1.
  ///
  /// In en, this message translates to:
  /// **'Are both devices on the same Wi-Fi?'**
  String get helperQ1;

  /// Helper question 1 answer.
  ///
  /// In en, this message translates to:
  /// **'Yes, same Wi-Fi'**
  String get helperQ1Same;

  /// Helper question 1 answer.
  ///
  /// In en, this message translates to:
  /// **'No, or there is no Wi-Fi'**
  String get helperQ1Different;

  /// Helper question 1 answer.
  ///
  /// In en, this message translates to:
  /// **'I\'ll use a cable'**
  String get helperQ1Cable;

  /// Helper: same Wi-Fi checklist.
  ///
  /// In en, this message translates to:
  /// **'Open LanDrop on the other device and keep its screen on. Turn off any VPN.'**
  String get helperChecklist;

  /// Helper: search button (same Wi-Fi).
  ///
  /// In en, this message translates to:
  /// **'Search again'**
  String get helperSearchAgain;

  /// Helper: search found nothing on the same Wi-Fi.
  ///
  /// In en, this message translates to:
  /// **'Make sure both devices use the same Wi-Fi network (not a guest network) and LanDrop is open on both, then search again.'**
  String get helperSameWifiNothing;

  /// Helper: same Wi-Fi did not work.
  ///
  /// In en, this message translates to:
  /// **'This Wi-Fi may keep devices apart. Let\'s connect them directly.'**
  String get helperBlocked;

  /// Helper: button to question 2.
  ///
  /// In en, this message translates to:
  /// **'Connect directly'**
  String get helperConnectDirectly;

  /// Helper question 2.
  ///
  /// In en, this message translates to:
  /// **'What is the other device?'**
  String get helperQ2;

  /// Helper question 2 answer.
  ///
  /// In en, this message translates to:
  /// **'An Android phone'**
  String get helperQ2Android;

  /// Helper question 2 answer.
  ///
  /// In en, this message translates to:
  /// **'An iPhone'**
  String get helperQ2Iphone;

  /// Helper question 2 answer.
  ///
  /// In en, this message translates to:
  /// **'A computer'**
  String get helperQ2Computer;

  /// Helper question 2 answer.
  ///
  /// In en, this message translates to:
  /// **'Only a browser'**
  String get helperQ2Browser;

  /// Helper: label of the recommended way.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get helperRecommended;

  /// Helper method title (Android shares, other phone scans).
  ///
  /// In en, this message translates to:
  /// **'Share a hotspot from this phone'**
  String get helperMethodShareQrTitle;

  /// Helper method body.
  ///
  /// In en, this message translates to:
  /// **'No internet is used. The other phone scans the code to join.'**
  String get helperMethodShareQrBody;

  /// Helper method title.
  ///
  /// In en, this message translates to:
  /// **'Share a hotspot from this device'**
  String get helperMethodShareTitle;

  /// Helper method body.
  ///
  /// In en, this message translates to:
  /// **'No internet is used. The other device joins this hotspot like any Wi-Fi network.'**
  String get helperMethodShareBody;

  /// Helper method title.
  ///
  /// In en, this message translates to:
  /// **'Join the other device\'s hotspot'**
  String get helperMethodJoinTitle;

  /// Helper method body.
  ///
  /// In en, this message translates to:
  /// **'Turn on the hotspot on the other device, then join it from this one. No internet is used.'**
  String get helperMethodJoinBody;

  /// Helper method title (Android).
  ///
  /// In en, this message translates to:
  /// **'Scan the other phone\'s hotspot code'**
  String get helperMethodJoinQrTitle;

  /// Helper method body (Android).
  ///
  /// In en, this message translates to:
  /// **'When the other phone shares a hotspot with LanDrop, this phone scans its QR code and joins.'**
  String get helperMethodJoinQrBody;

  /// Helper method title (Android).
  ///
  /// In en, this message translates to:
  /// **'Use Wi-Fi Direct'**
  String get helperMethodWifiDirectTitle;

  /// Helper method body (Android).
  ///
  /// In en, this message translates to:
  /// **'Phone to phone without a router. Both phones must run Android.'**
  String get helperMethodWifiDirectBody;

  /// Helper: button.
  ///
  /// In en, this message translates to:
  /// **'Open Wi-Fi Direct'**
  String get helperOpenWifiDirect;

  /// Helper method title.
  ///
  /// In en, this message translates to:
  /// **'Use a browser on the other device'**
  String get helperMethodBrowserTitle;

  /// Helper method body.
  ///
  /// In en, this message translates to:
  /// **'Nothing to install: the other device opens a link in its browser to send or download files. Both devices must be on the same Wi-Fi or hotspot.'**
  String get helperMethodBrowserBody;

  /// Helper: button to the Shares page.
  ///
  /// In en, this message translates to:
  /// **'Open the Share page'**
  String get helperOpenShares;

  /// Helper section header.
  ///
  /// In en, this message translates to:
  /// **'On this device'**
  String get helperOnThisDevice;

  /// Helper section header.
  ///
  /// In en, this message translates to:
  /// **'On the other device'**
  String get helperOnOtherDevice;

  /// Helper: alternative methods header.
  ///
  /// In en, this message translates to:
  /// **'Other ways'**
  String get helperOtherWays;

  /// Helper: back to the questions.
  ///
  /// In en, this message translates to:
  /// **'Try another way'**
  String get helperTryAnother;

  /// Helper: copies the (English) diagnosis report.
  ///
  /// In en, this message translates to:
  /// **'Copy connection report'**
  String get helperCopyReport;

  /// Join by QR: the camera preview failed to start.
  ///
  /// In en, this message translates to:
  /// **'The camera could not start. Type the name and password below instead.'**
  String get wifiJoinCameraFailed;

  /// Transfer card status: stopped by either side (Cancel button).
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get transferCancelled;

  /// Transfer card title when an outgoing transfer is done.
  ///
  /// In en, this message translates to:
  /// **'Sent to {name}'**
  String transferSentTo(String name);

  /// Transfer card title when an incoming transfer is done.
  ///
  /// In en, this message translates to:
  /// **'Received from {name}'**
  String transferReceivedFrom(String name);

  /// Transfer card status while running, before the speed is known. {percent} is already formatted (Persian digits in fa).
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String transferPercent(String percent);

  /// Transfer card status while running: percent and speed (e.g. 4.2 MB/s).
  ///
  /// In en, this message translates to:
  /// **'{percent}% · {speed}'**
  String transferPercentSpeed(String percent, String speed);

  /// Transfer card: estimated time left (e.g. "1 min left").
  ///
  /// In en, this message translates to:
  /// **'{time} left'**
  String transferTimeLeft(String time);

  /// Transfer card button that stops a running transfer.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get transferCancelAction;

  /// Transfer card status after Cancel, until the other side has stopped.
  ///
  /// In en, this message translates to:
  /// **'Cancelling…'**
  String get transferCancelling;

  /// Transfer card button: opens the received file (or the folder for several files).
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get transferOpen;

  /// Transfer card button: shows the received file in the file manager.
  ///
  /// In en, this message translates to:
  /// **'Show in folder'**
  String get transferShowInFolder;

  /// Transfer card button (phones): copies where the received files are.
  ///
  /// In en, this message translates to:
  /// **'Copy path'**
  String get transferCopyPath;

  /// Snackbar after Copy path.
  ///
  /// In en, this message translates to:
  /// **'Path copied'**
  String get transferPathCopied;

  /// Snackbar when Open / Show in folder failed; {path} stays left to right.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open it. The files are in {path}.'**
  String transferOpenFailed(String path);

  /// Transfer card note on a transfer accepted without asking (trusted device).
  ///
  /// In en, this message translates to:
  /// **'Accepted automatically'**
  String get transferAutoAccepted;

  /// Transfer card: a single file that failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get transferFileFailed;

  /// Incoming dialog badge: never accepted files from this device before.
  ///
  /// In en, this message translates to:
  /// **'First time from this device'**
  String get incomingFirstTime;

  /// Incoming dialog badge: files were accepted from this device before (same security code).
  ///
  /// In en, this message translates to:
  /// **'Trusted device'**
  String get incomingTrusted;

  /// Incoming dialog badge: the sender could not prove which device it is (e.g. another app).
  ///
  /// In en, this message translates to:
  /// **'Identity not confirmed'**
  String get incomingUnverified;

  /// Incoming dialog checkbox: accept future transfers from this device without asking.
  ///
  /// In en, this message translates to:
  /// **'Always accept from this device'**
  String get incomingAlwaysAccept;

  /// Incoming dialog warning: the sender has the name of a trusted device but another security code.
  ///
  /// In en, this message translates to:
  /// **'This device uses the name of \"{name}\" but is not the same device.'**
  String incomingAliasWarning(String name);

  /// Incoming dialog: button next to the save folder, opens Settings.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get incomingChangeFolder;

  /// Incoming dialog: expands the address and security code of the sender.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get incomingDetails;

  /// Snackbar when a trusted device's transfer was accepted without asking.
  ///
  /// In en, this message translates to:
  /// **'Accepted from {name} automatically'**
  String autoAcceptedSnack(String name);

  /// Snackbar / transfer card action: ask again next time for this device.
  ///
  /// In en, this message translates to:
  /// **'Stop auto-accept'**
  String get autoAcceptStop;

  /// Settings row and page title: devices files were accepted from.
  ///
  /// In en, this message translates to:
  /// **'Trusted devices'**
  String get settingsTrustedDevices;

  /// Settings row subtitle: number of trusted devices.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{None yet} =1{1 device} other{{count} devices}}'**
  String settingsTrustedDevicesSub(int count);

  /// Trusted devices page without devices.
  ///
  /// In en, this message translates to:
  /// **'Devices you accept files from appear here.'**
  String get trustedEmpty;

  /// Trusted devices page: how trust works.
  ///
  /// In en, this message translates to:
  /// **'A device counts as the same only with the same security code, never by its name alone.'**
  String get trustedIntro;

  /// Trusted devices page: switch per device.
  ///
  /// In en, this message translates to:
  /// **'Accept automatically'**
  String get trustedAutoAccept;

  /// Trusted devices page: subtitle of the auto-accept switch.
  ///
  /// In en, this message translates to:
  /// **'Saved without asking. You\'ll see a notice each time.'**
  String get trustedAutoAcceptSub;

  /// Trusted devices page: rename button (display name only).
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get trustedRename;

  /// Rename dialog field label.
  ///
  /// In en, this message translates to:
  /// **'Name shown on this device'**
  String get trustedRenameLabel;

  /// Trusted devices page: forget this device.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get trustedRemove;

  /// Snackbar after removing a trusted device.
  ///
  /// In en, this message translates to:
  /// **'{name} removed'**
  String trustedRemoved(String name);

  /// Trusted devices page: the name the device announces, when renamed here.
  ///
  /// In en, this message translates to:
  /// **'Device name: {alias}'**
  String trustedDeviceName(String alias);

  /// Trusted devices page: switch that lifts the size limit for auto-accept.
  ///
  /// In en, this message translates to:
  /// **'Also accept large transfers automatically'**
  String get trustedLarge;

  /// Trusted devices page: subtitle of the large-transfer switch.
  ///
  /// In en, this message translates to:
  /// **'Off: transfers over {size} always ask.'**
  String trustedLargeSub(String size);
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
