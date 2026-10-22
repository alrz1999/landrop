import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api.dart';
import 'l10n.dart';
import 'ltr_text.dart';
import 'widgets.dart';
import 'wifi_direct_service.dart';

/// The usual Wi-Fi Direct group owner address on Android.
const wifiDirectOwnerAddress = '192.168.49.1';

/// Addresses to probe once a group is formed: the owner when we joined, the
/// first few client leases when we are the owner.
List<String> wifiDirectProbeTargets(WifiDirectState s) {
  if (s.isOwner) {
    return [for (var i = 2; i <= 10; i++) '192.168.49.$i'];
  }
  return {wifiDirectOwnerAddress, if (s.ownerAddress != null) s.ownerAddress!}
      .toList();
}

/// Android only: forms a Wi-Fi Direct group with a nearby device, then runs
/// the normal LanDrop discovery over it (DESIGN.md 3.5).
class WifiDirectPage extends StatefulWidget {
  const WifiDirectPage({super.key, this.service});

  /// Test seam; the default is the real channel-backed service.
  final WifiDirectApi? service;

  @override
  State<WifiDirectPage> createState() => _WifiDirectPageState();
}

class _WifiDirectPageState extends State<WifiDirectPage> {
  late final WifiDirectApi _service = widget.service ?? WifiDirectService();
  final _subs = <StreamSubscription<dynamic>>[];
  List<WifiDirectPeer> _peers = const [];
  WifiDirectState _state = WifiDirectState.disconnected;

  /// The last error; shown in the current language.
  WifiDirectException? _error;
  bool _busy = false;
  bool _searching = false;
  List<DeviceInfo>? _found;

  @override
  void initState() {
    super.initState();
    _subs.add(_service.peers.listen((p) {
      if (mounted) setState(() => _peers = p);
    }));
    _subs.add(_service.states.listen(_onState));
    _subs.add(_service.errors.listen((e) {
      if (mounted) setState(() => _error = e);
    }));
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    // The group stays up so files can be sent; only discovery stops.
    unawaited(_service.stopDiscover());
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() body) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await body();
    } on WifiDirectException catch (e) {
      if (mounted) setState(() => _error = e);
    } catch (e) {
      if (mounted) setState(() => _error = wifiDirectError('error', '$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() => _guard(() async {
        await _service.checkAvailable();
        final s = await _service.info();
        if (s.connected) _onState(s);
        if (!s.connected) await _service.discover();
      });

  Future<void> _onState(WifiDirectState s) async {
    if (!mounted) return;
    final was = _state.connected;
    setState(() {
      _state = s;
      if (s.connected) _error = null;
    });
    if (s.connected && !was) await _findDevices(s);
  }

  Future<void> _findDevices(WifiDirectState s) async {
    final c = AppScope.read(context);
    setState(() {
      _searching = true;
      _found = null;
    });
    final byFp = <String, DeviceInfo>{};
    try {
      await c.restartDiscovery();
      for (final d in await c.probeAddresses(wifiDirectProbeTargets(s))) {
        byFp[d.fingerprint] = d;
      }
      for (final d in c.peers) {
        byFp.putIfAbsent(d.fingerprint, () => d);
      }
    } catch (_) {
      // The list simply stays empty; the hint below explains what to do.
    }
    if (!mounted) return;
    setState(() {
      _found = byFp.values.toList();
      _searching = false;
    });
  }

  Widget _errorCard() => Card(
        key: const Key('wifiDirectError'),
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_error!.localized(context.l)),
              const SizedBox(height: 8),
              Text(context.l.wifiDirectTry),
            ],
          ),
        ),
      );

  /// A peer's status in plain words ("Invitation sent…", "available").
  String _status(AppLocalizations l, String status) => switch (status) {
        'invited' => l.wifiDirectInvited,
        'connected' => l.wifiDirectStatusConnected,
        'failed' => l.wifiDirectStatusFailed,
        'available' => l.wifiDirectStatusAvailable,
        'unavailable' => l.wifiDirectStatusUnavailable,
        _ => status,
      };

  Widget _connectedCard() {
    final l = context.l;
    final role =
        _state.isOwner ? l.wifiDirectRoleOwner : l.wifiDirectRoleClient;
    final found = _found;
    return Card(
      key: const Key('wifiDirectConnected'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsetsDirectional.zero,
              leading: const Icon(Icons.wifi_tethering),
              title: Text(l.wifiDirectConnected),
            ),
            Text(role),
            if (_state.ssid != null)
              Text(l.wifiDirectNetwork(l.ltrValue(_state.ssid!)),
                  key: const Key('wifiDirectSsid')),
            if (_state.ownerAddress != null)
              Text(l.wifiDirectHost(l.ltrValue(_state.ownerAddress!)),
                  key: const Key('wifiDirectHost')),
            const SizedBox(height: 12),
            if (_searching)
              Row(children: [
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Expanded(child: Text(l.wifiDirectLooking)),
              ])
            else if (found != null && found.isEmpty)
              Text(l.wifiDirectNone, key: const Key('wifiDirectNone'))
            else if (found != null)
              for (final d in found)
                ListTile(
                  key: Key('wifiDirectDevice_${d.fingerprint}'),
                  contentPadding: EdgeInsetsDirectional.zero,
                  leading: const Icon(Icons.devices),
                  title: AutoDirText(d.alias),
                  subtitle: LtrText(d.ip),
                ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              OutlinedButton(
                  key: const Key('wifiDirectSearch'),
                  onPressed: _searching ? null : () => _findDevices(_state),
                  child: Text(l.wifiDirectSearchAgain)),
              FilledButton.tonal(
                  key: const Key('wifiDirectDisconnect'),
                  onPressed: () => _guard(() async {
                        await _service.disconnect();
                        if (mounted) {
                          setState(() {
                            _state = WifiDirectState.disconnected;
                            _found = null;
                            _peers = const [];
                          });
                        }
                      }),
                  child: Text(l.wifiDirectDisconnect)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _peerList() {
    final l = context.l;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.homeNearbyDevices,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(l.wifiDirectTapHint),
        const SizedBox(height: 8),
        if (_peers.isEmpty)
          Text(_busy ? l.wifiDirectLookingShort : l.wifiDirectEmpty,
              key: const Key('wifiDirectEmpty'))
        else
          for (final p in _peers)
            ListTile(
              key: Key('wifiDirectPeer_${p.address}'),
              leading: const Icon(Icons.smartphone),
              title: AutoDirText(p.name),
              subtitle: Text(_status(l, p.status)),
              onTap: p.status == 'connected'
                  ? null
                  : () => _guard(() => _service.connect(p.address)),
            ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          OutlinedButton(
              key: const Key('wifiDirectRescan'),
              onPressed: _busy ? null : _start,
              child: Text(l.wifiDirectSearchAgain)),
          OutlinedButton(
              key: const Key('wifiDirectCreateGroup'),
              onPressed: _busy ? null : () => _guard(_service.createGroup),
              child: Text(l.wifiDirectCreateGroup)),
        ]),
        const SizedBox(height: 8),
        Text(l.wifiDirectCreateHint),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Scaffold(
      appBar: AppBar(title: Text(l.wifiDirectTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            key: const Key('wifiDirectPage'),
            padding: const EdgeInsets.all(16),
            children: [
              Text(l.wifiDirectIntro),
              const SizedBox(height: 12),
              if (_error != null) ...[_errorCard(), const SizedBox(height: 12)],
              if (_state.connected) _connectedCard() else _peerList(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the Wi-Fi Direct page.
Future<void> openWifiDirect(BuildContext context) => Navigator.push(
    context, MaterialPageRoute(builder: (_) => const WifiDirectPage()));
