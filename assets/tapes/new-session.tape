Source assets/tapes/common.tape
Output assets/demo-new-session.gif
Hide
Type "unset TMUX; clear; tmux -L demo new -s sling 'nvim lua/sling/targets.lua'" Enter
Sleep 4s
Type "/^local function when_ready" Enter
Type ":noh" Enter
Type "zt"
Sleep 300ms
Show
Sleep 1s
Type "V"
Sleep 300ms
Type "22j"
Sleep 800ms
Type " kp"
Sleep 800ms
Set TypingSpeed 45ms
Type "why poll here instead of waiting for an event?"
Sleep 1s
Ctrl+S
Sleep 8s
Hide
Type@0 ":qa!" Enter
Sleep 200ms
