// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:test/test.dart';

void main() {
  group('GgParallelLogLine', () {
    group('GgParallelLogLine(text, time, isError)', () {
      test('is no error by default', () {
        final line = GgParallelLogLine(text: 'a', time: Duration.zero);
        expect(line.isError, isFalse);
      });
    });

    group('example()', () {
      test('has realistic defaults', () {
        final line = GgParallelLogLine.example();
        expect(
          [line.text, line.time, line.isError],
          ['00:03 +12: All tests passed!', const Duration(seconds: 3), false],
        );
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

    group('searchText', () {
      test('is the text in lower case', () {
        final line = GgParallelLogLine.example(text: 'Expected: ÄÖÜ');
        expect(line.searchText, 'expected: äöü');
      });

      test('has no colors, cursor moves or OSC links', () {
        const link = '\x1B]8;;https://ggsuite.dev\x07Link\x1B]8;;\x07';
        final line = GgParallelLogLine.example(
          text: '\x1B[31mFAIL\x1B[0m $link\x1B[2K',
        );
        expect(line.searchText, 'fail link');
      });

      test('keeps emoji and wide characters', () {
        final line = GgParallelLogLine.example(text: '✅ 中文 😀');
        expect(line.searchText, '✅ 中文 😀');
      });

      test('is empty for an empty line', () {
        expect(GgParallelLogLine.example(text: '').searchText, '');
      });
    });
  });
}
