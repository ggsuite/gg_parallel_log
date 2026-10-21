// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:math';

import 'package:gg_console_colors/gg_console_colors.dart';

import 'gg_parallel_log_lane.dart';
import 'gg_parallel_log_line.dart';
import 'gg_parallel_log_text.dart';
import 'gg_parallel_log_view_state.dart';

// #############################################################################
/// Builds the fullscreen view of one lane with its complete output.
class GgParallelLogDetail {
  /// Creates the view of [lane], the lane [index] of [count] lanes.
  const GgParallelLogDetail({
    required this.lane,
    this.state = const GgParallelLogViewState(mode: GgParallelLogMode.detail),
    this.index = 0,
    this.count = 1,
    this.width = 80,
    this.height = 24,
    this.frame = 0,
  });

  /// Creates an example view for tests and docs.
  factory GgParallelLogDetail.example({
    GgParallelLogLane? lane,
    GgParallelLogViewState? state,
    int? width,
    int? height,
  }) => GgParallelLogDetail(
    lane: lane ?? GgParallelLogLane.example(),
    state:
        state ?? const GgParallelLogViewState(mode: GgParallelLogMode.detail),
    width: width ?? 80,
    height: height ?? 24,
  );

  // ...........................................................................
  /// Returns exactly [height] lines, each narrower than the terminal.
  List<String> lines() {
    final w = width - 1;
    final window = _window();
    return [
      GgParallelLogText.spread(
        _title(),
        darkGray('lane ${index + 1}/$count'),
        w,
      ),
      darkGray('─' * w),
      for (var i = window.start; i < window.end; i++) _line(i, lane.lines[i]),
      for (var i = window.end - window.start; i < bodyHeight(height); i++) '',
      _position(window, w),
      _footer(),
    ].map((line) => GgParallelLogText.truncate(line, w)).toList();
  }

  // ...........................................................................
  /// Returns the number of output lines a terminal of [height] rows shows.
  static int bodyHeight(int height) => max(1, height - 4);

  // ...........................................................................
  /// Returns the indices of the lines of [lane] that contain [query].
  static List<int> matches(GgParallelLogLane lane, String query) {
    if (query.isEmpty) return [];
    final lines = lane.lines;
    return [
      for (var i = 0; i < lines.length; i++)
        if (GgParallelLogText.contains(lines[i].text, query)) i,
    ];
  }

  // ...........................................................................
  /// The lane shown.
  final GgParallelLogLane lane;

  /// What the user scrolled to and searched for.
  final GgParallelLogViewState state;

  /// The position of the lane among the visible lanes.
  final int index;

  /// The number of visible lanes.
  final int count;

  /// The number of terminal columns.
  final int width;

  /// The number of terminal rows.
  final int height;

  /// The frame of the spinner animation.
  final int frame;

  // ######################
  // Private
  // ######################

  // ...........................................................................
  ({int start, int end}) _window() {
    final total = lane.lines.length;
    final body = bodyHeight(height);
    final scroll = min(max(0, state.scroll), max(0, total - body));
    final end = total - scroll;
    return (start: max(0, end - body), end: end);
  }

  // ...........................................................................
  String _title() =>
      ' ${lane.status.icon(frame)} ${bold(lane.name)}  '
      '${darkGray('${lane.status.name} · '
      '${GgParallelLogText.duration(lane.elapsed)}')}';

  // ...........................................................................
  String _line(int index, GgParallelLogLine line) {
    final gutter = index == state.match ? cyan('❯') : ' ';
    final time = darkGray(GgParallelLogText.duration(line.time));
    final query = _query;
    final hit =
        query.isNotEmpty && GgParallelLogText.contains(line.text, query);
    final plain = line.isError
        ? GgParallelLogText.stripAnsi(line.text)
        : line.text;
    final text = hit ? GgParallelLogText.highlight(plain, query) : plain;
    return '$gutter $time ${darkGray('│')} '
        '${line.isError ? cError(text) : text}';
  }

  // ...........................................................................
  /// The query to highlight: while typing the input, otherwise the query.
  String get _query =>
      state.mode == GgParallelLogMode.search ? state.input : state.query;

  // ...........................................................................
  String _position(({int start, int end}) window, int w) {
    final total = lane.lines.length;
    final following = state.scroll <= 0 ? ' · following' : '';
    final info = total == 0
        ? ' no output yet '
        : ' ${window.start + 1}–${window.end} of $total$following ';
    final rest = max(0, w - 2 - GgParallelLogText.visibleWidth(info));
    return darkGray('──$info${'─' * rest}');
  }

  // ...........................................................................
  String _footer() {
    if (state.mode == GgParallelLogMode.search) {
      final count = matches(lane, state.input).length;
      return GgParallelLogText.spread(
        ' ${cyan('/')}${state.input}▏',
        darkGray('$count matches · ⏎ search · Esc cancel'),
        width - 1,
      );
    }
    if (state.notice.isNotEmpty) return ' ${state.notice}';
    if (state.confirm == GgParallelLogConfirm.cancelLane) {
      return cWarn(' Press x again to cancel ${lane.name}');
    }
    return darkGray(
      ' ${_matchInfo()}↑↓ scroll · ←→ lane · / search · '
      'n N match · s save · x cancel · Esc back',
    );
  }

  // ...........................................................................
  String _matchInfo() {
    if (state.query.isEmpty) return '';
    final all = matches(lane, state.query);
    final current = all.indexOf(state.match) + 1;
    return '"${state.query}" $current/${all.length} · ';
  }
}
