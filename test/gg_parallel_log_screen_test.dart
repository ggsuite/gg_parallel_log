// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_screen.dart';
import 'package:test/test.dart';

void main() {
  late GgParallelLogFakeTerminal terminal;
  late GgParallelLogScreen screen;
  late List<String> events;

  setUp(() {
    terminal = GgParallelLogFakeTerminal.example();
    screen = GgParallelLogScreen.example(terminal: terminal);
    events = [];
  });

  /// Opens [screen] and records what it reports in [events].
  void open() => screen.open(
    onInput: (input) => events.add('input $input'),
    onInterrupt: () => events.add('interrupt'),
    onTerminate: (code) => events.add('terminate $code'),
    onError: (error) => events.add('error $error'),
  );

  group('GgParallelLogScreen', () {
    group('example()', () {
      test('draws on a closed fake terminal', () {
        final screen = GgParallelLogScreen.example();
        expect(screen.terminal, isA<GgParallelLogFakeTerminal>());
        expect(screen.isOpen, isFalse);
        expect(screen.isFullscreen, isFalse);
      });
    });

    group('open(onInput, onInterrupt, onTerminate, onError)', () {
      test('switches into raw mode and hides the cursor', () {
        open();
        expect(screen.isOpen, isTrue);
        expect(terminal.isRawMode, isTrue);
        expect(terminal.output, '\x1B[?25l');
      });

      test('reports input, interrupts and terminations', () {
        open();
        terminal
          ..type('a')
          ..interrupt()
          ..terminate(143);
        expect(events, ['input a', 'interrupt', 'terminate 143']);
      });

      test('throws with the terminal untouched when input is taken', () {
        terminal = GgParallelLogFakeTerminal.example(inputTaken: true);
        screen = GgParallelLogScreen.example(terminal: terminal);
        expect(
          open,
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'Stream has already been listened to.',
            ),
          ),
        );
        terminal
          ..interrupt()
          ..terminate();
        expect(events, isEmpty);
        expect(screen.isOpen, isFalse);
        expect(terminal.isRawMode, isFalse);
        expect(terminal.output, '');
      });

      test('throws and stops listening when raw mode is missing', () {
        terminal = GgParallelLogFakeTerminal.example(supportsRawMode: false);
        screen = GgParallelLogScreen.example(terminal: terminal);
        expect(
          open,
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'The terminal cannot deliver single keys.',
            ),
          ),
        );
        terminal
          ..type('a')
          ..interrupt()
          ..terminate();
        expect(events, isEmpty);
        expect(screen.isOpen, isFalse);
        expect(terminal.isRawMode, isFalse);
        expect(terminal.output, '');
        screen.showInline(['a']);
        expect(terminal.output, '');
      });
    });

    group('showInline(lines)', () {
      test('does nothing before open', () {
        screen.showInline(['a']);
        expect(terminal.output, '');
        expect(terminal.screen, isEmpty);
      });

      test('draws below the scrollback', () {
        terminal.write('before\n');
        open();
        screen.showInline(['a', 'b']);
        expect(terminal.screen, ['before', 'a', 'b']);
      });

      test('redraws the block in place', () {
        terminal.write('before\n');
        open();
        screen
          ..showInline(['a', 'b', 'c'])
          ..showInline(['x', 'y']);
        expect(terminal.screen, ['before', 'x', 'y']);
        screen.showInline(['1', '2', '3', '4']);
        expect(terminal.screen, ['before', '1', '2', '3', '4']);
      });

      test('redraws a block of one line in place', () {
        terminal.write('before\n');
        open();
        screen
          ..showInline(['a'])
          ..showInline(['b']);
        expect(terminal.screen, ['before', 'b']);
        expect(terminal.output, endsWith('\rb\x1B[K\x1B[J\x1B[?2026l'));
      });

      test('writes nothing when the frame did not change', () {
        open();
        screen.showInline(['a', 'b']);
        terminal.clear();
        screen.showInline(['a', 'b']);
        expect(terminal.output, '');
        expect(terminal.screen, ['a', 'b']);
      });

      test('draws synchronized and erases the rest of each line', () {
        open();
        terminal.clear();
        screen.showInline(['a', 'b']);
        expect(
          terminal.output,
          '\x1B[?2026ha\x1B[K\r\nb\x1B[K\x1B[J\x1B[?2026l',
        );
      });

      test('rebuilds the screen from the top after a width change', () {
        terminal.write('before\n');
        open();
        screen.showInline(['a', 'b']);
        terminal
          ..resize(width: 60)
          ..clear();
        screen.showInline(['a', 'b']);
        expect(terminal.output, startsWith('\x1B[?2026h\x1B[H\x1B[2J'));
        expect(terminal.screen, ['a', 'b']);
      });

      test('leaves the fullscreen and redraws the block', () {
        terminal.write('before\n');
        open();
        screen
          ..showInline(['a', 'b'])
          ..showFullscreen(['detail'])
          ..showInline(['a', 'b']);
        expect(screen.isFullscreen, isFalse);
        expect(terminal.screen, ['before', 'a', 'b']);
      });
    });

    group('showFullscreen(lines)', () {
      test('does nothing before open', () {
        screen.showFullscreen(['a']);
        expect(terminal.output, '');
        expect(screen.isFullscreen, isFalse);
      });

      test('draws on the alternate screen, keeping the scrollback', () {
        terminal.write('before\n');
        open();
        screen
          ..showInline(['a', 'b'])
          ..showFullscreen(['title', 'line']);
        expect(screen.isFullscreen, isTrue);
        expect(terminal.screen, ['title', 'line']);
        screen.showFullscreen(['title']);
        expect(terminal.screen, ['title']);
      });

      test('writes nothing when the frame did not change', () {
        open();
        screen.showFullscreen(['a']);
        terminal.clear();
        screen.showFullscreen(['a']);
        expect(terminal.output, '');
      });

      test('redraws an unchanged frame after a width change', () {
        open();
        screen.showFullscreen(['a']);
        terminal
          ..resize(width: 60)
          ..clear();
        screen.showFullscreen(['a']);
        expect(terminal.output, '\x1B[?2026h\x1B[Ha\x1B[K\x1B[J\x1B[?2026l');
        expect(terminal.screen, ['a']);
      });
    });

    group('close(summary)', () {
      test('does nothing before open', () {
        screen.close('summary\n');
        expect(terminal.output, '');
        expect(screen.isOpen, isFalse);
      });

      test('leaves the summary where the block was', () {
        terminal.write('before\n');
        open();
        screen
          ..showInline(['a', 'b', 'c'])
          ..close('summary\n');
        expect(terminal.screen, ['before', 'summary']);
        expect(terminal.output, endsWith('summary\n\x1B[?25h'));
        expect(terminal.isRawMode, isFalse);
        expect(screen.isOpen, isFalse);
      });

      test('replaces a block of one line', () {
        terminal.write('before\n');
        open();
        screen
          ..showInline(['a'])
          ..close('summary\n');
        expect(terminal.screen, ['before', 'summary']);
      });

      test('writes the summary when nothing was drawn', () {
        open();
        screen.close('summary\n');
        expect(terminal.screen, ['summary']);
      });

      test('leaves the fullscreen first', () {
        terminal.write('before\n');
        open();
        screen
          ..showInline(['a', 'b'])
          ..showFullscreen(['detail'])
          ..close('summary\n');
        expect(screen.isFullscreen, isFalse);
        expect(terminal.screen, ['before', 'summary']);
      });

      test('rebuilds from the top after a width change', () {
        terminal.write('before\n');
        open();
        screen.showInline(['a', 'b']);
        terminal.resize(width: 60);
        screen.close('summary\n');
        expect(terminal.screen, ['summary']);
      });

      test('stops listening to the terminal', () {
        open();
        screen.close('summary\n');
        terminal
          ..type('a')
          ..interrupt()
          ..terminate();
        expect(events, isEmpty);
      });

      test('does nothing when called again', () {
        open();
        screen.close('summary\n');
        terminal.clear();
        screen
          ..close('again\n')
          ..showInline(['a'])
          ..showFullscreen(['b']);
        expect(terminal.output, '');
        expect(terminal.screen, ['summary']);
      });
    });
  });
}
