// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:test/test.dart' show expect, group, test;

void main() {
  group('GgParallelLog', () {
    test('greets with the greeting', () {
      expect(const GgParallelLog(greeting: 'Hi').greet('Ada'), 'Hi, Ada!');
    });

    test('example() greets with Hello', () {
      expect(GgParallelLog.example().greet('Ada'), 'Hello, Ada!');
      expect(GgParallelLog.example(greeting: 'Hey').greeting, 'Hey');
    });
  });
}
