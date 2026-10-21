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
import 'gg_parallel_log_viewport.dart';

// #############################################################################
/// Builds the fullscreen view of one lane with its complete output.
class GgParallelLogDetail {
  /// Creates the view of [lane], the lane [index] of [count] lanes.
  ///
  /// [matches] are the line indices that contain the current query.
  const GgParallelLogDetail({
    required this.lane,
    this.state = const GgParallelLogViewState(mode: GgParallelLogMode.detail),
    this.keymap = const GgParallelLogKeymap(),
    this.matches = const [],
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
    List<int>? matches,
    int? index,
    int? count,
    int? width,
    int? height,
    int? frame,
  }) => GgParallelLogDetail(
    lane: lane ?? GgParallelLogLane.example(),
    state:
        state ?? const GgParallelLogViewState(mode: GgParallelLogMode.detail),
    matches: matches ?? const [],
    index: index ?? 0,
    count: count ?? 1,
    width: width ?? 80,
    height: height ?? 24,
    frame: frame ?? 0,
  );

  // ...........................................................................
  /// Returns at most [height] lines, each narrower than the terminal.
  List<String> lines() {
    final w = width - 1;
    final body = GgParallelLogViewport.bodyHeight(height);
    final total = lane.lines.length;
    final window = GgParallelLogViewport.firstLine(total, state.top, height);
    final end = min(total, window + body);
    final lines = [
      GgParallelLogText.spread(
        _title(),
        darkGray('lane ${index + 1}/$count'),
        w,
      ),
      darkGray('─' * w),
      for (var i = window; i < end; i++) _line(i),
      for (var i = end - window; i < body; i++) '',
      _position(window, end, w),
      _footer(),
    ];
    return [
      for (final line in lines.take(max(1, height)))
        GgParallelLogText.truncate(line, w),
    ];
  }

  // ...........................................................................
  /// The lane shown.
  final GgParallelLogLane lane;

  /// What the user scrolled to and searched for.
  final GgParallelLogViewState state;

  /// The keys whose hints the footer lists.
  final GgParallelLogKeymap keymap;

  /// The indices of the lines that contain the query.
  final List<int> matches;

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
  String _title() =>
      ' ${lane.status.icon(frame)} ${bold(lane.name)}  '
      '${darkGray('${lane.status.name} · '
      '${GgParallelLogText.duration(lane.elapsed)}')}';

  // ...........................................................................
  String _line(int index) => GgParallelLogFormat.output(
    lane.lines[index],
    prefix: index == state.match ? '${cyan('❯')} ' : '  ',
    query: state.activeQuery,
  );

  // ...........................................................................
  String _position(int start, int end, int w) {
    final total = lane.lines.length;
    final following = state.top == null ? ' · following' : '';
    final info = total == 0
        ? ' no output yet '
        : ' ${start + 1}–$end of $total$following ';
    final rest = max(0, w - 2 - GgParallelLogText.visibleWidth(info));
    return darkGray('──$info${'─' * rest}');
  }

  // ...........................................................................
  String _footer() {
    if (state.mode == GgParallelLogMode.search) {
      final found = GgParallelLogFormat.plural(
        matches.length,
        'match',
        'matches',
      );
      return GgParallelLogText.spread(
        ' ${cyan('/')}${state.input}▏',
        darkGray('$found · ⏎ search · Esc cancel'),
        width - 1,
      );
    }
    if (state.notice.isNotEmpty) {
      return ' ${GgParallelLogFormat.notice(state.notice, state.noticeKind)}';
    }
    if (state.confirm == GgParallelLogConfirm.cancelLane) {
      return cWarn(' Press x again to cancel ${lane.name}');
    }
    return darkGray(
      ' ${_matchInfo()}${keymap.hints(GgParallelLogMode.detail)}',
    );
  }

  // ...........................................................................
  String _matchInfo() {
    if (state.query.isEmpty) return '';
    final current = matches.indexOf(state.match ?? -1) + 1;
    return '"${state.query}" $current/${matches.length} · ';
  }
}
