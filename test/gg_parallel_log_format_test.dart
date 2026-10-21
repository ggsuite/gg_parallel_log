// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:fake_async/fake_async.dart';
import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_format.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_view_state.dart';
import 'package:test/test.dart';

void main() {
  setUp(() => ggColorsEnabled = false);
  tearDown(() => ggColorsEnabled = null);

  // Returns a lane called [name] in [status] that ran for [elapsed].
  GgParallelLogLane laneIn(
    FakeAsync async,
    GgParallelLogStatus status, {
    String name = 'gg_log',
    Duration elapsed = const Duration(seconds: 65),
    String? lastLine = 'Compiling',
  }) {
    final lane = GgParallelLogLane.example(name: name);
    if (status == GgParallelLogStatus.waiting) return lane;
    lane.start();
    async.elapse(elapsed);
    if (lastLine != null) lane.log(lastLine);
    switch (status) {
      case GgParallelLogStatus.success:
        lane.succeed();
      case GgParallelLogStatus.error:
        lane.fail('boom');
      case GgParallelLogStatus.cancelled:
        lane.cancel();
      default:
    }
    return lane;
  }

  // Returns the row of a lane in [status], built inside a fake clock.
  String row(
    GgParallelLogStatus status, {
    String name = 'gg_log',
    int nameWidth = 6,
    int frame = 0,
    bool selected = false,
    Duration elapsed = const Duration(seconds: 65),
    String? lastLine = 'Compiling',
  }) => fakeAsync(
    (async) => GgParallelLogFormat.row(
      laneIn(async, status, name: name, elapsed: elapsed, lastLine: lastLine),
      nameWidth: nameWidth,
      frame: frame,
      selected: selected,
    ),
  );

  group('GgParallelLogFormat', () {
    group('row(lane, nameWidth, frame, selected)', () {
      test('shows a waiting lane without a time', () {
        expect(row(GgParallelLogStatus.waiting), '  ○ gg_log         waiting');
      });

      test('shows the last line of a running lane', () {
        expect(
          row(GgParallelLogStatus.running),
          '  ⠋ gg_log  01:05  Compiling',
        );
      });

      test('animates the icon of a running lane with frame', () {
        expect(
          row(GgParallelLogStatus.running, frame: 3),
          '  ⠸ gg_log  01:05  Compiling',
        );
      });

      test('shows the last line of a lane that succeeded', () {
        expect(
          row(GgParallelLogStatus.success, lastLine: 'All tests passed!'),
          '  ✓ gg_log  01:05  All tests passed!',
        );
      });

      test('shows the error of a lane that failed', () {
        expect(row(GgParallelLogStatus.error), '  ✗ gg_log  01:05  boom');
      });

      test('shows that a lane was cancelled', () {
        expect(
          row(GgParallelLogStatus.cancelled),
          '  ⊘ gg_log  01:05  cancelled',
        );
      });

      test('shows nothing behind a running lane without lines', () {
        expect(
          row(GgParallelLogStatus.running, lastLine: null),
          '  ⠋ gg_log  01:05  ',
        );
      });

      test('marks the selected lane', () {
        expect(
          row(GgParallelLogStatus.running, selected: true),
          '❯ ⠋ gg_log  01:05  Compiling',
        );
      });

      test('pads the name to nameWidth', () {
        expect(
          row(GgParallelLogStatus.running, name: 'a', nameWidth: 4),
          '  ⠋ a     01:05  Compiling',
        );
      });

      test('cuts a long name to nameWidth', () {
        expect(
          row(GgParallelLogStatus.running, name: 'gg_parallel_log'),
          '  ⠋ gg_pa…  01:05  Compiling',
        );
      });

      test('pads a name with wide characters by its visible width', () {
        expect(
          row(GgParallelLogStatus.running, name: '中文 🚀', nameWidth: 8),
          '  ⠋ 中文 🚀   01:05  Compiling',
        );
      });

      test('shows the last line without its colors', () {
        expect(
          row(GgParallelLogStatus.running, lastLine: '\x1B[32mok\x1B[0m'),
          '  ⠋ gg_log  01:05  ok',
        );
      });

      test('shows hours for lanes running an hour or longer', () {
        expect(
          row(
            GgParallelLogStatus.running,
            elapsed: const Duration(hours: 1, minutes: 2, seconds: 5),
          ),
          '  ⠋ gg_log  1:02:05  Compiling',
        );
      });

      test('colors marker, icon, name, time and summary', () {
        ggColorsEnabled = true;
        expect(
          [
            row(GgParallelLogStatus.running, selected: true),
            row(GgParallelLogStatus.waiting),
            row(GgParallelLogStatus.success),
            row(GgParallelLogStatus.error),
            row(GgParallelLogStatus.cancelled),
          ],
          [
            '${cyan('❯')} ${cyan('⠋')} ${bold('gg_log')}  '
                '${darkGray('01:05')}  Compiling',
            '  ${darkGray('○')} gg_log  ${darkGray('     ')}  '
                '${darkGray('waiting')}',
            '  ${green('✓')} gg_log  ${darkGray('01:05')}  '
                '${darkGray('Compiling')}',
            '  ${red('✗')} gg_log  ${darkGray('01:05')}  ${red('boom')}',
            '  ${yellow('⊘')} gg_log  ${darkGray('01:05')}  '
                '${yellow('cancelled')}',
          ],
        );
      });
    });

    group('nameWidth(lanes)', () {
      GgParallelLogLane lane(String name) =>
          GgParallelLogLane.example(name: name);

      test('is 4 for no lanes', () {
        expect(GgParallelLogFormat.nameWidth([]), 4);
      });

      test('is at least 4', () {
        expect(GgParallelLogFormat.nameWidth([lane('a'), lane('ab')]), 4);
      });

      test('fits the widest name', () {
        expect(
          GgParallelLogFormat.nameWidth([lane('gg_log'), lane('gg_one_two')]),
          10,
        );
      });

      test('measures wide characters and emoji by their columns', () {
        expect(GgParallelLogFormat.nameWidth([lane('中文中文 🚀')]), 11);
      });

      test('is at most 28', () {
        expect(GgParallelLogFormat.nameWidth([lane('x' * 40)]), 28);
      });
    });

    group('counts(lanes)', () {
      test('counts no lanes', () {
        expect(GgParallelLogFormat.counts([]), '0/0 done');
      });

      test('counts the lanes that are done', () {
        final lanes = [
          GgParallelLogLane.example(name: 'a'),
          GgParallelLogLane.example(name: 'b')..start(),
          GgParallelLogLane.example(name: 'c')..succeed(),
        ];
        expect(GgParallelLogFormat.counts(lanes), '1/3 done');
      });

      test('adds the failed and cancelled lanes', () {
        final lanes = [
          GgParallelLogLane.example(name: 'a')..succeed(),
          GgParallelLogLane.example(name: 'b')..fail('x'),
          GgParallelLogLane.example(name: 'c')..fail('y'),
          GgParallelLogLane.example(name: 'd')..cancel(),
          GgParallelLogLane.example(name: 'e')..start(),
        ];
        expect(
          GgParallelLogFormat.counts(lanes),
          '4/5 done · 2 failed · 1 cancelled',
        );
      });

      test('colors failed red and cancelled yellow', () {
        ggColorsEnabled = true;
        final lanes = [
          GgParallelLogLane.example(name: 'a')..fail('x'),
          GgParallelLogLane.example(name: 'b')..cancel(),
        ];
        expect(
          GgParallelLogFormat.counts(lanes),
          '2/2 done · ${red('1 failed')} · ${yellow('1 cancelled')}',
        );
      });
    });

    group('output(line, prefix, query)', () {
      test('shows the time and the text of the line', () {
        expect(
          GgParallelLogFormat.output(GgParallelLogLine.example()),
          '00:03 │ 00:03 +12: All tests passed!',
        );
      });

      test('starts with prefix', () {
        expect(
          GgParallelLogFormat.output(
            GgParallelLogLine.example(text: 'a'),
            prefix: '   ',
          ),
          '   00:03 │ a',
        );
      });

      test('shows hours for lines logged after an hour', () {
        expect(
          GgParallelLogFormat.output(
            GgParallelLogLine.example(
              text: 'a',
              time: const Duration(hours: 1, seconds: 5),
            ),
          ),
          '1:00:05 │ a',
        );
      });

      test('keeps the colors of a normal line', () {
        expect(
          GgParallelLogFormat.output(
            GgParallelLogLine.example(text: '\x1B[32mok\x1B[0m'),
          ),
          '00:03 │ \x1B[32mok\x1B[0m',
        );
      });

      test('drops the own colors of an error line', () {
        expect(
          GgParallelLogFormat.output(
            GgParallelLogLine.example(
              text: '\x1B[33mboom\x1B[0m',
              isError: true,
            ),
          ),
          '00:03 │ boom',
        );
      });

      test('shows an error line in red', () {
        ggColorsEnabled = true;
        expect(
          GgParallelLogFormat.output(
            GgParallelLogLine.example(
              text: '\x1B[33mboom\x1B[0m',
              isError: true,
            ),
          ),
          '${darkGray('00:03')} ${darkGray('│')} ${red('boom')}',
        );
      });

      test('inverts every match of query ignoring case and colors', () {
        expect(
          GgParallelLogFormat.output(
            GgParallelLogLine.example(text: '\x1B[32mExpected\x1B[0m: exp'),
            query: 'EXP',
          ),
          '00:03 │ \x1B[7mExp\x1B[27mected: \x1B[7mexp\x1B[27m',
        );
      });

      test('keeps a line that does not match query unchanged', () {
        expect(
          GgParallelLogFormat.output(
            GgParallelLogLine.example(text: '\x1B[32mok\x1B[0m'),
            query: 'error',
          ),
          '00:03 │ \x1B[32mok\x1B[0m',
        );
      });

      test('does not match the escape codes of a line', () {
        expect(
          GgParallelLogFormat.output(
            GgParallelLogLine.example(text: '\x1B[32mok\x1B[0m'),
            query: '32m',
          ),
          '00:03 │ \x1B[32mok\x1B[0m',
        );
      });

      test('inverts the match of an error line in red', () {
        ggColorsEnabled = true;
        expect(
          GgParallelLogFormat.output(
            GgParallelLogLine.example(text: 'a boom', isError: true),
            query: 'boom',
          ),
          '${darkGray('00:03')} ${darkGray('│')} '
          '${red('a \x1B[7mboom\x1B[27m')}',
        );
      });
    });

    group('notice(notice, kind)', () {
      const info = GgParallelLogNoticeKind.info;
      const warning = GgParallelLogNoticeKind.warning;
      const error = GgParallelLogNoticeKind.error;

      test('returns an info unchanged', () {
        expect(
          GgParallelLogFormat.notice('Saved to gg_log.log', info),
          'Saved to gg_log.log',
        );
      });

      test('keeps only the first line', () {
        expect(
          GgParallelLogFormat.notice('Cannot save\nstack trace\n', info),
          'Cannot save',
        );
      });

      test('drops cursor moves and control characters', () {
        expect(GgParallelLogFormat.notice('a\tb\x1B[2K\x07\r', info), 'a    b');
      });

      test('keeps the colors of the notice', () {
        expect(
          GgParallelLogFormat.notice('\x1B[32mok\x1B[0m', info),
          '\x1B[32mok\x1B[0m',
        );
      });

      test('returns an empty notice as it is', () {
        expect(GgParallelLogFormat.notice('', info), '');
      });

      test('returns each kind uncolored without colors', () {
        expect(
          [
            for (final kind in GgParallelLogNoticeKind.values)
              GgParallelLogFormat.notice('Saved 😀', kind),
          ],
          ['Saved 😀', 'Saved 😀', 'Saved 😀'],
        );
      });

      test('colors a warning yellow and an error red', () {
        ggColorsEnabled = true;
        expect(
          [
            GgParallelLogFormat.notice('a\nb', info),
            GgParallelLogFormat.notice('a\nb', warning),
            GgParallelLogFormat.notice('a\nb', error),
          ],
          ['a', yellow('a'), red('a')],
        );
      });
    });

    group('plural(count, singular, plural)', () {
      final cases = {0: '0 matches', 1: '1 match', 2: '2 matches'};
      for (final MapEntry(:key, :value) in cases.entries) {
        test('returns "$value" for $key', () {
          expect(GgParallelLogFormat.plural(key, 'match', 'matches'), value);
        });
      }
    });
  });
}
