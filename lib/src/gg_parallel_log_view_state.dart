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
  /// The inline list of all lanes.
  overview,

  /// The fullscreen output of one lane.
  detail,

  /// The detail view while the user types a search query.
  search,
}

// #############################################################################
/// The actions that wait for the user to press their key a second time.
enum GgParallelLogConfirm {
  /// Nothing waits for a confirmation.
  none,

  /// The selected lane is cancelled when x is pressed again.
  cancelLane,

  /// All lanes are cancelled when q is pressed again.
  cancelAll,
}

// #############################################################################
/// How a notice in the footer is meant, which decides its color.
enum GgParallelLogNoticeKind {
  /// A neutral message, e.g. where a log was saved.
  info,

  /// A warning, e.g. that lanes were cancelled.
  warning,

  /// An error, e.g. that a log could not be saved.
  error,
}

// #############################################################################
/// Everything the interactive log shows besides the lanes; changed by copying.
class GgParallelLogViewState {
  /// Creates a state; the defaults show the overview of all lanes.
  const GgParallelLogViewState({
    this.mode = GgParallelLogMode.overview,
    this.selected,
    this.errorsOnly = false,
    this.top,
    this.query = '',
    this.input = '',
    this.match,
    this.notice = '',
    this.noticeKind = GgParallelLogNoticeKind.info,
    this.confirm = GgParallelLogConfirm.none,
    this.interrupted = false,
  });

  /// Creates an example state for tests and docs.
  factory GgParallelLogViewState.example({
    GgParallelLogMode? mode,
    String? selected,
    bool? errorsOnly,
    int? top,
    String? query,
    String? input,
    int? match,
    String? notice,
    GgParallelLogNoticeKind? noticeKind,
    GgParallelLogConfirm? confirm,
    bool? interrupted,
  }) => GgParallelLogViewState(
    mode: mode ?? GgParallelLogMode.overview,
    selected: selected ?? 'gg_log',
    errorsOnly: errorsOnly ?? false,
    top: top,
    query: query ?? '',
    input: input ?? '',
    match: match,
    notice: notice ?? '',
    noticeKind: noticeKind ?? GgParallelLogNoticeKind.info,
    confirm: confirm ?? GgParallelLogConfirm.none,
    interrupted: interrupted ?? false,
  );

  // ...........................................................................
  /// Returns a copy with the given values replaced.
  ///
  /// Pass `following: true` to clear [top], `noMatch: true` to clear [match].
  GgParallelLogViewState copyWith({
    GgParallelLogMode? mode,
    String? selected,
    bool? errorsOnly,
    int? top,
    bool following = false,
    String? query,
    String? input,
    int? match,
    bool noMatch = false,
    String? notice,
    GgParallelLogNoticeKind? noticeKind,
    GgParallelLogConfirm? confirm,
    bool? interrupted,
  }) => GgParallelLogViewState(
    mode: mode ?? this.mode,
    selected: selected ?? this.selected,
    errorsOnly: errorsOnly ?? this.errorsOnly,
    top: following ? null : top ?? this.top,
    query: query ?? this.query,
    input: input ?? this.input,
    match: noMatch ? null : match ?? this.match,
    notice: notice ?? this.notice,
    noticeKind: noticeKind ?? (notice == null ? this.noticeKind : _info),
    confirm: confirm ?? this.confirm,
    interrupted: interrupted ?? this.interrupted,
  );

  // ...........................................................................
  /// Returns the lanes the views list, honoring [errorsOnly].
  List<GgParallelLogLane> visibleLanes(List<GgParallelLogLane> lanes) =>
      errorsOnly
      ? lanes.where((l) => l.status == GgParallelLogStatus.error).toList()
      : lanes;

  // ...........................................................................
  /// Returns the position of the [selected] lane in [visible], or 0.
  int selectedIndex(List<GgParallelLogLane> visible) {
    final index = visible.indexWhere((lane) => lane.name == selected);
    return index < 0 ? 0 : index;
  }

  // ...........................................................................
  /// The view shown.
  final GgParallelLogMode mode;

  /// The name of the selected lane, or null before there is one.
  final String? selected;

  /// Whether the views list the failed lanes only.
  final bool errorsOnly;

  /// The first output line the detail view shows, or null to follow the end.
  final int? top;

  /// The confirmed search query.
  final String query;

  /// The search query the user is typing.
  final String input;

  /// The index of the line of the current search match, or null.
  final int? match;

  /// The message shown in the footer until the next key.
  final String notice;

  /// How the [notice] is meant.
  final GgParallelLogNoticeKind noticeKind;

  /// The action that waits for a confirmation.
  final GgParallelLogConfirm confirm;

  /// Whether Ctrl+C cancelled all lanes once; the next one aborts.
  final bool interrupted;

  /// The query to highlight: the input while typing, else the query.
  String get activeQuery => mode == GgParallelLogMode.search ? input : query;

  // ######################
  // Private
  // ######################

  static const GgParallelLogNoticeKind _info = GgParallelLogNoticeKind.info;
}
