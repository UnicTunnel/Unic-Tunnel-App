import 'package:flutter/material.dart';

import 'ui/home_screen.dart';

/// Path to the sing-box binary. Overridable at build time:
///   flutter run -d windows --dart-define UNIC_SINGBOX_PATH=...
/// Default points at the dev binary that lives in TEMP after we downloaded it
/// for the integration tests. Slice 3c-ii will switch this to a bundled asset.
const String kSingboxBinaryPath = String.fromEnvironment(
  'UNIC_SINGBOX_PATH',
  defaultValue:
      r'C:\Users\Amirs\AppData\Local\Temp\singbox\x\sing-box-1.13.12-windows-amd64\sing-box.exe',
);

void main() {
  runApp(const UnicTunnelApp());
}

class UnicTunnelApp extends StatelessWidget {
  const UnicTunnelApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF60A5FA),
      brightness: Brightness.dark,
    );
    return MaterialApp(
      title: 'Unic-Tunnel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorScheme: scheme),
      home: const HomeScreen(singboxBinaryPath: kSingboxBinaryPath),
    );
  }
}
