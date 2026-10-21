// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:async';

import 'gg_parallel_log_terminal.dart';

// #############################################################################
/// A terminal in memory: records the output and lets tests press keys.
class GgParallelLogFakeTerminal implements GgParallelLogTerminal {
  /// Creates a terminal of [width] x [height] that is [isInteractive].
  GgParallelLogFakeTerminal({
    this._width = 80,
    this._height = 24,
    this.isInteractive = true,
  });

  /// Creates an example terminal for tests and docs.
  factory GgParallelLogFakeTerminal.example({
    int? width,
    int? height,
    bool? isInteractive,
  }) => GgParallelLogFakeTerminal(
    width: width ?? 80,
    height: height ?? 24,
    isInteractive: isInteractive ?? true,
  );

  // ...........................................................................
  @override
  void write(String text) => _output.write(text);

  // ...........................................................................
  @override
  void enableRawMode() => _isRawMode = true;

  // ...........................................................................
  @override
  void disableRawMode() => _isRawMode = false;

  // ...........................................................................
  /// Sends the raw key [input] as if the user typed it.
  void type(String input) => _input.add(input);

  // ...........................................................................
  /// Simulates Ctrl+C.
  void interrupt() => _interrupts.add(null);

  // ...........................................................................
  /// Changes the size of the terminal.
  void resize({int? width, int? height}) {
    _width = width ?? _width;
    _height = height ?? _height;
  }

  // ...........................................................................
  /// Forgets the output recorded so far.
  void clear() => _output.clear();

  // ...........................................................................
  @override
  final bool isInteractive;

  @override
  int get width => _width;

  @override
  int get height => _height;

  @override
  Stream<String> get input => _input.stream;

  @override
  Stream<void> get interrupts => _interrupts.stream;

  /// Everything written so far.
  String get output => _output.toString();

  /// True while the raw mode is enabled.
  bool get isRawMode => _isRawMode;

  // ######################
  // Private
  // ######################

  int _width;
  int _height;
  bool _isRawMode = false;
  final StringBuffer _output = StringBuffer();
  final StreamController<String> _input = StreamController.broadcast(
    sync: true,
  );
  final StreamController<void> _interrupts = StreamController.broadcast(
    sync: true,
  );
}
