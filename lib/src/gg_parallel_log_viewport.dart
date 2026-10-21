// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:math';

// #############################################################################
/// The geometry of the fullscreen view, shared by controller and view.
abstract final class GgParallelLogViewport {
  // ...........................................................................
  /// Returns the number of output lines a terminal of [height] rows shows.
  static int bodyHeight(int height) => max(1, height - 4);

  // ...........................................................................
  /// Returns the first line shown of [total] lines when scrolled to [top].
  ///
  /// A null [top] follows the end of the output.
  static int firstLine(int total, int? top, int height) {
    final last = lastFirstLine(total, height);
    return top == null ? last : top.clamp(0, last);
  }

  // ...........................................................................
  /// Returns the first line shown when following the end of [total] lines.
  static int lastFirstLine(int total, int height) =>
      max(0, total - bodyHeight(height));
}
