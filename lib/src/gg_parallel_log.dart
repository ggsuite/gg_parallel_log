// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:async';
import 'dart:io' as io;

import 'package:clock/clock.dart';
import 'package:gg_is_github/gg_is_github.dart';

import 'gg_parallel_log_cancelled_exception.dart';
import 'gg_parallel_log_fake_terminal.dart';
import 'gg_parallel_log_interactive_renderer.dart';
import 'gg_parallel_log_lane.dart';
import 'gg_parallel_log_line.dart';
import 'gg_parallel_log_plain_renderer.dart';
import 'gg_parallel_log_renderer.dart';
import 'gg_parallel_log_result.dart';
import 'gg_parallel_log_saver.dart';
import 'gg_parallel_log_stdio_terminal.dart';
import 'gg_parallel_log_status.dart';
import 'gg_parallel_log_summary.dart';
import 'gg_parallel_log_terminal.dart';

// #############################################################################
/// A task running in a lane.
typedef GgParallelLogTask<T> = Future<T> Function(GgParallelLogLane lane);

// #############################################################################
/// Logs parallel processes, each into a lane of its own.
///
/// Shows a live overview on a terminal, lines prefixed with the lane elsewhere.
class GgParallelLog {
  /// Creates a log called [title] drawing on [terminal], by default stdio.
  ///
  /// [exit] ends the process after a second Ctrl+C or SIGTERM.
  GgParallelLog({
    required this.title,
    GgParallelLogTerminal? terminal,
    this._interactive,
    io.Directory? saveDirectory,
    this.tick = const Duration(milliseconds: 100),
    this.summaryTail = 40,
    void Function(int code)? exit,
  }) : terminal = terminal ?? GgParallelLogStdioTerminal(),
       _saver = GgParallelLogSaver(directory: saveDirectory),
       _exit = exit ?? io.exit;

  /// Creates an example log drawing on a fake terminal.
  factory GgParallelLog.example({
    String? title,
    GgParallelLogTerminal? terminal,
    bool? interactive,
    io.Directory? saveDirectory,
    Duration? tick,
    int? summaryTail,
    void Function(int code)? exit,
  }) => GgParallelLog(
    title: title ?? 'gg do publish',
    terminal: terminal ?? GgParallelLogFakeTerminal(),
    interactive: interactive,
    saveDirectory: saveDirectory,
    tick: tick ?? const Duration(milliseconds: 100),
    summaryTail: summaryTail ?? 40,
    exit: exit ?? (_) {},
  );

  // ...........................................................................
  /// Returns the lane called [name] and creates it as waiting when needed.
  GgParallelLogLane lane(String name) {
    final existing = _lanes[name];
    if (existing != null) return existing;
    final lane = GgParallelLogLane(name: name, onChange: _laneChanged);
    _lanes[name] = lane;
    _renderer.laneChanged(lane, null);
    return lane;
  }

  // ...........................................................................
  /// Runs [task] in the waiting lane [name], its prints going to the lane.
  ///
  /// Throws what it throws, or at once when the lane gets cancelled.
  Future<T> run<T>(String name, GgParallelLogTask<T> task) async {
    final lane = this.lane(name);
    _checkRunnable(lane);
    lane.start();
    try {
      final result = await Future.any([
        runZoned(
          () => task(lane),
          zoneSpecification: ZoneSpecification(
            print: (_, _, _, line) => lane.log(line),
          ),
        ),
        lane.whenCancelled.then<T>(
          (_) => throw GgParallelLogCancelledException(name),
        ),
      ]);
      if (lane.isCancelled) throw GgParallelLogCancelledException(name);
      lane.succeed();
      return result;
    } catch (e) {
      if (!lane.isCancelled) {
        lane.fail(e);
        rethrow;
      }
      if (e is GgParallelLogCancelledException && e.lane == name) rethrow;
      throw GgParallelLogCancelledException(name);
    }
  }

  // ...........................................................................
  /// Runs all [tasks] with at most [concurrency] at a time and finishes.
  ///
  /// A failing task fails its lane only; the result lists the failures.
  Future<GgParallelLogResult> runAll(
    Map<String, GgParallelLogTask<void>> tasks, {
    int concurrency = 4,
  }) async {
    if (concurrency < 1) {
      throw ArgumentError.value(
        concurrency,
        'concurrency',
        'must be 1 or more',
      );
    }
    final queue = [...tasks.keys];
    queue.forEach(lane);
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final name = queue.removeAt(0);
        final wasWaiting = lane(name).status == GgParallelLogStatus.waiting;
        try {
          await run(name, tasks[name]!);
        } on GgParallelLogCancelledException {
          // The result lists the cancelled lane.
        } catch (_) {
          // The result lists the failed lane; other errors are bugs.
          if (!wasWaiting || !lane(name).status.isDone) rethrow;
        }
      }
    }

    try {
      await Future.wait([for (var i = 0; i < concurrency; i++) worker()]);
    } finally {
      await finish();
    }
    return result;
  }

  // ...........................................................................
  /// Removes the live view, leaves a summary and returns the result.
  ///
  /// Calling it again returns the same result without writing again.
  Future<GgParallelLogResult> finish() => _finished ??= _finish();

  // ...........................................................................
  /// The title shown above the lanes.
  final String title;

  /// The terminal drawn on.
  final GgParallelLogTerminal terminal;

  /// The time between two redraws of the live view.
  final Duration tick;

  /// The number of lines the summary repeats for each failed lane.
  final int summaryTail;

  /// All lanes in the order they were created.
  List<GgParallelLogLane> get lanes => _lanes.values.toList();

  /// How the lanes ended so far.
  GgParallelLogResult get result => GgParallelLogResult.of(lanes);

  /// Whether the log shows the live view, or would show it once started.
  bool get isInteractive {
    final renderer = _startedRenderer;
    if (renderer == null) return _wantsInteractive;
    return renderer is GgParallelLogInteractiveRenderer;
  }

  // ######################
  // Private
  // ######################

  final bool? _interactive;
  final GgParallelLogSaver _saver;
  final void Function(int code) _exit;
  final Map<String, GgParallelLogLane> _lanes = {};
  final DateTime _startedAt = clock.now();
  final Zone _zone = Zone.current;

  /// The time an abort waits for the processes of the lanes to end.
  static const Duration _killTimeout = Duration(seconds: 3);
  Future<GgParallelLogResult>? _finished;
  GgParallelLogRenderer? _startedRenderer;

  // ...........................................................................
  /// The renderer, started in the zone of the log on first use.
  ///
  /// The zone keeps the prints of the renderer out of the lanes.
  GgParallelLogRenderer get _renderer =>
      _startedRenderer ??= _zone.run<GgParallelLogRenderer>(_startRenderer);

  // ...........................................................................
  bool get _wantsInteractive =>
      _interactive ?? (terminal.isInteractive && !isGitHub);

  // ...........................................................................
  /// Starts the live view, or the plain one when it cannot take the input.
  ///
  /// After [finish] only the plain view starts, which needs no cleanup.
  GgParallelLogRenderer _startRenderer() {
    if (_finished == null && _wantsInteractive) {
      final renderer = GgParallelLogInteractiveRenderer(
        title: title,
        terminal: terminal,
        lanes: () => lanes,
        onAbort: _abort,
        saver: _saver,
        startedAt: _startedAt,
        tick: tick,
      );
      try {
        renderer.start();
        return renderer;
      } catch (_) {
        // The terminal cannot do it, e.g. no raw mode or the input in use.
      }
    }
    return GgParallelLogPlainRenderer(terminal: terminal)..start();
  }

  // ...........................................................................
  void _checkRunnable(GgParallelLogLane lane) {
    if (_finished != null) {
      throw StateError('The log "$title" has finished already.');
    }
    if (lane.isCancelled) throw GgParallelLogCancelledException(lane.name);
    if (lane.status != GgParallelLogStatus.waiting) {
      throw StateError('Lane "${lane.name}" has run already.');
    }
  }

  // ...........................................................................
  void _laneChanged(GgParallelLogLane lane, GgParallelLogLine? line) =>
      _renderer.laneChanged(lane, line);

  // ...........................................................................
  Future<GgParallelLogResult> _finish() async {
    final summary = _summary();
    final renderer = _startedRenderer;
    if (renderer == null) {
      terminal.write(summary);
    } else {
      await renderer.finish(summary);
    }
    return result;
  }

  // ...........................................................................
  String _summary() => GgParallelLogSummary(
    title: title,
    lanes: lanes,
    elapsed: clock.now().difference(_startedAt),
    width: terminal.width,
    tail: summaryTail,
    savedLogs: _saveLongFailures(),
  ).text();

  // ...........................................................................
  /// Saves the failed lanes the summary cannot repeat completely.
  Map<String, String> _saveLongFailures() {
    final saved = <String, String>{};
    for (final lane in lanes) {
      final long = lane.lines.length > summaryTail;
      if (lane.status != GgParallelLogStatus.error || !long) continue;
      try {
        saved[lane.name] = _saver.save(lane).path;
      } on io.FileSystemException {
        // The summary then mentions the skipped lines only.
      }
    }
    return saved;
  }

  // ...........................................................................
  /// Cancels all lanes, leaves the summary and ends the process.
  Future<void> _abort(int code) async {
    for (final lane in lanes) {
      lane.cancel();
    }
    await Future.wait([for (final lane in lanes) lane.whenKilled])
        .timeout(_killTimeout, onTimeout: () => []);
    await finish();
    _exit(code);
  }
}
