// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:gg_status_printer/gg_status_printer.dart';
import 'package:test/test.dart';

void main() {
  final dart = Platform.resolvedExecutable;
  const timeout = Duration(seconds: 20);
  const cr = GgStatusPrinter.carriageReturn;

  late List<(GgParallelLogStatus, String?, bool?)> changes;
  late List<List<String>> kills;
  late GgParallelLogLane lane;

  setUp(() {
    ggColorsEnabled = false;
    changes = [];
    kills = [];
    lane = GgParallelLogLane.example(
      onChange: (lane, line) =>
          changes.add((lane.status, line?.text, line?.isError)),
    );
  });

  tearDown(() => ggColorsEnabled = null);

  // ...........................................................................
  /// Returns the text and the error flag of every line of [lane].
  List<(String, bool)> linesOf(GgParallelLogLane lane) => [
    for (final line in lane.lines) (line.text, line.isError),
  ];

  // ...........................................................................
  /// Logs a status printer for [message] running and then succeeding.
  void logStatusPrinter(String message) {
    final printer = GgStatusPrinter<void>(
      message: message,
      ggLog: lane.log,
      useCarriageReturn: true,
      colorize: false,
    );
    printer.status = GgStatusPrinterStatus.running;
    printer.status = GgStatusPrinterStatus.success;
  }

  // ...........................................................................
  /// Creates a Windows tree that records its taskkill calls in [kills].
  ///
  /// Each kill finishes when [until] completes.
  GgParallelLogProcessTree recordingTree({Future<void>? until}) =>
      GgParallelLogProcessTree.example(
        isWindows: true,
        run: (executable, arguments) async {
          kills.add([executable, ...arguments]);
          await until;
          return ProcessResult(0, 0, '', '');
        },
      );

  // ...........................................................................
  /// Returns the taskkill call that kills the tree of [pid].
  List<String> taskkill(int pid) => ['taskkill', '/PID', '$pid', '/T', '/F'];

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
  Future<void> waitFor(FutureOr<bool> Function() isDone) async {
    while (!await isDone()) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  // ...........................................................................
  /// Returns whether [lane] has logged [text].
  bool hasLogged(GgParallelLogLane lane, String text) =>
      lane.lines.any((line) => line.text == text);

  // ...........................................................................
  /// Returns the pid of the child spawn_child.dart logged to [lane].
  int? childOf(GgParallelLogLane lane) {
    for (final line in lane.lines) {
      if (line.text.startsWith('child ')) {
        return int.parse(line.text.split(' ').last);
      }
    }
    return null;
  }

  // ...........................................................................
  /// Starts the sample [script] and kills it and its child after the test.
  Future<Process> start(String script, [List<String> arguments = const []]) {
    final process = Process.start(dart, [
      'test/sample_folder/$script',
      ...arguments,
    ]);
    addTearDown(() async {
      (await process).kill(ProcessSignal.sigkill);
      final child = childOf(lane);
      if (child != null) Process.killPid(child, ProcessSignal.sigkill);
    });
    return process;
  }

  group('GgParallelLogLane', () {
    group('example(name, onChange, processTree)', () {
      test('is a waiting lane called gg_log without lines', () {
        final lane = GgParallelLogLane.example();
        expect(
          [
            lane.name,
            lane.status,
            lane.lines,
            lane.lastLine,
            lane.elapsed,
            lane.isCancelled,
          ],
          [
            'gg_log',
            GgParallelLogStatus.waiting,
            isEmpty,
            '',
            Duration.zero,
            false,
          ],
        );
      });

      test('takes the name', () {
        expect(GgParallelLogLane.example(name: 'kidney').name, 'kidney');
      });

      test('works without onChange', () {
        final lane = GgParallelLogLane.example()
          ..start()
          ..log('a')
          ..succeed();
        expect(lane.lastLine, 'a');
      });
    });

    group('log(message)', () {
      test('splits the message into lines and reports each', () {
        lane.log('a\nb');
        expect(linesOf(lane), [('a', false), ('b', false)]);
        expect(changes, [
          (GgParallelLogStatus.waiting, 'a', false),
          (GgParallelLogStatus.waiting, 'b', false),
        ]);
      });

      test('drops only one line break at the end', () {
        lane.log('a\n');
        lane.log('b\n\n');
        expect(linesOf(lane), [('a', false), ('b', false), ('', false)]);
      });

      test('logs an empty message as an empty line', () {
        lane.log('');
        expect(linesOf(lane), [('', false)]);
      });

      test('keeps colors but drops moves, tabs and control characters', () {
        lane.log('\x1B[32mok\x1B[0m\x1B[2K\tx\r\x07');
        expect(lane.lines.single.text, '\x1B[32mok\x1B[0m    x');
        expect(lane.lastLine, 'ok    x');
      });

      test('lets a status printer replace its running line', () {
        logStatusPrinter('Running "dart test"');
        expect(linesOf(lane), [('✓ Running "dart test"', false)]);
        expect(changes, [
          (GgParallelLogStatus.waiting, '⌛️ Running "dart test"', false),
          (GgParallelLogStatus.waiting, '✓ Running "dart test"', false),
        ]);
      });

      test('appends a replacing line that would replace an error', () {
        lane.logError('boom');
        lane.log('${cr}done');
        expect(linesOf(lane), [('boom', true), ('done', false)]);
      });

      test('appends a replacing line when there is no line yet', () {
        lane.log('${cr}first');
        expect(linesOf(lane), [('first', false)]);
      });

      test('removes a carriage return inside a line without replacing', () {
        lane.log('a');
        lane.log('b${cr}c');
        expect(linesOf(lane), [('a', false), ('bc', false)]);
      });

      test('stamps lines with the time since the creation or start', () {
        fakeAsync((fake) {
          final lane = GgParallelLogLane.example();
          fake.elapse(const Duration(seconds: 2));
          lane.log('before');
          lane.start();
          fake.elapse(const Duration(seconds: 3));
          lane.log('after');
          expect(lane.lines.map((line) => line.time), [
            const Duration(seconds: 2),
            const Duration(seconds: 3),
          ]);
        });
      });
    });

    group('logError(message)', () {
      test('splits, cleans and reports the lines as errors', () {
        lane.logError('\x1B[31mboom\x1B[0m\n\tat main\n');
        expect(linesOf(lane), [
          ('\x1B[31mboom\x1B[0m', true),
          ('    at main', true),
        ]);
        expect(changes, [
          (GgParallelLogStatus.waiting, '\x1B[31mboom\x1B[0m', true),
          (GgParallelLogStatus.waiting, '    at main', true),
        ]);
        expect(lane.lastLine, '    at main');
      });

      test('replaces a normal line for a status printer', () {
        lane.log('⌛️ build');
        lane.logError('$cr✗ build');
        expect(linesOf(lane), [('✗ build', true)]);
      });
    });

    group('lines', () {
      test('cannot be modified', () {
        lane.log('a');
        expect(
          () => lane.lines.add(GgParallelLogLine.example()),
          throwsA(isA<UnsupportedError>()),
        );
        expect(() => lane.lines.clear(), throwsA(isA<UnsupportedError>()));
        expect(linesOf(lane), [('a', false)]);
      });
    });

    group('lastLine', () {
      test('is the last line without colors', () {
        lane.log('a\n\x1B[1mb\x1B[0m');
        expect(lane.lastLine, 'b');
      });
    });

    group('start()', () {
      test('marks a waiting lane as running and reports it once', () {
        lane.start();
        lane.start();
        expect(lane.status, GgParallelLogStatus.running);
        expect(changes, [(GgParallelLogStatus.running, null, null)]);
      });

      test('does nothing once the lane is done', () {
        lane.succeed();
        lane.start();
        expect(lane.status, GgParallelLogStatus.success);
        expect(changes, [(GgParallelLogStatus.success, null, null)]);
      });
    });

    group('succeed()', () {
      test('marks the lane as successful and reports it once', () {
        lane.start();
        lane.succeed();
        lane.succeed();
        expect(lane.status, GgParallelLogStatus.success);
        expect(changes, [
          (GgParallelLogStatus.running, null, null),
          (GgParallelLogStatus.success, null, null),
        ]);
      });

      test('does nothing once the lane is cancelled', () {
        lane.cancel();
        lane.succeed();
        expect(lane.status, GgParallelLogStatus.cancelled);
        expect(changes, [(GgParallelLogStatus.cancelled, null, null)]);
      });
    });

    group('fail(error)', () {
      test('logs the error as error line and marks the lane as failed', () {
        lane.start();
        lane.fail(Exception('3 tests failed'));
        expect(lane.status, GgParallelLogStatus.error);
        expect(linesOf(lane), [('Exception: 3 tests failed', true)]);
        expect(changes, [
          (GgParallelLogStatus.running, null, null),
          (GgParallelLogStatus.running, 'Exception: 3 tests failed', true),
          (GgParallelLogStatus.error, null, null),
        ]);
      });

      test('does nothing once the lane is done', () {
        lane.succeed();
        lane.fail('late');
        lane.fail('again');
        expect(lane.status, GgParallelLogStatus.success);
        expect(lane.lines, isEmpty);
      });
    });

    group('cancel()', () {
      test('marks the lane as cancelled and reports it once', () async {
        lane.start();
        lane.cancel();
        lane.cancel();
        await lane.whenCancelled;
        expect(
          [lane.status, lane.isCancelled],
          [GgParallelLogStatus.cancelled, true],
        );
        expect(changes, [
          (GgParallelLogStatus.running, null, null),
          (GgParallelLogStatus.cancelled, null, null),
        ]);
      });

      test('does nothing once the lane is done', () {
        fakeAsync((fake) {
          final lane = GgParallelLogLane.example();
          var cancelled = false;
          unawaited(lane.whenCancelled.then((_) => cancelled = true));
          lane.fail('boom');
          lane.cancel();
          fake.flushMicrotasks();
          expect(
            [lane.status, lane.isCancelled, cancelled],
            [GgParallelLogStatus.error, false, false],
          );
        });
      });
    });

    group('whenCancelled', () {
      test('completes only when the lane gets cancelled', () {
        fakeAsync((fake) {
          final lane = GgParallelLogLane.example();
          var cancelled = false;
          unawaited(lane.whenCancelled.then((_) => cancelled = true));
          lane.start();
          fake.flushMicrotasks();
          expect(cancelled, isFalse);
          lane.cancel();
          fake.flushMicrotasks();
          expect(cancelled, isTrue);
        });
      });
    });

    group('elapsed', () {
      test('runs from start() to the end of the lane', () {
        fakeAsync((fake) {
          final lane = GgParallelLogLane.example();
          fake.elapse(const Duration(seconds: 1));
          expect(lane.elapsed, Duration.zero);
          lane.start();
          fake.elapse(const Duration(seconds: 4));
          expect(lane.elapsed, const Duration(seconds: 4));
          lane.succeed();
          fake.elapse(const Duration(seconds: 4));
          expect(lane.elapsed, const Duration(seconds: 4));
        });
      });

      for (final finish in ['succeed', 'fail', 'cancel']) {
        test('is zero when the lane ends by $finish() without start()', () {
          fakeAsync((fake) {
            final lane = GgParallelLogLane.example();
            fake.elapse(const Duration(seconds: 1));
            switch (finish) {
              case 'succeed':
                lane.succeed();
              case 'fail':
                lane.fail('boom');
              default:
                lane.cancel();
            }
            fake.elapse(const Duration(seconds: 1));
            expect(lane.elapsed, Duration.zero);
          });
        });
      }
    });

    group('pipe(process, drain)', () {
      test('logs stdout, stderr as errors and returns the exit code', () async {
        final exitCode = await lane.pipe(await start('lane_output.dart'));
        expect(exitCode, 3);
        expect(linesOf(lane).toSet(), {('out', false), ('err', true)});
      });

      test('kills the process when the lane is cancelled', () async {
        final exitCode = lane.pipe(await start('sleep.dart'));
        await waitFor(() => hasLogged(lane, 'sleeping')).timeout(timeout);
        lane.cancel();
        expect(await exitCode.timeout(timeout), isNot(0));
      });

      test('returns when the output closes, before the drain', () async {
        final exitCode = lane.pipe(
          await start('lane_output.dart'),
          drain: const Duration(minutes: 5),
        );
        expect(await exitCode.timeout(timeout), 3);
      });

      test('kills the whole tree on cancel and returns at once', () async {
        final exitCode = lane.pipe(
          await start('spawn_child.dart'),
          drain: const Duration(minutes: 5),
        );
        await waitFor(() => hasLogged(lane, 'sleeping')).timeout(timeout);
        final child = childOf(lane)!;
        expect(await isRunning(child), isTrue);

        lane.cancel();

        expect(await exitCode.timeout(timeout), isNot(0));
        await waitFor(() async => !await isRunning(child)).timeout(timeout);
      });

      test('stops waiting for output a grandchild holds open', () async {
        final exitCode = lane.pipe(
          await start('spawn_child.dart', ['--exit']),
          drain: const Duration(milliseconds: 300),
        );
        expect(await exitCode.timeout(timeout), 0);
        expect(await isRunning(childOf(lane)!), isTrue);
      });

      test('kills a process piped after the lane was cancelled', () async {
        lane.cancel();
        final exitCode = lane.pipe(await start('sleep.dart'));
        expect(await exitCode.timeout(timeout), isNot(0));
      });

      test('kills a piped process at once after cancel()', () async {
        final lane = GgParallelLogLane.example(processTree: recordingTree());
        lane.cancel();
        final process = _TestProcess(pid: 7);
        final exitCode = lane.pipe(process);
        await lane.whenKilled;
        expect(kills, [taskkill(7)]);
        process.exit(1);
        expect(await exitCode, 1);
      });
    });

    group('cancel() with piped processes', () {
      test('kills the tree of every piped process still running', () async {
        final lane = GgParallelLogLane.example(processTree: recordingTree());
        final first = _TestProcess(pid: 1);
        final second = _TestProcess(pid: 2);
        final exitCodes = [lane.pipe(first), lane.pipe(second)];
        lane.cancel();
        await lane.whenKilled;
        expect(kills, [taskkill(1), taskkill(2)]);
        first.exit();
        second.exit();
        expect(await Future.wait(exitCodes), [0, 0]);
      });

      test('leaves a piped process alone that has ended', () async {
        final lane = GgParallelLogLane.example(processTree: recordingTree());
        final ended = _TestProcess(pid: 1);
        final running = _TestProcess(pid: 2);
        final endedExitCode = lane.pipe(ended);
        final runningExitCode = lane.pipe(running);
        ended.exit();
        await endedExitCode;
        lane.cancel();
        await lane.whenKilled;
        expect(kills, [taskkill(2)]);
        running.exit();
        await runningExitCode;
      });
    });

    group('whenKilled', () {
      test('completes at once when nothing was killed', () async {
        lane.cancel();
        await lane.whenKilled.timeout(timeout);
      });

      test('waits until the kills are done', () async {
        final release = Completer<void>();
        final lane = GgParallelLogLane.example(
          processTree: recordingTree(until: release.future),
        );
        final process = _TestProcess();
        unawaited(lane.pipe(process));
        lane.cancel();
        var killed = false;
        unawaited(lane.whenKilled.then((_) => killed = true));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(killed, isFalse);
        release.complete();
        await lane.whenKilled;
        expect(killed, isTrue);
        process.exit();
      });

      test('swallows a kill that fails', () async {
        final lane = GgParallelLogLane.example(
          processTree: GgParallelLogProcessTree.example(
            isWindows: true,
            run: (_, _) async => throw StateError('taskkill crashed'),
          ),
        );
        final process = _TestProcess();
        unawaited(lane.pipe(process));
        lane.cancel();
        await lane.whenKilled.timeout(timeout);
        expect(lane.status, GgParallelLogStatus.cancelled);
        process.exit();
      });
    });
  });
}

// #############################################################################
/// A process in memory whose output and exit the test controls.
class _TestProcess implements Process {
  /// Creates a running process with [pid].
  _TestProcess({this.pid = 4242});

  // ...........................................................................
  /// Closes the output and exits with [code].
  void exit([int code = 0]) {
    unawaited(_stdout.close());
    unawaited(_stderr.close());
    _exitCode.complete(code);
  }

  // ...........................................................................
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => false;

  // ...........................................................................
  @override
  final int pid;

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<List<int>> get stderr => _stderr.stream;

  @override
  IOSink get stdin => throw UnsupportedError('The test process has no stdin');

  @override
  Future<int> get exitCode => _exitCode.future;

  final StreamController<List<int>> _stdout = StreamController();
  final StreamController<List<int>> _stderr = StreamController();
  final Completer<int> _exitCode = Completer();
}
