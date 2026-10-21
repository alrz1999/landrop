// Small pure helpers used by the core.
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
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'heic': 'image/heic',
  'svg': 'image/svg+xml',
  'mp3': 'audio/mpeg',
  'wav': 'audio/wav',
  'ogg': 'audio/ogg',
  'm4a': 'audio/mp4',
  'mp4': 'video/mp4',
  'mov': 'video/quicktime',
  'mkv': 'video/x-matroska',
  'webm': 'video/webm',
};

String guessMime(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0) return 'application/octet-stream';
  return _mime[fileName.substring(dot + 1).toLowerCase()] ??
      'application/octet-stream';
}

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
