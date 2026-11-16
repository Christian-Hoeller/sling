local M = {}

function M.check()
  local health = vim.health
  local opts = require("sling.config").options
  local handlers = require("sling.targets")

  health.start("sling")
  if vim.fn.has("nvim-0.10") == 1 then
    health.ok("Neovim >= 0.10")
  else
    health.error("Neovim >= 0.10 required")
  end

  local uses_tmux, uses_clipboard = false, false
  for _, target in pairs(opts.targets) do
    if type(target) == "table" then
      uses_tmux = uses_tmux or target.type == "tmux"
      uses_clipboard = uses_clipboard or target.type == "clipboard"
    end
  end

  if uses_tmux then
    if vim.fn.executable("tmux") == 1 then
      health.ok("tmux found: " .. vim.trim(vim.fn.system({ "tmux", "-V" })))
    else
      health.error("tmux not found", { "install tmux, tmux targets need it" })
    end
    if vim.env.TMUX then
      health.ok("running inside tmux")
    else
      health.warn("not running inside tmux", { "start nvim from a tmux session to use tmux targets" })
    end
  end
  if uses_clipboard and vim.fn.has("clipboard") == 0 then
    health.warn("no clipboard provider, the clipboard target can't write to `+`", { "see :help clipboard" })
  end

  health.start("sling targets")
  for name, target in pairs(opts.targets) do
    if type(target) == "function" then
      health.ok(name .. ": function")
    elseif type(target) ~= "table" or type(handlers[target.type]) ~= "function" then
      health.error(name .. ": unknown target type `" .. tostring(type(target) == "table" and target.type) .. "`")
    elseif target.type == "tmux" then
      local bin = vim.split(target.cmd or "", " ", { trimempty = true })[1]
      if bin and vim.fn.executable(bin) == 1 then
        health.ok(name .. ": `" .. bin .. "` found")
      else
        health.warn(name .. ": `" .. tostring(bin) .. "` not found on $PATH")
      end
    else
      health.ok(name .. ": " .. target.type)
    end
  end

  health.start("sling actions")
  for name, action in pairs(opts.actions) do
    if action then
      local target = action.target or opts.target
      local keys = type(action.keys) == "table" and table.concat(action.keys, ", ") or action.keys or "no keys"
      if opts.targets[target] then
        health.ok(("%s -> %s (%s)"):format(name, target, keys))
      else
        health.error(("%s: unknown target `%s`"):format(name, target))
      end
    end
  end
end

return M
