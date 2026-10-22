import 'package:flutter/material.dart';

import '../core/api.dart';
import 'cable_wizard.dart';
import 'diagnosis_dialog.dart';
import 'hotspot_wizard.dart';
import 'l10n.dart';
import 'pickers.dart';
import 'shares.dart';
import 'widgets.dart';
import 'wifi_direct_page.dart';
import 'wifi_join_page.dart';

/// What the other device is (helper question 2, UX.md 3.4).
enum OtherDeviceKind { android, iphone, computer, browser }

/// The ways the helper can connect two devices; each one reuses an existing
/// wizard widget or page.
enum ConnectMethod {
  /// This device shares a hotspot ([HotspotCard] on Android, else steps).
  shareHotspot,

  /// The other device shares a hotspot, this one joins it.
  joinHotspot,

  /// Android: scan the other phone's LanDrop hotspot QR ([WifiJoinPage]).
  joinByQr,

  /// Android: Wi-Fi Direct ([WifiDirectPage]).
  wifiDirect,

  /// Ethernet or USB tethering ([CableSetup]).
  cable,

  /// The other device only has a browser (Shares page).
  browser,
}

/// Answer to "Are both devices on the same Wi-Fi?".
enum _SameWifi { yes, no }

/// Methods for this device ([self]) and the [other] one, recommended first.
/// Android-only methods are offered only when this device is Android.
List<ConnectMethod> connectMethodsFor(
    HotspotPlatform self, OtherDeviceKind other) {
  if (other == OtherDeviceKind.browser) return const [ConnectMethod.browser];
  switch (self) {
    case HotspotPlatform.android:
      return switch (other) {
        OtherDeviceKind.android => const [
            ConnectMethod.shareHotspot,
            ConnectMethod.joinByQr,
            ConnectMethod.wifiDirect,
          ],
        OtherDeviceKind.iphone => const [
            ConnectMethod.shareHotspot,
            ConnectMethod.joinHotspot,
          ],
        _ => const [ConnectMethod.shareHotspot, ConnectMethod.cable],
      };
    case HotspotPlatform.ios:
      return switch (other) {
        OtherDeviceKind.android => const [
            ConnectMethod.joinHotspot,
            ConnectMethod.shareHotspot,
          ],
        OtherDeviceKind.iphone => const [
            ConnectMethod.shareHotspot,
            ConnectMethod.joinHotspot,
          ],
        _ => const [ConnectMethod.shareHotspot, ConnectMethod.cable],
      };
    case HotspotPlatform.macos ||
          HotspotPlatform.windows ||
          HotspotPlatform.linux ||
          HotspotPlatform.other:
      return switch (other) {
        OtherDeviceKind.computer => const [
            ConnectMethod.cable,
            ConnectMethod.shareHotspot,
            ConnectMethod.joinHotspot,
          ],
        _ => const [ConnectMethod.joinHotspot, ConnectMethod.cable],
      };
  }
}

/// Finding codes that are only background information (UX.md 4.10): never
/// the one result the automatic check shows.
const infoOnlyFindingCodes = {
  'network',
  'udp-only-no-mdns',
  'mdns-only',
  'some-peers-silent',
  'mdns-unavailable',
};

/// The one finding the automatic check shows: the worst problem or warning,
/// else the first plain info (e.g. "all good"); null when there is none.
Finding? mainFinding(List<Finding> findings) {
  final shown = [
    for (final f in findings)
      if (!infoOnlyFindingCodes.contains(f.code)) f
  ];
  if (shown.isEmpty) return null;
  var best = shown.first;
  for (final f in shown) {
    if (f.severity.index > best.severity.index) best = f;
  }
  return best;
}

/// Opens the helper. [action] is a [Finding.action] chosen in the diagnosis
/// dialog: the helper then skips its check and starts at the matching step.
Future<void> openConnectHelper(
  BuildContext context, {
  String? action,
  FilesPicker pickFiles = defaultPickFiles,
  FolderPicker pickFolder = defaultPickFolder,
}) =>
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConnectHelperPage(
          initialAction: action,
          autoCheck: action == null,
          pickFiles: pickFiles,
          pickFolder: pickFolder,
        ),
      ),
    );

/// "Can't find the other device?" (UX.md 3.4, step U4): an automatic check,
/// at most two questions, then one connection method built from the existing
/// wizard widgets, always ending in the search for the other device, "Try
/// another way" and "Copy connection report".
class ConnectHelperPage extends StatefulWidget {
  const ConnectHelperPage({
    super.key,
    this.platform,
    this.localAddresses,
    this.initialAction,
    this.autoCheck = true,
    this.pickFiles = defaultPickFiles,
    this.pickFolder = defaultPickFolder,
  });

  /// Test seam; default [currentHotspotPlatform].
  final HotspotPlatform? platform;

  /// Test seam: this device's LAN addresses (passed to the search).
  final Future<List<String>> Function()? localAddresses;

  /// Start at the step for this [Finding.action] (hotspot or cable).
  final String? initialAction;

  /// Run the diagnosis and a rescan when the page opens.
  final bool autoCheck;

  /// Passed on to the Shares page ("Only a browser").
  final FilesPicker pickFiles;
  final FolderPicker pickFolder;

  @override
  State<ConnectHelperPage> createState() => _ConnectHelperPageState();
}

class _ConnectHelperPageState extends State<ConnectHelperPage> {
  bool _checking = false;
  List<Finding>? _findings;
  String? _checkError;

  /// Devices known before the check; any other device was found by it.
  Set<String>? _before;

  _SameWifi? _sameWifi;
  bool _sameWifiFailed = false;
  OtherDeviceKind? _other;
  ConnectMethod? _method;

  HotspotPlatform get _platform => widget.platform ?? currentHotspotPlatform();

  @override
  void initState() {
    super.initState();
    if (widget.initialAction != null) _onAction(widget.initialAction!);
    if (widget.autoCheck) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _check();
      });
    }
  }

  /// Step 0: the diagnosis plus a rescan, in parallel.
  Future<void> _check() async {
    final c = AppScope.read(context);
    setState(() {
      _checking = true;
      _checkError = null;
      _before ??= {for (final p in c.peers) p.fingerprint};
    });
    Future<void> rescan() async {
      try {
        await c.rescan();
      } catch (_) {
        // The diagnosis explains why searching fails.
      }
    }

    try {
      final results = await Future.wait<Object?>([c.runDiagnosis(), rescan()]);
      if (!mounted) return;
      setState(() => _findings = results.first as List<Finding>);
    } catch (e) {
      if (mounted) setState(() => _checkError = '$e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  /// A finding's button inside the helper: go to the matching step.
  void _onAction(String action) {
    setState(() {
      if (action == cableWizardAction) {
        _choose(ConnectMethod.cable);
      } else if (action == hotspotWizardAction) {
        _sameWifi = _SameWifi.no;
        _other = null;
        _method = null;
      }
    });
  }

  void _choose(ConnectMethod m) {
    _method = m;
  }

  void _restart() => setState(() {
        _sameWifi = null;
        _sameWifiFailed = false;
        _other = null;
        _method = null;
      });

  Future<void> _copyReport() async {
    var findings = _findings;
    if (findings == null) {
      try {
        findings = await AppScope.read(context).runDiagnosis();
      } catch (_) {
        return;
      }
      if (!mounted) return;
      setState(() => _findings = findings);
    }
    await copyDiagnosisReport(context, findings);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Scaffold(
      appBar: AppBar(title: Text(l.helperTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            key: const Key('connectHelper'),
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
            children: [
              ..._checkSection(context),
              const SizedBox(height: 8),
              ..._stepSection(context),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_sameWifi != null || _method != null)
                    OutlinedButton.icon(
                      key: const Key('helperTryAnother'),
                      onPressed: _restart,
                      icon: const Icon(Icons.alt_route),
                      label: Text(l.helperTryAnother),
                    ),
                  TextButton.icon(
                    key: const Key('helperCopyReport'),
                    onPressed: _checking ? null : _copyReport,
                    icon: const Icon(Icons.copy),
                    label: Text(l.helperCopyReport),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Step 0: automatic check ---------------------------------------------

  List<Widget> _checkSection(BuildContext context) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    if (_checking && _findings == null) {
      return [
        Padding(
          key: const Key('helperChecking'),
          padding: const EdgeInsetsDirectional.symmetric(vertical: 12),
          child: Row(children: [
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 16),
            Expanded(child: Text(l.helperChecking, style: t.bodyLarge)),
          ]),
        ),
      ];
    }
    final findings = _findings;
    final before = _before;
    final newDevices = [
      if (before != null && !_checking)
        for (final p in AppScope.of(context).peers)
          if (!before.contains(p.fingerprint)) p
    ];
    final main = findings == null ? null : mainFinding(findings);
    final rest = [
      for (final f in findings ?? const <Finding>[])
        if (f != main && !hiddenFindingCodes.contains(f.code)) f
    ];
    return [
      if (_checkError != null)
        Text(l.diagError(_checkError!),
            key: const Key('helperCheckError'),
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      if (newDevices.isNotEmpty)
        Card(
          key: const Key('helperFound'),
          child: ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: Text(l.helperFound(l.isoName(newDevices.first.alias))),
            trailing: TextButton(
              key: const Key('helperBack'),
              onPressed: () => Navigator.maybePop(context),
              child: Text(l.findBackToDevices),
            ),
          ),
        ),
      if (main != null)
        Card(
          key: const Key('helperResult'),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
            child: FindingTile(finding: main, onAction: _onAction),
          ),
        )
      else if (findings != null)
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
          child: Text(l.helperCheckFine,
              key: const Key('helperCheckFine'), style: t.bodyLarge),
        ),
      // Everything else the check saw, collapsed (technical texts stay
      // collapsed again inside each finding).
      if (rest.isNotEmpty)
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: const Key('helperDetails'),
            tilePadding: EdgeInsetsDirectional.zero,
            title: Text(l.diagDetails),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final f in rest) FindingTile(finding: f)],
          ),
        ),
    ];
  }

  // --- Questions and methods ----------------------------------------------

  List<Widget> _stepSection(BuildContext context) {
    final method = _method;
    if (method != null) return _methodSection(context, method);
    if (_sameWifi == _SameWifi.yes) return _sameWifiSection(context);
    if (_sameWifi == _SameWifi.no) return _question2(context);
    return _question1(context);
  }

  Widget _answer(Key key, IconData icon, String text, VoidCallback onTap) =>
      Card(
        child: ListTile(
          key: key,
          leading: Icon(icon),
          title: Text(text),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );

  Widget _question(String text, Key key) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 4, 8),
        child: Text(text,
            key: key, style: Theme.of(context).textTheme.titleMedium),
      );

  List<Widget> _question1(BuildContext context) {
    final l = context.l;
    return [
      _question(l.helperQ1, const Key('helperQ1')),
      _answer(const Key('q1-same'), Icons.wifi, l.helperQ1Same,
          () => setState(() => _sameWifi = _SameWifi.yes)),
      _answer(const Key('q1-different'), Icons.wifi_off, l.helperQ1Different,
          () => setState(() => _sameWifi = _SameWifi.no)),
      _answer(const Key('q1-cable'), Icons.cable, l.helperQ1Cable,
          () => setState(() => _choose(ConnectMethod.cable))),
    ];
  }

  List<Widget> _sameWifiSection(BuildContext context) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    return [
      _question(l.helperQ1Same, const Key('helperSameWifi')),
      Text(l.helperChecklist,
          key: const Key('helperChecklist'), style: t.bodyLarge),
      const SizedBox(height: 12),
      FindDevicePanel(
        label: l.helperSearchAgain,
        localAddresses: widget.localAddresses,
        nothingFoundHint: l.helperSameWifiNothing,
        onFound: (found) => setState(() => _sameWifiFailed = found.isEmpty),
      ),
      if (_sameWifiFailed) ...[
        const SizedBox(height: 16),
        Text(l.helperBlocked,
            key: const Key('helperBlocked'), style: t.bodyLarge),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.tonalIcon(
            key: const Key('helperConnectDirectly'),
            onPressed: () => setState(() => _sameWifi = _SameWifi.no),
            icon: const Icon(Icons.wifi_tethering),
            label: Text(l.helperConnectDirectly),
          ),
        ),
      ],
    ];
  }

  List<Widget> _question2(BuildContext context) {
    final l = context.l;
    void pick(OtherDeviceKind k) => setState(() {
          _other = k;
          _choose(connectMethodsFor(_platform, k).first);
        });
    return [
      _question(l.helperQ2, const Key('helperQ2')),
      _answer(const Key('q2-android'), Icons.phone_android, l.helperQ2Android,
          () => pick(OtherDeviceKind.android)),
      _answer(const Key('q2-iphone'), Icons.phone_iphone, l.helperQ2Iphone,
          () => pick(OtherDeviceKind.iphone)),
      _answer(const Key('q2-computer'), Icons.computer, l.helperQ2Computer,
          () => pick(OtherDeviceKind.computer)),
      _answer(const Key('q2-browser'), Icons.public, l.helperQ2Browser,
          () => pick(OtherDeviceKind.browser)),
    ];
  }

  (String, String) _methodText(AppLocalizations l, ConnectMethod m) {
    final phoneToPhone = _platform == HotspotPlatform.android &&
        (_other == OtherDeviceKind.android || _other == OtherDeviceKind.iphone);
    return switch (m) {
      ConnectMethod.shareHotspot => phoneToPhone
          ? (l.helperMethodShareQrTitle, l.helperMethodShareQrBody)
          : (l.helperMethodShareTitle, l.helperMethodShareBody),
      ConnectMethod.joinHotspot => (
          l.helperMethodJoinTitle,
          l.helperMethodJoinBody
        ),
      ConnectMethod.joinByQr => (
          l.helperMethodJoinQrTitle,
          l.helperMethodJoinQrBody
        ),
      ConnectMethod.wifiDirect => (
          l.helperMethodWifiDirectTitle,
          l.helperMethodWifiDirectBody
        ),
      ConnectMethod.cable => (l.connectCableTitle, l.cableIntro),
      ConnectMethod.browser => (
          l.helperMethodBrowserTitle,
          l.helperMethodBrowserBody
        ),
    };
  }

  IconData _methodIcon(ConnectMethod m) => switch (m) {
        ConnectMethod.shareHotspot => Icons.wifi_tethering,
        ConnectMethod.joinHotspot => Icons.wifi,
        ConnectMethod.joinByQr => Icons.qr_code_scanner,
        ConnectMethod.wifiDirect => Icons.wifi_find,
        ConnectMethod.cable => Icons.cable,
        ConnectMethod.browser => Icons.public,
      };

  /// The other device's platforms for its steps; null = every computer.
  List<HotspotPlatform>? get _otherPlatforms => switch (_other) {
        OtherDeviceKind.android => const [HotspotPlatform.android],
        OtherDeviceKind.iphone => const [HotspotPlatform.ios],
        _ => const [
            HotspotPlatform.macos,
            HotspotPlatform.windows,
            HotspotPlatform.linux,
          ],
      };

  List<Widget> _methodSection(BuildContext context, ConnectMethod m) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final c = AppScope.of(context);
    final p = _platform;
    final other = _other;
    final methods = other == null ? [m] : connectMethodsFor(p, other);
    final (title, body) = _methodText(l, m);
    final android = p == HotspotPlatform.android;
    final otherPlatforms = _otherPlatforms;
    final otherIsOnePhone = otherPlatforms != null && otherPlatforms.length == 1;

    Widget otherSteps(HotspotRole role) => otherIsOnePhone
        ? WizardSteps(hotspotSteps(otherPlatforms.single, role, l),
            keyPrefix: 'helper-other')
        : OtherDeviceSteps(
            role: role,
            platforms: otherPlatforms,
            initiallyExpanded: true,
            title: role == HotspotRole.join
                ? l.hotspotOtherJoin
                : l.hotspotOtherShare);

    final content = <Widget>[
      switch (m) {
        ConnectMethod.shareHotspot => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(l.helperOnThisDevice),
              WizardSteps(hotspotSteps(p, HotspotRole.share, l),
                  keyPrefix: 'helper-step'),
              if (android && c.hotspotService.supported) const HotspotCard(),
              SectionHeader(l.helperOnOtherDevice),
              otherSteps(HotspotRole.join),
            ],
          ),
        ConnectMethod.joinHotspot => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(l.helperOnOtherDevice),
              otherSteps(HotspotRole.share),
              SectionHeader(l.helperOnThisDevice),
              WizardSteps([
                ...hotspotSteps(p, HotspotRole.join, l),
                l.hotspotStepVpn,
              ], keyPrefix: 'helper-step'),
              if (android) _scanQrButton(context),
            ],
          ),
        ConnectMethod.joinByQr => _scanQrButton(context),
        ConnectMethod.wifiDirect => Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              key: const Key('helperWifiDirect'),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const WifiDirectPage())),
              icon: const Icon(Icons.wifi_find),
              label: Text(l.helperOpenWifiDirect),
            ),
          ),
        ConnectMethod.cable => CableSetup(
            platform: p,
            localAddresses: widget.localAddresses,
            initialKind: p == HotspotPlatform.android ||
                    p == HotspotPlatform.ios ||
                    other == OtherDeviceKind.android ||
                    other == OtherDeviceKind.iphone
                ? CableKind.usbTether
                : CableKind.ethernet,
          ),
        ConnectMethod.browser => Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              key: const Key('helperOpenShares'),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SharesPage(
                          pickFiles: widget.pickFiles,
                          pickFolder: widget.pickFolder))),
              icon: const Icon(Icons.ios_share),
              label: Text(l.helperOpenShares),
            ),
          ),
      },
    ];

    // The cable steps have their own search; the browser needs none.
    final ownSearch = m == ConnectMethod.cable || m == ConnectMethod.browser;
    return [
      Card(
        key: Key('helperMethod-${m.name}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (methods.length > 1 && m == methods.first)
                Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: 4),
                  child: Text(l.helperRecommended,
                      key: const Key('helperRecommended'),
                      style: t.labelLarge
                          ?.copyWith(color: Theme.of(context).colorScheme.primary)),
                ),
              Row(children: [
                Icon(_methodIcon(m)),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: t.titleMedium)),
              ]),
              const SizedBox(height: 8),
              Text(body, style: t.bodyMedium),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      ...content,
      if (!ownSearch) ...[
        const SizedBox(height: 16),
        FindDevicePanel(
          label: l.hotspotFindLabel,
          localAddresses: widget.localAddresses,
        ),
      ],
      if (methods.length > 1) ...[
        SectionHeader(l.helperOtherWays),
        for (final alt in methods)
          if (alt != m)
            Card(
              child: ListTile(
                key: Key('alt-${alt.name}'),
                leading: Icon(_methodIcon(alt)),
                title: Text(_methodText(l, alt).$1),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => setState(() => _choose(alt)),
              ),
            ),
      ],
    ];
  }

  Widget _scanQrButton(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(top: 8),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.icon(
            key: const Key('helperScanQr'),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        WifiJoinPage(localAddresses: widget.localAddresses))),
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(context.l.hotspotScanQr),
          ),
        ),
      );
}
