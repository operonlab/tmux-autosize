#!/usr/bin/env bash
# teardown.sh — cleanly remove tmux-autosize from a running server.
#
# Removes only the hook array elements this plugin installed (identified by the
# AUTOSIZE_HOOK marker), by index, leaving every other element — the user's own
# hooks — in place. Then clears the plugin options and deletes the runtime dir.
# Safe to run more than once.

set -u

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/helpers.sh
. "${CURRENT_DIR}/helpers.sh"

MARK="AUTOSIZE_HOOK=1"
HOOKS="client-attached client-resized after-select-window after-new-window pane-mode-changed"

for h in $HOOKS; do
	# show-hooks prints one line per element: "<hook>[<N>] <command...>".
	# Collect the indices of the elements carrying our marker. $1 is the
	# "<hook>[<N>]" token, so the [N] we strip out is unambiguous even if a
	# neighbouring element's command contains brackets.
	idxs=$(tmux show-hooks -g "$h" 2>/dev/null | awk -v m="$MARK" '
		index($0, m) > 0 {
			tok = $1
			sub(/^.*\[/, "", tok)
			sub(/\].*$/, "", tok)
			print tok
		}')
	# Unsetting an element does not renumber the array (a gap is left), so the
	# order we remove in does not matter and the user's indices stay stable.
	for i in $idxs; do
		tmux set-hook -gu "${h}[${i}]" 2>/dev/null || true
	done
done

# Clear plugin options (harmless if never set).
for opt in @autosize-debounce-ms @autosize-on-attach @autosize-on-new-window \
	@autosize-on-select-window @autosize-copy-mode-safe @autosize-rebalance \
	@autosize-debug; do
	tmux set-option -gu "$opt" 2>/dev/null || true
done

# Remove the per-user runtime directory (a namespaced path we own; refuse a
# symlink standing in for it).
base="${TMUX_TMPDIR:-/tmp}"
runtime="${base}/tmux-autosize-$(id -u)"
case "$runtime" in
	*/tmux-autosize-*) [ -d "$runtime" ] && [ ! -L "$runtime" ] && rm -rf "$runtime" ;;
esac

tmux display-message "tmux-autosize removed (hooks detached, runtime cleared)" 2>/dev/null || true
exit 0
