// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:math';

import 'package:gg_console_colors/gg_console_colors.dart';

import 'gg_parallel_log_lane.dart';
import 'gg_parallel_log_status.dart';
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
  }) => GgParallelLogOverview(
    title: title ?? 'gg do publish',
    lanes: lanes ?? [GgParallelLogLane.example()],
    state: state ?? const GgParallelLogViewState(),
    width: width ?? 80,
    height: height ?? 24,
  );

  // ...........................................................................
  /// Returns the lines, each narrower than the terminal.
  List<String> lines() {
    final visible = state.visibleLanes(lanes);
    return [
      _header(),
      ..._rows(visible),
      _footer(visible),
    ].map((line) => GgParallelLogText.truncate(line, width - 1)).toList();
  }

  // ...........................................................................
  /// Returns one row showing [lane], used by the overview and the summary.
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
  /// Returns the width of the name column for [lanes].
  static int nameWidth(List<GgParallelLogLane> lanes) =>
      lanes.fold(4, (w, lane) => max(w, lane.name.length)).clamp(4, 28);

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
  /// The title shown in the header.
  final String title;

  /// All lanes, also those hidden by a filter.
  final List<GgParallelLogLane> lanes;

  /// What the user selected and filtered.
  final GgParallelLogViewState state;

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

  // ...........................................................................
  String _header() => [
    ' ${bold(title)}',
    counts(lanes),
    GgParallelLogText.duration(elapsed),
    if (state.errorsOnly) cWarn('errors only'),
  ].join(' · ');

  // ...........................................................................
  List<String> _rows(List<GgParallelLogLane> visible) {
    if (visible.isEmpty) {
      return [
        darkGray(state.errorsOnly ? '   No failed lanes' : '   No lanes'),
      ];
    }

    final maxRows = max(1, height - 3);
    if (visible.length <= maxRows) return _range(visible, 0, visible.length);

    final available = max(1, maxRows - 2);
    final start = (state.selected - available ~/ 2).clamp(
      0,
      visible.length - available,
    );
    final end = start + available;
    return [
      _more('↑', start),
      ..._range(visible, start, end),
      _more('↓', visible.length - end),
    ];
  }

  // ...........................................................................
  List<String> _range(List<GgParallelLogLane> visible, int start, int end) => [
    for (var i = start; i < end; i++)
      row(
        visible[i],
        nameWidth: nameWidth(lanes),
        frame: frame,
        selected: i == state.selected,
      ),
  ];

  // ...........................................................................
  static String _more(String arrow, int count) =>
      count == 0 ? '' : darkGray('   $arrow $count more');

  // ...........................................................................
  String _footer(List<GgParallelLogLane> visible) {
    if (state.notice.isNotEmpty) return ' ${state.notice}';
    final selected = visible.isEmpty ? '' : visible[state.selected].name;
    return switch (state.confirm) {
      GgParallelLogConfirm.cancelLane => cWarn(
        ' Press x again to cancel $selected',
      ),
      GgParallelLogConfirm.cancelAll => cWarn(
        ' Press q again to cancel all running lanes',
      ),
      GgParallelLogConfirm.none => darkGray(
        ' ↑↓ select · ⏎ open · '
        'f ${state.errorsOnly ? 'all lanes' : 'errors only'} · '
        'x cancel · s save · q cancel all',
      ),
    };
  }

  // ...........................................................................
  static String _summary(GgParallelLogLane lane) => switch (lane.status) {
    GgParallelLogStatus.waiting => darkGray('waiting'),
    GgParallelLogStatus.running => lane.lastLine,
    GgParallelLogStatus.success => darkGray(lane.lastLine),
    GgParallelLogStatus.error => cError(lane.lastLine),
    GgParallelLogStatus.cancelled => cWarn('cancelled'),
  };
}
