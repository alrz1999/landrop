// Nearby shares UI (docs/NEARBY_PLAN.md section 4, step 4): the Details
// sheet section, the chip on the device row, the owner dialog, Persian.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/core/api.dart';
import 'package:landrop/l10n/app_localizations.dart';
import 'package:landrop/ui/app_controller.dart';
import 'package:landrop/ui/fake_core.dart';
import 'package:landrop/ui/format.dart';
import 'package:landrop/ui/l10n.dart' show BidiL10n;
import 'package:landrop/ui/widgets.dart' show AppScope;

import 'helpers/pump_localized.dart';

final en = lookupAppLocalizations(const Locale('en'));
final fa = lookupAppLocalizations(const Locale('fa'));

const _caps = PeerCapabilities();
const _fp = 'aa11';
const _peer = DeviceInfo(
  alias: 'Pixel 9',
  deviceType: 'mobile',
  deviceModel: 'Google',
  fingerprint: _fp,
  ip: '192.168.1.21',
  capabilities: _caps,
);
const _persianPeer = DeviceInfo(
  alias: 'لپ‌تاپ سارا',
  deviceType: 'desktop',
  deviceModel: 'Windows',
  fingerprint: 'fa77',
  ip: '192.168.1.42',
  capabilities: _caps,
);
const _plainPeer = DeviceInfo(
  alias: 'Work Laptop',
  deviceType: 'desktop',
  deviceModel: 'Linux',
  fingerprint: 'bb22',
  ip: '192.168.1.34',
);

Map<String, dynamic> _trustedStore(String locale, List<String> fps) => {
  'locale': locale,
  'trustedDevices': [
    for (final f in fps)
      {
        'fingerprint': f,
        'alias': 'x',
        'trustedAt': '2026-10-01T10:00:00.000Z',
        'autoAccept': false,
      },
  ],
};

NearbyListing _listing(
  String fp, {
  DateTime? expires,
  bool truncated = false,
  List<NearbyShare>? shares,
}) => NearbyListing(
  peerFingerprint: fp,
  ticket: 'secret-ticket',
  ticketExpires: expires ?? DateTime.now().add(const Duration(minutes: 9)),
  shares:
      shares ??
      [
        NearbyShare(
          id: 's1',
          createdAt: DateTime(2026, 10, 1),
          truncated: truncated,
          files: const [
            NearbyFile('f1', 'report.pdf', 'application/pdf', 2048),
            NearbyFile('f2', 'photo.jpg', 'image/jpeg', 3 * 1024 * 1024),
            NearbyFile('f3', 'notes.txt', 'text/plain', 10),
          ],
        ),
      ],
);

Future<FakeCore> _pump(
  WidgetTester t, {
  String locale = 'en',
  double width = 400,
  List<DeviceInfo> peers = const [_peer],
  List<String> trusted = const [_fp],
  FakeCore? core,
}) async {
  core ??= FakeCore(simulateDelay: Duration.zero, initialPeers: peers);
  await pumpApp(
    t,
    localizedApp(
      core: core,
      store: MemorySettingsStore(_trustedStore(locale, trusted)),
    ),
    width: width,
    height: 900,
  );
  return core;
}

Future<void> _openDetails(WidgetTester t, String fp) async {
  await t.tap(find.byKey(Key('details-$fp')));
  await t.pumpAndSettle();
}

AppController _controller(WidgetTester t) =>
    AppScope.read(t.element(find.byType(Scaffold).first));

NearbyAccessRequest _req(String id, {String alias = 'Laptop', DateTime? at}) =>
    NearbyAccessRequest(
      id: id,
      fingerprint: 'abcdef0123456789' * 4,
      alias: alias,
      remoteIp: '10.0.0.2',
      at: at ?? DateTime.now(),
    );

void main() {
  group('Details sheet: Nearby shares', () {
    testWidgets('trusted LanDrop device: section lists shares and files', (
      t,
    ) async {
      final core = FakeCore(
        simulateDelay: Duration.zero,
        initialPeers: const [_peer],
      )..nearbyListings[_fp] = _listing(_fp);
      await _pump(t, core: core);
      // Not polled in the background: nothing asked yet.
      expect(core.listNearbyCalls, isEmpty);
      await _openDetails(t, _fp);
      expect(core.listNearbyCalls, [_fp]);
      expect(find.byKey(const Key('nearbySection')), findsOneWidget);
      expect(find.text(en.nearbySharesTitle), findsWidgets);
      expect(find.byKey(const Key('nearbyFile-s1-f1')), findsOneWidget);
      expect(find.byKey(const Key('nearbyFile-s1-f2')), findsOneWidget);
      expect(find.text('report.pdf'), findsOneWidget);
      expect(find.text(formatBytes(3 * 1024 * 1024, en)), findsWidgets);
      expect(find.byKey(const Key('nearbySelectAll')), findsOneWidget);
      expect(find.byKey(const Key('nearbyTruncated')), findsNothing);
      expect(find.text(en.nearbyDownloadSelected(0)), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('a spinner shows while the device is asked', (t) async {
      final core = FakeCore(
        simulateDelay: Duration.zero,
        initialPeers: const [_peer],
      )..nearbyListings[_fp] = _listing(_fp);
      await _pump(t, core: core);
      await t.tap(find.byKey(const Key('details-$_fp')));
      await t.pump(); // sheet opens, first frame: still loading
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('nearbySpinner')), findsNothing);
      expect(find.byKey(const Key('nearbyFile-s1-f1')), findsOneWidget);
    });

    testWidgets('no section for a device that is not a LanDrop app', (t) async {
      final core = await _pump(
        t,
        peers: const [_plainPeer],
        trusted: const ['bb22'],
      );
      await _openDetails(t, 'bb22');
      expect(find.byKey(const Key('peerDetailsSheet')), findsOneWidget);
      expect(find.byKey(const Key('nearbySection')), findsNothing);
      expect(find.byKey(const Key('nearbyChip-bb22')), findsNothing);
      expect(core.listNearbyCalls, isEmpty);
    });

    testWidgets('the chip on a trusted device row opens it; not for others', (
      t,
    ) async {
      final core = FakeCore(
        simulateDelay: Duration.zero,
        initialPeers: const [_peer, _persianPeer],
      )..nearbyListings[_fp] = _listing(_fp);
      await _pump(t, core: core, peers: const [_peer, _persianPeer]);
      expect(find.byKey(const Key('nearbyChip-$_fp')), findsOneWidget);
      expect(find.byKey(const Key('nearbyChip-fa77')), findsNothing);
      expect(t.takeException(), isNull);
      await t.tap(find.byKey(const Key('nearbyChip-$_fp')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('nearbyFile-s1-f1')), findsOneWidget);
      // First in the sheet, above the address.
      expect(
        t.getTopLeft(find.byKey(const Key('nearbySection'))).dy,
        lessThan(t.getTopLeft(find.byKey(const Key('peerAddress'))).dy),
      );
    });

    testWidgets('chip row fits at 375 px', (t) async {
      final core = FakeCore(
        simulateDelay: Duration.zero,
        initialPeers: const [_peer],
      );
      await _pump(t, core: core, width: 375);
      expect(find.byKey(const Key('nearbyChip-$_fp')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('Download sends exactly the chosen (share, file) pairs', (
      t,
    ) async {
      final core = FakeCore(
        simulateDelay: Duration.zero,
        initialPeers: const [_peer],
      )..nearbyListings[_fp] = _listing(_fp);
      await _pump(t, core: core);
      await _openDetails(t, _fp);
      await t.tap(find.byKey(const Key('nearbyFile-s1-f1')));
      await t.tap(find.byKey(const Key('nearbyFile-s1-f3')));
      await t.pumpAndSettle();
      expect(find.text(en.nearbyDownloadSelected(2)), findsOneWidget);
      await t.tap(find.byKey(const Key('nearbyDownload')));
      await t.pumpAndSettle();
      expect(core.downloadNearbyCalls, hasLength(1));
      final (peer, _, items) = core.downloadNearbyCalls.single;
      expect(peer.fingerprint, _fp);
      expect(items, [('s1', 'f1'), ('s1', 'f3')]);
      // The sheet closed; the transfer card is on Home.
      expect(find.byKey(const Key('peerDetailsSheet')), findsNothing);
      expect(_controller(t).sessions, isNotEmpty);
    });

    testWidgets('Select all, then untick one', (t) async {
      final core = FakeCore(
        simulateDelay: Duration.zero,
        initialPeers: const [_peer],
      )..nearbyListings[_fp] = _listing(_fp);
      await _pump(t, core: core);
      await _openDetails(t, _fp);
      await t.tap(find.byKey(const Key('nearbySelectAll')));
      await t.pumpAndSettle();
      expect(find.text(en.nearbyDownloadSelected(3)), findsOneWidget);
      await t.tap(find.byKey(const Key('nearbyFile-s1-f2')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('nearbyDownload')));
      await t.pumpAndSettle();
      expect(core.downloadNearbyCalls.single.$3, [('s1', 'f1'), ('s1', 'f3')]);
    });

    testWidgets('a second share is expandable; truncated notice shows', (
      t,
    ) async {
      final core =
          FakeCore(simulateDelay: Duration.zero, initialPeers: const [_peer])
            ..nearbyListings[_fp] = _listing(
              _fp,
              truncated: true,
              shares: [
                NearbyShare(
                  id: 's1',
                  createdAt: DateTime(2026),
                  truncated: true,
                  files: const [
                    NearbyFile('a', 'one.txt', 'text/plain', 1),
                    NearbyFile('b', 'two.txt', 'text/plain', 2),
                  ],
                ),
                NearbyShare(
                  id: 's2',
                  createdAt: DateTime(2026),
                  files: const [
                    NearbyFile('a', 'three.txt', 'text/plain', 3),
                    NearbyFile('b', 'four.txt', 'text/plain', 4),
                  ],
                ),
              ],
            );
      await _pump(t, core: core);
      await _openDetails(t, _fp);
      expect(find.byKey(const Key('nearbyTruncated')), findsOneWidget);
      expect(find.byKey(const Key('nearbyFile-s2-a')), findsNothing);
      await t.ensureVisible(find.byKey(const Key('nearbyShare-s2')));
      await t.tap(find.byKey(const Key('nearbyShare-s2')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('nearbyFile-s2-b')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('nearbyDownload')));
      await t.pumpAndSettle();
      // The same file id in two shares is told apart by the share id.
      expect(core.downloadNearbyCalls.single.$3, [('s2', 'b')]);
    });

    testWidgets('Refresh asks the device again and shows the new list', (
      t,
    ) async {
      final core = FakeCore(
        simulateDelay: Duration.zero,
        initialPeers: const [_peer],
      )..nearbyListings[_fp] = _listing(_fp);
      await _pump(t, core: core);
      await _openDetails(t, _fp);
      await t.tap(find.byKey(const Key('nearbyFile-s1-f1')));
      core.nearbyListings[_fp] = _listing(
        _fp,
        shares: [
          NearbyShare(
            id: 's1',
            createdAt: DateTime(2026),
            files: const [
              NearbyFile('f9', 'new-file.zip', 'application/zip', 5),
            ],
          ),
        ],
      );
      await t.ensureVisible(find.byKey(const Key('nearbyRefresh')));
      await t.tap(find.byKey(const Key('nearbyRefresh')));
      await t.pumpAndSettle();
      expect(core.listNearbyCalls, [_fp, _fp]);
      expect(find.text('new-file.zip'), findsWidgets);
      expect(find.byKey(const Key('nearbyFile-s1-f1')), findsNothing);
      // The selection of a vanished file is dropped.
      expect(find.text(en.nearbyDownloadSelected(0)), findsOneWidget);
    });

    testWidgets('empty listing and failure show the same hint', (t) async {
      final core = FakeCore(
        simulateDelay: Duration.zero,
        initialPeers: const [_peer],
      );
      await _pump(t, core: core);
      await _openDetails(t, _fp);
      expect(find.text(en.nearbyEmpty), findsOneWidget);
      expect(find.text(en.nearbyEmptyHint), findsOneWidget);
      expect(find.byKey(const Key('nearbyDownload')), findsNothing);
      await t.tapAt(const Offset(200, 20));
      await t.pumpAndSettle();
      core.failNearbyList.add(_fp);
      await _openDetails(t, _fp);
      expect(find.text(en.nearbyEmpty), findsOneWidget);
      expect(find.text(en.nearbyEmptyHint), findsOneWidget);
      expect(find.byKey(const Key('nearbyRefresh')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('an expired ticket is renewed (re-listed) before downloading', (
      t,
    ) async {
      final past = DateTime.now().subtract(const Duration(minutes: 1));
      final core = FakeCore(
        simulateDelay: Duration.zero,
        initialPeers: const [_peer],
      )..nearbyListings[_fp] = _listing(_fp, expires: past);
      await _pump(t, core: core);
      await _openDetails(t, _fp);
      expect(core.listNearbyCalls, hasLength(1));
      await t.tap(find.byKey(const Key('nearbyFile-s1-f2')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('nearbyDownload')));
      await t.pumpAndSettle();
      expect(core.listNearbyCalls, hasLength(2)); // re-listed first
      expect(core.downloadNearbyCalls.single.$3, [('s1', 'f2')]);
    });

    testWidgets('a valid ticket is not renewed', (t) async {
      final core = FakeCore(
        simulateDelay: Duration.zero,
        initialPeers: const [_peer],
      )..nearbyListings[_fp] = _listing(_fp);
      await _pump(t, core: core);
      await _openDetails(t, _fp);
      await t.tap(find.byKey(const Key('nearbyFile-s1-f2')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('nearbyDownload')));
      await t.pumpAndSettle();
      expect(core.listNearbyCalls, hasLength(1));
      expect(core.downloadNearbyCalls, hasLength(1));
    });
  });

  group('Owner dialog', () {
    for (final (key, decision) in [
      ('nearbyAccessDeny', NearbyDecision.deny),
      ('nearbyAccessOnce', NearbyDecision.allowOnce),
      ('nearbyAccessAlways', NearbyDecision.alwaysAllow),
    ]) {
      testWidgets('$key answers $decision', (t) async {
        final core = await _pump(t);
        core.emitNearbyRequest(_req('r1'));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('nearbyAccessDialog')), findsOneWidget);
        expect(find.text(en.nearbyAccessTitle('Laptop')), findsOneWidget);
        // First 8 hex of the fingerprint, left to right.
        expect(find.text('ABCDEF01'), findsOneWidget);
        await t.tap(find.byKey(Key(key)));
        await t.pumpAndSettle();
        expect(core.nearbyAnswers, [('r1', decision)]);
        expect(find.byKey(const Key('nearbyAccessDialog')), findsNothing);
        if (decision == NearbyDecision.alwaysAllow) {
          expect(
            _controller(t).trustedDevice('abcdef0123456789' * 4),
            isNotNull,
          );
        }
      });
    }

    testWidgets('the next request is shown after the first is answered', (
      t,
    ) async {
      final core = await _pump(t);
      core.emitNearbyRequest(_req('r1', alias: 'First'));
      core.emitNearbyRequest(_req('r2', alias: 'Second'));
      await t.pumpAndSettle();
      expect(find.text(en.nearbyAccessTitle('First')), findsOneWidget);
      await t.tap(find.byKey(const Key('nearbyAccessDeny')));
      await t.pumpAndSettle();
      expect(find.text(en.nearbyAccessTitle('Second')), findsOneWidget);
      await t.tap(find.byKey(const Key('nearbyAccessOnce')));
      await t.pumpAndSettle();
      expect(core.nearbyAnswers, [
        ('r1', NearbyDecision.deny),
        ('r2', NearbyDecision.allowOnce),
      ]);
      expect(find.byKey(const Key('nearbyAccessDialog')), findsNothing);
    });

    testWidgets('it closes itself when answered elsewhere', (t) async {
      final core = await _pump(t);
      core.emitNearbyRequest(_req('r1'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('nearbyAccessDialog')), findsOneWidget);
      await _controller(t).answerNearbyRequest('r1', NearbyDecision.deny);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('nearbyAccessDialog')), findsNothing);
    });

    testWidgets('it closes itself when the request expires', (t) async {
      final core = await _pump(t);
      core.emitNearbyRequest(
        _req('r1', at: DateTime.now().subtract(const Duration(seconds: 59))),
      );
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(find.byKey(const Key('nearbyAccessDialog')), findsOneWidget);
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('nearbyAccessDialog')), findsNothing);
      expect(_controller(t).pendingNearbyRequest, isNull);
    });

    testWidgets('it waits for the incoming-transfer dialog', (t) async {
      final core = await _pump(t);
      core.simulateIncoming(autoProgress: false);
      await t.pumpAndSettle();
      expect(find.text(en.commonDecline), findsOneWidget);
      core.emitNearbyRequest(_req('r1'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('nearbyAccessDialog')), findsNothing);
      await t.tap(find.text(en.commonDecline));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('nearbyAccessDialog')), findsOneWidget);
      await t.tap(find.byKey(const Key('nearbyAccessDeny')));
      await t.pumpAndSettle();
    });

    testWidgets('a device without a name shows its code in the title', (
      t,
    ) async {
      final core = await _pump(t);
      core.emitNearbyRequest(_req('r1', alias: ''));
      await t.pumpAndSettle();
      expect(find.text(en.nearbyAccessTitle('ABCDEF01')), findsOneWidget);
      await t.tap(find.byKey(const Key('nearbyAccessDeny')));
      await t.pumpAndSettle();
    });
  });

  group('Persian (RTL)', () {
    final englishOnly = () {
      final a = jsonDecode(
        File('lib/l10n/app_en.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      return {
        for (final k in a.keys)
          if (k.startsWith('nearby') &&
              !k.startsWith('@') &&
              !(a[k] as String).contains('{'))
            a[k] as String,
      }..addAll({en.nearbyDownloadSelected(0)});
    }();

    List<String> texts(WidgetTester t) => [
      for (final w in t.widgetList<Text>(find.byType(Text)))
        w.data ?? w.textSpan?.toPlainText() ?? '',
    ];

    for (final width in [375.0, 1000.0]) {
      final w = width.toInt();
      testWidgets('sheet at $w px', (t) async {
        final core =
            FakeCore(
                simulateDelay: Duration.zero,
                initialPeers: const [_persianPeer],
              )
              ..nearbyListings['fa77'] = _listing(
                'fa77',
                truncated: true,
                shares: [
                  NearbyShare(
                    id: 's1',
                    createdAt: DateTime(2026),
                    truncated: true,
                    files: const [
                      NearbyFile(
                        'f1',
                        'گزارش-final-نسخه-نهایی-2024-با-نام-خیلی-بلند.pdf',
                        'application/pdf',
                        3250585,
                      ),
                      NearbyFile('f2', 'photo.jpg', 'image/jpeg', 2048),
                    ],
                  ),
                ],
              );
        await _pump(
          t,
          locale: 'fa',
          width: width,
          core: core,
          peers: const [_persianPeer],
          trusted: const ['fa77'],
        );
        expectRtl(t);
        expect(find.text(fa.nearbySharesTitle), findsOneWidget); // chip
        await _openDetails(t, 'fa77');
        expect(find.text(fa.nearbySharesTitle), findsWidgets);
        expect(find.text('۳٫۱ مگابایت'), findsWidgets);
        expect(find.text(fa.nearbySelectAll), findsOneWidget);
        expect(find.text(fa.nearbyDownloadSelected(0)), findsOneWidget);
        expect(fa.nearbyDownloadSelected(2), contains('۲'));
        expect(find.text(fa.nearbyTruncated), findsOneWidget);
        // A Persian name reads right to left, a Latin one left to right.
        final names = t.widgetList<Text>(find.byType(Text)).toList();
        final persian = names.firstWhere(
          (x) => (x.data ?? '').contains('گزارش'),
        );
        expect(persian.textDirection, TextDirection.rtl);
        expect(persian.data, contains('…')); // middle ellipsis
        expect(
          t.widget<Text>(find.text('photo.jpg')).textDirection,
          TextDirection.ltr,
        );
        final leaked = [
          for (final s in texts(t))
            if (englishOnly.contains(s)) s,
        ];
        expect(leaked, isEmpty);
        expect(t.takeException(), isNull);
      });

      testWidgets('empty sheet at $w px', (t) async {
        await _pump(
          t,
          locale: 'fa',
          width: width,
          peers: const [_persianPeer],
          trusted: const ['fa77'],
        );
        await _openDetails(t, 'fa77');
        expect(find.text(fa.nearbyEmpty), findsOneWidget);
        expect(find.text(fa.nearbyEmptyHint), findsOneWidget);
        expect(find.text(fa.nearbyRefresh), findsOneWidget);
        expect(t.takeException(), isNull);
      });

      testWidgets('owner dialog at $w px', (t) async {
        final core = await _pump(t, locale: 'fa', width: width);
        core.emitNearbyRequest(_req('r1', alias: 'لپ‌تاپ سارا'));
        await t.pumpAndSettle();
        expectRtl(t);
        expect(
          find.text(fa.nearbyAccessTitle(fa.isoName('لپ‌تاپ سارا'))),
          findsOneWidget,
        );
        for (final s in [
          fa.nearbyAccessDeny,
          fa.nearbyAccessOnce,
          fa.nearbyAccessAlways,
        ]) {
          expect(find.text(s), findsOneWidget);
        }
        // The fingerprint prefix stays Latin and left to right.
        final code = t.widget<Text>(
          find.descendant(
            of: find.byKey(const Key('nearbyAccessFingerprint')),
            matching: find.byType(Text),
          ),
        );
        expect(code.data, 'ABCDEF01');
        expect(code.textDirection, TextDirection.ltr);
        expect(
          Directionality.of(
            t.element(
              find.descendant(
                of: find.byKey(const Key('nearbyAccessFingerprint')),
                matching: find.byType(Text),
              ),
            ),
          ),
          TextDirection.ltr,
        );
        final leaked = [
          for (final s in texts(t))
            if (englishOnly.contains(s)) s,
        ];
        expect(leaked, isEmpty);
        expect(t.takeException(), isNull);
        await t.tap(find.byKey(const Key('nearbyAccessDeny')));
        await t.pumpAndSettle();
      });
    }
  });
}
