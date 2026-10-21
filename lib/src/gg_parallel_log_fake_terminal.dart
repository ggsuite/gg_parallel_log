// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:async';
import 'dart:math';

import 'gg_parallel_log_terminal.dart';
import 'gg_parallel_log_text.dart';

// #############################################################################
/// A terminal in memory: records the output, shows the screen, presses keys.
class GgParallelLogFakeTerminal implements GgParallelLogTerminal {
  /// Creates a terminal of [width] x [height] that is [isInteractive].
  ///
  /// [inputTaken] and [supportsRawMode] simulate a terminal in trouble.
  GgParallelLogFakeTerminal({
    this._width = 80,
    this._height = 24,
    this.isInteractive = true,
    this.inputTaken = false,
    this.supportsRawMode = true,
  });

  /// Creates an example terminal for tests and docs.
  factory GgParallelLogFakeTerminal.example({
    int? width,
    int? height,
    bool? isInteractive,
    bool? inputTaken,
    bool? supportsRawMode,
  }) => GgParallelLogFakeTerminal(
    width: width ?? 80,
    height: height ?? 24,
    isInteractive: isInteractive ?? true,
    inputTaken: inputTaken ?? false,
    supportsRawMode: supportsRawMode ?? true,
  );

  // ...........................................................................
  @override
  void write(String text) {
    _output.write(text);
    _emulate(text);
  }

  // ...........................................................................
  @override
  bool enableRawMode() => _isRawMode = supportsRawMode;

  // ...........................................................................
  @override
  void disableRawMode() => _isRawMode = false;

  // ...........................................................................
  /// Sends the raw key [input] as if the user typed it.
  void type(String input) => _input.add(input);

  // ...........................................................................
  /// Simulates a Ctrl+C signal.
  void interrupt() => _interrupts.add(null);

  // ...........................................................................
  /// Simulates a request to terminate with the exit [code].
  void terminate([int code = 143]) => _terminations.add(code);

  // ...........................................................................
  /// Changes the size of the terminal.
  void resize({int? width, int? height}) {
    _width = width ?? _width;
    _height = height ?? _height;
  }

  // ...........................................................................
  /// Forgets the output recorded so far, but keeps the screen.
  void clear() => _output.clear();

  // ...........................................................................
  @override
  final bool isInteractive;

  /// Whether listening to [input] fails because someone else listens.
  final bool inputTaken;

  /// Whether [enableRawMode] succeeds.
  final bool supportsRawMode;

  @override
  int get width => _width;

  @override
  int get height => _height;

  @override
  Stream<String> get input {
    if (inputTaken) throw StateError('Stream has already been listened to.');
    return _input.stream;
  }

  @override
  Stream<void> get interrupts => _interrupts.stream;

  @override
  Stream<int> get terminations => _terminations.stream;

  /// Everything written since the last [clear].
  String get output => _output.toString();

  /// Whether the raw mode is enabled.
  bool get isRawMode => _isRawMode;

  /// The lines the user sees, without colors and trailing empty lines.
  ///
  /// Understands line breaks, cursor up, erasing and the fullscreen buffer.
  List<String> get screen {
    final rows = _isFullscreen ? _fullscreenRows : _rows;
    final lines = rows.map((row) => row.toString()).toList();
    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    return lines;
  }

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
  final StreamController<int> _terminations = StreamController.broadcast(
    sync: true,
  );

  final List<StringBuffer> _rows = [StringBuffer()];
  final List<StringBuffer> _fullscreenRows = [StringBuffer()];
  bool _isFullscreen = false;
  int _row = 0;
  int _fullscreenRow = 0;

  static final RegExp _token = RegExp(
    r'\x1B\[\?(\d+)([hl])|\x1B\[([\d;]*)([A-Za-z])'
    r'|\r\n|\r|\n|[^\x1B\r\n]+|\x1B',
  );

  // ...........................................................................
  void _emulate(String text) {
    for (final match in _token.allMatches(text)) {
      final token = match[0]!;
      if (match[1] != null) {
        _mode(int.parse(match[1]!), on: match[2] == 'h');
      } else if (match[4] != null) {
        _csi(int.tryParse(match[3]!) ?? 0, match[4]!);
      } else if (token == '\r') {
        _setRow(_currentRow);
      } else if (token == '\n' || token == '\r\n') {
        _setRow(_currentRow + 1);
      } else if (token != '\x1B') {
        _lines[_currentRow].write(GgParallelLogText.stripAnsi(token));
      }
    }
  }

  // ...........................................................................
  List<StringBuffer> get _lines => _isFullscreen ? _fullscreenRows : _rows;

  int get _currentRow => _isFullscreen ? _fullscreenRow : _row;

  // ...........................................................................
  /// Moves the cursor to [row]; writing then replaces the rest of the row.
  void _setRow(int row) {
    final lines = _lines;
    while (lines.length <= row) {
      lines.add(StringBuffer());
    }
    if (_isFullscreen) {
      _fullscreenRow = row;
    } else {
      _row = row;
    }
    lines[row].clear();
  }

  // ...........................................................................
  void _mode(int mode, {required bool on}) {
    if (mode != 1049) return;
    _isFullscreen = on;
    if (!on) return;
    _fullscreenRows
      ..clear()
      ..add(StringBuffer());
    _fullscreenRow = 0;
  }

  // ...........................................................................
  void _csi(int count, String command) {
    final lines = _lines;
    switch (command) {
      case 'A':
        _setRow(max(0, _currentRow - max(1, count)));
      case 'H':
        _setRow(0);
      case 'J':
        lines.removeRange(_currentRow + 1, lines.length);
        if (count == 2) {
          lines.clear();
          lines.add(StringBuffer());
          _setRow(0);
        }
    }
  }
}
