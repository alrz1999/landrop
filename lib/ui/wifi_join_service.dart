import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'wifi_qr.dart';

/// A network this phone joined from a QR code.
class WifiJoinResult {
  final String ssid;

  /// Gateway (usually the other phone) when Android reported it.
  final String? gateway;
  final List<String> addresses;
  const WifiJoinResult(this.ssid, {this.gateway, this.addresses = const []});
}

class WifiJoinException implements Exception {
  /// unsupported, camera, timeout, lost, unsupported-security, permission,
  /// failed.
  final String code;
  final String message;
  const WifiJoinException(this.code, this.message);
  @override
  String toString() => message;
}

/// Readable text and what to try, per error code.
String wifiJoinMessage(String code, [String? detail]) => switch (code) {
      'unsupported' => 'Joining a Wi-Fi network from LanDrop needs Android 7 '
          'or newer. Join it in the Wi-Fi settings instead.',
      'camera' => 'LanDrop needs the camera to scan the QR code. Allow it in '
          'the app settings, or type the name and password instead.',
      'timeout' => 'Android did not join the network. Check that the other '
          'phone\'s hotspot is on and close by, that the password is right, '
          'and that you did not decline the Android prompt. Then try again.',
      'lost' => 'The network went away. Check that the hotspot is still on, '
          'then scan again.',
      'unsupported-security' => 'This network uses an old security type (WEP) '
          'that Android no longer lets apps join. Join it in the Wi-Fi '
          'settings instead.',
      'permission' => 'Android did not allow LanDrop to change the network. '
          'Join it in the Wi-Fi settings instead.',
      _ => 'Could not join the network${detail == null ? '' : ' ($detail)'}. '
          'Try again, or join it in the Wi-Fi settings.',
    };

/// What the page needs; the page tests use a fake.
abstract class WifiJoinApi {
  bool get supported;

  /// Fires when a joined network goes away.
  Stream<WifiJoinException> get lost;

  /// Asks for the camera; true when granted.
  Future<bool> requestCamera();

  /// Joins [c]; completes when connected. Throws [WifiJoinException].
  Future<WifiJoinResult> join(WifiCredentials c);

  /// Leaves the network and unbinds the app from it.
  Future<void> leave();
  void dispose();
}

Future<bool> _defaultCamera() async {
  try {
    if (await Permission.camera.isGranted) return true;
    return (await Permission.camera.request()).isGranted;
  } catch (_) {
    return false;
  }
}

/// Joins a Wi-Fi network through the `dev.landrop/wifijoin` channel and its
/// event channel (WifiJoinManager.kt).
class WifiJoinService implements WifiJoinApi {
  WifiJoinService({
    MethodChannel? channel,
    Stream<dynamic>? events,
    Future<bool> Function()? requestCameraPermission,
    bool? android,
    this.timeout = const Duration(seconds: 75),
  })  : _channel = channel ?? const MethodChannel(channelName),
        _camera = requestCameraPermission ?? _defaultCamera,
        supported = android ?? Platform.isAndroid {
    if (supported) {
      final s = events ?? const EventChannel(eventsName).receiveBroadcastStream();
      _sub = s.listen(handleEvent, onError: (Object e) {
        _fail(WifiJoinException('failed', wifiJoinMessage('failed', '$e')));
      });
    }
  }

  static const channelName = 'dev.landrop/wifijoin';
  static const eventsName = 'dev.landrop/wifijoin/events';
  final MethodChannel _channel;
  final Future<bool> Function() _camera;
  final Duration timeout;
  StreamSubscription<dynamic>? _sub;
  Completer<WifiJoinResult>? _pending;
  final _lost = StreamController<WifiJoinException>.broadcast();

  @override
  final bool supported;

  @override
  Stream<WifiJoinException> get lost => _lost.stream;

  void _fail(WifiJoinException e) {
    final p = _pending;
    _pending = null;
    if (p != null && !p.isCompleted) p.completeError(e);
  }

  /// Parses one native event (`connected`, `failed`, `lost`); ignores others.
  void handleEvent(dynamic e) {
    if (e is! Map) return;
    switch (e['type']) {
      case 'connected':
        final p = _pending;
        _pending = null;
        final gw = e['gateway'];
        final addrs = e['addresses'];
        p?.complete(WifiJoinResult(
          e['ssid'] is String ? e['ssid'] as String : '',
          gateway: gw is String && gw.isNotEmpty ? gw : null,
          addresses: [if (addrs is List) ...addrs.whereType<String>()],
        ));
      case 'failed':
        final code = e['code'] is String ? e['code'] as String : 'failed';
        _fail(WifiJoinException(
            code,
            wifiJoinMessage(
                code, e['message'] is String ? e['message'] as String : null)));
      case 'lost':
        if (_pending != null) {
          _fail(WifiJoinException('lost', wifiJoinMessage('lost')));
        } else {
          _lost.add(WifiJoinException('lost', wifiJoinMessage('lost')));
        }
    }
  }

  @override
  Future<bool> requestCamera() async => supported && await _camera();

  static String _securityName(WifiSecurity s) => switch (s) {
        WifiSecurity.open => 'open',
        WifiSecurity.wep => 'wep',
        WifiSecurity.wpa => 'wpa',
        WifiSecurity.wpa3 => 'wpa3',
      };

  @override
  Future<WifiJoinResult> join(WifiCredentials c) async {
    if (!supported) {
      throw WifiJoinException('unsupported', wifiJoinMessage('unsupported'));
    }
    try {
      final sdk = await _channel.invokeMethod<int>('sdkInt') ?? 0;
      if (sdk < 24) {
        throw WifiJoinException('unsupported', wifiJoinMessage('unsupported'));
      }
      final pending = Completer<WifiJoinResult>();
      _pending = pending;
      await _channel.invokeMethod<bool>('join', {
        'ssid': c.ssid,
        'password': c.password,
        'security': _securityName(c.security),
        'hidden': c.hidden,
      });
      return await pending.future.timeout(timeout, onTimeout: () {
        _pending = null;
        throw WifiJoinException('timeout', wifiJoinMessage('timeout'));
      });
    } on PlatformException catch (e) {
      _pending = null;
      throw WifiJoinException(e.code, wifiJoinMessage(e.code, e.message));
    } on MissingPluginException {
      _pending = null;
      throw WifiJoinException('unsupported', wifiJoinMessage('unsupported'));
    }
  }

  @override
  Future<void> leave() async {
    _pending = null;
    if (!supported) return;
    try {
      await _channel.invokeMethod<bool>('leave');
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    _lost.close();
  }
}
