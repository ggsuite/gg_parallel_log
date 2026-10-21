// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:test/test.dart';

void main() {
  group('GgParallelLogCancelledException', () {
    group('GgParallelLogCancelledException(lane)', () {
      test('is an Exception holding the name of the lane', () {
        const exception = GgParallelLogCancelledException('gg_one');
        expect(exception, isA<Exception>());
        expect(exception.lane, 'gg_one');
      });
    });

    group('example()', () {
      test('names the lane gg_log by default', () {
        expect(GgParallelLogCancelledException.example().lane, 'gg_log');
      });

      test('takes the lane a test cares about', () {
        expect(
          GgParallelLogCancelledException.example(lane: 'gg_one').lane,
          'gg_one',
        );
      });
    });

    group('toString()', () {
      test('tells which lane was cancelled', () {
        expect(
          GgParallelLogCancelledException.example().toString(),
          'Lane "gg_log" was cancelled.',
        );
      });

      test('keeps unicode in the lane name', () {
        expect(
          GgParallelLogCancelledException.example(lane: 'büld 🚀').toString(),
          'Lane "büld 🚀" was cancelled.',
        );
      });
    });

    test('can be thrown and caught by type', () {
      expect(
        () => throw GgParallelLogCancelledException.example(lane: 'a'),
        throwsA(
          isA<GgParallelLogCancelledException>()
              .having((e) => e.lane, 'lane', 'a')
              .having(
                (e) => e.toString(),
                'toString()',
                'Lane "a" was cancelled.',
              ),
        ),
      );
    });
  });
}
