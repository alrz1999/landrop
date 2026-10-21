import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Android foreground service: keeps the server reachable when the app is in
/// the background or the screen is off. No-op on other platforms.
class BackgroundService {
  static const _channel = MethodChannel('dev.landrop/service');

  static Future<void> start() async {
    if (!Platform.isAndroid) return;
    try {
      // Android 13+: the notification is hidden without this, but the
      // service still runs.
      await Permission.notification.request();
      await _channel.invokeMethod<bool>('start');
    } catch (_) {}
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('stop');
    } catch (_) {}
  }
}
