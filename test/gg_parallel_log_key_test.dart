// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_parallel_log/src/gg_parallel_log_key.dart';
import 'package:test/test.dart';

void main() {
  GgParallelLogKey key(GgParallelLogKeyType type) => GgParallelLogKey(type);
  GgParallelLogKey char(String c) => GgParallelLogKey.printable(c);
  String name(int unit) => switch (unit) {
    0x1B => 'ESC',
    0x0D => 'CR',
    0x0A => 'LF',
    0x7F => 'DEL',
    0x08 => 'BS',
    0x03 => 'ETX',
    _ => String.fromCharCode(unit),
  };

  group('GgParallelLogKey', () {
    group('GgParallelLogKey(type, char)', () {
      test('has no character by default', () {
        const up = GgParallelLogKey(GgParallelLogKeyType.up);
        expect([up.type, up.char], [GgParallelLogKeyType.up, '']);
      });
    });

    group('printable(char)', () {
      test('creates a character key', () {
        const k = GgParallelLogKey.printable('ä');
        expect([k.type, k.char], [GgParallelLogKeyType.char, 'ä']);
      });
    });

    group('example()', () {
      test('is the printable key f by default', () {
        expect(GgParallelLogKey.example(), char('f'));
      });

      test('takes the character a test cares about', () {
        expect(GgParallelLogKey.example(char: '/'), char('/'));
      });

      test('is the printable key f for the type char', () {
        expect(
          GgParallelLogKey.example(type: GgParallelLogKeyType.char),
          char('f'),
        );
      });

      test('has no character for a key that is not printable', () {
        expect(
          GgParallelLogKey.example(type: GgParallelLogKeyType.up),
          key(GgParallelLogKeyType.up),
        );
      });
    });

    group('isChar(c)', () {
      test('is true for the printable character only', () {
        expect(
          [
            char('q').isChar('q'),
            char('q').isChar('x'),
            char('q').isChar('Q'),
            key(GgParallelLogKeyType.up).isChar(''),
          ],
          [true, false, false, false],
        );
      });
    });

    group('==(other)', () {
      test('is true for the same type and character', () {
        expect(char('f') == GgParallelLogKey.example(), isTrue);
      });

      test('is false for another character', () {
        expect(char('f') == char('g'), isFalse);
      });

      test('is false for another type', () {
        expect(
          key(GgParallelLogKeyType.up) == key(GgParallelLogKeyType.down),
          isFalse,
        );
      });

      test('is false for another object', () {
        expect(char('f') == ('f' as Object), isFalse);
      });
    });

    group('hashCode', () {
      test('is equal for equal keys', () {
        expect(char('f').hashCode, GgParallelLogKey.example().hashCode);
      });
    });

    group('toString()', () {
      test('returns the character of a printable key', () {
        expect(char('😀').toString(), '😀');
      });

      test('returns the type name of other keys', () {
        expect(key(GgParallelLogKeyType.pageDown).toString(), 'pageDown');
      });
    });

    group('parse(input)', () {
      final sequences = {
        '\x1B[A': GgParallelLogKeyType.up,
        '\x1B[B': GgParallelLogKeyType.down,
        '\x1B[C': GgParallelLogKeyType.right,
        '\x1B[D': GgParallelLogKeyType.left,
        '\x1BOA': GgParallelLogKeyType.up,
        '\x1BOB': GgParallelLogKeyType.down,
        '\x1BOC': GgParallelLogKeyType.right,
        '\x1BOD': GgParallelLogKeyType.left,
        '\x1B[H': GgParallelLogKeyType.home,
        '\x1B[F': GgParallelLogKeyType.end,
        '\x1BOH': GgParallelLogKeyType.home,
        '\x1BOF': GgParallelLogKeyType.end,
        '\x1B[1~': GgParallelLogKeyType.home,
        '\x1B[4~': GgParallelLogKeyType.end,
        '\x1B[7~': GgParallelLogKeyType.home,
        '\x1B[8~': GgParallelLogKeyType.end,
        '\x1B[5~': GgParallelLogKeyType.pageUp,
        '\x1B[6~': GgParallelLogKeyType.pageDown,
        '\r': GgParallelLogKeyType.enter,
        '\n': GgParallelLogKeyType.enter,
        '\x1B': GgParallelLogKeyType.escape,
        '\x7F': GgParallelLogKeyType.backspace,
        '\x08': GgParallelLogKeyType.backspace,
        '\x03': GgParallelLogKeyType.ctrlC,
      };
      for (final MapEntry(:key, :value) in sequences.entries) {
        final shown = key.codeUnits.map(name).join(' ');
        test('reads ${value.name} from $shown', () {
          expect(GgParallelLogKey.parse(key), [GgParallelLogKey(value)]);
        });
      }

      test('returns no keys for empty input', () {
        expect(GgParallelLogKey.parse(''), isEmpty);
      });

      test('reads several keys and printable characters', () {
        expect(GgParallelLogKey.parse('\x1B[Bx \r'), [
          key(GgParallelLogKeyType.down),
          char('x'),
          char(' '),
          key(GgParallelLogKeyType.enter),
        ]);
      });

      test('reads umlauts, wide characters and surrogate pairs', () {
        expect(GgParallelLogKey.parse('ä中😀'), [
          char('ä'),
          char('中'),
          char('😀'),
        ]);
      });

      test('reads an emoji and its FE0F as they come', () {
        expect(GgParallelLogKey.parse('⌛\uFE0F'), [char('⌛'), char('\uFE0F')]);
      });

      test('skips control characters without a key', () {
        expect(GgParallelLogKey.parse('\x00a\tb\x1F'), [char('a'), char('b')]);
      });

      test('skips unknown CSI and SS3 sequences', () {
        expect(
          GgParallelLogKey.parse('\x1B[99~a\x1B[1;5A\x1B[<0;10;5Mb\x1BOPc'),
          [char('a'), char('b'), char('c')],
        );
      });

      test('skips Alt combinations', () {
        expect(GgParallelLogKey.parse('\x1Bx\x1B\r\x1Bäa'), [char('a')]);
      });

      test('skips Alt combinations with a surrogate pair', () {
        expect(GgParallelLogKey.parse('\x1B😀a'), [char('a')]);
      });

      test('reads ESC before another sequence as Escape', () {
        expect(GgParallelLogKey.parse('\x1B\x1B\x1B[A'), [
          key(GgParallelLogKeyType.escape),
          key(GgParallelLogKeyType.escape),
          key(GgParallelLogKeyType.up),
        ]);
      });

      test('skips an ESC [ that is not finished', () {
        expect(GgParallelLogKey.parse('a\x1B['), [char('a')]);
      });
    });
  });
}
