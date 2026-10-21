// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:test/test.dart';

void main() {
  late GgParallelLogFakeTerminal terminal;

  setUp(() {
    ggColorsEnabled = false;
    terminal = GgParallelLogFakeTerminal.example();
  });

  tearDown(() => ggColorsEnabled = null);

  // ...........................................................................
  /// Writes [text] and returns the screen afterwards.
  List<String> show(String text) {
    terminal.write(text);
    return terminal.screen;
  }

  group('GgParallelLogFakeTerminal', () {
    group('GgParallelLogFakeTerminal(width, height, ...)', () {
      test('is an interactive 80 x 24 terminal with free input', () {
        final terminal = GgParallelLogFakeTerminal();
        expect(
          [
            terminal.width,
            terminal.height,
            terminal.isInteractive,
            terminal.inputTaken,
            terminal.supportsRawMode,
            terminal.isRawMode,
            terminal.output,
            terminal.screen,
          ],
          [80, 24, true, false, true, false, '', isEmpty],
        );
      });
    });

    group('example(width, height, isInteractive, inputTaken, '
        'supportsRawMode)', () {
      test('is an interactive 80 x 24 terminal by default', () {
        expect(
          [
            terminal.width,
            terminal.height,
            terminal.isInteractive,
            terminal.inputTaken,
            terminal.supportsRawMode,
          ],
          [80, 24, true, false, true],
        );
      });

      test('takes the given values', () {
        final custom = GgParallelLogFakeTerminal.example(
          width: 10,
          height: 5,
          isInteractive: false,
          inputTaken: true,
          supportsRawMode: false,
        );
        expect(
          [
            custom.width,
            custom.height,
            custom.isInteractive,
            custom.inputTaken,
            custom.supportsRawMode,
          ],
          [10, 5, false, true, false],
        );
      });
    });

    group('write(text), output, clear()', () {
      test('write() records the text as it is', () {
        terminal.write('a');
        terminal.write('\x1B[31mb\x1B[0m');
        expect(terminal.output, 'a\x1B[31mb\x1B[0m');
      });

      test('clear() forgets the output but keeps the screen', () {
        terminal.write('a\nb');
        terminal.clear();
        expect(terminal.output, '');
        expect(terminal.screen, ['a', 'b']);
      });
    });

    group('screen', () {
      test('is empty before anything is written', () {
        expect(terminal.screen, isEmpty);
      });

      test('continues the row across writes', () {
        terminal.write('a');
        expect(show('b'), ['ab']);
      });

      test('starts a new row on \\n and \\r\\n', () {
        expect(show('a\nb\r\nc'), ['a', 'b', 'c']);
      });

      test('keeps empty rows in between but not at the end', () {
        expect(show('a\n\nb\n\n'), ['a', '', 'b']);
      });

      test('lets text after \\r replace the row', () {
        expect(show('abc\rX'), ['X']);
      });

      test('moves up n rows with ESC[nA and replaces that row', () {
        expect(show('1\n2\n3\n\x1B[2AX'), ['1', 'X', '3']);
      });

      test('moves up one row with ESC[A', () {
        expect(show('1\n2\x1B[AX'), ['X', '2']);
      });

      test('stops moving up at the top row', () {
        expect(show('1\n2\x1B[5AX'), ['X', '2']);
      });

      test('erases the rows below the cursor with ESC[J', () {
        expect(show('1\n2\n3\x1B[1A\x1B[JX'), ['1', 'X']);
      });

      test('erases everything with ESC[2J and starts at the top', () {
        expect(show('1\n2\x1B[2JX'), ['X']);
      });

      test('moves to the top row with ESC[H', () {
        expect(show('1\n2\x1B[HX'), ['X', '2']);
      });

      test('ignores colors, also with ;, and other sequences', () {
        expect(show('\x1B[1;31mred\x1B[0m \x1B[2Kok\x1Bx\x1B[?25l'), [
          'red okx',
        ]);
      });

      test('shows the own buffer of the fullscreen with ?1049h', () {
        terminal.write('inline\n');
        expect(show('\x1B[?1049hfull\n2\x1B[AX'), ['X', '2']);
      });

      test('restores the inline screen and cursor with ?1049l', () {
        terminal.write('inline\n\x1B[?1049hfull');
        expect(show('\x1B[?1049lmore'), ['inline', 'more']);
      });

      test('starts every fullscreen with an empty buffer', () {
        terminal.write('\x1B[?1049hold\x1B[?1049l');
        expect(show('\x1B[?1049h'), isEmpty);
      });

      test('erases only the fullscreen buffer in fullscreen', () {
        terminal.write('inline\n\x1B[?1049hfull\x1B[2J');
        expect(terminal.screen, isEmpty);
        expect(show('\x1B[?1049l'), ['inline']);
      });
    });

    group('enableRawMode(), disableRawMode()', () {
      test('switch the raw mode', () {
        expect(terminal.enableRawMode(), isTrue);
        expect(terminal.isRawMode, isTrue);
        terminal.disableRawMode();
        expect(terminal.isRawMode, isFalse);
      });

      test('enableRawMode() fails without supportsRawMode', () {
        final terminal = GgParallelLogFakeTerminal.example(
          supportsRawMode: false,
        );
        expect(terminal.enableRawMode(), isFalse);
        expect(terminal.isRawMode, isFalse);
      });
    });

    group('type(input)', () {
      test('sends the keys to every listener of input', () {
        final first = <String>[];
        final second = <String>[];
        terminal.input.listen(first.add);
        terminal.input.listen(second.add);
        terminal.type('q');
        terminal.type('\x1B[A');
        expect(
          [first, second],
          [
            ['q', '\x1B[A'],
            ['q', '\x1B[A'],
          ],
        );
      });
    });

    group('input', () {
      test('throws like a used stdin when inputTaken is set', () {
        final terminal = GgParallelLogFakeTerminal.example(inputTaken: true);
        expect(
          () => terminal.input,
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'Stream has already been listened to.',
            ),
          ),
        );
      });
    });

    group('interrupt()', () {
      test('emits on interrupts', () {
        var interrupts = 0;
        terminal.interrupts.listen((_) => interrupts++);
        terminal.interrupt();
        terminal.interrupt();
        expect(interrupts, 2);
      });
    });

    group('terminate(code)', () {
      test('emits the code on terminations, 143 by default', () {
        final codes = <int>[];
        terminal.terminations.listen(codes.add);
        terminal.terminate();
        terminal.terminate(129);
        expect(codes, [143, 129]);
      });
    });

    group('resize(width, height)', () {
      test('changes the given dimensions only', () {
        terminal.resize(width: 40);
        expect([terminal.width, terminal.height], [40, 24]);
        terminal.resize(height: 10);
        expect([terminal.width, terminal.height], [40, 10]);
        terminal.resize();
        expect([terminal.width, terminal.height], [40, 10]);
      });
    });
  });
}
