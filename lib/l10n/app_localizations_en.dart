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
}
