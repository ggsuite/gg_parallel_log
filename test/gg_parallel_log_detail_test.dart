// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:fake_async/fake_async.dart';
import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_detail.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_keymap.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_view_state.dart';
import 'package:test/test.dart';

void main() {
  const detail = GgParallelLogMode.detail;
  const search = GgParallelLogMode.search;
  final hints = ' ${const GgParallelLogKeymap().hints(detail)}';

  setUp(() => ggColorsEnabled = false);
  tearDown(() => ggColorsEnabled = null);

  // ...........................................................................
  /// Runs [body] with a lane that logged `line i` in second i of 30.
  void withLane(void Function(GgParallelLogLane lane) body) {
    fakeAsync((async) {
      final lane = GgParallelLogLane.example()..start();
      for (var i = 1; i <= 30; i++) {
        async.elapse(const Duration(seconds: 1));
        lane.log('line $i');
      }
      body(lane);
    });
  }

  /// Renders [lane] on a terminal of 120 x 10 unless told otherwise.
  List<String> render(
    GgParallelLogLane lane, {
    GgParallelLogViewState? state,
    List<int>? matches,
    int? index,
    int? count,
    int? width,
    int height = 10,
  }) => GgParallelLogDetail.example(
    lane: lane,
    state: state,
    matches: matches,
    index: index,
    count: count,
    width: width ?? 120,
    height: height,
  ).lines();

  GgParallelLogViewState state({
    GgParallelLogMode? mode,
    int? top,
    String? query,
    String? input,
    int? match,
    String? notice,
    GgParallelLogConfirm? confirm,
  }) => GgParallelLogViewState.example(
    mode: mode ?? detail,
    top: top,
    query: query,
    input: input,
    match: match,
    notice: notice,
    confirm: confirm,
  );

  /// Cuts [text] of single column characters to [width] columns.
  String cut(String text, int width) =>
      text.length <= width ? text : '${text.substring(0, width - 1)}…';

  const title = ' ⠋ gg_log  running · 00:30';
  final head = '$title${' ' * 85}lane 1/1';
  final rule = '─' * 119;
  String line(int i) => '  00:${'$i'.padLeft(2, '0')} │ line $i';
  String position(String info) => '──$info${'─' * (117 - info.length)}';
  final last = [for (var i = 25; i <= 30; i++) line(i)];

  group('GgParallelLogDetail', () {
    group('example()', () {
      test('shows a lane without output yet', () {
        final lines = GgParallelLogDetail.example(height: 6).lines();
        expect(lines, [
          ' ○ gg_log  waiting · 00:00${' ' * 45}lane 1/1',
          '─' * 79,
          '',
          '',
          '── no output yet ${'─' * 62}',
          cut(hints, 79),
        ]);
      });
    });

    group('lines()', () {
      test('shows the end of the output and follows it', () {
        withLane((lane) {
          expect(render(lane), [
            head,
            rule,
            ...last,
            position(' 25–30 of 30 · following '),
            hints,
          ]);
        });
      });

      test('shows the output from top on', () {
        withLane((lane) {
          expect(render(lane, state: state(top: 5)), [
            head,
            rule,
            for (var i = 6; i <= 11; i++) line(i),
            position(' 6–11 of 30 '),
            hints,
          ]);
        });
      });

      test('shows the last page for a top beyond it', () {
        withLane((lane) {
          expect(render(lane, state: state(top: 99)), [
            head,
            rule,
            ...last,
            position(' 25–30 of 30 '),
            hints,
          ]);
        });
      });

      test('fills a short output up with empty lines', () {
        fakeAsync((async) {
          final lane = GgParallelLogLane.example()..start();
          async.elapse(const Duration(seconds: 2));
          lane
            ..log('line 2')
            ..log('line 2');
          expect(render(lane), [
            ' ⠋ gg_log  running · 00:02${' ' * 85}lane 1/1',
            rule,
            line(2),
            line(2),
            '',
            '',
            '',
            '',
            position(' 1–2 of 2 · following '),
            hints,
          ]);
        });
      });

      test('shows the position of the lane among all lanes', () {
        withLane((lane) {
          expect(
            render(lane, index: 1, count: 3).first,
            '$title${' ' * 85}lane 2/3',
          );
        });
      });

      test('shows the icon of the status', () {
        final lane = GgParallelLogLane.example()..succeed();
        expect(
          render(lane).first,
          ' ✓ gg_log  success · 00:00${' ' * 85}lane 1/1',
        );
      });

      group('on a low terminal', () {
        final head60 = '$title${' ' * 25}lane 1/1';
        final rule60 = '─' * 59;
        final position60 = '── 30–30 of 30 · following ${'─' * 32}';
        final small = {
          0: [head60],
          1: [head60],
          2: [head60, rule60],
          3: [head60, rule60, line(30)],
          4: [head60, rule60, line(30), position60],
          5: [head60, rule60, line(30), position60, cut(hints, 59)],
        };
        for (final MapEntry(key: height, value: lines) in small.entries) {
          test('shows ${lines.length} lines on $height rows', () {
            withLane((lane) {
              expect(render(lane, width: 60, height: height), lines);
            });
          });
        }

        test('shows two output lines on 6 rows', () {
          withLane((lane) {
            expect(render(lane, height: 6), [
              head,
              rule,
              line(29),
              line(30),
              position(' 29–30 of 30 · following '),
              hints,
            ]);
          });
        });
      });

      test('cuts every line to one column less than the width', () {
        fakeAsync((async) {
          final lane = GgParallelLogLane.example()..start();
          async.elapse(const Duration(seconds: 1));
          lane.log('x' * 40);
          const notice = 'Saved to /tmp/gg_parallel_log/gg_log.log';
          expect(render(lane, state: state(notice: notice), width: 30), [
            ' ⠋ gg_log  running · 00:01',
            '─' * 29,
            '  00:01 │ ${'x' * 18}…',
            '',
            '',
            '',
            '',
            '',
            '── 1–1 of 1 · following ─────',
            ' Saved to /tmp/gg_parallel_l…',
          ]);
        });
      });

      group('with a search', () {
        String hit(int i, String query) =>
            '  00:$i │ \x1B[7m$query\x1B[27m${'$i'.substring(1)}\x1B[0m';

        test('marks the line of the current match', () {
          withLane((lane) {
            expect(
              render(lane, state: state(match: 27))[5],
              '❯ 00:28 │ line 28',
            );
          });
        });

        test('highlights the confirmed query', () {
          withLane((lane) {
            expect(render(lane, state: state(query: 'LINE 2')).sublist(2, 8), [
              '  00:25 │ \x1B[7mline 2\x1B[27m5\x1B[0m',
              '  00:26 │ \x1B[7mline 2\x1B[27m6\x1B[0m',
              '  00:27 │ \x1B[7mline 2\x1B[27m7\x1B[0m',
              '  00:28 │ \x1B[7mline 2\x1B[27m8\x1B[0m',
              '  00:29 │ \x1B[7mline 2\x1B[27m9\x1B[0m',
              line(30),
            ]);
          });
        });

        test('highlights the typed input instead of the query', () {
          withLane((lane) {
            final s = state(mode: search, query: 'line 2', input: 'line 3');
            expect(render(lane, state: s).sublist(2, 8), [
              ...last.sublist(0, 5),
              hit(30, 'line 3'),
            ]);
          });
        });

        test('shows the current match and the count in the footer', () {
          withLane((lane) {
            final s = state(query: 'line 2', match: 20);
            expect(
              render(lane, state: s, matches: [1, 19, 20, 21]).last,
              ' "line 2" 3/4 · ${hints.substring(1)}',
            );
          });
        });

        test('shows 0 as current match before the first jump', () {
          withLane((lane) {
            expect(
              render(lane, state: state(query: 'nope')).last,
              ' "nope" 0/0 · ${hints.substring(1)}',
            );
          });
        });

        for (final (count, found) in [
          (0, '0 matches'),
          (1, '1 match'),
          (2, '2 matches'),
        ]) {
          test('shows "$found" while typing', () {
            withLane((lane) {
              final s = state(mode: search, input: 'line 3');
              final matches = [for (var i = 0; i < count; i++) i];
              const footer = ' /line 3▏';
              final right = '$found · ⏎ search · Esc cancel';
              expect(
                render(lane, state: s, matches: matches).last,
                '$footer${' ' * (119 - footer.length - right.length)}$right',
              );
            });
          });
        }
      });

      group('in the footer', () {
        List<String> footer(GgParallelLogViewState state) {
          late List<String> lines;
          withLane((lane) => lines = render(lane, state: state));
          return [lines.last];
        }

        for (final kind in GgParallelLogNoticeKind.values) {
          test('colors a notice of kind ${kind.name}', () {
            ggColorsEnabled = true;
            final colored = switch (kind) {
              GgParallelLogNoticeKind.info => ' Saved',
              GgParallelLogNoticeKind.warning => ' ${cWarn('Saved')}',
              GgParallelLogNoticeKind.error => ' ${cError('Saved')}',
            };
            expect(
              footer(
                GgParallelLogViewState.example(
                  mode: detail,
                  notice: 'Saved',
                  noticeKind: kind,
                ),
              ),
              [colored],
            );
          });
        }

        test('shows the first line of a notice only, without controls', () {
          expect(
            footer(
              GgParallelLogViewState.example(
                mode: detail,
                notice: 'Saved\x07 to a.log\nsecond line',
              ),
            ),
            [' Saved to a.log'],
          );
        });

        test('shows a notice', () {
          withLane((lane) {
            final s = state(
              notice: 'Saved',
              confirm: GgParallelLogConfirm.cancelLane,
            );
            expect(render(lane, state: s).last, ' Saved');
          });
        });

        test('asks to confirm cancelling the lane', () {
          withLane((lane) {
            final s = state(confirm: GgParallelLogConfirm.cancelLane);
            expect(
              render(lane, state: s).last,
              ' Press x again to cancel gg_log',
            );
          });
        });

        test('lists the hints of its keymap', () {
          final lines = GgParallelLogDetail(
            lane: GgParallelLogLane.example(),
            keymap: GgParallelLogKeymap.example(
              bindings: [
                const GgParallelLogBinding(
                  action: GgParallelLogAction.save,
                  keys: [],
                  modes: {detail},
                  hint: 's store',
                ),
              ],
            ),
          ).lines();
          expect(lines.last, ' s store');
        });
      });

      group('with error lines', () {
        test('removes their own colors', () {
          fakeAsync((async) {
            final lane = GgParallelLogLane.example()..start();
            lane
              ..logError('\x1B[31mboom\x1B[0m')
              ..log('\x1B[32mok\x1B[0m');
            expect(render(lane).sublist(2, 4), [
              '  00:00 │ boom',
              '  00:00 │ \x1B[32mok\x1B[0m',
            ]);
          });
        });

        test('colors them as errors', () {
          ggColorsEnabled = true;
          fakeAsync((async) {
            final lane = GgParallelLogLane.example()..start();
            lane.logError('boom');
            expect(render(lane)[2], contains(cError('boom')));
          });
        });
      });
    });
  });
}
