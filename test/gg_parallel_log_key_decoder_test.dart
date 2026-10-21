// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_parallel_log/src/gg_parallel_log_key.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_key_decoder.dart';
import 'package:test/test.dart';

void main() {
  late GgParallelLogKeyDecoder decoder;

  const up = GgParallelLogKey(GgParallelLogKeyType.up);
  const down = GgParallelLogKey(GgParallelLogKeyType.down);
  const escape = GgParallelLogKey(GgParallelLogKeyType.escape);
  GgParallelLogKey char(String c) => GgParallelLogKey.printable(c);

  // Returns the keys of every chunk, one list per chunk.
  List<List<GgParallelLogKey>> feed(List<String> chunks) => [
    for (final chunk in chunks) decoder.add(chunk),
  ];

  setUp(() => decoder = GgParallelLogKeyDecoder.example());

  group('GgParallelLogKeyDecoder', () {
    group('example()', () {
      test('has no pending input', () {
        expect(decoder.hasPending, isFalse);
      });
    });

    group('add(chunk)', () {
      test('returns the keys of a complete chunk', () {
        expect(decoder.add('\x1B[Ajx'), [up, char('j'), char('x')]);
        expect(decoder.hasPending, isFalse);
      });

      test('returns no keys for an empty chunk', () {
        expect(decoder.add(''), isEmpty);
      });

      test('joins a CSI sequence split after ESC', () {
        expect(feed(['\x1B', '[A']), [
          <GgParallelLogKey>[],
          [up],
        ]);
      });

      test('joins a CSI sequence split after ESC [', () {
        expect(feed(['\x1B[', 'B']), [
          <GgParallelLogKey>[],
          [down],
        ]);
      });

      test('joins a CSI sequence split inside its parameters', () {
        expect(feed(['\x1B[5', '~', '\x1B[6', '~']), [
          <GgParallelLogKey>[],
          [const GgParallelLogKey(GgParallelLogKeyType.pageUp)],
          <GgParallelLogKey>[],
          [const GgParallelLogKey(GgParallelLogKeyType.pageDown)],
        ]);
      });

      test('joins an SS3 sequence split after ESC O', () {
        expect(feed(['\x1BO', 'A']), [
          <GgParallelLogKey>[],
          [up],
        ]);
      });

      test('joins a sequence split over three chunks', () {
        expect(feed(['\x1B', '[1;', '5A', 'k']), [
          <GgParallelLogKey>[],
          <GgParallelLogKey>[],
          <GgParallelLogKey>[],
          [char('k')],
        ]);
      });

      test('returns the keys before an unfinished sequence', () {
        expect(decoder.add('ab\x1B['), [char('a'), char('b')]);
        expect(decoder.hasPending, isTrue);
      });

      test('returns the keys after a joined sequence', () {
        expect(feed(['\x1B[', 'Bj😀']), [
          <GgParallelLogKey>[],
          [down, char('j'), char('😀')],
        ]);
      });

      test('reads ESC before an unfinished ESC as Escape', () {
        expect(decoder.add('\x1B\x1B'), [escape]);
        expect(decoder.hasPending, isTrue);
      });

      test('reads a pending ESC and a new sequence as two keys', () {
        expect(feed(['\x1B', '\x1B[A']), [
          <GgParallelLogKey>[],
          [escape, up],
        ]);
      });

      test('skips an Alt combination split after ESC', () {
        expect(feed(['\x1B', 'x', 'y']), [
          <GgParallelLogKey>[],
          <GgParallelLogKey>[],
          [char('y')],
        ]);
      });

      test('skips an Alt combination within one chunk', () {
        expect(decoder.add('\x1Bxy'), [char('y')]);
      });
    });

    group('flush()', () {
      test('reads a pending ESC as Escape', () {
        decoder.add('\x1B');
        expect(decoder.flush(), [escape]);
      });

      test('skips a pending ESC [ that never finished', () {
        decoder.add('\x1B[');
        expect(decoder.flush(), isEmpty);
      });

      test('returns no keys without pending input', () {
        decoder.add('a');
        expect(decoder.flush(), isEmpty);
      });

      test('clears the pending input', () {
        decoder.add('\x1B');
        decoder.flush();
        expect(
          [decoder.hasPending, decoder.add('[A')],
          [
            false,
            [char('['), char('A')],
          ],
        );
      });
    });

    group('hasPending', () {
      final cases = {
        'nothing': ('', false),
        'a complete key': ('a', false),
        'a complete sequence': ('\x1B[A', false),
        'ESC': ('\x1B', true),
        'ESC [': ('\x1B[', true),
        'ESC [ with parameters': ('\x1B[1;5', true),
        'ESC O': ('\x1BO', true),
        'an Alt combination': ('\x1Bx', false),
      };
      for (final MapEntry(key: name, value: (chunk, pending))
          in cases.entries) {
        test('is $pending after $name', () {
          decoder.add(chunk);
          expect(decoder.hasPending, pending);
        });
      }
    });
  });
}
