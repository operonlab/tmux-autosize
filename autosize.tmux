#!/usr/bin/env bash
# autosize.tmux — TPM entry point for tmux-autosize.
#
# Installs up to five window-size convergence hooks WITHOUT clobbering any hook
# the user (or another plugin) already set. tmux stores hooks as ARRAY options
# (since tmux 3.0), so we APPEND our command as a new array element with
# `set-hook -ga <hook> <cmd>` — every pre-existing element is preserved and runs
# in index order alongside ours.
#
# Idempotent across reloads: each command we add carries a marker (AUTOSIZE_HOOK)
# and we skip a hook that already contains it, so sourcing the plugin twice never
# stacks duplicate elements. scripts/teardown.sh removes exactly the marked
# elements, by index, and leaves the user's hooks untouched.

set -u

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/helpers.sh
. "${CURRENT_DIR}/scripts/helpers.sh"

AUTOSIZE="${CURRENT_DIR}/scripts/autosize.sh"
DEBOUNCE="${CURRENT_DIR}/scripts/debounce.sh"
FLUSH="${CURRENT_DIR}/scripts/flush.sh"

# Marker embedded in every command we install — the handle teardown/idempotency
# grep for. Independent of the install path, so renaming the plugin dir is fine.
MARK="AUTOSIZE_HOOK=1"

# install_hook <hook-name> <command>
# Append our command as a new array element unless a marked element is already
# present. Preserves every existing element (i.e. the user's own hooks).
install_hook() {
	local hook="$1" cmd="$2" cur
	cur="$(tmux show-hooks -g "$hook" 2>/dev/null)"
	case "$cur" in
		*"$MARK"*) return 0 ;; # already installed — stay idempotent
	esac
	tmux set-hook -ga "$hook" "$cmd"
}

on_attach=$(get_tmux_option @autosize-on-attach on)
on_new=$(get_tmux_option @autosize-on-new-window on)
on_select=$(get_tmux_option @autosize-on-select-window on)
copy_safe=$(get_tmux_option @autosize-copy-mode-safe on)

# client-attached: a client just attached (or a terminal that attached before it
# reached its final size). Converge the current window to the client.
if [ "$on_attach" = "on" ]; then
	install_hook client-attached \
		"run-shell -b \"${MARK} '${AUTOSIZE}'\""
fi

# client-resized: the core, always-on path. Debounced so a drag / settle burst
# resizes once. We pass the resizing client's own size + tty so a nested/SSH
# client converges to ITS size rather than a co-attached local client's.
install_hook client-resized \
	"run-shell -b \"${MARK} CLIENT_WIDTH=#{client_width} CLIENT_HEIGHT=#{client_height} CLIENT_TTY=#{client_tty} '${DEBOUNCE}'\""

# after-select-window: switching to a window that (under window-size manual) may
# be stuck at an old size — converge it to the client.
if [ "$on_select" = "on" ]; then
	install_hook after-select-window \
		"run-shell -b \"${MARK} '${AUTOSIZE}'\""
fi

# after-new-window: a freshly created window. TARGET_WIN pins the NEW window's id
# because `new-window -d` leaves current != new — an unpinned resize would
# converge the wrong window and leave the background one stuck.
if [ "$on_new" = "on" ]; then
	install_hook after-new-window \
		"run-shell -b \"${MARK} TARGET_WIN=#{window_id} '${AUTOSIZE}'\""
fi

# pane-mode-changed: completes the deferred path — when a pane leaves copy-mode,
# flush.sh converges any window autosize.sh had to skip. Only needed when the
# copy-mode guard is active.
if [ "$copy_safe" = "on" ]; then
	install_hook pane-mode-changed \
		"run-shell -b \"${MARK} '${FLUSH}'\""
fi

# A skipped final case can leave a non-zero $?; do not let that surface as a
# scary "returned 1" on every config reload.
exit 0
