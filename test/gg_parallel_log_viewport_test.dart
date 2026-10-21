// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_parallel_log/src/gg_parallel_log_viewport.dart';
import 'package:test/test.dart';

void main() {
  group('GgParallelLogViewport', () {
    group('bodyHeight(height)', () {
      for (final (height, body) in [(24, 20), (6, 2), (5, 1), (4, 1), (0, 1)]) {
        test('shows $body output lines on $height rows', () {
          expect(GgParallelLogViewport.bodyHeight(height), body);
        });
      }
    });

    group('firstLine(total, top, height)', () {
      for (final (total, top, first) in [
        (30, null, 24),
        (30, 5, 5),
        (30, -3, 0),
        (30, 24, 24),
        (30, 99, 24),
        (6, null, 0),
        (3, null, 0),
        (3, 2, 0),
        (0, null, 0),
      ]) {
        test('starts $total lines scrolled to $top at $first', () {
          expect(GgParallelLogViewport.firstLine(total, top, 10), first);
        });
      }
    });

    group('lastFirstLine(total, height)', () {
      for (final (total, height, last) in [
        (30, 10, 24),
        (30, 24, 10),
        (7, 10, 1),
        (6, 10, 0),
        (0, 10, 0),
        (30, 1, 29),
      ]) {
        test('starts the end of $total lines on $height rows at $last', () {
          expect(GgParallelLogViewport.lastFirstLine(total, height), last);
        });
      }
    });
  });
}
