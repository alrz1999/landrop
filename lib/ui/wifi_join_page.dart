import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'dialogs.dart' show latinDigitsFormatter;
import 'digits.dart';
import 'hotspot_service.dart' show escapeWifiQr;
import 'hotspot_wizard.dart' show FindDevicePanel;
import 'l10n.dart';
import 'permission_explainer.dart';
import 'widgets.dart';
import 'wifi_join_service.dart';
import 'wifi_qr.dart';
import 'wifi_scanner_view.dart';

/// Builds the camera view; calls `onCode` with each QR code text.
typedef WifiScannerBuilder = Widget Function(
    BuildContext context, void Function(String code) onCode);

enum _Stage { scan, confirm, joining, joined, error }

/// Why the scan or manual entry was not accepted.
enum _Hint { notWifiQr, manualInvalid }

/// Android only: scan the Wi-Fi QR code of another phone's hotspot (or type
/// the name and password), join that network, then look for the other device
/// (DESIGN.md 3.5).
class WifiJoinPage extends StatefulWidget {
  const WifiJoinPage(
      {super.key, this.service, this.scannerBuilder, this.localAddresses});

  /// Test seam; the default is the real channel-backed service.
  final WifiJoinApi? service;

  /// Test seam; the default is the camera ([WifiScannerView]).
  final WifiScannerBuilder? scannerBuilder;

  /// Test seam passed to [FindDevicePanel].
  final Future<List<String>> Function()? localAddresses;

  @override
  State<WifiJoinPage> createState() => _WifiJoinPageState();
}

class _WifiJoinPageState extends State<WifiJoinPage> {
  late final WifiJoinApi _service = widget.service ?? WifiJoinService();
  StreamSubscription<WifiJoinException>? _lostSub;
  final _ssid = TextEditingController();
  final _password = TextEditingController();
  bool _hidden = false;
  bool _manual = false;
  _Stage _stage = _Stage.scan;
  bool? _camera; // null while asking
  WifiCredentials? _creds;
  WifiJoinResult? _joined;
  WifiJoinException? _error;
  _Hint? _hint;
  WifiJoinException? _banner;

  @override
  void initState() {
    super.initState();
    _lostSub = _service.lost.listen((e) {
      if (mounted && _stage == _Stage.joined) {
        setState(() => _banner = e);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _askCamera());
  }

  @override
  void dispose() {
    _lostSub?.cancel();
    _ssid.dispose();
    _password.dispose();
    // The network stays joined (files may still be moving); only "Leave
    // network" releases it.
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  /// "Not now" on the camera explanation (UX.md 3.6).
  bool _cameraNotNow = false;

  /// The camera explanation is open (no spinner behind it).
  bool _explaining = false;

  Future<void> _askCamera() async {
    if (mounted) {
      setState(() {
        _camera = null;
        _explaining = true;
      });
    }
    final go = await explainBeforeAsking(context, AppPermission.camera);
    if (mounted) setState(() => _explaining = false);
    if (!go) {
      if (mounted) {
        setState(() {
          _cameraNotNow = true;
          _camera = false;
          _manual = true; // typing the name is the way on without it
        });
      }
      return;
    }
    _cameraNotNow = false;
    final ok = await _service.requestCamera();
    if (mounted) setState(() => _camera = ok);
  }

  void _onCode(String code) {
    if (_stage != _Stage.scan) return;
    final c = parseWifiQr(code);
    setState(() {
      if (c == null) {
        _hint = _Hint.notWifiQr;
      } else {
        _hint = null;
        _creds = c;
        _stage = _Stage.confirm;
      }
    });
  }

  void _submitManual() {
    // Typed on a Persian keyboard: digits become Latin (UX.md 4.6).
    final ssid = normalizeDigits(_ssid.text).trim();
    final pass = normalizeDigits(_password.text);
    final c = parseWifiQr(
        'WIFI:T:${pass.isEmpty ? 'nopass' : 'WPA'};S:${escapeWifiQr(ssid)};'
        'P:${escapeWifiQr(pass)};H:$_hidden;;');
    setState(() {
      if (c == null) {
        _hint = _Hint.manualInvalid;
      } else {
        _hint = null;
        _creds = c;
        _stage = _Stage.confirm;
      }
    });
  }

  Future<void> _join() async {
    final c = _creds;
    if (c == null) return;
    setState(() {
      _stage = _Stage.joining;
      _error = null;
      _banner = null;
    });
    try {
      final r = await _service.join(c);
      if (!mounted) return;
      setState(() {
        _joined = r;
        _stage = _Stage.joined;
      });
    } on WifiJoinException catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _stage = _Stage.error;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = wifiJoinError('failed', '$e');
          _stage = _Stage.error;
        });
      }
    }
  }

  Future<void> _leave() async {
    await _service.leave();
    if (!mounted) return;
    setState(() {
      _joined = null;
      _creds = null;
      _banner = null;
      _stage = _Stage.scan;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l.connectWifiJoinTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            key: const Key('wifiJoinPage'),
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
            children: switch (_stage) {
              _Stage.scan => _scan(context),
              _Stage.confirm => _confirm(context),
              _Stage.joining => _joining(context),
              _Stage.joined => _done(context),
              _Stage.error => _errorView(context),
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _scan(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l = context.l;
    final builder = widget.scannerBuilder ??
        (BuildContext _, void Function(String) onCode) =>
            WifiScannerView(onCode: onCode);
    return [
      Text(l.wifiJoinScanIntro, style: t.bodyMedium),
      const SizedBox(height: 12),
      if (_camera == null && _explaining)
        const SizedBox(height: 48)
      else if (_camera == null)
        const Center(child: CircularProgressIndicator())
      else if (_camera == true)
        SizedBox(
          key: const Key('scannerBox'),
          height: 300,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: builder(context, _onCode),
          ),
        )
      else if (_cameraNotNow)
        PermissionNotNowNote(
            permission: AppPermission.camera, onRetry: _askCamera)
      else ...[
        Text(wifiJoinMessage('camera', null, l),
            key: const Key('cameraDenied'),
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('retryCamera'),
          onPressed: _askCamera,
          icon: const Icon(Icons.photo_camera),
          label: Text(l.wifiJoinAllowCamera),
        ),
      ],
      if (_hint != null)
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 8),
          child: Text(
              _hint == _Hint.notWifiQr
                  ? l.wifiJoinNotWifiQr
                  : l.wifiJoinManualInvalid,
              key: const Key('scanHint'),
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      const SizedBox(height: 8),
      TextButton.icon(
        key: const Key('manualToggle'),
        onPressed: () => setState(() => _manual = !_manual),
        icon: Icon(_manual ? Icons.expand_less : Icons.keyboard),
        label: Text(l.wifiJoinManualToggle),
      ),
      if (_manual) ...[
        // Technical values: left to right, Persian digits typed as Latin.
        TextField(
          key: const Key('manualSsid'),
          controller: _ssid,
          textDirection: TextDirection.ltr,
          inputFormatters: [latinDigitsFormatter],
          decoration: InputDecoration(labelText: l.wifiJoinNetworkName),
        ),
        TextField(
          key: const Key('manualPassword'),
          controller: _password,
          obscureText: false,
          textDirection: TextDirection.ltr,
          keyboardType: TextInputType.visiblePassword,
          inputFormatters: [latinDigitsFormatter],
          decoration: InputDecoration(labelText: l.wifiJoinPasswordLabel),
        ),
        CheckboxListTile(
          key: const Key('manualHidden'),
          contentPadding: EdgeInsetsDirectional.zero,
          value: _hidden,
          onChanged: (v) => setState(() => _hidden = v ?? false),
          title: Text(l.wifiJoinHidden),
        ),
        FilledButton(
          key: const Key('manualContinue'),
          onPressed: _submitManual,
          child: Text(l.wifiJoinContinue),
        ),
      ],
    ];
  }

  List<Widget> _confirm(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l = context.l;
    final c = _creds!;
    return [
      Text(l.wifiJoinConfirmTitle(l.ltrValue(c.ssid)),
          key: const Key('joinConfirmTitle'), style: t.titleLarge),
      const SizedBox(height: 8),
      Text(l.wifiJoinExplain,
          key: const Key('joinExplain'), style: t.bodyMedium),
      const SizedBox(height: 16),
      FilledButton.icon(
        key: const Key('joinButton'),
        onPressed: _join,
        icon: const Icon(Icons.wifi),
        label: Text(l.wifiJoinJoin),
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        key: const Key('cancelJoin'),
        onPressed: () => setState(() => _stage = _Stage.scan),
        child: Text(l.commonCancel),
      ),
    ];
  }

  List<Widget> _joining(BuildContext context) => [
        const SizedBox(height: 24),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 16),
        Text(context.l.wifiJoinJoining(context.l.ltrValue(_creds?.ssid ?? '')),
            key: const Key('joining'), textAlign: TextAlign.center),
      ];

  List<Widget> _errorView(BuildContext context) => [
        Text(_error?.localized(context.l) ?? '',
            key: const Key('joinError'),
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('joinRetry'),
          onPressed: _join,
          child: Text(context.l.commonTryAgain),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('joinBack'),
          onPressed: () => setState(() => _stage = _Stage.scan),
          child: Text(context.l.wifiJoinScanAgain),
        ),
      ];

  List<Widget> _done(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l = context.l;
    final gw = _joined?.gateway;
    final ssid = _joined?.ssid.isNotEmpty == true
        ? _joined!.ssid
        : _creds?.ssid ?? '';
    return [
      Text(l.wifiJoinJoined(l.ltrValue(ssid)),
          key: const Key('joinedTitle'), style: t.titleLarge),
      if (_banner != null)
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 8),
          child: Text(_banner!.localized(l),
              key: const Key('joinLost'),
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      SectionHeader(l.wifiJoinFindTitle),
      FindDevicePanel(
        label: l.wifiJoinFindTitle,
        autoStart: true,
        localAddresses: widget.localAddresses,
        extraGateways: [?gw],
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        key: const Key('leaveNetwork'),
        onPressed: _leave,
        icon: const Icon(Icons.wifi_off),
        label: Text(l.wifiJoinLeave),
      ),
    ];
  }
}

/// Opens the page.
Future<void> openWifiJoin(BuildContext context) => Navigator.push(
    context, MaterialPageRoute(builder: (_) => const WifiJoinPage()));

/// Whether the QR join entry points are shown: Android only.
bool wifiJoinAvailable([bool? android]) => android ?? Platform.isAndroid;
