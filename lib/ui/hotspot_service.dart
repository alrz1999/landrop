import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'l10n.dart';

/// Runtime permission Android needs before `startLocalOnlyHotspot`.
enum HotspotPermission { nearbyWifiDevices, location }

/// Android 13 (API 33) and newer: "Nearby devices" (NEARBY_WIFI_DEVICES,
/// declared neverForLocation). Older: fine location (declared up to API 32).
HotspotPermission hotspotPermissionFor(int sdkInt) => sdkInt >= 33
    ? HotspotPermission.nearbyWifiDevices
    : HotspotPermission.location;

/// The hotspot this device shares (Android local-only hotspot).
class HotspotCredentials {
  final String ssid;
  final String password;

  /// This device's address on the hotspot, when Android reported it.
  final String? gateway;
  const HotspotCredentials(this.ssid, this.password, {this.gateway});
}

class HotspotException implements Exception {
  /// unsupported, permission, busy, no-channel, incompatible-mode,
  /// tethering-disallowed, cancelled, failed.
  final String code;

  /// English text (logs, tests); the UI shows [localized].
  final String message;

  /// Which text of [hotspotMessage] [message] is (default [code]).
  final String? messageCode;

  /// Technical detail inserted into the text, if any (English).
  final String? detail;
  const HotspotException(this.code, this.message,
      {this.messageCode, this.detail});

  /// [message] in the language of [l].
  String localized(AppLocalizations l) =>
      hotspotMessage(messageCode ?? code, detail, l);

  @override
  String toString() => message;
}

/// Readable text per hotspot message code (native error codes plus
/// `unsupported-platform`, `unsupported-sdk`, `unsupported-here`,
/// `permission-nearby`, `permission-location`, `no-name`, `start-error`);
/// English when [l] is null.
String hotspotMessage(String code, [String? detail, AppLocalizations? l]) {
  l ??= englishStrings;
  return switch (code) {
    'unsupported-platform' => l.errHotspotUnsupportedPlatform,
    'unsupported-sdk' => l.errHotspotUnsupportedSdk,
    'unsupported-here' => l.errHotspotUnavailable,
    'permission-nearby' => l.errHotspotPermissionNearby,
    'permission-location' => l.errHotspotPermissionLocation,
    'no-name' => l.errHotspotNoName,
    'start-error' => l.errHotspotStartError(detail ?? ''),
    'permission' =>
      l.errHotspotRefused(detail ?? l.errHotspotPermissionMissing),
    'incompatible-mode' => l.errHotspotIncompatible,
    'tethering-disallowed' => l.errHotspotDisallowed,
    'no-channel' => l.errHotspotNoChannel,
    'busy' => l.errHotspotBusy,
    'cancelled' => l.errHotspotCancelled,
    _ => detail == null
        ? l.errHotspotFailed
        : l.errHotspotFailedDetail(detail),
  };
}

HotspotException _hotspotError(String code, String messageCode,
        [String? detail]) =>
    HotspotException(code, hotspotMessage(messageCode, detail),
        messageCode: messageCode, detail: detail);

/// Asks for [p]; true when granted.
typedef HotspotPermissionRequest = Future<bool> Function(HotspotPermission p);

/// Asks for [p] with permission_handler; true when granted. Shared by the
/// hotspot and Wi-Fi Direct services.
Future<bool> requestWifiPermission(HotspotPermission p) async {
  final perm = p == HotspotPermission.nearbyWifiDevices
      ? Permission.nearbyWifiDevices
      : Permission.location;
  try {
    if (await perm.isGranted) return true;
    return (await perm.request()).isGranted;
  } catch (_) {
    return false;
  }
}

/// Escapes `\ ; , : "` with a backslash, as the `WIFI:` QR format requires.
String escapeWifiQr(String s) =>
    s.replaceAllMapped(RegExp(r'[\\;,:"]'), (m) => '\\${m[0]}');

/// Payload of a Wi-Fi QR code that phone cameras (Android 10+, iOS 11+)
/// offer to join: `WIFI:T:WPA;S:<ssid>;P:<password>;;`.
String wifiQrPayload(String ssid, String password) => password.isEmpty
    ? 'WIFI:T:nopass;S:${escapeWifiQr(ssid)};;'
    : 'WIFI:T:WPA;S:${escapeWifiQr(ssid)};P:${escapeWifiQr(password)};;';

/// Starts and stops the Android local-only hotspot through the
/// `dev.landrop/hotspot` channel (MainActivity / HotspotManager.kt).
class HotspotService {
  HotspotService({
    MethodChannel? channel,
    HotspotPermissionRequest? requestPermission,
    bool? android,
  })  : _channel = channel ?? const MethodChannel(channelName),
        _request = requestPermission ?? _defaultRequest,
        supported = android ?? Platform.isAndroid;

  static const channelName = 'dev.landrop/hotspot';
  final MethodChannel _channel;
  final HotspotPermissionRequest _request;

  /// Only Android can create a hotspot from the app.
  final bool supported;

  static Future<bool> _defaultRequest(HotspotPermission p) =>
      requestWifiPermission(p);

  /// Asks for the right permission, then starts the hotspot. Throws
  /// [HotspotException].
  Future<HotspotCredentials> start() async {
    if (!supported) {
      throw _hotspotError('unsupported', 'unsupported-platform');
    }
    try {
      final sdk = await _channel.invokeMethod<int>('sdkInt') ?? 0;
      if (sdk < 26) {
        throw _hotspotError('unsupported', 'unsupported-sdk');
      }
      final perm = hotspotPermissionFor(sdk);
      if (!await _request(perm)) {
        throw _hotspotError(
            'permission',
            perm == HotspotPermission.nearbyWifiDevices
                ? 'permission-nearby'
                : 'permission-location');
      }
      final m = await _channel.invokeMapMethod<String, dynamic>('start');
      final ssid = m?['ssid'];
      final pass = m?['password'];
      final gw = m?['gateway'];
      if (ssid is! String || ssid.isEmpty) {
        throw _hotspotError('failed', 'no-name');
      }
      return HotspotCredentials(ssid, pass is String ? pass : '',
          gateway: gw is String && gw.isNotEmpty ? gw : null);
    } on PlatformException catch (e) {
      throw _hotspotError(e.code, e.code, e.message);
    } on MissingPluginException {
      throw _hotspotError('unsupported', 'unsupported-here');
    }
  }

  Future<void> stop() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<bool>('stop');
    } catch (_) {}
  }
}
