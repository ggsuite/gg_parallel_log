<!-- helix:claude_md:start -->

# gg workflow

This repo is developed ticket by ticket with the `gg` CLI. Follow the
development guide, it tells you when to ask the user and which command
comes next:

@doc/guides/for-ai/ai-dev-guide.md

The steps are also available as skills: `/gg-ticket`, `/gg-commit`,
`/gg-push`, `/gg-publish`, `/gg-cleanup`. `/gg` lists them and says which
one comes next.

<!-- helix:claude_md:end -->

# Concept

## What and why

`gg_parallel_log` shows parallel processes the way the Claude Code console
does: a compact live overview of all lanes at the bottom of the terminal,
and each lane in fullscreen on demand. Goal: no error gets lost in
interleaved output, and existing `GgLog` code runs in parallel unchanged.
It must work the same on Linux, macOS and Windows.

## Design

- Hybrid view: the overview renders inline, so the scrollback above stays;
  only the detail view uses the alternate screen
- Calm by default: done lanes are dimmed, running ones bright, errors red,
  the selection is a single `❯`
- The footer lists the hints of the keymap; destructive keys (`x`, `q`)
  ask by a second press instead of a dialog
- The result stays in sight: the summary lists failed lanes first and the
  result table last
- Without a TTY or on GitHub it writes lines prefixed with the lane

## Structure

- `GgParallelLog` is the facade: `lane`, `run`, `runAll`, `finish` returns
  a `GgParallelLogResult`; cancelled runs throw
  `GgParallelLogCancelledException`
- `GgParallelLogLane` holds the output; its `log` is a `GgLog`; `pipe`
  kills the process tree via `GgParallelLogProcessTree`
- Renderers: `GgParallelLogInteractiveRenderer` (thin orchestrator) and
  `GgParallelLogPlainRenderer`
- `GgParallelLogController` is pure: view state + key → state + effects,
  driven by the declarative `GgParallelLogKeymap`; it also owns the Ctrl+C
  policy (cancel all, then abort); notices are text plus a kind, the views
  color them; `GgParallelLogViewport` holds the geometry both use
- `GgParallelLogScreen` owns all terminal output: raw mode, cursor,
  inline block, fullscreen, redraw on resize
- Pure view builders: `GgParallelLogOverview`, `GgParallelLogDetail`,
  `GgParallelLogSummary`, sharing `GgParallelLogFormat`; search results
  are cached by `GgParallelLogSearch`
- `GgParallelLogTerminal` abstracts the terminal; tests use
  `GgParallelLogFakeTerminal` and its `screen` model;
  `GgParallelLogStdioTerminal` polls keys from `GgParallelLogConsole`
  (`GgParallelLogNativeConsole`: stty + poll on POSIX with a watchdog that
  restores the terminal after a crash, console input on Windows) and never
  touches Dart's `stdin`

## Non-goals

- No dependency scheduling: `runAll` only limits the concurrency
- No TUI framework dependency: a small ANSI renderer is enough
