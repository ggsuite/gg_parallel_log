// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:async';

import 'gg_parallel_log_fake_terminal.dart';
import 'gg_parallel_log_terminal.dart';

// #############################################################################
/// Draws frames on a terminal: inline below the scrollback or in fullscreen.
///
/// Only writes what changed and restores the terminal on [close].
class GgParallelLogScreen {
  /// Creates a screen drawing on [terminal].
  GgParallelLogScreen({required this.terminal});

  /// Creates an example screen drawing on a fake terminal.
  factory GgParallelLogScreen.example({GgParallelLogTerminal? terminal}) =>
      GgParallelLogScreen(terminal: terminal ?? GgParallelLogFakeTerminal());

  // ...........................................................................
  /// Listens to the terminal, then switches it into raw mode.
  ///
  /// Throws, with the terminal untouched, when either fails.
  void open({
    required void Function(String input) onInput,
    required void Function() onInterrupt,
    required void Function(int code) onTerminate,
    required void Function(Object error) onError,
  }) {
    try {
      _subscriptions
        ..add(terminal.input.listen(onInput, onError: onError))
        ..add(
          terminal.interrupts.listen((_) => onInterrupt(), onError: onError),
        )
        ..add(terminal.terminations.listen(onTerminate, onError: onError));
      if (!terminal.enableRawMode()) {
        throw StateError('The terminal cannot deliver single keys.');
      }
    } catch (_) {
      _cancelSubscriptions();
      rethrow;
    }
    terminal.write(_hideCursor);
    _isOpen = true;
  }

  // ...........................................................................
  /// Draws [lines] inline, replacing the lines drawn before.
  void showInline(List<String> lines) {
    if (!_isOpen) return;
    _leaveFullscreen();
    final width = terminal.width;
    final frame = lines.join('\n');
    if (frame == _lastFrame && width == _blockWidth) return;
    terminal.write(
      '$_syncStart${_blockStart(width)}${_body(lines)}\x1B[J$_syncEnd',
    );
    _blockLines = lines.length;
    _blockWidth = width;
    _lastFrame = frame;
  }

  // ...........................................................................
  /// Draws [lines] in fullscreen, keeping the scrollback untouched.
  void showFullscreen(List<String> lines) {
    if (!_isOpen) return;
    if (!_isFullscreen) {
      terminal.write('\x1B[?1049h\x1B[2J');
      _isFullscreen = true;
      _lastFrame = null;
    }
    final frame = '${terminal.width}\n${lines.join('\n')}';
    if (frame == _lastFrame) return;
    terminal.write('$_syncStart\x1B[H${_body(lines)}\x1B[J$_syncEnd');
    _lastFrame = frame;
  }

  // ...........................................................................
  /// Restores the terminal and leaves [summary] where the frames were.
  void close(String summary) {
    if (!_isOpen) return;
    _isOpen = false;
    // Windows closes stdin on cancel, so restore its mode before.
    terminal.disableRawMode();
    _cancelSubscriptions();
    _leaveFullscreen();
    terminal.write('${_blockStart(terminal.width)}\x1B[J$summary$_showCursor');
  }

  // ...........................................................................
  /// The terminal drawn on.
  final GgParallelLogTerminal terminal;

  /// Whether the screen is open, i.e. between [open] and [close].
  bool get isOpen => _isOpen;

  /// Whether the screen shows a fullscreen frame.
  bool get isFullscreen => _isFullscreen;

  // ######################
  // Private
  // ######################

  static const String _hideCursor = '\x1B[?25l';
  static const String _showCursor = '\x1B[?25h';
  static const String _syncStart = '\x1B[?2026h';
  static const String _syncEnd = '\x1B[?2026l';

  final List<StreamSubscription<Object?>> _subscriptions = [];
  bool _isOpen = false;
  bool _isFullscreen = false;
  int _blockLines = 0;
  int _blockWidth = 0;
  String? _lastFrame;

  // ...........................................................................
  void _cancelSubscriptions() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
  }

  // ...........................................................................
  void _leaveFullscreen() {
    if (!_isFullscreen) return;
    terminal.write('\x1B[?1049l');
    _isFullscreen = false;
    _lastFrame = null;
  }

  // ...........................................................................
  /// Returns how to get to the first row of the inline block.
  ///
  /// After a width change terminals rewrap differently, so it starts over.
  String _blockStart(int width) {
    if (_blockLines == 0) return '';
    if (width != _blockWidth) return '\x1B[H\x1B[2J';
    return _blockLines > 1 ? '\r\x1B[${_blockLines - 1}A' : '\r';
  }

  // ...........................................................................
  static String _body(List<String> lines) =>
      lines.map((line) => '$line\x1B[K').join('\r\n');
}
