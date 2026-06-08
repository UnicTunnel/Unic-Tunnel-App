/// Runs `sing-box.exe` as a background sidecar process.
///
/// The Dart side never embeds the engine — we ship the binary alongside the
/// app and spawn it via [Process.start]. That keeps the Flutter↔Go boundary
/// at the process level (no FFI in v1).
///
/// Lifecycle: [start] writes the config to a temp file, launches the process,
/// pipes its stdout/stderr into [output], and exposes [exitCode] for callers
/// that want to await termination. [stop] sends SIGTERM (on Windows, kills
/// the process tree) and cleans up the temp file.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/singbox_config.dart';

/// One line of output from sing-box.
class SidecarLine {
  final String text;
  final bool isStderr;
  SidecarLine(this.text, {this.isStderr = false});

  @override
  String toString() => (isStderr ? 'stderr: ' : 'stdout: ') + text;
}

enum SidecarState { idle, starting, running, stopped, failed }

class SingboxSidecar {
  /// Absolute path to `sing-box.exe` (or `sing-box` on POSIX).
  final String binaryPath;

  /// Directory where the config file gets written. Defaults to the system temp.
  final Directory? workDir;

  final _outputController = StreamController<SidecarLine>.broadcast();
  final _stateController = StreamController<SidecarState>.broadcast();

  Process? _proc;
  File? _configFile;
  IOSink? _logSink;
  SidecarState _state = SidecarState.idle;
  int? _exitCode;
  Completer<int>? _exitCompleter;

  SingboxSidecar({required this.binaryPath, this.workDir});

  /// Where the sidecar tees sing-box stdout/stderr for post-mortem debugging.
  /// Truncated each time [start] is called. Readable from a non-elevated shell
  /// when the app is elevated, since both run as the same user.
  static File debugLogFile() => File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}unic-singbox.log',
      );

  Stream<SidecarLine> get output => _outputController.stream;
  Stream<SidecarState> get stateChanges => _stateController.stream;
  SidecarState get state => _state;
  int? get exitCode => _exitCode;

  /// Spawn sing-box with [config]. Returns once the process is started
  /// (NOT once it's ready — callers should listen to [output] or poll
  /// [SingboxConfig.socksPort] to determine readiness).
  Future<void> start(SingboxConfig config) async {
    if (_state == SidecarState.starting || _state == SidecarState.running) {
      throw StateError('sidecar already $_state');
    }
    _setState(SidecarState.starting);

    final dir = workDir ?? Directory.systemTemp;
    _configFile = await File('${dir.path}${Platform.pathSeparator}'
            'unic-singbox-${DateTime.now().microsecondsSinceEpoch}.json')
        .writeAsString(config.json);

    // Tee everything to a file so post-mortem debugging doesn't depend on
    // being able to drive the app (elevated apps can't be touched by UIPI).
    _logSink = debugLogFile().openWrite(mode: FileMode.write);
    _logSink!.writeln('=== unic-singbox debug log ${DateTime.now().toIso8601String()} ===');
    _logSink!.writeln('binary: $binaryPath');
    _logSink!.writeln('config: ${_configFile!.path}');
    _logSink!.writeln('---');
    await _logSink!.flush();

    _exitCompleter = Completer<int>();
    try {
      _proc = await Process.start(
        binaryPath,
        ['run', '-c', _configFile!.path],
        runInShell: false,
      );
    } catch (e) {
      _logSink!.writeln('!!! Process.start threw: $e');
      await _logSink!.flush();
      _setState(SidecarState.failed);
      await _cleanup();
      rethrow;
    }

    _proc!.stdout
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen((line) {
      _outputController.add(SidecarLine(line));
      _logSink?.writeln('[stdout] $line');
    });
    _proc!.stderr
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen((line) {
      _outputController.add(SidecarLine(line, isStderr: true));
      _logSink?.writeln('[stderr] $line');
    });

    _proc!.exitCode.then((code) async {
      _exitCode = code;
      _setState(code == 0 ? SidecarState.stopped : SidecarState.failed);
      await _cleanup();
      if (!_exitCompleter!.isCompleted) _exitCompleter!.complete(code);
    });

    _setState(SidecarState.running);
  }

  /// Wait for the process to exit. Returns its exit code.
  Future<int> waitForExit() async {
    if (_exitCode != null) return _exitCode!;
    if (_exitCompleter == null) throw StateError('not started');
    return _exitCompleter!.future;
  }

  /// Stop the process. On Windows, kills the whole tree. On POSIX, sends
  /// SIGTERM then SIGKILL after [timeout]. Idempotent.
  Future<void> stop({Duration timeout = const Duration(seconds: 5)}) async {
    final p = _proc;
    if (p == null) return;
    if (Platform.isWindows) {
      // No clean SIGTERM on Windows; kill the process. Wintun adapter is
      // released by sing-box on shutdown in normal cases, but a hard kill
      // skips that — acceptable for v1; TODO before mobile: graceful stop.
      p.kill(ProcessSignal.sigkill);
    } else {
      p.kill(ProcessSignal.sigterm);
      try {
        await waitForExit().timeout(timeout);
      } on TimeoutException {
        p.kill(ProcessSignal.sigkill);
      }
    }
    await _cleanup();
  }

  Future<void> _cleanup() async {
    final f = _configFile;
    _configFile = null;
    if (f != null && await f.exists()) {
      try { await f.delete(); } catch (_) { /* best-effort */ }
    }
    final sink = _logSink;
    _logSink = null;
    if (sink != null) {
      try {
        sink.writeln('--- sidecar cleanup at ${DateTime.now().toIso8601String()} ---');
        await sink.flush();
        await sink.close();
      } catch (_) { /* best-effort */ }
    }
  }

  void _setState(SidecarState s) {
    _state = s;
    _stateController.add(s);
  }

  /// Release stream controllers. Call when the sidecar object is no longer
  /// needed (e.g. in `dispose()` for a Flutter widget).
  Future<void> close() async {
    await stop();
    await _outputController.close();
    await _stateController.close();
  }
}
