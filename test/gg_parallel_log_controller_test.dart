// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_controller.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_key.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_keymap.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_view_state.dart';
import 'package:test/test.dart';

void main() {
  const overview = GgParallelLogMode.overview;
  const detail = GgParallelLogMode.detail;
  const search = GgParallelLogMode.search;
  const cancelLane = GgParallelLogConfirm.cancelLane;
  const cancelAll = GgParallelLogConfirm.cancelAll;
  const warning = GgParallelLogNoticeKind.warning;
  const cancelLaneType = GgParallelLogEffectType.cancelLane;
  const cancelAllType = GgParallelLogEffectType.cancelAll;

  const up = GgParallelLogKey(GgParallelLogKeyType.up);
  const pageUp = GgParallelLogKey(GgParallelLogKeyType.pageUp);
  const left = GgParallelLogKey(GgParallelLogKeyType.left);
  const home = GgParallelLogKey(GgParallelLogKeyType.home);
  const end = GgParallelLogKey(GgParallelLogKeyType.end);
  const enter = GgParallelLogKey(GgParallelLogKeyType.enter);
  const escape = GgParallelLogKey(GgParallelLogKeyType.escape);
  const backspace = GgParallelLogKey(GgParallelLogKeyType.backspace);
  const ctrlC = GgParallelLogKey(GgParallelLogKeyType.ctrlC);
  GgParallelLogKey char(String c) => GgParallelLogKey.printable(c);

  late GgParallelLogController controller;
  late List<GgParallelLogLane> lanes;

  setUp(() {
    ggColorsEnabled = false;
    controller = GgParallelLogController.example();
    final log = GgParallelLogLane.example()..start();
    for (var i = 0; i < 30; i++) {
      log.log(const {0, 10, 20, 28}.contains(i) ? 'Hit $i' : 'line $i');
    }
    lanes = [
      log,
      GgParallelLogLane.example(name: 'gg_args')..fail('boom'),
      GgParallelLogLane.example(name: 'gg_json')..succeed(),
      GgParallelLogLane.example(name: 'gg_is'),
      GgParallelLogLane.example(name: 'gg_test')..fail('boom'),
    ];
  });
  tearDown(() => ggColorsEnabled = null);

  // ...........................................................................
  /// Returns the keys the standard keymap binds to [action] in [mode].
  List<GgParallelLogKey> keysOf(
    GgParallelLogAction action,
    GgParallelLogMode mode,
  ) => [
    for (final binding in GgParallelLogKeymap.standard)
      if (binding.action == action && binding.modes.contains(mode))
        ...binding.keys,
  ];

  /// Returns all values of [state], so that states compare as a whole.
  Map<String, Object?> fields(GgParallelLogViewState state) => {
    'mode': state.mode,
    'selected': state.selected,
    'errorsOnly': state.errorsOnly,
    'top': state.top,
    'query': state.query,
    'input': state.input,
    'match': state.match,
    'notice': state.notice,
    'noticeKind': state.noticeKind,
    'interrupted': state.interrupted,
    'confirm': state.confirm,
  };

  /// Presses [key] in [state] on a terminal of [height] rows.
  GgParallelLogUpdate press(
    GgParallelLogViewState state,
    GgParallelLogKey key, {
    List<GgParallelLogLane>? on,
    int height = 10,
  }) => controller.handle(state, key, on ?? lanes, height: height);

  /// Expects [update] to hold [state] and [effects].
  void expectUpdate(
    GgParallelLogUpdate update,
    GgParallelLogViewState state, [
    List<GgParallelLogEffect> effects = const [],
  ]) {
    expect(fields(update.state), fields(state));
    expect(update.effects, effects);
  }

  GgParallelLogViewState state({
    GgParallelLogMode? mode,
    String? selected,
    bool? errorsOnly,
    int? top,
    String? query,
    String? input,
    int? match,
    String? notice,
    GgParallelLogNoticeKind? noticeKind,
    GgParallelLogConfirm? confirm,
    bool? interrupted,
  }) => GgParallelLogViewState.example(
    mode: mode,
    selected: selected,
    errorsOnly: errorsOnly,
    top: top,
    query: query,
    input: input,
    match: match,
    notice: notice,
    noticeKind: noticeKind,
    confirm: confirm,
    interrupted: interrupted,
  );

  group('GgParallelLogEffect', () {
    group('example()', () {
      test('saves the lane gg_log', () {
        expect(
          GgParallelLogEffect.example(),
          const GgParallelLogEffect(
            type: GgParallelLogEffectType.save,
            lane: 'gg_log',
          ),
        );
      });
    });

    group('==', () {
      test('is true for the same type and lane', () {
        expect(
          GgParallelLogEffect.example(lane: 'a') ==
              GgParallelLogEffect.example(lane: 'a'),
          isTrue,
        );
      });

      test('is false for another lane', () {
        expect(
          GgParallelLogEffect.example(lane: 'a') ==
              GgParallelLogEffect.example(lane: 'b'),
          isFalse,
        );
      });

      test('is false for another type', () {
        expect(
          const GgParallelLogEffect(type: cancelLaneType, lane: 'a') ==
              GgParallelLogEffect.example(lane: 'a'),
          isFalse,
        );
      });
    });

    group('hashCode', () {
      test('is the same for equal effects', () {
        expect(
          GgParallelLogEffect.example().hashCode,
          GgParallelLogEffect.example().hashCode,
        );
      });
    });

    group('toString()', () {
      test('names the type and the lane', () {
        expect(GgParallelLogEffect.example().toString(), 'save(gg_log)');
      });

      test('leaves the parentheses empty without a lane', () {
        expect(
          const GgParallelLogEffect(type: cancelAllType).toString(),
          'cancelAll()',
        );
      });
    });
  });

  group('GgParallelLogUpdate', () {
    group('example()', () {
      test('shows the overview without effects', () {
        final update = GgParallelLogUpdate.example();
        expect(fields(update.state), fields(const GgParallelLogViewState()));
        expect(update.effects, isEmpty);
      });
    });
  });

  group('GgParallelLogController', () {
    group('example()', () {
      test('uses the standard keymap', () {
        expect(controller.keymap.bindings, GgParallelLogKeymap.standard);
      });
    });

    group('normalize(state, lanes)', () {
      test('keeps a selection that exists', () {
        final s = state(selected: 'gg_json');
        expect(controller.normalize(s, lanes), same(s));
      });

      test('selects the first lane when none is selected', () {
        expect(
          fields(controller.normalize(const GgParallelLogViewState(), lanes)),
          fields(state(selected: 'gg_log')),
        );
      });

      test('selects the first failed lane when the filter hides it', () {
        expect(
          fields(controller.normalize(state(errorsOnly: true), lanes)),
          fields(state(errorsOnly: true, selected: 'gg_args')),
        );
      });

      test('keeps the overview when no lane is visible', () {
        final s = state();
        expect(controller.normalize(s, []), same(s));
      });

      for (final mode in [detail, search]) {
        test('falls back to the overview from ${mode.name} without lanes', () {
          expect(
            fields(controller.normalize(state(mode: mode), [])),
            fields(state()),
          );
        });
      }
    });

    group('handle(state, key, lanes, height)', () {
      group('with Ctrl+C', () {
        test('cancels all lanes the first time', () {
          expectUpdate(
            press(state(mode: search, confirm: cancelLane), ctrlC),
            state(
              mode: search,
              confirm: cancelLane,
              interrupted: true,
              notice: 'Cancelled all lanes · Ctrl+C again to exit',
              noticeKind: warning,
            ),
            [const GgParallelLogEffect(type: cancelAllType)],
          );
        });

        test('aborts the second time and keeps the state', () {
          final s = state(interrupted: true, notice: 'Hi');
          final update = press(s, ctrlC);
          expect(update.state, same(s));
          expect(update.effects, const [
            GgParallelLogEffect(type: GgParallelLogEffectType.abort),
          ]);
        });

        test('aborts after other keys in between', () {
          final first = press(state(), ctrlC).state;
          final other = press(first, char('j')).state;
          expect(press(other, ctrlC).effects, const [
            GgParallelLogEffect(type: GgParallelLogEffectType.abort),
          ]);
        });
      });

      group('with any key', () {
        test('clears the notice, its kind and a pending confirmation', () {
          expectUpdate(
            press(
              state(
                notice: 'Saved',
                noticeKind: GgParallelLogNoticeKind.error,
                confirm: cancelAll,
              ),
              char('z'),
            ),
            state(),
          );
        });

        test('selects the first lane when none is selected', () {
          expectUpdate(
            press(const GgParallelLogViewState(), char('z')),
            state(selected: 'gg_log'),
          );
        });

        test('falls back to the overview when no lane is left', () {
          expectUpdate(
            press(state(mode: detail, errorsOnly: true), up, on: [lanes[0]]),
            state(errorsOnly: true),
          );
        });

        test('reads the keys from the keymap of the controller', () {
          controller = GgParallelLogController(
            keymap: GgParallelLogKeymap.example(
              bindings: [GgParallelLogBinding.example()],
            ),
          );
          expectUpdate(press(state(), enter), state());
          expectUpdate(press(state(), char('s')), state(), [
            GgParallelLogEffect.example(),
          ]);
        });
      });

      group('with unknown keys', () {
        for (final key in [backspace, char('z'), char('ä')]) {
          test('ignores "$key" in the overview', () {
            expectUpdate(press(state(), key), state());
          });
        }

        for (final key in [backspace, enter, char('f'), char('z')]) {
          test('ignores "$key" in the detail view', () {
            expectUpdate(press(state(mode: detail), key), state(mode: detail));
          });
        }

        for (final key in [
          pageUp,
          left,
          char('b'),
          char(' '),
          char('/'),
          char('n'),
          char('N'),
        ]) {
          test('ignores the detail key "$key" in the overview', () {
            expectUpdate(press(state(), key), state());
          });
        }
      });

      group('in the overview', () {
        for (final key in keysOf(GgParallelLogAction.up, overview)) {
          test('"$key" selects the previous lane', () {
            expectUpdate(
              press(state(selected: 'gg_json'), key),
              state(selected: 'gg_args'),
            );
          });

          test('"$key" keeps the first lane selected', () {
            expectUpdate(press(state(), key), state());
          });
        }

        for (final key in keysOf(GgParallelLogAction.down, overview)) {
          test('"$key" selects the next lane', () {
            expectUpdate(
              press(state(selected: 'gg_args'), key),
              state(selected: 'gg_json'),
            );
          });

          test('"$key" keeps the last lane selected', () {
            expectUpdate(
              press(state(selected: 'gg_test'), key),
              state(selected: 'gg_test'),
            );
          });
        }

        for (final key in keysOf(GgParallelLogAction.first, overview)) {
          test('"$key" selects the first lane', () {
            expectUpdate(press(state(selected: 'gg_is'), key), state());
          });
        }

        for (final key in keysOf(GgParallelLogAction.last, overview)) {
          test('"$key" selects the last lane', () {
            expectUpdate(
              press(state(selected: 'gg_args'), key),
              state(selected: 'gg_test'),
            );
          });
        }

        test('moves among the failed lanes only while they are filtered', () {
          expectUpdate(
            press(state(errorsOnly: true, selected: 'gg_args'), char('j')),
            state(errorsOnly: true, selected: 'gg_test'),
          );
        });

        for (final key in keysOf(GgParallelLogAction.open, overview)) {
          test('"$key" opens the lane, following its end', () {
            expectUpdate(
              press(state(selected: 'gg_json', top: 3, match: 2), key),
              state(mode: detail, selected: 'gg_json'),
            );
          });
        }

        test('f lists the failed lanes only and selects the first', () {
          expectUpdate(
            press(state(), char('f')),
            state(errorsOnly: true, selected: 'gg_args'),
          );
        });

        test('f lists all lanes again and keeps the selection', () {
          expectUpdate(
            press(state(errorsOnly: true, selected: 'gg_test'), char('f')),
            state(selected: 'gg_test'),
          );
        });

        test('f keeps the selection when no lane failed', () {
          expectUpdate(
            press(state(), char('f'), on: [lanes[0]]),
            state(errorsOnly: true),
          );
        });

        test('x asks to confirm cancelling the selected lane', () {
          expectUpdate(press(state(), char('x')), state(confirm: cancelLane));
        });

        test('x again cancels the selected lane', () {
          expectUpdate(
            press(state(confirm: cancelLane), char('x')),
            state(notice: 'Cancelled gg_log', noticeKind: warning),
            [const GgParallelLogEffect(type: cancelLaneType, lane: 'gg_log')],
          );
        });

        test('x after q asks to confirm cancelling the lane', () {
          expectUpdate(
            press(state(confirm: cancelAll), char('x')),
            state(confirm: cancelLane),
          );
        });

        test('x asks again after another key', () {
          final asked = press(state(), char('x')).state;
          final other = press(asked, char('z')).state;
          expectUpdate(press(other, char('x')), state(confirm: cancelLane));
        });

        test('x does not cancel a lane that is done', () {
          expectUpdate(
            press(state(selected: 'gg_json', confirm: cancelLane), char('x')),
            state(selected: 'gg_json', notice: 'gg_json is already done'),
          );
        });

        test('q asks to confirm cancelling all running lanes', () {
          expectUpdate(press(state(), char('q')), state(confirm: cancelAll));
        });

        test('q again cancels the running and the waiting lanes', () {
          expectUpdate(
            press(state(confirm: cancelAll), char('q')),
            state(notice: 'Cancelled 2 lanes', noticeKind: warning),
            const [GgParallelLogEffect(type: cancelAllType)],
          );
        });

        test('q again names a single cancelled lane in singular', () {
          expectUpdate(
            press(state(confirm: cancelAll), char('q'), on: [lanes[0]]),
            state(notice: 'Cancelled 1 lane', noticeKind: warning),
            const [GgParallelLogEffect(type: cancelAllType)],
          );
        });

        test('q after x asks to confirm cancelling all lanes', () {
          expectUpdate(
            press(state(confirm: cancelLane), char('q')),
            state(confirm: cancelAll),
          );
        });

        test('q reports that no lane is running', () {
          expectUpdate(
            press(
              state(selected: 'gg_args'),
              char('q'),
              on: lanes.sublist(1, 3),
            ),
            state(selected: 'gg_args', notice: 'No running lanes'),
          );
        });

        test('s saves the selected lane', () {
          expectUpdate(
            press(state(selected: 'gg_is'), char('s')),
            state(selected: 'gg_is'),
            [GgParallelLogEffect.example(lane: 'gg_is')],
          );
        });
      });

      group('in the overview without lanes', () {
        const empty = GgParallelLogViewState();
        for (final action in [
          GgParallelLogAction.up,
          GgParallelLogAction.down,
          GgParallelLogAction.first,
          GgParallelLogAction.last,
          GgParallelLogAction.open,
          GgParallelLogAction.cancel,
          GgParallelLogAction.save,
        ]) {
          for (final key in keysOf(action, overview)) {
            test('"$key" (${action.name}) changes nothing', () {
              expectUpdate(press(empty, key, on: []), empty);
            });
          }
        }

        test('f toggles the filter', () {
          expectUpdate(
            press(empty, char('f'), on: []),
            const GgParallelLogViewState(errorsOnly: true),
          );
        });

        test('q reports that no lane is running', () {
          expectUpdate(
            press(empty, char('q'), on: []),
            const GgParallelLogViewState(notice: 'No running lanes'),
          );
        });
      });

      group('in the detail view', () {
        // 30 lines, 6 of them fit on 10 rows: the last page starts at 24.

        for (final key in keysOf(GgParallelLogAction.up, detail)) {
          test('"$key" scrolls up from the end', () {
            expectUpdate(
              press(state(mode: detail), key),
              state(mode: detail, top: 23),
            );
          });

          test('"$key" stops at the first line', () {
            expectUpdate(
              press(state(mode: detail, top: 0), key),
              state(mode: detail, top: 0),
            );
          });
        }

        for (final key in keysOf(GgParallelLogAction.down, detail)) {
          test('"$key" scrolls down by a line', () {
            expectUpdate(
              press(state(mode: detail, top: 22), key),
              state(mode: detail, top: 23),
            );
          });

          test('"$key" follows the output again at its end', () {
            expectUpdate(
              press(state(mode: detail, top: 23), key),
              state(mode: detail),
            );
          });

          test('"$key" keeps following the output', () {
            expectUpdate(press(state(mode: detail), key), state(mode: detail));
          });
        }

        for (final key in keysOf(GgParallelLogAction.pageUp, detail)) {
          test('"$key" scrolls up by a page', () {
            expectUpdate(
              press(state(mode: detail), key),
              state(mode: detail, top: 18),
            );
          });

          test('"$key" stops at the first line', () {
            expectUpdate(
              press(state(mode: detail, top: 3), key),
              state(mode: detail, top: 0),
            );
          });
        }

        for (final key in keysOf(GgParallelLogAction.pageDown, detail)) {
          test('"$key" scrolls down by a page', () {
            expectUpdate(
              press(state(mode: detail, top: 0), key),
              state(mode: detail, top: 6),
            );
          });

          test('"$key" follows the output at its end', () {
            expectUpdate(
              press(state(mode: detail, top: 20), key),
              state(mode: detail),
            );
          });
        }

        for (final key in keysOf(GgParallelLogAction.first, detail)) {
          test('"$key" scrolls to the first line', () {
            expectUpdate(
              press(state(mode: detail), key),
              state(mode: detail, top: 0),
            );
          });
        }

        for (final key in keysOf(GgParallelLogAction.last, detail)) {
          test('"$key" follows the output', () {
            expectUpdate(
              press(state(mode: detail, top: 5), key),
              state(mode: detail),
            );
          });
        }

        for (final key in [up, pageUp, home, char('j'), end]) {
          test('"$key" keeps following an output that fits the view', () {
            final short = GgParallelLogLane.example()
              ..log('Hit 0')
              ..log('line 1')
              ..log('line 2');
            expectUpdate(
              press(state(mode: detail), key, on: [short]),
              state(mode: detail),
            );
          });
        }

        test('keeps following when a match is in an output that fits', () {
          final short = GgParallelLogLane.example()
            ..log('Hit 0')
            ..log('line 1');
          expectUpdate(
            press(
              state(mode: detail, query: 'hit'),
              char('n'),
              on: [short],
            ),
            state(mode: detail, query: 'hit', match: 0),
          );
        });

        test('pages by the rows the terminal has', () {
          expectUpdate(
            press(state(mode: detail), pageUp, height: 14),
            state(mode: detail, top: 10),
          );
        });

        for (final key in keysOf(GgParallelLogAction.previousLane, detail)) {
          test('"$key" shows the previous lane from its end', () {
            expectUpdate(
              press(
                state(mode: detail, selected: 'gg_args', top: 4, match: 3),
                key,
              ),
              state(mode: detail),
            );
          });

          test('"$key" stays on the first lane', () {
            expectUpdate(
              press(state(mode: detail, top: 4, match: 3), key),
              state(mode: detail),
            );
          });
        }

        for (final key in keysOf(GgParallelLogAction.nextLane, detail)) {
          test('"$key" shows the next lane from its end', () {
            expectUpdate(
              press(state(mode: detail, top: 4, match: 3), key),
              state(mode: detail, selected: 'gg_args'),
            );
          });

          test('"$key" stays on the last lane', () {
            expectUpdate(
              press(state(mode: detail, selected: 'gg_test'), key),
              state(mode: detail, selected: 'gg_test'),
            );
          });
        }

        test(
          'switches among the failed lanes only while they are filtered',
          () {
            expectUpdate(
              press(
                state(mode: detail, errorsOnly: true, selected: 'gg_args'),
                char('l'),
              ),
              state(mode: detail, errorsOnly: true, selected: 'gg_test'),
            );
          },
        );

        for (final key in keysOf(GgParallelLogAction.back, detail)) {
          test('"$key" goes back to the overview', () {
            expectUpdate(
              press(state(mode: detail, top: 4), key),
              state(top: 4),
            );
          });
        }

        test('x asks to confirm cancelling the lane', () {
          expectUpdate(
            press(state(mode: detail), char('x')),
            state(mode: detail, confirm: cancelLane),
          );
        });

        test('x again cancels the lane', () {
          expectUpdate(
            press(state(mode: detail, confirm: cancelLane), char('x')),
            state(
              mode: detail,
              notice: 'Cancelled gg_log',
              noticeKind: warning,
            ),
            [const GgParallelLogEffect(type: cancelLaneType, lane: 'gg_log')],
          );
        });

        test('s saves the lane', () {
          expectUpdate(
            press(state(mode: detail), char('s')),
            state(mode: detail),
            [GgParallelLogEffect.example()],
          );
        });

        test('/ starts a new search and keeps the query', () {
          expectUpdate(
            press(state(mode: detail, query: 'hit', input: 'hix'), char('/')),
            state(mode: search, query: 'hit'),
          );
        });

        group('n', () {
          for (final (from, to, top) in [
            (null, 0, 0),
            (0, 10, 7),
            (10, 20, 17),
            (20, 28, null),
            (28, 0, 0),
          ]) {
            test('jumps from match $from to $to', () {
              expectUpdate(
                press(
                  state(mode: detail, query: 'hit', match: from),
                  char('n'),
                ),
                state(mode: detail, query: 'hit', match: to, top: top),
              );
            });
          }

          test('finds lines logged after the last jump', () {
            final s = state(mode: detail, query: 'hit', match: 20);
            final first = press(s, char('n')).state;
            lanes[0].log('Hit 30');
            expectUpdate(
              press(first, char('n')),
              state(mode: detail, query: 'hit', match: 30),
            );
          });
        });

        group('N', () {
          for (final (from, to, top) in [
            (null, 28, null),
            (28, 20, 17),
            (10, 0, 0),
            (0, 28, null),
          ]) {
            test('jumps from match $from to $to', () {
              expectUpdate(
                press(
                  state(mode: detail, query: 'hit', match: from),
                  char('N'),
                ),
                state(mode: detail, query: 'hit', match: to, top: top),
              );
            });
          }
        });

        for (final key in [char('n'), char('N')]) {
          test('"$key" does nothing without a query', () {
            expectUpdate(
              press(state(mode: detail, top: 5), key),
              state(mode: detail, top: 5),
            );
          });

          test('"$key" does nothing when nothing matches', () {
            expectUpdate(
              press(state(mode: detail, query: 'nope', top: 5), key),
              state(mode: detail, query: 'nope', top: 5),
            );
          });
        }
      });

      group('while searching', () {
        GgParallelLogViewState typing(String input, {String query = ''}) =>
            state(mode: search, input: input, query: query, top: 5, match: 3);

        test('appends a typed character', () {
          expectUpdate(press(typing('hi'), char('t')), typing('hit'));
        });

        for (final c in ['q', 'x', 's', 'f', 'n', 'N', '/', 'j', ' ', '😀']) {
          test('types "$c" instead of triggering its action', () {
            expectUpdate(press(typing('a'), char(c)), typing('a$c'));
          });
        }

        test('backspace deletes the last character', () {
          expectUpdate(press(typing('hit'), backspace), typing('hi'));
        });

        test('backspace deletes an emoji as a whole', () {
          expectUpdate(press(typing('a😀'), backspace), typing('a'));
        });

        test('backspace keeps an empty input empty', () {
          expectUpdate(press(typing(''), backspace), typing(''));
        });

        for (final key in [up, pageUp, left, home, end]) {
          test('ignores "$key"', () {
            expectUpdate(press(typing('hit'), key), typing('hit'));
          });
        }

        test('Esc returns to the detail view and keeps the query', () {
          expectUpdate(
            press(typing('hix', query: 'hit'), escape),
            state(mode: detail, input: 'hix', query: 'hit', top: 5, match: 3),
          );
        });

        test('Enter jumps to the last match and follows the end', () {
          expectUpdate(
            press(typing('hit'), enter),
            state(mode: detail, input: 'hit', query: 'hit', match: 28),
          );
        });

        test('Enter scrolls the match into the middle of the view', () {
          expectUpdate(
            press(typing('HIT 10'), enter),
            state(
              mode: detail,
              input: 'HIT 10',
              query: 'HIT 10',
              match: 10,
              top: 7,
            ),
          );
        });

        test('Enter reports a query without a match', () {
          expectUpdate(
            press(typing('nope'), enter),
            state(
              mode: detail,
              input: 'nope',
              query: 'nope',
              top: 5,
              notice: 'No match for "nope"',
              noticeKind: warning,
            ),
          );
        });

        test('Enter with an empty input clears the query', () {
          expectUpdate(
            press(typing('', query: 'hit'), enter),
            state(mode: detail, top: 5),
          );
        });
      });
    });
  });
}
