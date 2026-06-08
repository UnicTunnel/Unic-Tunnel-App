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

    test('uses the modern `address` array (not the removed inet4_address)', () {
      // sing-box ≥1.12 FATALs if it sees inet4_address. Regression guard.
      final inbound = (obj['inbounds'] as List).single as Map;
      expect(inbound['address'], isA<List>());
      expect((inbound['address'] as List).single, equals('172.19.0.1/30'));
      expect(inbound.containsKey('inet4_address'), isFalse);
      expect(inbound.containsKey('inet6_address'), isFalse);
    });

    test('has ssh + direct outbounds (direct is needed for UDP)', () {
      final outs = (obj['outbounds'] as List).cast<Map>();
      expect(outs, hasLength(2));
      expect(outs[0]['type'], equals('ssh'));
      expect(outs[0]['server'], equals(_payload.host));
      expect(outs[1]['type'], equals('direct'));
      expect(outs[1]['tag'], equals('direct-out'));
    });

    test('UDP is routed direct (SSH cannot carry UDP)', () {
      final rules = ((obj['route'] as Map)['rules'] as List).cast<Map>();
      final udpRule = rules.firstWhere((r) => r['network'] == 'udp');
      expect(udpRule['outbound'], equals('direct-out'));
    });

    test('DNS is forced to TCP and detoured through ssh-out', () {
      final dns = obj['dns'] as Map;
      final server = (dns['servers'] as List).single as Map;
      expect(server['type'], equals('tcp'));
      expect(server['detour'], equals('ssh-out'));
    });
  });

  test('changing socksPort flows through', () {
    final cfg = buildSingboxConfig(_payload, socksPort: 22222);
    final obj = jsonDecode(cfg.json);
    expect(obj['inbounds'][0]['listen_port'], equals(22222));
  });
}
