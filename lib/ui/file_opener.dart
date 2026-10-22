import 'dart:io';

/// Runs a program without a shell (test seam for [SystemFileOpener]).
typedef ProcessRunner = Future<ProcessResult> Function(
    String executable, List<String> arguments);

/// Opens received files or shows them in the file manager (UX.md 3.8).
abstract class FileOpener {
  /// Whether "Open" / "Show in folder" work on this platform. When false
  /// the transfer card shows the saved path with a Copy button instead.
  bool get canOpen;

  /// Opens [path] (a file or a folder) like a double click would. Returns
  /// false when it could not be started.
  Future<bool> open(String path);

  /// Shows [path] selected in the file manager (its folder on Linux).
  Future<bool> reveal(String path);
}

/// Desktop implementation with no extra package: `open` / `open -R` on
/// macOS, `explorer` / `explorer /select,` on Windows, `xdg-open` on Linux.
/// Android and iOS are not supported without a new dependency (a
/// `FileProvider` / document interaction plugin), so [canOpen] is false
/// there (UX.md 6, U6 gaps).
class SystemFileOpener implements FileOpener {
  SystemFileOpener({String? os, ProcessRunner? run})
      : os = os ?? Platform.operatingSystem,
        _run = run ?? Process.run;

  /// `Platform.operatingSystem` value ('macos', 'windows', 'linux', ...).
  final String os;
  final ProcessRunner _run;

  @override
  bool get canOpen => const {'macos', 'windows', 'linux'}.contains(os);

  /// The command [open] runs for [path], or null when unsupported. Paths are
  /// passed as one argument each, never through a shell.
  (String, List<String>)? openCommand(String path) => switch (os) {
        'macos' => ('open', [path]),
        'windows' => ('explorer', [path]),
        'linux' => ('xdg-open', [path]),
        _ => null,
      };

  /// The command [reveal] runs for [path], or null when unsupported.
  (String, List<String>)? revealCommand(String path) => switch (os) {
        'macos' => ('open', ['-R', path]),
        'windows' => ('explorer', ['/select,', path]),
        'linux' => ('xdg-open', [_parent(path)]),
        _ => null,
      };

  static String _parent(String path) {
    final i = path.lastIndexOf(RegExp(r'[\\/]'));
    return i <= 0 ? path : path.substring(0, i);
  }

  /// Only absolute paths: a relative one starting with '-' could be read as
  /// an option by `open` or `xdg-open`.
  static bool _safe(String path) =>
      path.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path);

  Future<bool> _exec((String, List<String>)? cmd, String path) async {
    if (cmd == null || !_safe(path)) return false;
    try {
      final r = await _run(cmd.$1, cmd.$2);
      // explorer.exe exits with 1 even when it worked.
      return os == 'windows' || r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> open(String path) => _exec(openCommand(path), path);

  @override
  Future<bool> reveal(String path) => _exec(revealCommand(path), path);
}
