#!/usr/bin/env bash
# helpers.sh — shared option / runtime / log helpers for tmux-autosize.
#
# Meant to be sourced, not executed. It intentionally does NOT use `set -e`: it
# is pulled into scripts that tmux runs from hooks, where any non-zero exit is
# treated by tmux as an error. Failures degrade to a quiet no-op / empty output
# instead of aborting mid-hook.

# get_tmux_option <option-name> <default-value>
# Read a global tmux user option, falling back to a default when unset/empty.
get_tmux_option() {
	option_name="$1"
	default_value="$2"
	option_value=$(tmux show-option -gqv "$option_name" 2>/dev/null)
	if [ -z "$option_value" ]; then
		printf '%s' "$default_value"
	else
		printf '%s' "$option_value"
	fi
}

# autosize_runtime_dir
# Print the per-user runtime directory used for the pending-resize markers and
# the debounce state file. Created mode 0700. Refuses a pre-planted symlink
# (returns non-zero) so a hostile actor cannot redirect our writes.
autosize_runtime_dir() {
	_base="${TMUX_TMPDIR:-/tmp}"
	_dir="${_base}/tmux-autosize-$(id -u)"
	if [ ! -d "$_dir" ]; then
		# Create atomically at mode 0700 (no umask window where it is briefly
		# world-accessible). -m implies no -p, which is fine: TMUX_TMPDIR / /tmp
		# is the always-present parent and only the final component is ours.
		mkdir -m 700 "$_dir" 2>/dev/null || return 1
	fi
	# Reject a symlink standing in for the directory (anti pre-plant).
	if [ ! -d "$_dir" ] || [ -L "$_dir" ]; then
		return 1
	fi
	printf '%s' "$_dir"
}

# is_pos_int <value>  → return 0 if a non-empty run of digits, else 1.
is_pos_int() {
	case "$1" in
		'' | *[!0-9]*) return 1 ;;
		*) return 0 ;;
	esac
}

# stat_mtime <path>
# Print the file modification time as an epoch second, portably across the BSD
# stat (macOS) and GNU stat (Linux) flag dialects. Prints 0 when missing.
stat_mtime() {
	_f="$1"
	if [ ! -e "$_f" ]; then
		printf '0'
		return 0
	fi
	# Order matters. GNU/busybox stat reads `-f` as "file system" (not "format"),
	# so `stat -f %m FILE` there prints a multi-line block and exits non-zero. So
	# try GNU `-c %Y` first (empty on macOS) and only then fall back to BSD `-f %m`.
	_m=$(stat -c %Y "$_f" 2>/dev/null)
	if [ -z "$_m" ]; then
		_m=$(stat -f %m "$_f" 2>/dev/null)
	fi
	case "$_m" in
		'' | *[!0-9]*) _m=0 ;;
	esac
	printf '%s' "$_m"
}

# autosize_log <message...>
# Append a diagnostic line to the runtime log, but only when @autosize-debug is
# on (read once by the caller into AUTOSIZE_DEBUG). No-op otherwise, so the hot
# path stays silent and the log cannot grow unbounded in normal use.
autosize_log() {
	[ "${AUTOSIZE_DEBUG:-off}" = "on" ] || return 0
	_rd=$(autosize_runtime_dir) || return 0
	printf '[%s] [pid=%s] %s\n' "$(date +'%H:%M:%S')" "$$" "$*" \
		>>"${_rd}/autosize.log" 2>/dev/null || true
}
