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

Split the interactive renderer into controller, keymap and screen
Read keys from the console instead of stdin on all platforms
Restore the terminal after crashes with a watchdog on POSIX
Add runAll, results, cancel exception and process tree killing
Run the tests on Linux, macOS and Windows in CI
