// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:test/test.dart';

void main() {
  const timeout = Duration(seconds: 20);

  late _RecordingConsole console;

  setUp(() {
    ggColorsEnabled = false;
    console = _RecordingConsole();
  });

  tearDown(() => ggColorsEnabled = null);

  // ...........................................................................
  /// Waits until [isDone] returns true.
  Future<void> waitFor(bool Function() isDone) async {
    while (!isDone()) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  group('GgParallelLogStdioTerminal', () {
    group('example(environment, isWindows, console)', () {
      test('is a terminal that polls every 15 ms', () {
        final terminal = GgParallelLogStdioTerminal.example();
        expect(terminal, isA<GgParallelLogTerminal>());
        expect(terminal.pollInterval, const Duration(milliseconds: 15));
      });

      test('is a POSIX terminal with TERM xterm-256color', () {
        final terminal = GgParallelLogStdioTerminal.example();
        expect(
          terminal.interactiveWith(
            stdinIsTerminal: true,
            stdoutIsTerminal: true,
            supportsAnsi: false,
          ),
          isTrue,
        );
      });
    });

    group('interactiveWith(stdinIsTerminal, stdoutIsTerminal, '
        'supportsAnsi)', () {
      // .......................................................................
      /// Asks a terminal with these properties whether it is interactive.
      bool interactive({
        bool isWindows = false,
        Map<String, String> environment = const {'TERM': 'xterm'},
        bool stdinIsTerminal = true,
        bool stdoutIsTerminal = true,
        bool supportsAnsi = true,
      }) =>
          GgParallelLogStdioTerminal.example(
            environment: environment,
            isWindows: isWindows,
          ).interactiveWith(
            stdinIsTerminal: stdinIsTerminal,
            stdoutIsTerminal: stdoutIsTerminal,
            supportsAnsi: supportsAnsi,
          );

      final cases = <String, (bool, bool Function())>{
        'POSIX with TERM': (true, interactive),
        'POSIX with TERM, despite no ANSI check': (
          true,
          () => interactive(supportsAnsi: false),
        ),
        'POSIX with TERM dumb': (
          false,
          () => interactive(environment: {'TERM': 'dumb'}),
        ),
        'POSIX with an empty TERM': (
          false,
          () => interactive(environment: {'TERM': ''}),
        ),
        'POSIX without TERM': (false, () => interactive(environment: {})),
        'Windows with ANSI, without TERM': (
          true,
          () => interactive(isWindows: true, environment: {}),
        ),
        'Windows without ANSI': (
          false,
          () => interactive(isWindows: true, supportsAnsi: false),
        ),
        'no stdin TTY': (false, () => interactive(stdinIsTerminal: false)),
        'no stdout TTY': (false, () => interactive(stdoutIsTerminal: false)),
        'Windows without a stdout TTY': (
          false,
          () => interactive(isWindows: true, stdoutIsTerminal: false),
        ),
      };

      for (final MapEntry(key: name, value: (expected, isInteractive))
          in cases.entries) {
        test('is $expected on $name', () {
          expect(isInteractive(), expected);
        });
      }
    });

    group('isInteractive', () {
      test('checks the TTYs and the ANSI support of the process', () {
        final terminal = GgParallelLogStdioTerminal();
        expect(
          terminal.isInteractive,
          terminal.interactiveWith(
            stdinIsTerminal: stdin.hasTerminal,
            stdoutIsTerminal: stdout.hasTerminal,
            supportsAnsi: stdout.supportsAnsiEscapes,
          ),
        );
      });
    });

    group('width, height', () {
      test('are the size of the TTY, or 80 x 24 without one', () {
        final terminal = GgParallelLogStdioTerminal.example();
        expect(
          [terminal.width, terminal.height],
          stdout.hasTerminal
              ? [stdout.terminalColumns, stdout.terminalLines]
              : [80, 24],
        );
      });
    });

    group('write(text)', () {
      test('writes to stdout', () {
        expect(
          () => GgParallelLogStdioTerminal.example().write(''),
          returnsNormally,
        );
      });
    });

    group('enableRawMode(), disableRawMode()', () {
      test('switch the mode of the console', () {
        final terminal = GgParallelLogStdioTerminal.example(console: console);
        expect(terminal.enableRawMode(), isTrue);
        terminal.disableRawMode();
        expect(console.calls, ['enableRawMode', 'disableRawMode']);
      });

      test('enableRawMode() reports a console without raw mode', () {
        final terminal = GgParallelLogStdioTerminal.example(
          console: _RecordingConsole(supportsRawMode: false),
        );
        expect(terminal.enableRawMode(), isFalse);
      });
    });

    group('input', () {
      test('polls the console only while listened to', () {
        fakeAsync((fake) {
          final terminal = GgParallelLogStdioTerminal(
            console: console,
            pollInterval: const Duration(milliseconds: 10),
          );
          final input = terminal.input;
          fake.elapse(const Duration(milliseconds: 50));
          expect(console.calls, isEmpty);

          final subscription = input.listen((_) {});
          addTearDown(subscription.cancel);
          fake.elapse(const Duration(milliseconds: 35));
          expect(console.calls, ['read', 'read', 'read']);

          unawaited(subscription.cancel());
          fake.elapse(const Duration(milliseconds: 50));
          expect(console.calls, ['read', 'read', 'read']);
        });
      });

      test('emits the keys typed since the last poll', () {
        fakeAsync((fake) {
          final console = _RecordingConsole(keys: ['', 'a', '', '\x1B[A']);
          final terminal = GgParallelLogStdioTerminal(
            console: console,
            pollInterval: const Duration(milliseconds: 10),
          );
          final keys = <String>[];
          final subscription = terminal.input.listen(keys.add);
          addTearDown(subscription.cancel);
          fake.elapse(const Duration(milliseconds: 60));
          unawaited(subscription.cancel());
          expect(keys, ['a', '\x1B[A']);
        });
      });

      test('is refused in the whole process while one listens', () {
        final first = GgParallelLogStdioTerminal.example(console: console);
        final second = GgParallelLogStdioTerminal.example(
          console: _RecordingConsole(),
        );
        final subscription = first.input.listen((_) {});
        addTearDown(subscription.cancel);
        for (final terminal in [second, first]) {
          expect(
            () => terminal.input,
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                'The console input is in use.',
              ),
            ),
          );
        }
      });

      test('is free again once the listener cancels', () async {
        final other = _RecordingConsole();
        final first = GgParallelLogStdioTerminal.example(console: console);
        final second = GgParallelLogStdioTerminal.example(console: other);
        await first.input.listen((_) {}).cancel();
        final subscription = second.input.listen((_) {});
        addTearDown(subscription.cancel);
        await waitFor(() => other.calls.contains('read')).timeout(timeout);
      });

      test('is only locked by listening, not by getting the stream', () async {
        final other = _RecordingConsole();
        final first = GgParallelLogStdioTerminal.example(console: console);
        final second = GgParallelLogStdioTerminal.example(console: other);
        expect(first.input, isA<Stream<String>>());
        final subscription = second.input.listen((_) {});
        addTearDown(subscription.cancel);
        await waitFor(() => other.calls.contains('read')).timeout(timeout);
      });
    });

    group('interrupts', () {
      test('watches SIGINT until cancelled', () async {
        final terminal = GgParallelLogStdioTerminal.example();
        final subscription = terminal.interrupts.listen((_) {});
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await subscription.cancel();
      });
    });

    group('terminations', () {
      test('watches SIGHUP only on Windows', () async {
        final terminal = GgParallelLogStdioTerminal.example(isWindows: true);
        final subscription = terminal.terminations.listen((_) {});
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await subscription.cancel();
      });

      test('watches SIGHUP and SIGTERM off Windows', () async {
        final terminal = GgParallelLogStdioTerminal.example(isWindows: false);
        final subscription = terminal.terminations.listen((_) {});
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await subscription.cancel();
      }, skip: Platform.isWindows ? 'Windows has no SIGTERM to watch' : null);

      test('needs isWindows, as Windows cannot watch SIGTERM', () async {
        final terminal = GgParallelLogStdioTerminal.example(isWindows: false);
        final errors = <Object>[];
        late StreamSubscription<int> subscription;
        runZonedGuarded(
          () => subscription = terminal.terminations.listen((_) {}),
          (error, _) => errors.add(error),
        );
        await waitFor(() => errors.isNotEmpty).timeout(timeout);
        await subscription.cancel();
        expect(errors, [
          isA<SignalException>().having(
            (e) => e.message,
            'message',
            contains('SIGTERM'),
          ),
        ]);
      }, skip: Platform.isWindows ? null : 'Only Windows lacks SIGTERM');
    });
  });
}

// #############################################################################
/// A console that records its calls and hands out prepared [keys].
class _RecordingConsole implements GgParallelLogConsole {
  /// Creates a console that returns one of [keys] per [read].
  ///
  /// Its raw mode works when [supportsRawMode] is set.
  _RecordingConsole({List<String> keys = const [], this.supportsRawMode = true})
    : _keys = [...keys];

  // ...........................................................................
  @override
  bool enableRawMode() {
    calls.add('enableRawMode');
    return supportsRawMode;
  }

  // ...........................................................................
  @override
  void disableRawMode() => calls.add('disableRawMode');

  // ...........................................................................
  @override
  String read() {
    calls.add('read');
    return _keys.isEmpty ? '' : _keys.removeAt(0);
  }

  // ...........................................................................
  /// The names of the methods called so far.
  final List<String> calls = [];

  /// Whether [enableRawMode] succeeds.
  final bool supportsRawMode;

  final List<String> _keys;
}
