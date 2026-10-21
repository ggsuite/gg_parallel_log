// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:async';
import 'dart:io';

import 'gg_parallel_log_console.dart';
import 'gg_parallel_log_native_console.dart';
import 'gg_parallel_log_terminal.dart';

// #############################################################################
/// The terminal of the process: stdout for output, the console for keys.
///
/// Keys are polled from the console, so stdin stays usable afterwards.
class GgParallelLogStdioTerminal implements GgParallelLogTerminal {
  /// Creates the terminal of the process.
  ///
  /// Tests pass [environment], [isWindows] and a [console] of their own.
  GgParallelLogStdioTerminal({
    Map<String, String>? environment,
    bool? isWindows,
    this._console,
    this.pollInterval = const Duration(milliseconds: 15),
  }) : _environment = environment ?? Platform.environment,
       _isWindows = isWindows ?? Platform.isWindows;

  /// Creates an example terminal for tests and docs.
  factory GgParallelLogStdioTerminal.example({
    Map<String, String>? environment,
    bool? isWindows,
    GgParallelLogConsole? console,
  }) => GgParallelLogStdioTerminal(
    environment: environment ?? const {'TERM': 'xterm-256color'},
    isWindows: isWindows ?? false,
    console: console,
  );

  // ...........................................................................
  /// Returns whether a terminal with these properties is interactive.
  ///
  /// POSIX needs a TERM other than dumb, as Dart's check misses Alacritty.
  bool interactiveWith({
    required bool stdinIsTerminal,
    required bool stdoutIsTerminal,
    required bool supportsAnsi,
  }) {
    if (!stdinIsTerminal || !stdoutIsTerminal) return false;
    if (_isWindows) return supportsAnsi;
    final term = _environment['TERM'] ?? '';
    return term.isNotEmpty && term != 'dumb';
  }

  // ...........................................................................
  @override
  bool enableRawMode() => _consoleOrNative.enableRawMode();

  // ...........................................................................
  @override
  void disableRawMode() => _consoleOrNative.disableRawMode();

  // ...........................................................................
  @override
  void write(String text) => stdout.write(text);

  // ...........................................................................
  /// The time between two looks at the console for new keys.
  final Duration pollInterval;

  @override
  bool get isInteractive => interactiveWith(
    stdinIsTerminal: stdin.hasTerminal,
    stdoutIsTerminal: stdout.hasTerminal,
    supportsAnsi: stdout.supportsAnsiEscapes,
  );

  @override
  int get width => stdout.hasTerminal ? stdout.terminalColumns : 80;

  @override
  int get height => stdout.hasTerminal ? stdout.terminalLines : 24;

  /// Polls the console while listened to; only one listener per process.
  @override
  Stream<String> get input {
    if (_inputInUse) throw StateError('The console input is in use.');
    Timer? timer;
    late final StreamController<String> controller;
    controller = StreamController<String>(
      onListen: () {
        _inputInUse = true;
        timer = Timer.periodic(pollInterval, (_) {
          final keys = _consoleOrNative.read();
          if (keys.isNotEmpty) controller.add(keys);
        });
      },
      onCancel: () {
        _inputInUse = false;
        timer?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Stream<void> get interrupts => ProcessSignal.sigint.watch();

  /// Emits 129 on SIGHUP and, besides on Windows, 143 on SIGTERM.
  @override
  Stream<int> get terminations {
    final subscriptions = <StreamSubscription<ProcessSignal>>[];
    late final StreamController<int> controller;
    controller = StreamController<int>(
      onListen: () => subscriptions.addAll([
        ProcessSignal.sighup.watch().listen((_) => controller.add(129)),
        if (!_isWindows)
          ProcessSignal.sigterm.watch().listen((_) => controller.add(143)),
      ]),
      onCancel: () => Future.wait([
        for (final subscription in subscriptions) subscription.cancel(),
      ]),
    );
    return controller.stream;
  }

  // ######################
  // Private
  // ######################

  /// Whether a terminal of this process polls the console already.
  static bool _inputInUse = false;

  final Map<String, String> _environment;
  final bool _isWindows;
  GgParallelLogConsole? _console;

  // ...........................................................................
  GgParallelLogConsole get _consoleOrNative =>
      _console ??= GgParallelLogNativeConsole.create();
}
