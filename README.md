# gg_parallel_log

English | [Deutsch](README.de.md)

[![CI](https://github.com/ggsuite/gg_parallel_log/actions/workflows/quick_check.yaml/badge.svg)](https://github.com/ggsuite/gg_parallel_log/actions/workflows/quick_check.yaml)
[![pub package](https://img.shields.io/pub/v/gg_parallel_log.svg)](https://pub.dev/packages/gg_parallel_log)

Interactive CLI logger for parallel processes: inline overview, fullscreen
lane details, error filter, search, cancel and a plain fallback.

![The live overview of eight parallel lanes](doc/images/overview.png)

## Motivation

Tools like `gg` run many things at once: tests, analysis and publishing
across a dozen repositories. Written to one terminal, their output
interleaves into a wall of text, and the one line that matters, the
failure, is buried in it.

`gg_parallel_log` gives every process a lane of its own and shows them the
way the Claude Code console does:

- A compact live overview stays at the bottom of the terminal, one row per
  lane, while the scrollback above stays untouched
- Each lane opens in fullscreen with its complete output, search included
- Failed lanes are repeated at the end, so no error disappears with the
  live view
- Every lane is a plain `GgLog`, so existing code that takes a `ggLog`
  runs in parallel without a change

## Installation

```bash
dart pub add gg_parallel_log
```

## Usage

Hand `runAll` a task per lane. Each task gets its lane, whose `log` goes
wherever a `GgLog` is expected; everything a task prints ends up in its
lane as well. `runAll` lists all lanes at once, runs at most `concurrency`
of them at a time, leaves the summary and returns the result. Taken from
[example/gg_parallel_log_example.dart](example/gg_parallel_log_example.dart),
which simulates publishing eight packages:

```dart
final log = GgParallelLog(title: 'gg do publish');
final result = await log.runAll({
  for (final MapEntry(key: package, value: tests) in _packages.entries)
    package: (lane) => _publish(lane, tests),
}, concurrency: 3);
exitCode = result.exitCode;
```

For full control, create lanes with `log.lane(name)`, run tasks with
`log.run(name, task)` and call `log.finish()` in a `finally`. `run` throws
what the task throws, or a `GgParallelLogCancelledException` as soon as
the user cancels the lane. A lane logs a child process with
`await lane.pipe(process)` and kills the whole process tree on cancel.

### Keys

| Where | Key | Does |
| --- | --- | --- |
| Overview | `↑` `↓` / `k` `j` | Select a lane |
| Overview | `⏎` / `→` | Open the lane in fullscreen |
| Overview | `f` | Show failed lanes only, or all again |
| Overview | `q` `q` | Cancel all running lanes |
| Both | `x` `x` | Cancel the selected lane |
| Both | `s` | Save the output of the lane to a file |
| Fullscreen | `↑` `↓` / `k` `j` | Scroll by a line |
| Fullscreen | `b` `Space` / `PgUp` `PgDn` | Scroll by a page |
| Fullscreen | `g` `G` / `Home` `End` | Jump to the top, follow the end |
| Fullscreen | `←` `→` | Switch to the previous or next lane |
| Fullscreen | `/` `n` `N` | Search, jump to the next or previous match |
| Fullscreen | `Esc` | Back to the overview |
| Anywhere | `Ctrl+C` | Cancel all lanes; a second time exits with 130 |

![A failed lane in fullscreen with a search](doc/images/detail_search.png)

When all lanes are done, the live view gives way to a summary. Failed
lanes come first with their last 40 lines and the path of the full log,
the result table comes last:

![The summary after all lanes are done](doc/images/summary.png)

Without a terminal, e.g. on CI or in a pipe, the log writes each line
prefixed with its lane, followed by the same summary.

## Platforms

The live view runs on Linux, macOS and Windows. Keys are read straight
from the console (`poll` on POSIX, the console input on Windows), so
Dart's `stdin` stays untouched and a program can still ask the user
afterwards. While the view is open, `Ctrl+C`, `Ctrl+Z` and `Ctrl+S` arrive
as keys instead of signals, so child processes are not hit by them. The
terminal state is saved with `stty -g` and restored on `finish`, on
`SIGTERM` and on `SIGHUP`; should the program crash, a small watchdog
process restores it on POSIX, and Dart does so on Windows. CI runs the tests on all three systems and
drives the live view in tmux on Linux and macOS
([tool/interactive_smoke_test.sh](tool/interactive_smoke_test.sh)).

## Limitations

- Cancelling is cooperative for tasks: `run` returns at once, but a task
  keeps running until it checks `lane.isCancelled`; piped processes are
  killed with their whole tree
- Output written directly to stdout, e.g. by a child process started with
  `inheritStdio`, bypasses the lanes and breaks the view; pipe it into a
  lane instead
- Widths come from a built-in table: rare emoji and terminals that draw
  ambiguous characters wide may be off by a column
- The output is UTF-8; a terminal with another encoding shows the
  symbols garbled
- GNU screen without `altscreen on` cannot show the fullscreen view
  cleanly

## Documentation

- [Code guide](doc/guides/code-guide.md)
- [Test guide](doc/guides/test-guide.md)
- [Development guide](doc/guides/develop-guide.md)

## Status

Before 1.0, the API may change between minor versions.

## Contributing

Follow the [development guide](doc/guides/develop-guide.md).

## License

MIT, see [LICENSE](LICENSE).
