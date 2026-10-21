import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'hotspot_service.dart' show escapeWifiQr;
import 'hotspot_wizard.dart' show FindDevicePanel;
import 'widgets.dart';
import 'wifi_join_service.dart';
import 'wifi_qr.dart';
import 'wifi_scanner_view.dart';

/// Builds the camera view; calls `onCode` with each QR code text.
typedef WifiScannerBuilder = Widget Function(
    BuildContext context, void Function(String code) onCode);

enum _Stage { scan, confirm, joining, joined, error }

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
  String? _error;
  String? _hint;
  String? _banner;

  @override
  void initState() {
    super.initState();
    _lostSub = _service.lost.listen((e) {
      if (mounted && _stage == _Stage.joined) {
        setState(() => _banner = e.message);
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

  Future<void> _askCamera() async {
    if (mounted) setState(() => _camera = null);
    final ok = await _service.requestCamera();
    if (mounted) setState(() => _camera = ok);
  }

  void _onCode(String code) {
    if (_stage != _Stage.scan) return;
    final c = parseWifiQr(code);
    setState(() {
      if (c == null) {
        _hint = 'That QR code is not a Wi-Fi code. Scan the code shown by '
            'the other phone\'s LanDrop hotspot.';
      } else {
        _hint = null;
        _creds = c;
        _stage = _Stage.confirm;
      }
    });
  }

  void _submitManual() {
    final ssid = _ssid.text.trim();
    final pass = _password.text;
    final c = parseWifiQr(
        'WIFI:T:${pass.isEmpty ? 'nopass' : 'WPA'};S:${escapeWifiQr(ssid)};'
        'P:${escapeWifiQr(pass)};H:$_hidden;;');
    setState(() {
      if (c == null) {
        _hint = 'Enter the network name (up to 32 characters) and its '
            'password (8 to 63 characters, or none for an open network).';
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
          _error = e.message;
          _stage = _Stage.error;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = wifiJoinMessage('failed', '$e');
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
      appBar: AppBar(title: const Text('Join a hotspot by QR')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            key: const Key('wifiJoinPage'),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
    final builder = widget.scannerBuilder ??
        (BuildContext _, void Function(String) onCode) =>
            WifiScannerView(onCode: onCode);
    return [
      Text(
          'On the other phone, open LanDrop > Connect without Wi-Fi > '
          '"This device shares the hotspot" > Start hotspot. Then point this '
          'camera at the QR code it shows.',
          style: t.bodyMedium),
      const SizedBox(height: 12),
      if (_camera == null)
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
      else ...[
        Text(wifiJoinMessage('camera'),
            key: const Key('cameraDenied'),
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('retryCamera'),
          onPressed: _askCamera,
          icon: const Icon(Icons.photo_camera),
          label: const Text('Allow the camera'),
        ),
      ],
      if (_hint != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_hint!,
              key: const Key('scanHint'),
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      const SizedBox(height: 8),
      TextButton.icon(
        key: const Key('manualToggle'),
        onPressed: () => setState(() => _manual = !_manual),
        icon: Icon(_manual ? Icons.expand_less : Icons.keyboard),
        label: const Text('Enter name and password'),
      ),
      if (_manual) ...[
        TextField(
          key: const Key('manualSsid'),
          controller: _ssid,
          decoration: const InputDecoration(labelText: 'Network name'),
        ),
        TextField(
          key: const Key('manualPassword'),
          controller: _password,
          obscureText: false,
          decoration: const InputDecoration(
              labelText: 'Password (empty for an open network)'),
        ),
        CheckboxListTile(
          key: const Key('manualHidden'),
          contentPadding: EdgeInsets.zero,
          value: _hidden,
          onChanged: (v) => setState(() => _hidden = v ?? false),
          title: const Text('Hidden network'),
        ),
        FilledButton(
          key: const Key('manualContinue'),
          onPressed: _submitManual,
          child: const Text('Continue'),
        ),
      ],
    ];
  }

  List<Widget> _confirm(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = _creds!;
    return [
      Text('Join ${c.ssid}?',
          key: const Key('joinConfirmTitle'), style: t.titleLarge),
      const SizedBox(height: 8),
      Text(
          'LanDrop will ask Android to join this Wi-Fi network. Android will '
          'ask you to confirm. While joined, this phone may lose its '
          'internet connection. Only LanDrop uses this network; other apps '
          'keep using your normal connection where Android allows it.',
          key: const Key('joinExplain'),
          style: t.bodyMedium),
      const SizedBox(height: 16),
      FilledButton.icon(
        key: const Key('joinButton'),
        onPressed: _join,
        icon: const Icon(Icons.wifi),
        label: const Text('Join'),
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        key: const Key('cancelJoin'),
        onPressed: () => setState(() => _stage = _Stage.scan),
        child: const Text('Cancel'),
      ),
    ];
  }

  List<Widget> _joining(BuildContext context) => [
        const SizedBox(height: 24),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 16),
        Text(
            'Joining ${_creds?.ssid ?? ''}… Confirm the Android prompt when '
            'it appears.',
            key: const Key('joining'),
            textAlign: TextAlign.center),
      ];

  List<Widget> _errorView(BuildContext context) => [
        Text(_error ?? '',
            key: const Key('joinError'),
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('joinRetry'),
          onPressed: _join,
          child: const Text('Try again'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('joinBack'),
          onPressed: () => setState(() => _stage = _Stage.scan),
          child: const Text('Scan again'),
        ),
      ];

  List<Widget> _done(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final gw = _joined?.gateway;
    return [
      Text('Joined ${_joined?.ssid.isNotEmpty == true ? _joined!.ssid : _creds?.ssid ?? ''}',
          key: const Key('joinedTitle'), style: t.titleLarge),
      if (_banner != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_banner!,
              key: const Key('joinLost'),
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      const SectionHeader('Find the other device'),
      FindDevicePanel(
        label: 'Find the other device',
        autoStart: true,
        localAddresses: widget.localAddresses,
        extraGateways: [?gw],
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        key: const Key('leaveNetwork'),
        onPressed: _leave,
        icon: const Icon(Icons.wifi_off),
        label: const Text('Leave network'),
      ),
    ];
  }
}

/// Opens the page.
Future<void> openWifiJoin(BuildContext context) => Navigator.push(
    context, MaterialPageRoute(builder: (_) => const WifiJoinPage()));

/// Whether the QR join entry points are shown: Android only.
bool wifiJoinAvailable([bool? android]) => android ?? Platform.isAndroid;
