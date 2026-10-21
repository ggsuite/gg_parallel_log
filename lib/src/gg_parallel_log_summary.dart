// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:math';

import 'package:gg_console_colors/gg_console_colors.dart';

import 'gg_parallel_log_format.dart';
import 'gg_parallel_log_lane.dart';
import 'gg_parallel_log_status.dart';
import 'gg_parallel_log_text.dart';

// #############################################################################
/// Builds what stays in the scrollback once all lanes are done.
///
/// Failed lanes come first with their last lines, the result table last.
class GgParallelLogSummary {
  /// Creates the summary of [lanes]; failed lanes show [tail] lines.
  ///
  /// [savedLogs] maps lane names to the files holding their full output.
  const GgParallelLogSummary({
    required this.title,
    required this.lanes,
    this.elapsed = Duration.zero,
    this.width = 80,
    this.tail = 40,
    this.savedLogs = const {},
  });

  /// Creates an example summary for tests and docs.
  factory GgParallelLogSummary.example({
    String? title,
    List<GgParallelLogLane>? lanes,
    Duration? elapsed,
    int? width,
    int? tail,
    Map<String, String>? savedLogs,
  }) => GgParallelLogSummary(
    title: title ?? 'gg do publish',
    lanes: lanes ?? [GgParallelLogLane.example()],
    elapsed: elapsed ?? Duration.zero,
    width: width ?? 80,
    tail: tail ?? 40,
    savedLogs: savedLogs ?? const {},
  );

  // ...........................................................................
  /// Returns the summary, ending with a line break.
  String text() {
    final nameWidth = GgParallelLogFormat.nameWidth(lanes);
    final lines = [
      for (final lane in lanes)
        if (lane.status == GgParallelLogStatus.error) ..._failed(lane),
      ' ${bold(title)} · ${GgParallelLogFormat.counts(lanes)} · '
          '${GgParallelLogText.duration(elapsed)}',
      for (final lane in lanes)
        GgParallelLogFormat.row(lane, nameWidth: nameWidth),
    ];
    return '${lines.join('\n')}\n';
  }

  // ...........................................................................
  /// The title shown above the result table.
  final String title;

  /// The lanes to summarize.
  final List<GgParallelLogLane> lanes;

  /// The time all lanes took together.
  final Duration elapsed;

  /// The number of terminal columns.
  final int width;

  /// The number of lines repeated for each failed lane.
  final int tail;

  /// The files holding the full output of lanes, by lane name.
  final Map<String, String> savedLogs;

  // ######################
  // Private
  // ######################

  // ...........................................................................
  List<String> _failed(GgParallelLogLane lane) {
    final lines = lane.lines;
    final skipped = max(0, lines.length - tail);
    final nameWidth = GgParallelLogText.visibleWidth(lane.name);
    final rule = '─' * max(3, min(width, 80) - nameWidth - 6);
    final saved = savedLogs[lane.name];
    final earlier = GgParallelLogFormat.plural(
      skipped,
      'earlier line',
      'earlier lines',
    );
    return [
      ' ${lane.status.icon(0)} ${bold(lane.name)} ${darkGray(rule)}',
      if (skipped > 0)
        darkGray('   … $earlier${saved == null ? '' : ' · full log: $saved'}'),
      for (final line in lines.skip(skipped))
        GgParallelLogFormat.output(line, prefix: '   '),
      '',
    ];
  }
}
