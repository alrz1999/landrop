// mDNS / Bonjour (`_landrop._tcp`) as a second discovery channel
// (DESIGN.md 2.4a). Pure Dart: a minimal DNS codec, a responder that
// advertises this device, and a browser that collects other devices.
//
// Everything received is untrusted. It is only a hint: the core still
// verifies the fingerprint over HTTPS /info before a peer is added.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'util.dart';

const mdnsServiceName = '_landrop._tcp.local';
const mdnsMetaName = '_services._dns-sd._udp.local';
const mdnsPort = 5353;
final InternetAddress mdnsGroup = InternetAddress('224.0.0.251');

const dnsTypeA = 1;
const dnsTypePtr = 12;
const dnsTypeTxt = 16;
const dnsTypeSrv = 33;
const dnsTypeAny = 255;

// ------------------------------------------------------------------ codec

class DnsQuestion {
  final String name;
  final int type;
  const DnsQuestion(this.name, this.type);
}

class DnsRecord {
  final String name;
  final int type;
  final int ttl;

  /// PTR target or SRV host.
  final String? target;

  /// SRV port.
  final int port;

  /// TXT strings (`key=value`).
  final List<String> txt;

  /// A record address, dotted.
  final String? ip;

  const DnsRecord(this.name, this.type,
      {this.ttl = 120,
      this.target,
      this.port = 0,
      this.txt = const [],
      this.ip});

  DnsRecord.ptr(String name, String target, {int ttl = 120})
      : this(name, dnsTypePtr, ttl: ttl, target: target);
  DnsRecord.srv(String name, String host, int port, {int ttl = 120})
      : this(name, dnsTypeSrv, ttl: ttl, target: host, port: port);
  DnsRecord.txtRecord(String name, List<String> txt, {int ttl = 120})
      : this(name, dnsTypeTxt, ttl: ttl, txt: txt);
  DnsRecord.a(String name, String ip, {int ttl = 120})
      : this(name, dnsTypeA, ttl: ttl, ip: ip);
}

class DnsMessage {
  final int id;
  final int flags;
  final List<DnsQuestion> questions;

  /// Answer, authority and additional records, flattened.
  final List<DnsRecord> records;
  const DnsMessage(
      {this.id = 0,
      this.flags = 0,
      this.questions = const [],
      this.records = const []});

  bool get isResponse => flags & 0x8000 != 0;
}

const _maxRecords = 64; // per message, all sections together
const _maxQuestions = 16;

void _w16(BytesBuilder b, int v) =>
    b.add([(v >> 8) & 0xff, v & 0xff]);
void _w32(BytesBuilder b, int v) =>
    b.add([(v >> 24) & 0xff, (v >> 16) & 0xff, (v >> 8) & 0xff, v & 0xff]);

void _writeName(BytesBuilder b, String name) {
  var total = 1;
  for (final label in name.split('.')) {
    if (label.isEmpty) continue;
    final bytes = utf8.encode(label);
    if (bytes.length > 63) throw ArgumentError('DNS label too long');
    total += bytes.length + 1;
    if (total > 255) throw ArgumentError('DNS name too long');
    b.addByte(bytes.length);
    b.add(bytes);
  }
  b.addByte(0);
}

/// Encodes without name compression. Throws [ArgumentError] only for
/// oversized data we produced ourselves.
Uint8List encodeDnsMessage(DnsMessage m) {
  final b = BytesBuilder();
  _w16(b, m.id);
  _w16(b, m.flags);
  _w16(b, m.questions.length);
  _w16(b, m.isResponse ? m.records.length : 0);
  _w16(b, 0);
  _w16(b, m.isResponse ? 0 : m.records.length);
  for (final q in m.questions) {
    _writeName(b, q.name);
    _w16(b, q.type);
    _w16(b, 1);
  }
  for (final r in m.records) {
    _writeName(b, r.name);
    _w16(b, r.type);
    // Cache-flush bit on unique records (not PTR).
    _w16(b, r.type == dnsTypePtr ? 1 : 0x8001);
    _w32(b, r.ttl);
    final d = BytesBuilder();
    switch (r.type) {
      case dnsTypePtr:
        _writeName(d, r.target ?? '');
      case dnsTypeSrv:
        _w16(d, 0);
        _w16(d, 0);
        _w16(d, r.port);
        _writeName(d, r.target ?? '');
      case dnsTypeTxt:
        if (r.txt.isEmpty) d.addByte(0);
        for (final s in r.txt) {
          final bytes = utf8.encode(s);
          if (bytes.length > 255) throw ArgumentError('TXT string too long');
          d.addByte(bytes.length);
          d.add(bytes);
        }
      case dnsTypeA:
        final p = (r.ip ?? '').split('.').map(int.tryParse).toList();
        if (p.length != 4 || p.any((x) => x == null || x < 0 || x > 255)) {
          throw ArgumentError('bad IPv4');
        }
        d.add(p.cast<int>());
      default:
        throw ArgumentError('unsupported record type');
    }
    final bytes = d.toBytes();
    _w16(b, bytes.length);
    b.add(bytes);
  }
  return b.toBytes();
}

class _Bad implements Exception {
  const _Bad();
}

(String, int) _readName(Uint8List d, int off) {
  final labels = <String>[];
  var pos = off;
  int? end;
  var hops = 0;
  var total = 0;
  while (true) {
    if (pos < 0 || pos >= d.length) throw const _Bad();
    final len = d[pos];
    if (len == 0) {
      end ??= pos + 1;
      break;
    }
    if (len & 0xC0 == 0xC0) {
      if (pos + 1 >= d.length) throw const _Bad();
      end ??= pos + 2;
      if (++hops > 16) throw const _Bad(); // pointer loop protection
      pos = ((len & 0x3f) << 8) | d[pos + 1];
      continue;
    }
    if (len & 0xC0 != 0) throw const _Bad();
    if (pos + 1 + len > d.length) throw const _Bad();
    total += len + 1;
    if (total > 255) throw const _Bad();
    labels.add(utf8.decode(d.sublist(pos + 1, pos + 1 + len),
        allowMalformed: true));
    pos += 1 + len;
  }
  return (labels.join('.'), end);
}

/// Decodes [d]; null for anything malformed. Never throws.
DnsMessage? decodeDnsMessage(Uint8List d) {
  try {
    if (d.length < 12 || d.length > 9000) return null;
    int u16(int o) => (d[o] << 8) | d[o + 1];
    final id = u16(0);
    final flags = u16(2);
    final qd = u16(4);
    final an = u16(6) + u16(8) + u16(10);
    if (qd > _maxQuestions || an > _maxRecords) return null;
    var pos = 12;
    final qs = <DnsQuestion>[];
    for (var i = 0; i < qd; i++) {
      final (name, next) = _readName(d, pos);
      if (next + 4 > d.length) return null;
      qs.add(DnsQuestion(name, u16(next)));
      pos = next + 4;
    }
    final rs = <DnsRecord>[];
    for (var i = 0; i < an; i++) {
      final (name, next) = _readName(d, pos);
      if (next + 10 > d.length) return null;
      final type = u16(next);
      final ttl = (u16(next + 4) << 16) | u16(next + 6);
      final len = u16(next + 8);
      final rd = next + 10;
      if (rd + len > d.length) return null;
      pos = rd + len;
      switch (type) {
        case dnsTypePtr:
          rs.add(DnsRecord.ptr(name, _readName(d, rd).$1, ttl: ttl));
        case dnsTypeSrv:
          if (len < 7) return null;
          rs.add(DnsRecord.srv(name, _readName(d, rd + 6).$1, u16(rd + 4),
              ttl: ttl));
        case dnsTypeTxt:
          final strs = <String>[];
          var p = rd;
          while (p < rd + len) {
            final l = d[p];
            if (p + 1 + l > rd + len) return null;
            if (l > 0) {
              strs.add(utf8.decode(d.sublist(p + 1, p + 1 + l),
                  allowMalformed: true));
            }
            p += 1 + l;
          }
          rs.add(DnsRecord.txtRecord(name, strs, ttl: ttl));
        case dnsTypeA:
          if (len != 4) return null;
          rs.add(DnsRecord.a(
              name, '${d[rd]}.${d[rd + 1]}.${d[rd + 2]}.${d[rd + 3]}',
              ttl: ttl));
        default:
          break; // ignored
      }
    }
    return DnsMessage(id: id, flags: flags, questions: qs, records: rs);
  } catch (_) {
    return null;
  }
}

// ------------------------------------------------------------------ socket seam

typedef MdnsPacketHandler = void Function(Uint8List data, InternetAddress from);

/// Sends to and receives from the mDNS multicast group.
abstract class MdnsSocket {
  Future<void> start(MdnsPacketHandler onPacket);
  Future<void> send(Uint8List data);
  Future<void> close();
}

class RawMdnsSocket implements MdnsSocket {
  final int port;
  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _sub;
  RawMdnsSocket({this.port = mdnsPort});

  @override
  Future<void> start(MdnsPacketHandler onPacket) async {
    final reusePort = Platform.isMacOS ||
        Platform.isIOS ||
        Platform.isLinux ||
        Platform.isAndroid;
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port,
        reuseAddress: true, reusePort: reusePort);
    socket.multicastLoopback = true;
    var joined = false;
    try {
      for (final iface in await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLoopback: false)) {
        if (!isRealInterface(iface.name)) continue;
        try {
          socket.joinMulticast(mdnsGroup, iface);
          joined = true;
        } catch (_) {}
      }
    } catch (_) {}
    if (!joined) {
      try {
        socket.joinMulticast(mdnsGroup);
      } catch (_) {}
    }
    _socket = socket;
    _sub = socket.listen((e) {
      if (e != RawSocketEvent.read) return;
      try {
        final dg = socket.receive();
        if (dg != null) onPacket(dg.data, dg.address);
      } catch (_) {}
    }, onError: (_) {});
  }

  int get _multicastIfOption =>
      (Platform.isLinux || Platform.isAndroid) ? 32 : 9;

  @override
  Future<void> send(Uint8List data) async {
    final s = _socket;
    if (s == null) return;
    var sent = false;
    try {
      for (final a in await localIPv4Addresses()) {
        try {
          s.setRawOption(RawSocketOption(RawSocketOption.levelIPv4,
              _multicastIfOption, Uint8List.fromList(a.rawAddress)));
          s.send(data, mdnsGroup, port);
          sent = true;
        } catch (_) {}
      }
    } catch (_) {}
    if (!sent) {
      try {
        s.send(data, mdnsGroup, port);
      } catch (_) {}
    }
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    _sub = null;
    _socket?.close();
    _socket = null;
  }
}

// ------------------------------------------------------------------ service

class MdnsCandidate {
  final String instance;
  final String fingerprint;
  final String alias;
  final String deviceType;
  final int port;
  final List<String> addresses;
  const MdnsCandidate(this.instance, this.fingerprint, this.alias,
      this.deviceType, this.port, this.addresses);
}

final _fpRe = RegExp(r'^[0-9a-f]{64}$');

bool _validAddr(String ip, bool allowLoopback) {
  final p = ip.split('.').map(int.tryParse).toList();
  if (p.length != 4 || p.any((x) => x == null || x < 0 || x > 255)) {
    return false;
  }
  final a = p[0]!, b = p[1]!;
  if (allowLoopback && a == 127) return true;
  return a == 10 ||
      (a == 172 && b >= 16 && b <= 31) ||
      (a == 192 && b == 168) ||
      (a == 169 && b == 254);
}

String _cleanText(String s, int max) {
  final t = s.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '');
  return t.length > max ? t.substring(0, max) : t;
}

class _Inst {
  String? host;
  int? srvPort;
  Map<String, String>? txt;
}

class MdnsService {
  final MdnsSocket socket;
  final String fingerprint;
  final String alias;
  final String deviceType;
  final int port;

  /// This device's IPv4 addresses to advertise (A records).
  final Future<List<String>> Function() addresses;
  final Duration queryInterval;
  final Duration announceInterval;
  final int ttl;

  /// Test seam: accept 127.x.x.x addresses from peers.
  final bool allowLoopback;

  MdnsService({
    required this.socket,
    required this.fingerprint,
    required this.alias,
    required this.deviceType,
    required this.port,
    required this.addresses,
    this.queryInterval = const Duration(seconds: 15),
    this.announceInterval = const Duration(seconds: 60),
    this.ttl = 120,
    this.allowLoopback = false,
  });

  /// Why the socket could not start (null when it runs).
  String? error;
  bool started = false;

  final _foundCtrl = StreamController<MdnsCandidate>.broadcast();
  Stream<MdnsCandidate> get onFound => _foundCtrl.stream;
  final _goneCtrl = StreamController<String>.broadcast();

  /// Fingerprints that said goodbye.
  Stream<String> get onGone => _goneCtrl.stream;

  final Map<String, MdnsCandidate> _candidates = {};
  Map<String, MdnsCandidate> get candidates => Map.unmodifiable(
      {for (final c in _candidates.values) c.fingerprint: c});

  final Map<String, _Inst> _insts = {};
  final Map<String, Set<String>> _hosts = {};
  Timer? _queryTimer;
  Timer? _announceTimer;
  DateTime _lastReply = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastMetaReply = DateTime.fromMillisecondsSinceEpoch(0);

  String get instanceLabel => 'LanDrop-${fingerprint.substring(0, 8)}';
  String get instanceName => '$instanceLabel.$mdnsServiceName';
  String get hostName => '$instanceLabel.local';

  Future<void> start() async {
    error = null;
    try {
      await socket.start(_onPacket);
    } catch (e) {
      started = false;
      error = e is SocketException
          ? (e.osError?.message.isNotEmpty == true
              ? '${e.message}: ${e.osError!.message}'
              : e.message)
          : '$e';
      try {
        await socket.close();
      } catch (_) {}
      return;
    }
    started = true;
    unawaited(_announce(ttl));
    query();
    _queryTimer = Timer.periodic(queryInterval, (_) => query());
    _announceTimer =
        Timer.periodic(announceInterval, (_) => _announce(ttl));
  }

  Future<void> stop() async {
    _queryTimer?.cancel();
    _announceTimer?.cancel();
    _queryTimer = _announceTimer = null;
    if (started) {
      started = false;
      try {
        await _announce(0); // goodbye
      } catch (_) {}
    }
    try {
      await socket.close();
    } catch (_) {}
    await _foundCtrl.close();
    await _goneCtrl.close();
  }

  /// Ask the network for `_landrop._tcp` instances now.
  void query() {
    if (!started) return;
    try {
      socket.send(encodeDnsMessage(const DnsMessage(
          questions: [DnsQuestion(mdnsServiceName, dnsTypePtr)])));
    } catch (_) {}
  }

  List<String> _txtStrings() => [
        'fp=$fingerprint',
        'v=1',
        'alias=${_truncUtf8(alias, 100)}',
        'type=${_truncUtf8(deviceType, 16)}',
        'port=$port',
      ];

  static String _truncUtf8(String s, int maxBytes) {
    var out = s;
    while (utf8.encode(out).length > maxBytes) {
      out = out.substring(0, out.length - 1);
    }
    return out;
  }

  Future<DnsMessage> _selfMessage(int ttl) async {
    final addrs = <String>[];
    try {
      addrs.addAll((await addresses()).take(8));
    } catch (_) {}
    return DnsMessage(flags: 0x8400, records: [
      DnsRecord.ptr(mdnsServiceName, instanceName, ttl: ttl),
      DnsRecord.srv(instanceName, hostName, port, ttl: ttl),
      DnsRecord.txtRecord(instanceName, _txtStrings(), ttl: ttl),
      for (final a in addrs) DnsRecord.a(hostName, a, ttl: ttl),
    ]);
  }

  Future<void> _announce(int ttl) async {
    if (!started && ttl != 0) return;
    try {
      await socket.send(encodeDnsMessage(await _selfMessage(ttl)));
    } catch (_) {}
  }

  // -- receive

  void _onPacket(Uint8List data, InternetAddress from) {
    try {
      final m = decodeDnsMessage(data);
      if (m == null) return;
      if (m.isResponse) {
        _onResponse(m, from);
      } else {
        _onQuery(m);
      }
    } catch (_) {
      // never throw out of the socket handler
    }
  }

  void _onQuery(DnsMessage m) {
    if (!started) return;
    final wanted = m.questions.any((q) {
      final n = q.name.toLowerCase();
      final t = q.type;
      if (n == mdnsMetaName) return t == dnsTypePtr || t == dnsTypeAny;
      if (n == mdnsServiceName) return t == dnsTypePtr || t == dnsTypeAny;
      if (n == instanceName.toLowerCase()) return true;
      if (n == hostName.toLowerCase()) return true;
      return false;
    });
    if (!wanted) return;
    final meta = m.questions.any((q) => q.name.toLowerCase() == mdnsMetaName) &&
        !m.questions.any((q) => q.name.toLowerCase() != mdnsMetaName);
    // Light rate limit (separately for the meta and the service answer).
    final now = DateTime.now();
    final last = meta ? _lastMetaReply : _lastReply;
    if (now.difference(last) < const Duration(milliseconds: 10)) return;
    if (meta) {
      _lastMetaReply = now;
    } else {
      _lastReply = now;
    }
    unawaited(() async {
      final msg = meta
          ? DnsMessage(flags: 0x8400, records: [
              DnsRecord.ptr(mdnsMetaName, mdnsServiceName, ttl: ttl)
            ])
          : await _selfMessage(ttl);
      try {
        await socket.send(encodeDnsMessage(msg));
      } catch (_) {}
    }());
  }

  static const _maxInstances = 64;
  static const _maxHosts = 128;

  void _onResponse(DnsMessage m, InternetAddress from) {
    final touched = <String>{};
    final suffix = '.$mdnsServiceName';
    for (final r in m.records) {
      final name = r.name.toLowerCase();
      switch (r.type) {
        case dnsTypePtr:
          if (name != mdnsServiceName || r.target == null) break;
          final inst = r.target!.toLowerCase();
          if (!inst.endsWith(suffix)) break;
          if (r.ttl == 0) {
            _remove(inst);
          } else if (_insts.containsKey(inst) ||
              _insts.length < _maxInstances) {
            _insts.putIfAbsent(inst, _Inst.new);
            touched.add(inst);
          }
        case dnsTypeSrv:
          if (!name.endsWith(suffix)) break;
          if (r.ttl == 0) {
            _remove(name);
            break;
          }
          final st = _slot(name);
          if (st == null) break;
          st.host = r.target?.toLowerCase();
          st.srvPort = r.port;
          touched.add(name);
        case dnsTypeTxt:
          if (!name.endsWith(suffix)) break;
          if (r.ttl == 0) {
            _remove(name);
            break;
          }
          final st = _slot(name);
          if (st == null) break;
          final kv = <String, String>{};
          for (final s in r.txt.take(16)) {
            final i = s.indexOf('=');
            if (i <= 0) continue;
            kv[s.substring(0, i).toLowerCase()] = s.substring(i + 1);
          }
          st.txt = kv;
          touched.add(name);
        case dnsTypeA:
          final ip = r.ip;
          if (ip == null) break;
          if (r.ttl == 0) {
            _hosts[name]?.remove(ip);
          } else if (_hosts.containsKey(name) || _hosts.length < _maxHosts) {
            final set = _hosts.putIfAbsent(name, () => {});
            if (set.length < 8) set.add(ip);
          }
          // An A record may complete an instance whose host it is.
          for (final e in _insts.entries) {
            if (e.value.host == name) touched.add(e.key);
          }
      }
    }
    for (final inst in touched) {
      _maybeEmit(inst, from);
    }
  }

  _Inst? _slot(String inst) {
    final s = _insts[inst];
    if (s != null) return s;
    if (_insts.length >= _maxInstances) return null;
    return _insts[inst] = _Inst();
  }

  void _remove(String inst) {
    _insts.remove(inst);
    final c = _candidates.remove(inst);
    if (c != null && !_goneCtrl.isClosed) _goneCtrl.add(c.fingerprint);
  }

  void _maybeEmit(String inst, InternetAddress from) {
    final st = _insts[inst];
    if (st == null || st.txt == null) return;
    final txt = st.txt!;
    final fp = (txt['fp'] ?? '').toLowerCase();
    if (!_fpRe.hasMatch(fp) || fp == fingerprint) return;
    final p = st.srvPort ?? int.tryParse(txt['port'] ?? '');
    if (p == null || p < 1 || p > 65535) return;
    final addrs = [
      for (final a in _hosts[st.host] ?? const <String>{})
        if (_validAddr(a, allowLoopback)) a
    ];
    if (addrs.isEmpty && _validAddr(from.address, allowLoopback)) {
      addrs.add(from.address);
    }
    if (addrs.isEmpty) return;
    var type = _cleanText(txt['type'] ?? 'desktop', 16);
    if (!RegExp(r'^[a-z]+$').hasMatch(type)) type = 'desktop';
    final alias = _cleanText(txt['alias'] ?? '', 64);
    final c = MdnsCandidate(inst, fp, alias.isEmpty ? 'LanDrop' : alias, type,
        p, addrs..sort());
    _candidates[inst] = c;
    if (!_foundCtrl.isClosed) _foundCtrl.add(c);
  }
}
