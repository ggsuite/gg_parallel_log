// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_parallel_log/gg_parallel_log.dart';
import 'package:gg_parallel_log/src/gg_parallel_log_search.dart';
import 'package:gg_status_printer/gg_status_printer.dart';
import 'package:test/test.dart';

void main() {
  const cr = GgStatusPrinter.carriageReturn;
  late GgParallelLogSearch search;
  late GgParallelLogLane lane;

  // Creates a lane holding [lines].
  GgParallelLogLane laneOf(List<String> lines, {String name = 'gg_log'}) {
    final lane = GgParallelLogLane.example(name: name);
    lines.forEach(lane.log);
    return lane;
  }

  setUp(() {
    search = GgParallelLogSearch.example();
    lane = laneOf([
      'Compiling gg_log',
      '\x1B[31mERROR\x1B[0m: expected 1',
      'no error here',
      'Done ✅',
    ]);
  });

  group('GgParallelLogSearch', () {
    group('matches(lane, query)', () {
      test('returns no matches for an empty query', () {
        expect(search.matches(lane, ''), isEmpty);
      });

      test('returns the indices of the lines holding the query', () {
        expect(search.matches(lane, 'error'), [1, 2]);
      });

      test('ignores the case of the query and of the lines', () {
        expect(search.matches(lane, 'eRRoR'), [1, 2]);
      });

      test('ignores the colors of the lines', () {
        expect(
          [search.matches(lane, 'ERROR:'), search.matches(lane, '31m')],
          [
            [1],
            <int>[],
          ],
        );
      });

      test('finds umlauts and emoji', () {
        final umlauts = laneOf(['Ärger', 'ok', 'Done ✅']);
        expect(
          [search.matches(umlauts, 'ä'), search.matches(umlauts, '✅')],
          [
            [0],
            [2],
          ],
        );
      });

      test('returns no matches when no line holds the query', () {
        expect(search.matches(lane, 'warning'), isEmpty);
      });

      test('returns no matches for a lane without lines', () {
        expect(search.matches(laneOf([]), 'error'), isEmpty);
      });

      test('returns a list that cannot be changed', () {
        expect(
          () => search.matches(lane, 'error').add(3),
          throwsUnsupportedError,
        );
      });

      test('returns a copy that later searches do not change', () {
        final before = search.matches(lane, 'error');
        lane.log('error 2');
        search.matches(lane, 'error');
        expect(before, [1, 2]);
      });

      test('finds lines logged after the last search', () {
        final before = search.matches(lane, 'error').toList();
        lane
          ..log('error 2')
          ..log('fine');
        expect(
          [before, search.matches(lane, 'error')],
          [
            [1, 2],
            [1, 2, 4],
          ],
        );
      });

      test('drops a match when the last line was replaced', () {
        final progress = laneOf(['build', 'error at 10%']);
        final before = search.matches(progress, 'error').toList();
        progress.log('${cr}done');
        expect(
          [before, search.matches(progress, 'error')],
          [
            [1],
            <int>[],
          ],
        );
      });

      test('finds a match when the last line was replaced', () {
        final progress = laneOf(['build', '10%']);
        final before = search.matches(progress, 'error').toList();
        progress.log('${cr}error at 20%');
        expect(
          [before, search.matches(progress, 'error')],
          [
            <int>[],
            [1],
          ],
        );
      });

      test('checks a replaced last line followed by new lines', () {
        final progress = laneOf(['error 1', '10%']);
        search.matches(progress, 'error');
        progress
          ..log('${cr}error at 20%')
          ..log('error 3')
          ..log('${cr}done');
        expect(progress.lines.map((l) => l.text), [
          'error 1',
          'error at 20%',
          'done',
        ]);
        expect(search.matches(progress, 'error'), [0, 1]);
      });

      test('keeps the matches of a last line that is an error', () {
        final failing = laneOf(['build'])..logError('error 1');
        search.matches(failing, 'error');
        failing.log('${cr}error 2');
        expect(search.matches(failing, 'error'), [1, 2]);
      });

      test('returns the same matches when searched twice', () {
        expect(
          [search.matches(lane, 'error'), search.matches(lane, 'error')],
          [
            [1, 2],
            [1, 2],
          ],
        );
      });

      test('starts over when the query changes', () {
        expect(
          [
            search.matches(lane, 'error').toList(),
            search.matches(lane, 'done').toList(),
            search.matches(lane, 'ERROR').toList(),
          ],
          [
            [1, 2],
            [3],
            [1, 2],
          ],
        );
      });

      test('keeps the matches of each lane apart', () {
        final other = laneOf(['error', 'ok'], name: 'gg_one');
        expect(
          [
            search.matches(lane, 'error').toList(),
            search.matches(other, 'error').toList(),
            search.matches(lane, 'error').toList(),
          ],
          [
            [1, 2],
            [0],
            [1, 2],
          ],
        );
      });

      test('keeps the matches of each search apart', () {
        final other = GgParallelLogSearch.example();
        search.matches(lane, 'error');
        lane.log('error 2');
        expect(other.matches(lane, 'error'), [1, 2, 4]);
      });
    });
  });
}
