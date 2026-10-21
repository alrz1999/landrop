// Pluggable discovery transport. The default implementation uses UDP
// multicast (224.0.0.167:53317); tests can inject an in-memory transport.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'util.dart';

typedef DiscoveryMessageHandler = void Function(
    Map<String, dynamic> message, InternetAddress from);

abstract class DiscoveryTransport {
  /// Begin receiving messages; [onMessage] is called for every datagram
  /// (including possibly our own, which the core filters by fingerprint).
  Future<void> start(DiscoveryMessageHandler onMessage);

  /// Send [message] to every listener on the LAN.
  Future<void> broadcast(Map<String, dynamic> message);

  Future<void> close();
}

class MulticastDiscoveryTransport implements DiscoveryTransport {
  final InternetAddress group;
  final int port;
  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _sub;

  MulticastDiscoveryTransport({InternetAddress? group, this.port = 53317})
      : group = group ?? InternetAddress('224.0.0.167');

  @override
  Future<void> start(DiscoveryMessageHandler onMessage) async {
    final reusePort = Platform.isMacOS ||
        Platform.isIOS ||
        Platform.isLinux ||
        Platform.isAndroid;
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port,
        reuseAddress: true, reusePort: reusePort);
    socket.multicastLoopback = true; // lets two instances on one host meet
    var joined = false;
    try {
      final ifaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLoopback: false);
      for (final iface in ifaces) {
        if (isVpnInterface(iface.name)) continue;
        try {
          socket.joinMulticast(group, iface);
          joined = true;
        } catch (_) {}
      }
    } catch (_) {}
    if (!joined) {
      try {
        socket.joinMulticast(group);
      } catch (_) {}
    }
    _socket = socket;
    _sub = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = socket.receive();
      if (dg == null) return;
      try {
        final decoded = jsonDecode(utf8.decode(dg.data));
        if (decoded is Map<String, dynamic>) onMessage(decoded, dg.address);
      } catch (_) {
        // ignore malformed datagrams
      }
    });
  }

  // IP_MULTICAST_IF: Linux/Android 32, macOS/iOS/Windows 9.
  int get _multicastIfOption =>
      (Platform.isLinux || Platform.isAndroid) ? 32 : 9;

  /// Announce on every real network interface, via multicast and via UDP
  /// broadcast (many routers pass broadcast when they drop multicast).
  @override
  Future<void> broadcast(Map<String, dynamic> message) async {
    final s = _socket;
    if (s == null) return;
    final data = utf8.encode(jsonEncode(message));
    try {
      s.broadcastEnabled = true;
    } catch (_) {}
    var sentOnIface = false;
    try {
      final ifaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLoopback: false);
      for (final iface in ifaces) {
        if (isVpnInterface(iface.name)) continue;
        for (final a in iface.addresses) {
          final r = a.rawAddress;
          if (r.length != 4 || (r[0] == 169 && r[1] == 254)) continue;
          try {
            s.setRawOption(RawSocketOption(RawSocketOption.levelIPv4,
                _multicastIfOption, Uint8List.fromList(r)));
            s.send(data, group, port);
            sentOnIface = true;
          } catch (_) {}
          try {
            // Assumes a /24, which is what home networks use.
            s.send(data, InternetAddress('${r[0]}.${r[1]}.${r[2]}.255'), port);
          } catch (_) {}
        }
      }
    } catch (_) {}
    if (!sentOnIface) {
      try {
        s.send(data, group, port);
      } catch (_) {}
    }
    try {
      s.send(data, InternetAddress('255.255.255.255'), port);
    } catch (_) {}
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    _sub = null;
    _socket?.close();
    _socket = null;
  }
}
