// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_controller.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_interactive_renderer.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_key.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_keymap.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_saver.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_view_state.dart';
import 'package:path/path.dart' show join;
import 'package:test/test.dart';

void main() {
  const width = 120;
  const w = width - 1;
  late GgParallelLogFakeTerminal terminal;
  late List<int> aborts;
  late Directory tmp;

  setUp(() {
    ggColorsEnabled = false;
    terminal = GgParallelLogFakeTerminal.example(width: width, height: 8);
    aborts = [];
    tmp = Directory.systemTemp.createTempSync('gg_parallel_log_');
  });

  tearDown(() {
    ggColorsEnabled = null;
    tmp.deleteSync(recursive: true);
  });

  // ...........................................................................
  /// Creates and starts a renderer of [lanes] on the terminal.
  GgParallelLogInteractiveRenderer start(
    List<GgParallelLogLane> lanes, {
    GgParallelLogSaver? saver,
    void Function(int code)? onAbort,
  }) => GgParallelLogInteractiveRenderer.example(
    terminal: terminal,
    lanes: lanes,
    saver: saver,
    onAbort: onAbort ?? aborts.add,
  )..start();

  /// Creates the lanes a, running with two lines, and b, waiting.
  List<GgParallelLogLane> twoLanes() => [
    GgParallelLogLane.example(name: 'a')
      ..start()
      ..log('alpha')
      ..log('beta'),
    GgParallelLogLane.example(name: 'b'),
  ];

  /// Returns an overview row as the terminal shows it.
  String row(
    String name, {
    bool selected = false,
    String icon = '○',
    String time = '',
    String text = 'waiting',
  }) =>
      '${selected ? '❯' : ' '} $icon ${name.padRight(4)}  '
      '${time.padLeft(5)}  $text';

  /// Returns the header of the overview.
  String header(String counts) => ' gg do publish · $counts · 00:00';

  final overviewHints =
      ' ${const GgParallelLogKeymap().hints(GgParallelLogMode.overview)}';
  final detailHints =
      ' ${const GgParallelLogKeymap().hints(GgParallelLogMode.detail)}';

  /// Returns [left] and [right] spread over a detail line.
  String spread(String left, String right) =>
      '$left${' ' * (w - left.length - right.length)}$right';

  /// Returns the position rule of the detail view showing [info].
  String rule(String info) => '──$info'.padRight(w, '─');

  /// Returns the detail view of lane a of [twoLanes] with [footer].
  List<String> detailOfA({
    String footer = '',
    String prefix = '  ',
    String position = ' 1–2 of 2 · following ',
  }) => [
    spread(' ⠋ a  running · 00:00', 'lane 1/2'),
    '─' * w,
    '  00:00 │ alpha',
    '${prefix}00:00 │ beta',
    '',
    '',
    rule(position),
    footer.isEmpty ? detailHints : footer,
  ];

  /// Returns the overview of [twoLanes] at spinner frame [spinner].
  List<String> overviewOfTwo({
    String? footer,
    bool bSelected = false,
    String spinner = '⠋',
  }) => [
    header('0/2 done'),
    row('a', selected: !bSelected, icon: spinner, time: '00:00', text: 'beta'),
    row('b', selected: bSelected),
    footer ?? overviewHints,
  ];

  group('GgParallelLogInteractiveRenderer', () {
    group('example()', () {
      test('draws on a fake terminal with the standard parts', () {
        final renderer = GgParallelLogInteractiveRenderer.example();
        expect(renderer.title, 'gg do publish');
        expect(renderer.terminal, isA<GgParallelLogFakeTerminal>());
        expect(renderer.tick, const Duration(milliseconds: 100));
        expect(
          renderer.saver.directory.path,
          join(Directory.systemTemp.path, 'gg_parallel_log'),
        );
        expect(renderer.controller, isA<GgParallelLogController>());
        expect(renderer.state.mode, GgParallelLogMode.overview);
      });

      test('ignores a termination', () {
        fakeAsync((fake) {
          final renderer = GgParallelLogInteractiveRenderer.example(
            terminal: terminal,
          )..start();
          terminal.terminate();
          expect(renderer.state.mode, GgParallelLogMode.overview);
          expect(terminal.isRawMode, isTrue);
        });
      });
    });

    group('start()', () {
      test('switches into raw mode and draws the overview inline', () {
        fakeAsync((fake) {
          terminal.write('before\n');
          start(twoLanes());
          expect(terminal.isRawMode, isTrue);
          expect(terminal.screen, ['before', ...overviewOfTwo()]);
        });
      });

      test('throws with the terminal untouched when input is taken', () {
        fakeAsync((fake) {
          terminal = GgParallelLogFakeTerminal.example(inputTaken: true);
          expect(
            () => start(twoLanes()),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                'Stream has already been listened to.',
              ),
            ),
          );
          fake.elapse(const Duration(seconds: 1));
          expect(terminal.isRawMode, isFalse);
          expect(terminal.output, '');
        });
      });

      test('redraws on every tick', () {
        fakeAsync((fake) {
          final lanes = twoLanes();
          start(lanes);
          lanes[1]
            ..start()
            ..log('compiling');
          expect(terminal.screen, overviewOfTwo());
          fake.elapse(const Duration(milliseconds: 100));
          expect(terminal.screen, [
            header('0/2 done'),
            row('a', selected: true, icon: '⠙', time: '00:00', text: 'beta'),
            row('b', icon: '⠙', time: '00:00', text: 'compiling'),
            overviewHints,
          ]);
        });
      });

      group('keys', () {
        test('select the next lane with an arrow key', () {
          fakeAsync((fake) {
            start(twoLanes());
            terminal.type('\x1B[B');
            expect(terminal.screen, overviewOfTwo(bSelected: true));
          });
        });

        test('join an escape sequence split across two reads', () {
          fakeAsync((fake) {
            final renderer = start(twoLanes());
            terminal.type('\x1B');
            fake.elapse(const Duration(milliseconds: 49));
            terminal.type('[B');
            fake.elapse(const Duration(milliseconds: 50));
            expect(renderer.state.selected, 'b');
            expect(renderer.state.mode, GgParallelLogMode.overview);
            expect(terminal.screen, overviewOfTwo(bSelected: true));
          });
        });

        test('read a lone Escape after 50 ms', () {
          fakeAsync((fake) {
            final renderer = start(twoLanes());
            terminal
              ..type('\r')
              ..type('\x1B');
            fake.elapse(const Duration(milliseconds: 49));
            expect(renderer.state.mode, GgParallelLogMode.detail);
            fake.elapse(const Duration(milliseconds: 1));
            expect(renderer.state.mode, GgParallelLogMode.overview);
            expect(terminal.screen, overviewOfTwo());
          });
        });

        test('open the selected lane in fullscreen', () {
          fakeAsync((fake) {
            terminal.write('before\n');
            start(twoLanes());
            terminal.type('\r');
            expect(terminal.screen, detailOfA());
            terminal.type('q');
            expect(terminal.screen, ['before', ...overviewOfTwo()]);
          });
        });

        test('drop the rest of a pasted chunk after a confirmed search', () {
          fakeAsync((fake) {
            final renderer = start(twoLanes());
            terminal
              ..type('\r')
              ..type('/beta\rq');
            expect(renderer.state.mode, GgParallelLogMode.detail);
            expect(
              terminal.screen,
              detailOfA(
                footer: ' "beta" 1/1 ·$detailHints',
                prefix: '❯ ',
                position: ' 1–2 of 2 · following ',
              ),
            );
          });
        });
      });

      group('effects', () {
        test('cancel the selected lane on a second x', () {
          fakeAsync((fake) {
            final lanes = twoLanes();
            start(lanes);
            terminal.type('x');
            expect(
              terminal.screen,
              overviewOfTwo(footer: ' Press x again to cancel a'),
            );
            terminal.type('x');
            expect(lanes[0].status, GgParallelLogStatus.cancelled);
            expect(terminal.screen, [
              header('1/2 done · 1 cancelled'),
              row(
                'a',
                selected: true,
                icon: '⊘',
                time: '00:00',
                text: 'cancelled',
              ),
              row('b'),
              ' Cancelled a',
            ]);
          });
        });

        test('cancel all lanes on a second q', () {
          fakeAsync((fake) {
            final lanes = twoLanes();
            start(lanes);
            terminal.type('qq');
            expect(lanes.map((l) => l.status), [
              GgParallelLogStatus.cancelled,
              GgParallelLogStatus.cancelled,
            ]);
            expect(terminal.screen.last, ' Cancelled 2 lanes');
          });
        });

        test('save the selected lane and tell where', () {
          fakeAsync((fake) {
            terminal = GgParallelLogFakeTerminal.example(width: 300);
            final saver = GgParallelLogSaver.example(
              directory: Directory(join(tmp.path, 'logs')),
            );
            start(twoLanes(), saver: saver);
            terminal.type('s');
            final files = saver.directory.listSync();
            expect(files, hasLength(1));
            final file = files.single as File;
            expect(file.readAsStringSync(), '00:00 alpha\n00:00 beta\n');
            expect(
              terminal.screen,
              overviewOfTwo(footer: ' Saved a to ${file.path}'),
            );
          });
        });

        test('ignore effects on lanes that are gone', () {
          fakeAsync((fake) {
            final lanes = twoLanes();
            final renderer = GgParallelLogInteractiveRenderer(
              title: 'gg do publish',
              terminal: terminal,
              lanes: () => lanes,
              onAbort: aborts.add,
              controller: _GhostController(),
              saver: GgParallelLogSaver.example(directory: tmp),
            )..start();
            terminal.type('s');
            expect(renderer.state.notice, '');
            expect(tmp.listSync(), isEmpty);
            expect(lanes.map((l) => l.status), [
              GgParallelLogStatus.running,
              GgParallelLogStatus.waiting,
            ]);
            expect(terminal.screen, overviewOfTwo());
          });
        });
        test('show an error instead of crashing when saving fails', () {
          fakeAsync((fake) {
            final blocker = File(join(tmp.path, 'blocker'))
              ..writeAsStringSync('');
            final saver = GgParallelLogSaver.example(
              directory: Directory(blocker.path),
            );
            final renderer = start(twoLanes(), saver: saver);
            terminal.type('s');
            expect(renderer.state.noticeKind, GgParallelLogNoticeKind.error);
            fake.elapse(const Duration(milliseconds: 100));
            expect(
              terminal.screen,
              equals([
                ...overviewOfTwo(spinner: '⠙').take(3),
                matches(RegExp(r'^ Error: \w*Exception: Creation failed')),
              ]),
            );
            expect(terminal.isRawMode, isTrue);
            terminal.type('j');
            expect(
              terminal.screen,
              overviewOfTwo(bSelected: true, spinner: '⠙'),
            );
          });
        });
      });

      group('Ctrl+C', () {
        for (final (via, press) in [
          ('key', () => terminal.type('\x03')),
          ('signal', () => terminal.interrupt()),
        ]) {
          test('as $via cancels all lanes first and aborts then', () {
            fakeAsync((fake) {
              final lanes = twoLanes();
              final renderer = start(lanes);
              press();
              expect(aborts, isEmpty);
              expect(renderer.state.interrupted, isTrue);
              expect(terminal.screen, [
                header('2/2 done · 2 cancelled'),
                row(
                  'a',
                  selected: true,
                  icon: '⊘',
                  time: '00:00',
                  text: 'cancelled',
                ),
                row('b', icon: '⊘', time: '00:00', text: 'cancelled'),
                ' Cancelled all lanes · Ctrl+C again to exit',
              ]);
              press();
              expect(aborts, [130]);
            });
          });
        }

        test('shows an error when aborting fails', () {
          fakeAsync((fake) {
            start(twoLanes(), onAbort: (_) => throw StateError('no exit'));
            terminal
              ..interrupt()
              ..interrupt();
            fake.elapse(const Duration(milliseconds: 100));
            expect(terminal.screen.last, ' Error: Bad state: no exit');
            expect(terminal.isRawMode, isTrue);
          });
        });
      });

      group('termination', () {
        test('aborts with the code of the signal', () {
          fakeAsync((fake) {
            start(twoLanes());
            terminal.terminate(143);
            expect(aborts, [143]);
          });
        });

        test('shows the first line of an error when aborting fails', () {
          fakeAsync((fake) {
            final renderer = start(
              twoLanes(),
              onAbort: (_) => throw StateError('no exit\nat line 2'),
            );
            terminal.terminate();
            fake.elapse(const Duration(milliseconds: 100));
            expect(
              renderer.state.notice,
              'Error: Bad state: no exit\nat line 2',
            );
            expect(terminal.screen, [
              ...overviewOfTwo(spinner: '⠙').take(3),
              ' Error: Bad state: no exit',
            ]);
            expect(terminal.isRawMode, isTrue);
          });
        });
      });
    });

    group('laneChanged(lane, line)', () {
      test('leaves drawing to the next tick', () {
        fakeAsync((fake) {
          final lanes = twoLanes();
          final renderer = start(lanes);
          terminal.clear();
          renderer.laneChanged(lanes[0], null);
          expect(terminal.output, '');
        });
      });
    });

    group('render()', () {
      test('shows an error of a tick instead of crashing', () {
        fakeAsync((fake) {
          final lanes = twoLanes();
          var broken = false;
          final renderer = GgParallelLogInteractiveRenderer(
            title: 'gg do publish',
            terminal: terminal,
            lanes: () => broken ? throw StateError('no lanes') : lanes,
            onAbort: aborts.add,
          )..start();
          broken = true;
          fake.elapse(const Duration(milliseconds: 100));
          expect(renderer.state.notice, 'Error: Bad state: no lanes');
          broken = false;
          fake.elapse(const Duration(milliseconds: 100));
          expect(terminal.screen, [
            header('0/2 done'),
            row('a', selected: true, icon: '⠹', time: '00:00', text: 'beta'),
            row('b'),
            ' Error: Bad state: no lanes',
          ]);
        });
      });
      test('does nothing before start', () {
        GgParallelLogInteractiveRenderer.example(terminal: terminal).render();
        expect(terminal.output, '');
      });

      test('returns to the overview when no lane is left to show', () {
        fakeAsync((fake) {
          final lanes = twoLanes();
          final renderer = start(lanes);
          terminal.type('\r');
          lanes.clear();
          renderer.render();
          expect(renderer.state.mode, GgParallelLogMode.overview);
          expect(terminal.screen, [
            header('0/0 done'),
            '   No lanes',
            overviewHints,
          ]);
        });
      });
    });

    group('finish(summary)', () {
      test('leaves the summary and restores the terminal', () {
        fakeAsync((fake) {
          terminal.write('before\n');
          final renderer = start(twoLanes());
          terminal.type('\r');
          renderer.finish('summary\n');
          fake.flushMicrotasks();
          expect(terminal.screen, ['before', 'summary']);
          expect(terminal.isRawMode, isFalse);
          expect(terminal.output, endsWith('summary\n\x1B[?25h'));
        });
      });

      test('stops redrawing and reading keys', () {
        fakeAsync((fake) {
          final renderer = start(twoLanes());
          terminal.type('\x1B');
          renderer.finish('summary\n');
          fake.flushMicrotasks();
          terminal
            ..clear()
            ..type('j')
            ..interrupt()
            ..terminate();
          fake.elapse(const Duration(seconds: 1));
          expect(terminal.output, '');
          expect(aborts, isEmpty);
        });
      });
    });
  });
}

// #############################################################################
/// Asks to save and cancel a lane that does not exist.
class _GhostController extends GgParallelLogController {
  @override
  GgParallelLogUpdate handle(
    GgParallelLogViewState state,
    GgParallelLogKey key,
    List<GgParallelLogLane> lanes, {
    int height = 24,
  }) => GgParallelLogUpdate(
    state,
    effects: const [
      GgParallelLogEffect(type: GgParallelLogEffectType.save, lane: 'ghost'),
      GgParallelLogEffect(
        type: GgParallelLogEffectType.cancelLane,
        lane: 'ghost',
      ),
    ],
  );
}
