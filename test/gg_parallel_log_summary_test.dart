// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:fake_async/fake_async.dart';
import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_summary.dart';
import 'package:test/test.dart';

void main() {
  setUp(() => ggColorsEnabled = false);
  tearDown(() => ggColorsEnabled = null);

  // ...........................................................................
  /// Returns a lane called [name] that logged [lines] and then failed.
  GgParallelLogLane failed(
    FakeAsync async, {
    String name = 'gg_args',
    List<String> lines = const ['a', 'b'],
  }) {
    final lane = GgParallelLogLane.example(name: name)..start();
    lines.forEach(lane.log);
    async.elapse(const Duration(seconds: 65));
    return lane..fail('Expected: 3');
  }

  /// Returns the summary of [lanes] as a list of lines.
  List<String> summarize(
    List<GgParallelLogLane> lanes, {
    int? width,
    int? tail,
    Map<String, String>? savedLogs,
  }) => GgParallelLogSummary.example(
    lanes: lanes,
    elapsed: const Duration(seconds: 120),
    width: width,
    tail: tail,
    savedLogs: savedLogs,
  ).text().split('\n');

  final args = [
    ' ✗ gg_args ${'─' * 67}',
    '   00:00 │ a',
    '   00:00 │ b',
    '   01:05 │ Expected: 3',
    '',
  ];
  const header = ' gg do publish · 1/1 done · 1 failed · 02:00';
  const argsRow = '  ✗ gg_args  01:05  Expected: 3';

  group('GgParallelLogSummary', () {
    group('example()', () {
      test('lists a single waiting lane', () {
        expect(
          GgParallelLogSummary.example().text(),
          ' gg do publish · 0/1 done · 00:00\n'
          '  ○ gg_log${' ' * 9}waiting\n',
        );
      });
    });

    group('text()', () {
      test('repeats the failed lanes first and ends with the table', () {
        fakeAsync((async) {
          final log = GgParallelLogLane.example()
            ..start()
            ..log('All tests passed!');
          final gg = GgParallelLogLane.example(name: 'gg_test')..start();
          final lanes = [
            log,
            failed(async),
            GgParallelLogLane.example(name: 'gg_json')..cancel(),
            gg..fail('boom'),
          ];
          log.succeed();
          expect(
            GgParallelLogSummary.example(
              lanes: lanes,
              elapsed: const Duration(seconds: 120),
            ).text(),
            [
              ...args,
              ' ✗ gg_test ${'─' * 67}',
              '   01:05 │ boom',
              '',
              ' gg do publish · 4/4 done · 2 failed · 1 cancelled · 02:00',
              '  ✓ gg_log   01:05  All tests passed!',
              argsRow,
              '  ⊘ gg_json  00:00  cancelled',
              '  ✗ gg_test  01:05  boom',
              '',
            ].join('\n'),
          );
        });
      });

      test('shows only the table when no lane failed', () {
        final lane = GgParallelLogLane.example()..succeed();
        expect(summarize([lane]), [
          ' gg do publish · 1/1 done · 02:00',
          '  ✓ gg_log  00:00  ',
          '',
        ]);
      });

      group('with tail', () {
        test('shows all lines of a lane with exactly tail lines', () {
          fakeAsync((async) {
            expect(summarize([failed(async)], tail: 3), [
              ...args,
              header,
              argsRow,
              '',
            ]);
          });
        });

        test('leaves out a single line of a lane with tail + 1 lines', () {
          fakeAsync((async) {
            expect(summarize([failed(async)], tail: 2), [
              args[0],
              '   … 1 earlier line',
              ...args.sublist(2),
              header,
              argsRow,
              '',
            ]);
          });
        });

        test('counts the lines it leaves out', () {
          fakeAsync((async) {
            expect(summarize([failed(async)], tail: 1), [
              args[0],
              '   … 2 earlier lines',
              ...args.sublist(3),
              header,
              argsRow,
              '',
            ]);
          });
        });

        test('repeats only the header for a tail of 0', () {
          fakeAsync((async) {
            expect(summarize([failed(async)], tail: 0), [
              args[0],
              '   … 3 earlier lines',
              '',
              header,
              argsRow,
              '',
            ]);
          });
        });
      });

      group('with savedLogs', () {
        const saved = {'gg_args': '/tmp/gg_parallel_log/gg_args.log'};

        test('points to the full log when lines are left out', () {
          fakeAsync((async) {
            expect(summarize([failed(async)], tail: 1, savedLogs: saved), [
              args[0],
              '   … 2 earlier lines · '
                  'full log: /tmp/gg_parallel_log/gg_args.log',
              ...args.sublist(3),
              header,
              argsRow,
              '',
            ]);
          });
        });

        test('does not point to the full log when all lines are shown', () {
          fakeAsync((async) {
            expect(summarize([failed(async)], savedLogs: saved), [
              ...args,
              header,
              argsRow,
              '',
            ]);
          });
        });

        test('ignores logs of other lanes', () {
          fakeAsync((async) {
            final other = {'gg_log': '/tmp/gg_parallel_log/gg_log.log'};
            expect(
              summarize([failed(async)], tail: 1, savedLogs: other)[1],
              '   … 2 earlier lines',
            );
          });
        });
      });

      group('with width', () {
        for (final (width, rule) in [(120, 67), (80, 67), (40, 27), (10, 3)]) {
          test('draws a rule of $rule columns for $width columns', () {
            fakeAsync((async) {
              expect(
                summarize([failed(async)], width: width).first,
                ' ✗ gg_args ${'─' * rule}',
              );
            });
          });
        }
      });

      test('measures wide characters of a name by their columns', () {
        fakeAsync((async) {
          expect(summarize([failed(async, name: '日本語', lines: [])]), [
            ' ✗ 日本語 ${'─' * 68}',
            '   01:05 │ Expected: 3',
            '',
            header,
            '  ✗ 日本語  01:05  Expected: 3',
            '',
          ]);
        });
      });
    });
  });
}
