// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_interactive.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_saver.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_view_state.dart';
import 'package:test/test.dart';

void main() {
  late GgParallelLogFakeTerminal terminal;
  late List<GgParallelLogLane> lanes;
  late List<int> exits;
  late Directory tmp;

  setUp(() {
    ggColorsEnabled = false;
    terminal = GgParallelLogFakeTerminal(width: 60, height: 12);
    exits = [];
    tmp = Directory.systemTemp.createTempSync('gg_parallel_log_');
  });

  tearDown(() {
    ggColorsEnabled = null;
    tmp.deleteSync(recursive: true);
  });

  /// Creates a running lane a with 30 lines, a failed b and a waiting c.
  List<GgParallelLogLane> abc() {
    final a = GgParallelLogLane.example(name: 'a')..start();
    for (var i = 1; i <= 30; i++) {
      a.log('line $i');
    }
    return [
      a,
      GgParallelLogLane.example(name: 'b')..fail('boom'),
      GgParallelLogLane.example(name: 'c'),
    ];
  }

  /// Runs [body] with a started view in fake time and finishes it afterwards.
  void withView(
    void Function(GgParallelLogInteractive view, FakeAsync fake) body, {
    List<GgParallelLogLane> Function()? createLanes,
  }) {
    fakeAsync((fake) {
      lanes = (createLanes ?? abc)();
      final view = GgParallelLogInteractive(
        title: 'gg do publish',
        terminal: terminal,
        lanes: () => lanes,
        saver: GgParallelLogSaver(directory: tmp),
        exit: exits.add,
      )..start();
      body(view, fake);
      view.finish('');
      fake.flushMicrotasks();
    });
  }

  void type(List<String> keys) => keys.forEach(terminal.type);

  group('GgParallelLogInteractive', () {
    test('example() draws on a fake terminal', () {
      final view = GgParallelLogInteractive.example();
      expect(view.terminal, isA<GgParallelLogFakeTerminal>());
      expect(view.title, 'gg do publish');
      expect(view.tick, const Duration(milliseconds: 100));
      view.render();
      expect(
        (view.terminal as GgParallelLogFakeTerminal).output,
        contains('gg_log'),
      );
    });

    group('start()', () {
      test('enables the raw mode, hides the cursor and draws', () {
        withView((view, fake) {
          expect(terminal.isRawMode, isTrue);
          expect(terminal.output, startsWith('\x1B[?25l\x1B[?2026h'));
          expect(terminal.output, contains(' gg do publish · 1/3 done'));
        });
      });
    });

    group('render()', () {
      test('redraws the block in place when something changed', () {
        withView((view, fake) {
          terminal.clear();
          fake.elapse(const Duration(milliseconds: 100));
          expect(terminal.output, startsWith('\x1B[?2026h\r\x1B[4A'));
        });
      });

      test('skips the redraw when nothing changed', () {
        withView((view, fake) {
          terminal.clear();
          fake.elapse(const Duration(milliseconds: 100));
          expect(terminal.output, '');
        }, createLanes: () => [GgParallelLogLane.example()..succeed()]);
      });

      test('moves up a single row for a one line block', () {
        withView((view, fake) {
          terminal.resize(height: 1);
          view.render();
          terminal.clear();
          terminal.resize(width: 59);
          view.render();
          expect(terminal.output, startsWith('\x1B[?2026h\r'));
        });
      });

      test('counts the rows wrapped by a narrower terminal', () {
        withView((view, fake) {
          terminal.clear();
          terminal.resize(width: 30);
          view.render();
          expect(terminal.output, startsWith('\x1B[?2026h\r\x1B[6A'));
        });
      });

      test('keeps the selected lane when the order changes', () {
        withView((view, fake) {
          type(['j', 'j']);
          lanes.insert(0, GgParallelLogLane.example(name: 'd'));
          view.render();
          expect(view.state.selected, 3);
        });
      });

      test('does nothing after finish()', () {
        withView((view, fake) {
          view.finish('');
          fake.flushMicrotasks();
          terminal.clear();
          view.render();
          expect(terminal.output, '');
        });
      });
    });

    group('laneChanged()', () {
      test('waits for the next tick', () {
        withView((view, fake) {
          terminal.clear();
          view.laneChanged(lanes.first, null);
          expect(terminal.output, '');
        });
      });
    });

    group('in the overview', () {
      test('arrows, j, k, Home and End move the selection', () {
        withView((view, fake) {
          final selections = <int>[];
          for (final key in ['j', '\x1B[B', 'j', 'k', '\x1B[A', '\x1B[F']) {
            terminal.type(key);
            selections.add(view.state.selected);
          }
          terminal.type('\x1B[H');
          selections.add(view.state.selected);
          expect(selections, [1, 2, 2, 1, 0, 2, 0]);
        });
      });

      test('f lists the failed lanes only and back', () {
        withView((view, fake) {
          type(['f']);
          expect(view.state.errorsOnly, isTrue);
          expect(terminal.output, contains('errors only'));
          type(['f']);
          expect(view.state.errorsOnly, isFalse);
        });
      });

      test('Enter, l and the right arrow open the lane', () {
        withView((view, fake) {
          for (final key in ['\r', 'l', '\x1B[C']) {
            terminal.clear();
            type([key]);
            expect(view.state.mode, GgParallelLogMode.detail);
            expect(terminal.output, startsWith('\x1B[?1049h\x1B[2J'));
            type(['\x1B']);
            expect(view.state.mode, GgParallelLogMode.overview);
            expect(terminal.output, contains('\x1B[?1049l'));
          }
        });
      });

      test('Enter does nothing without lanes', () {
        withView((view, fake) {
          type(['\r', 's', 'x']);
          expect(view.state.mode, GgParallelLogMode.overview);
        }, createLanes: () => []);
      });

      test('x asks and then cancels the selected lane', () {
        withView((view, fake) {
          type(['x']);
          expect(view.state.confirm, GgParallelLogConfirm.cancelLane);
          expect(terminal.output, contains('Press x again to cancel a'));
          type(['x']);
          expect(lanes[0].isCancelled, isTrue);
          expect(view.state.notice, 'Cancelled a');
        });
      });

      test('any other key withdraws the question', () {
        withView((view, fake) {
          type(['x', 'j', 'k', 'x']);
          expect(lanes[0].isCancelled, isFalse);
        });
      });

      test('x tells when the lane is already done', () {
        withView((view, fake) {
          type(['j', 'x']);
          expect(view.state.notice, 'b is already done');
        });
      });

      test('q asks and then cancels all running lanes', () {
        withView((view, fake) {
          type(['q']);
          expect(view.state.confirm, GgParallelLogConfirm.cancelAll);
          type(['q']);
          expect(view.state.notice, 'Cancelled 2 lanes');
          expect(lanes.map((l) => l.status.name), [
            'cancelled',
            'error',
            'cancelled',
          ]);
          type(['q']);
          expect(view.state.notice, 'No running lanes');
        });
      });

      test('s saves the output of the selected lane', () {
        withView((view, fake) {
          type(['s']);
          expect(view.state.notice, startsWith('Saved a to ${tmp.path}'));
          expect(tmp.listSync(), hasLength(1));
        });
      });
    });

    group('in the detail view', () {
      test('arrows, j, k, Page Up/Down, Home, End, g and G scroll', () {
        withView((view, fake) {
          type(['\r']);
          final scrolls = <int>[];
          for (final key in [
            'k',
            '\x1B[A',
            'j',
            '\x1B[B',
            'j',
            '\x1B[5~',
            '\x1B[6~',
            '\x1B[H',
            'G',
            'g',
            '\x1B[F',
          ]) {
            terminal.type(key);
            scrolls.add(view.state.scroll);
          }
          expect(scrolls, [1, 2, 1, 0, 0, 8, 0, 22, 0, 22, 0]);
        });
      });

      test('h, l and the arrows switch the lane', () {
        withView((view, fake) {
          type(['\r', 'k']);
          final selections = <int>[];
          for (final key in ['l', '\x1B[C', 'h', '\x1B[D', '\x1B[D']) {
            terminal.type(key);
            selections.add(view.state.selected);
          }
          expect(selections, [1, 2, 1, 0, 0]);
          expect(view.state.scroll, 0);
        });
      });

      test('x and s work on the lane shown', () {
        withView((view, fake) {
          type(['\r', 'x', 'x']);
          expect(lanes[0].isCancelled, isTrue);
          type(['s']);
          expect(view.state.notice, startsWith('Saved a to '));
          expect(view.state.mode, GgParallelLogMode.detail);
        });
      });

      test('q goes back to the overview', () {
        withView((view, fake) {
          type(['\r', 'q']);
          expect(view.state.mode, GgParallelLogMode.overview);
        });
      });

      test('/ searches and n and N jump between the matches', () {
        withView((view, fake) {
          type(['\r', '/', 'line 1', '\x7F', '1', '\x1B[A']);
          expect(view.state.mode, GgParallelLogMode.search);
          expect(view.state.input, 'line 1');
          type(['\r']);
          expect(view.state.mode, GgParallelLogMode.detail);
          expect([view.state.query, view.state.match], ['line 1', 18]);
          expect(view.state.scroll, 8);
          final matches = <int>[];
          for (final key in ['n', 'N', 'N']) {
            terminal.type(key);
            matches.add(view.state.match);
          }
          expect(matches, [0, 18, 17]);
        });
      });

      test('says when the query matches nothing', () {
        withView((view, fake) {
          type(['\r', '/', 'zzz', '\r']);
          expect(view.state.notice, 'No match for "zzz"');
          expect(view.state.match, -1);
          type(['n']);
          expect(view.state.match, -1);
        });
      });

      test('an empty query clears the search', () {
        withView((view, fake) {
          type(['\r', '/', '\x7F', '\r']);
          expect([view.state.query, view.state.notice], ['', '']);
        });
      });

      test('Escape leaves the search input', () {
        withView((view, fake) {
          type(['\r', '/', 'x', '\x1B']);
          expect(view.state.mode, GgParallelLogMode.detail);
          expect(view.state.query, '');
        });
      });

      test('goes back to the overview when the lane disappears', () {
        withView((view, fake) {
          type(['\r']);
          lanes.clear();
          terminal.clear();
          view.render();
          expect(view.state.mode, GgParallelLogMode.overview);
          expect(terminal.output, startsWith('\x1B[?1049l'));
        });
      });
    });

    group('Ctrl+C', () {
      test('first cancels all lanes, then exits with 130', () {
        withView((view, fake) {
          terminal.interrupt();
          expect(lanes[0].isCancelled, isTrue);
          expect(view.state.notice, contains('Ctrl+C again to exit'));
          type(['\x03']);
          fake.flushMicrotasks();
          expect(exits, [130]);
          expect(terminal.isRawMode, isFalse);
        });
      });
    });

    group('finish(summary)', () {
      test('replaces the block by the summary and restores the terminal', () {
        withView((view, fake) {
          terminal.clear();
          view.finish('summary\n');
          fake.flushMicrotasks();
          expect(terminal.output, '\r\x1B[4A\x1B[Jsummary\n\x1B[?25h');
          expect(terminal.isRawMode, isFalse);
        });
      });

      test('leaves the fullscreen first', () {
        withView((view, fake) {
          type(['\r']);
          terminal.clear();
          view.finish('');
          fake.flushMicrotasks();
          expect(terminal.output, startsWith('\x1B[?1049l'));
        });
      });

      test('writes nothing before the first frame', () {
        fakeAsync((fake) {
          final view = GgParallelLogInteractive.example(terminal: terminal);
          view.finish('summary\n');
          fake.flushMicrotasks();
          expect(terminal.output, '\x1B[Jsummary\n\x1B[?25h');
        });
      });
    });
  });
}
