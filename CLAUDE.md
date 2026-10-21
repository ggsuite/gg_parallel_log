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

## Design

- Hybrid view: the overview renders inline, so the scrollback above stays;
  only the detail view uses the alternate screen
- Calm by default: done lanes are dimmed, running ones bright, errors red,
  the selection is a single `❯`
- Every key is shown in the footer; destructive keys (`x`, `q`) ask by a
  second press instead of a dialog
- The result stays in sight: the summary lists failed lanes first and the
  result table last
- Without a TTY or on GitHub it writes lines prefixed with the lane

## Structure

- `GgParallelLog` is the facade: lanes, `run()`, `finish()`
- `GgParallelLogLane` holds the output; its `log` is a `GgLog`
- Renderers: `GgParallelLogInteractive` and `GgParallelLogPlain`
- Pure view builders: `GgParallelLogOverview`, `GgParallelLogDetail`,
  `GgParallelLogSummary`; immutable `GgParallelLogViewState`
- `GgParallelLogTerminal` abstracts the terminal; tests use
  `GgParallelLogFakeTerminal`, Windows needs VT input via FFI
  (`GgParallelLogWindowsConsole`)

## Non-goals

- No scheduler: concurrency and order belong to the caller
- No TUI framework dependency: a small ANSI renderer is enough
