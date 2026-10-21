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

import 'gg_parallel_log_line.dart';
import 'gg_parallel_log_status.dart';
import 'gg_parallel_log_text.dart';

/// Is called when a lane got a new [line] or, with a null line, a new status.
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
  GgParallelLogLane({required this.name, GgParallelLogLaneChanged? onChange})
    : _onChange = onChange ?? _ignore,
      _createdAt = clock.now();

  /// Creates an example lane for tests and docs.
  factory GgParallelLogLane.example({
    String? name,
    GgParallelLogLaneChanged? onChange,
  }) => GgParallelLogLane(name: name ?? 'gg_log', onChange: onChange);

  // ...........................................................................
  /// Appends [message] to the output; usable wherever a `GgLog` is expected.
  ///
  /// A message starting with the carriage return of `GgStatusPrinter`
  /// replaces the previous line, so status printers update in place.
  void log(String message) => _append(message, isError: false);

  // ...........................................................................
  /// Appends [message] to the output and marks it as error output.
  void logError(String message) => _append(message, isError: true);

  // ...........................................................................
  /// Marks a waiting lane as running and starts its clock.
  void start() {
    if (_status != GgParallelLogStatus.waiting) return;
    _status = GgParallelLogStatus.running;
    _startedAt = clock.now();
    _onChange(this, null);
  }

  // ...........................................................................
  /// Marks the lane as completed successfully.
  void succeed() => _finish(GgParallelLogStatus.success);

  // ...........................................................................
  /// Logs [error] and marks the lane as failed.
  void fail(Object error) {
    if (status.isDone) return;
    logError('$error');
    _finish(GgParallelLogStatus.error);
  }

  // ...........................................................................
  /// Cancels the lane, kills its piped processes and completes [whenCancelled].
  void cancel() {
    if (status.isDone) return;
    _finish(GgParallelLogStatus.cancelled);
    _cancelled.complete();
  }

  // ...........................................................................
  /// Logs the output of [process] and kills it when the lane is cancelled.
  ///
  /// Returns the exit code once the process and its output are done.
  Future<int> pipe(Process process) async {
    unawaited(whenCancelled.then((_) => process.kill()));
    final done = [
      _decodeLines(process.stdout).forEach(log),
      _decodeLines(process.stderr).forEach(logError),
    ];
    final exitCode = await process.exitCode;
    await Future.wait<void>(done);
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

  /// True when the lane was cancelled.
  bool get isCancelled => _status == GgParallelLogStatus.cancelled;

  /// Completes when the lane gets cancelled.
  Future<void> get whenCancelled => _cancelled.future;

  /// The text of the last line without colors, or an empty string.
  String get lastLine =>
      _lines.isEmpty ? '' : GgParallelLogText.stripAnsi(_lines.last.text);

  // ######################
  // Private
  // ######################

  final GgParallelLogLaneChanged _onChange;
  final DateTime _createdAt;
  final List<GgParallelLogLine> _lines = [];
  final Completer<void> _cancelled = Completer<void>();
  GgParallelLogStatus _status = GgParallelLogStatus.waiting;
  DateTime? _startedAt;
  DateTime? _finishedAt;

  // ...........................................................................
  static void _ignore(GgParallelLogLane lane, GgParallelLogLine? line) {}

  // ...........................................................................
  void _append(String message, {required bool isError}) {
    for (final part in message.split('\n')) {
      final replace = part.startsWith(GgStatusPrinter.carriageReturn);
      final text = part.replaceAll(GgStatusPrinter.carriageReturn, '');
      final line = GgParallelLogLine(
        text: GgParallelLogText.sanitize(text),
        time: clock.now().difference(_startedAt ?? _createdAt),
        isError: isError,
      );
      if (replace && _lines.isNotEmpty) {
        _lines.last = line;
      } else {
        _lines.add(line);
      }
      _onChange(this, line);
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
