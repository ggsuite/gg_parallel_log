// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:async';

import 'package:clock/clock.dart';

import 'gg_parallel_log_controller.dart';
import 'gg_parallel_log_detail.dart';
import 'gg_parallel_log_fake_terminal.dart';
import 'gg_parallel_log_key.dart';
import 'gg_parallel_log_key_decoder.dart';
import 'gg_parallel_log_lane.dart';
import 'gg_parallel_log_line.dart';
import 'gg_parallel_log_overview.dart';
import 'gg_parallel_log_renderer.dart';
import 'gg_parallel_log_saver.dart';
import 'gg_parallel_log_screen.dart';
import 'gg_parallel_log_terminal.dart';
import 'gg_parallel_log_view_state.dart';

// #############################################################################
/// Shows an inline overview of all lanes and one lane in fullscreen.
///
/// Wires keys, controller and screen together and redraws on every [tick].
class GgParallelLogInteractiveRenderer implements GgParallelLogRenderer {
  /// Creates the view of the [lanes] of the log called [title].
  ///
  /// [onAbort] ends the program, e.g. after a second Ctrl+C.
  GgParallelLogInteractiveRenderer({
    required this.title,
    required this.terminal,
    required this._lanes,
    required this._onAbort,
    GgParallelLogSaver? saver,
    GgParallelLogController? controller,
    DateTime? startedAt,
    this.tick = const Duration(milliseconds: 100),
  }) : saver = saver ?? GgParallelLogSaver(),
       controller = controller ?? GgParallelLogController(),
       _screen = GgParallelLogScreen(terminal: terminal),
       _startedAt = startedAt ?? clock.now();

  /// Creates an example renderer on a fake terminal.
  factory GgParallelLogInteractiveRenderer.example({
    GgParallelLogTerminal? terminal,
    List<GgParallelLogLane>? lanes,
    GgParallelLogSaver? saver,
    void Function(int code)? onAbort,
  }) {
    final all = lanes ?? [GgParallelLogLane.example()];
    return GgParallelLogInteractiveRenderer(
      title: 'gg do publish',
      terminal: terminal ?? GgParallelLogFakeTerminal(),
      lanes: () => all,
      onAbort: onAbort ?? (_) {},
      saver: saver,
    );
  }

  // ...........................................................................
  /// Takes the input, switches the terminal into raw mode and draws.
  ///
  /// Throws, with the terminal untouched, when the input is taken already.
  @override
  void start() {
    _screen.open(
      onInput: (input) => _guarded(() => _onInput(input)),
      onInterrupt: () => _guarded(_interrupt),
      onTerminate: (code) => _guarded(() => _onAbort(code)),
      onError: _showError,
    );
    _timer = Timer.periodic(tick, (_) => _guarded(() {}));
    render();
  }

  // ...........................................................................
  @override
  void laneChanged(GgParallelLogLane lane, GgParallelLogLine? line) {}

  // ...........................................................................
  @override
  Future<void> finish(String summary) async {
    _timer?.cancel();
    _flushTimer?.cancel();
    _screen.close(summary);
  }

  // ...........................................................................
  /// Draws the current view; the screen skips frames that did not change.
  void render() {
    if (!_screen.isOpen) return;
    final lanes = _lanes();
    _state = controller.normalize(_state, lanes);
    if (_state.mode == GgParallelLogMode.overview) {
      _screen.showInline(_overview(lanes));
    } else {
      _screen.showFullscreen(_detail(lanes));
    }
  }

  // ...........................................................................
  /// The title shown in the overview.
  final String title;

  /// The terminal drawn on.
  final GgParallelLogTerminal terminal;

  /// The time between two redraws.
  final Duration tick;

  /// Saves the output of a lane when the user presses s.
  final GgParallelLogSaver saver;

  /// Turns keys into states and effects.
  final GgParallelLogController controller;

  /// What the view currently shows.
  GgParallelLogViewState get state => _state;

  // ######################
  // Private
  // ######################

  final List<GgParallelLogLane> Function() _lanes;
  final void Function(int code) _onAbort;
  final GgParallelLogScreen _screen;
  final DateTime _startedAt;
  final GgParallelLogKeyDecoder _decoder = GgParallelLogKeyDecoder();
  GgParallelLogViewState _state = const GgParallelLogViewState();
  Timer? _timer;
  Timer? _flushTimer;

  /// The time a lone Escape waits for the rest of a sequence.
  static const Duration _escapeDelay = Duration(milliseconds: 50);

  // ...........................................................................
  int get _frame => clock.now().difference(_startedAt).inMilliseconds ~/ 80;

  // ...........................................................................
  List<String> _overview(List<GgParallelLogLane> lanes) =>
      GgParallelLogOverview(
        title: title,
        lanes: lanes,
        state: _state,
        keymap: controller.keymap,
        width: terminal.width,
        height: terminal.height,
        elapsed: clock.now().difference(_startedAt),
        frame: _frame,
      ).lines();

  // ...........................................................................
  List<String> _detail(List<GgParallelLogLane> lanes) {
    final visible = _state.visibleLanes(lanes);
    final index = _state.selectedIndex(visible);
    final lane = visible[index];
    return GgParallelLogDetail(
      lane: lane,
      state: _state,
      keymap: controller.keymap,
      matches: controller.search.matches(lane, _state.activeQuery),
      index: index,
      count: visible.length,
      width: terminal.width,
      height: terminal.height,
      frame: _frame,
    ).lines();
  }

  // ...........................................................................
  /// Runs [action] and draws; shows errors instead of breaking the terminal.
  void _guarded(void Function() action) {
    try {
      action();
      render();
    } catch (e) {
      _showError(e);
      _renderQuietly();
    }
  }

  // ...........................................................................
  /// Draws the error notice; a view that fails again waits for the next tick.
  void _renderQuietly() {
    try {
      render();
    } catch (_) {
      // The notice shows once drawing works again.
    }
  }

  // ...........................................................................
  void _showError(Object error) {
    _state = _state.copyWith(
      notice: 'Error: $error',
      noticeKind: GgParallelLogNoticeKind.error,
    );
  }

  // ...........................................................................
  void _onInput(String input) {
    _flushTimer?.cancel();
    _handle(_decoder.add(input));
    if (_decoder.hasPending) {
      _flushTimer = Timer(
        _escapeDelay,
        () => _guarded(() => _handle(_decoder.flush())),
      );
    }
  }

  // ...........................................................................
  /// Handles [keys]; a confirmed search drops the rest of a pasted chunk.
  void _handle(List<GgParallelLogKey> keys) {
    for (final key in keys) {
      final searching = _state.mode == GgParallelLogMode.search;
      final update = controller.handle(
        _state,
        key,
        _lanes(),
        height: terminal.height,
      );
      _state = update.state;
      update.effects.forEach(_perform);
      if (searching && key.type == GgParallelLogKeyType.enter) return;
    }
  }

  // ...........................................................................
  void _perform(GgParallelLogEffect effect) {
    final lanes = _lanes();
    final lane = lanes.where((l) => l.name == effect.lane).firstOrNull;
    switch (effect.type) {
      case GgParallelLogEffectType.cancelLane:
        lane?.cancel();
      case GgParallelLogEffectType.cancelAll:
        for (final lane in lanes) {
          lane.cancel();
        }
      case GgParallelLogEffectType.save:
        if (lane == null) return;
        final file = saver.save(lane);
        _state = _state.copyWith(notice: 'Saved ${lane.name} to ${file.path}');
      case GgParallelLogEffectType.abort:
        _onAbort(130);
    }
  }

  // ...........................................................................
  /// Lets the controller decide what a Ctrl+C signal does.
  void _interrupt() {
    final update = controller.interrupt(_state);
    _state = update.state;
    update.effects.forEach(_perform);
  }
}
