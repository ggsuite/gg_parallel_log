// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:test/test.dart';

void main() {
  setUp(() => ggColorsEnabled = false);
  tearDown(() => ggColorsEnabled = null);

  group('GgParallelLogStatus', () {
    group('isDone', () {
      test('is true for success, error and cancelled', () {
        expect(GgParallelLogStatus.values.where((s) => s.isDone), [
          GgParallelLogStatus.success,
          GgParallelLogStatus.error,
          GgParallelLogStatus.cancelled,
        ]);
      });
    });

    group('icon(frame)', () {
      test('returns one icon per status', () {
        expect(GgParallelLogStatus.values.map((s) => s.icon(0)), [
          '○',
          '⠋',
          '✓',
          '✗',
          '⊘',
        ]);
      });

      test('animates the spinner and wraps around', () {
        expect(GgParallelLogStatus.running.icon(1), '⠙');
        expect(GgParallelLogStatus.running.icon(10), '⠋');
      });

      test('colors the icon when colors are enabled', () {
        ggColorsEnabled = true;
        expect(GgParallelLogStatus.success.icon(0), green('✓'));
      });
    });
  });
}
