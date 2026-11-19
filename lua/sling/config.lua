local M = {}

---@class sling.Action
---@field template? string prompt template, `{var}` placeholders
---@field target? string name of a target in `targets`
---@field input? boolean|string ask for input; a string is used as the input title
---@field scratch? boolean|string open the scratch instead; `template` is appended to it first; a string is the title
---@field submit? boolean send the prompt right away instead of only prefilling
---@field keys? string|string[] keymap(s) for this action
---@field mode? string|string[] modes for `keys`
---@field desc? string

---@class sling.Config
M.defaults = {
  -- used by actions that don't set their own
  template = "{input}\n\n{ref}",
  target = "claude",
  submit = false,

  -- prompt window for actions with `input`
  input = {
    width = 80, -- text wraps at this width
    min_height = 3,
    max_height = 15, -- grows with the text up to this
  },

  -- scratch window, same fields as `input`
  scratch = {
    width = 100,
    min_height = 15,
    max_height = 30,
  },

  ---@type table<string, table|fun(prompt: string, ctx: table, action: sling.Action)>
  targets = {
    claude = {
      type = "tmux",
      cmd = "claude",
      -- args for `tmux split-window`
      split = { "-h" },
      -- reuse a running pane in the current window instead of splitting again
      reuse = true,
      -- how to recognise a pane started outside of the plugin
      match = function(pane)
        return pane.command == "claude" or pane.title:find("Claude Code", 1, true) ~= nil
      end,
      -- lua pattern in the pane content that tells a fresh pane is ready for input
      ready = "Claude Code v",
      ready_timeout = 15000,
      -- move the cursor to the pane after sending
      focus = true,
    },
    clipboard = { type = "clipboard" },
  },

  ---@type table<string, sling.Action|false>
  actions = {
    ask = { input = "Ask Claude", keys = "<leader>ap", mode = { "n", "x" }, desc = "Prompt (prefill)" },
    ask_submit = {
      input = "Ask Claude (submit)",
      submit = true,
      keys = "<leader>aP",
      mode = { "n", "x" },
      desc = "Prompt (submit)",
    },
    add = { template = "{ref} ", keys = "<leader>aa", mode = { "n", "x" }, desc = "Add reference" },
    collect = {
      scratch = true,
      template = "{ref} ",
      keys = "<leader>ac",
      mode = { "n", "x" },
      desc = "Add reference to scratch",
    },
    scratch = { scratch = true, keys = "<leader>as", mode = { "n", "x" }, desc = "Open scratch" },
    fix = {
      template = "Fix these diagnostics in {ref}:\n{diagnostics}",
      keys = "<leader>ad",
      mode = { "n", "x" },
      desc = "Fix diagnostics",
    },
  },

  -- extra template variables: name -> fun(ctx): string
  ---@type table<string, fun(ctx: table): string>
  vars = {},

  -- file trees: filetype -> fun(): string?, path under the cursor
  ---@type table<string, fun(line: integer): string?>
  trees = {},
}

---@type sling.Config
M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

return M
