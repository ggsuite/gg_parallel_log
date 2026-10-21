// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'gg_parallel_log_lane.dart';
import 'gg_parallel_log_status.dart';

// #############################################################################
/// Tells how the lanes of a parallel log ended.
class GgParallelLogResult {
  /// Creates a result listing the lane names by how they ended.
  const GgParallelLogResult({
    this.succeeded = const [],
    this.failed = const [],
    this.cancelled = const [],
    this.unfinished = const [],
  });

  /// Creates the result of [lanes] as they are now.
  factory GgParallelLogResult.of(List<GgParallelLogLane> lanes) {
    List<String> names(bool Function(GgParallelLogStatus) test) => [
      for (final lane in lanes)
        if (test(lane.status)) lane.name,
    ];
    return GgParallelLogResult(
      succeeded: names((s) => s == GgParallelLogStatus.success),
      failed: names((s) => s == GgParallelLogStatus.error),
      cancelled: names((s) => s == GgParallelLogStatus.cancelled),
      unfinished: names((s) => !s.isDone),
    );
  }

  /// Creates an example result for tests and docs.
  factory GgParallelLogResult.example({
    List<String>? succeeded,
    List<String>? failed,
    List<String>? cancelled,
    List<String>? unfinished,
  }) => GgParallelLogResult(
    succeeded: succeeded ?? const ['gg_log'],
    failed: failed ?? const ['gg_one'],
    cancelled: cancelled ?? const [],
    unfinished: unfinished ?? const [],
  );

  // ...........................................................................
  /// The lanes that completed successfully.
  final List<String> succeeded;

  /// The lanes that failed.
  final List<String> failed;

  /// The lanes that were cancelled.
  final List<String> cancelled;

  /// The lanes that were waiting or running when the log finished.
  final List<String> unfinished;

  /// Whether every lane completed successfully.
  bool get isSuccess =>
      failed.isEmpty && cancelled.isEmpty && unfinished.isEmpty;

  /// The exit code for the process: 0 on success, otherwise 1.
  int get exitCode => isSuccess ? 0 : 1;
}
