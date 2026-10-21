// In-memory "LAN" for mDNS tests (not a test file itself).
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:landrop/core/mdns.dart';

class MdnsHub {
  final List<MemoryMdnsSocket> members = [];
}

class MemoryMdnsSocket implements MdnsSocket {
  final MdnsHub hub;
  final InternetAddress address;
  final bool failStart;
  MdnsPacketHandler? _h;
  MemoryMdnsSocket(this.hub, {String ip = '127.0.0.1', this.failStart = false})
      : address = InternetAddress(ip);

  @override
  Future<void> start(MdnsPacketHandler onPacket) async {
    if (failStart) throw const SocketException('address in use');
    _h = onPacket;
    hub.members.add(this);
  }

  @override
  Future<void> send(Uint8List data) async {
    for (final m in List.of(hub.members)) {
      scheduleMicrotask(() => m._h?.call(Uint8List.fromList(data), address));
    }
  }

  /// Inject raw bytes as if received from [from].
  void inject(List<int> data, {String from = '10.0.0.9'}) =>
      _h?.call(Uint8List.fromList(data), InternetAddress(from));

  @override
  Future<void> close() async {
    hub.members.remove(this);
    _h = null;
  }
}
