// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

// #############################################################################
/// Runs [executable] with [arguments] and returns its result.
typedef GgParallelLogProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

// #############################################################################
/// Sends [signal] to the process with [pid] and tells whether it was there.
typedef GgParallelLogSignalSender = bool Function(
  int pid,
  ProcessSignal signal,
);

// #############################################################################
/// Ends a process together with all processes it started.
class GgParallelLogProcessTree {
  /// Creates a killer for the current platform; tests pass other functions.
  GgParallelLogProcessTree({
    bool? isWindows,
    GgParallelLogProcessRunner? run,
    GgParallelLogSignalSender? signal,
    this.grace = const Duration(seconds: 1),
  }) : isWindows = isWindows ?? Platform.isWindows,
       _run = run ?? Process.run,
       _signal = signal ?? Process.killPid;

  /// Creates an example killer for the current platform.
  factory GgParallelLogProcessTree.example({
    bool? isWindows,
    GgParallelLogProcessRunner? run,
    GgParallelLogSignalSender? signal,
    Duration? grace,
  }) => GgParallelLogProcessTree(
    isWindows: isWindows,
    run: run,
    signal: signal,
    grace: grace ?? Duration.zero,
  );

  // ...........................................................................
  /// Kills the process with [pid] and its descendants.
  ///
  /// POSIX sends SIGTERM, then SIGKILL after [grace]; Windows uses taskkill.
  Future<void> kill(int pid) async {
    if (isWindows) {
      final result = await _runSafely('taskkill', ['/PID', '$pid', '/T', '/F']);
      if (result == null) _signal(pid, ProcessSignal.sigkill);
      return;
    }
    final tree = [...await descendants(pid), pid];
    final alive = tree.where((p) => _signal(p, ProcessSignal.sigterm)).toList();
    if (alive.isEmpty) return;
    await Future<void>.delayed(grace);
    for (final p in alive) {
      _signal(p, ProcessSignal.sigkill);
    }
  }

  // ...........................................................................
  /// Returns the descendants of [pid] on POSIX, deepest first.
  ///
  /// Returns none when `pgrep` is missing, e.g. in a slim container.
  Future<List<int>> descendants(int pid) async {
    final result = await _runSafely('pgrep', ['-P', '$pid']);
    final children = '${result?.stdout ?? ''}'
        .split('\n')
        .map((line) => int.tryParse(line.trim()))
        .whereType<int>();
    return [
      for (final child in children) ...[...await descendants(child), child],
    ];
  }

  // ...........................................................................
  /// Whether the processes run on Windows.
  final bool isWindows;

  /// The time processes get to end after SIGTERM before SIGKILL.
  final Duration grace;

  // ######################
  // Private
  // ######################

  final GgParallelLogProcessRunner _run;
  final GgParallelLogSignalSender _signal;

  // ...........................................................................
  Future<ProcessResult?> _runSafely(
    String executable,
    List<String> args,
  ) async {
    try {
      return await _run(executable, args);
    } on ProcessException {
      return null;
    }
  }
}
