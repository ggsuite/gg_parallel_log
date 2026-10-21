# Changelog

## Unreleased

### Added

- Add `GgParallelLog`, which logs parallel processes in lanes of their own
- Show a live inline overview with a fullscreen view per lane
- Filter failed lanes, search the output, cancel lanes and save their logs
- Pipe child processes into a lane and kill them on cancel
- Leave a summary that repeats the end of every failed lane
- Fall back to lines prefixed with the lane when there is no terminal
- Run tasks with a concurrency limit via `runAll` and return a result
- Read keys from the console on Linux, macOS and Windows, keep stdin usable
- Kill the whole process tree of a cancelled lane
- Add the interactive parallel logger

### Changed

- Restructure the logger and support Linux and macOS
- Drive the live view in CI despite GITHUB_ACTIONS
