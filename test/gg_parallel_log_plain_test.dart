// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_plain.dart';
import 'package:test/test.dart';

void main() {
  late GgParallelLogFakeTerminal terminal;
  late GgParallelLogPlain plain;

  setUp(() {
    ggColorsEnabled = false;
    terminal = GgParallelLogFakeTerminal(isInteractive: false);
    plain = GgParallelLogPlain.example(terminal: terminal)..start();
  });
  tearDown(() => ggColorsEnabled = null);

  group('GgParallelLogPlain', () {
    test('example() writes to a fake terminal', () {
      expect(
        GgParallelLogPlain.example().terminal,
        isA<GgParallelLogFakeTerminal>(),
      );
    });

    group('laneChanged(lane, line)', () {
      test('writes lines and status changes prefixed with the lane', () {
        final lane = GgParallelLogLane.example(onChange: plain.laneChanged);
        plain.laneChanged(lane, null);
        lane
          ..start()
          ..log('ok')
          ..logError('warning')
          ..succeed();
        expect(
          terminal.output,
          '[gg_log] started\n'
          '[gg_log] ok\n'
          '[gg_log] warning\n'
          '✓ gg_log success after 00:00\n',
        );
      });

      test('colors error lines', () {
        ggColorsEnabled = true;
        final lane = GgParallelLogLane.example(onChange: plain.laneChanged);
        lane.logError('boom');
        expect(terminal.output, contains(red('boom')));
      });
    });

    group('finish(summary)', () {
      test('writes the summary after a blank line', () async {
        await plain.finish('summary\n');
        expect(terminal.output, '\nsummary\n');
      });
    });
  });
}
