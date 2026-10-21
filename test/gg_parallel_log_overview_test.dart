// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:fake_async/fake_async.dart';
import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_overview.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_view_state.dart';
import 'package:test/test.dart';

void main() {
  setUp(() => ggColorsEnabled = false);
  tearDown(() => ggColorsEnabled = null);

  /// Creates one lane per status, the first one done after five seconds.
  List<GgParallelLogLane> lanesOfAllKinds(FakeAsync fake) {
    final done = GgParallelLogLane.example(name: 'gg_log')..start();
    fake.elapse(const Duration(seconds: 5));
    done
      ..log('Published')
      ..succeed();
    return [
      done,
      GgParallelLogLane.example(name: 'gg_status_printer')
        ..start()
        ..log('+3: test'),
      GgParallelLogLane.example(name: 'gg'),
      GgParallelLogLane.example(name: 'gg_one')
        ..start()
        ..fail('boom'),
      GgParallelLogLane.example(name: 'gg_git')..cancel(),
    ];
  }

  String name(String n) => n.padRight(17);

  group('GgParallelLogOverview', () {
    group('lines()', () {
      test('shows a header, a row per lane and the keys', () {
        fakeAsync((fake) {
          final overview = GgParallelLogOverview(
            title: 'gg do publish',
            lanes: lanesOfAllKinds(fake),
            elapsed: const Duration(seconds: 42),
            width: 100,
          );
          expect(overview.lines(), [
            ' gg do publish · 3/5 done · 1 failed · 1 cancelled · 00:42',
            '❯ ✓ ${name('gg_log')}  00:05  Published',
            '  ⠋ ${name('gg_status_printer')}  00:00  +3: test',
            '  ○ ${name('gg')}         waiting',
            '  ✗ ${name('gg_one')}  00:00  boom',
            '  ⊘ ${name('gg_git')}  00:00  cancelled',
            ' ↑↓ select · ⏎ open · f errors only · x cancel · s save · '
                'q cancel all',
          ]);
        });
      });

      test('filters the failed lanes', () {
        fakeAsync((fake) {
          final lines = GgParallelLogOverview.example(
            lanes: lanesOfAllKinds(fake),
            state: const GgParallelLogViewState(errorsOnly: true),
            width: 100,
          ).lines();
          expect(lines[0], endsWith('00:00 · errors only'));
          expect(lines.sublist(1), [
            '❯ ✗ ${name('gg_one')}  00:00  boom',
            ' ↑↓ select · ⏎ open · f all lanes · x cancel · s save · '
                'q cancel all',
          ]);
        });
      });

      test('says when there is nothing to list', () {
        expect(
          GgParallelLogOverview.example(lanes: []).lines()[1],
          '   No lanes',
        );
        expect(
          GgParallelLogOverview.example(
            lanes: [],
            state: const GgParallelLogViewState(errorsOnly: true),
          ).lines()[1],
          '   No failed lanes',
        );
      });

      test('scrolls the rows around the selection', () {
        final lanes = [
          for (var i = 0; i < 10; i++) GgParallelLogLane.example(name: 'l$i'),
        ];
        List<String> rows(int selected) => GgParallelLogOverview.example(
          lanes: lanes,
          height: 6,
          state: GgParallelLogViewState(selected: selected),
        ).lines().sublist(1, 4);

        expect(rows(5), [
          '   ↑ 5 more',
          '❯ ○ l5           waiting',
          '   ↓ 4 more',
        ]);
        expect(rows(0).first, '');
        expect(rows(9).last, '');
      });

      test('shows notices and confirmations in the footer', () {
        String footer(GgParallelLogViewState state) =>
            GgParallelLogOverview.example(
              state: state,
              width: 100,
            ).lines().last;

        expect(footer(const GgParallelLogViewState(notice: 'Saved')), ' Saved');
        expect(
          footer(
            const GgParallelLogViewState(
              confirm: GgParallelLogConfirm.cancelLane,
            ),
          ),
          ' Press x again to cancel gg_log',
        );
        expect(
          footer(
            const GgParallelLogViewState(
              confirm: GgParallelLogConfirm.cancelAll,
            ),
          ),
          ' Press q again to cancel all running lanes',
        );
      });

      test('names no lane in the confirmation when the list is empty', () {
        final lines = GgParallelLogOverview.example(
          lanes: [],
          state: const GgParallelLogViewState(
            confirm: GgParallelLogConfirm.cancelLane,
          ),
        ).lines();
        expect(lines.last, ' Press x again to cancel ');
      });

      test('keeps every line narrower than the terminal', () {
        final lines = GgParallelLogOverview.example(width: 20).lines();
        expect(lines.first, ' gg do publish · 0…');
      });
    });

    group('nameWidth(lanes)', () {
      test('fits the longest name between 4 and 28 columns', () {
        GgParallelLogLane lane(int length) =>
            GgParallelLogLane.example(name: 'x' * length);
        expect(GgParallelLogOverview.nameWidth([lane(2)]), 4);
        expect(GgParallelLogOverview.nameWidth([lane(2), lane(10)]), 10);
        expect(GgParallelLogOverview.nameWidth([lane(40)]), 28);
      });
    });
  });
}
