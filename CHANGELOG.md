# Changelog

All notable changes to tmux-autosize are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-07-12

### Added

- **`@autosize-rebalance`** (default `off`) — optionally re-arrange a window's
  panes right after it converges. `spread` evens the panes without changing the
  layout shape (`select-layout -E`, tmux ≥ 2.7); `even-horizontal`,
  `even-vertical`, and `tiled` apply the matching named tmux layout; `off` keeps
  the previous behaviour (tmux's own proportional pane scaling). Read fresh on
  every convergence, so it takes effect on the next resize with no
  teardown/reload. A rebalance is best-effort: any failure (or an unrecognised
  value) is logged and swallowed, never surfaced as a hook error. All supported
  values sit below the plugin's existing tmux 3.0 floor, so no version bump.
- The copy-mode defer/flush path honours `@autosize-rebalance` too: the pending
  marker still stores only the size, and `scripts/flush.sh` re-reads the current
  option value when it converges a deferred window.
- Smoke suite (`test/smoke.sh`): two new scenarios build a 3-pane unequal-width
  window and assert `even-horizontal` evens the pane widths to ≤ 1 cell while
  `off` leaves tmux's proportions intact (panes stay unequal, widest stays
  widest). The suite gained a `SMOKE_TMUX_SOCK` override so a `-L`-pinning PATH
  shim can point it at a single private socket.

## [0.1.0] - 2026-07-12

Initial release.

### Added

- Automatic window-size convergence via five tmux hooks — `client-attached`,
  `client-resized` (debounced), `after-select-window`, `after-new-window` (with
  a `TARGET_WIN` pin for background `new-window -d`), and `pane-mode-changed`
  (copy-mode flush). Each converges the affected window to the client's real
  size with an explicit `resize-window -x -y`.
- **Non-clobbering, idempotent hook install** (`autosize.tmux`): appends to
  tmux's hook **array** options (`set-hook -ga`, tmux ≥ 3.0) so pre-existing
  user/plugin hooks are preserved, and skips a hook that already carries our
  marker so a double source never stacks duplicates.
- **Copy-mode safety** (`@autosize-copy-mode-safe`): defers a resize while any
  pane is in copy-mode — writing a pending marker instead — to route around the
  upstream re-wrap spin ([tmux/tmux#4814](https://github.com/tmux/tmux/issues/4814)),
  then converges the window the moment it leaves copy-mode via `scripts/flush.sh`.
- **Debounce** (`@autosize-debounce-ms`, default `250`): a resize burst (drag /
  attach settle) coalesces into a single convergence. The survivor test is
  identity-based, so it works even where `date +%N` is unavailable.
- Options: `@autosize-debounce-ms`, `@autosize-on-attach`,
  `@autosize-on-new-window`, `@autosize-on-select-window`,
  `@autosize-copy-mode-safe`, and `@autosize-debug` (diagnostic log).
- `scripts/teardown.sh` — removes only the hook array elements this plugin
  installed (by marked index, without renumbering the user's), clears the plugin
  options, and deletes the runtime directory.
- Per-user runtime directory under `${TMUX_TMPDIR:-/tmp}/tmux-autosize-<uid>/`,
  created mode `0700` with a symlink-pre-plant guard; holds the pending-resize
  markers and the debounce state.
- CI: `shellcheck -S warning` across all shell files on two runners, plus a
  headless functional smoke suite (`test/smoke.sh`) exercising the core resize,
  non-clobbering install, copy-mode defer/flush, teardown, and debounce
  coalescing on a private `tmux -L` socket.
