<h1 align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/sling-dark.svg">
    <img alt="sling" src="assets/sling-light.svg" width="360">
  </picture>
</h1>

Sling a selection from Neovim to a CLI agent (Claude Code by default) running in a tmux pane.

Select code, hit a key, type a prompt. The prompt plus a file/line reference is pasted into the agent's input. If no agent pane exists in the current tmux window, one is opened in a split.

![sling demo](assets/demo.gif)

## Requirements

- Neovim **0.10+**
- [tmux](https://github.com/tmux/tmux) — Neovim must run **inside** a tmux session
- [Claude Code](https://docs.claude.com/en/docs/claude-code) (`claude` on `$PATH`), or any other CLI agent configured as a target

Check:

```sh
nvim --version | head -1   # NVIM v0.10.0 or newer
tmux -V
which claude
```

## Getting started

### 1. Install

Works without configuration: keymaps and the `:Sling` command are registered on startup. `setup()` is only needed to change the defaults.

**[lazy.nvim](https://github.com/folke/lazy.nvim)**

```lua
{
  "Christian-Hoeller/sling",
  event = "VeryLazy",
  opts = {}, -- optional, your config goes here
}
```

For a local checkout use `dir = "~/projects/sling"` instead of the repo name.

**vim.pack** (Neovim 0.12+, built-in plugin manager)

```lua
vim.pack.add({ "https://github.com/Christian-Hoeller/sling" })
-- optional
require("sling").setup({})
```

**Manual (native packages)**

```sh
git clone https://github.com/Christian-Hoeller/sling \
  ~/.local/share/nvim/site/pack/plugins/start/sling
nvim -c 'helptags ALL' -c q   # generate :help tags
```

```lua
-- init.lua, optional
require("sling").setup({})
```

Update with `git -C ~/.local/share/nvim/site/pack/plugins/start/sling pull`.

### 2. Start Neovim inside tmux

```sh
tmux new -s work
nvim .
```

### 3. Check

```vim
:checkhealth sling
```

Reports the Neovim version, tmux, whether Neovim runs inside tmux, the target commands (`claude`) and the configured actions.

### 4. Sling

1. Put the cursor on a line, or select lines in visual mode.
2. Press `<leader>ap`, type a prompt, e.g. `why is this slow?`, hit `<Enter>`.
3. A pane running `claude` opens to the right (or an existing one is reused). Once Claude Code is ready, this is pasted into its input:

   ```
   why is this slow?

   @lua/sling/targets.lua#L54-73
   ```

4. Review and press `<Enter>` in the Claude pane — or use `<leader>aP` to submit right away.

`claude` already running in another pane of the same tmux window? It's detected and used instead of opening a new split.

Not in tmux? Use the built-in clipboard target:

```vim
:lua require("sling").run("ask", { target = "clipboard" })
```

### Troubleshooting

| Message                       | Cause / fix                                                               |
| ----------------------------- | ------------------------------------------------------------------------- |
| `not inside tmux`             | start nvim from a tmux session (`$TMUX` must be set)                      |
| `could not open tmux pane`    | check `split` args; `tmux split-window -h claude` must work by hand       |
| `timed out waiting for <cmd>` | `ready` pattern not seen in the pane within `ready_timeout` (default 15s) |
| `timed out waiting for claude` in a new folder | Claude Code asks "Do you trust this folder?" first; answer it in the pane, then sling again |
| keymaps missing / different   | another plugin uses `<leader>a*` (e.g. LazyVim's AI group); remap the actions, see [Configuration](#configuration) |
| keymaps on `\` instead of space | `mapleader` is set after sling loaded; set it before plugins load |

Run `:checkhealth sling` first.

## Usage

### Default actions

| Key          | Action       | What it does                                 |
| ------------ | ------------ | -------------------------------------------- |
| `<leader>ap` | `ask`        | ask for a prompt, prefill it (no submit)     |
| `<leader>aP` | `ask_submit` | ask for a prompt, submit it                  |
| `<leader>aa` | `add`        | paste only the `@file#L1-5` reference        |
| `<leader>ad` | `fix`        | send the diagnostics of the range with "fix" |

All work in normal mode (cursor line) and visual mode (selection).

### Command

```vim
:Sling              " runs `ask` on the cursor line
:Sling add          " any action, tab-completes
:'<,'>Sling fix     " with a range
```

### Help

`:help sling` has the full reference.

## Configuration

Three pieces: **templates** build the prompt, **targets** receive it, **actions** combine both with a keymap. Everything is merged into the defaults, so only set what you change.

```lua
opts = {
  template = "{input}\n\n@{file}#L{lines}", -- default for all actions
  target = "claude",                        -- default target
  submit = false,                           -- default: prefill only

  -- prompt window: multi-line, wraps at `width`, grows up to `max_height`
  -- <C-s> submits (any mode), <CR> submits in normal mode, <Esc>/q cancels
  input = { width = 80, min_height = 3, max_height = 15 },

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
      ready_timeout = 15000,     -- ms
      focus = true,              -- jump to the pane after sending
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
    explain = { template = "Explain:\n```{filetype}\n{selection}\n```", keys = "<leader>ke" },
  },

  -- extra template variables
  vars = {
    branch = function() return vim.trim(vim.fn.system("git branch --show-current")) end,
  },
}
```

### Action fields

| Field      | Type                 | Default              | Description                                                               |
| ---------- | -------------------- | -------------------- | ------------------------------------------------------------------------- |
| `template` | `string`             | top-level `template` | prompt template                                                           |
| `target`   | `string`             | top-level `target`   | name of a target in `targets`                                             |
| `input`    | `boolean \| string`  | `nil`                | ask for `{input}` first; a string is the input title; empty input cancels |
| `submit`   | `boolean`            | top-level `submit`   | press Enter after pasting                                                 |
| `keys`     | `string \| string[]` | `nil`                | keymap(s)                                                                 |
| `mode`     | `string \| string[]` | `{ "n", "x" }`       | modes for `keys`                                                          |
| `desc`     | `string`             | `Sling: <name>`      | keymap description                                                        |

### Template variables

| Variable        | Value                                  |
| --------------- | -------------------------------------- |
| `{input}`       | text typed at the prompt               |
| `{file}`        | file path relative to cwd              |
| `{abs_file}`    | absolute file path                     |
| `{dir}`         | directory of the file, relative to cwd |
| `{cwd}`         | current working directory              |
| `{filetype}`    | buffer filetype                        |
| `{lines}`       | `10` or `10-20`                        |
| `{start_line}`  | first line of the range                |
| `{end_line}`    | last line of the range                 |
| `{selection}`   | selected text                          |
| `{diagnostics}` | diagnostics in the range, one per line |

Unknown placeholders are left as is.

### Lua API

```lua
require("sling").run("ask")
require("sling").run("ask", { submit = true })
require("sling").run({ template = "Review @{file}", target = "clipboard" })
```

## License

MIT
