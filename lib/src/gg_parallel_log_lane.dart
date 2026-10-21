// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:gg_status_printer/gg_status_printer.dart';
import 'package:meta/meta.dart';

import 'gg_parallel_log_line.dart';
import 'gg_parallel_log_process_tree.dart';
import 'gg_parallel_log_status.dart';
import 'gg_parallel_log_text.dart';

// #############################################################################
/// Reports that a lane got a new line or, with a null line, a new status.
typedef GgParallelLogLaneChanged = void Function(
  GgParallelLogLane lane,
  GgParallelLogLine? line,
);

// #############################################################################
/// One of the parallel processes of a parallel log, with its own output.
///
/// Pass [log] wherever a `GgLog` is expected.
class GgParallelLogLane {
  /// Creates a waiting lane called [name] that reports changes to [onChange].
  GgParallelLogLane({
    required this.name,
    GgParallelLogLaneChanged? onChange,
    GgParallelLogProcessTree? processTree,
  }) : _onChange = onChange ?? _ignore,
       _processTree = processTree ?? GgParallelLogProcessTree(),
       _createdAt = clock.now();

  /// Creates an example lane for tests and docs.
  factory GgParallelLogLane.example({
    String? name,
    GgParallelLogLaneChanged? onChange,
    GgParallelLogProcessTree? processTree,
  }) => GgParallelLogLane(
    name: name ?? 'gg_log',
    onChange: onChange,
    processTree: processTree,
  );

  // ...........................................................................
  /// Appends [message]; a status printer line replaces the previous line.
  void log(String message) => _append(message, isError: false);

  // ...........................................................................
  /// Appends [message] and marks it as error output.
  void logError(String message) => _append(message, isError: true);

  // ...........................................................................
  /// Marks a waiting lane as running and starts its clock.
  @internal
  void start() {
    if (_status != GgParallelLogStatus.waiting) return;
    _status = GgParallelLogStatus.running;
    _startedAt = clock.now();
    _onChange(this, null);
  }

  // ...........................................................................
  /// Marks the lane as completed successfully.
  @internal
  void succeed() => _finish(GgParallelLogStatus.success);

  // ...........................................................................
  /// Logs [error] and marks the lane as failed.
  @internal
  void fail(Object error) {
    if (status.isDone) return;
    logError('$error');
    _finish(GgParallelLogStatus.error);
  }

  // ...........................................................................
  /// Cancels the lane, kills its running piped processes, see [whenKilled].
  void cancel() {
    if (status.isDone) return;
    _finish(GgParallelLogStatus.cancelled);
    _cancelled.complete();
    _processes.forEach(_kill);
  }

  // ...........................................................................
  /// Logs the output of [process] and kills its tree when the lane cancels.
  ///
  /// Returns the exit code, waiting at most [drain] for open output after.
  Future<int> pipe(
    Process process, {
    Duration drain = const Duration(seconds: 2),
  }) async {
    if (isCancelled) {
      _kill(process);
    } else {
      _processes.add(process);
    }
    final subscriptions = [
      _decodeLines(process.stdout).listen(log),
      _decodeLines(process.stderr).listen(logError),
    ];
    // Created now, as output that closes before the exit completes them.
    final closed = [
      for (final subscription in subscriptions)
        subscription.asFuture<void>().catchError((_) {}),
    ];
    final exitCode = await process.exitCode;
    _processes.remove(process);
    await Future.wait(closed).timeout(drain, onTimeout: () => []);
    for (final subscription in subscriptions) {
      unawaited(subscription.cancel());
    }
    return exitCode;
  }

  // ...........................................................................
  /// The name shown for the lane.
  final String name;

  /// The current status.
  GgParallelLogStatus get status => _status;

  /// All lines written so far.
  List<GgParallelLogLine> get lines => UnmodifiableListView(_lines);

  /// The time the lane is running or was running.
  Duration get elapsed {
    final startedAt = _startedAt;
    if (startedAt == null) return Duration.zero;
    return (_finishedAt ?? clock.now()).difference(startedAt);
  }

  /// Whether the lane was cancelled.
  bool get isCancelled => _status == GgParallelLogStatus.cancelled;

  /// Completes when the lane gets cancelled.
  Future<void> get whenCancelled => _cancelled.future;

  /// Completes when the processes killed by [cancel] are gone.
  Future<void> get whenKilled => Future.wait(_kills);

  /// The text of the last line without colors, or an empty string.
  String get lastLine =>
      _lines.isEmpty ? '' : GgParallelLogText.stripAnsi(_lines.last.text);

  // ######################
  // Private
  // ######################

  final GgParallelLogLaneChanged _onChange;
  final GgParallelLogProcessTree _processTree;
  final DateTime _createdAt;
  final List<GgParallelLogLine> _lines = [];
  final Completer<void> _cancelled = Completer<void>();
  final Set<Process> _processes = {};
  final List<Future<void>> _kills = [];
  GgParallelLogStatus _status = GgParallelLogStatus.waiting;
  DateTime? _startedAt;
  DateTime? _finishedAt;

  // ...........................................................................
  /// Kills the tree of [process]; a failing kill must not crash the log.
  void _kill(Process process) =>
      _kills.add(_processTree.kill(process.pid).catchError((Object _) {}));

  // ...........................................................................
  static void _ignore(GgParallelLogLane lane, GgParallelLogLine? line) {}

  // ...........................................................................
  void _append(String message, {required bool isError}) {
    final trimmed = message.endsWith('\n')
        ? message.substring(0, message.length - 1)
        : message;
    for (final part in trimmed.split('\n')) {
      final replace = part.startsWith(GgStatusPrinter.carriageReturn);
      final line = GgParallelLogLine(
        text: GgParallelLogText.sanitize(
          part.replaceAll(GgStatusPrinter.carriageReturn, ''),
        ),
        time: clock.now().difference(_startedAt ?? _createdAt),
        isError: isError,
      );
      _add(line, replace: replace);
      _onChange(this, line);
    }
  }

  // ...........................................................................
  /// Adds [line], or replaces the last line unless that one is an error.
  void _add(GgParallelLogLine line, {required bool replace}) {
    if (replace && _lines.isNotEmpty && !_lines.last.isError) {
      _lines.last = line;
    } else {
      _lines.add(line);
    }
  }

  // ...........................................................................
  void _finish(GgParallelLogStatus status) {
    if (_status.isDone) return;
    final now = clock.now();
    _status = status;
    _startedAt ??= now;
    _finishedAt = now;
    _onChange(this, null);
  }

  // ...........................................................................
  static Stream<String> _decodeLines(Stream<List<int>> bytes) => bytes
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(const LineSplitter());
}
