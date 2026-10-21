// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_console_colors/gg_console_colors.dart';

// #############################################################################
/// The state a lane of a parallel log is in.
enum GgParallelLogStatus {
  /// The lane is known but its task has not started yet
  waiting,

  /// The task of the lane is running
  running,

  /// The task completed successfully
  success,

  /// The task failed
  error,

  /// The lane was cancelled
  cancelled;

  // ...........................................................................
  /// Returns true when the lane will not change any more.
  bool get isDone => index >= success.index;

  // ...........................................................................
  /// Returns the colored icon, animated with [frame] while running.
  String icon(int frame) => switch (this) {
    waiting => darkGray('○'),
    running => cyan(spinner[frame % spinner.length]),
    success => cSuccess('✓'),
    error => cError('✗'),
    cancelled => cWarn('⊘'),
  };

  // ...........................................................................
  /// The frames of the spinner shown while a lane is running.
  static const List<String> spinner = [
    '⠋',
    '⠙',
    '⠹',
    '⠸',
    '⠼',
    '⠴',
    '⠦',
    '⠧',
    '⠇',
    '⠏',
  ];
}
