// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:math';

import 'package:gg_console_colors/gg_console_colors.dart';

import 'gg_parallel_log_lane.dart';
import 'gg_parallel_log_line.dart';
import 'gg_parallel_log_status.dart';
import 'gg_parallel_log_text.dart';
import 'gg_parallel_log_view_state.dart';

// #############################################################################
/// Formats lanes and lines the same way in every view.
abstract final class GgParallelLogFormat {
  // ...........................................................................
  /// Returns one row showing [lane] with its name padded to [nameWidth].
  static String row(
    GgParallelLogLane lane, {
    required int nameWidth,
    int frame = 0,
    bool selected = false,
  }) {
    final marker = selected ? cyan('❯') : ' ';
    final name = GgParallelLogText.fit(lane.name, nameWidth);
    final time = lane.status == GgParallelLogStatus.waiting
        ? ''
        : GgParallelLogText.duration(lane.elapsed);
    return '$marker ${lane.status.icon(frame)} '
        '${selected ? bold(name) : name}  '
        '${darkGray(time.padLeft(5))}  ${_summary(lane)}';
  }

  // ...........................................................................
  /// Returns the width of the name column for [lanes], from 4 to 28.
  static int nameWidth(List<GgParallelLogLane> lanes) => lanes
      .fold(4, (w, lane) => max(w, GgParallelLogText.visibleWidth(lane.name)))
      .clamp(4, 28);

  // ...........................................................................
  /// Returns the colored counts of [lanes], e.g. `3/5 done · 1 failed`.
  static String counts(List<GgParallelLogLane> lanes) {
    int count(GgParallelLogStatus s) =>
        lanes.where((l) => l.status == s).length;
    final done = lanes.where((l) => l.status.isDone).length;
    final failed = count(GgParallelLogStatus.error);
    final cancelled = count(GgParallelLogStatus.cancelled);
    return [
      '$done/${lanes.length} done',
      if (failed > 0) cError('$failed failed'),
      if (cancelled > 0) cWarn('$cancelled cancelled'),
    ].join(' · ');
  }

  // ...........................................................................
  /// Returns [line] with its time behind [prefix] and [query] highlighted.
  static String output(
    GgParallelLogLine line, {
    String prefix = '',
    String query = '',
  }) {
    final plain = line.isError
        ? GgParallelLogText.stripAnsi(line.text)
        : line.text;
    final hit =
        query.isNotEmpty && line.searchText.contains(query.toLowerCase());
    final text = hit ? GgParallelLogText.highlight(plain, query) : plain;
    return '$prefix${darkGray(GgParallelLogText.duration(line.time))} '
        '${darkGray('│')} ${line.isError ? cError(text) : text}';
  }

  // ...........................................................................
  /// Returns [notice] colored by its [kind] and without line breaks.
  static String notice(String notice, GgParallelLogNoticeKind kind) {
    final text = GgParallelLogText.sanitize(notice.split('\n').first);
    return switch (kind) {
      GgParallelLogNoticeKind.info => text,
      GgParallelLogNoticeKind.warning => cWarn(text),
      GgParallelLogNoticeKind.error => cError(text),
    };
  }

  // ...........................................................................
  /// Returns [count] and the noun in singular or plural, e.g. `1 match`.
  static String plural(int count, String singular, String plural) =>
      '$count ${count == 1 ? singular : plural}';

  // ######################
  // Private
  // ######################

  // ...........................................................................
  static String _summary(GgParallelLogLane lane) => switch (lane.status) {
    GgParallelLogStatus.waiting => darkGray('waiting'),
    GgParallelLogStatus.running => lane.lastLine,
    GgParallelLogStatus.success => darkGray(lane.lastLine),
    GgParallelLogStatus.error => cError(lane.lastLine),
    GgParallelLogStatus.cancelled => cWarn('cancelled'),
  };
}
