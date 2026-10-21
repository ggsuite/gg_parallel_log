// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:fake_async/fake_async.dart';
import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:test/test.dart';

void main() {
  group('GgParallelLogConsole', () {
    test('lets the stdio terminal run on a console of its own', () {
      fakeAsync((fake) {
        final console = _ScriptedConsole(keys: ['q']);
        final terminal = GgParallelLogStdioTerminal.example(console: console);
        final keys = <String>[];
        final rawMode = terminal.enableRawMode();
        final subscription = terminal.input.listen(keys.add);
        addTearDown(subscription.cancel);
        fake.elapse(terminal.pollInterval * 2);
        terminal.disableRawMode();
        expect(rawMode, isTrue);
        expect(keys, ['q']);
        expect(console.modes, [true, false]);
      });
    });

    test('tells the terminal when it has no raw mode', () {
      final terminal = GgParallelLogStdioTerminal.example(
        console: _ScriptedConsole(supportsRawMode: false),
      );
      expect(terminal.enableRawMode(), isFalse);
    });
  });
}

// #############################################################################
/// A console that delivers prepared [keys] and records its modes.
class _ScriptedConsole implements GgParallelLogConsole {
  /// Creates a console that returns one of [keys] per [read].
  ///
  /// Its raw mode works when [supportsRawMode] is set.
  _ScriptedConsole({List<String> keys = const [], this.supportsRawMode = true})
    : _keys = [...keys];

  // ...........................................................................
  @override
  bool enableRawMode() {
    modes.add(true);
    return supportsRawMode;
  }

  // ...........................................................................
  @override
  void disableRawMode() => modes.add(false);

  // ...........................................................................
  @override
  String read() => _keys.isEmpty ? '' : _keys.removeAt(0);

  // ...........................................................................
  /// Whether each mode switch enabled or disabled the raw mode.
  final List<bool> modes = [];

  /// Whether [enableRawMode] succeeds.
  final bool supportsRawMode;

  final List<String> _keys;
}
