import 'package:flutter/material.dart';

import '../core/singbox_config.dart';
import '../core/unic_link.dart';
import '../engine/sidecar.dart';

enum _ConnState { idle, connecting, connected, disconnecting }

/// The one screen the v1 app has. Two visual modes:
///   - no saved link → paste-link form
///   - saved link    → big On/Off button + status
class HomeScreen extends StatefulWidget {
  final String singboxBinaryPath;
  const HomeScreen({super.key, required this.singboxBinaryPath});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UnicPayload? _payload;
  _ConnState _state = _ConnState.idle;
  String? _error;
  SingboxSidecar? _sidecar;
  final _linkController = TextEditingController();

  static const _socksPort = 11080;

  @override
  void dispose() {
    _linkController.dispose();
    _sidecar?.close();
    super.dispose();
  }

  void _submitLink() {
    setState(() => _error = null);
    try {
      final p = parseUnicLink(_linkController.text.trim());
      setState(() {
        _payload = p;
        _linkController.clear();
      });
    } on UnicLinkException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _connect() async {
    if (_payload == null) return;
    setState(() {
      _state = _ConnState.connecting;
      _error = null;
    });
    final config = buildSingboxConfig(_payload!, socksPort: _socksPort);
    final sidecar = SingboxSidecar(binaryPath: widget.singboxBinaryPath);
    try {
      await sidecar.start(config);
      if (!mounted) return;
      setState(() {
        _sidecar = sidecar;
        _state = _ConnState.connected;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sidecar = null;
        _state = _ConnState.idle;
        _error = 'Could not start sing-box: $e';
      });
    }
  }

  Future<void> _disconnect() async {
    setState(() => _state = _ConnState.disconnecting);
    await _sidecar?.stop();
    if (!mounted) return;
    setState(() {
      _sidecar = null;
      _state = _ConnState.idle;
    });
  }

  void _forgetLink() {
    if (_state != _ConnState.idle) return;
    setState(() {
      _payload = null;
      _error = null;
    });
  }

  /// Mask the last two octets of a v4 IP for casual screenshots/streaming.
  String _maskedHost(String host) {
    final parts = host.split('.');
    if (parts.length == 4 && parts.every((p) => int.tryParse(p) != null)) {
      return '${parts[0]}.${parts[1]}.•.•';
    }
    return host;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unic-Tunnel'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _payload == null ? _buildPasteScreen() : _buildConnectScreen(),
      ),
    );
  }

  Widget _buildPasteScreen() {
    final cs = Theme.of(context).colorScheme;
    final tx = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text('Paste your unic:// link', style: tx.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'The person who set up your server should have sent you one.',
          style: tx.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _linkController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'unic://...',
          ),
          minLines: 3,
          maxLines: 6,
          autocorrect: false,
          enableSuggestions: false,
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: cs.error)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _submitLink,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Continue'),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectScreen() {
    final cs = Theme.of(context).colorScheme;
    final tx = Theme.of(context).textTheme;
    final connected = _state == _ConnState.connected;
    final busy = _state == _ConnState.connecting ||
        _state == _ConnState.disconnecting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 24),
        Text(_payload!.name, style: tx.headlineSmall),
        const SizedBox(height: 4),
        Text(
          _maskedHost(_payload!.host),
          style: tx.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
        ),
        const Spacer(),
        InkWell(
          onTap: busy ? null : (connected ? _disconnect : _connect),
          customBorder: const CircleBorder(),
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: connected ? cs.primary : cs.surfaceContainerHigh,
              border: Border.all(
                color: connected ? cs.primary : cs.outline,
                width: 2,
              ),
            ),
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : Text(
                      connected ? 'OFF' : 'ON',
                      style: tx.headlineMedium?.copyWith(
                        color: connected ? cs.onPrimary : cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          switch (_state) {
            _ConnState.idle => 'Disconnected',
            _ConnState.connecting => 'Connecting…',
            _ConnState.connected => 'Tunneling through your server',
            _ConnState.disconnecting => 'Disconnecting…',
          },
          style: tx.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        if (connected) ...[
          const SizedBox(height: 4),
          Text(
            'SOCKS proxy: 127.0.0.1:$_socksPort',
            style: tx.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_error!, style: TextStyle(color: cs.onErrorContainer)),
          ),
        ],
        const Spacer(),
        TextButton(
          onPressed: _state == _ConnState.idle ? _forgetLink : null,
          child: const Text('Forget this link'),
        ),
      ],
    );
  }
}
