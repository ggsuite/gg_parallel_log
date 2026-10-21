// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:math';

import 'package:gg_console_colors/gg_console_colors.dart';

import 'gg_parallel_log_format.dart';
import 'gg_parallel_log_keymap.dart';
import 'gg_parallel_log_lane.dart';
import 'gg_parallel_log_text.dart';
import 'gg_parallel_log_view_state.dart';

// #############################################################################
/// Builds the inline overview: a header, one row per lane and a footer.
class GgParallelLogOverview {
  /// Creates the overview of [lanes] for a terminal of [width] x [height].
  const GgParallelLogOverview({
    required this.title,
    required this.lanes,
    this.state = const GgParallelLogViewState(),
    this.keymap = const GgParallelLogKeymap(),
    this.width = 80,
    this.height = 24,
    this.elapsed = Duration.zero,
    this.frame = 0,
  });

  /// Creates an example overview for tests and docs.
  factory GgParallelLogOverview.example({
    String? title,
    List<GgParallelLogLane>? lanes,
    GgParallelLogViewState? state,
    int? width,
    int? height,
    Duration? elapsed,
    int? frame,
  }) => GgParallelLogOverview(
    title: title ?? 'gg do publish',
    lanes: lanes ?? [GgParallelLogLane.example()],
    state: state ?? const GgParallelLogViewState(),
    width: width ?? 80,
    height: height ?? 24,
    elapsed: elapsed ?? Duration.zero,
    frame: frame ?? 0,
  );

  // ...........................................................................
  /// Returns the lines, each narrower and all lower than the terminal.
  List<String> lines() {
    final visible = state.visibleLanes(lanes);
    final rowCount = max(0, height - 3);
    final lines = [
      _header(),
      if (rowCount > 0) ..._rows(visible, rowCount),
      if (rowCount > 0) _footer(visible),
    ];
    return [
      for (final line in lines) GgParallelLogText.truncate(line, width - 1),
    ];
  }

  // ...........................................................................
  /// The title shown in the header.
  final String title;

  /// All lanes, also those hidden by a filter.
  final List<GgParallelLogLane> lanes;

  /// What the user selected and filtered.
  final GgParallelLogViewState state;

  /// The keys whose hints the footer lists.
  final GgParallelLogKeymap keymap;

  /// The number of terminal columns.
  final int width;

  /// The number of terminal rows.
  final int height;

  /// The time since the log started.
  final Duration elapsed;

  /// The frame of the spinner animation.
  final int frame;

  // ######################
  // Private
  // ######################

  static const GgParallelLogMode _overview = GgParallelLogMode.overview;

  // ...........................................................................
  String _header() => [
    ' ${bold(title)}',
    GgParallelLogFormat.counts(lanes),
    GgParallelLogText.duration(elapsed),
    if (state.errorsOnly) cWarn('errors only'),
  ].join(' · ');

  // ...........................................................................
  List<String> _rows(List<GgParallelLogLane> visible, int rowCount) {
    if (visible.isEmpty) {
      return [
        darkGray(state.errorsOnly ? '   No failed lanes' : '   No lanes'),
      ];
    }
    final selected = state.selectedIndex(visible);
    if (visible.length <= rowCount) {
      return _range(visible, 0, visible.length, selected);
    }
    final withMore = rowCount >= 3;
    final available = withMore ? rowCount - 2 : rowCount;
    final start = (selected - available ~/ 2).clamp(
      0,
      visible.length - available,
    );
    final end = start + available;
    final rows = _range(visible, start, end, selected);
    if (!withMore) return rows;
    return [_more('↑', start), ...rows, _more('↓', visible.length - end)];
  }

  // ...........................................................................
  List<String> _range(
    List<GgParallelLogLane> visible,
    int start,
    int end,
    int selected,
  ) {
    final nameWidth = GgParallelLogFormat.nameWidth(lanes);
    return [
      for (var i = start; i < end; i++)
        GgParallelLogFormat.row(
          visible[i],
          nameWidth: nameWidth,
          frame: frame,
          selected: i == selected,
        ),
    ];
  }

  // ...........................................................................
  static String _more(String arrow, int count) =>
      count == 0 ? '' : darkGray('   $arrow $count more');

  // ...........................................................................
  String _footer(List<GgParallelLogLane> visible) {
    if (state.notice.isNotEmpty) {
      return ' ${GgParallelLogFormat.notice(state.notice, state.noticeKind)}';
    }
    return switch (state.confirm) {
      GgParallelLogConfirm.cancelLane => cWarn(
        ' Press x again to cancel '
        '${visible.isEmpty ? '' : visible[state.selectedIndex(visible)].name}',
      ),
      GgParallelLogConfirm.cancelAll => cWarn(
        ' Press q again to cancel all running lanes',
      ),
      GgParallelLogConfirm.none => darkGray(
        ' ${keymap.hints(_overview, errorsOnly: state.errorsOnly)}',
      ),
    };
  }
}
