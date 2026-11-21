Source assets/tapes/common.tape
Output assets/demo-scratch.gif
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
Sleep 600ms
Type " kc"
Sleep 1.5s
Escape
Sleep 300ms
Escape
Sleep 600ms
Type ":e lua/sling/input.lua" Enter
Sleep 1s
Type "/local function resize" Enter
Type ":noh" Enter
Type "zz"
Sleep 600ms
Type "V"
Sleep 300ms
Type "10j"
Sleep 600ms
Type " kc"
Sleep 1.5s
Escape
Sleep 300ms
Escape
Sleep 600ms
Type " e"
Sleep 1.5s
Type "5j"
Sleep 800ms
Type " kc"
Sleep 1.5s
Enter
Enter
Set TypingSpeed 45ms
Type "merge both polling loops into one helper, then update the README"
Sleep 1.2s
Ctrl+S
Sleep 9s
Hide
Ctrl+A
Type "l"
Sleep 300ms
Type@0 ":qa!" Enter
Sleep 200ms
