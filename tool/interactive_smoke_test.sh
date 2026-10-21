#!/usr/bin/env bash

# @license
# Copyright (c) ggsuite
#
# Use of this source code is governed by terms that can be
# found in the LICENSE file in the root of this package.

# Runs the example in a real terminal (tmux), presses keys and checks what
# the screen shows. Needs tmux and dart. Usage: tool/interactive_smoke_test.sh

set -euo pipefail
cd "$(dirname "$0")/.."

session=gg_parallel_log_smoke
exe="${TMPDIR:-/tmp}/gg_parallel_log_example"
status="${TMPDIR:-/tmp}/gg_parallel_log_status"
modes="${TMPDIR:-/tmp}/gg_parallel_log_modes"
rm -f "$status" "$modes"

dart compile exe example/gg_parallel_log_example.dart -o "$exe" > /dev/null
tmux kill-session -t "$session" 2> /dev/null || true
tmux new-session -d -s "$session" -x 100 -y 30 \
  "$exe; echo \$? > $status; stty -a > $modes; sleep 60"
trap 'tmux kill-session -t "$session" 2> /dev/null || true' EXIT

screen() { tmux capture-pane -t "$session" -p; }
press() { tmux send-keys -t "$session" "$@"; }

# Waits until a line of the screen contains all given texts.
see() {
  for _ in $(seq 1 80); do
    local lines
    lines="$(screen)"
    for text in "$@"; do
      lines="$(printf '%s\n' "$lines" | grep -F -- "$text" || true)"
    done
    [ -n "$lines" ] && echo "✓ $*" && return 0
    sleep 0.25
  done
  echo "✗ Missing a line with: $*"
  screen
  exit 1
}

see 'gg do publish ·' 'done'
see '↑↓ select' 'q cancel all'
see '❯' 'gg_log'

press Down
see '❯' 'gg_console_colors'
press Enter
see 'gg_console_colors' 'lane 2/8'
see 'Esc back'
press /
see '⏎ search' 'Esc cancel'
press Escape Escape
see '↑↓ select'
press f
see 'errors only'
press f
press Up
see '❯' 'gg_log'

for _ in $(seq 1 240); do
  [ -s "$status" ] && break
  sleep 0.5
done
see '8/8 done' '1 failed'
see '✗ gg_one' 'tests failed'
# One of the simulated packages fails, so the example exits with 1.
code="$(cat "$status")"
[ "$code" = 1 ] || { echo "✗ Exit code $code"; screen; exit 1; }
echo '✓ Exited with 1'

for _ in $(seq 1 20); do [ -s "$modes" ] && break; sleep 0.25; done
for mode in icanon echo isig ixon; do
  grep -qE "(^| )$mode( |$)" "$modes" || { echo "✗ Terminal left -$mode"; exit 1; }
done
echo '✓ Terminal restored'
