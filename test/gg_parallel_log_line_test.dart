// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:test/test.dart';

void main() {
  group('GgParallelLogLine', () {
    test('is no error by default', () {
      const line = GgParallelLogLine(text: 'a', time: Duration.zero);
      expect(line.isError, isFalse);
    });

    group('example()', () {
      test('has realistic defaults', () {
        final line = GgParallelLogLine.example();
        expect(line.text, '00:03 +12: All tests passed!');
        expect(line.time, const Duration(seconds: 3));
        expect(line.isError, isFalse);
      });

      test('takes the values a test cares about', () {
        final line = GgParallelLogLine.example(
          text: 'boom',
          time: Duration.zero,
          isError: true,
        );
        expect(
          [line.text, line.time, line.isError],
          ['boom', Duration.zero, true],
        );
      });
    });
  });
}
