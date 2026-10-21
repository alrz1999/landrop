import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

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
  final String message;
  const HotspotException(this.code, this.message);
  @override
  String toString() => message;
}

/// Asks for [p]; true when granted.
typedef HotspotPermissionRequest = Future<bool> Function(HotspotPermission p);

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

  static Future<bool> _defaultRequest(HotspotPermission p) async {
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

  /// Asks for the right permission, then starts the hotspot. Throws
  /// [HotspotException].
  Future<HotspotCredentials> start() async {
    if (!supported) {
      throw const HotspotException(
          'unsupported', 'Only Android can start a hotspot from LanDrop.');
    }
    try {
      final sdk = await _channel.invokeMethod<int>('sdkInt') ?? 0;
      if (sdk < 26) {
        throw const HotspotException('unsupported',
            'This Android version cannot start a hotspot from an app. Use '
                'Settings > Hotspot instead.');
      }
      final perm = hotspotPermissionFor(sdk);
      if (!await _request(perm)) {
        throw HotspotException(
            'permission',
            perm == HotspotPermission.nearbyWifiDevices
                ? 'LanDrop needs the "Nearby devices" permission to start a '
                    'hotspot.'
                : 'LanDrop needs the location permission to start a hotspot '
                    '(Android requires it for Wi-Fi features; LanDrop does '
                    'not use your location).');
      }
      final m = await _channel.invokeMapMethod<String, dynamic>('start');
      final ssid = m?['ssid'];
      final pass = m?['password'];
      final gw = m?['gateway'];
      if (ssid is! String || ssid.isEmpty) {
        throw const HotspotException(
            'failed', 'The hotspot started but Android did not report its name.');
      }
      return HotspotCredentials(ssid, pass is String ? pass : '',
          gateway: gw is String && gw.isNotEmpty ? gw : null);
    } on PlatformException catch (e) {
      throw HotspotException(e.code, _message(e.code, e.message));
    } on MissingPluginException {
      throw const HotspotException(
          'unsupported', 'Starting a hotspot is not available here.');
    }
  }

  Future<void> stop() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<bool>('stop');
    } catch (_) {}
  }

  static String _message(String code, String? detail) => switch (code) {
        'permission' => 'Android refused: ${detail ?? 'permission missing'}. '
            'On Android 12 and older, Location must also be switched on.',
        'incompatible-mode' => 'Android cannot start it right now, usually '
            'because the normal hotspot or tethering is on. Turn that off, '
            'or use it instead.',
        'tethering-disallowed' =>
          'Hotspots are not allowed on this device (for example by a work '
              'profile or the carrier).',
        'no-channel' => 'No free Wi-Fi channel. Try again in a moment.',
        'busy' => 'A hotspot is already starting.',
        'cancelled' => 'The hotspot was stopped.',
        _ => 'The hotspot could not start${detail == null ? '' : ': $detail'}.',
      };
}
