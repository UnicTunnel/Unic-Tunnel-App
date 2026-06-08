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
          // sing-box ≥1.12 replaced inet4_address/inet6_address with a single
          // `address` array taking CIDR strings. Old field names are FATAL now.
          'address': ['172.19.0.1/30'],
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

  final sshOutbound = {
    'type': 'ssh',
    'tag': 'ssh-out',
    'server': p.host,
    'server_port': p.port,
    'user': p.user,
    'password': p.password,
    // Prefer modern, high-throughput AEAD ciphers. ChaCha20-Poly1305 wins on
    // most CPUs; AES-GCM-128 is the OpenSSH default fallback. Both are
    // enabled by default on Ubuntu's sshd, so this is a "prefer fastest"
    // not a "require this one specific cipher" change.
    'client_version': 'SSH-2.0-OpenSSH_9.6',
    'host_key_algorithms': [
      'ssh-ed25519',
      'rsa-sha2-256',
      'rsa-sha2-512',
    ],
  };

  // SSH cannot carry UDP. In TUN mode we'd otherwise drop all UDP — including
  // DNS — and the device looks "disconnected". The classic sshuttle-style mix:
  //   * DNS: forced to TCP, detoured through the SSH tunnel  (privacy kept)
  //   * other UDP (QUIC, WebRTC, etc.): goes direct          (privacy lost,
  //                                                            but works)
  //   * TCP: through the SSH tunnel                          (privacy kept)
  // SOCKS mode doesn't need any of this — apps that pick up the SOCKS proxy
  // will route DNS through it via SOCKS5-hostname themselves.
  final config = <String, dynamic>{
    'log': {'level': 'warn'},
    if (tun)
      'dns': {
        'servers': [
          {
            'tag': 'remote-dns',
            'type': 'tcp',
            'server': '1.1.1.1',
            'detour': 'ssh-out',
          },
        ],
        'final': 'remote-dns',
      },
    'inbounds': [inbound],
    'outbounds': [
      sshOutbound,
      if (tun) {'type': 'direct', 'tag': 'direct-out'},
    ],
    'route': {
      if (tun) 'auto_detect_interface': true,
      if (tun)
        'rules': [
          // SSH can't transport UDP → send non-DNS UDP direct.
          {'network': 'udp', 'outbound': 'direct-out'},
        ],
      'final': 'ssh-out',
    },
  };

  const encoder = JsonEncoder.withIndent('  ');
  return SingboxConfig._(
    encoder.convert(config),
    tun ? -1 : socksPort,
    tun,
  );
}
