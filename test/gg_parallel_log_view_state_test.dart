// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_view_state.dart';
import 'package:test/test.dart';

void main() {
  group('GgParallelLogViewState', () {
    test('shows the unfiltered overview by default', () {
      const state = GgParallelLogViewState();
      expect(state.mode, GgParallelLogMode.overview);
      expect([state.selected, state.scroll, state.match], [0, 0, -1]);
      expect([state.query, state.input, state.notice], ['', '', '']);
      expect(state.errorsOnly, isFalse);
      expect(state.confirm, GgParallelLogConfirm.none);
    });

    test('example() takes the values a test cares about', () {
      final state = GgParallelLogViewState.example(
        mode: GgParallelLogMode.detail,
        selected: 2,
        errorsOnly: true,
        scroll: 5,
        query: 'E]',
      );
      expect(state.mode, GgParallelLogMode.detail);
      expect([state.selected, state.scroll], [2, 5]);
      expect([state.errorsOnly, state.query], [true, 'E]']);
      expect(GgParallelLogViewState.example().mode, GgParallelLogMode.overview);
    });

    group('copyWith()', () {
      test('replaces the given values and keeps the rest', () {
        const state = GgParallelLogViewState(query: 'q', selected: 1);
        final copy = state.copyWith(
          mode: GgParallelLogMode.search,
          errorsOnly: true,
          scroll: 3,
          input: 'in',
          match: 7,
          notice: 'n',
          confirm: GgParallelLogConfirm.cancelAll,
        );
        expect(copy.mode, GgParallelLogMode.search);
        expect([copy.selected, copy.scroll, copy.match], [1, 3, 7]);
        expect([copy.query, copy.input, copy.notice], ['q', 'in', 'n']);
        expect(copy.errorsOnly, isTrue);
        expect(copy.confirm, GgParallelLogConfirm.cancelAll);
        expect(state.copyWith().query, 'q');
      });
    });

    group('visibleLanes(lanes)', () {
      test('lists all lanes or only the failed ones', () {
        final ok = GgParallelLogLane.example(name: 'ok')..succeed();
        final failed = GgParallelLogLane.example(name: 'failed')..fail('x');
        final lanes = [ok, failed];
        expect(const GgParallelLogViewState().visibleLanes(lanes), lanes);
        expect(
          const GgParallelLogViewState(errorsOnly: true).visibleLanes(lanes),
          [failed],
        );
      });
    });
  });
}
