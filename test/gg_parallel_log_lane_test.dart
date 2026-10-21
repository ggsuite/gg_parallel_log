// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:gg_status_printer/gg_status_printer.dart';
import 'package:test/test.dart';

void main() {
  late List<(String, String?)> changes;
  late GgParallelLogLane lane;

  setUp(() {
    changes = [];
    lane = GgParallelLogLane.example(
      onChange: (lane, line) => changes.add((lane.name, line?.text)),
    );
  });

  group('GgParallelLogLane', () {
    test('example() is a waiting lane called gg_log', () {
      final lane = GgParallelLogLane.example();
      expect(lane.name, 'gg_log');
      expect(lane.status, GgParallelLogStatus.waiting);
      expect(lane.lines, isEmpty);
      expect(lane.lastLine, '');
      lane.log('works without a listener');
    });

    group('log(message)', () {
      test('splits, cleans and reports lines', () {
        lane.log('a\n\tb\r');
        expect(lane.lines.map((l) => l.text), ['a', '    b']);
        expect(changes, [('gg_log', 'a'), ('gg_log', '    b')]);
        expect(lane.lines.first.isError, isFalse);
      });

      test('lets a status printer replace its line', () {
        final printer = GgStatusPrinter<void>(
          message: 'Running "dart test"',
          ggLog: lane.log,
          useCarriageReturn: true,
          colorize: false,
        );
        printer.status = GgStatusPrinterStatus.running;
        printer.status = GgStatusPrinterStatus.success;
        expect(lane.lines.map((l) => l.text), ['✓ Running "dart test"']);
      });

      test('appends a replacing line when there is none yet', () {
        lane.log('${GgStatusPrinter.carriageReturn}first');
        expect(lane.lastLine, 'first');
      });

      test('stamps lines with the time since the start', () {
        fakeAsync((fake) {
          final lane = GgParallelLogLane.example();
          fake.elapse(const Duration(seconds: 2));
          lane.log('before');
          lane.start();
          fake.elapse(const Duration(seconds: 3));
          lane.log('after');
          expect(lane.lines.map((l) => l.time), [
            const Duration(seconds: 2),
            const Duration(seconds: 3),
          ]);
        });
      });
    });

    group('logError(message)', () {
      test('marks the lines as errors', () {
        lane.logError('\x1B[31mboom\x1B[0m');
        expect(lane.lines.single.isError, isTrue);
        expect(lane.lastLine, 'boom');
      });
    });

    group('lines', () {
      test('cannot be modified', () {
        expect(
          () => lane.lines.add(GgParallelLogLine.example()),
          throwsA(isA<UnsupportedError>()),
        );
      });
    });

    group('start(), succeed(), elapsed', () {
      test('run the clock from start to the end', () {
        fakeAsync((fake) {
          final lane = GgParallelLogLane.example(
            onChange: (lane, line) => changes.add((lane.status.name, null)),
          );
          fake.elapse(const Duration(seconds: 1));
          expect(lane.elapsed, Duration.zero);
          lane.start();
          lane.start();
          fake.elapse(const Duration(seconds: 4));
          expect(lane.elapsed, const Duration(seconds: 4));
          lane.succeed();
          fake.elapse(const Duration(seconds: 4));
          expect(lane.elapsed, const Duration(seconds: 4));
          expect(lane.status, GgParallelLogStatus.success);
          expect(changes, [('running', null), ('success', null)]);
        });
      });
    });

    group('fail(error)', () {
      test('logs the error and marks the lane as failed', () {
        lane.start();
        lane.fail(Exception('3 tests failed'));
        expect(lane.status, GgParallelLogStatus.error);
        expect(lane.lastLine, 'Exception: 3 tests failed');
        expect(lane.lines.last.isError, isTrue);
      });

      test('does nothing once the lane is done', () {
        lane.succeed();
        lane.fail('late');
        expect(lane.status, GgParallelLogStatus.success);
        expect(lane.lines, isEmpty);
      });
    });

    group('cancel()', () {
      test('marks the lane and completes whenCancelled', () async {
        lane.cancel();
        lane.cancel();
        await lane.whenCancelled;
        expect(lane.isCancelled, isTrue);
        expect(lane.status, GgParallelLogStatus.cancelled);
      });

      test('does nothing once the lane is done', () {
        lane.succeed();
        lane.cancel();
        expect(lane.isCancelled, isFalse);
      });
    });

    group('pipe(process)', () {
      final dart = Platform.resolvedExecutable;

      test('logs the output and returns the exit code', () async {
        final exitCode = await lane.pipe(
          await Process.start(dart, ['--version']),
        );
        expect(exitCode, 0);
        expect(lane.lastLine, contains('Dart SDK version'));
      });

      test('logs the error output as errors', () async {
        final exitCode = await lane.pipe(
          await Process.start(dart, ['does_not_exist.dart']),
        );
        expect(exitCode, isNot(0));
        expect(lane.lines.where((l) => l.isError), isNotEmpty);
      });

      test('kills the process when the lane is cancelled', () async {
        final process = await Process.start(dart, [
          'test/sample_folder/sleep.dart',
        ]);
        final exitCode = lane.pipe(process);
        while (lane.lastLine != 'sleeping') {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        lane.cancel();
        expect(await exitCode, isNot(0));
      });
    });
  });
}
