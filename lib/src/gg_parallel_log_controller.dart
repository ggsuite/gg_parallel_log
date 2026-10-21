// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:math';

import 'gg_parallel_log_format.dart';
import 'gg_parallel_log_key.dart';
import 'gg_parallel_log_keymap.dart';
import 'gg_parallel_log_lane.dart';
import 'gg_parallel_log_search.dart';
import 'gg_parallel_log_text.dart';
import 'gg_parallel_log_view_state.dart';
import 'gg_parallel_log_viewport.dart';

// #############################################################################
/// The side effects the controller asks the renderer for.
enum GgParallelLogEffectType {
  /// Cancels the lane named in the effect.
  cancelLane,

  /// Cancels all lanes that are not done.
  cancelAll,

  /// Saves the output of the lane named in the effect.
  save,

  /// Ends the program after a second Ctrl+C.
  abort,
}

// #############################################################################
/// A side effect, e.g. cancelling a lane, with the lane it is about.
class GgParallelLogEffect {
  /// Creates an effect of [type], about the lane called [lane] if any.
  const GgParallelLogEffect({required this.type, this.lane});

  /// Creates an example effect for tests and docs.
  factory GgParallelLogEffect.example({
    GgParallelLogEffectType? type,
    String? lane,
  }) => GgParallelLogEffect(
    type: type ?? GgParallelLogEffectType.save,
    lane: lane ?? 'gg_log',
  );

  // ...........................................................................
  @override
  bool operator ==(Object other) =>
      other is GgParallelLogEffect && other.type == type && other.lane == lane;

  // ...........................................................................
  @override
  int get hashCode => Object.hash(type, lane);

  // ...........................................................................
  @override
  String toString() => '${type.name}(${lane ?? ''})';

  // ...........................................................................
  /// The kind of effect.
  final GgParallelLogEffectType type;

  /// The name of the lane the effect is about, or null.
  final String? lane;
}

// #############################################################################
/// The outcome of a key: the next state and the effects to perform.
class GgParallelLogUpdate {
  /// Creates an update to [state] with [effects].
  const GgParallelLogUpdate(this.state, {this.effects = const []});

  /// Creates an example update for tests and docs.
  factory GgParallelLogUpdate.example() =>
      const GgParallelLogUpdate(GgParallelLogViewState());

  // ...........................................................................
  /// The state after the key.
  final GgParallelLogViewState state;

  /// The effects the renderer performs.
  final List<GgParallelLogEffect> effects;
}

// #############################################################################
/// Turns keys into the next view state and effects; does no I/O.
class GgParallelLogController {
  /// Creates a controller reading keys with [keymap].
  GgParallelLogController({
    this.keymap = const GgParallelLogKeymap(),
    GgParallelLogSearch? search,
  }) : search = search ?? GgParallelLogSearch();

  /// Creates an example controller for tests and docs.
  factory GgParallelLogController.example() => GgParallelLogController();

  // ...........................................................................
  /// Returns [state] with a selection that exists among [lanes].
  ///
  /// Falls back to the overview when no lane is left to show.
  GgParallelLogViewState normalize(
    GgParallelLogViewState state,
    List<GgParallelLogLane> lanes,
  ) {
    final visible = state.visibleLanes(lanes);
    if (visible.isEmpty) {
      return state.mode == GgParallelLogMode.overview
          ? state
          : state.copyWith(mode: GgParallelLogMode.overview);
    }
    final selected = visible[state.selectedIndex(visible)].name;
    return selected == state.selected
        ? state
        : state.copyWith(selected: selected);
  }

  // ...........................................................................
  /// Returns the update [key] causes on a terminal of [height] rows.
  GgParallelLogUpdate handle(
    GgParallelLogViewState state,
    GgParallelLogKey key,
    List<GgParallelLogLane> lanes, {
    int height = 24,
  }) {
    if (key.type == GgParallelLogKeyType.ctrlC) return interrupt(state);
    final confirm = state.confirm;
    final s = normalize(
      state,
      lanes,
    ).copyWith(notice: '', confirm: GgParallelLogConfirm.none);
    final context = _Context(this, s, lanes, height, confirm);
    if (s.mode == GgParallelLogMode.search) return context.search(key);
    final action = keymap.action(s.mode, key);
    if (action == null) return GgParallelLogUpdate(s);
    return context.act(action);
  }

  // ...........................................................................
  /// Returns the update of Ctrl+C: cancel all lanes first, abort then.
  GgParallelLogUpdate interrupt(GgParallelLogViewState state) {
    if (state.interrupted) {
      return GgParallelLogUpdate(state, effects: [_effect(_Type.abort)]);
    }
    return GgParallelLogUpdate(
      state.copyWith(
        interrupted: true,
        notice: 'Cancelled all lanes · Ctrl+C again to exit',
        noticeKind: GgParallelLogNoticeKind.warning,
      ),
      effects: [_effect(_Type.cancelAll)],
    );
  }

  // ...........................................................................
  /// The keys and the actions they trigger.
  final GgParallelLogKeymap keymap;

  /// Finds the search matches, caching them per lane.
  final GgParallelLogSearch search;

  // ######################
  // Private
  // ######################

  // ...........................................................................
  static GgParallelLogEffect _effect(_Type type, [String? lane]) =>
      GgParallelLogEffect(type: type, lane: lane);
}

typedef _Type = GgParallelLogEffectType;

// #############################################################################
/// The state of a single key press while the controller handles it.
class _Context {
  _Context(this.controller, this.state, this.lanes, this.height, this.confirm)
    : visible = state.visibleLanes(lanes);

  final GgParallelLogController controller;
  final GgParallelLogViewState state;
  final List<GgParallelLogLane> lanes;
  final List<GgParallelLogLane> visible;
  final int height;
  final GgParallelLogConfirm confirm;

  // ...........................................................................
  int get _index => state.selectedIndex(visible);

  GgParallelLogLane? get _lane => visible.isEmpty ? null : visible[_index];

  int get _total => _lane?.lines.length ?? 0;

  int get _body => GgParallelLogViewport.bodyHeight(height);

  int get _first => GgParallelLogViewport.firstLine(_total, state.top, height);

  // ...........................................................................
  GgParallelLogUpdate act(GgParallelLogAction action) {
    final overview = state.mode == GgParallelLogMode.overview;
    return switch (action) {
      GgParallelLogAction.up => overview ? _select(-1) : _scrollTo(_first - 1),
      GgParallelLogAction.down => overview ? _select(1) : _scrollTo(_first + 1),
      GgParallelLogAction.pageUp => _scrollTo(_first - _body),
      GgParallelLogAction.pageDown => _scrollTo(_first + _body),
      GgParallelLogAction.first =>
        overview ? _select(-visible.length) : _scrollTo(0),
      GgParallelLogAction.last =>
        overview ? _select(visible.length) : _scrollTo(_total),
      GgParallelLogAction.open => _open(),
      GgParallelLogAction.back => _with(mode: GgParallelLogMode.overview),
      GgParallelLogAction.previousLane => _switchLane(-1),
      GgParallelLogAction.nextLane => _switchLane(1),
      GgParallelLogAction.toggleErrors => GgParallelLogUpdate(
        controller.normalize(
          state.copyWith(errorsOnly: !state.errorsOnly),
          lanes,
        ),
      ),
      GgParallelLogAction.cancel => _cancel(),
      GgParallelLogAction.cancelAll => _cancelAll(),
      GgParallelLogAction.save => _effect(GgParallelLogEffectType.save),
      GgParallelLogAction.search => GgParallelLogUpdate(
        state.copyWith(mode: GgParallelLogMode.search, input: ''),
      ),
      GgParallelLogAction.nextMatch => _jump(forward: true),
      GgParallelLogAction.previousMatch => _jump(forward: false),
    };
  }

  // ...........................................................................
  GgParallelLogUpdate search(GgParallelLogKey key) {
    final input = state.input;
    return switch (key.type) {
      GgParallelLogKeyType.escape => _with(mode: GgParallelLogMode.detail),
      GgParallelLogKeyType.enter => _confirmSearch(),
      GgParallelLogKeyType.backspace => GgParallelLogUpdate(
        state.copyWith(input: GgParallelLogText.dropLast(input)),
      ),
      GgParallelLogKeyType.char => GgParallelLogUpdate(
        state.copyWith(input: '$input${key.char}'),
      ),
      _ => GgParallelLogUpdate(state),
    };
  }

  // ...........................................................................
  GgParallelLogUpdate _with({required GgParallelLogMode mode}) =>
      GgParallelLogUpdate(state.copyWith(mode: mode));

  // ...........................................................................
  GgParallelLogUpdate _select(int delta) {
    if (visible.isEmpty) return GgParallelLogUpdate(state);
    final index = (_index + delta).clamp(0, visible.length - 1);
    return GgParallelLogUpdate(state.copyWith(selected: visible[index].name));
  }

  // ...........................................................................
  GgParallelLogUpdate _open() {
    if (visible.isEmpty) return GgParallelLogUpdate(state);
    return GgParallelLogUpdate(
      state.copyWith(
        mode: GgParallelLogMode.detail,
        following: true,
        noMatch: true,
      ),
    );
  }

  // ...........................................................................
  GgParallelLogUpdate _switchLane(int delta) {
    final selected = _select(delta).state;
    return GgParallelLogUpdate(
      selected.copyWith(following: true, noMatch: true),
    );
  }

  // ...........................................................................
  /// Shows the output from line [top] on; at the end it follows the output.
  GgParallelLogUpdate _scrollTo(int top) {
    final last = max(0, _total - _body);
    final first = max(0, top);
    if (first >= last) {
      return GgParallelLogUpdate(state.copyWith(following: true));
    }
    return GgParallelLogUpdate(state.copyWith(top: first));
  }

  // ...........................................................................
  GgParallelLogUpdate _cancel() {
    final lane = _lane;
    if (lane == null) return GgParallelLogUpdate(state);
    if (lane.status.isDone) {
      return GgParallelLogUpdate(
        state.copyWith(notice: '${lane.name} is already done'),
      );
    }
    if (confirm != GgParallelLogConfirm.cancelLane) {
      return GgParallelLogUpdate(
        state.copyWith(confirm: GgParallelLogConfirm.cancelLane),
      );
    }
    return GgParallelLogUpdate(
      state.copyWith(
        notice: 'Cancelled ${lane.name}',
        noticeKind: GgParallelLogNoticeKind.warning,
      ),
      effects: [GgParallelLogController._effect(_Type.cancelLane, lane.name)],
    );
  }

  // ...........................................................................
  GgParallelLogUpdate _cancelAll() {
    final running = lanes.where((lane) => !lane.status.isDone).length;
    if (running == 0) {
      return GgParallelLogUpdate(state.copyWith(notice: 'No running lanes'));
    }
    if (confirm != GgParallelLogConfirm.cancelAll) {
      return GgParallelLogUpdate(
        state.copyWith(confirm: GgParallelLogConfirm.cancelAll),
      );
    }
    return GgParallelLogUpdate(
      state.copyWith(
        notice:
            'Cancelled ${GgParallelLogFormat.plural(running, 'lane', 'lanes')}',
        noticeKind: GgParallelLogNoticeKind.warning,
      ),
      effects: [GgParallelLogController._effect(_Type.cancelAll)],
    );
  }

  // ...........................................................................
  GgParallelLogUpdate _effect(GgParallelLogEffectType type) {
    final lane = _lane;
    if (lane == null) return GgParallelLogUpdate(state);
    return GgParallelLogUpdate(
      state,
      effects: [GgParallelLogController._effect(type, lane.name)],
    );
  }

  // ...........................................................................
  GgParallelLogUpdate _confirmSearch() {
    final query = state.input;
    final s = state.copyWith(
      mode: GgParallelLogMode.detail,
      query: query,
      noMatch: true,
    );
    final matches = controller.search.matches(_lane!, query);
    if (matches.isNotEmpty) return _show(s, matches.last);
    if (query.isEmpty) return GgParallelLogUpdate(s);
    return GgParallelLogUpdate(
      s.copyWith(
        notice: 'No match for "$query"',
        noticeKind: GgParallelLogNoticeKind.warning,
      ),
    );
  }

  // ...........................................................................
  GgParallelLogUpdate _jump({required bool forward}) {
    final matches = controller.search.matches(_lane!, state.query);
    if (matches.isEmpty) return GgParallelLogUpdate(state);
    final current = state.match ?? (forward ? -1 : _total);
    final next = forward
        ? matches.firstWhere((m) => m > current, orElse: () => matches.first)
        : matches.lastWhere((m) => m < current, orElse: () => matches.last);
    return _show(state, next);
  }

  // ...........................................................................
  /// Marks the match at [line] and scrolls it into the middle of the view.
  GgParallelLogUpdate _show(GgParallelLogViewState s, int line) {
    final scrolled = _Context(
      controller,
      s.copyWith(match: line),
      lanes,
      height,
      confirm,
    );
    return scrolled._scrollTo(line - _body ~/ 2);
  }
}
