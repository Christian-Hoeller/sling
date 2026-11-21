Source assets/tapes/common.tape
Output assets/demo-existing-session.gif
Hide
Type "unset TMUX; clear; tmux -L demo new -s sling 'nvim lua/sling/targets.lua'" Enter
Sleep 4s
Type " kP"
Sleep 500ms
Type "In two sentences: what does this plugin do?"
Ctrl+S
Sleep 25s
Ctrl+A
Type "l"
Sleep 300ms
Type "/^local function find_pane" Enter
Type ":noh" Enter
Type "zt"
Sleep 300ms
Show
Sleep 1.5s
Type "V"
Sleep 300ms
Type "16j"
Sleep 800ms
Type " kp"
Sleep 800ms
Set TypingSpeed 45ms
Type "also search the other tmux windows"
Sleep 1s
Ctrl+S
Sleep 3s
Hide
Type@0 ":qa!" Enter
Sleep 200ms
