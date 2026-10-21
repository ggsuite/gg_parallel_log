// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:test/test.dart';

void main() {
  final dart = Platform.resolvedExecutable;
  const timeout = Duration(seconds: 20);
  const term = ProcessSignal.sigterm;
  const kill = ProcessSignal.sigkill;

  late List<List<String>> runs;
  late List<(int, ProcessSignal)> signals;

  setUp(() {
    runs = [];
    signals = [];
  });

  // ...........................................................................
  /// Creates a tree whose `pgrep -P` answers come from [children].
  ///
  /// [isAlive] says which pids exist when they get a signal.
  GgParallelLogProcessTree fakeTree({
    required bool isWindows,
    Map<int, List<int>> children = const {},
    bool Function(int pid) isAlive = _always,
    Duration? grace,
  }) => GgParallelLogProcessTree.example(
    isWindows: isWindows,
    grace: grace,
    run: (executable, arguments) async {
      runs.add([executable, ...arguments]);
      final pid = int.tryParse(arguments.last);
      return ProcessResult(0, 0, [...?children[pid], ''].join('\n'), '');
    },
    signal: (pid, signal) {
      signals.add((pid, signal));
      return isAlive(pid);
    },
  );

  // ...........................................................................
  /// Creates a tree on [isWindows] whose tools are not installed.
  GgParallelLogProcessTree treeWithoutTools({required bool isWindows}) =>
      GgParallelLogProcessTree.example(
        isWindows: isWindows,
        run: (executable, arguments) async {
          runs.add([executable, ...arguments]);
          throw ProcessException(executable, arguments, 'not found', 2);
        },
        signal: (pid, signal) {
          signals.add((pid, signal));
          return false;
        },
      );

  // ...........................................................................
  /// Returns whether the process with [pid] still runs.
  Future<bool> isRunning(int pid) async {
    if (Platform.isWindows) {
      final result = await Process.run('tasklist', [
        '/FI',
        'PID eq $pid',
        '/NH',
      ]);
      return RegExp('\\s$pid\\s').hasMatch('${result.stdout}');
    }
    final result = await Process.run('ps', ['-o', 'stat=', '-p', '$pid']);
    final stat = '${result.stdout}'.trim();
    return stat.isNotEmpty && !stat.startsWith('Z');
  }

  // ...........................................................................
  /// Waits until [isDone] returns true.
  Future<void> waitFor(Future<bool> Function() isDone) async {
    while (!await isDone()) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  // ...........................................................................
  /// Starts spawn_child.dart and returns it with the pid of its child.
  ///
  /// Waits until the child sleeps and keeps reading, so no pipe breaks.
  Future<(Process, int)> startTree() async {
    final process = await Process.start(dart, [
      'test/sample_folder/spawn_child.dart',
    ]);
    addTearDown(() => process.kill(ProcessSignal.sigkill));
    final lines = <String>[];
    process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen(lines.add);
    await waitFor(() async => lines.contains('sleeping')).timeout(timeout);
    final child = int.parse(
      lines.firstWhere((line) => line.startsWith('child ')).split(' ').last,
    );
    addTearDown(() => Process.killPid(child, ProcessSignal.sigkill));
    return (process, child);
  }

  group('GgParallelLogProcessTree', () {
    group('GgParallelLogProcessTree(isWindows, run, signal, grace)', () {
      test('uses the current platform and a grace of one second', () {
        final tree = GgParallelLogProcessTree();
        expect(
          [tree.isWindows, tree.grace],
          [Platform.isWindows, const Duration(seconds: 1)],
        );
      });
    });

    group('example(isWindows, run, signal, grace)', () {
      test('uses the current platform and no grace by default', () {
        final tree = GgParallelLogProcessTree.example();
        expect(
          [tree.isWindows, tree.grace],
          [Platform.isWindows, Duration.zero],
        );
      });

      test('takes the given values', () async {
        final tree = fakeTree(
          isWindows: false,
          grace: const Duration(milliseconds: 5),
        );
        await tree.kill(1);
        expect(
          [tree.isWindows, tree.grace],
          [false, const Duration(milliseconds: 5)],
        );
        expect(runs, [
          ['pgrep', '-P', '1'],
        ]);
        expect(signals, [(1, term), (1, kill)]);
      });
    });

    group('kill(pid)', () {
      test('ends a real process with all its descendants', () async {
        final (process, child) = await startTree();
        expect(await isRunning(child), isTrue);

        await GgParallelLogProcessTree().kill(process.pid).timeout(timeout);

        expect(await process.exitCode.timeout(timeout), isNot(0));
        await waitFor(() async => !await isRunning(child)).timeout(timeout);
      });

      test('runs taskkill for the whole tree on Windows', () async {
        await fakeTree(isWindows: true).kill(42);
        expect(runs, [
          ['taskkill', '/PID', '42', '/T', '/F'],
        ]);
        expect(signals, isEmpty);
      });

      test('kills the pid itself when taskkill is missing', () async {
        await treeWithoutTools(isWindows: true).kill(42);
        expect(signals.map((s) => s.$1), [42]);
      });

      test('sends SIGTERM to the tree and SIGKILL after the grace', () {
        fakeAsync((fake) {
          final killed = fakeTree(
            isWindows: false,
            grace: const Duration(seconds: 1),
            children: {
              1: [2, 3],
              2: [4],
            },
          ).kill(1);
          unawaited(killed);
          fake.flushMicrotasks();
          expect(signals, [(4, term), (2, term), (3, term), (1, term)]);

          fake.elapse(const Duration(milliseconds: 999));
          expect(signals, hasLength(4));

          fake.elapse(const Duration(milliseconds: 1));
          expect(signals.skip(4), [(4, kill), (2, kill), (3, kill), (1, kill)]);
        });
      });

      test('sends SIGKILL only to the processes SIGTERM found', () async {
        await fakeTree(
          isWindows: false,
          children: {
            1: [2, 3],
          },
          isAlive: (pid) => pid != 3,
        ).kill(1);
        expect(signals, [
          (2, term),
          (3, term),
          (1, term),
          (2, kill),
          (1, kill),
        ]);
      });

      test('neither waits nor sends SIGKILL when all are gone', () {
        fakeAsync((fake) {
          var done = false;
          final killed = fakeTree(
            isWindows: false,
            grace: const Duration(hours: 1),
            isAlive: (_) => false,
          ).kill(1);
          unawaited(killed.then((_) => done = true));
          fake.flushMicrotasks();
          expect(done, isTrue);
          expect(signals, [(1, term)]);
        });
      });

      test('kills only the pid itself when pgrep is missing', () async {
        await treeWithoutTools(isWindows: false).kill(1);
        expect(runs, [
          ['pgrep', '-P', '1'],
        ]);
        expect(signals, [(1, term)]);
      });
    });

    group('descendants(pid)', () {
      test('finds the real children with pgrep', () async {
        final (process, child) = await startTree();
        expect(await GgParallelLogProcessTree().descendants(process.pid), [
          child,
        ]);
      }, skip: Platform.isWindows ? 'pgrep is a POSIX tool' : null);

      test('asks pgrep for every level and returns deepest first', () async {
        final descendants = await fakeTree(
          isWindows: false,
          children: {
            1: [2, 3],
            2: [4],
          },
        ).descendants(1);
        expect(descendants, [4, 2, 3]);
        expect(runs, [
          ['pgrep', '-P', '1'],
          ['pgrep', '-P', '2'],
          ['pgrep', '-P', '4'],
          ['pgrep', '-P', '3'],
        ]);
      });

      test('ignores lines that are no pids', () async {
        final tree = GgParallelLogProcessTree.example(
          isWindows: false,
          run: (executable, arguments) async =>
              ProcessResult(0, 1, arguments.last == '1' ? ' 7 \nx\n' : '', ''),
        );
        expect(await tree.descendants(1), [7]);
      });

      test('returns none when pgrep is missing', () async {
        expect(
          await treeWithoutTools(isWindows: false).descendants(1),
          isEmpty,
        );
      });
    });
  });
}

// .............................................................................
bool _always(int pid) => true;
