import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Android foreground service: keeps the server reachable when the app is in
/// the background or the screen is off. No-op on other platforms.
class BackgroundService {
  static const _channel = MethodChannel('dev.landrop/service');

  /// [askNotification]: ask for the Android 13+ notification permission
  /// first. The app passes false until it has explained why (UX.md 3.6,
  /// `PermissionExplainer`); the service runs either way.
  static Future<void> start({bool askNotification = true}) async {
    if (!Platform.isAndroid) return;
    try {
      // Android 13+: the notification is hidden without this, but the
      // service still runs.
      if (askNotification) await Permission.notification.request();
      await _channel.invokeMethod<bool>('start');
    } catch (_) {}
  }

  /// Updates the service notification text ("2 active shares", "1 browser
  /// connected"). The service only re-posts it while running.
  static Future<void> update({required int shares, required int browsers}) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>(
          'update', {'shares': shares, 'browsers': browsers});
    } catch (_) {}
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('stop');
    } catch (_) {}
  }
}
