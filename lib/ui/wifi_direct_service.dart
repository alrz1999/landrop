import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'hotspot_service.dart';
import 'l10n.dart';

/// A device found by Wi-Fi Direct discovery.
class WifiDirectPeer {
  final String name;
  final String address;

  /// connected, invited, failed, available or unavailable.
  final String status;
  const WifiDirectPeer(this.name, this.address, this.status);

  bool get busy => status == 'connected' || status == 'invited';

  @override
  bool operator ==(Object other) =>
      other is WifiDirectPeer &&
      other.name == name &&
      other.address == address &&
      other.status == status;
  @override
  int get hashCode => Object.hash(name, address, status);
}

/// Connection state of the Wi-Fi Direct group.
class WifiDirectState {
  final bool connected;
  final bool isOwner;

  /// IP address of the group owner (usually 192.168.49.1).
  final String? ownerAddress;
  final String? ssid;
  const WifiDirectState(
      {this.connected = false,
      this.isOwner = false,
      this.ownerAddress,
      this.ssid});
  static const disconnected = WifiDirectState();
}

class WifiDirectException implements Exception {
  /// unsupported, permission, busy, error, no-service-requests, wifi-off.
  final String code;

  /// English text (logs, tests); the UI shows [localized].
  final String message;

  /// Technical detail inserted into the text, if any (English).
  final String? detail;
  const WifiDirectException(this.code, this.message, {this.detail});

  /// [message] in the language of [l]. A raw technical error (the message is
  /// the detail itself) stays as it is.
  String localized(AppLocalizations l) => detail != null && message == detail
      ? message
      : wifiDirectMessage(code, detail, l);

  @override
  String toString() => message;
}

/// What the page needs; the page tests use a fake.
abstract class WifiDirectApi {
  bool get supported;
  Stream<List<WifiDirectPeer>> get peers;
  Stream<WifiDirectState> get states;
  Stream<WifiDirectException> get errors;

  /// Throws [WifiDirectException] (`unsupported`, `wifi-off`) when it cannot work.
  Future<void> checkAvailable();
  Future<void> discover();
  Future<void> stopDiscover();
  Future<void> connect(String address, {int? groupOwnerIntent});
  Future<void> createGroup();
  Future<void> disconnect();
  Future<WifiDirectState> info();
  void dispose();
}

/// Readable text and what to try, per error code; English when [l] is null.
String wifiDirectMessage(String code,
    [String? detail, AppLocalizations? l]) {
  l ??= englishStrings;
  return switch (code) {
    'unsupported' => l.errWifiDirectUnsupported,
    'wifi-off' => l.errWifiDirectWifiOff,
    'permission' => l.errWifiDirectPermission,
    'busy' => l.errWifiDirectBusy,
    'no-service-requests' => l.errWifiDirectNotReady,
    _ => detail == null
        ? l.errWifiDirectFailed
        : l.errWifiDirectFailedDetail(detail),
  };
}

/// A [WifiDirectException] with the English text for [code].
WifiDirectException wifiDirectError(String code, [String? detail]) =>
    WifiDirectException(code, wifiDirectMessage(code, detail),
        detail: detail);

/// Wi-Fi Direct assist through the `dev.landrop/wifidirect` channel and the
/// `dev.landrop/wifidirect/events` event channel (WifiDirectManager.kt). It
/// only forms the group; LanDrop then talks over the new IP link.
class WifiDirectService implements WifiDirectApi {
  WifiDirectService({
    MethodChannel? channel,
    Stream<dynamic>? events,
    HotspotPermissionRequest? requestPermission,
    bool? android,
  })  : _channel = channel ?? const MethodChannel(channelName),
        _request = requestPermission ?? requestWifiPermission,
        supported = android ?? Platform.isAndroid {
    if (supported) {
      final s = events ?? const EventChannel(eventsName).receiveBroadcastStream();
      _sub = s.listen(handleEvent, onError: (Object e) {
        _errors.add(WifiDirectException('error', '$e', detail: '$e'));
      });
    }
  }

  static const channelName = 'dev.landrop/wifidirect';
  static const eventsName = 'dev.landrop/wifidirect/events';
  final MethodChannel _channel;
  final HotspotPermissionRequest _request;
  StreamSubscription<dynamic>? _sub;

  @override
  final bool supported;

  final _peers = StreamController<List<WifiDirectPeer>>.broadcast();
  final _states = StreamController<WifiDirectState>.broadcast();
  final _errors = StreamController<WifiDirectException>.broadcast();

  @override
  Stream<List<WifiDirectPeer>> get peers => _peers.stream;
  @override
  Stream<WifiDirectState> get states => _states.stream;
  @override
  Stream<WifiDirectException> get errors => _errors.stream;

  /// Parses one native event (`peers`, `state` or `error`); ignores others.
  void handleEvent(dynamic e) {
    if (e is! Map) return;
    switch (e['type']) {
      case 'peers':
        final raw = e['peers'];
        _peers.add([
          if (raw is List)
            for (final p in raw)
              if (p is Map && p['address'] is String)
                WifiDirectPeer(
                    p['name'] is String && (p['name'] as String).isNotEmpty
                        ? p['name'] as String
                        : p['address'] as String,
                    p['address'] as String,
                    p['status'] is String ? p['status'] as String : 'available')
        ]);
      case 'state':
        _states.add(_parseState(e));
      case 'error':
        final code = e['code'] is String ? e['code'] as String : 'error';
        _errors.add(wifiDirectError(
            code, e['message'] is String ? e['message'] as String : null));
    }
  }

  static WifiDirectState _parseState(Map e) {
    final owner = e['ownerAddress'];
    final ssid = e['ssid'];
    return WifiDirectState(
      connected: e['connected'] == true,
      isOwner: e['isOwner'] == true,
      ownerAddress: owner is String && owner.isNotEmpty ? owner : null,
      ssid: ssid is String && ssid.isNotEmpty ? ssid : null,
    );
  }

  Future<T?> _call<T>(String method, [Object? args]) async {
    if (!supported) {
      throw wifiDirectError('unsupported');
    }
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw wifiDirectError(e.code, e.message);
    } on MissingPluginException {
      throw wifiDirectError('unsupported');
    }
  }

  Future<void> _permission() async {
    final sdk = await _call<int>('sdkInt') ?? 0;
    if (!await _request(hotspotPermissionFor(sdk))) {
      throw wifiDirectError('permission');
    }
  }

  @override
  Future<void> checkAvailable() async {
    final r = await _call<dynamic>('supported');
    if (r is bool) {
      if (!r) throw wifiDirectError('unsupported');
      return;
    }
    if (r is Map) {
      if (r['feature'] == false) {
        throw wifiDirectError('unsupported');
      }
      if (r['wifiEnabled'] == false) {
        throw wifiDirectError('wifi-off');
      }
    }
  }

  @override
  Future<void> discover() async {
    await _permission();
    await _call<bool>('discover');
  }

  @override
  Future<void> stopDiscover() async {
    if (!supported) return;
    try {
      await _call<bool>('stopDiscover');
    } on WifiDirectException {
      // Nothing to stop.
    }
  }

  @override
  Future<void> connect(String address, {int? groupOwnerIntent}) async {
    await _permission();
    await _call<bool>('connect', {
      'address': address,
      'groupOwnerIntent': ?groupOwnerIntent,
    });
  }

  @override
  Future<void> createGroup() async {
    await _permission();
    await _call<bool>('createGroup');
  }

  @override
  Future<void> disconnect() async {
    if (!supported) return;
    try {
      await _call<bool>('disconnect');
    } on WifiDirectException {
      // Already gone.
    }
  }

  @override
  Future<WifiDirectState> info() async {
    final m = await _call<Map<dynamic, dynamic>>('info');
    return m == null ? WifiDirectState.disconnected : _parseState(m);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _peers.close();
    _states.close();
    _errors.close();
  }
}
