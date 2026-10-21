// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:test/test.dart';

void main() {
  List<List<String>> names(GgParallelLogResult r) => [
    r.succeeded,
    r.failed,
    r.cancelled,
    r.unfinished,
  ];

  group('GgParallelLogResult', () {
    group('GgParallelLogResult()', () {
      test('lists no lanes by default', () {
        expect(names(const GgParallelLogResult()), [
          <String>[],
          <String>[],
          <String>[],
          <String>[],
        ]);
      });
    });

    group('example()', () {
      test('has one succeeded and one failed lane by default', () {
        expect(names(GgParallelLogResult.example()), [
          ['gg_log'],
          ['gg_one'],
          <String>[],
          <String>[],
        ]);
      });

      test('takes the lanes a test cares about', () {
        final result = GgParallelLogResult.example(
          succeeded: ['a', 'b'],
          failed: [],
          cancelled: ['c'],
          unfinished: ['d'],
        );
        expect(names(result), [
          ['a', 'b'],
          <String>[],
          ['c'],
          ['d'],
        ]);
      });

      test('fails by default', () {
        final result = GgParallelLogResult.example();
        expect([result.isSuccess, result.exitCode], [false, 1]);
      });
    });

    group('of(lanes)', () {
      test('sorts the lane names by status and keeps their order', () {
        final lanes = [
          GgParallelLogLane.example(name: 'waiting'),
          GgParallelLogLane.example(name: 'ok 1')..succeed(),
          GgParallelLogLane.example(name: 'running')..start(),
          GgParallelLogLane.example(name: 'failed')..fail('boom'),
          GgParallelLogLane.example(name: 'cancelled')..cancel(),
          GgParallelLogLane.example(name: 'ok 2')
            ..start()
            ..succeed(),
        ];
        expect(names(GgParallelLogResult.of(lanes)), [
          ['ok 1', 'ok 2'],
          ['failed'],
          ['cancelled'],
          ['waiting', 'running'],
        ]);
      });

      test('lists nothing for no lanes', () {
        expect(names(GgParallelLogResult.of([])), [
          <String>[],
          <String>[],
          <String>[],
          <String>[],
        ]);
      });
    });

    group('isSuccess', () {
      final cases = [
        ('no lanes', const GgParallelLogResult(), true),
        ('succeeded lanes', const GgParallelLogResult(succeeded: ['a']), true),
        (
          'a failed lane',
          const GgParallelLogResult(succeeded: ['a'], failed: ['b']),
          false,
        ),
        (
          'a cancelled lane',
          const GgParallelLogResult(cancelled: ['a']),
          false,
        ),
        (
          'an unfinished lane',
          const GgParallelLogResult(unfinished: ['a']),
          false,
        ),
      ];
      for (final (name, result, expected) in cases) {
        test('is $expected for $name', () {
          expect(result.isSuccess, expected);
        });
      }
    });

    group('exitCode', () {
      test('is 0 when every lane succeeded', () {
        expect(const GgParallelLogResult(succeeded: ['a', 'b']).exitCode, 0);
      });

      test('is 0 for no lanes', () {
        expect(const GgParallelLogResult().exitCode, 0);
      });

      for (final (name, result) in [
        ('a failed', const GgParallelLogResult(failed: ['a'])),
        ('a cancelled', const GgParallelLogResult(cancelled: ['a'])),
        ('an unfinished', const GgParallelLogResult(unfinished: ['a'])),
      ]) {
        test('is 1 for $name lane', () {
          expect(result.exitCode, 1);
        });
      }

      test('is 1 for lanes that are still running', () {
        final lane = GgParallelLogLane.example()..start();
        expect(GgParallelLogResult.of([lane]).exitCode, 1);
      });
    });
  });
}
