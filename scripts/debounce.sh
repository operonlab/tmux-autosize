#!/usr/bin/env bash
# debounce.sh — client-resized debounce wrapper.
#
# tmux can emit a burst of client-resized events while a terminal window is
# being dragged, or while a client settles right after attach. Converging the
# window on every intermediate size wastes work and can briefly lock a window
# to a mid-drag value. This wrapper waits @autosize-debounce-ms (default 250)
# of quiet before delegating to autosize.sh — only the LAST event in a burst
# actually resizes.
#
# It is fully detached (the hook runs it with `run-shell -b`), so the sleep
# never blocks tmux's event loop.
#
# Survivor test is identity-based, not clock-based: each invocation writes a
# unique token to the shared state file, then sleeps; after the sleep, only the
# instance whose token still stands (i.e. no newer event overwrote it) proceeds.
# This is robust even where `date +%N` is unavailable (stock BSD/macOS).
#
# No `set -e`: tmux treats any non-zero exit from a hook script as an error.

set -uo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/helpers.sh
. "${CURRENT_DIR}/helpers.sh"

# Propagate the resizing client's context to autosize.sh.
export CLIENT_WIDTH="${CLIENT_WIDTH:-}"
export CLIENT_HEIGHT="${CLIENT_HEIGHT:-}"
export CLIENT_TTY="${CLIENT_TTY:-}"
export TARGET_WIN="${TARGET_WIN:-}"

MS=$(get_tmux_option @autosize-debounce-ms 250)
case "$MS" in
	'' | *[!0-9]*) MS=250 ;;
esac

RD=$(autosize_runtime_dir) || exit 0
TS_FILE="${RD}/debounce.ts"

# Unique per-process token (PID is unique among concurrent instances; RANDOM
# guards the unlikely PID reuse within one debounce window).
TOKEN="$$-${RANDOM}"
echo "$TOKEN" >"$TS_FILE" 2>/dev/null || exit 0

# Sleep MS milliseconds. awk renders the fractional seconds portably.
sleep "$(awk "BEGIN{printf \"%.3f\", ${MS}/1000}")" 2>/dev/null || true

CUR=$(cat "$TS_FILE" 2>/dev/null || echo "")
if [ "$CUR" != "$TOKEN" ]; then
	# A newer resize event overwrote our token — that instance will do the work.
	exit 0
fi

exec "${CURRENT_DIR}/autosize.sh"
