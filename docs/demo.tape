# tmux-autosize demo — recorded with vhs (https://github.com/charmbracelet/vhs)
#   cd tmux-autosize && vhs docs/demo.tape
#
# Runs in a throwaway, isolated tmux server (-L vhsdemo-autosize,
# -f /dev/null) so it never touches your real tmux. Under `window-size
# manual` a background window (`new-window -d`) is born stuck at 80x24. The
# recording contrasts one made before the plugin loads (stays 80x24) with
# one made after — its after-new-window hook converges it to the client size.
#
# The hidden setup restores the console window to the client size after
# switching to manual (manual mode would otherwise shrink it too); the
# subject of the demo is the background windows.

Output "docs/demo.gif"
Set Shell "bash"
Set FontSize 15
Set Width 1200
Set Height 660
Set Padding 12
Set TypingSpeed 45ms

Hide
Type `tmux -L vhsdemo-autosize -f /dev/null new-session -d -s demo -n console 'bash --norc -i'`
Enter
Type `tmux -L vhsdemo-autosize attach -t demo`
Enter
Sleep 800ms
Type `PS1='az> '`
Enter
Type `tmux -L vhsdemo-autosize set -g status-right ''`
Enter
Type `alias lw="tmux -L vhsdemo-autosize list-windows -F '  #I #{window_name}: #{window_width}x#{window_height}'"`
Enter
Type `eval "$(tmux -L vhsdemo-autosize display -p 'CW=#{client_width} CH=#{client_height}')"`
Enter
Type `tmux -L vhsdemo-autosize set -g window-size manual`
Enter
Type `tmux -L vhsdemo-autosize resize-window -t demo:console -x $CW -y $CH`
Enter
Type "clear"
Enter
Sleep 400ms
Show
Type "# window-size manual: a window made in the background is born stuck at 80x24"
Enter
Type `tmux -L vhsdemo-autosize new-window -d -n bg-before`
Enter
Sleep 500ms
Type "lw"
Enter
Sleep 3s
Type "# load tmux-autosize, then make another background window:"
Enter
Hide
Type "./autosize.tmux"
Enter
Sleep 500ms
Show
Type `tmux -L vhsdemo-autosize new-window -d -n bg-after`
Enter
Sleep 900ms
Type "lw"
Enter
Sleep 3.5s
Hide
Type `tmux -L vhsdemo-autosize kill-server`
Enter
Sleep 500ms
