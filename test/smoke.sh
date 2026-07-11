#!/usr/bin/env bash
# smoke.sh — headless functional test for tmux-autosize.
#
# Everything runs on a PRIVATE `tmux -L` socket (never the default server) with
# TMUX_TMPDIR redirected to a scratch dir, so neither the runtime markers nor
# any tmux socket can touch a real environment. Covers:
#
#   a) core resize        — a background window forced to 80x24 under
#                           window-size manual converges to the injected client
#                           size when autosize.sh runs with an explicit TARGET_WIN.
#   b) hook install       — install preserves a pre-existing user hook AND adds
#                           ours; sourcing twice does not stack duplicates.
#   c) copy-mode safety   — with a pane in copy-mode autosize.sh defers (writes a
#                           pending marker, no resize); leaving copy-mode + flush
#                           converges the window.
#   d) teardown           — removes only our hook elements; the user hook remains.
#   e) debounce           — five near-simultaneous debounce.sh runs coalesce into
#                           exactly one core resize.
#
# Headless has no attached client, so where a real client size would come from
# we inject CLIENT_WIDTH / CLIENT_HEIGHT — the very env the client-resized hook
# supplies in production. The logic under test (target resolution, the copy-mode
# guard, debounce coalescing, non-clobbering hook install) is exercised for real.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

WORK="$(mktemp -d 2>/dev/null || mktemp -d -t autosize)"
export TMUX_TMPDIR="$WORK"
RTD="${WORK}/tmux-autosize-$(id -u)"

SOCK="autosizetest$$"
FAILS=0

cleanup() {
	tmux -L "$SOCK" kill-server 2>/dev/null || true
	rm -rf "$WORK" 2>/dev/null || true
}
trap cleanup EXIT

check() {
	# check <label> <expected> <actual>
	if [ "$2" = "$3" ]; then
		echo "  PASS: $1 (= $3)"
	else
		echo "  FAIL: $1 — expected [$2] got [$3]"
		FAILS=$((FAILS + 1))
	fi
}

contains() {
	# contains <haystack> <needle>  → echoes yes/no
	case "$1" in
		*"$2"*) echo "yes" ;;
		*) echo "no" ;;
	esac
}

file_exists() {
	[ -f "$1" ] && echo "yes" || echo "no"
}

dims() {
	# dims <window-id>  → "WxH"
	tmux -L "$SOCK" display-message -p -t "$1" '#{window_width}x#{window_height}' 2>/dev/null
}

echo "tmux version: $(tmux -L "$SOCK" -V 2>/dev/null || tmux -V 2>/dev/null || echo 'not installed')"
echo "platform: $(uname -s)"

# One session at 200x50, window-size manual so windows do NOT auto-follow — this
# is exactly the mode where background windows get stuck, and it makes the
# resize observable without an attached client.
tmux -L "$SOCK" -f /dev/null new-session -d -s main -x 200 -y 50
tmux -L "$SOCK" set-option -g window-size manual
tmux -L "$SOCK" set-option -g @autosize-debug on

# ══════════════════════ a) core resize ══════════════════════
echo "── a) autosize.sh converges a stuck background window to the client size"
tmux -L "$SOCK" new-window -d
BG=$(tmux -L "$SOCK" list-windows -F '#{window_id}' | tail -1)
tmux -L "$SOCK" resize-window -t "$BG" -x 80 -y 24 # force the stuck state
echo "     background window ${BG} forced to: $(dims "$BG")"
check "background window is stuck at 80x24" "80x24" "$(dims "$BG")"

tmux -L "$SOCK" run-shell "CLIENT_WIDTH=200 CLIENT_HEIGHT=50 TARGET_WIN=${BG} '${REPO_DIR}/scripts/autosize.sh'"
sleep 0.3
echo "     after autosize.sh (TARGET_WIN=${BG}, client 200x50): $(dims "$BG")"
check "background window converged to 200x50" "200x50" "$(dims "$BG")"

# Confirm targeting is honoured: the CURRENT window must be untouched by the
# TARGET_WIN-pinned call above.
CUR=$(tmux -L "$SOCK" display-message -p -t main:0 '#{window_id}')
tmux -L "$SOCK" resize-window -t "$CUR" -x 120 -y 40
tmux -L "$SOCK" run-shell "CLIENT_WIDTH=200 CLIENT_HEIGHT=50 TARGET_WIN=${BG} '${REPO_DIR}/scripts/autosize.sh'"
sleep 0.2
check "current window untouched by a TARGET_WIN=other call" "120x40" "$(dims "$CUR")"

# ══════════════════════ b) hook install (non-clobbering, idempotent) ══════════════════════
echo "── b) autosize.tmux appends our hooks without clobbering an existing one"
# Plant a fake user hook on client-resized FIRST.
tmux -L "$SOCK" set-hook -g client-resized 'display-message mine'
tmux -L "$SOCK" run-shell "'${REPO_DIR}/autosize.tmux'"
sleep 0.2
crh="$(tmux -L "$SOCK" show-hooks -g client-resized)"
echo "$crh" | sed 's/^/     /'
check "user's fake client-resized hook still present" "yes" "$(contains "$crh" 'display-message mine')"
check "our client-resized hook installed" "yes" "$(contains "$crh" 'AUTOSIZE_HOOK')"
check "after-new-window hook installed" "yes" \
	"$(contains "$(tmux -L "$SOCK" show-hooks -g after-new-window)" 'TARGET_WIN')"
check "pane-mode-changed (flush) hook installed" "yes" \
	"$(contains "$(tmux -L "$SOCK" show-hooks -g pane-mode-changed)" 'flush.sh')"

# Count our elements before and after a SECOND source — must not grow.
n1=$(tmux -L "$SOCK" show-hooks -g client-resized | grep -c 'AUTOSIZE_HOOK')
tmux -L "$SOCK" run-shell "'${REPO_DIR}/autosize.tmux'"
sleep 0.2
n2=$(tmux -L "$SOCK" show-hooks -g client-resized | grep -c 'AUTOSIZE_HOOK')
check "loading twice does not stack duplicates" "${n1}" "${n2}"
check "exactly one of our client-resized elements" "1" "${n2}"

# ══════════════════════ c) copy-mode safety (defer + flush) ══════════════════════
echo "── c) copy-mode defers the resize; flush converges after leaving copy-mode"
CW2=$(tmux -L "$SOCK" list-windows -F '#{window_id}' | tail -1) # reuse a window
PANE=$(tmux -L "$SOCK" list-panes -t "$CW2" -F '#{pane_id}' | head -1)
tmux -L "$SOCK" resize-window -t "$CW2" -x 80 -y 24
tmux -L "$SOCK" copy-mode -t "$PANE"
check "pane is in copy-mode" "1" "$(tmux -L "$SOCK" display-message -p -t "$PANE" '#{pane_in_mode}')"

tmux -L "$SOCK" run-shell "CLIENT_WIDTH=200 CLIENT_HEIGHT=50 TARGET_WIN=${CW2} '${REPO_DIR}/scripts/autosize.sh'"
sleep 0.3
check "resize was DEFERRED (window still 80x24)" "80x24" "$(dims "$CW2")"
check "pending marker was written" "yes" "$(file_exists "${RTD}/pending/${CW2}")"

# Leave copy-mode and flush.
tmux -L "$SOCK" send-keys -t "$PANE" -X cancel
sleep 0.1
check "pane left copy-mode" "0" "$(tmux -L "$SOCK" display-message -p -t "$PANE" '#{pane_in_mode}')"
tmux -L "$SOCK" run-shell "'${REPO_DIR}/scripts/flush.sh'"
sleep 0.3
check "flush converged the window to 200x50" "200x50" "$(dims "$CW2")"
check "pending marker was consumed" "no" "$(file_exists "${RTD}/pending/${CW2}")"

# ══════════════════════ d) teardown (removes only ours) ══════════════════════
echo "── d) teardown removes only our hook elements; user hook remains"
tmux -L "$SOCK" run-shell "'${REPO_DIR}/scripts/teardown.sh'"
sleep 0.2
crh2="$(tmux -L "$SOCK" show-hooks -g client-resized)"
echo "$crh2" | sed 's/^/     /'
check "user's fake hook survived teardown" "yes" "$(contains "$crh2" 'display-message mine')"
check "our client-resized element removed" "no" "$(contains "$crh2" 'AUTOSIZE_HOOK')"
check "after-new-window fully cleared" "no" \
	"$(contains "$(tmux -L "$SOCK" show-hooks -g after-new-window)" 'AUTOSIZE_HOOK')"
check "runtime dir removed" "no" "$([ -d "$RTD" ] && echo yes || echo no)"

# ══════════════════════ e) debounce coalescing ══════════════════════
echo "── e) five rapid debounce.sh runs coalesce into one core resize"
# Fresh runtime + a target window forced small.
tmux -L "$SOCK" set-option -g @autosize-debug on
tmux -L "$SOCK" set-option -g @autosize-debounce-ms 250
DBW=$(tmux -L "$SOCK" list-windows -F '#{window_id}' | tail -1)
tmux -L "$SOCK" resize-window -t "$DBW" -x 80 -y 24
for _ in 1 2 3 4 5; do
	tmux -L "$SOCK" run-shell -b "CLIENT_WIDTH=200 CLIENT_HEIGHT=50 TARGET_WIN=${DBW} '${REPO_DIR}/scripts/debounce.sh'"
done
# Wait comfortably past the 250ms debounce window for the single survivor to run.
sleep 1.2
resizes=$(grep -c 'resize: ' "${RTD}/autosize.log" 2>/dev/null || echo 0)
echo "     autosize.log 'resize:' lines: ${resizes}"
check "exactly one core resize ran (5 events coalesced)" "1" "${resizes}"
check "the window did converge to 200x50" "200x50" "$(dims "$DBW")"

echo ""
if [ "$FAILS" -eq 0 ]; then
	echo "ALL SMOKE CHECKS PASSED"
	exit 0
else
	echo "SMOKE FAILURES: $FAILS"
	exit 1
fi
