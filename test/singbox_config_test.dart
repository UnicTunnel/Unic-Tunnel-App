import 'dart:convert';

import 'package:test/test.dart';
import 'package:unic_tunnel_app/core/singbox_config.dart';
import 'package:unic_tunnel_app/core/unic_link.dart';

const _payload = UnicPayload(
  name: 'iran-server',
  host: '198.105.115.89',
  port: 2222,
  user: 'u_e6e44995',
  password: 'y4wyjEqwoFyoBnuI4Axxfqs0',
);

void main() {
  group('socks mode (default)', () {
    final cfg = buildSingboxConfig(_payload, socksPort: 11080);
    final obj = jsonDecode(cfg.json) as Map<String, dynamic>;

    test('reports socksPort + tunMode=false', () {
      expect(cfg.socksPort, equals(11080));
      expect(cfg.tunMode, isFalse);
    });

    test('inbound is mixed on 127.0.0.1:11080', () {
      final inbound = (obj['inbounds'] as List).single as Map;
      expect(inbound['type'], equals('mixed'));
      expect(inbound['listen'], equals('127.0.0.1'));
      expect(inbound['listen_port'], equals(11080));
    });

    test('outbound is ssh with the payload creds', () {
      final out = (obj['outbounds'] as List).single as Map;
      expect(out['type'], equals('ssh'));
      expect(out['server'], equals(_payload.host));
      expect(out['server_port'], equals(_payload.port));
      expect(out['user'], equals(_payload.user));
      expect(out['password'], equals(_payload.password));
    });

    test('route final points at the ssh outbound', () {
      expect(obj['route']['final'], equals('ssh-out'));
    });
  });

  group('tun mode', () {
    final cfg = buildSingboxConfig(_payload, tun: true);
    final obj = jsonDecode(cfg.json) as Map<String, dynamic>;

    test('reports tunMode=true and no socks port', () {
      expect(cfg.tunMode, isTrue);
      expect(cfg.socksPort, equals(-1));
    });

    test('inbound is a tun adapter with auto_route', () {
      final inbound = (obj['inbounds'] as List).single as Map;
      expect(inbound['type'], equals('tun'));
      expect(inbound['auto_route'], isTrue);
      expect(inbound['stack'], equals('mixed'));
    });

    test('still has the same ssh outbound', () {
      final out = (obj['outbounds'] as List).single as Map;
      expect(out['type'], equals('ssh'));
      expect(out['server'], equals(_payload.host));
    });
  });

  test('changing socksPort flows through', () {
    final cfg = buildSingboxConfig(_payload, socksPort: 22222);
    final obj = jsonDecode(cfg.json);
    expect(obj['inbounds'][0]['listen_port'], equals(22222));
  });
}
