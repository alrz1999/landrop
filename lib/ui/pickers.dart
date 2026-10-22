import 'package:file_picker/file_picker.dart';

import 'l10n.dart' show englishStrings;

/// Picks files to send or share. Overridable for tests.
typedef FilesPicker = Future<List<String>> Function();

/// Picks a folder to send or share. Overridable for tests.
typedef FolderPicker = Future<String?> Function();

/// The system file picker; [dialogTitle] is its window title (callers with
/// a BuildContext pass a translated one, see [pickFilesTitled]).
Future<List<String>> defaultPickFiles([String? dialogTitle]) async {
  final files = await FilePicker.pickFiles(
      dialogTitle: dialogTitle ?? englishStrings.pickFilesTitle);
  return [
    for (final f in files)
      if (f.path != null) f.path!,
  ];
}

/// The system folder picker; see [defaultPickFiles].
Future<String?> defaultPickFolder([String? dialogTitle]) =>
    FilePicker.getDirectoryPath(
        dialogTitle: dialogTitle ?? englishStrings.pickFolderTitle);

/// Runs [pick]; the system picker gets [title] as its window title.
Future<List<String>> pickFilesTitled(FilesPicker pick, String title) =>
    identical(pick, defaultPickFiles) ? defaultPickFiles(title) : pick();

/// Runs [pick]; the system picker gets [title] as its window title.
Future<String?> pickFolderTitled(FolderPicker pick, String title) =>
    identical(pick, defaultPickFolder) ? defaultPickFolder(title) : pick();
