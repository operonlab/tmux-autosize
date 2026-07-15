# tmux-autosize HERO screenshot — recorded with vhs (https://github.com/charmbracelet/vhs)
#   cd tmux-autosize && vhs docs/screenshot.tape   ->  docs/screenshot.png
#
# The money shot: under `window-size manual`, a background window (new-window -d)
# is born stuck at the 80x24 default. tmux-autosize's after-new-window hook
# converges every new background window to the real client size the instant it is
# born. The lw table contrasts a window made BEFORE the plugin loads (bg-before,
# ✗ stuck 80x24) with one made AFTER (bg-after, ✓ matches the client).
#
# Fully self-contained + anonymous: docs/demo-setup.sh stages the family two-row
# pill cockpit + byte-exact Starship prompt (user "dev", staged /tmp project) on
# an ISOLATED tmux server (socket az-demo) so the real tmux/config are untouched;
# teardown kills that server. The gif Output is a required vhs side effect and is
# thrown away under /tmp.

Output "/tmp/tmux-autosize-screenshot.gif"
Require tmux

Set Shell "bash"
Set FontFamily "MesloLGS Nerd Font Mono"
Set FontSize 20
Set Width 2496
Set Height 520
Set Padding 20
Set TypingSpeed 2ms

# ── hidden setup: isolated cockpit server, attach, manual mode, then stage the
#    before/after windows (bg-before born stuck while the plugin is off; load the
#    plugin; bg-after converges on birth) ──
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
Type "nw bg-before"
Enter
Sleep 500ms
Type "load-autosize"
Enter
Sleep 900ms
Type "nw bg-after"
Enter
Sleep 900ms
Type "clear"
Enter
Sleep 400ms
Show

# ── money shot: the size table contrasts bg-before (✗ 80x24) with bg-after (✓) ──
Type "# window-size manual: bg-before born stuck at 80x24; tmux-autosize converged bg-after on birth"
Enter
Sleep 300ms
Type "lw"
Enter
Sleep 1500ms
Screenshot "docs/screenshot.png"
Sleep 1s

# ── teardown: detach, kill the isolated server ──
Hide
Ctrl+B
Type "d"
Sleep 400ms
Type "tmux -L az-demo kill-server"
Enter
Sleep 500ms
