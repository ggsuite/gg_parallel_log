// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:test/test.dart';

void main() {
  group('GgParallelLogTerminal', () {
    test('is implemented by the fake and the stdio terminal', () {
      expect([
        GgParallelLogFakeTerminal.example(),
        GgParallelLogStdioTerminal.example(),
      ], everyElement(isA<GgParallelLogTerminal>()));
    });
  });
}
