# sling

Hand off a selection from Neovim to a CLI agent (Claude Code by default) running in a tmux pane.

Select code, hit a key, type a prompt. The prompt plus a file/line reference is pasted into the agent's input. If no agent pane exists in the current tmux window, one is opened in a split.

## Requirements

- Neovim **0.10+** (uses `vim.system`, `vim.fn.getregion`)
- [tmux](https://github.com/tmux/tmux) — Neovim must run **inside** a tmux session
- [Claude Code](https://docs.claude.com/en/docs/claude-code) (`claude` on `$PATH`), or any other CLI agent configured as a target
- optional: a `vim.ui.input` provider (e.g. [snacks.nvim](https://github.com/folke/snacks.nvim), [dressing.nvim](https://github.com/stevearc/dressing.nvim)) for a nicer prompt box

Check:

```sh
nvim --version | head -1   # NVIM v0.10.0 or newer
tmux -V
which claude
```

## Getting started

### 1. Install

The plugin does nothing until `setup()` is called — it registers the keymaps and the `:Sling` command.

**[lazy.nvim](https://github.com/folke/lazy.nvim)**

```lua
{
  "Christian-Hoeller/sling",
  event = "VeryLazy",
  opts = {}, -- calls require("sling").setup({})
}
```

For a local checkout use `dir = "~/projects/sling"` instead of the repo name.

**vim.pack** (Neovim 0.12+)

```lua
vim.pack.add({ "https://github.com/Christian-Hoeller/sling" })
require("sling").setup()
```

**Manual (native packages)**

```sh
git clone https://github.com/Christian-Hoeller/sling \
  ~/.local/share/nvim/site/pack/plugins/start/sling
```

```lua
-- init.lua
require("sling").setup()
```

Update with `git -C ~/.local/share/nvim/site/pack/plugins/start/sling pull`.

### 2. Start Neovim inside tmux

```sh
tmux new -s work
nvim .
```

### 3. Hand off

1. Put the cursor on a line, or select lines in visual mode.
2. Press `<leader>ap`, type a prompt, e.g. `why is this slow?`, hit `<Enter>`.
3. A pane running `claude` opens to the right (or an existing one is reused). Once Claude Code is ready, this is pasted into its input:

   ```
   why is this slow?

   @lua/sling/targets.lua#L54-73
   ```

4. Review and press `<Enter>` in the Claude pane — or use `<leader>aP` to submit right away.

`claude` already running in another pane of the same tmux window? It's detected and used instead of opening a new split.

### 4. Verify

```vim
:Sling add       " pastes only the reference of the current line
:'<,'>Sling fix  " sends the diagnostics of the selection
```

Not in tmux? Use the built-in clipboard target:

```vim
:lua require("sling").run("ask", { target = "clipboard" })
```

### Troubleshooting

| Message                          | Cause / fix                                                              |
| -------------------------------- | ------------------------------------------------------------------------ |
| `not inside tmux`                | start nvim from a tmux session (`$TMUX` must be set)                     |
| `could not open tmux pane`       | check `split` args; `tmux split-window -h claude` must work by hand      |
| `timed out waiting for <cmd>`    | `ready` pattern not seen in the pane within `ready_timeout` (default 15s) |
| keymaps missing                  | `setup()` not called, or `<leader>a*` taken by another plugin            |

## Default actions

| Key          | Action       | What it does                                   |
| ------------ | ------------ | ---------------------------------------------- |
| `<leader>ap` | `ask`        | ask for a prompt, prefill it (no submit)       |
| `<leader>aP` | `ask_submit` | ask for a prompt, submit it                    |
| `<leader>aa` | `add`        | paste only the `@file#L1-5` reference          |
| `<leader>ad` | `fix`        | send the diagnostics of the range with "fix"   |

All work in normal mode (cursor line) and visual mode (selection). `:Sling {action}` runs an action too and accepts a range.

## Configuration

Three pieces: **templates** build the prompt, **targets** receive it, **actions** combine both with a keymap.

```lua
opts = {
  template = "{input}\n\n@{file}#L{lines}", -- default for all actions
  target = "claude",
  submit = false,

  targets = {
    claude = {
      type = "tmux",
      cmd = "claude",
      split = { "-h" },          -- args for `tmux split-window`, e.g. { "-h", "-l", "40%" }
      reuse = true,              -- paste into a running pane instead of splitting again
      match = function(pane)     -- recognise panes started by hand: { id, command, title }
        return pane.command == "claude" or pane.title:find("Claude Code", 1, true) ~= nil
      end,
      ready = "Claude Code v",   -- lua pattern in the pane content: fresh pane is ready
      focus = true,
    },
    clipboard = { type = "clipboard" },
    -- a target can also be a function
    log = function(prompt, ctx, action) print(prompt) end,
  },

  actions = {
    ask = { keys = "<leader>kp" },   -- change a default
    fix = false,                     -- disable a default
    tests = {                        -- add your own
      template = "Write tests for @{file}#L{lines}",
      submit = true,
      keys = "<leader>kt",
      desc = "Write tests",
    },
    explain = { template = "Explain:\n```{filetype}\n{selection}\n```", input = false, keys = "<leader>ke" },
  },

  -- extra template variables
  vars = {
    branch = function() return vim.trim(vim.fn.system("git branch --show-current")) end,
  },
}
```

### Template variables

`{input}` `{file}` (relative to cwd) `{abs_file}` `{dir}` `{cwd}` `{filetype}` `{lines}` (`10` or `10-20`) `{start_line}` `{end_line}` `{selection}` `{diagnostics}`

### Lua API

```lua
require("sling").run("ask")
require("sling").run("ask", { submit = true })
require("sling").run({ template = "Review @{file}", target = "clipboard" })
```

## License

MIT
