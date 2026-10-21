// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_saver.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late GgParallelLogSaver saver;
  final now = DateTime(2026, 1, 2, 3, 4, 5);
  const stamp = '20260102_030405';

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('gg_parallel_log_saver_');
    saver = GgParallelLogSaver.example(directory: tmp);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  // ...........................................................................
  /// Saves [lane] at [now] and returns the file.
  File save(GgParallelLogLane lane) =>
      withClock(Clock.fixed(now), () => saver.save(lane));

  group('GgParallelLogSaver', () {
    group('GgParallelLogSaver(directory)', () {
      test('writes into a temp folder by default', () {
        expect(
          GgParallelLogSaver().directory.path,
          join(Directory.systemTemp.path, 'gg_parallel_log'),
        );
      });

      test('writes into the given folder', () {
        expect(saver.directory.path, tmp.path);
      });
    });

    group('save(lane)', () {
      test('creates the folder', () {
        final logs = Directory(join(tmp.path, 'a', 'logs'));
        saver = GgParallelLogSaver.example(directory: logs);
        final file = save(GgParallelLogLane.example());
        expect(file.path, join(logs.path, 'gg_log_$stamp.log'));
        expect(file.existsSync(), isTrue);
      });

      test('names the file after the lane and the time', () {
        final file = save(GgParallelLogLane.example());
        expect(basename(file.path), 'gg_log_$stamp.log');
      });

      for (final (name, safe) in [
        ('gg one/x', 'gg_one_x'),
        ('a  b', 'a_b'),
        ('v1.2-rc_3', 'v1.2-rc_3'),
        (r'ä\ö:*?', '_'),
        ('日本', '_'),
      ]) {
        test('names the lane "$name" as "$safe"', () {
          final file = save(GgParallelLogLane.example(name: name));
          expect(basename(file.path), '${safe}_$stamp.log');
        });
      }

      test('never overwrites a file but counts up', () {
        final taken = File(join(tmp.path, 'gg_log_$stamp.log'))
          ..writeAsStringSync('old');
        final lane = GgParallelLogLane.example();
        final names = [save(lane), save(lane)].map((f) => basename(f.path));
        expect(names, ['gg_log_${stamp}_2.log', 'gg_log_${stamp}_3.log']);
        expect(taken.readAsStringSync(), 'old');
      });

      test('writes the lines with their time and without colors', () {
        fakeAsync((async) {
          final lane = GgParallelLogLane.example()..start();
          lane.log('\x1B[32mok\x1B[0m');
          async.elapse(const Duration(seconds: 65));
          lane
            ..logError('\x1B[31mboom\x1B[0m')
            ..log('done');
          final file = saver.save(lane);
          expect(
            file.readAsStringSync(),
            '00:00 ok\n01:05 ! boom\n01:05 done\n',
          );
        }, initialTime: now);
      });

      test('writes an empty file for a lane without output', () {
        expect(save(GgParallelLogLane.example()).readAsStringSync(), '');
      });

      test('fails when a folder has the name of the file', () {
        final path = join(tmp.path, 'gg_log_$stamp.log');
        Directory(path).createSync();
        expect(
          () => save(GgParallelLogLane.example()),
          throwsA(
            isA<FileSystemException>().having((e) => e.path, 'path', path),
          ),
        );
      });
    });
  });
}
