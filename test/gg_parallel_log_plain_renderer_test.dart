// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:fake_async/fake_async.dart';
import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_plain_renderer.dart';
import 'package:test/test.dart';

void main() {
  late GgParallelLogFakeTerminal terminal;
  late GgParallelLogPlainRenderer renderer;

  setUp(() {
    ggColorsEnabled = false;
    terminal = GgParallelLogFakeTerminal.example(isInteractive: false);
    renderer = GgParallelLogPlainRenderer.example(terminal: terminal);
  });

  tearDown(() => ggColorsEnabled = null);

  /// Creates a lane that reports its changes to the renderer.
  GgParallelLogLane lane() =>
      GgParallelLogLane.example(onChange: renderer.laneChanged);

  group('GgParallelLogPlainRenderer', () {
    group('example()', () {
      test('writes to a fake terminal that is not interactive', () {
        final terminal = GgParallelLogPlainRenderer.example().terminal;
        expect(terminal, isA<GgParallelLogFakeTerminal>());
        expect(terminal.isInteractive, isFalse);
      });
    });

    group('start()', () {
      test('writes nothing', () {
        renderer.start();
        expect(terminal.output, '');
      });
    });

    group('laneChanged(lane, line)', () {
      test('writes nothing for a waiting lane', () {
        renderer.laneChanged(lane(), null);
        expect(terminal.output, '');
      });

      test('writes the start of a lane', () {
        lane().start();
        expect(terminal.output, '[gg_log] started\n');
      });

      test('writes each line prefixed with its lane', () {
        lane()
          ..log('first')
          ..logError('second');
        expect(terminal.screen, ['[gg_log] first', '[gg_log] second']);
      });

      test('writes error lines in the error color', () {
        ggColorsEnabled = true;
        lane().logError('boom');
        expect(terminal.output, '${darkGray('[gg_log]')} ${cError('boom')}\n');
      });

      for (final (status, icon) in [
        (GgParallelLogStatus.success, '✓'),
        (GgParallelLogStatus.error, '✗'),
        (GgParallelLogStatus.cancelled, '⊘'),
      ]) {
        test('writes the end of a lane that is ${status.name}', () {
          fakeAsync((fake) {
            final running = lane()..start();
            fake.elapse(const Duration(seconds: 65));
            switch (status) {
              case GgParallelLogStatus.success:
                running.succeed();
              case GgParallelLogStatus.error:
                running.fail('boom');
              default:
                running.cancel();
            }
            expect(terminal.output, endsWith('\n'));
            expect(terminal.screen, [
              '[gg_log] started',
              if (status == GgParallelLogStatus.error) '[gg_log] boom',
              '$icon gg_log ${status.name} after 01:05',
            ]);
          });
        });
      }
    });

    group('finish(summary)', () {
      test('writes an empty line and the summary', () async {
        lane().log('done');
        await renderer.finish('summary\n');
        expect(terminal.screen, ['[gg_log] done', '', 'summary']);
      });

      test('keeps writing late lines afterwards', () async {
        final quiet = lane();
        await renderer.finish('summary\n');
        quiet.log('late');
        expect(terminal.screen, ['', 'summary', '[gg_log] late']);
      });
    });
  });
}
