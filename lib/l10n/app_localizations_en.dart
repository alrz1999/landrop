// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'LanDrop';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languagePersian => 'فارسی';

  @override
  String get commonCancel => 'Cancel';

  @override
  String sizeBytes(String value) {
    return '$value B';
  }

  @override
  String sizeKB(String value) {
    return '$value KB';
  }

  @override
  String sizeMB(String value) {
    return '$value MB';
  }

  @override
  String sizeGB(String value) {
    return '$value GB';
  }

  @override
  String sizeTB(String value) {
    return '$value TB';
  }

  @override
  String speedPerSecond(String size) {
    return '$size/s';
  }

  @override
  String durationSeconds(String seconds) {
    return '$seconds s';
  }

  @override
  String durationMinutes(String minutes) {
    return '$minutes min';
  }

  @override
  String durationHours(String hours) {
    return '$hours h';
  }

  @override
  String durationHoursMinutes(String hours, String minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get sendErrorDeclined => 'The other device declined.';

  @override
  String get sendErrorBusy =>
      'The other device is busy with another transfer. Try again in a moment.';

  @override
  String get sendErrorUnreachable =>
      'Could not reach the other device. Check that both are on the same network.';

  @override
  String get sendErrorCancelled => 'The transfer was cancelled.';

  @override
  String get sendErrorTimeout => 'The other device stopped responding.';

  @override
  String get sendErrorFingerprintMismatch =>
      'The other device\'s security code has changed. Search again before sending.';

  @override
  String get sendErrorDiskError => 'A file could not be read or saved.';

  @override
  String get sendErrorUnknown => 'Sending failed.';

  @override
  String diagWhatToDo(String fix) {
    return 'What to do: $fix';
  }

  @override
  String get diagServerDownTitle =>
      'This device cannot receive files right now';

  @override
  String get diagServerDownDetail =>
      'LanDrop on this device is not accepting connections, so other devices cannot see it or send to it.';

  @override
  String get diagServerDownFix =>
      'Use \"Restart service\" in Settings, or close and reopen LanDrop.';

  @override
  String get diagDiscoveryFailedTitle => 'Automatic discovery is off';

  @override
  String get diagDiscoveryFailedDetail =>
      'LanDrop could not start looking for nearby devices, so they will not appear on their own. Sending by IP still works.';

  @override
  String get diagDiscoveryFailedFix =>
      'Use \"Rescan network\" or \"Add by IP\". Restarting LanDrop or allowing local network access may fix it.';

  @override
  String get diagNoLanTitle => 'Not connected to Wi-Fi or a LAN';

  @override
  String get diagNoLanDetail =>
      'This device has no local network address, so it cannot reach other devices nearby.';

  @override
  String get diagNoLanFix =>
      'Connect to the same Wi-Fi as the other device, plug in an Ethernet cable, or turn on a hotspot on one device and join it from the other.';

  @override
  String get diagLinkLocalOnlyTitle => 'Direct cable or no DHCP';

  @override
  String get diagLinkLocalOnlyDetail =>
      'This looks like a direct cable or a network without DHCP. LanDrop works, but both devices must be connected to each other; give both devices a moment to get addresses.';

  @override
  String get diagVpnActiveTitle => 'A VPN is on';

  @override
  String get diagVpnActiveDetail =>
      'VPNs often hide the local network, so nearby devices cannot reach each other.';

  @override
  String get diagVpnActiveFix =>
      'Turn the VPN off, or allow \"local network access\" in its settings, then try again.';

  @override
  String get diagAnnounceBlockedTitle => 'Devices only show up after a scan';

  @override
  String get diagAnnounceBlockedDetail =>
      'Your router seems to block the messages devices use to find each other (multicast and broadcast). Transfers still work by IP.';

  @override
  String get diagAnnounceBlockedFix =>
      'Use \"Rescan network\" or \"Add by IP\". To fix it for good, turn on multicast / turn off \"AP isolation\" in the router.';

  @override
  String get diagSomePeersSilentTitle =>
      'Some devices did not announce themselves';

  @override
  String get diagSomePeersSilentDetail =>
      'Other devices were found automatically, but these only by scan or IP. They may be on another part of the network or have discovery turned off.';

  @override
  String get diagProbeRefusedTitle =>
      'The device is there, but LanDrop is not answering';

  @override
  String get diagProbeRefusedDetail =>
      'The other device answered, but nothing accepted the connection. LanDrop is probably closed there, or it uses a different port.';

  @override
  String get diagProbeRefusedFix =>
      'Open LanDrop on the other device and keep it in front. Check the address and port shown on its screen.';

  @override
  String get diagProbeTimeoutTitle => 'No answer from that address';

  @override
  String get diagProbeTimeoutDetail =>
      'Nothing came back. A firewall, \"AP / client isolation\" on the router, or being on a different network can cause this.';

  @override
  String get diagProbeTimeoutFix =>
      'Check both devices are on the same Wi-Fi (not a guest network). Allow LanDrop in the firewall. If it still fails, turn on a hotspot on one device and join it from the other.';

  @override
  String get diagProbeUnreachableTitle =>
      'That address cannot be reached from here';

  @override
  String get diagProbeUnreachableDetail =>
      'This device has no way to reach that address. It is probably on a different network, or the address is wrong.';

  @override
  String get diagProbeUnreachableFix =>
      'Check the address on the other device, and connect both to the same Wi-Fi or hotspot.';

  @override
  String get diagProbeFingerprintMismatchTitle =>
      'A different device is at this address';

  @override
  String get diagProbeFingerprintMismatchDetail =>
      'The device at this address is not the one LanDrop knew before. Either another device took the address, or LanDrop was reinstalled there and made a new security key.';

  @override
  String get diagProbeFingerprintMismatchFix =>
      'Check the fingerprint shown in Settings on the other device. If it is right, remove and add the device again.';

  @override
  String get diagProbeNotLandropTitle =>
      'Something answered, but it is not LanDrop';

  @override
  String get diagProbeNotLandropDetail =>
      'A program accepted the connection on that port, but it did not respond like LanDrop or LocalSend.';

  @override
  String get diagProbeNotLandropFix =>
      'Check the port shown in LanDrop on the other device.';

  @override
  String get diagProbeOkTitle => 'The device answers';

  @override
  String diagProbeOkDetail(String alias) {
    return '$alias at this address is reachable and working.';
  }

  @override
  String get diagDifferentSubnetTitle =>
      'The devices seem to be on different networks';

  @override
  String get diagDifferentSubnetDetail =>
      'The addresses do not match, so the devices may be on different Wi-Fi networks, or one is on a guest network.';

  @override
  String get diagDifferentSubnetFix =>
      'Connect both devices to the same Wi-Fi (not a guest network).';

  @override
  String get diagHotspotLikelyFixTitle => 'No other device found yet';

  @override
  String get diagHotspotLikelyFixDetail =>
      'If LanDrop is open on the other device and it still does not show up, this network probably keeps devices apart (common on guest, office, school and hotel Wi-Fi). Connecting both devices through a hotspot from a phone or laptop usually fixes it, and needs no router.';

  @override
  String get diagHotspotLikelyFixFix =>
      'Tap \"Connect with a hotspot\" for step-by-step help, or use \"Add by IP\" if you know the other device\'s address.';

  @override
  String get diagMdnsOnlyTitle => 'Standard device discovery works';

  @override
  String get diagMdnsOnlyDetail =>
      'LanDrop\'s own announcements are blocked on this network, but standard device discovery (mDNS / Bonjour) works. Transfers will work.';

  @override
  String get diagMdnsVisibleUnreachableTitle =>
      'The device is on your network, but LanDrop cannot reach it';

  @override
  String diagMdnsVisibleUnreachableDetail(String reason) {
    return 'The device is on your network and announces itself, but LanDrop\'s port cannot be reached: a firewall on that device or this one, or the app is closing. $reason';
  }

  @override
  String get diagMdnsVisibleUnreachableFix =>
      'Allow LanDrop in the firewall on both devices, keep LanDrop open on the other device, then use \"Rescan network\".';

  @override
  String get diagMdnsReasonTimeout =>
      'Nothing answered on LanDrop\'s port (timeout), which usually means a firewall is dropping it.';

  @override
  String get diagMdnsReasonRefused =>
      'The port refused the connection, which usually means LanDrop is closing or not running there.';

  @override
  String get diagMdnsReasonFingerprintMismatch =>
      'Something answered, but with a different security key than the device announced.';

  @override
  String get diagMdnsReasonOther =>
      'The connection or the check of its identity failed.';

  @override
  String get diagUdpOnlyNoMdnsTitle => 'Standard discovery (mDNS) is blocked';

  @override
  String get diagUdpOnlyNoMdnsDetail =>
      'Devices were found with LanDrop\'s own announcements, but not through standard discovery (mDNS / Bonjour). This is not a problem for LanDrop.';

  @override
  String get diagMdnsUnavailableTitle =>
      'Standard device discovery could not start';

  @override
  String get diagMdnsUnavailableDetail =>
      'LanDrop could not start mDNS / Bonjour on this device, so it relies on its own announcements. Sending by IP still works.';

  @override
  String get diagMdnsUnavailableFix =>
      'Use \"Rescan network\" or \"Add by IP\".';

  @override
  String get diagMdnsUnavailableDetailBoth =>
      'LanDrop could not start mDNS / Bonjour on this device, so it relies on its own announcements. Those failed too, so devices will not appear on their own. Sending by IP still works.';

  @override
  String get diagAllGoodTitle => 'No problems found';

  @override
  String get diagAllGoodDetail =>
      'This device is on a local network and ready to send and receive.';

  @override
  String get diagAllGoodFix =>
      'If a device is still missing, make sure LanDrop is open on it, then use \"Rescan network\" or \"Add by IP\".';

  @override
  String get diagNetworkTitle => 'Your network';

  @override
  String get diagNetworkDetail => 'Addresses this device has, for reference.';

  @override
  String get diagSearchFailedTitle => 'The search failed';

  @override
  String get commonTryAgain => 'Try again';

  @override
  String get commonDismiss => 'Dismiss';

  @override
  String get commonClose => 'Close';

  @override
  String get commonShow => 'Show';

  @override
  String get commonStop => 'Stop';

  @override
  String get commonDecline => 'Decline';

  @override
  String get commonAccept => 'Accept';

  @override
  String get commonSave => 'Save';

  @override
  String get deviceKindPhone => 'Phone';

  @override
  String get deviceKindComputer => 'Computer';

  @override
  String get deviceKindBrowser => 'Browser';

  @override
  String get selfStatusReady => 'Visible to nearby devices';

  @override
  String get selfStatusStarting => 'Getting ready…';

  @override
  String get selfStatusStopped => 'Stopped';

  @override
  String get selfStatusError => 'Can\'t receive right now.';

  @override
  String get selfRename => 'Rename device';

  @override
  String selfAddress(String ip, String port) {
    return '$ip · port $port';
  }

  @override
  String selfAddressUnknown(String port) {
    return 'IP unknown · port $port';
  }

  @override
  String get peerDetails => 'Details';

  @override
  String get detailsAddress => 'Address';

  @override
  String get detailsConnection => 'Connection';

  @override
  String get detailsCableLink => 'Direct cable link';

  @override
  String get detailsOtherAddresses => 'Other addresses';

  @override
  String get detailsModel => 'Model';

  @override
  String get securityCode => 'Security code';

  @override
  String get securityCodeHint =>
      'Compare this code with the other device to be sure it\'s really yours.';

  @override
  String get emptyTitle => 'No devices found yet';

  @override
  String get emptyBody =>
      'Make sure LanDrop is open on the other device and both are on the same Wi-Fi.';

  @override
  String get emptyWhy => 'Why can\'t I see my device?';

  @override
  String get connectHotspotTitle => 'Connect without Wi-Fi / router';

  @override
  String get connectHotspotSub =>
      'Use a hotspot from a phone or laptop, step by step';

  @override
  String get connectCableTitle => 'Connect with a cable';

  @override
  String get connectCableSub =>
      'Ethernet cable between two computers, or USB tethering';

  @override
  String get connectWifiDirectTitle => 'Connect with Wi-Fi Direct';

  @override
  String get connectWifiDirectSub =>
      'Phone to phone without a router (Android)';

  @override
  String get connectWifiJoinTitle => 'Join a hotspot by QR';

  @override
  String get connectWifiJoinSub =>
      'Scan the QR code of another phone\'s LanDrop hotspot';

  @override
  String get qrForLanDrop => 'For another LanDrop app';

  @override
  String get addressNotAvailable => 'Address not available yet';

  @override
  String get qrSelfSemantics => 'QR code with this device\'s address';

  @override
  String transferSummary(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$doneString of $totalString files';
  }

  @override
  String transferDeclined(String name) {
    return 'Declined by $name';
  }

  @override
  String transferFailed(String reason) {
    return 'Failed: $reason';
  }

  @override
  String get transferFailedPlain => 'Failed';

  @override
  String get transferDone => 'Done';

  @override
  String transferWaiting(String name) {
    return 'Waiting for $name to accept…';
  }

  @override
  String get transferRunning => 'Transferring';

  @override
  String transferFrom(String name) {
    return 'From $name';
  }

  @override
  String transferTo(String name) {
    return 'To $name';
  }

  @override
  String transferSavedTo(String path) {
    return 'Saved to $path';
  }

  @override
  String incomingTitle(String name, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString files',
      one: '1 file',
    );
    return '$name wants to send you $_temp0';
  }

  @override
  String incomingFromBrowser(String ip) {
    return 'Web browser at $ip';
  }

  @override
  String incomingFromBrowserModel(String ip, String model) {
    return 'Web browser at $ip · $model';
  }

  @override
  String fileCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString files',
      one: '1 file',
    );
    return '$_temp0';
  }

  @override
  String incomingTotal(String size) {
    return 'Total: $size';
  }

  @override
  String incomingSavesTo(String folder) {
    return 'Saves to $folder';
  }

  @override
  String get pairingTitle => 'Allow a browser to send you files?';

  @override
  String get pairingCodeLabel => 'Code shown in the browser';

  @override
  String pairingCodeSemantics(String digits) {
    return 'Pairing code $digits';
  }

  @override
  String get pairingBody =>
      'Approve only if the browser shows the same code. For the next hour it can then offer you files; you still accept every transfer.';

  @override
  String get pairingApprove => 'Approve';

  @override
  String get addByIpTitle => 'Add device by IP';

  @override
  String get addByIpLabel => 'IP address';

  @override
  String addByIpHint(String example, String exampleWithPort) {
    return '$example or $exampleWithPort';
  }

  @override
  String addByIpInvalid(String example) {
    return 'Enter an IPv4 address, e.g. $example';
  }

  @override
  String get addByIpAdd => 'Add';

  @override
  String addByIpAdded(String name) {
    return 'Added $name';
  }

  @override
  String addByIpNoAnswer(String address) {
    return 'No LanDrop device answered at $address.';
  }

  @override
  String addByIpError(String address, String error) {
    return 'Could not reach $address — $error';
  }

  @override
  String get addFailedTitle => 'Device not found';

  @override
  String get addFailedDiagnose => 'Diagnose this IP';

  @override
  String get pickerEmpty => 'No devices found yet.';

  @override
  String get pickerHelp => 'Help me connect';

  @override
  String sendPickerTitleFiles(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString files',
      one: '1 file',
    );
    return 'Send $_temp0 to…';
  }

  @override
  String sendPickerTitleFolder(String name) {
    return 'Send folder \"$name\" to…';
  }

  @override
  String get aliasLabel => 'Name shown to others';

  @override
  String get settingsDeviceName => 'Device name';

  @override
  String get homeSend => 'Send';

  @override
  String get homeNearbyDevices => 'Nearby devices';

  @override
  String get homeRescan => 'Rescan network';

  @override
  String get homeAddByIp => 'Add by IP';

  @override
  String get homeDiscoveryOff => 'Automatic search is off on this device.';

  @override
  String get homeHelp => 'Help';

  @override
  String homeHotspotBanner(String ssid) {
    return 'Sharing hotspot \"$ssid\"';
  }

  @override
  String get homeActivity => 'Activity';

  @override
  String get homeClearFinished => 'Clear finished';

  @override
  String get homeShareLink => 'Share link';

  @override
  String homeActiveShares(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString links',
      one: '1 link',
    );
    return 'Sharing $_temp0';
  }

  @override
  String homeReceiving(int count, String name) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString files',
      one: '1 file',
    );
    return 'Receiving $_temp0 from $name';
  }

  @override
  String homeScanFinished(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString devices',
      one: '1 device',
    );
    return 'Scan finished: $_temp0 found';
  }

  @override
  String homeScanFailed(String error) {
    return 'Scan failed: $error';
  }

  @override
  String get sendSheetTitle => 'What do you want to send?';

  @override
  String get sendSheetFiles => 'Files';

  @override
  String get sendSheetFolder => 'Folder';

  @override
  String sendSent(String name) {
    return 'Sent to $name.';
  }

  @override
  String sendDeclined(String name) {
    return '$name declined.';
  }

  @override
  String sendFailed(String name) {
    return 'Couldn\'t reach $name. Is LanDrop still open there?';
  }

  @override
  String errorFilePicker(String error) {
    return 'Could not open file picker: $error';
  }

  @override
  String errorFolderPicker(String error) {
    return 'Could not open folder picker: $error';
  }

  @override
  String errorPicker(String error) {
    return 'Could not open the picker: $error';
  }

  @override
  String get sharesTitle => 'Shares';

  @override
  String get shareSendLinkTitle => 'Send a link';

  @override
  String get shareSendLinkBody =>
      'Anyone on this Wi-Fi with the link can download the files from a browser.';

  @override
  String get shareFiles => 'Share files';

  @override
  String get shareFolder => 'Share folder';

  @override
  String get shareNothingShared =>
      'Nothing shared. A share gives you a link and QR code that opens in any browser on this network, no app needed.';

  @override
  String get browserSectionTitle => 'Use from a browser';

  @override
  String get browserSectionBody =>
      'Open this address on another phone or computer to send files here. Nothing to install.';

  @override
  String get shareLessThanMinute => 'less than a minute';

  @override
  String get shareTtl1h => '1 hour';

  @override
  String get shareTtl24h => '24 hours';

  @override
  String get shareTtlNone => 'Until I stop';

  @override
  String get shareUnlimited => 'Unlimited';

  @override
  String get shareLinkWorksFor => 'Link works for';

  @override
  String get shareDownloadsAllowed => 'Downloads allowed';

  @override
  String get shareOptionsNote =>
      'Anyone on this network who has the link can download while it works. Playing a video counts as one download.';

  @override
  String get shareShowNearby => 'Show to nearby devices';

  @override
  String get shareShowNearbyHint =>
      'Only devices you trust and browsers you approved can see it.';

  @override
  String get shareConfirm => 'Share';

  @override
  String shareOptionsTitleFiles(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString files',
      one: '1 file',
    );
    return 'Share $_temp0';
  }

  @override
  String shareOptionsTitleFolder(String name) {
    return 'Share folder \"$name\"';
  }

  @override
  String shareCreatedFiles(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString files',
      one: '1 file',
    );
    return 'Sharing $_temp0. Open the link on the other device.';
  }

  @override
  String shareCreatedFolder(String name) {
    return 'Sharing folder \"$name\". Open the link on the other device.';
  }

  @override
  String errorShare(String error) {
    return 'Could not share: $error';
  }

  @override
  String get shareUntilStopped => 'Until you stop it';

  @override
  String get shareExpired => 'Expired';

  @override
  String shareEndsIn(String time) {
    return 'Ends in $time';
  }

  @override
  String get shareUnlimitedDownloads => 'Unlimited downloads';

  @override
  String get shareLimitReached => 'Download limit reached';

  @override
  String shareDownloadsLeft(int left, int max) {
    final intl.NumberFormat leftNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String leftString = leftNumberFormat.format(left);
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return '$leftString of $maxString downloads left';
  }

  @override
  String shareTitleMore(String first, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$first and $countString more';
  }

  @override
  String get shareQrSemantics => 'QR code for the share link';

  @override
  String get shareHttpWarning => 'Plain HTTP link: not encrypted.';

  @override
  String get shareLinkCopied => 'Link copied';

  @override
  String get shareCopyLink => 'Copy link';

  @override
  String get shareStop => 'Stop sharing';

  @override
  String get browsersTitle => 'Connected browsers';

  @override
  String get browsersNone =>
      'No browser is paired. A paired browser can send you files until it signs out, you disconnect it, or an hour passes.';

  @override
  String browserSessionSubtitle(String ip, String time, String ago) {
    return '$ip · paired $time · last seen $ago';
  }

  @override
  String get agoJustNow => 'just now';

  @override
  String agoMinutes(String minutes) {
    return '$minutes min ago';
  }

  @override
  String agoHours(String hours) {
    return '$hours h ago';
  }

  @override
  String browserDisconnected(String name) {
    return '$name disconnected';
  }

  @override
  String get browserDisconnect => 'Disconnect';

  @override
  String get webQrCaption => 'For any phone camera or browser';

  @override
  String get webQrSemantics => 'QR code for the browser address';

  @override
  String get webHttpOnNote =>
      'Plain HTTP is on (Settings): no warning, but not encrypted. Secure address:';

  @override
  String get webWarningTitle => 'The browser shows a warning?';

  @override
  String get webWarningBody =>
      'The browser will first warn that the connection is not private. That is expected: LanDrop uses its own certificate instead of one bought from a certificate company. Choose \"Advanced\" then \"Proceed\" (Chrome, Edge), or \"Show details\" then \"visit this website\" (Safari). Then tap \"Pair this browser\" and approve here if both show the same code.';

  @override
  String get settingsSectionDevice => 'This device';

  @override
  String get settingsSaveFolder => 'Save received files to';

  @override
  String get settingsNotSet => 'Not set';

  @override
  String get settingsUseDefaultFolder => 'Use default folder';

  @override
  String get settingsPrivateFolder => 'Only visible inside LanDrop.';

  @override
  String get settingsUseDownloads => 'Use Downloads';

  @override
  String get settingsSectionConnect => 'Connecting';

  @override
  String get settingsConnectHelp => 'Can\'t find the other device?';

  @override
  String get settingsConnectHelpSub =>
      'Check the connection and see what to do';

  @override
  String get settingsShares => 'Shares and browsers';

  @override
  String get settingsSharesSub =>
      'Links you share and browsers that can send you files';

  @override
  String get settingsSectionApp => 'App';

  @override
  String get settingsBackground => 'Keep running in background';

  @override
  String get settingsBackgroundSub =>
      'Stays reachable with the screen off. Shows a notification.';

  @override
  String get settingsQuit => 'Quit LanDrop';

  @override
  String get settingsQuitSub => 'Stops receiving and closes the app';

  @override
  String get settingsAdvanced => 'Advanced';

  @override
  String get settingsAdvancedSub =>
      'Address, security code, connection methods';

  @override
  String get advancedSectionAddress => 'Address';

  @override
  String get advancedRestart => 'Restart LanDrop service';

  @override
  String get serviceRunning => 'Running';

  @override
  String get serviceStarting => 'Starting…';

  @override
  String get serviceStopped => 'Stopped';

  @override
  String get serviceError => 'Not running';

  @override
  String get advancedSectionBrowsers => 'Browsers';

  @override
  String get webHttpTitle => 'Allow browsers without a warning (not encrypted)';

  @override
  String get webHttpSub =>
      'Off is safer. When on, browser traffic is not encrypted: anyone on this network can see the files and pairing codes. Only for networks you trust.';

  @override
  String get webHttpUrlTitle => 'Browser address (plain HTTP)';

  @override
  String get webHttpConfirmTitle => 'Turn on plain HTTP for browsers?';

  @override
  String get webHttpConfirmBody =>
      'Browsers will open LanDrop without a certificate warning, but nothing is encrypted: anyone on this Wi-Fi can read the files, share links and pairing codes, and could pretend to be this device. Use it only on a network you trust, such as your home Wi-Fi, never on public or work networks.';

  @override
  String get webHttpConfirmOn => 'Turn on';

  @override
  String errorWebHttp(String error) {
    return 'Could not change plain HTTP: $error';
  }

  @override
  String get keepSharesTitle => 'Keep share links after restart';

  @override
  String get keepSharesSub =>
      'Share links keep working after LanDrop restarts, as long as they have not expired and the files are unchanged. The list of shared files is stored on this device. Off deletes it.';

  @override
  String get advancedSectionTroubleshoot => 'Troubleshooting';

  @override
  String get advancedReport => 'Connection report';

  @override
  String get advancedReportSub => 'Find out why devices cannot connect';

  @override
  String get advancedSectionMethods => 'All connection methods';

  @override
  String get diagActionHotspot => 'Connect with a hotspot';

  @override
  String get diagTitle => 'Connection check';

  @override
  String diagTitleTarget(String target) {
    return 'Checking $target';
  }

  @override
  String get diagRunning => 'Checking the network…';

  @override
  String diagError(String error) {
    return 'Could not run the check: $error';
  }

  @override
  String get diagReportCopied => 'Report copied';

  @override
  String get diagCopyReport => 'Copy report';

  @override
  String get diagRunAgain => 'Run again';

  @override
  String get diagDetails => 'Details';

  @override
  String get diagReportNote =>
      'This report is in English so support can read it.';

  @override
  String get platformAndroid => 'Android';

  @override
  String get platformIos => 'iPhone / iPad';

  @override
  String get platformMac => 'Mac';

  @override
  String get platformWindows => 'Windows';

  @override
  String get platformLinux => 'Linux';

  @override
  String get platformOther => 'Other devices';

  @override
  String get hotspotShareAndroid1 =>
      'Tap \"Start hotspot\" below: LanDrop makes a private hotspot (no mobile data is shared) and shows a QR code the other device can scan to join. This phone may leave its Wi-Fi while it runs.';

  @override
  String get hotspotShareAndroid2 =>
      'Or use the normal hotspot: Settings > Network & internet > Hotspot & tethering > Wi-Fi hotspot (names differ a little by brand). Turn it on and note its name and password.';

  @override
  String get hotspotShareIos1 =>
      'Open Settings > Personal Hotspot and turn on \"Allow Others to Join\". (Your mobile plan must allow hotspot use.)';

  @override
  String get hotspotShareIos2 =>
      'Keep that screen open until the other device has joined: it shows the Wi-Fi password.';

  @override
  String get hotspotShareMac1 =>
      'Easiest: do it the other way round. Let the other device share a hotspot and join it from this Mac (choose \"This device joins it\" above).';

  @override
  String get hotspotShareMac2 =>
      'To share from this Mac anyway: System Settings > General > Sharing, click (i) next to Internet Sharing, share your connection (for example Ethernet) to computers using Wi-Fi, set a network name and password, then turn Internet Sharing on.';

  @override
  String get hotspotShareWindows1 =>
      'Open Settings > Network & internet > Mobile hotspot.';

  @override
  String get hotspotShareWindows2 =>
      'Turn on \"Mobile hotspot\". The network name and password are shown on that page.';

  @override
  String hotspotShareLinux1(String command) {
    return 'Open Settings > Wi-Fi, open the menu (⋮) and choose \"Turn On Wi-Fi Hotspot…\". On other desktops use NetworkManager: create a new Wi-Fi network with mode \"Hotspot\", or run: $command';
  }

  @override
  String get hotspotShareLinux2 => 'Note the network name and password.';

  @override
  String get hotspotShareOther1 =>
      'Turn on the hotspot (\"tethering\") in this device\'s network settings and note its name and password.';

  @override
  String get hotspotJoinAndroid1 =>
      'Open Settings > Wi-Fi and pick the other device\'s hotspot, then enter its password. Or tap the QR icon next to \"Add network\" and scan the code shown on the other device.';

  @override
  String get hotspotJoinIos1 =>
      'Open Settings > Wi-Fi and pick the other device\'s hotspot, then enter its password. Or point the Camera at the QR code shown on the other device and tap \"Join network\".';

  @override
  String get hotspotJoinMac1 =>
      'Click the Wi-Fi icon in the menu bar (or Control Center), pick the other device\'s hotspot and enter its password.';

  @override
  String get hotspotJoinWindows1 =>
      'Click the network icon in the taskbar, open the Wi-Fi list, pick the other device\'s hotspot and enter its password.';

  @override
  String hotspotJoinLinux1(String command) {
    return 'Open the network menu (top right) > Wi-Fi > Select network, pick the other device\'s hotspot and enter its password. Or run: $command';
  }

  @override
  String get hotspotJoinOther1 =>
      'Open the Wi-Fi settings, pick the other device\'s hotspot and enter its password.';

  @override
  String get hotspotStepShareOther =>
      'On the other device, join this hotspot like any Wi-Fi network (see below).';

  @override
  String get hotspotStepVpn => 'Turn off any VPN. Mobile data can stay on.';

  @override
  String get hotspotStepOpenBoth =>
      'Open LanDrop on both devices, then tap \"I\'m connected, find the other device\".';

  @override
  String get hotspotWizardTitle => 'Connect without Wi-Fi';

  @override
  String get hotspotIntro =>
      'No router needed: one device shares a Wi-Fi hotspot, the other joins it, and LanDrop finds the other device on that network. This also helps when the Wi-Fi keeps devices apart (guest, office or hotel networks). Files go directly between the two devices and do not use mobile data.';

  @override
  String get hotspotRoleShare => 'This device shares the hotspot';

  @override
  String get hotspotRoleJoin => 'This device joins it';

  @override
  String wizardOnThisDevice(String platform) {
    return 'On this device ($platform)';
  }

  @override
  String get hotspotScanQr => 'Scan the hotspot QR code';

  @override
  String get hotspotOtherJoin => 'On the other device: join the hotspot';

  @override
  String get hotspotOtherShare => 'On the other device: share a hotspot';

  @override
  String get hotspotFindLabel => 'I\'m connected, find the other device';

  @override
  String get hotspotCableInstead => 'Using a cable instead? Ethernet or USB';

  @override
  String get hotspotStart => 'Start hotspot';

  @override
  String get hotspotOn => 'Hotspot is on';

  @override
  String hotspotName(String ssid) {
    return 'Name: $ssid';
  }

  @override
  String get hotspotNoPassword => 'No password';

  @override
  String hotspotPassword(String password) {
    return 'Password: $password';
  }

  @override
  String get hotspotScanHint =>
      'Scan with the other device\'s camera to join (Android 10+, iPhone). The hotspot stops when you tap Stop or close LanDrop.';

  @override
  String get hotspotStop => 'Stop hotspot';

  @override
  String get hotspotQrSemantics => 'QR code to join this hotspot';

  @override
  String get findPhaseNetwork => 'Looking at the new network…';

  @override
  String get findPhaseProbeHotspot => 'Checking the usual hotspot addresses…';

  @override
  String get findPhaseScan => 'Scanning the network…';

  @override
  String get findPhaseWhy => 'Nothing found. Checking why…';

  @override
  String get findNothingHintHotspot =>
      'Check that both devices are on the same hotspot and LanDrop is open on both. Then try again, or use \"Add by IP\" with the address shown on the other device.';

  @override
  String findFound(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString devices',
      one: '1 device',
    );
    return 'Found $_temp0';
  }

  @override
  String get findBackToDevices => 'Back to devices';

  @override
  String get findNothingTitle => 'No device found yet';

  @override
  String get cableEthMac1 =>
      'Plug the Ethernet cable into both computers (a USB or Thunderbolt Ethernet adapter is fine). Cable or router: the same steps.';

  @override
  String get cableEthMac2 =>
      'Open System Settings > Network. If the adapter is not listed, click \"…\" > \"Add Service…\" (or the + button), pick the Ethernet adapter and click Create.';

  @override
  String cableEthMac3(String prefix) {
    return 'Select it and set \"Configure IPv4\" to \"Using DHCP\". With no router the Mac gives itself an address starting with $prefix. That is normal.';
  }

  @override
  String get cableEthPlugBoth => 'Plug the Ethernet cable into both computers.';

  @override
  String cableEthWindows2(String prefix) {
    return 'Open Settings > Network & internet > Ethernet. It should say \"No Internet\" or \"Unidentified network\": that is fine, Windows gives itself an address starting with $prefix.';
  }

  @override
  String get cableEthWindows3 =>
      'Under \"IP assignment\" keep \"Automatic (DHCP)\". On the Windows Firewall prompt, allow LanDrop on Private networks. If the network is marked \"Public\", set it to Private.';

  @override
  String cableEthLinux2(String command) {
    return 'Open Settings > Network, pick the wired connection and open its settings > IPv4. Choose the \"Link-Local Only\" method and apply. Or run: $command';
  }

  @override
  String get cableEthLinux3 =>
      'Turn the connection off and on so it gets an address.';

  @override
  String get cableEthOther1 =>
      'Plug an Ethernet cable (with an adapter if needed) into both computers, and make sure the wired network uses automatic addresses (DHCP or \"link-local\").';

  @override
  String get cableUsbAndroid1 =>
      'This phone is the one sharing: connect it to the computer with a USB cable.';

  @override
  String get cableUsbAndroid2 =>
      'Open Settings > Network & internet > Hotspot & tethering (names differ a little by brand), then turn on \"USB tethering\". It only switches on while a computer is plugged in.';

  @override
  String get cableUsbIos1 =>
      'Connect the iPhone to the computer with a USB cable and tap \"Trust\" if asked.';

  @override
  String get cableUsbIos2 =>
      'Open Settings > Personal Hotspot and turn on \"Allow Others to Join\". On a Windows PC, iTunes or the Apple Devices app must be installed.';

  @override
  String get cableUsbMac1 =>
      'Connect the phone to this Mac with a USB cable. On the phone turn on Personal Hotspot (iPhone) or USB tethering (Android).';

  @override
  String get cableUsbMac2 =>
      'The Mac shows a new network adapter in System Settings > Network (for example \"iPhone USB\" or \"RNDIS/Ethernet Gadget\"). Android USB tethering needs a driver on a Mac, which is not built in; an iPhone works out of the box.';

  @override
  String get cableUsbWindows1 =>
      'Connect the phone to this PC with a USB cable. On the phone turn on USB tethering (Android) or Personal Hotspot (iPhone).';

  @override
  String get cableUsbWindows2 =>
      'Windows adds a new adapter (shown in Settings > Network & internet > Advanced network settings). Wait until it says Connected.';

  @override
  String get cableUsbLinux1 =>
      'Connect the phone to this computer with a USB cable. On the phone turn on USB tethering (Android) or Personal Hotspot (iPhone).';

  @override
  String get cableUsbLinux2 =>
      'A new wired connection appears (named like usb0, enx… or eth1). It usually connects by itself.';

  @override
  String get cableUsbOther1 =>
      'Connect the phone with a USB cable and turn on USB tethering or Personal Hotspot; the computer then has a new network adapter.';

  @override
  String get cableStepWait =>
      'Wait a few seconds: with no router it takes up to a minute for both computers to get their addresses.';

  @override
  String get cableStepVpn =>
      'Turn off any VPN. The other device now shares its connection to this one.';

  @override
  String get cableStepOpenBoth =>
      'Open LanDrop on both devices, then tap \"The cable is connected, find the other device\".';

  @override
  String get cableIntro =>
      'No Wi-Fi or router needed: connect the two devices with a cable and LanDrop finds the other device on that link. Files go directly over the cable.';

  @override
  String get cableKindEthernet => 'Ethernet cable';

  @override
  String get cableKindUsb => 'USB tethering';

  @override
  String get cableTetherHint =>
      'On the phone: Android > Settings > Network & internet > Hotspot & tethering > USB tethering. iPhone > Settings > Personal Hotspot.';

  @override
  String get cableFindLabel => 'The cable is connected, find the other device';

  @override
  String get cablePhaseProbe => 'Checking the usual cable and USB addresses…';

  @override
  String get cableNothingHint =>
      'Check the cable, that the adapter shows as connected, and that LanDrop is open on both devices. A direct cable can take up to a minute to get addresses. Then try again, or use \"Add by IP\" with the address shown on the other device.';

  @override
  String get wifiDirectTitle => 'Wi-Fi Direct';

  @override
  String get wifiDirectIntro =>
      'Connect two devices directly, without a router. Once connected, send files as usual.';

  @override
  String get wifiDirectTry =>
      'Try: Wi-Fi on, accept the invitation on the other device, keep both screens on and close together.';

  @override
  String get wifiDirectRoleOwner => 'This device hosts the group.';

  @override
  String get wifiDirectRoleClient => 'Joined the other device\'s group.';

  @override
  String get wifiDirectConnected => 'Connected via Wi-Fi Direct';

  @override
  String wifiDirectNetwork(String ssid) {
    return 'Network: $ssid';
  }

  @override
  String wifiDirectHost(String address) {
    return 'Host address: $address';
  }

  @override
  String get wifiDirectLooking => 'Looking for LanDrop devices…';

  @override
  String get wifiDirectNone =>
      'No LanDrop device answered yet. Make sure LanDrop is open on the other device, then search again.';

  @override
  String get wifiDirectSearchAgain => 'Search again';

  @override
  String get wifiDirectDisconnect => 'Disconnect';

  @override
  String get wifiDirectTapHint =>
      'Tap a device to connect. The other device gets an Android invitation dialog and must accept it.';

  @override
  String get wifiDirectLookingShort => 'Looking…';

  @override
  String get wifiDirectEmpty =>
      'No devices found yet. Open Wi-Fi Direct on the other device too.';

  @override
  String get wifiDirectInvited =>
      'Invitation sent. Accept it on the other device.';

  @override
  String get wifiDirectStatusConnected => 'connected';

  @override
  String get wifiDirectStatusFailed => 'failed';

  @override
  String get wifiDirectStatusAvailable => 'available';

  @override
  String get wifiDirectStatusUnavailable => 'unavailable';

  @override
  String get wifiDirectCreateGroup => 'Create group here';

  @override
  String get wifiDirectCreateHint =>
      '\"Create group here\" makes this device the host, so the other device can find and join it from its own Wi-Fi Direct screen. Keep both screens on.';

  @override
  String get wifiJoinNotWifiQr =>
      'That QR code is not a Wi-Fi code. Scan the code shown by the other phone\'s LanDrop hotspot.';

  @override
  String get wifiJoinManualInvalid =>
      'Enter the network name (up to 32 characters) and its password (8 to 63 characters, or none for an open network).';

  @override
  String get wifiJoinScanIntro =>
      'On the other phone, open LanDrop > Connect without Wi-Fi > \"This device shares the hotspot\" > Start hotspot. Then point this camera at the QR code it shows.';

  @override
  String get wifiJoinAllowCamera => 'Allow the camera';

  @override
  String get wifiJoinManualToggle => 'Enter name and password';

  @override
  String get wifiJoinNetworkName => 'Network name';

  @override
  String get wifiJoinPasswordLabel => 'Password (empty for an open network)';

  @override
  String get wifiJoinHidden => 'Hidden network';

  @override
  String get wifiJoinContinue => 'Continue';

  @override
  String wifiJoinConfirmTitle(String ssid) {
    return 'Join $ssid?';
  }

  @override
  String get wifiJoinExplain =>
      'LanDrop will ask Android to join this Wi-Fi network. Android will ask you to confirm. While joined, this phone may lose its internet connection. Only LanDrop uses this network; other apps keep using your normal connection where Android allows it.';

  @override
  String get wifiJoinJoin => 'Join';

  @override
  String wifiJoinJoining(String ssid) {
    return 'Joining $ssid… Confirm the Android prompt when it appears.';
  }

  @override
  String get wifiJoinScanAgain => 'Scan again';

  @override
  String wifiJoinJoined(String ssid) {
    return 'Joined $ssid';
  }

  @override
  String get wifiJoinFindTitle => 'Find the other device';

  @override
  String get wifiJoinLeave => 'Leave network';

  @override
  String get errHotspotUnsupportedPlatform =>
      'Only Android can start a hotspot from LanDrop.';

  @override
  String get errHotspotUnsupportedSdk =>
      'This Android version cannot start a hotspot from an app. Use Settings > Hotspot instead.';

  @override
  String get errHotspotPermissionNearby =>
      'LanDrop needs the \"Nearby devices\" permission to start a hotspot.';

  @override
  String get errHotspotPermissionLocation =>
      'LanDrop needs the location permission to start a hotspot (Android requires it for Wi-Fi features; LanDrop does not use your location).';

  @override
  String get errHotspotNoName =>
      'The hotspot started but Android did not report its name.';

  @override
  String get errHotspotUnavailable =>
      'Starting a hotspot is not available here.';

  @override
  String errHotspotRefused(String detail) {
    return 'Android refused: $detail. On Android 12 and older, Location must also be switched on.';
  }

  @override
  String get errHotspotPermissionMissing => 'permission missing';

  @override
  String get errHotspotIncompatible =>
      'Android cannot start it right now, usually because the normal hotspot or tethering is on. Turn that off, or use it instead.';

  @override
  String get errHotspotDisallowed =>
      'Hotspots are not allowed on this device (for example by a work profile or the carrier).';

  @override
  String get errHotspotNoChannel =>
      'No free Wi-Fi channel. Try again in a moment.';

  @override
  String get errHotspotBusy => 'A hotspot is already starting.';

  @override
  String get errHotspotCancelled => 'The hotspot was stopped.';

  @override
  String get errHotspotFailed => 'The hotspot could not start.';

  @override
  String errHotspotFailedDetail(String detail) {
    return 'The hotspot could not start: $detail.';
  }

  @override
  String errHotspotStartError(String error) {
    return 'The hotspot could not start: $error';
  }

  @override
  String get errWifiDirectUnsupported =>
      'Wi-Fi Direct is not available on this device.';

  @override
  String get errWifiDirectWifiOff =>
      'Wi-Fi is off. Turn Wi-Fi on (no router needed), then try again.';

  @override
  String get errWifiDirectPermission =>
      'LanDrop needs permission to find nearby devices. Allow it, and on Android 12 and older also switch Location on.';

  @override
  String get errWifiDirectBusy =>
      'Wi-Fi Direct is busy. Wait a moment and try again, or tap Disconnect first.';

  @override
  String get errWifiDirectNotReady =>
      'Wi-Fi Direct is not ready yet. Try again.';

  @override
  String get errWifiDirectFailed =>
      'Wi-Fi Direct failed. Turn Wi-Fi off and on, and try again.';

  @override
  String errWifiDirectFailedDetail(String detail) {
    return 'Wi-Fi Direct failed ($detail). Turn Wi-Fi off and on, and try again.';
  }

  @override
  String get errWifiJoinUnsupported =>
      'Joining a Wi-Fi network from LanDrop needs Android 7 or newer. Join it in the Wi-Fi settings instead.';

  @override
  String get errWifiJoinCamera =>
      'LanDrop needs the camera to scan the QR code. Allow it in the app settings, or type the name and password instead.';

  @override
  String get errWifiJoinTimeout =>
      'Android did not join the network. Check that the other phone\'s hotspot is on and close by, that the password is right, and that you did not decline the Android prompt. Then try again.';

  @override
  String get errWifiJoinLost =>
      'The network went away. Check that the hotspot is still on, then scan again.';

  @override
  String get errWifiJoinUnsupportedSecurity =>
      'This network uses an old security type (WEP) that Android no longer lets apps join. Join it in the Wi-Fi settings instead.';

  @override
  String get errWifiJoinPermission =>
      'Android did not allow LanDrop to change the network. Join it in the Wi-Fi settings instead.';

  @override
  String get errWifiJoinFailed =>
      'Could not join the network. Try again, or join it in the Wi-Fi settings.';

  @override
  String errWifiJoinFailedDetail(String detail) {
    return 'Could not join the network ($detail). Try again, or join it in the Wi-Fi settings.';
  }

  @override
  String errorWebHttpStart(String error) {
    return 'Plain HTTP for browsers could not start: $error';
  }

  @override
  String get pickFilesTitle => 'Choose files to send';

  @override
  String get pickFolderTitle => 'Choose a folder to send';

  @override
  String get helperTitle => 'Help me connect';

  @override
  String get helperChecking => 'Checking your connection…';

  @override
  String helperFound(String name) {
    return 'Found $name!';
  }

  @override
  String get helperCheckFine => 'Nothing looks wrong on this device.';

  @override
  String get helperQ1 => 'Are both devices on the same Wi-Fi?';

  @override
  String get helperQ1Same => 'Yes, same Wi-Fi';

  @override
  String get helperQ1Different => 'No, or there is no Wi-Fi';

  @override
  String get helperQ1Cable => 'I\'ll use a cable';

  @override
  String get helperChecklist =>
      'Open LanDrop on the other device and keep its screen on. Turn off any VPN.';

  @override
  String get helperSearchAgain => 'Search again';

  @override
  String get helperSameWifiNothing =>
      'Make sure both devices use the same Wi-Fi network (not a guest network) and LanDrop is open on both, then search again.';

  @override
  String get helperBlocked =>
      'This Wi-Fi may keep devices apart. Let\'s connect them directly.';

  @override
  String get helperConnectDirectly => 'Connect directly';

  @override
  String get helperQ2 => 'What is the other device?';

  @override
  String get helperQ2Android => 'An Android phone';

  @override
  String get helperQ2Iphone => 'An iPhone';

  @override
  String get helperQ2Computer => 'A computer';

  @override
  String get helperQ2Browser => 'Only a browser';

  @override
  String get helperRecommended => 'Recommended';

  @override
  String get helperMethodShareQrTitle => 'Share a hotspot from this phone';

  @override
  String get helperMethodShareQrBody =>
      'No internet is used. The other phone scans the code to join.';

  @override
  String get helperMethodShareTitle => 'Share a hotspot from this device';

  @override
  String get helperMethodShareBody =>
      'No internet is used. The other device joins this hotspot like any Wi-Fi network.';

  @override
  String get helperMethodJoinTitle => 'Join the other device\'s hotspot';

  @override
  String get helperMethodJoinBody =>
      'Turn on the hotspot on the other device, then join it from this one. No internet is used.';

  @override
  String get helperMethodJoinQrTitle => 'Scan the other phone\'s hotspot code';

  @override
  String get helperMethodJoinQrBody =>
      'When the other phone shares a hotspot with LanDrop, this phone scans its QR code and joins.';

  @override
  String get helperMethodWifiDirectTitle => 'Use Wi-Fi Direct';

  @override
  String get helperMethodWifiDirectBody =>
      'Phone to phone without a router. Both phones must run Android.';

  @override
  String get helperOpenWifiDirect => 'Open Wi-Fi Direct';

  @override
  String get helperMethodBrowserTitle => 'Use a browser on the other device';

  @override
  String get helperMethodBrowserBody =>
      'Nothing to install: the other device opens a link in its browser to send or download files. Both devices must be on the same Wi-Fi or hotspot.';

  @override
  String get helperOpenShares => 'Open the Share page';

  @override
  String get helperOnThisDevice => 'On this device';

  @override
  String get helperOnOtherDevice => 'On the other device';

  @override
  String get helperOtherWays => 'Other ways';

  @override
  String get helperTryAnother => 'Try another way';

  @override
  String get helperCopyReport => 'Copy connection report';

  @override
  String get wifiJoinCameraFailed =>
      'The camera could not start. Type the name and password below instead.';

  @override
  String get transferCancelled => 'Cancelled';

  @override
  String transferSentTo(String name) {
    return 'Sent to $name';
  }

  @override
  String transferReceivedFrom(String name) {
    return 'Received from $name';
  }

  @override
  String transferPercent(String percent) {
    return '$percent%';
  }

  @override
  String transferPercentSpeed(String percent, String speed) {
    return '$percent% · $speed';
  }

  @override
  String transferTimeLeft(String time) {
    return '$time left';
  }

  @override
  String get transferCancelAction => 'Cancel';

  @override
  String get transferCancelling => 'Cancelling…';

  @override
  String get transferOpen => 'Open';

  @override
  String get transferShowInFolder => 'Show in folder';

  @override
  String get transferCopyPath => 'Copy path';

  @override
  String get transferPathCopied => 'Path copied';

  @override
  String transferOpenFailed(String path) {
    return 'Couldn\'t open it. The files are in $path.';
  }

  @override
  String get transferAutoAccepted => 'Accepted automatically';

  @override
  String get transferFileFailed => 'Failed';

  @override
  String get incomingFirstTime => 'First time from this device';

  @override
  String get incomingTrusted => 'Trusted device';

  @override
  String get incomingUnverified => 'Identity not confirmed';

  @override
  String get incomingAlwaysAccept => 'Always accept from this device';

  @override
  String incomingAliasWarning(String name) {
    return 'This device uses the name of \"$name\" but is not the same device.';
  }

  @override
  String get incomingChangeFolder => 'Change';

  @override
  String incomingExpired(String name) {
    return 'The request from $name expired.';
  }

  @override
  String incomingWithdrawn(String name) {
    return '$name cancelled the request.';
  }

  @override
  String get permContinue => 'Continue';

  @override
  String get permNotNow => 'Not now';

  @override
  String get permLater =>
      'Android asks next. You can change this later in the system settings.';

  @override
  String get permNotificationsTitle => 'Show that LanDrop is running?';

  @override
  String get permNotificationsBody =>
      'LanDrop keeps receiving files in the background. Android shows this as a notification and asks you to allow notifications for LanDrop on the next screen.';

  @override
  String get permNearbyTitle => 'Allow \"Nearby devices\"?';

  @override
  String get permNearbyBody =>
      'To start a hotspot or a Wi-Fi Direct connection, Android needs the \"Nearby devices\" permission (\"Location\" on older phones). LanDrop does not use your location.';

  @override
  String get permCameraTitle => 'Use the camera to scan the code?';

  @override
  String get permCameraBody =>
      'LanDrop uses the camera only to read the Wi-Fi QR code of the other phone. No photos are taken or saved.';

  @override
  String get permNotificationsOff =>
      'Notifications are off. LanDrop still receives in the background, but you won\'t see that it is running.';

  @override
  String get permNearbyOff =>
      'This stays off until you allow \"Nearby devices\".';

  @override
  String get permCameraOff =>
      'The camera stays off. You can type the network name and password instead.';

  @override
  String get permTryAgain => 'Try again';

  @override
  String get settingsAllowNotifications => 'Allow notifications';

  @override
  String get transferDetails => 'Details';

  @override
  String get transferDetailsTitle => 'What happened';

  @override
  String get transferDetailsReason => 'Reason';

  @override
  String get transferDetailsCode => 'Error code';

  @override
  String get transferDetailsUnknown => 'Unknown';

  @override
  String get transferDetailsReportNote =>
      'The copied report is in English, so anyone can help.';

  @override
  String get incomingKnown => 'Seen before, not trusted yet';

  @override
  String get incomingDetails => 'Details';

  @override
  String autoAcceptedSnack(String name) {
    return 'Accepted from $name automatically';
  }

  @override
  String get autoAcceptStop => 'Stop auto-accept';

  @override
  String get settingsTrustedDevices => 'Trusted devices';

  @override
  String settingsTrustedDevicesSub(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString devices',
      one: '1 device',
      zero: 'None yet',
    );
    return '$_temp0';
  }

  @override
  String get trustedEmpty => 'Devices you accept files from appear here.';

  @override
  String get trustedIntro =>
      'A device counts as the same only with the same security code, never by its name alone.';

  @override
  String get trustedAutoAccept => 'Accept automatically';

  @override
  String get trustedAutoAcceptSub =>
      'Saved without asking. You\'ll see a notice each time.';

  @override
  String get trustedRename => 'Rename';

  @override
  String get trustedRenameLabel => 'Name shown on this device';

  @override
  String get trustedRemove => 'Remove';

  @override
  String trustedRemoved(String name) {
    return '$name removed';
  }

  @override
  String trustedDeviceName(String alias) {
    return 'Device name: $alias';
  }

  @override
  String get trustedLarge => 'Also accept large transfers automatically';

  @override
  String trustedLargeSub(String size) {
    return 'Off: transfers over $size always ask.';
  }

  @override
  String get onboardingSemantics => 'Welcome to LanDrop';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStart => 'Start';

  @override
  String onboardingStep(int step, int total) {
    final intl.NumberFormat stepNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String stepString = stepNumberFormat.format(step);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Step $stepString of $totalString';
  }

  @override
  String get onboarding1Title => 'Send files to your nearby devices';

  @override
  String get onboarding1Body =>
      'No internet, no account. Files go straight from one device to the other.';

  @override
  String get onboarding2Title => 'Open LanDrop on both devices';

  @override
  String get onboarding2Body =>
      'Connect them to the same Wi-Fi. No Wi-Fi? LanDrop can help you connect directly.';

  @override
  String get onboarding3Title => 'Name this device';

  @override
  String get onboarding3Body => 'Others will see this name.';

  @override
  String get onboardingPermissions => 'What LanDrop may ask for';

  @override
  String get onboardingLocalNetworkComputer =>
      'Your Mac will ask whether LanDrop may find devices on your local network. Choose Allow, or nearby devices won\'t appear.';

  @override
  String get onboardingLocalNetworkPhone =>
      'Your iPhone or iPad will ask whether LanDrop may find devices on your local network. Choose Allow, or nearby devices won\'t appear.';

  @override
  String get onboardingFirewallWindows =>
      'Windows may ask whether LanDrop may use the network. Allow it on private networks.';

  @override
  String get onboardingStorageAndroid =>
      'Files: to save what you receive in Downloads, where other apps find it. LanDrop explains this first, the first time you receive files.';

  @override
  String get onboardingNothingToAllow =>
      'Nothing to allow now. LanDrop asks only when something is needed.';

  @override
  String get storageTitle => 'Save received files in Downloads?';

  @override
  String get storageBody =>
      'To put files in your Downloads folder, where your other apps can find them, Android needs you to allow \"All files access\" for LanDrop on the next screen. Without it, files are kept inside LanDrop\'s own folder.';

  @override
  String get storageLater => 'You can change this later in Settings.';

  @override
  String get storageAllow => 'Allow';

  @override
  String get storageNotNow => 'Not now';

  @override
  String storageGranted(String folder) {
    return 'Received files now go to $folder.';
  }

  @override
  String get storageKeptPrivate =>
      'Files stay in LanDrop\'s own folder. You can try again in Settings.';

  @override
  String get sendSheetText => 'Text';

  @override
  String get sendTextTitle => 'Send text';

  @override
  String get sendTextLabel => 'Text or link';

  @override
  String get sendTextPaste => 'Paste';

  @override
  String get sendTextNext => 'Choose device';

  @override
  String sendTextTooLong(String max) {
    return 'Too long: at most $max.';
  }

  @override
  String get sendPickerTitleText => 'Send text to…';

  @override
  String textFromTitle(String name) {
    return 'Text from $name';
  }

  @override
  String get textCopy => 'Copy';

  @override
  String get textCopied => 'Text copied';

  @override
  String get textOpenLink => 'Open link';

  @override
  String get textLinkFailed => 'Couldn\'t open the link.';

  @override
  String get textSaveFile => 'Save as file';

  @override
  String get textSaveFailed => 'Couldn\'t save the file.';

  @override
  String get textAutoNotice => 'Received automatically from a trusted device.';

  @override
  String get textMessage => 'Text message';

  @override
  String get historyTitle => 'History';

  @override
  String get historySettingsSub => 'Past transfers on this device';

  @override
  String get historyPrivacy =>
      'History stays on this device. You can turn it off in Settings.';

  @override
  String get historyEmpty => 'No transfers yet.';

  @override
  String get historyOff => 'History is off.';

  @override
  String get historyClear => 'Clear history';

  @override
  String get historyClearBody =>
      'Remove every entry? Received files are not deleted.';

  @override
  String get historyClearConfirm => 'Clear';

  @override
  String get historyCleared => 'History cleared';

  @override
  String get historyToday => 'Today';

  @override
  String get historyYesterday => 'Yesterday';

  @override
  String historyFilesMore(String name, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString more',
      one: '1 more',
    );
    return '$name and $_temp0';
  }

  @override
  String get historyWhen => 'When';

  @override
  String get historyResult => 'Result';

  @override
  String get historySize => 'Size';

  @override
  String get historyFiles => 'Files';

  @override
  String get historySavedIn => 'Saved in';

  @override
  String historyMoreFiles(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString more files',
      one: '1 more file',
    );
    return 'and $_temp0';
  }

  @override
  String get historyGone => 'These files are no longer there.';

  @override
  String historyDateTime(String date, String time) {
    return '$date, $time';
  }

  @override
  String get historyDetailsSemantics => 'Transfer details';

  @override
  String get settingsSectionPrivacy => 'History and privacy';

  @override
  String get settingsKeepHistory => 'Keep history';

  @override
  String get settingsKeepHistorySub =>
      'Stays on this device. Turning it off deletes it.';

  @override
  String get transferRetryMissing => 'Some files are no longer there.';

  @override
  String get peerTrusted => 'Trusted';

  @override
  String get homeRecent => 'Recent';

  @override
  String get recentNotNearby => 'Not nearby';

  @override
  String recentLastSeen(String when) {
    return 'Last seen $when';
  }

  @override
  String recentSemantics(String name) {
    return '$name, not nearby';
  }

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get themeSystem => 'Same as system';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String shareSendingFiles(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString files',
      one: '1 file',
    );
    return 'Sending $_temp0';
  }

  @override
  String get shareSendingText => 'Sending text';

  @override
  String get shareErrTooMany => 'Too many items to share at once. Try fewer.';

  @override
  String get shareErrTooBig =>
      'These items are too big to share this way. Use Send inside LanDrop instead.';

  @override
  String get shareErrUnreadable =>
      'Some items couldn\'t be read, so they were skipped.';

  @override
  String get shareErrFailed => 'Couldn\'t receive the shared items.';

  @override
  String get nearbySharesTitle => 'Nearby shares';

  @override
  String get nearbyLoading => 'Looking for shared files…';

  @override
  String get nearbyEmpty => 'Nothing shared with you';

  @override
  String get nearbyEmptyHint =>
      'If you expected files, the owner may need to allow this device.';

  @override
  String get nearbySelectAll => 'Select all';

  @override
  String nearbyDownloadSelected(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Download selected ($countString)';
  }

  @override
  String get nearbyRefresh => 'Refresh';

  @override
  String get nearbyTruncated => 'Some files are not listed';

  @override
  String nearbyAccessTitle(String alias) {
    return '$alias wants to see your nearby shares';
  }

  @override
  String get nearbyAccessDeny => 'Deny';

  @override
  String get nearbyAccessOnce => 'Allow for 1 hour';

  @override
  String get nearbyAccessAlways => 'Always allow (trust)';
}
