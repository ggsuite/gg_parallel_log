# Changelog

## Unreleased

### Added

- Add `GgParallelLog`, which logs parallel processes in lanes of their own
- Show a live inline overview with a fullscreen view per lane
- Filter failed lanes, search the output, cancel lanes and save their logs
- Pipe child processes into a lane and kill them on cancel
- Leave a summary that repeats the end of every failed lane
- Fall back to lines prefixed with the lane when there is no terminal
- Add the interactive parallel logger

Live inline overview, fullscreen lane view, search, error filter
Cancel lanes, save logs, pipe processes, summary with failed lanes
Plain fallback without a terminal, VT input on Windows
