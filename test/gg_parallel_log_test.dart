// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_is_github/gg_is_github.dart';
import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:path/path.dart' show join;
import 'package:test/test.dart';

void main() {
  late GgParallelLogFakeTerminal terminal;
  late Directory tmp;
  late List<int> exits;

  setUp(() {
    ggColorsEnabled = false;
    testIsGitHub = false;
    terminal = GgParallelLogFakeTerminal.example(isInteractive: false);
    tmp = Directory.systemTemp.createTempSync('gg_parallel_log_');
    exits = [];
  });

  tearDown(() {
    ggColorsEnabled = null;
    testIsGitHub = null;
    tmp.deleteSync(recursive: true);
  });

  // ...........................................................................
  /// Runs [body] with a clock that stands still, so every time is 00:00.
  Future<void> stillClock(Future<void> Function() body) =>
      withClock(Clock.fixed(DateTime(2026, 10, 21, 15)), body);

  /// Creates a log on the terminal that records its exits.
  GgParallelLog create({
    bool? interactive,
    Directory? saveDirectory,
    int? summaryTail,
  }) => GgParallelLog.example(
    terminal: terminal,
    interactive: interactive,
    saveDirectory: saveDirectory,
    summaryTail: summaryTail,
    exit: exits.add,
  );

  /// Returns a row of the summary table as the terminal shows it.
  String row(String name, String icon, String text) =>
      '  $icon ${name.padRight(4)}  00:00  $text';

  /// Returns the title line of the summary.
  String title(String counts) => ' gg do publish · $counts · 00:00';

  group('GgParallelLog', () {
    group('GgParallelLog(title)', () {
      test('draws on the stdio terminal with standard settings', () {
        final log = GgParallelLog(title: 'gg do publish');
        expect(log.title, 'gg do publish');
        expect(log.terminal, isA<GgParallelLogStdioTerminal>());
        expect(log.tick, const Duration(milliseconds: 100));
        expect(log.summaryTail, 40);
        expect(log.lanes, isEmpty);
      });
    });

    group('example()', () {
      test('draws on an interactive fake terminal', () {
        final log = GgParallelLog.example();
        expect(log.title, 'gg do publish');
        expect(log.terminal, isA<GgParallelLogFakeTerminal>());
        expect(log.isInteractive, isTrue);
      });

      test('keeps the process alive on a termination', () {
        fakeAsync((fake) {
          final terminal = GgParallelLogFakeTerminal.example();
          final log = GgParallelLog.example(terminal: terminal)..lane('a');
          terminal.terminate();
          fake.flushMicrotasks();
          expect(log.result.cancelled, ['a']);
        });
      });
    });

    group('isInteractive', () {
      for (final (interactive, isTerminal, isGitHub, expected) in [
        (null, true, false, true),
        (null, false, false, false),
        (null, true, true, false),
        (true, false, true, true),
        (false, true, false, false),
      ]) {
        test('is $expected with interactive: $interactive, '
            'an interactive terminal: $isTerminal, GitHub: $isGitHub', () {
          testIsGitHub = isGitHub;
          terminal = GgParallelLogFakeTerminal.example(
            isInteractive: isTerminal,
          );
          expect(create(interactive: interactive).isInteractive, expected);
        });
      }

      test('stays true once the live view started', () {
        fakeAsync((fake) {
          terminal = GgParallelLogFakeTerminal.example();
          final log = create()..lane('a');
          expect(terminal.isRawMode, isTrue);
          expect(log.isInteractive, isTrue);
          log.finish();
          fake.flushMicrotasks();
        });
      });

      test('turns false when the live view could not take the input', () {
        terminal = GgParallelLogFakeTerminal.example(inputTaken: true);
        final log = create();
        expect(log.isInteractive, isTrue);
        log.lane('a');
        expect(log.isInteractive, isFalse);
      });
    });

    group('lane(name)', () {
      test('creates each lane once and keeps the order', () {
        final log = create();
        final b = log.lane('b');
        log.lane('a');
        expect(log.lane('b'), same(b));
        expect(log.lanes.map((l) => l.name), ['b', 'a']);
        expect(log.lanes.map((l) => l.status), [
          GgParallelLogStatus.waiting,
          GgParallelLogStatus.waiting,
        ]);
        expect(terminal.output, '');
      });
    });

    group('run(name, task)', () {
      test('returns the result and logs the prints into the lane', () {
        return stillClock(() async {
          final log = create();
          final result = await log.run('a', (lane) async {
            print('hello');
            return 42;
          });
          expect(result, 42);
          expect(log.lane('a').lines.map((l) => l.text), ['hello']);
          expect(terminal.screen, [
            '[a] started',
            '[a] hello',
            '✓ a success after 00:00',
          ]);
        });
      });

      test('fails the lane and rethrows the error', () {
        return stillClock(() async {
          final log = create();
          await expectLater(
            log.run<void>('a', (lane) async => throw Exception('boom')),
            throwsA(
              isA<Exception>().having(
                (e) => '$e',
                'toString()',
                'Exception: boom',
              ),
            ),
          );
          expect(log.lane('a').status, GgParallelLogStatus.error);
          expect(terminal.screen, [
            '[a] started',
            '[a] Exception: boom',
            '✗ a error after 00:00',
          ]);
        });
      });

      test('does not start a lane cancelled before', () async {
        final log = create();
        log.lane('a').cancel();
        var started = false;
        await expectLater(
          log.run('a', (lane) async => started = true),
          throwsA(
            isA<GgParallelLogCancelledException>().having(
              (e) => e.lane,
              'lane',
              'a',
            ),
          ),
        );
        expect(started, isFalse);
      });

      test('throws when the lane is cancelled and the task returns', () async {
        final log = create();
        await expectLater(
          log.run('a', (lane) async {
            lane.cancel();
            return 1;
          }),
          throwsA(isA<GgParallelLogCancelledException>()),
        );
        expect(log.lane('a').status, GgParallelLogStatus.cancelled);
      });

      test('throws when the lane is cancelled and the task throws', () async {
        final log = create();
        await expectLater(
          log.run<void>('a', (lane) async {
            lane.cancel();
            throw Exception('killed');
          }),
          throwsA(isA<GgParallelLogCancelledException>()),
        );
        expect(log.lane('a').status, GgParallelLogStatus.cancelled);
        expect(log.lane('a').lines, isEmpty);
      });

      test(
        'throws when the task cancels its lane and throws at once',
        () async {
          final log = create();
          await expectLater(
            log.run<void>('a', (lane) {
              lane.cancel();
              throw Exception('killed');
            }),
            throwsA(
              isA<GgParallelLogCancelledException>().having(
                (e) => e.lane,
                'lane',
                'a',
              ),
            ),
          );
          expect(log.lane('a').status, GgParallelLogStatus.cancelled);
          expect(log.lane('a').lines, isEmpty);
        },
      );

      test(
        'fails its lane when the task hits another cancelled lane',
        () async {
          final log = create();
          log.lane('b').cancel();
          await expectLater(
            log.run('a', (lane) => log.run('b', (lane) async => 1)),
            throwsA(
              isA<GgParallelLogCancelledException>().having(
                (e) => e.lane,
                'lane',
                'b',
              ),
            ),
          );
          expect(log.lane('a').status, GgParallelLogStatus.error);
          expect(log.lane('a').lastLine, 'Lane "b" was cancelled.');
        },
      );

      test('throws at once when the lane is cancelled during the task', () {
        return stillClock(() async {
          final log = create();
          final never = Completer<void>();
          final running = log.run('a', (lane) => never.future);
          log.lane('a').cancel();
          await expectLater(
            running,
            throwsA(
              isA<GgParallelLogCancelledException>().having(
                (e) => e.lane,
                'lane',
                'a',
              ),
            ),
          );
          expect(never.isCompleted, isFalse);
          expect(terminal.screen, ['[a] started', '⊘ a cancelled after 00:00']);
        });
      });

      test('refuses to run once the log finished', () async {
        final log = create();
        await log.finish();
        await expectLater(
          log.run('a', (lane) async => 1),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'The log "gg do publish" has finished already.',
            ),
          ),
        );
      });

      test('refuses to run a lane twice', () async {
        final log = create();
        await log.run('a', (lane) async => 1);
        await expectLater(
          log.run('a', (lane) async => 2),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'Lane "a" has run already.',
            ),
          ),
        );
      });
    });

    group('runAll(tasks, concurrency)', () {
      test('refuses a concurrency below 1', () async {
        await expectLater(
          create().runAll({}, concurrency: 0),
          throwsA(
            isA<ArgumentError>().having((e) => e.name, 'name', 'concurrency'),
          ),
        );
      });

      test('runs at most concurrency tasks at a time', () async {
        final log = create();
        var running = 0;
        var peak = 0;
        final started = <String>[];
        Future<void> task(GgParallelLogLane lane) async {
          started.add(lane.name);
          peak = max(peak, ++running);
          await Future<void>.value();
          await Future<void>.value();
          running--;
        }

        final result = await log.runAll({
          for (final name in ['a', 'b', 'c', 'd', 'e']) name: task,
        }, concurrency: 2);
        expect(peak, 2);
        expect(started, ['a', 'b', 'c', 'd', 'e']);
        expect(result.succeeded, ['a', 'b', 'c', 'd', 'e']);
      });

      test('refuses a concurrency below 1', () async {
        await expectLater(
          create().runAll({'a': (lane) async {}}, concurrency: 0),
          throwsA(
            isA<ArgumentError>()
                .having((e) => e.name, 'name', 'concurrency')
                .having((e) => e.message, 'message', 'must be 1 or more'),
          ),
        );
      });

      test('rethrows when a lane has run already and finishes', () {
        return stillClock(() async {
          final log = create();
          await log.run('a', (lane) async {});
          await expectLater(
            log.runAll({'a': (lane) async {}}),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                'Lane "a" has run already.',
              ),
            ),
          );
          expect(terminal.screen, [
            '[a] started',
            '✓ a success after 00:00',
            '',
            title('1/1 done'),
            row('a', '✓', ''),
          ]);
        });
      });

      test('rethrows when the log finished while lanes wait', () async {
        final log = create();
        await expectLater(
          log.runAll({
            'a': (lane) async => log.finish(),
            'b': (lane) async {},
          }, concurrency: 1),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'The log "gg do publish" has finished already.',
            ),
          ),
        );
        expect(log.lane('b').status, GgParallelLogStatus.waiting);
      });
      test('lists every lane before the first task starts', () async {
        final log = create();
        final seen = <String>[];
        await log.runAll({
          'a': (lane) async => seen.addAll(log.lanes.map((l) => l.name)),
          'b': (lane) async {},
        }, concurrency: 1);
        expect(seen, ['a', 'b']);
      });

      test('keeps running the other lanes when one fails', () async {
        final log = create();
        final result = await log.runAll({
          'a': (lane) async => throw Exception('boom'),
          'b': (lane) async => lane.log('done'),
        }, concurrency: 1);
        expect(result.failed, ['a']);
        expect(result.succeeded, ['b']);
      });

      test('returns the lanes by how they ended', () async {
        final log = create();
        final result = await log.runAll({
          'ok': (lane) async {},
          'bad': (lane) async => throw Exception('boom'),
          'gone': (lane) async => lane.cancel(),
        });
        expect(
          [
            result.succeeded,
            result.failed,
            result.cancelled,
            result.unfinished,
          ],
          [
            ['ok'],
            ['bad'],
            ['gone'],
            <String>[],
          ],
        );
        expect(result.exitCode, 1);
      });

      test('finishes the log once all tasks are done', () {
        return stillClock(() async {
          final log = create();
          await log.runAll({'a': (lane) async {}});
          expect(terminal.screen, [
            '[a] started',
            '✓ a success after 00:00',
            '',
            title('1/1 done'),
            row('a', '✓', ''),
          ]);
          terminal.clear();
          await log.finish();
          expect(terminal.output, '');
        });
      });
    });

    group('finish()', () {
      test('returns how the lanes ended', () async {
        final log = create();
        await log.run('a', (lane) async {});
        log.lane('b');
        final result = await log.finish();
        expect(
          [result.succeeded, result.unfinished],
          [
            ['a'],
            ['b'],
          ],
        );
        expect(result.exitCode, 1);
      });

      test('returns the same future and writes once', () async {
        final log = create();
        await log.run('a', (lane) async {});
        expect(log.finish(), same(log.finish()));
        await log.finish();
        expect(
          terminal.screen.where((line) => line.startsWith(' gg do publish')),
          hasLength(1),
        );
      });

      test('writes only the summary when there is no lane', () {
        return stillClock(() async {
          terminal = GgParallelLogFakeTerminal.example();
          await create().finish();
          expect(terminal.isRawMode, isFalse);
          expect(terminal.output, '${title('0/0 done')}\n');
        });
      });

      test('starts no live view once finished', () {
        fakeAsync((fake) {
          terminal = GgParallelLogFakeTerminal.example();
          final log = create();
          log.finish();
          fake.flushMicrotasks();
          log.lane('a').log('late');
          expect(log.isInteractive, isFalse);
          expect(terminal.isRawMode, isFalse);
          expect(fake.periodicTimerCount, 0);
          expect(terminal.screen, [title('0/0 done'), '[a] late']);
        });
      });

      test('saves long failed lanes and names the file', () {
        return stillClock(() async {
          final logs = Directory(join(tmp.path, 'logs'));
          final log = create(saveDirectory: logs, summaryTail: 2);
          await log.runAll({
            'a': (lane) async {
              lane
                ..log('one')
                ..log('two');
              throw Exception('boom');
            },
          });
          final file = logs.listSync().single as File;
          expect(
            file.readAsStringSync(),
            '00:00 one\n00:00 two\n00:00 ! Exception: boom\n',
          );
          expect(terminal.screen, [
            '[a] started',
            '[a] one',
            '[a] two',
            '[a] Exception: boom',
            '✗ a error after 00:00',
            '',
            ' ✗ a ${'─' * 73}',
            '   … 1 earlier line · full log: ${file.path}',
            '   00:00 │ two',
            '   00:00 │ Exception: boom',
            '',
            title('1/1 done · 1 failed'),
            row('a', '✗', 'Exception: boom'),
          ]);
        });
      });

      test('saves no failed lane the summary shows completely', () async {
        final logs = Directory(join(tmp.path, 'logs'));
        final log = create(saveDirectory: logs, summaryTail: 1);
        await log.runAll({'a': (lane) async => throw Exception('boom')});
        expect(logs.existsSync(), isFalse);
        expect(terminal.screen, isNot(contains(startsWith('   …'))));
      });

      test('leaves out the path when the folder cannot be written', () {
        return stillClock(() async {
          final blocker = File(join(tmp.path, 'blocker'))
            ..writeAsStringSync('');
          final log = create(
            saveDirectory: Directory(blocker.path),
            summaryTail: 1,
          );
          final result = await log.runAll({
            'a': (lane) async {
              lane.log('one');
              throw Exception('boom');
            },
          });
          expect(result.failed, ['a']);
          expect(terminal.screen, [
            '[a] started',
            '[a] one',
            '[a] Exception: boom',
            '✗ a error after 00:00',
            '',
            ' ✗ a ${'─' * 73}',
            '   … 1 earlier line',
            '   00:00 │ Exception: boom',
            '',
            title('1/1 done · 1 failed'),
            row('a', '✗', 'Exception: boom'),
          ]);
        });
      });

      for (final (trouble, broken) in [
        (
          'the input is taken',
          () {
            return GgParallelLogFakeTerminal.example(inputTaken: true);
          },
        ),
        (
          'raw mode is missing',
          () {
            return GgParallelLogFakeTerminal.example(supportsRawMode: false);
          },
        ),
      ]) {
        test('falls back to plain output when $trouble', () {
          return stillClock(() async {
            terminal = broken();
            final log = create();
            expect(log.isInteractive, isTrue);
            await log.runAll({'a': (lane) async {}});
            expect(terminal.isRawMode, isFalse);
            expect(terminal.screen, [
              '[a] started',
              '✓ a success after 00:00',
              '',
              title('1/1 done'),
              row('a', '✓', ''),
            ]);
            expect(log.isInteractive, isFalse);
          });
        });
      }
    });

    group('interactive', () {
      test('cancels all lanes and exits on a second Ctrl+C', () {
        fakeAsync((fake) {
          terminal = GgParallelLogFakeTerminal.example();
          terminal.write('before\n');
          final log = create();
          Object? error;
          unawaited(
            log
                .run('a', (lane) async {
                  lane.log('working');
                  await lane.whenCancelled;
                })
                .then<void>((_) {}, onError: (Object e) => error = e),
          );
          log.lane('b');
          fake.elapse(const Duration(milliseconds: 100));
          expect(terminal.isRawMode, isTrue);
          terminal.interrupt();
          fake.flushMicrotasks();
          expect(exits, isEmpty);
          terminal.interrupt();
          fake.flushMicrotasks();
          expect(exits, [130]);
          expect(error, isA<GgParallelLogCancelledException>());
          expect(terminal.isRawMode, isFalse);
          expect(terminal.screen, [
            'before',
            title('2/2 done · 2 cancelled'),
            row('a', '⊘', 'cancelled'),
            row('b', '⊘', 'cancelled'),
          ]);
        });
      });

      test('cancels all lanes and exits on a termination', () {
        fakeAsync((fake) {
          terminal = GgParallelLogFakeTerminal.example();
          final log = create()..lane('a');
          terminal.terminate(143);
          fake.flushMicrotasks();
          expect(exits, [143]);
          expect(log.result.cancelled, ['a']);
          expect(terminal.isRawMode, isFalse);
        });
      });
    });
  });
}
