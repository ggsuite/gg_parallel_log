// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_console_colors/gg_console_colors.dart';

import 'gg_parallel_log_fake_terminal.dart';
import 'gg_parallel_log_lane.dart';
import 'gg_parallel_log_line.dart';
import 'gg_parallel_log_renderer.dart';
import 'gg_parallel_log_status.dart';
import 'gg_parallel_log_terminal.dart';
import 'gg_parallel_log_text.dart';

// #############################################################################
/// Writes every line prefixed with its lane, for CI, pipes and dumb terminals.
class GgParallelLogPlainRenderer implements GgParallelLogRenderer {
  /// Creates a renderer writing to [terminal].
  GgParallelLogPlainRenderer({required this.terminal});

  /// Creates an example renderer writing to a fake terminal.
  factory GgParallelLogPlainRenderer.example({
    GgParallelLogTerminal? terminal,
  }) => GgParallelLogPlainRenderer(
    terminal: terminal ?? GgParallelLogFakeTerminal(isInteractive: false),
  );

  // ...........................................................................
  @override
  void start() {}

  // ...........................................................................
  /// Writes [line], or the new status of [lane] when [line] is null.
  ///
  /// Keeps writing after [finish], so late lines still reach the log.
  @override
  void laneChanged(GgParallelLogLane lane, GgParallelLogLine? line) {
    final prefix = darkGray('[${lane.name}]');
    if (line != null) {
      final text = line.isError ? cError(line.text) : line.text;
      terminal.write('$prefix $text\n');
      return;
    }
    switch (lane.status) {
      case GgParallelLogStatus.waiting:
        return;
      case GgParallelLogStatus.running:
        terminal.write('$prefix started\n');
      default:
        final time = GgParallelLogText.duration(lane.elapsed);
        terminal.write(
          '${lane.status.icon(0)} ${lane.name} ${lane.status.name} '
          'after $time\n',
        );
    }
  }

  // ...........................................................................
  @override
  Future<void> finish(String summary) async => terminal.write('\n$summary');

  // ...........................................................................
  /// The terminal written to.
  final GgParallelLogTerminal terminal;
}
