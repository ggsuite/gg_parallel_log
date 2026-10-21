// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_native_console.dart';
import 'package:test/test.dart';

void main() {
  group('GgParallelLogNativeConsole', () {
    group('create()', () {
      test('returns the console of the current platform', () {
        expect(
          GgParallelLogNativeConsole.create(),
          isA<GgParallelLogConsole>(),
        );
      });
    });
  });
}
