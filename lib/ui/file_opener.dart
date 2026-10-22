import 'dart:io';

import '../core/util.dart' show hasSpoofingChars;

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

  /// Opens [url] in the default browser. Only an http(s) link passing
  /// [isWebLink] is ever opened; false otherwise or when it failed. Same
  /// platforms as [canOpen].
  Future<bool> openLink(String url);
}

/// Whether [text] is exactly one http(s) link (surrounding spaces
/// allowed): no other words, no spaces or control characters inside, a
/// host present. Only such text gets an "Open link" button.
bool isWebLink(String text) {
  final s = text.trim();
  if (s.isEmpty || s.length > 2048) return false;
  if (RegExp(r'[\s\u0000-\u001F\u007F]').hasMatch(s)) return false;
  // Bidi overrides and other invisible characters would show a different
  // link than the one opened (SECURITY.md S7).
  if (hasSpoofingChars(s)) return false;
  final uri = Uri.tryParse(s);
  if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return false;
  final scheme = uri.scheme.toLowerCase();
  return scheme == 'http' || scheme == 'https';
}

/// Extensions whose default action runs code (programs, scripts,
/// installers, shortcuts, launchers) on macOS, Windows or Linux.
const _runnableExtensions = {
  // macOS
  'app', 'command', 'dmg', 'tool', 'terminal', 'workflow', 'action', 'pkg', 'mpkg',
  'scpt', 'scptd', 'applescript', 'prefpane', 'kext', 'webloc', 'inetloc',
  'fileloc',
  // Windows
  'exe', 'com', 'bat', 'cmd', 'msi', 'msp', 'msix', 'appx', 'ps1', 'psm1',
  'vbs', 'vbe', 'js', 'jse', 'wsf', 'wsh', 'hta', 'scr', 'pif', 'cpl', 'lnk',
  'url', 'reg', 'inf', 'appref-ms', 'application', 'gadget', 'msc', 'library-ms',
  'settingcontent-ms',
  // Linux and cross-platform
  'desktop', 'sh', 'bash', 'zsh', 'csh', 'ksh', 'run', 'bin', 'appimage',
  'jar', 'py', 'pyw', 'pl', 'rb', 'deb', 'rpm', 'flatpakref',
};

/// Whether opening [path] with its default application would run code
/// (an executable, script, installer, shortcut or app bundle such as a
/// received folder `Evil.app`). "Open" shows such files in their folder
/// instead (SECURITY.md S8).
bool isRunnablePath(String path) {
  final trimmed = path.replaceAll(RegExp(r'[\\/]+$'), '');
  final name = trimmed.split(RegExp(r'[\\/]')).last.toLowerCase();
  final dot = name.lastIndexOf('.');
  if (dot < 0) return false;
  return _runnableExtensions.contains(name.substring(dot + 1));
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

  /// Opens [path], except a runnable one ([isRunnablePath]), which is only
  /// shown in its folder: a received file must never run by a click on
  /// "Open".
  @override
  Future<bool> open(String path) => isRunnablePath(path) || _hasExecBit(path)
      ? reveal(path)
      : _exec(openCommand(path), path);

  /// A file with an execute permission bit (never set on received files)
  /// could be run by `open` / `xdg-open` even without a known extension.
  static bool _hasExecBit(String path) {
    if (Platform.isWindows) return false;
    try {
      final st = FileStat.statSync(path);
      return st.type == FileSystemEntityType.file && (st.mode & 0x49) != 0;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> reveal(String path) => _exec(revealCommand(path), path);

  /// The command [openLink] runs for [url], or null when unsupported or
  /// not a web link. Passed as one argument, never through a shell.
  (String, List<String>)? linkCommand(String url) {
    if (!isWebLink(url)) return null;
    final u = url.trim();
    return switch (os) {
      'macos' => ('open', [u]),
      'windows' => ('explorer', [u]),
      'linux' => ('xdg-open', [u]),
      _ => null,
    };
  }

  @override
  Future<bool> openLink(String url) async {
    final cmd = linkCommand(url);
    if (cmd == null) return false;
    try {
      final r = await _run(cmd.$1, cmd.$2);
      return os == 'windows' || r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
