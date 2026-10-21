// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_parallel_log/src/gg_parallel_log_key.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_keymap.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_view_state.dart';
import 'package:test/test.dart';

void main() {
  GgParallelLogKey key(GgParallelLogKeyType type) => GgParallelLogKey(type);
  GgParallelLogKey char(String c) => GgParallelLogKey.printable(c);

  final up = key(GgParallelLogKeyType.up);
  final down = key(GgParallelLogKeyType.down);
  final left = key(GgParallelLogKeyType.left);
  final right = key(GgParallelLogKeyType.right);
  final home = key(GgParallelLogKeyType.home);
  final end = key(GgParallelLogKeyType.end);
  final pageUp = key(GgParallelLogKeyType.pageUp);
  final pageDown = key(GgParallelLogKeyType.pageDown);
  final enter = key(GgParallelLogKeyType.enter);
  final escape = key(GgParallelLogKeyType.escape);
  final backspace = key(GgParallelLogKeyType.backspace);
  final ctrlC = key(GgParallelLogKeyType.ctrlC);

  final allKeys = [
    up,
    down,
    left,
    right,
    home,
    end,
    pageUp,
    pageDown,
    enter,
    escape,
    backspace,
    ctrlC,
    for (final c in 'kjgGlhbnN/fsxqz '.split('')) char(c),
  ];

  // Returns the action of every key that triggers one in [mode].
  Map<GgParallelLogKey, GgParallelLogAction> actions(
    GgParallelLogKeymap keymap,
    GgParallelLogMode mode,
  ) => {for (final k in allKeys) k: ?keymap.action(mode, k)};

  group('GgParallelLogBinding', () {
    group('GgParallelLogBinding(action, keys, modes, hint)', () {
      test('has no hint by default', () {
        final binding = GgParallelLogBinding(
          action: GgParallelLogAction.save,
          keys: [char('s')],
          modes: const {GgParallelLogMode.detail},
        );
        expect(binding.hint, '');
      });
    });

    group('example()', () {
      test('saves with s in the overview', () {
        final binding = GgParallelLogBinding.example();
        expect(
          [binding.action, binding.keys, binding.modes, binding.hint],
          [
            GgParallelLogAction.save,
            [char('s')],
            {GgParallelLogMode.overview},
            's save',
          ],
        );
      });

      test('takes the hint a test cares about', () {
        expect(GgParallelLogBinding.example(hint: '').hint, '');
      });
    });
  });

  group('GgParallelLogKeymap', () {
    group('GgParallelLogKeymap(bindings)', () {
      test('uses the standard bindings by default', () {
        expect(
          const GgParallelLogKeymap().bindings,
          same(GgParallelLogKeymap.standard),
        );
      });
    });

    group('example()', () {
      test('uses the standard bindings by default', () {
        expect(
          GgParallelLogKeymap.example().bindings,
          same(GgParallelLogKeymap.standard),
        );
      });

      test('takes the bindings a test cares about', () {
        final bindings = [GgParallelLogBinding.example()];
        expect(
          GgParallelLogKeymap.example(bindings: bindings).bindings,
          same(bindings),
        );
      });
    });

    group('action(mode, key)', () {
      final keymap = GgParallelLogKeymap.example();

      test('maps the keys of the overview', () {
        expect(actions(keymap, GgParallelLogMode.overview), {
          up: GgParallelLogAction.up,
          char('k'): GgParallelLogAction.up,
          down: GgParallelLogAction.down,
          char('j'): GgParallelLogAction.down,
          home: GgParallelLogAction.first,
          char('g'): GgParallelLogAction.first,
          end: GgParallelLogAction.last,
          char('G'): GgParallelLogAction.last,
          enter: GgParallelLogAction.open,
          right: GgParallelLogAction.open,
          char('l'): GgParallelLogAction.open,
          char('f'): GgParallelLogAction.toggleErrors,
          char('s'): GgParallelLogAction.save,
          char('x'): GgParallelLogAction.cancel,
          char('q'): GgParallelLogAction.cancelAll,
        });
      });

      test('maps the keys of the detail view', () {
        expect(actions(keymap, GgParallelLogMode.detail), {
          up: GgParallelLogAction.up,
          char('k'): GgParallelLogAction.up,
          down: GgParallelLogAction.down,
          char('j'): GgParallelLogAction.down,
          pageUp: GgParallelLogAction.pageUp,
          char('b'): GgParallelLogAction.pageUp,
          pageDown: GgParallelLogAction.pageDown,
          char(' '): GgParallelLogAction.pageDown,
          home: GgParallelLogAction.first,
          char('g'): GgParallelLogAction.first,
          end: GgParallelLogAction.last,
          char('G'): GgParallelLogAction.last,
          left: GgParallelLogAction.previousLane,
          char('h'): GgParallelLogAction.previousLane,
          right: GgParallelLogAction.nextLane,
          char('l'): GgParallelLogAction.nextLane,
          char('/'): GgParallelLogAction.search,
          char('n'): GgParallelLogAction.nextMatch,
          char('N'): GgParallelLogAction.previousMatch,
          char('s'): GgParallelLogAction.save,
          char('x'): GgParallelLogAction.cancel,
          escape: GgParallelLogAction.back,
          char('q'): GgParallelLogAction.back,
        });
      });

      test('maps no key while a search query is typed', () {
        expect(actions(keymap, GgParallelLogMode.search), isEmpty);
      });

      test('returns null for an unbound key', () {
        expect(keymap.action(GgParallelLogMode.overview, char('z')), isNull);
      });

      test('takes the first binding that matches', () {
        final custom = GgParallelLogKeymap.example(
          bindings: [
            GgParallelLogBinding(
              action: GgParallelLogAction.search,
              keys: [char('s')],
              modes: const {GgParallelLogMode.detail},
            ),
            GgParallelLogBinding.example(),
            GgParallelLogBinding(
              action: GgParallelLogAction.cancel,
              keys: [char('s')],
              modes: const {GgParallelLogMode.overview},
            ),
          ],
        );
        expect(
          [
            custom.action(GgParallelLogMode.overview, char('s')),
            custom.action(GgParallelLogMode.detail, char('s')),
          ],
          [GgParallelLogAction.save, GgParallelLogAction.search],
        );
      });
    });

    group('hints(mode, errorsOnly)', () {
      final keymap = GgParallelLogKeymap.example();

      test('lists the hints of the overview', () {
        expect(
          keymap.hints(GgParallelLogMode.overview),
          '↑↓ select · ⏎ open · f errors only · s save · x cancel · '
          'q cancel all',
        );
      });

      test('offers all lanes again while only errors are listed', () {
        expect(
          keymap.hints(GgParallelLogMode.overview, errorsOnly: true),
          '↑↓ select · ⏎ open · f all lanes · s save · x cancel · '
          'q cancel all',
        );
      });

      test('lists the hints of the detail view', () {
        expect(
          keymap.hints(GgParallelLogMode.detail),
          '↑↓ scroll · b Space page · ←→ lane · / search · n N match · '
          's save · x cancel · Esc back',
        );
      });

      test('ignores errorsOnly in the detail view', () {
        expect(
          keymap.hints(GgParallelLogMode.detail, errorsOnly: true),
          keymap.hints(GgParallelLogMode.detail),
        );
      });

      test('lists no hints while a search query is typed', () {
        expect(keymap.hints(GgParallelLogMode.search), '');
      });

      test('skips bindings without a hint', () {
        final custom = GgParallelLogKeymap.example(
          bindings: [
            GgParallelLogBinding.example(hint: ''),
            GgParallelLogBinding.example(hint: 'a'),
            GgParallelLogBinding.example(hint: 'b'),
          ],
        );
        expect(custom.hints(GgParallelLogMode.overview), 'a · b');
      });
    });
  });
}
