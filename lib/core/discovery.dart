// Pluggable discovery transport. The default implementation uses UDP
// multicast (224.0.0.167:53317); tests can inject an in-memory transport.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

  @override
  Future<void> broadcast(Map<String, dynamic> message) async {
    final s = _socket;
    if (s == null) return;
    try {
      s.send(utf8.encode(jsonEncode(message)), group, port);
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
