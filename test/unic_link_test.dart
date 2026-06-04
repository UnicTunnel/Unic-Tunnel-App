import 'dart:convert';

import 'package:test/test.dart';
import 'package:unic_tunnel_app/core/unic_link.dart';

void main() {
  group('unic:// round-trip', () {
    test('build then parse returns the same payload', () {
      const original = UnicPayload(
        name: 'iran-server',
        host: '198.105.115.89',
        port: 2222,
        user: 'u_e6e44995',
        password: 'y4wyjEqwoFyoBnuI4Axxfqs0',
      );
      final link = buildUnicLink(original);
      expect(link.startsWith('unic://'), isTrue);
      final decoded = parseUnicLink(link);
      expect(decoded, equals(original));
    });

    test('parses a link minted by the Go panel', () {
      // Real link captured from the live panel after slice 2e shipped.
      // Cross-language compatibility lives or dies on this test.
      const link =
          'unic://eyJ2IjoxLCJuYW1lIjoibGFwdG9wLXRlc3QiLCJob3N0IjoiMTk4LjEwNS4xMTUuODkiLCJwb3J0IjoyMjIyLCJ1c2VyIjoidV9lNmU0NDk5NSIsInBhc3N3b3JkIjoieTR3eWpFcXdvRnlvQm51STRBeHhmcXMwIn0';
      final p = parseUnicLink(link);
      expect(p.v, equals(1));
      expect(p.name, equals('laptop-test'));
      expect(p.host, equals('198.105.115.89'));
      expect(p.port, equals(2222));
      expect(p.user, equals('u_e6e44995'));
      expect(p.password, equals('y4wyjEqwoFyoBnuI4Axxfqs0'));
    });
  });

  group('parse rejects', () {
    test('non-unic scheme', () {
      expect(() => parseUnicLink('vless://abc'),
          throwsA(isA<UnicLinkException>()));
    });

    test('unknown version', () {
      final badJson = jsonEncode({
        'v': 2,
        'name': 'x',
        'host': 'h',
        'port': 22,
        'user': 'u',
        'password': 'p',
      });
      final link = 'unic://${base64Url.encode(utf8.encode(badJson)).replaceAll('=', '')}';
      expect(() => parseUnicLink(link), throwsA(isA<UnicLinkException>()));
    });

    test('garbage payloads', () {
      for (final bad in const [
        'unic://',
        'unic://!!!',
        'unic://Zm9v', // "foo" — valid base64, not valid JSON
      ]) {
        expect(() => parseUnicLink(bad), throwsA(isA<UnicLinkException>()),
            reason: 'expected throw on $bad');
      }
    });
  });

  test('accepts padded base64url', () {
    const p = UnicPayload(
      name: '', host: 'h', port: 22, user: 'u', password: 'p',
    );
    final link = buildUnicLink(p);
    // Manually pad and confirm we still decode.
    final padded = '$link==';
    expect(parseUnicLink(padded), equals(p));
  });
}
