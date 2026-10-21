// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:math';

import 'gg_parallel_log_lane.dart';

// #############################################################################
/// Finds the lines of a lane that contain a query, scanning new lines only.
class GgParallelLogSearch {
  /// Creates a search with an empty cache.
  GgParallelLogSearch();

  /// Creates an example search for tests and docs.
  factory GgParallelLogSearch.example() => GgParallelLogSearch();

  // ...........................................................................
  /// Returns the indices of the lines of [lane] that contain [query].
  ///
  /// Ignores case and colors; rechecks the last line, it may be replaced.
  List<int> matches(GgParallelLogLane lane, String query) {
    if (query.isEmpty) return const [];
    final needle = query.toLowerCase();
    var entry = _cache[lane];
    if (entry == null || entry.needle != needle) {
      entry = _cache[lane] = _Entry(needle);
    }
    final lines = lane.lines;
    final start = max(0, entry.scanned - 1);
    entry.matches.removeWhere((index) => index >= start);
    for (var i = start; i < lines.length; i++) {
      if (lines[i].searchText.contains(needle)) entry.matches.add(i);
    }
    entry.scanned = lines.length;
    return List.unmodifiable(entry.matches);
  }

  // ######################
  // Private
  // ######################

  final Expando<_Entry> _cache = Expando();
}

// #############################################################################
class _Entry {
  _Entry(this.needle);

  final String needle;
  final List<int> matches = [];
  int scanned = 0;
}
