// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_saver.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('gg_parallel_log_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('GgParallelLogSaver', () {
    test('writes into a temp folder by default', () {
      expect(
        GgParallelLogSaver.example().directory.path,
        join(Directory.systemTemp.path, 'gg_parallel_log'),
      );
    });

    group('save(lane)', () {
      test('writes the lines without colors into a stamped file', () {
        final saver = GgParallelLogSaver.example(
          directory: Directory(join(tmp.path, 'logs')),
        );
        final file = withClock(
          Clock.fixed(DateTime(2026, 10, 21, 15, 7, 9)),
          () {
            final lane = GgParallelLogLane.example(name: 'gg one/x')
              ..log('\x1B[32mok\x1B[0m')
              ..logError('boom');
            return saver.save(lane);
          },
        );
        expect(basename(file.path), 'gg_one_x_20261021_150709.log');
        expect(file.readAsStringSync(), '00:00 ok\n00:00 ! boom\n');
      });
    });
  });
}
