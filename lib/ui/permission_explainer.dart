// Just-in-time permission explanations (docs/UX.md 3.6): a short sheet
// shown before Android's own permission dialog, with "Continue" and
// "Not now". Each one is shown once (remembered in the settings JSON as
// `permissionsExplained`); after that the action goes straight to the
// system dialog, so a "Try again" never shows the sheet twice.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'l10n.dart';
import 'widgets.dart' show AppScope;

/// The runtime permissions LanDrop explains first.
enum AppPermission {
  /// Android 13+: the notification of the background service.
  notifications,

  /// "Nearby devices" (Android 13+) or location (older): hotspot and
  /// Wi-Fi Direct.
  nearbyDevices,

  /// The camera, to scan a Wi-Fi QR code.
  camera,
}

/// Checks and asks for [AppPermission]s (test seam, like `StorageAccess`).
/// Only [request] for [AppPermission.notifications] is used: the nearby
/// devices and camera permissions are still asked by their services.
class PermissionAccess {
  const PermissionAccess();

  /// Only Android shows the explanations.
  bool get isAndroid => Platform.isAndroid;

  /// Granted already (checked without asking). True off Android.
  Future<bool> granted(AppPermission p) async {
    if (!Platform.isAndroid) return true;
    try {
      return switch (p) {
        AppPermission.notifications => await Permission.notification.isGranted,
        AppPermission.nearbyDevices =>
          await Permission.nearbyWifiDevices.isGranted ||
              await Permission.location.isGranted,
        AppPermission.camera => await Permission.camera.isGranted,
      };
    } catch (_) {
      return false;
    }
  }

  /// Opens the system dialog; whether it is granted afterwards.
  Future<bool> request(AppPermission p) async {
    if (!Platform.isAndroid) return true;
    try {
      final perm = switch (p) {
        AppPermission.notifications => Permission.notification,
        AppPermission.nearbyDevices => Permission.nearbyWifiDevices,
        AppPermission.camera => Permission.camera,
      };
      return (await perm.request()).isGranted;
    } catch (_) {
      return false;
    }
  }
}

/// The explanation sheet for [p]. True for "Continue" (then the caller
/// lets Android ask), false for "Not now" or when dismissed.
Future<bool> showPermissionExplainer(
    BuildContext context, AppPermission p) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final l = ctx.l;
      final t = Theme.of(ctx).textTheme;
      final (icon, title, body) = switch (p) {
        AppPermission.notifications => (
            Icons.notifications_outlined,
            l.permNotificationsTitle,
            l.permNotificationsBody
          ),
        AppPermission.nearbyDevices => (
            Icons.wifi_tethering,
            l.permNearbyTitle,
            l.permNearbyBody
          ),
        AppPermission.camera => (
            Icons.qr_code_scanner,
            l.permCameraTitle,
            l.permCameraBody
          ),
      };
      return Semantics(
        label: title,
        container: true,
        child: SafeArea(
          child: SingleChildScrollView(
            key: Key('permissionSheet-${p.name}'),
            padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 32, color: Theme.of(ctx).colorScheme.primary),
                const SizedBox(height: 12),
                Text(title, style: t.titleLarge),
                const SizedBox(height: 8),
                Text(body, style: t.bodyMedium),
                const SizedBox(height: 8),
                Text(l.permLater, style: t.bodySmall),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      key: const Key('permissionNotNow'),
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(l.permNotNow),
                    ),
                    FilledButton(
                      key: const Key('permissionContinue'),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(l.permContinue),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return ok ?? false;
}

/// Before an action that makes Android ask for [p]: explains it once.
/// True when the action may go on (explained before, already granted, not
/// Android, or "Continue"); false after "Not now".
Future<bool> explainBeforeAsking(BuildContext context, AppPermission p) async {
  final c = AppScope.maybeOf(context);
  if (c == null || !c.permissions.isAndroid) return true;
  if (c.permissionExplained(p)) return true;
  if (await c.permissions.granted(p)) return true;
  if (!context.mounted) return false;
  final ok = await showPermissionExplainer(context, p);
  await c.markPermissionExplained(p);
  return ok;
}

/// What a feature says after "Not now": it stays off, with a way to try
/// again (which now goes straight to Android's dialog).
class PermissionNotNowNote extends StatelessWidget {
  const PermissionNotNowNote(
      {super.key, required this.permission, required this.onRetry});
  final AppPermission permission;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Card(
      key: Key('permissionNotNow-${permission.name}'),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(switch (permission) {
              AppPermission.notifications => l.permNotificationsOff,
              AppPermission.nearbyDevices => l.permNearbyOff,
              AppPermission.camera => l.permCameraOff,
            }),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                key: Key('permissionRetry-${permission.name}'),
                onPressed: onRetry,
                child: Text(l.permTryAgain),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
