local config = require("sling.config")
local context = require("sling.context")
local scratch = require("sling.scratch")
local targets = require("sling.targets")

local M = {}

---@param done? fun(ok: boolean) runs once the target received the prompt or failed
local function send(action, ctx, done)
  done = done or function() end
  local opts = config.options
  local name = action.target or opts.target
  local target = opts.targets[name]
  if not target then
    vim.notify("sling: unknown target `" .. tostring(name) .. "`", vim.log.levels.ERROR)
    return done(false)
  end

  local prompt = context.render(action.template or opts.template, ctx, opts.vars)
  if type(target) == "function" then
    -- function targets fail by returning false
    return done(target(prompt, ctx, action) ~= false)
  end
  local handler = targets[target.type]
  if not handler then
    vim.notify("sling: unknown target type `" .. tostring(target.type) .. "`", vim.log.levels.ERROR)
    return done(false)
  end
  handler(prompt, ctx, action, target, name, done)
end

---Prompt window, sized by `size` (default: the `input` option).
---@param opts { title: string, lines?: string[], footer?: string, keys?: table<string, fun(buf: integer)> }
---@param on_done fun(text: string, submitted: boolean)
---@param size? { width: integer, min_height: integer, max_height: integer }
local function prompt(opts, on_done, size)
  require("sling.input").open(vim.tbl_extend("force", size or config.options.input, opts), on_done)
end

local function clear(buf)
  -- own undo step, `u` brings the text back
  vim.bo[buf].undolevels = vim.bo[buf].undolevels
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
end

---Append the rendered template (if any) to the scratch and open it.
---Closing keeps the text for next time, submitting sends it and clears what was sent once it arrived.
local function open_scratch(action, ctx)
  local lines = action.template and scratch.append(context.render(action.template, ctx, config.options.vars))
    or scratch.read()
  local title = type(action.scratch) == "string" and action.scratch or "Scratch"
  local win = {
    title = title,
    lines = lines,
    footer = " <C-s> submit · <C-l> clear · <Esc> close ",
    keys = { ["<C-l>"] = clear },
  }
  prompt(win, function(text, submitted)
    local sent = vim.split(text, "\n")
    -- save first, a failed send keeps the scratch
    scratch.write(sent)
    if not submitted or vim.trim(text) == "" then
      return
    end
    sent = scratch.read()
    ctx.input = text
    send(vim.tbl_extend("force", action, { template = "{input}" }), ctx, function(ok)
      if ok then
        scratch.remove_head(sent)
      end
    end)
  end, config.options.scratch)
end

---Run an action by name, or an ad-hoc action table.
---@param action string|sling.Action
---@param overrides? sling.Action
---@param range? { [1]: integer, [2]: integer }
function M.run(action, overrides, range)
  if type(action) == "string" then
    local found = config.options.actions[action]
    if not found then
      return vim.notify("sling: unknown action `" .. action .. "`", vim.log.levels.ERROR)
    end
    action = found
  end
  action = vim.tbl_extend("force", { submit = config.options.submit }, action, overrides or {})

  -- capture before the input opens, the selection is gone afterwards
  local ctx = context.capture(range, config.options.trees)
  if action.scratch then
    return open_scratch(action, ctx)
  end
  if not action.input then
    return send(action, ctx)
  end

  local title = type(action.input) == "string" and action.input or "Prompt"
  prompt({ title = title }, function(input, submitted)
    if not submitted or vim.trim(input) == "" then
      return
    end
    ctx.input = input
    send(action, ctx)
  end)
end

-- keymaps of the previous setup(), removed when setup() runs again
local mapped = {}

---Optional: defaults are applied on startup. Call again to reconfigure.
---@param opts? sling.Config
function M.setup(opts)
  config.setup(opts)
  M.did_setup = true

  for _, map in ipairs(mapped) do
    pcall(vim.keymap.del, map[1], map[2])
  end
  mapped = {}

  for name, action in pairs(config.options.actions) do
    if action and action.keys then
      local keys = type(action.keys) == "table" and action.keys or { action.keys }
      local mode = action.mode or { "n", "x" }
      for _, lhs in ipairs(keys) do
        vim.keymap.set(mode, lhs, function()
          M.run(name)
        end, { desc = action.desc or ("Sling: " .. name) })
        mapped[#mapped + 1] = { mode, lhs }
      end
    end
  end

  vim.api.nvim_create_user_command("Sling", function(cmd)
    M.run(cmd.args ~= "" and cmd.args or "ask", nil, cmd.range > 0 and { cmd.line1, cmd.line2 } or nil)
  end, {
    nargs = "?",
    range = true,
    desc = "Run a sling action",
    complete = function()
      return vim.tbl_keys(config.options.actions)
    end,
  })
end

return M
