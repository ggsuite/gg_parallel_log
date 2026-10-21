// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'gg_parallel_log_text.dart';

// #############################################################################
/// One line written to a lane of a parallel log.
class GgParallelLogLine {
  /// Creates a line with [text] logged [time] after the lane started.
  GgParallelLogLine({
    required this.text,
    required this.time,
    this.isError = false,
  });

  /// Creates an example line for tests and docs.
  factory GgParallelLogLine.example({
    String? text,
    Duration? time,
    bool? isError,
  }) => GgParallelLogLine(
    text: text ?? '00:03 +12: All tests passed!',
    time: time ?? const Duration(seconds: 3),
    isError: isError ?? false,
  );

  // ...........................................................................
  /// The text of the line, without line breaks but possibly with colors.
  final String text;

  /// The time since the lane started.
  final Duration time;

  /// Whether the line was written to the error output.
  final bool isError;

  /// The text without colors and in lower case, as searches compare it.
  late final String searchText = GgParallelLogText.stripAnsi(text)
      .toLowerCase();
}
