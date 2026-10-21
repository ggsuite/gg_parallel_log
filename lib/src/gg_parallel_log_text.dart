// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// #############################################################################
/// Measures, cuts and cleans terminal text that may hold ANSI escapes.
abstract final class GgParallelLogText {
  // ...........................................................................
  /// Returns the number of terminal columns [text] occupies.
  static int visibleWidth(String text) {
    var width = 0;
    for (final rune in stripAnsi(text).runes) {
      width += runeWidth(rune);
    }
    return width;
  }

  // ...........................................................................
  /// Returns the number of terminal columns a single [rune] occupies.
  static int runeWidth(int rune) {
    if (rune < 0x20 || _isZeroWidth(rune)) return 0;
    return _isWide(rune) ? 2 : 1;
  }

  // ...........................................................................
  /// Removes all ANSI escape sequences from [text].
  static String stripAnsi(String text) => text.replaceAll(_ansi, '');

  // ...........................................................................
  /// Keeps colors but removes cursor moves, carriage returns and tabs.
  static String sanitize(String text) => text
      .replaceAllMapped(_ansi, (m) => m[0]!.endsWith('m') ? m[0]! : '')
      .replaceAll('\r', '')
      .replaceAll('\t', '    ');

  // ...........................................................................
  /// Cuts [text] to [width] columns and marks the cut with an ellipsis.
  static String truncate(String text, int width) {
    if (visibleWidth(text) <= width) return text;
    if (width <= 0) return '';

    final result = StringBuffer();
    var used = 0;
    var hasAnsi = false;
    for (final token in _tokens(text)) {
      if (token.startsWith('\x1B')) {
        result.write(token);
        hasAnsi = true;
        continue;
      }
      final w = runeWidth(token.runes.first);
      if (used + w > width - 1) break;
      result.write(token);
      used += w;
    }
    result.write('…');
    if (hasAnsi) result.write(_reset);
    return result.toString();
  }

  // ...........................................................................
  /// Pads [text] with spaces to exactly [width] visible columns.
  static String pad(String text, int width) {
    final missing = width - visibleWidth(text);
    return missing > 0 ? '$text${' ' * missing}' : text;
  }

  // ...........................................................................
  /// Cuts or pads [text] so that it fills exactly [width] columns.
  static String fit(String text, int width) =>
      pad(truncate(text, width), width);

  // ...........................................................................
  /// Places [left] and [right] on one line of [width] columns.
  static String spread(String left, String right, int width) {
    final gap = width - visibleWidth(left) - visibleWidth(right);
    if (gap < 1) return truncate(left, width);
    return '$left${' ' * gap}$right';
  }

  // ...........................................................................
  /// Formats [duration] as `mm:ss`, or `h:mm:ss` from one hour on.
  static String duration(Duration duration) {
    String two(int value) => value.toString().padLeft(2, '0');
    final minutes = two(duration.inMinutes.remainder(60));
    final seconds = two(duration.inSeconds.remainder(60));
    if (duration.inHours == 0) return '$minutes:$seconds';
    return '${duration.inHours}:$minutes:$seconds';
  }

  // ...........................................................................
  /// Wraps [text] in reverse video, which stays visible without colors.
  static String inverse(String text) => '\x1B[7m$text\x1B[27m';

  // ...........................................................................
  /// Inverts every case insensitive occurrence of [query] in [text].
  static String highlight(String text, String query) {
    if (query.isEmpty) return text;
    final plain = stripAnsi(text);
    final pattern = RegExp(RegExp.escape(query), caseSensitive: false);
    return plain.replaceAllMapped(pattern, (m) => inverse(m[0]!));
  }

  // ...........................................................................
  /// Returns true when [text] contains [query], ignoring case and colors.
  static bool contains(String text, String query) =>
      stripAnsi(text).toLowerCase().contains(query.toLowerCase());

  // ######################
  // Private
  // ######################

  static const String _reset = '\x1B[0m';

  static final RegExp _ansi = RegExp(
    r'\x1B\[[0-?]*[ -/]*[@-~]|\x1B\][^\x07]*\x07|\x1B[ -~]',
  );

  // ...........................................................................
  static Iterable<String> _tokens(String text) sync* {
    var index = 0;
    for (final match in _ansi.allMatches(text)) {
      yield* _runes(text.substring(index, match.start));
      yield match[0]!;
      index = match.end;
    }
    yield* _runes(text.substring(index));
  }

  // ...........................................................................
  static Iterable<String> _runes(String text) =>
      text.runes.map(String.fromCharCode);

  // ...........................................................................
  static bool _isZeroWidth(int rune) =>
      (rune >= 0x0300 && rune <= 0x036F) ||
      (rune >= 0x200B && rune <= 0x200F) ||
      (rune >= 0xFE00 && rune <= 0xFE0F);

  // ...........................................................................
  static bool _isWide(int rune) {
    for (final range in _wideRanges) {
      if (rune < range.$1) return false;
      if (rune <= range.$2) return true;
    }
    return false;
  }

  static const List<(int, int)> _wideRanges = [
    (0x1100, 0x115F),
    (0x231A, 0x231B),
    (0x2329, 0x232A),
    (0x23E9, 0x23EC),
    (0x23F0, 0x23F0),
    (0x23F3, 0x23F3),
    (0x25FD, 0x25FE),
    (0x2614, 0x2615),
    (0x2648, 0x2653),
    (0x267F, 0x267F),
    (0x2693, 0x2693),
    (0x26A1, 0x26A1),
    (0x26AA, 0x26AB),
    (0x26BD, 0x26BE),
    (0x26C4, 0x26C5),
    (0x26CE, 0x26CE),
    (0x26D4, 0x26D4),
    (0x26EA, 0x26EA),
    (0x26F2, 0x26F3),
    (0x26F5, 0x26F5),
    (0x26FA, 0x26FA),
    (0x26FD, 0x26FD),
    (0x2705, 0x2705),
    (0x270A, 0x270B),
    (0x2728, 0x2728),
    (0x274C, 0x274C),
    (0x274E, 0x274E),
    (0x2753, 0x2755),
    (0x2757, 0x2757),
    (0x2795, 0x2797),
    (0x27B0, 0x27B0),
    (0x27BF, 0x27BF),
    (0x2B1B, 0x2B1C),
    (0x2B50, 0x2B50),
    (0x2B55, 0x2B55),
    (0x2E80, 0x303E),
    (0x3041, 0x33FF),
    (0x3400, 0x4DBF),
    (0x4E00, 0x9FFF),
    (0xA000, 0xA4CF),
    (0xAC00, 0xD7A3),
    (0xF900, 0xFAFF),
    (0xFE30, 0xFE4F),
    (0xFF00, 0xFF60),
    (0xFFE0, 0xFFE6),
    (0x1F300, 0x1F64F),
    (0x1F680, 0x1F6FF),
    (0x1F900, 0x1F9FF),
    (0x1FA70, 0x1FAFF),
    (0x20000, 0x3FFFD),
  ];
}
