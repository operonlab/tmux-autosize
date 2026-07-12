#!/usr/bin/env bash
# flush.sh — complete resizes that autosize.sh deferred because of copy-mode.
#
# When @autosize-copy-mode-safe is on, autosize.sh refuses to resize a window
# that has a pane in copy-mode (a resize forces a scrollback re-wrap — the
# cost class behind upstream freeze reports like tmux/tmux#4814) and instead
# drops a pending marker under the runtime dir:
#     <runtime>/pending/<window_id>   containing:  "<width> <height>"
#
# This script runs on the pane-mode-changed hook. For every marker whose window
# has since LEFT copy-mode, it applies the recorded size and removes the marker.
# Markers for windows still in copy-mode are kept for the next pass; markers for
# vanished windows (or ones older than an hour) are reaped.
#
# No `set -e`: tmux treats any non-zero exit from a hook script as an error.

set -uo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/helpers.sh
. "${CURRENT_DIR}/helpers.sh"

AUTOSIZE_DEBUG=$(get_tmux_option @autosize-debug off)
export AUTOSIZE_DEBUG

RD=$(autosize_runtime_dir) || exit 0
PD="${RD}/pending"
[ -d "$PD" ] || exit 0

# ── Lock so a burst of pane-mode-changed events runs one flush at a time ──
LOCK="${RD}/flush.lock.d"
if [ -d "$LOCK" ]; then
	AGE=$(($(date +%s) - $(stat_mtime "$LOCK")))
	if [ "$AGE" -gt 5 ]; then
		rmdir "$LOCK" 2>/dev/null || true
	fi
fi
mkdir "$LOCK" 2>/dev/null || exit 0
trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT INT TERM

shopt -s nullglob
for marker in "$PD"/*; do
	key=$(basename "$marker") # window id, e.g. @1

	# Reap a stale marker (>1h): its window is likely long gone.
	MAGE=$(($(date +%s) - $(stat_mtime "$marker")))
	if [ "$MAGE" -gt 3600 ]; then
		rm -f "$marker"
		autosize_log "flush reap: key=${key} age=${MAGE}s"
		continue
	fi

	# Does the window still exist, and does it still have a pane in copy-mode?
	HOT=$(tmux list-panes -t "$key" -F '#{pane_in_mode}' 2>/dev/null)
	RC=$?
	if [ "$RC" -ne 0 ]; then
		rm -f "$marker" # window gone
		autosize_log "flush drop: key=${key} (window gone rc=${RC})"
		continue
	fi
	HCNT=$(printf '%s\n' "$HOT" | grep -c '^1' || true)
	if [ "${HCNT:-0}" -gt 0 ]; then
		autosize_log "flush keep: key=${key} (still copy-mode hot=${HCNT})"
		continue # still dangerous, leave for next pass
	fi

	read -r TX TY <"$marker" 2>/dev/null || {
		rm -f "$marker"
		continue
	}
	if ! is_pos_int "${TX:-}" || ! is_pos_int "${TY:-}"; then
		rm -f "$marker"
		continue
	fi

	tmux resize-window -t "$key" -x "$TX" -y "$TY" 2>/dev/null \
		&& autosize_rebalance "$key"
	rm -f "$marker"
	autosize_log "flush resize: key=${key} size=${TX}x${TY}"
done
