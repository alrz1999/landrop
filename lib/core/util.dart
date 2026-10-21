// Small pure helpers used by the core.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

final Random _rng = Random.secure();

String randomHex([int bytes = 16]) {
  final sb = StringBuffer();
  for (var i = 0; i < bytes; i++) {
    sb.write(_rng.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

/// [bytes] random bytes (default 128 bit) as URL-safe base64 without padding.
String randomToken([int bytes = 16]) => base64Url
    .encode(List<int>.generate(bytes, (_) => _rng.nextInt(256)))
    .replaceAll('=', '');

/// Uniformly random decimal code with [digits] digits (leading zeros kept).
String randomDigits(int digits) =>
    List.generate(digits, (_) => _rng.nextInt(10)).join();

/// An HTTP error answered as `{ "message": ..., ...extra }` with [status].
class HttpStatusError implements Exception {
  final int status;
  final String message;
  final Map<String, dynamic>? extra; // merged into the JSON error body
  HttpStatusError(this.status, this.message, [this.extra]);
  @override
  String toString() => 'HTTP $status: $message';
}

/// Reduce an untrusted, sender-supplied file name to a safe single path
/// component: no directories, no traversal, no control/reserved characters.
String sanitizeFileName(String raw) {
  var name = raw.replaceAll('\\', '/');
  final slash = name.lastIndexOf('/');
  if (slash >= 0) name = name.substring(slash + 1);
  name = name.replaceAll(RegExp(r'[\x00-\x1f\x7f<>:"|?*]'), '_');
  // Strip leading dots/spaces (no hidden files, no "..") and trailing
  // dots/spaces (Windows silently drops them).
  name = name.replaceAll(RegExp(r'^[.\s]+'), '');
  name = name.replaceAll(RegExp(r'[.\s]+$'), '');
  if (name.length > 200) {
    final dot = name.lastIndexOf('.');
    final ext = (dot > 0 && name.length - dot <= 16) ? name.substring(dot) : '';
    name = name.substring(0, 200 - ext.length) + ext;
  }
  if (name.isEmpty) name = 'file';
  return name;
}

/// Split an untrusted, sender-supplied relative path (folder transfers use
/// `Photos/2024/a.jpg`) into safe path segments. Backslashes count as
/// separators; empty, `.` and `..` segments and a leading Windows drive
/// (`C:`) are dropped; every remaining segment goes through
/// [sanitizeFileName]. Never returns an empty list.
List<String> sanitizeRelativePath(String raw) {
  final parts = raw.replaceAll('\\', '/').split('/');
  final out = <String>[];
  for (var i = 0; i < parts.length; i++) {
    final p = parts[i].trim();
    if (p.isEmpty || p == '.' || p == '..') continue;
    if (out.isEmpty && RegExp(r'^[A-Za-z]:$').hasMatch(p)) continue;
    out.add(sanitizeFileName(p));
  }
  if (out.length > 64) out.removeRange(63, out.length - 1); // keep the name
  return out.isEmpty ? ['file'] : out;
}

/// True when the existing directory [path], with symlinks resolved, is the
/// existing directory [root] or inside it.
Future<bool> isWithinDir(String root, String path) async {
  try {
    final r = await Directory(root).resolveSymbolicLinks();
    final t = await Directory(path).resolveSymbolicLinks();
    final sep = Platform.pathSeparator;
    return t == r || t.startsWith(r.endsWith(sep) ? r : '$r$sep');
  } catch (_) {
    return false;
  }
}

/// A directory name in [dir] based on [name] that does not exist yet and is
/// not in [taken]: `Photos`, `Photos (1)`, ...
String uniqueDirName(String dir, String name, {Set<String> taken = const {}}) {
  final sep = Platform.pathSeparator;
  for (var i = 0; i < 10000; i++) {
    final candidate = i == 0 ? name : '$name ($i)';
    if (taken.contains(candidate)) continue;
    if (FileSystemEntity.typeSync('$dir$sep$candidate', followLinks: false) ==
        FileSystemEntityType.notFound) {
      return candidate;
    }
  }
  throw StateError('could not allocate a unique folder name');
}

/// Atomically reserve a non-existing file in [dir] named after [fileName],
/// appending " (n)" before the extension on collision.
Future<File> reserveUniqueFile(String dir, String fileName) async {
  final dot = fileName.lastIndexOf('.');
  final base = dot > 0 ? fileName.substring(0, dot) : fileName;
  final ext = dot > 0 ? fileName.substring(dot) : '';
  final sep = Platform.pathSeparator;
  final canonicalDir = Directory(dir).absolute.path;
  for (var i = 0; i < 10000; i++) {
    final candidate = i == 0 ? fileName : '$base ($i)$ext';
    final file = File('$canonicalDir$sep$candidate');
    // Defence in depth: the result must live directly inside dir.
    if (file.parent.absolute.path != canonicalDir) {
      throw StateError('unsafe path');
    }
    try {
      await file.create(exclusive: true);
      return file;
    } on FileSystemException {
      continue; // exists, try next
    }
  }
  throw StateError('could not allocate a unique file name');
}

const _mime = <String, String>{
  'txt': 'text/plain',
  'html': 'text/html',
  'htm': 'text/html',
  'css': 'text/css',
  'csv': 'text/csv',
  'json': 'application/json',
  'xml': 'application/xml',
  'pdf': 'application/pdf',
  'zip': 'application/zip',
  'gz': 'application/gzip',
  'tar': 'application/x-tar',
  '7z': 'application/x-7z-compressed',
  'apk': 'application/vnd.android.package-archive',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'pptx':
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'md': 'text/markdown',
  'log': 'text/plain',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'avif': 'image/avif',
  'bmp': 'image/bmp',
  'heic': 'image/heic',
  'svg': 'image/svg+xml',
  'mp3': 'audio/mpeg',
  'wav': 'audio/wav',
  'ogg': 'audio/ogg',
  'oga': 'audio/ogg',
  'opus': 'audio/ogg',
  'flac': 'audio/flac',
  'aac': 'audio/aac',
  'm4a': 'audio/mp4',
  'mp4': 'video/mp4',
  'm4v': 'video/mp4',
  'mov': 'video/quicktime',
  'mkv': 'video/x-matroska',
  'webm': 'video/webm',
  'ogv': 'video/ogg',
};

String guessMime(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0) return 'application/octet-stream';
  return _mime[fileName.substring(dot + 1).toLowerCase()] ??
      'application/octet-stream';
}

/// Types a browser may display inline from a share without any risk of
/// running script in the page's origin: audio, video, raster images, PDF and
/// plain text. HTML, SVG, XML and everything else are always attachments.
bool isInlineSafeMime(String mime) =>
    mime.startsWith('video/') ||
    mime.startsWith('audio/') ||
    const {
      'image/png',
      'image/jpeg',
      'image/gif',
      'image/webp',
      'image/avif',
      'image/bmp',
      'application/pdf',
      'text/plain',
      'text/csv',
      'text/markdown',
    }.contains(mime);

bool _isPrivate(InternetAddress a) {
  final b = a.rawAddress;
  if (b.length != 4) return false;
  return b[0] == 10 ||
      (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
      (b[0] == 192 && b[1] == 168);
}

/// VPN/tunnel interfaces: scanning or announcing on them wastes time and makes
/// peers show up under the wrong address.
bool isVpnInterface(String name) {
  final n = name.toLowerCase();
  return ['utun', 'tun', 'tap', 'ppp', 'ipsec', 'wg', 'vpn', 'tailscale']
      .any(n.startsWith);
}

/// Non-loopback, non-link-local IPv4 addresses of this host, private first.
Future<List<InternetAddress>> localIPv4Addresses() async {
  final out = <InternetAddress>[];
  try {
    final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4, includeLoopback: false);
    for (final i in ifaces) {
      if (isVpnInterface(i.name)) continue;
      for (final a in i.addresses) {
        final r = a.rawAddress;
        if (r.length == 4 && !(r[0] == 169 && r[1] == 254) && !a.isLoopback) {
          out.add(a);
        }
      }
    }
  } catch (_) {}
  out.sort((x, y) => (_isPrivate(x) ? 0 : 1) - (_isPrivate(y) ? 0 : 1));
  return out;
}
