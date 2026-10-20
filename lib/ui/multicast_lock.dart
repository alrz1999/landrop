import 'dart:io';

import 'package:flutter/services.dart';

/// Android drops incoming multicast packets unless a WifiManager.MulticastLock
/// is held. No-op on other platforms.
class MulticastLock {
  static const _channel = MethodChannel('dev.landrop/multicast');

  static Future<void> acquire() => _call('acquire');
  static Future<void> release() => _call('release');

  static Future<void> _call(String method) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>(method);
    } catch (_) {
      // Discovery still works through subnet scan / manual IP.
    }
  }
}
