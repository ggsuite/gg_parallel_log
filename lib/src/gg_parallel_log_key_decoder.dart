// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'gg_parallel_log_key.dart';

// #############################################################################
/// Turns terminal input chunks into keys, joining sequences split by reads.
class GgParallelLogKeyDecoder {
  /// Creates a decoder without pending input.
  GgParallelLogKeyDecoder();

  /// Creates an example decoder for tests and docs.
  factory GgParallelLogKeyDecoder.example() => GgParallelLogKeyDecoder();

  // ...........................................................................
  /// Returns the complete keys of [chunk] and keeps an unfinished sequence.
  List<GgParallelLogKey> add(String chunk) {
    final input = '$_pending$chunk';
    final cut = _unfinishedStart(input);
    _pending = input.substring(cut);
    return GgParallelLogKey.parse(input.substring(0, cut));
  }

  // ...........................................................................
  /// Returns the keys of the pending input, read as they are, e.g. Escape.
  List<GgParallelLogKey> flush() {
    final keys = GgParallelLogKey.parse(_pending);
    _pending = '';
    return keys;
  }

  // ...........................................................................
  /// Whether an unfinished sequence waits for the next chunk.
  bool get hasPending => _pending.isNotEmpty;

  // ######################
  // Private
  // ######################

  String _pending = '';

  static final RegExp _unfinished = RegExp(r'\x1B(\[[0-?]*[ -/]*|O)?$');

  // ...........................................................................
  static int _unfinishedStart(String input) =>
      _unfinished.firstMatch(input)?.start ?? input.length;
}
