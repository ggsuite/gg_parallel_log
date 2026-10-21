// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:fake_async/fake_async.dart';
import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_is_github/gg_is_github.dart';
import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:test/test.dart';

void main() {
  late GgParallelLogFakeTerminal terminal;
  late GgParallelLog log;

  setUp(() {
    ggColorsEnabled = false;
    testIsGitHub = false;
    terminal = GgParallelLogFakeTerminal(isInteractive: false);
    log = GgParallelLog.example(terminal: terminal);
  });

  tearDown(() {
    ggColorsEnabled = null;
    testIsGitHub = null;
  });

  group('GgParallelLog', () {
    test('draws on stdin and stdout by default', () {
      final log = GgParallelLog(title: 'gg do publish');
      expect(log.terminal, isA<GgParallelLogStdioTerminal>());
      expect(log.tick, const Duration(milliseconds: 100));
    });

    test('example() draws on a fake terminal', () {
      final log = GgParallelLog.example();
      expect(log.title, 'gg do publish');
      expect(log.terminal, isA<GgParallelLogFakeTerminal>());
    });

    group('isInteractive', () {
      test('follows the terminal, GitHub and the parameter', () {
        final interactive = GgParallelLogFakeTerminal();
        expect(
          GgParallelLog.example(terminal: interactive).isInteractive,
          true,
        );
        expect(log.isInteractive, isFalse);
        expect(
          GgParallelLog.example(
            terminal: terminal,
            interactive: true,
          ).isInteractive,
          isTrue,
        );
        testIsGitHub = true;
        expect(
          GgParallelLog.example(terminal: interactive).isInteractive,
          false,
        );
      });
    });

    group('lane(name)', () {
      test('creates each lane once and keeps the order', () {
        final b = log.lane('b');
        log.lane('a');
        expect(log.lane('b'), same(b));
        expect(log.lanes.map((l) => l.name), ['b', 'a']);
        expect(terminal.output, '');
      });
    });

    group('run(name, task)', () {
      test('runs the task in the lane and catches its prints', () async {
        final result = await log.run('a', (lane) async {
          print('hello');
          return 42;
        });
        expect(result, 42);
        expect(log.lane('a').status, GgParallelLogStatus.success);
        expect(
          terminal.output,
          '[a] started\n[a] hello\n✓ a success after 00:00\n',
        );
      });

      test('marks the lane as failed and rethrows', () async {
        await expectLater(
          log.run<void>('a', (lane) async => throw Exception('boom')),
          throwsA(isA<Exception>()),
        );
        expect(log.lane('a').status, GgParallelLogStatus.error);
        expect(log.lane('a').lastLine, 'Exception: boom');
      });

      test('refuses to run a cancelled lane', () async {
        log.lane('a').cancel();
        await expectLater(
          log.run('a', (lane) async => 1),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'Lane "a" was cancelled.',
            ),
          ),
        );
      });
    });

    group('finish()', () {
      test('writes the summary once and ignores later lines', () async {
        await log.run('a', (lane) async => lane.log('done'));
        await log.finish();
        await log.finish();
        log.lane('a').log('late');
        expect(
          terminal.output,
          endsWith(
            '\n gg do publish · 1/1 done · 00:00\n  ✓ a     00:00  done\n',
          ),
        );
        expect(terminal.output, isNot(contains('late')));
      });
    });

    group('interactive', () {
      test('shows the live view and exits on a double Ctrl+C', () {
        fakeAsync((fake) {
          final exits = <int>[];
          final terminal = GgParallelLogFakeTerminal();
          final log = GgParallelLog(
            title: 'gg do publish',
            terminal: terminal,
            exit: exits.add,
          );
          log.lane('a');
          expect(terminal.isRawMode, isTrue);
          terminal
            ..interrupt()
            ..interrupt();
          fake.flushMicrotasks();
          expect(exits, [130]);
          log.finish();
          fake.flushMicrotasks();
        });
      });
    });
  });
}
