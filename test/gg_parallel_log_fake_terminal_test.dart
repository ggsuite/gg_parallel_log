// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:test/test.dart';

void main() {
  late GgParallelLogFakeTerminal terminal;

  setUp(() => terminal = GgParallelLogFakeTerminal.example());

  group('GgParallelLogFakeTerminal', () {
    test('example() is an interactive 80 x 24 terminal', () {
      expect(
        [terminal.width, terminal.height, terminal.isInteractive],
        [80, 24, true],
      );
      final custom = GgParallelLogFakeTerminal.example(
        width: 10,
        height: 5,
        isInteractive: false,
      );
      expect(
        [custom.width, custom.height, custom.isInteractive],
        [10, 5, false],
      );
    });

    test('write() records and clear() forgets the output', () {
      terminal.write('a');
      terminal.write('b');
      expect(terminal.output, 'ab');
      terminal.clear();
      expect(terminal.output, '');
    });

    test('enableRawMode() and disableRawMode() switch the raw mode', () {
      terminal.enableRawMode();
      expect(terminal.isRawMode, isTrue);
      terminal.disableRawMode();
      expect(terminal.isRawMode, isFalse);
    });

    test('type() and interrupt() feed the streams', () {
      final keys = <String>[];
      var interrupts = 0;
      terminal.input.listen(keys.add);
      terminal.interrupts.listen((_) => interrupts++);
      terminal.type('q');
      terminal.interrupt();
      expect(keys, ['q']);
      expect(interrupts, 1);
    });

    test('resize() changes the given dimensions only', () {
      terminal.resize(width: 40);
      expect([terminal.width, terminal.height], [40, 24]);
      terminal.resize(height: 10);
      expect([terminal.width, terminal.height], [40, 10]);
    });
  });
}
