// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// #############################################################################
/// The operating system side of a terminal: its modes and pending keys.
///
/// Reading keys this way keeps Dart's stdin open for later prompts.
abstract interface class GgParallelLogConsole {
  // ...........................................................................
  /// Delivers keys without Enter, without echo and with Ctrl+C as a key.
  ///
  /// Returns false when the console cannot do that.
  bool enableRawMode();

  // ...........................................................................
  /// Restores the mode the console had before [enableRawMode].
  void disableRawMode();

  // ...........................................................................
  /// Returns the keys typed since the last call, without waiting.
  String read();
}
