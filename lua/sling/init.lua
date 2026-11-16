local config = require("sling.config")
local context = require("sling.context")
local targets = require("sling.targets")

local M = {}

local function send(action, ctx)
  local opts = config.options
  local name = action.target or opts.target
  local target = opts.targets[name]
  if not target then
    return vim.notify("sling: unknown target `" .. tostring(name) .. "`", vim.log.levels.ERROR)
  end

  local prompt = context.render(action.template or opts.template, ctx, opts.vars)
  if type(target) == "function" then
    return target(prompt, ctx, action)
  end
  local handler = targets[target.type]
  if not handler then
    return vim.notify("sling: unknown target type `" .. tostring(target.type) .. "`", vim.log.levels.ERROR)
  end
  handler(prompt, ctx, action, target, name)
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
  local ctx = context.capture(range)
  if not action.input then
    return send(action, ctx)
  end

  local title = type(action.input) == "string" and action.input or "Prompt"
  vim.ui.input({ prompt = title .. ": " }, function(input)
    if input == nil or vim.trim(input) == "" then
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
