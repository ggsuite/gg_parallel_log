// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:fake_async/fake_async.dart';
import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_keymap.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_overview.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_view_state.dart';
import 'package:test/test.dart';

void main() {
  const overview = GgParallelLogMode.overview;
  final hints = ' ${const GgParallelLogKeymap().hints(overview)}';
  final filteredHints =
      ' ${const GgParallelLogKeymap().hints(overview, errorsOnly: true)}';

  setUp(() => ggColorsEnabled = false);
  tearDown(() => ggColorsEnabled = null);

  // ...........................................................................
  /// Runs [body] with lanes that ran for 65 seconds on a fake clock.
  void withLanes(void Function(List<GgParallelLogLane> lanes) body) {
    fakeAsync((async) {
      final log = GgParallelLogLane.example()..start();
      final args = GgParallelLogLane.example(name: 'gg_args')..start();
      async.elapse(const Duration(seconds: 65));
      log.log('Running tests');
      args.fail('Expected: 3');
      body([
        log,
        args,
        GgParallelLogLane.example(name: 'gg_json')..succeed(),
        GgParallelLogLane.example(name: 'gg_is'),
      ]);
    });
  }

  const elapsed = Duration(seconds: 65);
  const header = ' gg do publish · 2/4 done · 1 failed · 01:05';
  const log = '  ⠋ gg_log   01:05  Running tests';
  const args = '  ✗ gg_args  01:05  Expected: 3';
  const json = '  ✓ gg_json  00:00  ';
  final isRow = '  ○ gg_is${' ' * 11}waiting';
  String selected(String row) => '❯${row.substring(1)}';

  List<String> render(
    List<GgParallelLogLane> lanes, {
    GgParallelLogViewState? state,
    int? width,
    int? height,
    int? frame,
  }) => GgParallelLogOverview.example(
    lanes: lanes,
    state: state ?? GgParallelLogViewState.example(),
    elapsed: elapsed,
    width: width,
    height: height,
    frame: frame,
  ).lines();

  group('GgParallelLogOverview', () {
    group('example()', () {
      test('shows a single waiting lane, selected', () {
        expect(GgParallelLogOverview.example().lines(), [
          ' gg do publish · 0/1 done · 00:00',
          '❯ ○ gg_log${' ' * 9}waiting',
          hints,
        ]);
      });
    });

    group('lines()', () {
      test('shows the header, a row per lane and the hints', () {
        withLanes((lanes) {
          expect(render(lanes), [
            header,
            selected(log),
            args,
            json,
            isRow,
            hints,
          ]);
        });
      });

      test('marks the selected lane', () {
        withLanes((lanes) {
          expect(
            render(
              lanes,
              state: GgParallelLogViewState.example(selected: 'gg_json'),
            ),
            [header, log, args, selected(json), isRow, hints],
          );
        });
      });

      test('animates the spinner of running lanes with frame', () {
        withLanes((lanes) {
          expect(
            render(lanes, frame: 3)[1],
            '❯ ⠸ gg_log   01:05  Running tests',
          );
        });
      });

      test('lists the failed lanes only while they are filtered', () {
        withLanes((lanes) {
          expect(
            render(
              lanes,
              state: GgParallelLogViewState.example(
                errorsOnly: true,
                selected: 'gg_args',
              ),
            ),
            ['$header · errors only', selected(args), filteredHints],
          );
        });
      });

      test('says so when no lane failed', () {
        withLanes((lanes) {
          expect(
            render(
              lanes.sublist(0, 1),
              state: GgParallelLogViewState.example(errorsOnly: true),
            ),
            [
              ' gg do publish · 0/1 done · 01:05 · errors only',
              '   No failed lanes',
              filteredHints,
            ],
          );
        });
      });

      test('says so when there are no lanes', () {
        expect(render([]), [
          ' gg do publish · 0/0 done · 01:05',
          '   No lanes',
          hints,
        ]);
      });

      group('on a low terminal', () {
        final expected = {
          1: [header],
          2: [header],
          3: [header],
          4: [header, selected(log), hints],
          5: [header, selected(log), args, hints],
          6: [header, '', selected(log), '   ↓ 3 more', hints],
        };
        for (final MapEntry(key: height, value: lines) in expected.entries) {
          test('shows ${lines.length} lines on $height rows', () {
            withLanes((lanes) {
              expect(render(lanes, height: height), lines);
            });
          });
        }

        test('keeps the selected lane visible', () {
          withLanes((lanes) {
            final state = GgParallelLogViewState.example(selected: 'gg_is');
            expect(render(lanes, state: state, height: 5), [
              header,
              json,
              selected(isRow),
              hints,
            ]);
          });
        });
      });

      group('with more lanes than rows', () {
        final many = [
          for (var i = 0; i < 10; i++)
            GgParallelLogLane.example(name: 'lane_$i'),
        ];
        String row(int i, {bool isSelected = false}) =>
            '${isSelected ? '❯' : ' '} ○ lane_$i${' ' * 9}waiting';
        const top = ' gg do publish · 0/10 done · 01:05';

        List<String> window(String selection) => render(
          many,
          state: GgParallelLogViewState.example(selected: selection),
          height: 8,
        );

        test('shows the lanes around the selection', () {
          expect(window('lane_5'), [
            top,
            '   ↑ 4 more',
            row(4),
            row(5, isSelected: true),
            row(6),
            '   ↓ 3 more',
            hints,
          ]);
        });

        test('leaves the line above empty at the first lane', () {
          expect(window('lane_0'), [
            top,
            '',
            row(0, isSelected: true),
            row(1),
            row(2),
            '   ↓ 7 more',
            hints,
          ]);
        });

        test('leaves the line below empty at the last lane', () {
          expect(window('lane_9'), [
            top,
            '   ↑ 7 more',
            row(7),
            row(8),
            row(9, isSelected: true),
            '',
            hints,
          ]);
        });
      });

      group('in the footer', () {
        List<String> footer(GgParallelLogViewState state) {
          late List<String> lines;
          withLanes((lanes) => lines = render(lanes, state: state));
          return lines.sublist(5);
        }

        for (final kind in GgParallelLogNoticeKind.values) {
          test('colors a notice of kind ${kind.name}', () {
            ggColorsEnabled = true;
            final colored = switch (kind) {
              GgParallelLogNoticeKind.info => ' Saved',
              GgParallelLogNoticeKind.warning => ' ${cWarn('Saved')}',
              GgParallelLogNoticeKind.error => ' ${cError('Saved')}',
            };
            expect(
              footer(
                GgParallelLogViewState.example(
                  notice: 'Saved',
                  noticeKind: kind,
                ),
              ),
              [colored],
            );
          });
        }

        test('shows the first line of a notice only, without controls', () {
          expect(
            footer(
              GgParallelLogViewState.example(
                notice: 'Saved\x07 to a.log\nsecond line',
              ),
            ),
            [' Saved to a.log'],
          );
        });

        test('shows a notice', () {
          expect(
            footer(GgParallelLogViewState.example(notice: 'Saved to a.log')),
            [' Saved to a.log'],
          );
        });

        test('prefers a notice over a confirmation', () {
          expect(
            footer(
              GgParallelLogViewState.example(
                notice: 'Saved to a.log',
                confirm: GgParallelLogConfirm.cancelAll,
              ),
            ),
            [' Saved to a.log'],
          );
        });

        test('asks to confirm cancelling the selected lane', () {
          expect(
            footer(
              GgParallelLogViewState.example(
                selected: 'gg_is',
                confirm: GgParallelLogConfirm.cancelLane,
              ),
            ),
            [' Press x again to cancel gg_is'],
          );
        });

        test('asks to confirm cancelling all running lanes', () {
          expect(
            footer(
              GgParallelLogViewState.example(
                confirm: GgParallelLogConfirm.cancelAll,
              ),
            ),
            [' Press q again to cancel all running lanes'],
          );
        });

        test('lists the hints of its keymap', () {
          final lines = GgParallelLogOverview(
            title: 'gg do publish',
            lanes: const [],
            keymap: GgParallelLogKeymap.example(
              bindings: [GgParallelLogBinding.example(hint: 's store')],
            ),
          ).lines();
          expect(lines.last, ' s store');
        });
      });

      test('cuts every line to one column less than the width', () {
        withLanes((lanes) {
          expect(render(lanes, width: 20), [
            ' gg do publish · 2…',
            '❯ ⠋ gg_log   01:05…',
            '  ✗ gg_args  01:05…',
            '  ✓ gg_json  00:00…',
            '  ○ gg_is         …',
            '${hints.substring(0, 18)}…',
          ]);
        });
      });
    });
  });
}
