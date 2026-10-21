// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_saver.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_summary.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() {
    ggColorsEnabled = false;
    tmp = Directory.systemTemp.createTempSync('gg_parallel_log_');
  });
  tearDown(() {
    ggColorsEnabled = null;
    tmp.deleteSync(recursive: true);
  });

  group('GgParallelLogSummary', () {
    test('example() summarizes a waiting lane', () {
      expect(
        GgParallelLogSummary.example().text(),
        ' gg do publish · 0/1 done · 00:00\n  ○ gg_log         waiting\n',
      );
    });

    group('text()', () {
      test('lists the lanes', () {
        final lane = GgParallelLogLane.example()
          ..start()
          ..log('Published')
          ..succeed();
        expect(
          GgParallelLogSummary.example(lanes: [lane]).text(),
          ' gg do publish · 1/1 done · 00:00\n'
          '  ✓ gg_log  00:00  Published\n',
        );
      });

      test('repeats the last lines of failed lanes and saves the rest', () {
        final failed = GgParallelLogLane.example(name: 'gg_one')
          ..start()
          ..log('one')
          ..log('two')
          ..log('three')
          ..fail('boom');
        final text = GgParallelLogSummary.example(
          lanes: [failed],
          tail: 2,
          saver: GgParallelLogSaver(directory: tmp),
        ).text();
        final lines = text.split('\n');
        expect(lines[0], ' ✗ gg_one ${'─' * 68}');
        expect(lines[1], startsWith('   … 2 earlier lines · full log: '));
        expect(lines.sublist(2), [
          '   00:00 │ three',
          '   00:00 │ boom',
          '',
          ' gg do publish · 1/1 done · 1 failed · 00:00',
          '  ✗ gg_one  00:00  boom',
          '',
        ]);
        expect(tmp.listSync(), hasLength(1));
      });

      test('repeats short failed lanes completely', () {
        final failed = GgParallelLogLane.example()..fail('boom');
        final text = GgParallelLogSummary.example(lanes: [failed]).text();
        expect(text, isNot(contains('earlier lines')));
        expect(text, contains('   00:00 │ boom\n\n gg do publish'));
      });
    });
  });
}
