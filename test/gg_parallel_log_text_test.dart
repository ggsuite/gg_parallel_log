// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_parallel_log/src/gg_parallel_log_text.dart';
import 'package:test/test.dart';

void main() {
  const red = '\x1B[31m';
  const green = '\x1B[32m';
  const reset = '\x1B[0m';
  const hourglass = '⌛\uFE0F';
  const check = '✔\uFE0F';
  const linkBel = '\x1B]8;;https://ggsuite.dev\x07';
  const linkEndBel = '\x1B]8;;\x07';
  const linkSt = '\x1B]8;;https://ggsuite.dev\x1B\\';
  const linkEndSt = '\x1B]8;;\x1B\\';

  group('GgParallelLogText', () {
    group('visibleWidth(text)', () {
      final cases = <String, (String, int)>{
        'empty text': ('', 0),
        'ASCII': ('abc', 3),
        'colored text': ('${red}ab$reset', 2),
        'an OSC link ended by BEL': ('${linkBel}link$linkEndBel', 4),
        'an OSC link ended by ST': ('${linkSt}link$linkEndSt', 4),
        'an emoji with FE0F': (hourglass, 2),
        'a narrow symbol made an emoji by FE0F': (check, 2),
        'a narrow symbol without FE0F': ('✔', 1),
        'a combining mark': ('e\u0301', 1),
        'CJK characters': ('中文', 4),
        'Hangul': ('한', 2),
        'a fullwidth letter': ('Ａ', 2),
        'a halfwidth katakana': ('ｱ', 1),
        'an emoji as surrogate pair': ('😀', 2),
        'a wide surrogate pair': ('\u{20000}', 2),
        'a narrow surrogate pair': ('\u{40000}', 1),
        'a zero width space': ('a\u200Bb', 2),
        'a bell': ('\x07', 0),
        'a lone FE0F': ('\uFE0F', 0),
      };
      for (final MapEntry(key: name, value: (text, width)) in cases.entries) {
        test('returns $width for $name', () {
          expect(GgParallelLogText.visibleWidth(text), width);
        });
      }
    });

    group('runeWidth(rune)', () {
      test('returns 0 for C0 control characters', () {
        expect([0x00, 0x09, 0x1B, 0x1F].map(GgParallelLogText.runeWidth), [
          0,
          0,
          0,
          0,
        ]);
      });

      test('returns 0 for DEL and C1 control characters', () {
        expect([0x7F, 0x85, 0x9F].map(GgParallelLogText.runeWidth), [0, 0, 0]);
      });

      test('returns 0 for combining marks, zero width and selectors', () {
        expect(
          [
            0x0300,
            0x036F,
            0x200B,
            0x200D,
            0x200F,
            0xFE00,
            0xFE0F,
          ].map(GgParallelLogText.runeWidth),
          [0, 0, 0, 0, 0, 0, 0],
        );
      });

      test('returns 2 inside and 1 just outside the wide ranges', () {
        expect(
          [
            0x1100,
            0x115F,
            0x1160,
            0x4E2D,
            0x1F600,
            0x1F650,
            0x3FFFD,
            0x3FFFE,
          ].map(GgParallelLogText.runeWidth),
          [2, 2, 1, 2, 2, 1, 2, 1],
        );
      });

      test('returns 1 for printable narrow characters', () {
        expect([0x20, 0x41, 0xE9, 0x2713].map(GgParallelLogText.runeWidth), [
          1,
          1,
          1,
          1,
        ]);
      });
    });

    group('stripAnsi(text)', () {
      test('removes colors and cursor moves', () {
        expect(
          GgParallelLogText.stripAnsi('$red\x1B[1A\x1B[2Ka$reset\x1B[?25lb'),
          'ab',
        );
      });

      test('removes OSC sequences ended by BEL or ST', () {
        expect(
          GgParallelLogText.stripAnsi(
            '\x1B]0;title\x07${linkBel}a$linkEndBel ${linkSt}b$linkEndSt',
          ),
          'a b',
        );
      });

      test('removes escapes made of ESC and one character', () {
        expect(GgParallelLogText.stripAnsi('\x1B=a\x1B7b\x1B8'), 'ab');
      });

      test('returns text without escapes unchanged', () {
        expect(GgParallelLogText.stripAnsi('a😀$hourglass'), 'a😀$hourglass');
      });

      test('returns an empty string for empty text', () {
        expect(GgParallelLogText.stripAnsi(''), '');
      });
    });

    group('sanitize(text)', () {
      test('keeps colors and drops cursor moves', () {
        expect(
          GgParallelLogText.sanitize('\x1B[1;31ma$reset\x1B[2K\x1B[1Ab'),
          '\x1B[1;31ma${reset}b',
        );
      });

      test('replaces a tab by four spaces', () {
        expect(GgParallelLogText.sanitize('a\tb'), 'a    b');
      });

      test('drops C0, DEL and C1 control characters', () {
        expect(
          GgParallelLogText.sanitize('a\r\n\x07\x00\x1Cb\x7F\x85\x9Fc'),
          'abc',
        );
      });

      test('drops OSC links but keeps their text', () {
        expect(
          GgParallelLogText.sanitize(
            '${linkBel}a$linkEndBel ${linkSt}b$linkEndSt',
          ),
          'a b',
        );
      });

      test('drops escapes made of ESC and one character', () {
        expect(GgParallelLogText.sanitize('a\x1B7b\x1B8'), 'ab');
      });

      test('drops a lone escape character', () {
        expect(GgParallelLogText.sanitize('a\x1B'), 'a');
      });

      test('drops ESC m, which is no color', () {
        expect(GgParallelLogText.sanitize('a\x1Bmb'), 'ab');
      });

      test('keeps emoji and wide characters', () {
        expect(GgParallelLogText.sanitize('中$hourglass😀'), '中$hourglass😀');
      });
    });

    group('truncate(text, width)', () {
      test('returns short text unchanged', () {
        expect(GgParallelLogText.truncate('abc', 3), 'abc');
      });

      test('returns empty text unchanged', () {
        expect(GgParallelLogText.truncate('', 0), '');
      });

      test('returns an empty string for a width of zero or less', () {
        expect(
          [
            GgParallelLogText.truncate('abc', 0),
            GgParallelLogText.truncate('abc', -1),
          ],
          ['', ''],
        );
      });

      test('returns only the ellipsis for a width of one', () {
        expect(GgParallelLogText.truncate('abc', 1), '…');
      });

      test('cuts and adds an ellipsis', () {
        expect(GgParallelLogText.truncate('abcdef', 4), 'abc…');
      });

      test('ends colored text that fits with a reset', () {
        expect(GgParallelLogText.truncate('${red}ab', 4), '${red}ab$reset');
      });

      test('adds no second reset to text that fits', () {
        expect(
          GgParallelLogText.truncate('${red}ab$reset', 4),
          '${red}ab$reset',
        );
      });

      test('keeps the escapes after the cut and resets once', () {
        expect(
          GgParallelLogText.truncate('${red}abc${green}def', 3),
          '${red}ab…$green$reset',
        );
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

      test('never splits an emoji from its FE0F', () {
        expect(
          GgParallelLogText.truncate('$hourglass$hourglass', 3),
          '$hourglass…',
        );
      });

      test('never splits a surrogate pair', () {
        expect(GgParallelLogText.truncate('😀😀😀', 5), '😀😀…');
      });

      test('keeps a combining mark with its base character', () {
        expect(
          GgParallelLogText.truncate('e\u0301e\u0301e\u0301', 2),
          'e\u0301…',
        );
      });

      test('closes an OSC link that is cut', () {
        expect(
          GgParallelLogText.truncate('${linkSt}abcdef$linkEndSt', 4),
          '${linkSt}abc…$linkEndSt$reset',
        );
      });

      test('closes an OSC link ended by BEL that is cut', () {
        expect(
          GgParallelLogText.truncate('${linkBel}abcdef$linkEndBel', 4),
          '${linkBel}abc…$linkEndBel$reset',
        );
      });
    });

    group('pad(text, width)', () {
      test('fills up with spaces', () {
        expect(GgParallelLogText.pad('${red}ab$reset', 4), '${red}ab$reset  ');
      });

      test('counts wide characters and emoji twice', () {
        expect(
          [GgParallelLogText.pad('中', 3), GgParallelLogText.pad(hourglass, 3)],
          ['中 ', '$hourglass '],
        );
      });

      test('keeps text that is already wide enough', () {
        expect(GgParallelLogText.pad('abcd', 2), 'abcd');
      });
    });

    group('fit(text, width)', () {
      test('cuts long text to the exact width', () {
        expect(GgParallelLogText.fit('abcdef', 4), 'abc…');
      });

      test('pads short text to the exact width', () {
        expect(GgParallelLogText.fit('ab', 4), 'ab  ');
      });

      test('pads a cut wide character to the exact width', () {
        expect(GgParallelLogText.fit('中中中', 4), '中… ');
      });
    });

    group('spread(left, right, width)', () {
      test('puts the right text at the right edge', () {
        expect(GgParallelLogText.spread('a', 'b', 5), 'a   b');
      });

      test('measures the visible width of colored text', () {
        expect(
          GgParallelLogText.spread('${red}a$reset', '中', 5),
          '${red}a$reset  中',
        );
      });

      test('keeps a gap of one column', () {
        expect(GgParallelLogText.spread('ab', 'cd', 5), 'ab cd');
      });

      test('drops the right text when there is no room', () {
        expect(GgParallelLogText.spread('abc', 'de', 5), 'abc');
      });

      test('cuts the left text when it is too wide alone', () {
        expect(GgParallelLogText.spread('abcdef', 'x', 4), 'abc…');
      });
    });

    group('duration(duration)', () {
      final cases = {
        Duration.zero: '00:00',
        const Duration(milliseconds: 1999): '00:01',
        const Duration(seconds: 65): '01:05',
        const Duration(minutes: 59, seconds: 59): '59:59',
        const Duration(hours: 1): '1:00:00',
        const Duration(seconds: 3725): '1:02:05',
        const Duration(hours: 25, minutes: 3): '25:03:00',
      };
      for (final MapEntry(:key, :value) in cases.entries) {
        test('returns $value for $key', () {
          expect(GgParallelLogText.duration(key), value);
        });
      }
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

      test('ignores the case of umlauts', () {
        expect(
          GgParallelLogText.highlight('Äpfel', 'ä'),
          '\x1B[7mÄ\x1B[27mpfel',
        );
      });

      test('treats the query literally, not as a pattern', () {
        expect(
          GgParallelLogText.highlight('a.b axb [E]', '.b'),
          'a\x1B[7m.b\x1B[27m axb [E]',
        );
      });

      test('finds emoji', () {
        expect(
          GgParallelLogText.highlight('ok 😀', '😀'),
          'ok \x1B[7m😀\x1B[27m',
        );
      });

      test('returns the text without colors when nothing matches', () {
        expect(GgParallelLogText.highlight('${red}abc$reset', 'x'), 'abc');
      });

      test('returns the text unchanged for an empty query', () {
        expect(GgParallelLogText.highlight('${red}a', ''), '${red}a');
      });
    });

    group('dropLast(text)', () {
      test('returns an empty string for empty text', () {
        expect(GgParallelLogText.dropLast(''), '');
      });

      test('drops the last character', () {
        expect(GgParallelLogText.dropLast('abc'), 'ab');
      });

      test('drops a whole surrogate pair', () {
        expect(GgParallelLogText.dropLast('a😀'), 'a');
      });

      test('drops an emoji together with its FE0F', () {
        expect(GgParallelLogText.dropLast('a$hourglass'), 'a');
      });
    });
  });
}
