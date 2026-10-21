import 'package:file_picker/file_picker.dart';

/// Picks files to send or share. Overridable for tests.
typedef FilesPicker = Future<List<String>> Function();

/// Picks a folder to send or share. Overridable for tests.
typedef FolderPicker = Future<String?> Function();

// The system picker's own title stays English (no BuildContext here); the
// picker window itself is localized by the operating system.
Future<List<String>> defaultPickFiles() async {
  final files = await FilePicker.pickFiles(dialogTitle: 'Choose files to send');
  return [
    for (final f in files)
      if (f.path != null) f.path!,
  ];
}

Future<String?> defaultPickFolder() =>
    FilePicker.getDirectoryPath(dialogTitle: 'Choose a folder to send');
