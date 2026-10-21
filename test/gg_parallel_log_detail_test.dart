// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_detail.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_view_state.dart';
import 'package:test/test.dart';

void main() {
  late GgParallelLogLane lane;

  setUp(() {
    ggColorsEnabled = false;
    lane = GgParallelLogLane.example(name: 'gg_one')..start();
    for (var i = 1; i <= 30; i++) {
      lane.log('line $i');
    }
    lane.logError('Expected: 3');
  });
  tearDown(() => ggColorsEnabled = null);

  GgParallelLogViewState detail({
    int scroll = 0,
    String query = '',
    int match = -1,
  }) => GgParallelLogViewState(
    mode: GgParallelLogMode.detail,
    scroll: scroll,
    query: query,
    match: match,
  );

  List<String> render(GgParallelLogViewState state, {int height = 10}) =>
      GgParallelLogDetail.example(
        lane: lane,
        state: state,
        width: 60,
        height: height,
      ).lines();

  group('GgParallelLogDetail', () {
    group('lines()', () {
      test('shows the end of the output and follows it', () {
        expect(render(detail()), [
          ' ⠋ gg_one  running · 00:00${' ' * 25}lane 1/1',
          '─' * 59,
          '  00:00 │ line 26',
          '  00:00 │ line 27',
          '  00:00 │ line 28',
          '  00:00 │ line 29',
          '  00:00 │ line 30',
          '  00:00 │ Expected: 3',
          '── 26–31 of 31 · following ${'─' * 32}',
          ' ↑↓ scroll · ←→ lane · / search · n N match · s save · x c…',
        ]);
      });

      test('scrolls up and stops at the first line', () {
        expect(render(detail(scroll: 3))[2], '  00:00 │ line 23');
        expect(render(detail(scroll: 99))[2], '  00:00 │ line 1');
        expect(render(detail(scroll: 3))[8], startsWith('── 23–28 of 31 ─'));
      });

      test('pads a short output and says when there is none', () {
        final empty = GgParallelLogDetail.example().lines();
        expect(empty.length, 24);
        expect(empty[2], '');
        expect(empty[22], startsWith('── no output yet ─'));
      });

      test('marks and highlights the search matches', () {
        final lines = render(detail(query: 'line 3', match: 29));
        expect(lines[6], '❯ 00:00 │ \x1B[7mline 3\x1B[27m0');
        expect(lines.last, startsWith(' "line 3" 2/2 · ↑↓ scroll'));
      });

      test('highlights while the user types the query', () {
        final lines = render(
          const GgParallelLogViewState(
            mode: GgParallelLogMode.search,
            input: 'expected',
          ),
        );
        expect(lines[7], '  00:00 │ \x1B[7mExpected\x1B[27m: 3');
        expect(
          lines.last,
          ' /expected▏${' ' * 15}1 matches · ⏎ search · Esc cancel',
        );
      });

      test('colors error lines', () {
        ggColorsEnabled = true;
        expect(render(detail())[7], endsWith(red('Expected: 3')));
      });

      test('ends the highlight inside a colored error line', () {
        ggColorsEnabled = true;
        expect(
          render(detail(query: 'exp'))[7],
          endsWith(red('\x1B[7mExp\x1B[27mected: 3')),
        );
      });

      test('shows notices and confirmations in the footer', () {
        expect(render(detail().copyWith(notice: 'Saved')).last, ' Saved');
        expect(
          render(detail().copyWith(confirm: GgParallelLogConfirm.cancelLane))
              .last,
          ' Press x again to cancel gg_one',
        );
      });
    });

    group('bodyHeight(height)', () {
      test('leaves room for four rows and shows at least one line', () {
        expect(GgParallelLogDetail.bodyHeight(10), 6);
        expect(GgParallelLogDetail.bodyHeight(3), 1);
      });
    });

    group('matches(lane, query)', () {
      test('returns the matching line indices', () {
        expect(GgParallelLogDetail.matches(lane, 'LINE 3'), [2, 29]);
        expect(GgParallelLogDetail.matches(lane, ''), isEmpty);
      });
    });
  });
}
