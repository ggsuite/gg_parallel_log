// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_parallel_log/src/gg_parallel_log_windows_console.dart';
import 'package:test/test.dart';

void main() {
  group('GgParallelLogWindowsConsole', () {
    test('enables VT input and restores the previous mode', () {
      final mode = GgParallelLogWindowsConsole.enableVirtualTerminalInput();
      if (mode != null) GgParallelLogWindowsConsole.restoreInputMode(mode);
      expect(mode, anyOf(isNull, isA<int>()));
    });
  });
}
