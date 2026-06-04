/// Generates a sing-box `config.json` string from a [UnicPayload].
///
/// Two modes:
///  - **SOCKS** (`tun: false`): exposes a local SOCKS5/HTTP mixed inbound on
///    [socksPort]. No admin elevation needed. Used for tests and dev.
///  - **TUN** (`tun: true`): creates a virtual TUN adapter that captures ALL
///    device traffic + DNS. Requires Administrator on Windows (Wintun).
///
/// Outbound is always an `ssh` outbound built from the payload.
library;

import 'dart:convert';

import 'unic_link.dart';

class SingboxConfig {
  /// Generated JSON string ready to write to disk.
  final String json;

  /// Local port for the SOCKS inbound, when [tunMode] is false. -1 in TUN mode.
  final int socksPort;
  final bool tunMode;

  SingboxConfig._(this.json, this.socksPort, this.tunMode);
}

/// Build a sing-box config from a parsed unic:// payload.
///
/// In SOCKS mode (default), a `mixed` inbound listens on `127.0.0.1:socksPort`
/// so callers can curl through it as a local proxy. In TUN mode, the inbound
/// is a `tun` adapter with `auto_route` — every connection in/out of the
/// device routes through the tunnel.
SingboxConfig buildSingboxConfig(
  UnicPayload p, {
  int socksPort = 11080,
  bool tun = false,
}) {
  final inbound = tun
      ? {
          'type': 'tun',
          'tag': 'tun-in',
          'inet4_address': '172.19.0.1/30',
          'auto_route': true,
          'strict_route': true,
          'stack': 'mixed',
        }
      : {
          'type': 'mixed',
          'tag': 'socks-in',
          'listen': '127.0.0.1',
          'listen_port': socksPort,
        };

  final config = {
    'log': {'level': 'warn'},
    'inbounds': [inbound],
    'outbounds': [
      {
        'type': 'ssh',
        'tag': 'ssh-out',
        'server': p.host,
        'server_port': p.port,
        'user': p.user,
        'password': p.password,
      },
    ],
    'route': {'final': 'ssh-out'},
  };

  const encoder = JsonEncoder.withIndent('  ');
  return SingboxConfig._(
    encoder.convert(config),
    tun ? -1 : socksPort,
    tun,
  );
}
