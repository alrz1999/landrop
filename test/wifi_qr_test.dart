import 'package:flutter_test/flutter_test.dart';
import 'package:landrop/ui/hotspot_service.dart';
import 'package:landrop/ui/wifi_qr.dart';

void main() {
  test('round trip with the builder, including escapes', () {
    for (final (s, p) in [
      ('LanDrop-1', 'secret123'),
      (r'we;ird,na:me"\x', r'p;a,s:s"w\ord'),
      ('1234', '12345678'),
      ('été \u{1F600}', 'pässwörd1'),
    ]) {
      final c = parseWifiQr(wifiQrPayload(s, p));
      expect(c, isNotNull, reason: s);
      expect(c!.ssid, s);
      expect(c.password, p);
      expect(c.security, WifiSecurity.wpa);
      expect(c.hidden, isFalse);
    }
  });

  test('open network round trip', () {
    final c = parseWifiQr(wifiQrPayload('Cafe', ''))!;
    expect(c.security, WifiSecurity.open);
    expect(c.password, '');
  });

  test('order independent, hidden, types, missing trailing ;;', () {
    final c = parseWifiQr('WIFI:H:true;P:abcdefgh;S:Net;T:WPA2')!;
    expect(c, const WifiCredentials('Net', 'abcdefgh', hidden: true));
    expect(parseWifiQr('WIFI:T:WEP;S:a;P:12345;;')!.security, WifiSecurity.wep);
    expect(parseWifiQr('WIFI:T:SAE;S:a;P:12345678;;')!.security,
        WifiSecurity.wpa3);
    expect(parseWifiQr('WIFI:T:WPA3;S:a;P:12345678;;')!.security,
        WifiSecurity.wpa3);
    expect(parseWifiQr('WIFI:S:a;P:12345678;;')!.security, WifiSecurity.wpa);
    expect(parseWifiQr('WIFI:S:a;;')!.security, WifiSecurity.open);
    expect(parseWifiQr('wifi:T:nopass;S:a;;')!.security, WifiSecurity.open);
    expect(parseWifiQr('  WIFI:S:a;T:nopass;H:false;;\n')!.hidden, isFalse);
  });

  test('quoted values are literal', () {
    final c = parseWifiQr('WIFI:T:WPA;S:"1234";P:"abcdefgh";;')!;
    expect(c.ssid, '1234');
    expect(c.password, 'abcdefgh');
  });

  test('rejects malformed input', () {
    for (final s in [
      '',
      'WIFI:',
      'WIFI:;;',
      'WIFI:T:WPA;S:;P:x;;',
      'WIFI:T:WPA;P:abcdefgh;;',
      'WIFI:T:WPA;S:a;;', // secured without password
      'WIFI:T:EAP-TLS;S:a;P:abcdefgh;;',
      'http://example.com',
      'xWIFI:S:a;;',
      'WIFI:S',
    ]) {
      expect(parseWifiQr(s), isNull, reason: s);
    }
  });

  test('rejects hostile input', () {
    expect(parseWifiQr('WIFI:S:${'a' * 33};T:nopass;;'), isNull);
    expect(parseWifiQr('WIFI:S:a;T:WPA;P:${'p' * 64};;'), isNull);
    expect(parseWifiQr('WIFI:S:${'a' * 5000};;'), isNull);
    expect(parseWifiQr('WIFI:S:a\nb;T:nopass;;'), isNull);
    expect(parseWifiQr('WIFI:S:a\u0000;T:nopass;;'), isNull);
    expect(parseWifiQr('WIFI:S:a;T:WPA;P:abc\u0007defgh;;'), isNull);
    expect(parseWifiQr('WIFI:S:a;T:nopass;;' * 1), isNotNull);
    // Dangling backslash must not throw.
    expect(parseWifiQr(r'WIFI:S:a\'), isNotNull);
    expect(parseWifiQr('WIFI:${'\\' * 500}'), isNull);
    expect(parseWifiQr('WIFI:${';' * 900}'), isNull);
  });
}
