// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// #############################################################################
/// The terminal a parallel log draws on and reads keys from.
abstract interface class GgParallelLogTerminal {
  // ...........................................................................
  /// True when the terminal can show the interactive view.
  bool get isInteractive;

  /// The number of columns.
  int get width;

  /// The number of rows.
  int get height;

  /// The raw key input of the terminal.
  Stream<String> get input;

  /// Emits whenever the user presses Ctrl+C.
  Stream<void> get interrupts;

  // ...........................................................................
  /// Writes [text] as it is, escape sequences included.
  void write(String text);

  // ...........................................................................
  /// Delivers every key immediately and stops echoing it.
  void enableRawMode();

  // ...........................................................................
  /// Restores the mode the terminal had before [enableRawMode].
  void disableRawMode();
}
