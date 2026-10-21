// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:test/test.dart';

void main() {
  group('GgParallelLogStdioTerminal', () {
    test('is not interactive without a TTY, as in a test run', () {
      final terminal = GgParallelLogStdioTerminal.example();
      expect(terminal.isInteractive, isFalse);
      expect(terminal.width, greaterThan(0));
      expect(terminal.height, greaterThan(0));
    });
  });
}
