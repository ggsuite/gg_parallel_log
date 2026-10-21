// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_parallel_log/src/gg_parallel_log_interactive_renderer.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_plain_renderer.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_renderer.dart';
import 'package:test/test.dart';

void main() {
  group('GgParallelLogRenderer', () {
    test('is implemented by the plain and the interactive renderer', () {
      expect([
        GgParallelLogPlainRenderer.example(),
        GgParallelLogInteractiveRenderer.example(),
      ], everyElement(isA<GgParallelLogRenderer>()));
    });
  });
}
