// An HttpServer with connection limits (SECURITY.md S1). dart:io's
// HttpServer has no cap on connections and no TLS handshake timeout, so the
// listening socket is ours: every accepted socket is counted (total and per
// remote address), TLS is negotiated here with a timeout, and only then is
// the socket handed to an HttpServer through [HttpServer.listenOn].
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class ServerLimits {
  /// Open connections at once (including ones still in the TLS handshake).
  final int maxConnections;

  /// Open connections from one remote address.
  final int maxConnectionsPerIp;

  /// TLS handshake must finish within this time.
  final Duration handshakeTimeout;

  /// [HttpServer.idleTimeout]: a keep-alive connection without a request, or
  /// a request whose headers do not arrive, is closed after about this long.
  final Duration idleTimeout;

  const ServerLimits({
    this.maxConnections = 256,
    this.maxConnectionsPerIp = 32,
    this.handshakeTimeout = const Duration(seconds: 10),
    this.idleTimeout = const Duration(seconds: 30),
  });
}

/// Binds [address]:[port] (TLS when [context] is given) and returns an
/// [HttpServer] that enforces [limits]. Connections over a limit are closed
/// at once. Throws [SocketException] like [HttpServer.bind].
Future<GuardedHttpServer> bindGuarded(
  InternetAddress address,
  int port, {
  SecurityContext? context,
  ServerLimits limits = const ServerLimits(),
}) async {
  if (context == null) {
    final raw = await ServerSocket.bind(address, port);
    return GuardedHttpServer._(
      raw.address,
      raw.port,
      raw.close,
      limits,
      (accept) => raw.listen(accept, onError: (_) {}),
      null,
    );
  }
  // TLS is negotiated on the raw socket: a handshake that stalls can only
  // be aborted by closing the RawSocket (a Socket handed to
  // SecureSocket.secureServer is detached and destroy() no longer reaches
  // the descriptor).
  final raw = await RawServerSocket.bind(address, port);
  return GuardedHttpServer._(
    raw.address,
    raw.port,
    raw.close,
    limits,
    (accept) => raw.listen((r) => accept(r), onError: (_) {}),
    context,
  );
}

class GuardedHttpServer {
  GuardedHttpServer._(
    this._address,
    this.port,
    this._closeRaw,
    this.limits,
    StreamSubscription Function(void Function(dynamic)) listen,
    this._context,
  ) {
    _feed = _FedServerSocket(_address, port);
    http = HttpServer.listenOn(_feed)..idleTimeout = limits.idleTimeout;
    _sub = listen(_accept);
  }

  final InternetAddress _address;
  final Future<dynamic> Function() _closeRaw;
  final SecurityContext? _context;
  final ServerLimits limits;
  late final _FedServerSocket _feed;
  late final HttpServer http;
  late final StreamSubscription _sub;
  final Map<String, int> _perIp = {};
  final Set<RawSocket> _handshaking = {};
  int _open = 0;
  bool _closed = false;

  final int port;

  /// Connections currently counted (test/diagnostic).
  int get openConnections => _open;

  /// [s] is a [Socket] (plain HTTP) or a [RawSocket] (TLS).
  void _accept(dynamic s) {
    // Never throws into the listen callback: a socket that died already has
    // no usable remote address.
    final String ip;
    try {
      ip = (s.remoteAddress as InternetAddress).address;
    } catch (_) {
      _destroy(s);
      return;
    }
    if (_closed ||
        _open >= limits.maxConnections ||
        (_perIp[ip] ?? 0) >= limits.maxConnectionsPerIp) {
      _destroy(s);
      return;
    }
    _open++;
    _perIp[ip] = (_perIp[ip] ?? 0) + 1;
    var released = false;
    void release() {
      if (released) return;
      released = true;
      _open--;
      final n = (_perIp[ip] ?? 1) - 1;
      if (n <= 0) {
        _perIp.remove(ip);
      } else {
        _perIp[ip] = n;
      }
    }

    final ctx = _context;
    if (ctx == null) {
      _feed.add(_TrackedSocket(s as Socket, release));
      return;
    }
    final raw = s as RawSocket;
    _handshaking.add(raw);
    var timedOut = false;
    final timer = Timer(limits.handshakeTimeout, () {
      timedOut = true;
      _handshaking.remove(raw);
      raw.close();
      release();
    });
    RawSecureSocket.secureServer(raw, ctx).then(
      (secure) {
        timer.cancel();
        _handshaking.remove(raw);
        if (timedOut || _closed) {
          secure.close();
          release();
          return;
        }
        _feed.add(_RawSecureAdapter(secure, release));
      },
      onError: (Object _) {
        timer.cancel();
        _handshaking.remove(raw);
        raw.close();
        release();
      },
    );
  }

  static void _destroy(dynamic s) {
    try {
      if (s is Socket) {
        s.destroy();
      } else if (s is RawSocket) {
        s.close();
      }
    } catch (_) {}
  }

  Future<void> close({bool force = false}) async {
    _closed = true;
    for (final s in _handshaking.toList()) {
      s.close();
    }
    _handshaking.clear();
    await http.close(force: force);
    try {
      await _sub.cancel();
      await _closeRaw();
    } catch (_) {}
  }
}

/// The ServerSocket handed to [HttpServer.listenOn]: emits the sockets this
/// server accepted (after TLS, when used).
class _FedServerSocket extends Stream<Socket> implements ServerSocket {
  _FedServerSocket(this._address, this._port);
  final InternetAddress _address;
  final int _port;
  final StreamController<Socket> _c = StreamController();

  void add(Socket s) {
    if (_c.isClosed) {
      s.destroy();
    } else {
      _c.add(s);
    }
  }

  @override
  StreamSubscription<Socket> listen(
    void Function(Socket event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _c.stream.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  int get port => _port;

  @override
  InternetAddress get address => _address;

  @override
  Future<ServerSocket> close() async {
    await _c.close();
    return this;
  }
}

/// Forwards everything to [_s] and calls [_release] once when the socket
/// is destroyed, its input ends or fails, or its output is done.
class _TrackedSocket extends Stream<Uint8List> implements Socket {
  _TrackedSocket(this._s, this._release) {
    _s.done.then((_) => _release(), onError: (_) => _release());
  }
  final Socket _s;
  final void Function() _release;

  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _s.listen(
      onData,
      onError: (Object e, StackTrace st) {
        _release();
        if (onError is void Function(Object, StackTrace)) {
          onError(e, st);
        } else if (onError is void Function(Object)) {
          onError(e);
        }
      },
      onDone: () {
        _release();
        onDone?.call();
      },
      cancelOnError: cancelOnError,
    );
  }

  @override
  void destroy() {
    _release();
    _s.destroy();
  }

  @override
  Encoding get encoding => _s.encoding;
  @override
  set encoding(Encoding e) => _s.encoding = e;
  @override
  void add(List<int> data) => _s.add(data);
  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _s.addError(error, stackTrace);
  @override
  Future addStream(Stream<List<int>> stream) => _s.addStream(stream);
  @override
  Future close() => _s.close();
  @override
  Future get done => _s.done;
  @override
  Future flush() => _s.flush();
  @override
  void write(Object? object) => _s.write(object);
  @override
  void writeAll(Iterable objects, [String separator = '']) =>
      _s.writeAll(objects, separator);
  @override
  void writeCharCode(int charCode) => _s.writeCharCode(charCode);
  @override
  void writeln([Object? object = '']) => _s.writeln(object);
  @override
  int get port => _s.port;
  @override
  int get remotePort => _s.remotePort;
  @override
  InternetAddress get address => _s.address;
  @override
  InternetAddress get remoteAddress => _s.remoteAddress;
  @override
  bool setOption(SocketOption option, bool enabled) =>
      _s.setOption(option, enabled);
  @override
  Uint8List getRawOption(RawSocketOption option) => _s.getRawOption(option);
  @override
  void setRawOption(RawSocketOption option) => _s.setRawOption(option);
}

/// A [SecureSocket] over a [RawSecureSocket] (which dart:io only exposes
/// as a raw event stream). Reads honour pause/resume; writes are queued and
/// [addStream] waits for them, so a large body never piles up in memory.
/// [_release] runs once when the connection is over.
class _RawSecureAdapter extends Stream<Uint8List> implements SecureSocket {
  _RawSecureAdapter(this._raw, this._release) {
    _in = StreamController<Uint8List>(
      sync: true,
      onListen: _start,
      onPause: () => _raw.readEventsEnabled = false,
      onResume: () {
        _raw.readEventsEnabled = true;
        _readAll();
      },
      onCancel: destroy,
    );
  }

  final RawSecureSocket _raw;
  final void Function() _release;
  late final StreamController<Uint8List> _in;
  StreamSubscription<RawSocketEvent>? _events;
  final _out = <List<int>>[];
  var _outOffset = 0;
  Completer<void>? _drained;
  bool _closing = false;
  bool _shutdown = false;
  bool _gone = false;
  final Completer<void> _done = Completer<void>();

  void _start() {
    _events = _raw.listen(
      _onEvent,
      onError: (Object e) {
        if (!_in.isClosed) _in.addError(e);
        _finish();
      },
      onDone: _finish,
    );
    _readAll();
  }

  void _onEvent(RawSocketEvent e) {
    switch (e) {
      case RawSocketEvent.read:
        _readAll();
      case RawSocketEvent.write:
        _writeOut();
      case RawSocketEvent.readClosed:
        if (!_in.isClosed) _in.close();
      case RawSocketEvent.closed:
        _finish();
    }
  }

  void _readAll() {
    while (!_gone && !_in.isClosed && !_in.isPaused) {
      final Uint8List? d;
      try {
        d = _raw.read();
      } catch (_) {
        _finish();
        return;
      }
      if (d == null || d.isEmpty) return;
      _in.add(d);
    }
  }

  void _writeOut() {
    if (_gone) return;
    try {
      while (_out.isNotEmpty) {
        final chunk = _out.first;
        final n = _raw.write(chunk, _outOffset, chunk.length - _outOffset);
        _outOffset += n;
        if (_outOffset < chunk.length) {
          _raw.writeEventsEnabled = true;
          return;
        }
        _out.removeAt(0);
        _outOffset = 0;
      }
    } catch (_) {
      _finish();
      return;
    }
    final d = _drained;
    if (d != null) {
      _drained = null;
      d.complete();
    }
    if (_closing && !_shutdown) {
      _shutdown = true;
      try {
        _raw.shutdown(SocketDirection.send);
      } catch (_) {}
    }
  }

  void _finish() {
    if (_gone) return;
    _gone = true;
    _release();
    _out.clear();
    final d = _drained;
    if (d != null) {
      _drained = null;
      d.complete();
    }
    if (!_in.isClosed) _in.close();
    if (!_done.isCompleted) _done.complete();
    _events?.cancel();
    try {
      _raw.close();
    } catch (_) {}
  }

  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _in.stream.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  void destroy() => _finish();

  @override
  Encoding encoding = utf8;

  @override
  void add(List<int> data) {
    if (_gone || _closing || data.isEmpty) return;
    _out.add(data);
    _writeOut();
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream<List<int>> stream) {
    final c = Completer<void>();
    late StreamSubscription<List<int>> sub;
    sub = stream.listen(
      (data) {
        add(data);
        if (_out.isNotEmpty && !_gone) {
          sub.pause();
          (_drained ??= Completer<void>()).future.then((_) => sub.resume());
        }
      },
      onError: (Object e, StackTrace st) {
        if (!c.isCompleted) c.completeError(e, st);
      },
      onDone: () {
        if (!c.isCompleted) c.complete();
      },
      cancelOnError: true,
    );
    // A closed connection ends the transfer instead of hanging it.
    _done.future.then((_) {
      sub.cancel();
      if (!c.isCompleted) c.complete();
    });
    return c.future;
  }

  @override
  Future close() {
    if (!_closing) {
      _closing = true;
      _writeOut();
    }
    return _done.future;
  }

  @override
  Future get done => _done.future;

  @override
  Future flush() {
    if (_out.isEmpty || _gone) return Future.value();
    return (_drained ??= Completer<void>()).future;
  }

  @override
  void write(Object? object) => add(encoding.encode('$object'));
  @override
  void writeAll(Iterable objects, [String separator = '']) =>
      write(objects.join(separator));
  @override
  void writeCharCode(int charCode) => write(String.fromCharCode(charCode));
  @override
  void writeln([Object? object = '']) => write('$object\n');

  @override
  int get port => _raw.port;
  @override
  int get remotePort => _raw.remotePort;
  @override
  InternetAddress get address => _raw.address;
  @override
  InternetAddress get remoteAddress => _raw.remoteAddress;
  @override
  bool setOption(SocketOption option, bool enabled) =>
      _raw.setOption(option, enabled);
  @override
  Uint8List getRawOption(RawSocketOption option) => _raw.getRawOption(option);
  @override
  void setRawOption(RawSocketOption option) => _raw.setRawOption(option);
  @override
  X509Certificate? get peerCertificate => _raw.peerCertificate;
  @override
  String? get selectedProtocol => _raw.selectedProtocol;
  @override
  // ignore: deprecated_member_use
  void renegotiate({
    bool useSessionCache = true,
    bool requestClientCertificate = false,
    bool requireClientCertificate = false,
  }) =>
      // ignore: deprecated_member_use
      _raw.renegotiate(
        useSessionCache: useSessionCache,
        requestClientCertificate: requestClientCertificate,
        requireClientCertificate: requireClientCertificate,
      );
}
