// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_view_state.dart';
import 'package:test/test.dart';

void main() {
  const info = GgParallelLogNoticeKind.info;
  const warning = GgParallelLogNoticeKind.warning;
  const error = GgParallelLogNoticeKind.error;

  // Returns all fields of [s] in the order of the constructor.
  List<Object?> fields(GgParallelLogViewState s) => [
    s.mode,
    s.selected,
    s.errorsOnly,
    s.top,
    s.query,
    s.input,
    s.match,
    s.notice,
    s.noticeKind,
    s.confirm,
    s.interrupted,
  ];

  group('GgParallelLogNoticeKind', () {
    test('has info, warning and error', () {
      expect(GgParallelLogNoticeKind.values, [info, warning, error]);
    });
  });

  group('GgParallelLogViewState', () {
    group('GgParallelLogViewState()', () {
      test('shows the unfiltered overview without a selection', () {
        expect(fields(const GgParallelLogViewState()), [
          GgParallelLogMode.overview,
          null,
          false,
          null,
          '',
          '',
          null,
          '',
          info,
          GgParallelLogConfirm.none,
          false,
        ]);
      });
    });

    group('example()', () {
      test('selects gg_log in the overview by default', () {
        expect(fields(GgParallelLogViewState.example()), [
          GgParallelLogMode.overview,
          'gg_log',
          false,
          null,
          '',
          '',
          null,
          '',
          info,
          GgParallelLogConfirm.none,
          false,
        ]);
      });

      test('takes the values a test cares about', () {
        final state = GgParallelLogViewState.example(
          mode: GgParallelLogMode.search,
          selected: 'gg_one',
          errorsOnly: true,
          top: 5,
          query: 'E]',
          input: 'err',
          match: 7,
          notice: 'Cannot save',
          noticeKind: error,
          confirm: GgParallelLogConfirm.cancelLane,
          interrupted: true,
        );
        expect(fields(state), [
          GgParallelLogMode.search,
          'gg_one',
          true,
          5,
          'E]',
          'err',
          7,
          'Cannot save',
          error,
          GgParallelLogConfirm.cancelLane,
          true,
        ]);
      });
    });

    group('copyWith(...)', () {
      final state = GgParallelLogViewState.example(
        mode: GgParallelLogMode.detail,
        top: 3,
        query: 'q',
        match: 4,
        notice: 'n',
        noticeKind: warning,
      );

      test('keeps every value when nothing is given', () {
        expect(fields(state.copyWith()), fields(state));
      });

      test('replaces the given values and keeps the rest', () {
        final copy = state.copyWith(
          mode: GgParallelLogMode.search,
          selected: 'gg_one',
          errorsOnly: true,
          top: 9,
          query: 'x',
          input: 'in',
          match: 8,
          notice: 'Cannot save',
          noticeKind: error,
          confirm: GgParallelLogConfirm.cancelAll,
          interrupted: true,
        );
        expect(fields(copy), [
          GgParallelLogMode.search,
          'gg_one',
          true,
          9,
          'x',
          'in',
          8,
          'Cannot save',
          error,
          GgParallelLogConfirm.cancelAll,
          true,
        ]);
      });

      test('leaves the original unchanged', () {
        state.copyWith(mode: GgParallelLogMode.overview, top: 1);
        expect([state.mode, state.top], [GgParallelLogMode.detail, 3]);
      });

      test('clears top with following', () {
        expect(state.copyWith(following: true).top, isNull);
      });

      test('prefers following over a given top', () {
        expect(state.copyWith(following: true, top: 5).top, isNull);
      });

      test('clears match with noMatch', () {
        expect(state.copyWith(noMatch: true).match, isNull);
      });

      test('prefers noMatch over a given match', () {
        expect(state.copyWith(noMatch: true, match: 5).match, isNull);
      });

      test('makes a new notice an info when no kind is given', () {
        final copy = state.copyWith(notice: 'Saved');
        expect([copy.notice, copy.noticeKind], ['Saved', info]);
      });

      test('makes a cleared notice an info', () {
        final copy = state.copyWith(notice: '');
        expect([copy.notice, copy.noticeKind], ['', info]);
      });

      test('keeps the kind when the notice stays', () {
        final copy = state.copyWith(top: 1);
        expect([copy.notice, copy.noticeKind], ['n', warning]);
      });

      test('changes only the kind when no notice is given', () {
        final copy = state.copyWith(noticeKind: error);
        expect([copy.notice, copy.noticeKind], ['n', error]);
      });

      test('keeps interrupted until it is cleared', () {
        final interrupted = state.copyWith(interrupted: true);
        expect(
          [
            interrupted.interrupted,
            interrupted.copyWith().interrupted,
            interrupted.copyWith(interrupted: false).interrupted,
          ],
          [true, true, false],
        );
      });
    });

    group('activeQuery', () {
      for (final (mode, expected) in [
        (GgParallelLogMode.overview, 'query'),
        (GgParallelLogMode.detail, 'query'),
        (GgParallelLogMode.search, 'input'),
      ]) {
        test('is the $expected in the ${mode.name} mode', () {
          final state = GgParallelLogViewState.example(
            mode: mode,
            query: 'query',
            input: 'input',
          );
          expect(state.activeQuery, expected);
        });
      }

      test('is empty while an empty query is typed', () {
        final state = GgParallelLogViewState.example(
          mode: GgParallelLogMode.search,
          query: 'old',
        );
        expect(state.activeQuery, '');
      });
    });

    group('visibleLanes(lanes)', () {
      final ok = GgParallelLogLane.example(name: 'ok')..succeed();
      final failed1 = GgParallelLogLane.example(name: 'f1')..fail('x');
      final running = GgParallelLogLane.example(name: 'run')..start();
      final cancelled = GgParallelLogLane.example(name: 'c')..cancel();
      final failed2 = GgParallelLogLane.example(name: 'f2')..fail('y');
      final lanes = [ok, failed1, running, cancelled, failed2];

      test('lists all lanes by default', () {
        expect(const GgParallelLogViewState().visibleLanes(lanes), same(lanes));
      });

      test('lists only the failed lanes in their order with errorsOnly', () {
        expect(
          const GgParallelLogViewState(errorsOnly: true).visibleLanes(lanes),
          [failed1, failed2],
        );
      });

      test('lists nothing with errorsOnly when no lane failed', () {
        expect(
          const GgParallelLogViewState(errorsOnly: true)
              .visibleLanes([ok, running, cancelled]),
          isEmpty,
        );
      });
    });

    group('selectedIndex(visible)', () {
      final lanes = [
        for (final name in ['a', 'b', 'c'])
          GgParallelLogLane.example(name: name),
      ];

      test('returns the position of the selected lane', () {
        expect(
          GgParallelLogViewState.example(selected: 'c').selectedIndex(lanes),
          2,
        );
      });

      test('returns 0 when the selected lane is not visible', () {
        expect(
          GgParallelLogViewState.example(selected: 'x').selectedIndex(lanes),
          0,
        );
      });

      test('returns 0 when no lane is selected', () {
        expect(const GgParallelLogViewState().selectedIndex(lanes), 0);
      });

      test('returns 0 when no lane is visible', () {
        expect(GgParallelLogViewState.example().selectedIndex([]), 0);
      });
    });
  });
}
