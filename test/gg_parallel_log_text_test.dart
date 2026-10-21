// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_parallel_log/src/gg_parallel_log_text.dart';
import 'package:test/test.dart';

void main() {
  const red = '\x1B[31m';
  const reset = '\x1B[0m';

  group('GgParallelLogText', () {
    group('visibleWidth(text)', () {
      final cases = {
        'abc': 3,
        '${red}ab$reset': 2,
        '⌛️': 2,
        'é': 1,
        '中文': 4,
        '😀': 2,
        '✓': 1,
        '\u{40000}': 1,
        '\x07': 0,
      };
      for (final MapEntry(:key, :value) in cases.entries) {
        test('returns $value for "$key"', () {
          expect(GgParallelLogText.visibleWidth(key), value);
        });
      }
    });

    group('runeWidth(rune)', () {
      test('returns 0, 1 or 2', () {
        expect([0x0A, 0x41, 0x4E2D, 0xFE0F].map(GgParallelLogText.runeWidth), [
          0,
          1,
          2,
          0,
        ]);
      });
    });

    group('stripAnsi(text)', () {
      test('removes colors, cursor moves and OSC sequences', () {
        const text = '$red\x1B[1A\x1B[2Ka$reset\x1B]0;title\x07b\x1B=\x1B7';
        expect(GgParallelLogText.stripAnsi(text), 'ab');
      });
    });

    group('sanitize(text)', () {
      test('keeps colors, drops cursor moves, CR and tabs', () {
        const text = '${red}a$reset\x1B[2K\r\tb';
        expect(GgParallelLogText.sanitize(text), '${red}a$reset    b');
      });
    });

    group('truncate(text, width)', () {
      test('returns short text unchanged', () {
        expect(GgParallelLogText.truncate('abc', 3), 'abc');
      });

      test('returns an empty string for a width of zero', () {
        expect(GgParallelLogText.truncate('abc', 0), '');
      });

      test('cuts and adds an ellipsis', () {
        expect(GgParallelLogText.truncate('abcdef', 4), 'abc…');
      });

      test('keeps escape sequences and resets the colors', () {
        expect(
          GgParallelLogText.truncate('${red}abcdef$reset', 4),
          '${red}abc…$reset',
        );
      });

      test('never splits a wide character', () {
        expect(GgParallelLogText.truncate('中中中', 4), '中…');
      });
    });

    group('pad(text, width)', () {
      test('fills up with spaces', () {
        expect(GgParallelLogText.pad('${red}ab$reset', 4), '${red}ab$reset  ');
      });

      test('keeps text that is already wide enough', () {
        expect(GgParallelLogText.pad('abcd', 2), 'abcd');
      });
    });

    group('fit(text, width)', () {
      test('cuts or pads to the exact width', () {
        expect(GgParallelLogText.fit('abcdef', 4), 'abc…');
        expect(GgParallelLogText.fit('ab', 4), 'ab  ');
      });
    });

    group('spread(left, right, width)', () {
      test('puts the right text at the right edge', () {
        expect(GgParallelLogText.spread('a', 'b', 5), 'a   b');
      });

      test('drops the right text when there is no room', () {
        expect(GgParallelLogText.spread('abc', 'def', 5), 'abc');
      });
    });

    group('duration(duration)', () {
      test('formats minutes and hours', () {
        expect(
          GgParallelLogText.duration(const Duration(seconds: 65)),
          '01:05',
        );
        expect(
          GgParallelLogText.duration(const Duration(seconds: 3725)),
          '1:02:05',
        );
      });
    });

    group('inverse(text)', () {
      test('wraps the text in reverse video', () {
        expect(GgParallelLogText.inverse('x'), '\x1B[7mx\x1B[27m');
      });
    });

    group('highlight(text, query)', () {
      test('inverts every match ignoring case and colors', () {
        expect(
          GgParallelLogText.highlight('${red}Expected exp$reset', 'exp'),
          '\x1B[7mExp\x1B[27mected \x1B[7mexp\x1B[27m',
        );
      });

      test('returns the text unchanged for an empty query', () {
        expect(GgParallelLogText.highlight('${red}a', ''), '${red}a');
      });
    });

    group('contains(text, query)', () {
      test('ignores case and colors', () {
        expect(GgParallelLogText.contains('${red}Ab$reset', 'aB'), isTrue);
        expect(GgParallelLogText.contains('ab', 'c'), isFalse);
      });
    });
  });
}
