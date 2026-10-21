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
      test('is true for success, error and cancelled only', () {
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

      test('shows the spinner frame by frame and wraps around', () {
        expect(
          [for (var f = 0; f < 11; f++) GgParallelLogStatus.running.icon(f)],
          [...GgParallelLogStatus.spinner, '⠋'],
        );
      });

      test('ignores the frame when not running', () {
        expect(
          [
            GgParallelLogStatus.success.icon(0),
            GgParallelLogStatus.success.icon(7),
          ],
          ['✓', '✓'],
        );
      });

      test('colors the icon when colors are enabled', () {
        ggColorsEnabled = true;
        expect(GgParallelLogStatus.values.map((s) => s.icon(1)), [
          darkGray('○'),
          cyan('⠙'),
          green('✓'),
          red('✗'),
          yellow('⊘'),
        ]);
      });
    });

    group('spinner', () {
      test('holds ten braille frames', () {
        expect(GgParallelLogStatus.spinner, [
          '⠋',
          '⠙',
          '⠹',
          '⠸',
          '⠼',
          '⠴',
          '⠦',
          '⠧',
          '⠇',
          '⠏',
        ]);
      });
    });
  });
}
