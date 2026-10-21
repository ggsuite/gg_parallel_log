// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// #############################################################################
/// The kinds of keys the interactive log reacts on.
enum GgParallelLogKeyType {
  /// The arrow up key.
  up,

  /// The arrow down key.
  down,

  /// The arrow left key.
  left,

  /// The arrow right key.
  right,

  /// The Home or Pos1 key.
  home,

  /// The End key.
  end,

  /// The Page Up key.
  pageUp,

  /// The Page Down key.
  pageDown,

  /// The Enter or Return key.
  enter,

  /// The Escape key.
  escape,

  /// The Backspace key.
  backspace,

  /// Ctrl+C, when the terminal delivers it as a character.
  ctrlC,

  /// A printable character, see [GgParallelLogKey.char].
  char,
}

// #############################################################################
/// A key pressed in the terminal.
class GgParallelLogKey {
  /// Creates a key of [type]; printable keys also carry their [char].
  const GgParallelLogKey(this.type, [this.char = '']);

  /// Creates the printable key [char].
  const GgParallelLogKey.printable(String char)
    : this(GgParallelLogKeyType.char, char);

  /// Creates an example key for tests and docs.
  factory GgParallelLogKey.example({GgParallelLogKeyType? type, String? char}) {
    final printable = type == null || type == GgParallelLogKeyType.char;
    return GgParallelLogKey(
      type ?? GgParallelLogKeyType.char,
      char ?? (printable ? 'f' : ''),
    );
  }

  // ...........................................................................
  /// Returns true when this is the printable character [c].
  bool isChar(String c) => type == GgParallelLogKeyType.char && char == c;

  // ...........................................................................
  @override
  bool operator ==(Object other) =>
      other is GgParallelLogKey && other.type == type && other.char == char;

  // ...........................................................................
  @override
  int get hashCode => Object.hash(type, char);

  // ...........................................................................
  @override
  String toString() => type == GgParallelLogKeyType.char ? char : type.name;

  // ...........................................................................
  /// The kind of the key.
  final GgParallelLogKeyType type;

  /// The character of a printable key, otherwise an empty string.
  final String char;

  // ...........................................................................
  /// Splits the raw terminal [input] into the keys it holds.
  ///
  /// Skips unknown sequences, Alt combinations and control characters.
  static List<GgParallelLogKey> parse(String input) {
    final keys = <GgParallelLogKey>[];
    var index = 0;
    while (index < input.length) {
      final match = _sequence.matchAsPrefix(input, index);
      if (match != null) {
        final type = _sequences[match[0]!];
        if (type != null) keys.add(GgParallelLogKey(type));
        index = match.end;
        continue;
      }
      final c = _charAt(input, index);
      final key = _single(c);
      if (key != null) keys.add(key);
      index += c.length;
    }
    return keys;
  }

  // ######################
  // Private
  // ######################

  /// Matches CSI and SS3 sequences, and ESC plus a character as Alt key.
  static final RegExp _sequence = RegExp(
    r'\x1B(\[[0-?]*[ -/]*[@-~]|O[@-~]|[^\x1B])',
    unicode: true,
  );

  static const Map<String, GgParallelLogKeyType> _sequences = {
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
  };

  static const Map<String, GgParallelLogKeyType> _singles = {
    '\r': GgParallelLogKeyType.enter,
    '\n': GgParallelLogKeyType.enter,
    '\x1B': GgParallelLogKeyType.escape,
    '\x7F': GgParallelLogKeyType.backspace,
    '\x08': GgParallelLogKeyType.backspace,
    '\x03': GgParallelLogKeyType.ctrlC,
  };

  // ...........................................................................
  static GgParallelLogKey? _single(String c) {
    final type = _singles[c];
    if (type != null) return GgParallelLogKey(type);
    final control = c.codeUnitAt(0) < 0x20;
    return control ? null : GgParallelLogKey.printable(c);
  }

  // ...........................................................................
  static String _charAt(String input, int index) {
    final unit = input.codeUnitAt(index);
    final pair = unit >= 0xD800 && unit <= 0xDBFF && index + 1 < input.length;
    return input.substring(index, pair ? index + 2 : index + 1);
  }
}
