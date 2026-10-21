// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:math';

import 'package:gg_console_colors/gg_console_colors.dart';

import 'gg_parallel_log_lane.dart';
import 'gg_parallel_log_overview.dart';
import 'gg_parallel_log_saver.dart';
import 'gg_parallel_log_status.dart';
import 'gg_parallel_log_text.dart';

// #############################################################################
/// Builds what stays in the scrollback once all lanes are done.
///
/// Lists every lane and repeats the last lines of each failed lane, so no
/// error gets lost when the interactive view disappears.
class GgParallelLogSummary {
  /// Creates the summary of [lanes]; failed lanes show [tail] lines.
  GgParallelLogSummary({
    required this.title,
    required this.lanes,
    this.elapsed = Duration.zero,
    this.width = 80,
    this.tail = 40,
    GgParallelLogSaver? saver,
  }) : saver = saver ?? GgParallelLogSaver();

  /// Creates an example summary for tests and docs.
  factory GgParallelLogSummary.example({
    List<GgParallelLogLane>? lanes,
    int? tail,
    GgParallelLogSaver? saver,
  }) => GgParallelLogSummary(
    title: 'gg do publish',
    lanes: lanes ?? [GgParallelLogLane.example()],
    tail: tail ?? 40,
    saver: saver,
  );

  // ...........................................................................
  /// Returns the summary, ending with a line break.
  ///
  /// The failed lanes come first, so the result stays in sight at the end.
  String text() {
    final nameWidth = GgParallelLogOverview.nameWidth(lanes);
    final lines = [
      for (final lane in lanes)
        if (lane.status == GgParallelLogStatus.error) ..._failed(lane),
      ' ${bold(title)} · ${GgParallelLogOverview.counts(lanes)} · '
          '${GgParallelLogText.duration(elapsed)}',
      for (final lane in lanes)
        GgParallelLogOverview.row(lane, nameWidth: nameWidth),
    ];
    return '${lines.join('\n')}\n';
  }

  // ...........................................................................
  /// The title shown in the first line.
  final String title;

  /// The lanes to summarize.
  final List<GgParallelLogLane> lanes;

  /// The time all lanes took together.
  final Duration elapsed;

  /// The number of terminal columns.
  final int width;

  /// The number of lines repeated for each failed lane.
  final int tail;

  /// Saves the full output of failed lanes that is longer than [tail].
  final GgParallelLogSaver saver;

  // ######################
  // Private
  // ######################

  // ...........................................................................
  List<String> _failed(GgParallelLogLane lane) {
    final lines = lane.lines;
    final skipped = max(0, lines.length - tail);
    final rule = '─' * max(3, min(width, 80) - lane.name.length - 6);
    return [
      ' ${lane.status.icon(0)} ${bold(lane.name)} ${darkGray(rule)}',
      if (skipped > 0)
        darkGray(
          '   … $skipped earlier lines · full log: ${saver.save(lane).path}',
        ),
      for (final line in lines.skip(skipped))
        '   ${darkGray(GgParallelLogText.duration(line.time))} '
            '${darkGray('│')} '
            '${line.isError ? cError(line.text) : line.text}',
      '',
    ];
  }
}
