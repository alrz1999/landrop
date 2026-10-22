// Security review batch B (docs/SECURITY.md S6-S14, S16, S17).
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/core/landrop_core.dart';
import 'package:landrop/core/util.dart';
import 'package:landrop/core/web_assets.dart';
import 'package:landrop/core/web_server.dart';
import 'package:landrop/ui/file_opener.dart';

void main() {
  group('S6 names and aliases', () {
    test('bidi and invisible characters are removed from file names', () {
      expect(sanitizeFileName('invoice\u202Efdp.exe'), 'invoicefdp.exe');
      for (final c in [
        '\u202A', '\u202B', '\u202C', '\u202D', '\u202E', '\u2066', '\u2067',
        '\u2068', '\u2069', '\u200B', '\u061C', '\uFEFF', '\u2028', '\u2029',
      ]) {
        expect(sanitizeFileName('a${c}b.txt'), 'ab.txt', reason: c.codeUnits.toString());
      }
    });

    test('Windows reserved names, trailing dots/spaces, streams', () {
      for (final n in ['CON', 'nul.txt', 'Com1', 'LPT9.tar.gz', 'aux.', 'PRN ']) {
        final r = sanitizeFileName(n);
        expect(r.startsWith('_'), isTrue, reason: n);
      }
      expect(sanitizeFileName('console.txt'), 'console.txt');
      expect(sanitizeFileName('a.txt. . '), 'a.txt');
      expect(sanitizeFileName('a.txt:evil'), 'a.txt_evil');
      expect(sanitizeFileName('x::\$DATA'), 'x__\$DATA');
    });

    test('names are capped in UTF-8 bytes and keep the extension', () {
      final r = sanitizeFileName('${'ش' * 300}.pdf');
      expect(utf8.encode(r).length, lessThanOrEqualTo(255));
      expect(r.endsWith('.pdf'), isTrue);
      final e = sanitizeFileName('${'😀' * 300}.txt');
      expect(utf8.encode(e).length, lessThanOrEqualTo(255));
      expect(e.endsWith('.txt'), isTrue);
      expect(e.contains('�'), isFalse);
    });

    test('aliases lose control and bidi characters', () {
      expect(sanitizeDisplayText('Al\u202Eice\u0007\n x'), 'Alice x');
      expect(sanitizeDisplayText('a' * 200).length, 64);
      expect(sanitizeDisplayText('\u202E\u2066'), '');
    });
  });

  group('S7 isWebLink', () {
    test('rejects format characters, other schemes, no host', () {
      expect(isWebLink('https://example.com/a'), isTrue);
      expect(isWebLink('https://example.com/\u202Efdp'), isFalse);
      expect(isWebLink('https://exa\u200Bmple.com'), isFalse);
      expect(isWebLink('https://example.com/\u2066'), isFalse);
      expect(isWebLink('https://example.com/\uFEFFx'), isFalse);
      expect(isWebLink('data:text/html,hi'), isFalse);
      expect(isWebLink('https:///path'), isFalse);
    });

    test('the opened URL is the displayed (trimmed) text', () {
      final calls = <String>[];
      final o = SystemFileOpener(
          os: 'linux',
          run: (e, a) async {
            calls.add([e, ...a].join('|'));
            return ProcessResult(0, 0, '', '');
          });
      final cmd = o.linkCommand('  https://example.com/x  ')!;
      expect(cmd.$1, 'xdg-open');
      expect(cmd.$2, ['https://example.com/x']);
      expect(o.linkCommand('https://example.com/\u202Ex'), isNull);
      expect(o.linkCommand('file:///etc/passwd'), isNull);
    });
  });

  group('S8 FileOpener', () {
    test('runnable paths are only revealed, never opened', () async {
      final calls = <String>[];
      Future<ProcessResult> run(String e, List<String> a) async {
        calls.add([e, ...a].join('|'));
        return ProcessResult(0, 0, '', '');
      }

      final o = SystemFileOpener(os: 'macos', run: run);
      for (final n in [
        'a.exe', 'a.BAT', 'a.cmd', 'a.com', 'a.scr', 'a.msi', 'a.ps1', 'a.vbs',
        'a.js', 'a.jar', 'a.sh', 'a.command', 'Evil.app', 'Evil.app/', 'a.dmg',
        'a.pkg', 'a.desktop', 'a.AppImage', 'a.lnk', 'a.hta',
      ]) {
        calls.clear();
        await o.open('/Users/me/Downloads/$n');
        expect(calls.single, startsWith('open|-R|'), reason: n);
      }
      calls.clear();
      await o.open('/Users/me/Downloads/photo.jpg');
      expect(calls.single, 'open|/Users/me/Downloads/photo.jpg');
      expect(isRunnablePath('/x/Evil.app'), isTrue);
      expect(isRunnablePath('/x/a.txt'), isFalse);
    });

    test('relative or dash paths are refused; only http(s) links', () async {
      final calls = <String>[];
      final o = SystemFileOpener(
          os: 'linux',
          run: (e, a) async {
            calls.add('$e ${a.join(' ')}');
            return ProcessResult(0, 0, '', '');
          });
      expect(await o.open('-rf'), isFalse);
      expect(await o.reveal('--help'), isFalse);
      expect(await o.openLink('ftp://example.com'), isFalse);
      expect(await o.openLink('-x'), isFalse);
      expect(calls, isEmpty);
    });

    test('a file with an execute bit is revealed, not opened', () async {
      if (Platform.isWindows) return;
      final d = await Directory.systemTemp.createTemp('landrop_exec');
      addTearDown(() => d.delete(recursive: true));
      final f = File('${d.path}/tool')..writeAsStringSync('#!/bin/sh');
      await Process.run('chmod', ['755', f.path]);
      final calls = <String>[];
      final o = SystemFileOpener(
          os: 'macos',
          run: (e, a) async {
            calls.add([e, ...a].join('|'));
            return ProcessResult(0, 0, '', '');
          });
      await o.open(f.path);
      expect(calls.single, startsWith('open|-R|'));
    });
  });

  group('S11 key.pem mode', () {
    test('key file is 600 and not in a world-accessible way', () async {
      if (!(Platform.isMacOS || Platform.isLinux)) return;
      final d = await Directory.systemTemp.createTemp('landrop_id');
      addTearDown(() => d.delete(recursive: true));
      await TlsIdentity.generate().save('${d.path}/id');
      final st = File('${d.path}/id/key.pem').statSync();
      expect(st.mode & 0x1FF, 384); // 0600
      expect(File('${d.path}/id/key.pem').readAsStringSync(),
          contains('PRIVATE KEY'));
    });
  });

  group('S12/S13 symlinks', () {
    test('a share file swapped for a symlink is not served', () async {
      if (Platform.isWindows) return;
      final tmp = await Directory.systemTemp.createTemp('landrop_sym');
      final save = await Directory('${tmp.path}/save').create();
      final c = LanDropCoreImpl(LanDropCoreOptions(
          port: 0,
          bindAddress: InternetAddress.loopbackIPv4,
          advertiseIp: '127.0.0.1',
          multicastEnabled: false,
          persistIdentity: false));
      addTearDown(() async {
        await c.dispose();
        await tmp.delete(recursive: true);
      });
      await c.start(alias: 'a', saveDir: save.path);
      final f = File('${tmp.path}/doc.txt')..writeAsStringSync('12345');
      final secret = File('${tmp.path}/secret.txt')..writeAsStringSync('abcde');
      final s = c.createShare([f.path]);
      Future<int> get() async {
        final cl = HttpClient()..badCertificateCallback = (_, _, _) => true;
        try {
          final r = await (await cl.getUrl(Uri.parse(
                  'https://127.0.0.1:${c.self.port}/api/landrop/v1/shares/'
                  '${s.token}/files/${s.files.single.id}')))
              .close();
          await r.drain<void>();
          return r.statusCode;
        } finally {
          cl.close(force: true);
        }
      }

      expect(await get(), 200);
      f.deleteSync();
      Link(f.path).createSync(secret.path);
      expect(await get(), 404);
    });

    test('reserveUniqueFile never writes through an existing symlink', () async {
      if (Platform.isWindows) return;
      final d = await Directory.systemTemp.createTemp('landrop_part');
      addTearDown(() => d.delete(recursive: true));
      final victim = File('${d.path}/victim')..writeAsStringSync('keep');
      Link('${d.path}/.a.part').createSync(victim.path);
      final f = await reserveUniqueFile(d.path, '.a.part');
      expect(f.path.endsWith('.a.part'), isFalse);
      await f.writeAsString('x');
      expect(victim.readAsStringSync(), 'keep');
    });
  });

  group('S14 CSP', () {
    test('inline script and style are allowed only by their hash', () {
      String h(String tag) {
        final m = RegExp('<$tag>(.*?)</$tag>', dotAll: true)
            .firstMatch(webPageHtml)!;
        return "'sha256-${base64Encode(sha256.convert(utf8.encode(m.group(1)!)).bytes)}'";
      }

      expect(webCsp, contains('script-src \'self\' ${h('script')};'));
      expect(webCsp, contains('style-src \'self\' ${h('style')};'));
      expect(webCsp, isNot(contains('unsafe-inline')));
      // One inline block each, no inline handlers or style attributes (the
      // hash policy would block them).
      expect('<script>'.allMatches(webPageHtml).length, 1);
      expect('<style>'.allMatches(webPageHtml).length, 1);
      expect(RegExp(r'<[^>]+\s(on[a-z]+|style)\s*=', caseSensitive: false)
          .hasMatch(webPageHtml), isFalse);
    });
  });

  group('S17 token keys', () {
    test('lookup key is the SHA-256 of the token, distinct per token', () {
      expect(webTokenKey('abc'),
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
      expect(webTokenKey('abc'), isNot(webTokenKey('abd')));
      expect(webTokenKey('abc'), isNot(contains('abc')));
    });
  });
}
