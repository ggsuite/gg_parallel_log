#!/usr/bin/env dart

// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';
import 'dart:math';

import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:gg_status_printer/gg_status_printer.dart';

/// Simulates publishing eight packages, three of them at a time.
Future<void> main() async {
  final log = GgParallelLog(title: 'gg do publish');
  final result = await log.runAll({
    for (final MapEntry(key: package, value: tests) in _packages.entries)
      package: (lane) => _publish(lane, tests),
  }, concurrency: 3);
  exitCode = result.exitCode;
}

/// The packages with the number of their tests.
const _packages = {
  'gg_log': 12,
  'gg_console_colors': 36,
  'gg_status_printer': 54,
  'gg_process': 80,
  'gg_git': 140,
  'gg_one': 95,
  'gg_multi': 420,
  'gg': 210,
};

final _random = Random(7);

// .............................................................................
Future<void> _publish(GgParallelLogLane lane, int tests) async {
  final sdk = await Process.start('dart', ['--version'], runInShell: true);
  await lane.pipe(sdk);

  await _step(lane, 'Running "dart pub get"', 800);
  await _step(lane, 'Running "dart analyze"', 1500);
  if (lane.name == 'gg_git') {
    lane.logError('Warning: 2 files are not formatted, fixed them.');
  }
  await _test(lane, tests);
  await _step(lane, 'Publishing to pub.dev', 1200);
  print('Published ${lane.name} 1.${_random.nextInt(9)}.${_random.nextInt(9)}');
}

// .............................................................................
Future<void> _step(GgParallelLogLane lane, String message, int ms) =>
    GgStatusPrinter<void>(
      message: message,
      ggLog: lane.log,
    ).run(() => _sleep(ms ~/ 2 + _random.nextInt(ms)));

// .............................................................................
Future<void> _test(GgParallelLogLane lane, int tests) async {
  final failing = lane.name == 'gg_one';
  var failed = 0;
  for (var i = 1; i <= tests && !lane.isCancelled; i++) {
    await _sleep(15 + _random.nextInt(60));
    final file = 'test/${lane.name}_${i % 7}_test.dart';
    if (failing && i % 30 == 0) {
      failed++;
      lane.logError('+${i - failed} -$failed: $file: publishes v$i [E]');
      lane.logError("  Expected: '1.2.$i'");
      lane.logError("    Actual: '1.2.${i - 1}'");
      continue;
    }
    lane.log('+${i - failed}${failed > 0 ? ' -$failed' : ''}: $file: case $i');
  }
  if (failed > 0) throw Exception('$failed tests failed');
  lane.log('+$tests: All tests passed!');
}

// .............................................................................
Future<void> _sleep(int ms) => Future<void>.delayed(Duration(milliseconds: ms));
