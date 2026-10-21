// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:gg_is_github/gg_is_github.dart';

import 'gg_parallel_log_fake_terminal.dart';
import 'gg_parallel_log_interactive.dart';
import 'gg_parallel_log_lane.dart';
import 'gg_parallel_log_line.dart';
import 'gg_parallel_log_plain.dart';
import 'gg_parallel_log_renderer.dart';
import 'gg_parallel_log_saver.dart';
import 'gg_parallel_log_stdio_terminal.dart';
import 'gg_parallel_log_summary.dart';
import 'gg_parallel_log_terminal.dart';

// #############################################################################
/// Logs parallel processes, each into its own lane.
///
/// On a terminal it shows a live overview of all lanes and lets the user open
/// each lane in fullscreen; elsewhere it writes lines prefixed with the lane.
class GgParallelLog {
  /// Creates a log called [title].
  ///
  /// - [terminal] drawn on, by default stdin and stdout
  /// - [interactive] forces or prevents the interactive view
  /// - [saveDirectory] receives the logs the user saves
  /// - [tick] is the time between two redraws
  /// - [exit] is called when the user presses Ctrl+C twice
  GgParallelLog({
    required this.title,
    GgParallelLogTerminal? terminal,
    this._interactive,
    Directory? saveDirectory,
    this.tick = const Duration(milliseconds: 100),
    this._exit,
  }) : terminal = terminal ?? GgParallelLogStdioTerminal(),
       _saver = GgParallelLogSaver(directory: saveDirectory);

  /// Creates an example log drawing on a fake terminal.
  factory GgParallelLog.example({
    String? title,
    GgParallelLogTerminal? terminal,
    bool? interactive,
    Directory? saveDirectory,
  }) => GgParallelLog(
    title: title ?? 'gg do publish',
    terminal: terminal ?? GgParallelLogFakeTerminal(),
    interactive: interactive,
    saveDirectory: saveDirectory,
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
  /// Runs [task] in the lane called [name] and returns its result.
  ///
  /// The lane is running while the task runs, and fails when it throws.
  /// Everything the task prints ends up in the lane.
  Future<T> run<T>(
    String name,
    Future<T> Function(GgParallelLogLane lane) task,
  ) async {
    final lane = this.lane(name);
    if (lane.isCancelled) throw StateError('Lane "$name" was cancelled.');
    lane.start();
    try {
      final result = await runZoned(
        () => task(lane),
        zoneSpecification: ZoneSpecification(
          print: (_, _, _, line) => lane.log(line),
        ),
      );
      lane.succeed();
      return result;
    } catch (e) {
      lane.fail(e);
      rethrow;
    }
  }

  // ...........................................................................
  /// Removes the live view and leaves a summary on the terminal.
  ///
  /// Failed lanes are repeated with their last lines.
  Future<void> finish() async {
    if (_isFinished) return;
    _isFinished = true;
    final summary = GgParallelLogSummary(
      title: title,
      lanes: lanes,
      elapsed: clock.now().difference(_startedAt),
      width: terminal.width,
      saver: _saver,
    );
    await _renderer.finish(summary.text());
  }

  // ...........................................................................
  /// The title shown above the lanes.
  final String title;

  /// The terminal drawn on.
  final GgParallelLogTerminal terminal;

  /// The time between two redraws of the interactive view.
  final Duration tick;

  /// All lanes in the order they were created.
  List<GgParallelLogLane> get lanes => _lanes.values.toList();

  /// True when the log shows the interactive view.
  bool get isInteractive =>
      _interactive ?? (terminal.isInteractive && !isGitHub);

  // ######################
  // Private
  // ######################

  final bool? _interactive;
  final GgParallelLogSaver _saver;
  final void Function(int code)? _exit;
  final Map<String, GgParallelLogLane> _lanes = {};
  final DateTime _startedAt = clock.now();
  bool _isFinished = false;

  late final GgParallelLogRenderer _renderer = _createRenderer()..start();

  // ...........................................................................
  GgParallelLogRenderer _createRenderer() => isInteractive
      ? GgParallelLogInteractive(
          title: title,
          terminal: terminal,
          lanes: () => lanes,
          saver: _saver,
          tick: tick,
          exit: _exit,
        )
      : GgParallelLogPlain(terminal: terminal);

  // ...........................................................................
  void _laneChanged(GgParallelLogLane lane, GgParallelLogLine? line) {
    if (!_isFinished) _renderer.laneChanged(lane, line);
  }
}
