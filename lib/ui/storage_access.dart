import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Public Downloads folder on Android. Writing there with dart:io needs
/// "All files access" (API 30+) or storage permission (API <= 29).
const androidPublicDir = '/storage/emulated/0/Download/LanDrop';

/// Ask for the permission that lets the app write outside its private folder.
/// Always true off Android. Opens the system screen, so call it only after
/// LanDrop explained why (UX.md 3.6, `showStorageExplanation`).
Future<bool> ensureStorageAccess() async {
  if (!Platform.isAndroid) return true;
  try {
    if (await Permission.manageExternalStorage.isGranted) return true;
    if ((await Permission.manageExternalStorage.request()).isGranted) {
      return true;
    }
    // Android 10 and older: plain storage permission.
    return (await Permission.storage.request()).isGranted;
  } catch (_) {
    return false;
  }
}

/// Whether the permission is already granted, without asking. Always true
/// off Android.
Future<bool> hasStorageAccess() async {
  if (!Platform.isAndroid) return true;
  try {
    return await Permission.manageExternalStorage.isGranted ||
        await Permission.storage.isGranted;
  } catch (_) {
    return false;
  }
}

/// Android "All files access" (test seam for [AppController]).
class StorageAccess {
  const StorageAccess();

  /// Only Android needs the permission (and the explanation before it).
  bool get isAndroid => Platform.isAndroid;

  /// Downloads/LanDrop, used once the permission is granted.
  String get publicDir => androidPublicDir;

  /// Granted already (checked without asking).
  Future<bool> granted() => hasStorageAccess();

  /// Opens the system screen. Returns whether it is granted afterwards.
  Future<bool> request() => ensureStorageAccess();
}
