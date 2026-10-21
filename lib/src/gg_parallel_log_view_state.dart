// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'gg_parallel_log_lane.dart';
import 'gg_parallel_log_status.dart';

// #############################################################################
/// The views the interactive log can show.
enum GgParallelLogMode {
  /// The inline list of all lanes
  overview,

  /// The fullscreen output of one lane
  detail,

  /// The detail view while the user types a search query
  search,
}

// #############################################################################
/// The actions that wait for the user to press their key a second time.
enum GgParallelLogConfirm {
  /// Nothing waits for a confirmation
  none,

  /// The selected lane is cancelled when x is pressed again
  cancelLane,

  /// All lanes are cancelled when q is pressed again
  cancelAll,
}

// #############################################################################
/// What the interactive log currently shows; changed by copying.
class GgParallelLogViewState {
  /// Creates a state; the defaults show the overview of all lanes.
  const GgParallelLogViewState({
    this.mode = GgParallelLogMode.overview,
    this.selected = 0,
    this.errorsOnly = false,
    this.scroll = 0,
    this.query = '',
    this.input = '',
    this.match = -1,
    this.notice = '',
    this.confirm = GgParallelLogConfirm.none,
  });

  /// Creates an example state for tests and docs.
  factory GgParallelLogViewState.example({
    GgParallelLogMode? mode,
    int? selected,
    bool? errorsOnly,
    int? scroll,
    String? query,
  }) => GgParallelLogViewState(
    mode: mode ?? GgParallelLogMode.overview,
    selected: selected ?? 0,
    errorsOnly: errorsOnly ?? false,
    scroll: scroll ?? 0,
    query: query ?? '',
  );

  // ...........................................................................
  /// Returns a copy with the given values replaced.
  GgParallelLogViewState copyWith({
    GgParallelLogMode? mode,
    int? selected,
    bool? errorsOnly,
    int? scroll,
    String? query,
    String? input,
    int? match,
    String? notice,
    GgParallelLogConfirm? confirm,
  }) => GgParallelLogViewState(
    mode: mode ?? this.mode,
    selected: selected ?? this.selected,
    errorsOnly: errorsOnly ?? this.errorsOnly,
    scroll: scroll ?? this.scroll,
    query: query ?? this.query,
    input: input ?? this.input,
    match: match ?? this.match,
    notice: notice ?? this.notice,
    confirm: confirm ?? this.confirm,
  );

  // ...........................................................................
  /// Returns the lanes the overview lists, honoring [errorsOnly].
  List<GgParallelLogLane> visibleLanes(List<GgParallelLogLane> lanes) =>
      errorsOnly
      ? lanes.where((l) => l.status == GgParallelLogStatus.error).toList()
      : lanes;

  // ...........................................................................
  /// The view shown.
  final GgParallelLogMode mode;

  /// The index of the selected lane within the visible lanes.
  final int selected;

  /// True when the overview lists failed lanes only.
  final bool errorsOnly;

  /// The number of lines the detail view is scrolled up from the end.
  final int scroll;

  /// The confirmed search query.
  final String query;

  /// The search query the user is typing.
  final String input;

  /// The line index of the current search match, or -1.
  final int match;

  /// A message shown in the footer until the next key.
  final String notice;

  /// The action that waits for a confirmation.
  final GgParallelLogConfirm confirm;
}
