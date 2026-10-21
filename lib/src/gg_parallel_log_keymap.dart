// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'gg_parallel_log_key.dart';
import 'gg_parallel_log_view_state.dart';

// #############################################################################
/// The things a user can do with a key.
enum GgParallelLogAction {
  /// Selects the previous lane or scrolls up by a line.
  up,

  /// Selects the next lane or scrolls down by a line.
  down,

  /// Scrolls up by a page.
  pageUp,

  /// Scrolls down by a page.
  pageDown,

  /// Selects the first lane or scrolls to the first line.
  first,

  /// Selects the last lane or follows the output.
  last,

  /// Opens the selected lane in fullscreen.
  open,

  /// Goes back to the overview.
  back,

  /// Shows the previous lane in fullscreen.
  previousLane,

  /// Shows the next lane in fullscreen.
  nextLane,

  /// Lists the failed lanes only, or all lanes again.
  toggleErrors,

  /// Cancels the selected lane after a second press.
  cancel,

  /// Cancels all running lanes after a second press.
  cancelAll,

  /// Saves the output of the selected lane into a file.
  save,

  /// Starts typing a search query.
  search,

  /// Jumps to the next search match.
  nextMatch,

  /// Jumps to the previous search match.
  previousMatch,
}

// #############################################################################
/// Binds keys to an action in some views, with a hint for the footer.
class GgParallelLogBinding {
  /// Creates a binding of [keys] to [action] in [modes].
  const GgParallelLogBinding({
    required this.action,
    required this.keys,
    required this.modes,
    this.hint = '',
  });

  /// Creates an example binding for tests and docs.
  factory GgParallelLogBinding.example({String? hint}) => GgParallelLogBinding(
    action: GgParallelLogAction.save,
    keys: const [GgParallelLogKey.printable('s')],
    modes: const {GgParallelLogMode.overview},
    hint: hint ?? 's save',
  );

  // ...........................................................................
  /// The action the keys trigger.
  final GgParallelLogAction action;

  /// The keys that trigger the action.
  final List<GgParallelLogKey> keys;

  /// The views the binding is active in.
  final Set<GgParallelLogMode> modes;

  /// The hint shown in the footer, or an empty string for none.
  final String hint;
}

// #############################################################################
/// Maps keys to actions and lists the hints of each view.
class GgParallelLogKeymap {
  /// Creates a keymap of [bindings].
  const GgParallelLogKeymap({this.bindings = standard});

  /// Creates an example keymap for tests and docs.
  factory GgParallelLogKeymap.example({List<GgParallelLogBinding>? bindings}) =>
      GgParallelLogKeymap(bindings: bindings ?? standard);

  // ...........................................................................
  /// Returns the action [key] triggers in [mode], or null.
  GgParallelLogAction? action(GgParallelLogMode mode, GgParallelLogKey key) {
    for (final binding in bindings) {
      if (binding.modes.contains(mode) && binding.keys.contains(key)) {
        return binding.action;
      }
    }
    return null;
  }

  // ...........................................................................
  /// Returns the hints of [mode] for the footer, e.g. `⏎ open · s save`.
  String hints(GgParallelLogMode mode, {bool errorsOnly = false}) => [
    for (final binding in bindings)
      if (binding.modes.contains(mode) && binding.hint.isNotEmpty)
        binding.action == GgParallelLogAction.toggleErrors && errorsOnly
            ? 'f all lanes'
            : binding.hint,
  ].join(' · ');

  // ...........................................................................
  /// The bindings, the first match wins.
  final List<GgParallelLogBinding> bindings;

  // ...........................................................................
  /// The keys of the log.
  static const List<GgParallelLogBinding> standard = [
    GgParallelLogBinding(
      action: GgParallelLogAction.up,
      keys: [_up, GgParallelLogKey.printable('k')],
      modes: {_overview},
      hint: '↑↓ select',
    ),
    GgParallelLogBinding(
      action: GgParallelLogAction.up,
      keys: [_up, GgParallelLogKey.printable('k')],
      modes: {_detail},
      hint: '↑↓ scroll',
    ),
    GgParallelLogBinding(
      action: GgParallelLogAction.down,
      keys: [_down, GgParallelLogKey.printable('j')],
      modes: {_overview, _detail},
    ),
    GgParallelLogBinding(
      action: GgParallelLogAction.pageUp,
      keys: [
        GgParallelLogKey(GgParallelLogKeyType.pageUp),
        GgParallelLogKey.printable('b'),
      ],
      modes: {_detail},
      hint: 'b Space page',
    ),
    GgParallelLogBinding(
      action: GgParallelLogAction.pageDown,
      keys: [
        GgParallelLogKey(GgParallelLogKeyType.pageDown),
        GgParallelLogKey.printable(' '),
      ],
      modes: {_detail},
    ),
    GgParallelLogBinding(
      action: GgParallelLogAction.first,
      keys: [_home, GgParallelLogKey.printable('g')],
      modes: {_overview, _detail},
    ),
    GgParallelLogBinding(
      action: GgParallelLogAction.last,
      keys: [_end, GgParallelLogKey.printable('G')],
      modes: {_overview, _detail},
    ),
    GgParallelLogBinding(
      action: GgParallelLogAction.open,
      keys: [_enter, _right, GgParallelLogKey.printable('l')],
      modes: {_overview},
      hint: '⏎ open',
    ),
    GgParallelLogBinding(
      action: GgParallelLogAction.previousLane,
      keys: [_left, GgParallelLogKey.printable('h')],
      modes: {_detail},
      hint: '←→ lane',
    ),
    GgParallelLogBinding(
      action: GgParallelLogAction.nextLane,
      keys: [_right, GgParallelLogKey.printable('l')],
      modes: {_detail},
    ),
    GgParallelLogBinding(
      action: GgParallelLogAction.search,
      keys: [GgParallelLogKey.printable('/')],
      modes: {_detail},
      hint: '/ search',
    ),
    GgParallelLogBinding(
      action: GgParallelLogAction.nextMatch,
      keys: [GgParallelLogKey.printable('n')],
      modes: {_detail},
      hint: 'n N match',
    ),
    GgParallelLogBinding(
      action: GgParallelLogAction.previousMatch,
      keys: [GgParallelLogKey.printable('N')],
      modes: {_detail},
    ),
    GgParallelLogBinding(
      action: GgParallelLogAction.toggleErrors,
      keys: [GgParallelLogKey.printable('f')],
      modes: {_overview},
      hint: 'f errors only',
    ),
    GgParallelLogBinding(
      action: GgParallelLogAction.save,
      keys: [GgParallelLogKey.printable('s')],
      modes: {_overview, _detail},
      hint: 's save',
    ),
    GgParallelLogBinding(
      action: GgParallelLogAction.cancel,
      keys: [GgParallelLogKey.printable('x')],
      modes: {_overview, _detail},
      hint: 'x cancel',
    ),
    GgParallelLogBinding(
      action: GgParallelLogAction.cancelAll,
      keys: [GgParallelLogKey.printable('q')],
      modes: {_overview},
      hint: 'q cancel all',
    ),
    GgParallelLogBinding(
      action: GgParallelLogAction.back,
      keys: [_escape, GgParallelLogKey.printable('q')],
      modes: {_detail},
      hint: 'Esc back',
    ),
  ];

  // ######################
  // Private
  // ######################

  static const _overview = GgParallelLogMode.overview;
  static const _detail = GgParallelLogMode.detail;
  static const _up = GgParallelLogKey(GgParallelLogKeyType.up);
  static const _down = GgParallelLogKey(GgParallelLogKeyType.down);
  static const _left = GgParallelLogKey(GgParallelLogKeyType.left);
  static const _right = GgParallelLogKey(GgParallelLogKeyType.right);
  static const _home = GgParallelLogKey(GgParallelLogKeyType.home);
  static const _end = GgParallelLogKey(GgParallelLogKeyType.end);
  static const _enter = GgParallelLogKey(GgParallelLogKeyType.enter);
  static const _escape = GgParallelLogKey(GgParallelLogKeyType.escape);
}
