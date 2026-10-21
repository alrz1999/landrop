import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Public Downloads folder on Android. Writing there with dart:io needs
/// "All files access" (API 30+) or storage permission (API <= 29).
const androidPublicDir = '/storage/emulated/0/Download/LanDrop';

/// Ask for the permission that lets the app write outside its private folder.
/// Always true off Android.
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
