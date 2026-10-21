// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// #############################################################################
/// Is thrown by `GgParallelLog.run` when the lane was cancelled.
class GgParallelLogCancelledException implements Exception {
  /// Creates the exception for the lane called [lane].
  const GgParallelLogCancelledException(this.lane);

  /// Creates an example exception for tests and docs.
  factory GgParallelLogCancelledException.example({String? lane}) =>
      GgParallelLogCancelledException(lane ?? 'gg_log');

  // ...........................................................................
  @override
  String toString() => 'Lane "$lane" was cancelled.';

  // ...........................................................................
  /// The name of the cancelled lane.
  final String lane;
}
