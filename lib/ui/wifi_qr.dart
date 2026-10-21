/// Security type of a scanned Wi-Fi QR code.
enum WifiSecurity { open, wep, wpa, wpa3 }

/// What a `WIFI:` QR code carries.
class WifiCredentials {
  final String ssid;

  /// Empty for open networks.
  final String password;
  final WifiSecurity security;
  final bool hidden;
  const WifiCredentials(this.ssid, this.password,
      {this.security = WifiSecurity.wpa, this.hidden = false});

  @override
  bool operator ==(Object other) =>
      other is WifiCredentials &&
      other.ssid == ssid &&
      other.password == password &&
      other.security == security &&
      other.hidden == hidden;
  @override
  int get hashCode => Object.hash(ssid, password, security, hidden);
}

const _maxPayload = 1024;
const _maxSsidBytes = 32;
const _maxPassword = 63;

bool _hasControl(String s) =>
    s.runes.any((r) => r < 0x20 || r == 0x7f || (r >= 0x80 && r < 0xa0));

int _utf8Length(String s) {
  var n = 0;
  for (final r in s.runes) {
    n += r < 0x80 ? 1 : r < 0x800 ? 2 : r < 0x10000 ? 3 : 4;
  }
  return n;
}

/// Splits [s] at unescaped [sep]; escapes stay in the pieces.
List<String> _splitUnescaped(String s, String sep) {
  final out = <String>[];
  final cur = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final ch = s[i];
    if (ch == r'\' && i + 1 < s.length) {
      cur..write(ch)..write(s[i + 1]);
      i++;
    } else if (ch == sep) {
      out.add(cur.toString());
      cur.clear();
    } else {
      cur.write(ch);
    }
  }
  out.add(cur.toString());
  return out;
}

String _unescape(String s) {
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (s[i] == r'\' && i + 1 < s.length) {
      b.write(s[i + 1]);
      i++;
    } else {
      b.write(s[i]);
    }
  }
  return b.toString();
}

/// A value wrapped in unescaped double quotes is a literal string.
String _value(String raw) {
  if (raw.length >= 2 && raw.startsWith('"') && raw.endsWith('"')) {
    var slashes = 0;
    for (var i = raw.length - 2; i >= 0 && raw[i] == r'\'; i--) {
      slashes++;
    }
    if (slashes.isEven) return _unescape(raw.substring(1, raw.length - 1));
  }
  return _unescape(raw);
}

/// Parses `WIFI:T:WPA;S:name;P:secret;H:true;;` (inverse of
/// `wifiQrPayload`). Returns null for anything that is not a usable Wi-Fi
/// code: wrong prefix, empty or oversize name, control characters, a secured
/// network without a password, or an over-long payload.
WifiCredentials? parseWifiQr(String input) {
  if (input.length > _maxPayload) return null;
  final text = input.trim();
  if (text.length < 5 || text.substring(0, 5).toUpperCase() != 'WIFI:') {
    return null;
  }
  String? type, ssid, pass;
  var hidden = false;
  for (final field in _splitUnescaped(text.substring(5), ';')) {
    if (field.isEmpty) continue;
    final parts = _splitUnescaped(field, ':');
    final key = parts.first.toUpperCase();
    final raw = field.substring(parts.first.length + (parts.length > 1 ? 1 : 0));
    if (parts.length < 2) continue;
    switch (key) {
      case 'T':
        type = _value(raw).trim().toUpperCase();
      case 'S':
        ssid = _value(raw);
      case 'P':
        pass = _value(raw);
      case 'H':
        hidden = _value(raw).trim().toLowerCase() == 'true';
    }
  }
  if (ssid == null || ssid.isEmpty) return null;
  if (_utf8Length(ssid) > _maxSsidBytes || _hasControl(ssid)) return null;
  final p = pass ?? '';
  if (p.length > _maxPassword || _hasControl(p)) return null;

  WifiSecurity sec;
  switch (type) {
    case null:
    case '':
      sec = p.isEmpty ? WifiSecurity.open : WifiSecurity.wpa;
    case 'NOPASS':
      sec = WifiSecurity.open;
    case 'WEP':
      sec = WifiSecurity.wep;
    case 'WPA3':
    case 'SAE':
      sec = WifiSecurity.wpa3;
    case 'WPA':
    case 'WPA2':
    case 'WPA/WPA2':
    case 'WPA2-EAP':
      sec = WifiSecurity.wpa;
    default:
      return null;
  }
  if (sec != WifiSecurity.open && p.isEmpty) return null;
  return WifiCredentials(ssid, sec == WifiSecurity.open ? '' : p,
      security: sec, hidden: hidden);
}
