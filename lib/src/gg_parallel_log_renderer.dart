// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'gg_parallel_log_lane.dart';
import 'gg_parallel_log_line.dart';

// #############################################################################
/// Shows the lanes of a parallel log on a terminal.
abstract interface class GgParallelLogRenderer {
  // ...........................................................................
  /// Is called once before the first lane shows up.
  void start();

  // ...........................................................................
  /// Is called when [lane] got a new [line] or, with a null line, a status.
  void laneChanged(GgParallelLogLane lane, GgParallelLogLine? line);

  // ...........................................................................
  /// Removes the live view and leaves [summary] on the terminal.
  Future<void> finish(String summary);
}
