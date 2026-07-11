# Changelog

All notable changes to tmux-autosize are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
