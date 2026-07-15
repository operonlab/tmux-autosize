# tmux-autosize demo — under `window-size manual`, a window made in the
# background (new-window -d) is born stuck at the 80x24 default and stays there.
# tmux-autosize's after-new-window hook converges every new background window to
# the real client size the instant it is born — no status line, no colours, it
# only fixes sizes (the real effect is shown in the pane body via lw).
# Fully self-contained: docs/demo-setup.sh stages the family two-row pill cockpit
# + byte-exact Starship prompt on an ISOLATED tmux server (socket az-demo) and
# three pane helpers (nw / lw / load-autosize). Re-record from the repo root
# with:  vhs docs/demo.tape
Output "docs/demo.gif"
Require tmux

Set Shell "bash"
Set FontFamily "MesloLGS Nerd Font Mono"
Set FontSize 20
Set Width 2496
Set Height 940
Set Padding 20
Set TypingSpeed 35ms

Hide
Type "bash docs/demo-setup.sh"
Enter
Sleep 3s
Type "clear; tmux -L az-demo attach -t demo"
Enter
Sleep 1500ms
Type "bash /tmp/vhs-autosize-demo/manual-prep.sh"
Enter
Sleep 900ms
Show

# BEFORE — window-size manual, tmux-autosize NOT loaded yet
Sleep 1000ms
Type "# window-size manual: a background window is born stuck at 80x24"
Enter
Sleep 400ms
Type "nw bg-before"
Enter
Sleep 600ms
Type "lw"
Enter
Sleep 4s

# load tmux-autosize, then make another background window
Type "# load tmux-autosize, then make another background window:"
Enter
Sleep 400ms
Type "load-autosize"
Enter
Sleep 900ms

# AFTER — the after-new-window hook converges it on creation
Type "nw bg-after"
Enter
Sleep 1000ms
Type "lw"
Enter
Sleep 4500ms

Hide
Ctrl+B
Type "d"
Sleep 500ms
Type "tmux -L az-demo kill-server"
Enter
Sleep 500ms
