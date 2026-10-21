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
}
