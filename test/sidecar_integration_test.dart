/// Integration test: spawns the REAL sing-box binary via the sidecar, points
/// it at a REAL VPS via a unic:// link, and verifies traffic actually tunnels.
///
/// Skipped unless both env vars are set:
///   UNIC_TEST_LINK     — a unic:// link to a working VPS account
///   UNIC_TEST_SINGBOX  — absolute path to sing-box.exe (Windows) or sing-box (POSIX)
///
/// Run with:
///   $env:UNIC_TEST_LINK='unic://...'
///   $env:UNIC_TEST_SINGBOX='C:\path\to\sing-box.exe'
///   dart test test/sidecar_integration_test.dart
library;

import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:unic_tunnel_app/core/singbox_config.dart';
import 'package:unic_tunnel_app/core/unic_link.dart';
import 'package:unic_tunnel_app/engine/sidecar.dart';

const _socksPort = 21080;

void main() {
  final link = Platform.environment['UNIC_TEST_LINK'];
  final binary = Platform.environment['UNIC_TEST_SINGBOX'];

  final binaryExists = binary != null && binary.isNotEmpty && File(binary).existsSync();
  final canRun = link != null && link.isNotEmpty && binaryExists;

  final skipReason = canRun
      ? null
      : 'set UNIC_TEST_LINK + UNIC_TEST_SINGBOX (binary must exist on disk)';

  test('sidecar tunnels real traffic through the VPS', () async {
    final payload = parseUnicLink(link!);
    final config = buildSingboxConfig(payload, socksPort: _socksPort);

    final sidecar = SingboxSidecar(binaryPath: binary!);
    final stderr = <String>[];
    sidecar.output.listen((l) {
      if (l.isStderr) stderr.add(l.text);
    });

    try {
      await sidecar.start(config);

      // Wait up to 10s for sing-box to start listening on the SOCKS port.
      final ready = await _waitForPort(_socksPort, timeout: const Duration(seconds: 10));
      expect(ready, isTrue,
          reason: 'sing-box never opened :$_socksPort. stderr:\n${stderr.join("\n")}');

      // curl through SOCKS5 to confirm traffic actually exits via the VPS.
      final result = await Process.run('curl.exe', [
        '-s', '--max-time', '15',
        '--socks5-hostname', '127.0.0.1:$_socksPort',
        'https://api.ipify.org',
      ]);
      expect(result.exitCode, equals(0),
          reason: 'curl failed: stderr=${result.stderr}');

      final exitIp = (result.stdout as String).trim();
      expect(exitIp, equals(payload.host),
          reason: 'expected exit IP ${payload.host}, got "$exitIp" '
              '(sing-box stderr:\n${stderr.join("\n")})');
    } finally {
      await sidecar.stop();
    }
  }, skip: skipReason, timeout: const Timeout(Duration(seconds: 30)));
}

/// Poll TCP connect until the port accepts or we run out of time.
Future<bool> _waitForPort(int port, {required Duration timeout}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    try {
      final s = await Socket.connect('127.0.0.1', port,
          timeout: const Duration(seconds: 1));
      s.destroy();
      return true;
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }
  return false;
}
