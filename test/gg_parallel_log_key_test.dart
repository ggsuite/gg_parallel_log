// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_parallel_log/src/gg_parallel_log_key.dart';
import 'package:test/test.dart';

void main() {
  group('GgParallelLogKey', () {
    group('parse(input)', () {
      final sequences = {
        '\x1B[A': GgParallelLogKeyType.up,
        '\x1B[B': GgParallelLogKeyType.down,
        '\x1B[C': GgParallelLogKeyType.right,
        '\x1B[D': GgParallelLogKeyType.left,
        '\x1BOA': GgParallelLogKeyType.up,
        '\x1BOD': GgParallelLogKeyType.left,
        '\x1B[H': GgParallelLogKeyType.home,
        '\x1B[4~': GgParallelLogKeyType.end,
        '\x1B[5~': GgParallelLogKeyType.pageUp,
        '\x1B[6~': GgParallelLogKeyType.pageDown,
        '\r': GgParallelLogKeyType.enter,
        '\x1B': GgParallelLogKeyType.escape,
        '\x7F': GgParallelLogKeyType.backspace,
        '\t': GgParallelLogKeyType.tab,
        '\x03': GgParallelLogKeyType.ctrlC,
      };
      for (final MapEntry(:key, :value) in sequences.entries) {
        test('reads ${value.name}', () {
          expect(GgParallelLogKey.parse(key), [GgParallelLogKey(value)]);
        });
      }

      test('reads several keys and printable characters', () {
        expect(GgParallelLogKey.parse('\x1B[Bx😀\r'), [
          const GgParallelLogKey(GgParallelLogKeyType.down),
          const GgParallelLogKey.printable('x'),
          const GgParallelLogKey.printable('😀'),
          const GgParallelLogKey(GgParallelLogKeyType.enter),
        ]);
      });

      test('skips unknown escape sequences', () {
        expect(GgParallelLogKey.parse('\x1B[99~a'), [
          const GgParallelLogKey.printable('a'),
        ]);
      });
    });

    group('isChar(c)', () {
      test('is true for the printable character only', () {
        expect(const GgParallelLogKey.printable('q').isChar('q'), isTrue);
        expect(const GgParallelLogKey.printable('q').isChar('x'), isFalse);
        expect(
          const GgParallelLogKey(GgParallelLogKeyType.up).isChar(''),
          isFalse,
        );
      });
    });

    group('==, hashCode, toString()', () {
      test('compare type and character', () {
        final a = GgParallelLogKey.example();
        expect(a, const GgParallelLogKey.printable('f'));
        expect(a.hashCode, const GgParallelLogKey.printable('f').hashCode);
        expect(a == GgParallelLogKey.example(char: 'g'), isFalse);
        expect(a.toString(), 'f');
        expect(
          GgParallelLogKey.example(type: GgParallelLogKeyType.up).toString(),
          'up',
        );
      });
    });
  });
}
