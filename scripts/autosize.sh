#!/usr/bin/env bash
# autosize.sh — converge ONE window to the attached client's size.
#
# This is the core resize. It resolves a target window (an explicit TARGET_WIN,
# else the current window), reads the client size (from the CLIENT_WIDTH /
# CLIENT_HEIGHT the hooks pass in, else by querying the attached client), and
# resizes the window to match with an explicit `resize-window -x <w> -y <h>`.
#
# Why explicit -x/-y and not `resize-window -A`: on this plugin's tested tmux
# (next-3.8) `-A` (adjust toward the client) is a no-op for a background window
# that is stuck at the wrong size; only explicit target dimensions converge it.
#
# Copy-mode safety (@autosize-copy-mode-safe on): resizing a window forces
# tmux to re-wrap its scrollback; with a large history that reflow is expensive
# enough to freeze the server (upstream tmux/tmux#4814 documents a freeze of
# this class, triggered by drag-resize + very large history). A pane sitting in
# copy-mode is actively holding scrollback state, so we take the conservative
# path and DEFER: record the wanted size in a pending marker and let
# scripts/flush.sh converge the window the moment it leaves copy-mode.
#
# No `set -e`: tmux treats any non-zero exit from a hook script as an error.

set -uo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/helpers.sh
. "${CURRENT_DIR}/helpers.sh"

AUTOSIZE_DEBUG=$(get_tmux_option @autosize-debug off)
export AUTOSIZE_DEBUG
COPY_SAFE=$(get_tmux_option @autosize-copy-mode-safe on)

# ── Target window ─────────────────────────────────────────────────────────
# TARGET_WIN is the event window id (#{window_id}) the after-new-window hook
# passes in. `new-window -d` makes current != new, so without an explicit
# target we would converge the wrong (foreground) window and leave the new
# background one stuck. When unset (attach / select-window / resize / manual)
# it means "the current window".
TARGET="${TARGET_WIN:-}"
if [ -z "$TARGET" ]; then
	TARGET=$(tmux display-message -p '#{window_id}' 2>/dev/null)
fi
if [ -z "$TARGET" ]; then
	autosize_log "skip: no target window"
	exit 0
fi

# ── Client size ───────────────────────────────────────────────────────────
# The hooks hand us the resizing client's own width/height so a nested / SSH
# client converges to ITS size, not a larger co-attached local client. When not
# provided, ask the client attached to the target's session. With no client
# attached there is nothing to converge to — a deliberate no-op.
CW="${CLIENT_WIDTH:-}"
CH="${CLIENT_HEIGHT:-}"
if ! is_pos_int "$CW" || ! is_pos_int "$CH"; then
	CW=$(tmux display-message -p -t "$TARGET" '#{client_width}' 2>/dev/null)
	CH=$(tmux display-message -p -t "$TARGET" '#{client_height}' 2>/dev/null)
fi
if ! is_pos_int "$CW" || ! is_pos_int "$CH"; then
	autosize_log "skip: no client size (cw='${CW}' ch='${CH}') target=${TARGET}"
	exit 0
fi
# Guard against nonsense (a transient 0/1 mid-teardown). A real terminal is
# never this small; converging to it would just create a different stuck state.
if [ "$CW" -lt 20 ] || [ "$CH" -lt 5 ]; then
	autosize_log "skip: client too small ${CW}x${CH} target=${TARGET}"
	exit 0
fi

# ── Copy-mode guard ───────────────────────────────────────────────────────
if [ "$COPY_SAFE" = "on" ]; then
	HOT=$(tmux list-panes -t "$TARGET" -F '#{pane_in_mode}' 2>/dev/null \
		| grep -c '^1' || true)
	if [ "${HOT:-0}" -gt 0 ]; then
		RD=$(autosize_runtime_dir) || exit 0
		PD="${RD}/pending"
		# RD already exists at 0700 (autosize_runtime_dir made it); only the
		# final component is ours, so no -p is needed (and it keeps mode 0700).
		mkdir -m 700 "$PD" 2>/dev/null || true
		# Key the marker by window id (stable, unique, a valid tmux target).
		printf '%s %s\n' "$CW" "$CH" >"${PD}/${TARGET}" 2>/dev/null || true
		autosize_log "defer: copy-mode hot=${HOT} target=${TARGET} size=${CW}x${CH}"
		exit 0
	fi
fi

# ── Safe: converge now ────────────────────────────────────────────────────
# Drop any stale pending marker first (we are resizing this window for real).
RD=$(autosize_runtime_dir) && rm -f "${RD}/pending/${TARGET}" 2>/dev/null
tmux resize-window -t "$TARGET" -x "$CW" -y "$CH" 2>/dev/null \
	&& autosize_rebalance "$TARGET"
autosize_log "resize: target=${TARGET} size=${CW}x${CH}"
