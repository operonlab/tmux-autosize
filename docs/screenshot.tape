# tmux-autosize hero screenshots — recorded with vhs (https://github.com/charmbracelet/vhs)
#   cd tmux-autosize && vhs docs/screenshot.tape
#
# Produces two stills that fill the README's hero slot with a bigger, sharper
# before/after than docs/demo.gif can:
#   docs/screenshot-before.png — window-size manual, plugin NOT loaded: a
#     background window (new-window -d) is born stuck at the 80x24 default.
#   docs/screenshot-after.png  — plugin loaded: the after-new-window hook
#     resizes each new background window to the real client size on birth.
#
# Runs in a throwaway, isolated tmux server (-L shot-autosize, -f /dev/null) so
# it never touches your real tmux, and kills that server on the way out. The
# gif Output is a required vhs side effect and is thrown away under /tmp.

Output "/tmp/tmux-autosize-screenshot.gif"
Set Shell "bash"
Set FontFamily "MesloLGS Nerd Font Mono"
Set FontSize 22
Set Width 1600
Set Height 900
Set Padding 30
Set TypingSpeed 2ms

# ── hidden setup: isolated tmux server, clean prompt, manual mode ──
Hide
Type `tmux -L shot-autosize -f /dev/null new-session -d -s demo -n console 'bash --norc'`
Enter
Type `tmux -L shot-autosize attach -t demo`
Enter
Sleep 1s
Type `PS1='az> '`
Enter
Type `tmux -L shot-autosize set -g status off`
Enter
Type `eval "$(tmux -L shot-autosize display -p 'CW=#{client_width} CH=#{client_height}')"`
Enter
Type `tmux -L shot-autosize set -g window-size manual`
Enter
Type `tmux -L shot-autosize resize-window -t demo:console -x $CW -y $CH`
Enter
Type `nw() { tmux -L shot-autosize new-window -d -n "$1"; }`
Enter
Type `lw() { printf '\n    WINDOW       SIZE          STATUS\n    ─────────────────────────────────────────────────────\n'; tmux -L shot-autosize list-windows -F "    #{p13:window_name}#{p14:#{window_width}x#{window_height}}#{?#{&&:#{==:#{window_width},$CW},#{==:#{window_height},$CH}},✓  matches the client,✗  STUCK at the 80x24 default}"; printf '\n'; }`
Enter
Type "clear"
Enter
Sleep 500ms
Show

# ── BEFORE: window-size manual, a background window is born stuck ──
Type "#  BEFORE — window-size manual, tmux-autosize NOT loaded"
Enter
Type "#  a window made in the background (new-window -d) never sees a client,"
Enter
Type "#  so it is born at the 80x24 default and simply stays stuck there:"
Enter
Type "nw bg"
Enter
Sleep 400ms
Type "lw"
Enter
Sleep 300ms
Type "#  the client (this terminal) is bigger — every window should match it."
Enter
Sleep 1500ms
Screenshot "docs/screenshot-before.png"
Sleep 2s

# ── transition: drop the stuck window, load the plugin ──
Hide
Type "tmux -L shot-autosize kill-window -t demo:bg"
Enter
Type "./autosize.tmux"
Enter
Sleep 800ms
Type "clear"
Enter
Sleep 500ms
Show

# ── AFTER: same background window now converges on creation ──
Type "#  AFTER — tmux-autosize loaded"
Enter
Type "#  make another background window; the after-new-window hook resizes it"
Enter
Type "#  to the real client size the instant it is born — no manual step:"
Enter
Type "nw bg"
Enter
Sleep 1300ms
Type "lw"
Enter
Sleep 300ms
Type "#  born correct. no status line, no colors — it only fixes sizes."
Enter
Sleep 1500ms
Screenshot "docs/screenshot-after.png"
Sleep 2s

# ── teardown ──
Hide
Type "tmux -L shot-autosize kill-server"
Enter
Sleep 400ms
