// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// The real terminal needs a TTY, which unit tests do not have.
// coverage:ignore-file

import 'dart:convert';
import 'dart:io';

import 'gg_parallel_log_terminal.dart';
import 'gg_parallel_log_windows_console.dart';

// #############################################################################
/// The terminal of the process, i.e. stdin and stdout.
///
/// Its input can be listened to only once per process, as stdin can.
class GgParallelLogStdioTerminal implements GgParallelLogTerminal {
  /// Creates the terminal on top of stdin and stdout.
  GgParallelLogStdioTerminal();

  /// Creates an example terminal for docs.
  factory GgParallelLogStdioTerminal.example() => GgParallelLogStdioTerminal();

  // ...........................................................................
  @override
  void write(String text) => stdout.write(text);

  // ...........................................................................
  @override
  void enableRawMode() {
    _echoMode = stdin.echoMode;
    _lineMode = stdin.lineMode;
    stdin.echoMode = false;
    stdin.lineMode = false;
    _consoleMode = GgParallelLogWindowsConsole.enableVirtualTerminalInput();
  }

  // ...........................................................................
  @override
  void disableRawMode() {
    final consoleMode = _consoleMode;
    if (consoleMode != null) {
      GgParallelLogWindowsConsole.restoreInputMode(consoleMode);
    }
    try {
      stdin.lineMode = _lineMode;
      stdin.echoMode = _echoMode;
    } on StdinException {
      // stdin is closed already, so there is no mode left to restore
    }
  }

  // ...........................................................................
  @override
  bool get isInteractive =>
      stdin.hasTerminal &&
      stdout.hasTerminal &&
      stdout.supportsAnsiEscapes &&
      Platform.environment['TERM'] != 'dumb';

  @override
  int get width => stdout.hasTerminal ? stdout.terminalColumns : 80;

  @override
  int get height => stdout.hasTerminal ? stdout.terminalLines : 24;

  @override
  Stream<String> get input =>
      stdin.transform(const Utf8Decoder(allowMalformed: true));

  @override
  Stream<void> get interrupts => ProcessSignal.sigint.watch();

  // ######################
  // Private
  // ######################

  bool _echoMode = true;
  bool _lineMode = true;
  int? _consoleMode;
}
