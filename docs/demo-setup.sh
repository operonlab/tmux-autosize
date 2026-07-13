#!/bin/bash
# demo-setup.sh — self-contained stage for docs/demo.tape. Builds everything the
# recording needs and starts an ISOLATED tmux server (socket: az-demo, own
# config) — your real tmux server and config are never touched.
# Anonymous by construction: identity-free prompt, no hostname in the status bar.
#
# The subject is window SIZE, not colour: under `window-size manual` a background
# window (`new-window -d`) is born stuck at 80x24. This stage keeps the visible
# console window at the client size and gives the pane two helpers — nw (make a
# background window) and lw (list every window's size vs the client) — so the
# recording can contrast a window made BEFORE the plugin loads with one made
# AFTER. The plugin itself adds no status line and no colours; the cockpit theme
# here is just the demo's shared set dressing.
set -u
SOCK=az-demo
WORK=/tmp/vhs-autosize-demo
PLUGIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMUX_BIN="${TMUX_BIN:-tmux}"

mkdir -p "$WORK"

# ── clean, anonymous shell + the size helpers (nw / lw) ──
cat > "$WORK/rc.sh" <<'RC'
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export LANG=en_US.UTF-8
PS1='\[\e[38;2;166;227;161m\] dev \[\e[0m\]❯ '
PROMPT_COMMAND=
# make a background window (no client attaches to it -> exposes the manual bug)
nw() { tmux new-window -d -n "$1"; }
# load the tmux-autosize plugin (installs the after-new-window convergence hook)
load-autosize() { tmux run-shell "$(cat /tmp/vhs-autosize-demo/plugin-path 2>/dev/null)"; }
# list every window's size and mark it against the CURRENT client size
lw() {
  eval "$(tmux display -p 'CW=#{client_width} CH=#{client_height}')"
  printf '\n    \033[1mWINDOW         SIZE           STATUS\033[0m\n'
  printf '    \033[38;2;69;71;90m─────────────────────────────────────────────────────\033[0m\n'
  tmux list-windows -F "    #{p13:window_name}#{p15:#{window_width}x#{window_height}}#{?#{&&:#{==:#{window_width},$CW},#{==:#{window_height},$CH}},✓  matches the client,✗  stuck at the 80x24 default}"
  printf '\n'
}
RC

# ── manual-mode prep (run AFTER attach: a client must exist for its size) ──
cat > "$WORK/manual-prep.sh" <<EOF
eval "\$(tmux display -p 'CW=#{client_width} CH=#{client_height}')"
tmux set -g window-size manual
tmux resize-window -t demo:console -x \$CW -y \$CH
clear
EOF

# ── record the plugin path for the pane's load-autosize helper ──
printf '%s\n' "$PLUGIN/autosize.tmux" > "$WORK/plugin-path"

# ── cockpit-style theme (catppuccin mocha, hardcoded, portable). No
#    pane-border-status: the subject lives in the pane body, and the plugin
#    itself never draws one ──
cat > "$WORK/theme.conf" <<'CONF'
set -g default-terminal "tmux-256color"
set -as terminal-overrides ",xterm-256color:Tc"
set -g mouse on
setw -g mode-keys vi
setw -g automatic-rename off
set -g escape-time 0
set -g status 2
set -g status-interval 2
set -g status-style "bg=#1E1E1E,fg=#cdd6f4"
set -g status-left '#[fg=#a6e3a1,bg=#1E1E1E]#[fg=#11111b,bg=#a6e3a1]  #[fg=#cdd6f4,bg=#313244] #S #[fg=#313244,bg=#1E1E1E] '
set -g status-left-length 30
set -g status-right '#[fg=#f5c2e7,bg=#1E1E1E]#[fg=#11111b,bg=#f5c2e7]  #[fg=#cdd6f4,bg=#313244] #W #[fg=#89dceb,bg=#313244]#[fg=#11111b,bg=#89dceb]  #[fg=#cdd6f4,bg=#313244] %H:%M #[fg=#313244,bg=#1E1E1E]'
set -g status-right-length 120
set -g 'status-format[1]' '#[align=left]#(cat /tmp/vhs-demo-row2-left 2>/dev/null)#[align=right]#(cat /tmp/vhs-demo-row2-right 2>/dev/null)'
set -g window-status-format '#[fg=#6c7086] #I:#W '
set -g window-status-current-format '#[fg=#89b4fa,bold] #I:#W '
set -g window-status-separator ''
set -g message-style 'bg=#f9e2af,fg=#11111b,bold'
CONF

# ── ambient row-2 pills (static demo values, honest set dressing) ──
pill() { printf '#[fg=%s,bg=#1E1E1E]\xee\x82\xb6#[fg=#11111b,bg=%s]%s #[fg=#cdd6f4,bg=#313244] %s #[fg=#313244,bg=#1E1E1E]\xee\x82\xb4 ' "$1" "$1" "$2" "$3"; }
{ pill '#f5c2e7' '' 'AI 5H 40%'; pill '#89b4fa' '' 'CX 5H 65%'; } > /tmp/vhs-demo-row2-left
{ pill '#a6e3a1' '' 'CPU 34%'; pill '#f9e2af' '' 'MEM 16.7/24G'; pill '#94e2d5' '' '↓17K ↑30K'; } > /tmp/vhs-demo-row2-right

# ── isolated server: a single console window. Do NOT pass -x/-y here — that
#    would set the session's window size and background windows would inherit it
#    instead of being born stuck at the 80x24 default-size (the whole premise).
#    The console is sized to the client after attach, in manual-prep.sh ──
"$TMUX_BIN" -L "$SOCK" kill-server 2>/dev/null
sleep 0.3
"$TMUX_BIN" -L "$SOCK" -f "$WORK/theme.conf" new-session -d -s demo -n console "bash --rcfile $WORK/rc.sh -i"
"$TMUX_BIN" -L "$SOCK" set -g default-command "bash --rcfile $WORK/rc.sh -i"
