local M = {}

local BUFFER = "sling"

-- pane ids created by the plugin, keyed by target name
local panes = {}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.ERROR, { title = "sling" })
end

---@param args string[]
---@param stdin? string
---@return string? stdout nil on failure
local function tmux(args, stdin)
  local res = vim.system(vim.list_extend({ "tmux" }, args), { text = true, stdin = stdin }):wait()
  if res.code ~= 0 then
    return nil
  end
  return vim.trim(res.stdout or "")
end

---Panes of the window nvim runs in, without nvim's own pane.
local function list_panes()
  local own = vim.env.TMUX_PANE
  local out = tmux({ "list-panes", "-t", own, "-F", "#{pane_id}\t#{pane_current_command}\t#{pane_title}" })
  local result = {}
  for line in vim.gsplit(out or "", "\n", { trimempty = true }) do
    local id, command, title = line:match("^(%S+)\t([^\t]*)\t(.*)$")
    if id and id ~= own then
      result[#result + 1] = { id = id, command = command, title = title }
    end
  end
  return result
end

local function find_pane(name, opts)
  local list = list_panes()
  for _, pane in ipairs(list) do
    if pane.id == panes[name] then
      return pane.id
    end
  end
  panes[name] = nil
  if opts.match then
    for _, pane in ipairs(list) do
      if opts.match(pane) then
        return pane.id
      end
    end
  end
end

---Poll the pane content until `opts.ready` shows up, `done(false)` when it doesn't.
local function when_ready(pane, opts, cb, done)
  if not opts.ready then
    return cb()
  end
  local deadline = vim.uv.now() + (opts.ready_timeout or 15000)
  local function poll()
    local content = tmux({ "capture-pane", "-p", "-t", pane })
    if content == nil then
      notify("pane closed before it was ready")
      return done(false)
    end
    if content:find(opts.ready) then
      -- give the app a moment to finish drawing its input
      return vim.defer_fn(cb, 300)
    end
    if vim.uv.now() > deadline then
      notify("timed out waiting for `" .. opts.cmd .. "`")
      return done(false)
    end
    vim.defer_fn(poll, 100)
  end
  poll()
end

local function paste(pane, prompt, opts, submit, done)
  if tmux({ "load-buffer", "-b", BUFFER, "-" }, prompt) == nil then
    notify("tmux load-buffer failed")
    return done(false)
  end
  -- -p: bracketed paste, so newlines don't submit
  tmux({ "paste-buffer", "-p", "-d", "-b", BUFFER, "-t", pane })
  -- apps tend to trim pasted text, type the trailing space so the next paste stays separated
  if prompt:match(" $") then
    tmux({ "send-keys", "-t", pane, "-l", " " })
  end
  if opts.focus then
    tmux({ "select-pane", "-t", pane })
  end
  if submit then
    vim.defer_fn(function()
      tmux({ "send-keys", "-t", pane, "Enter" })
    end, 150)
  end
  done(true)
end

---Paste the prompt into a tmux pane running `opts.cmd`, creating the pane when needed.
---`done(ok)` runs once the prompt is pasted or sending failed, possibly much later.
---@param done fun(ok: boolean)
function M.tmux(prompt, ctx, action, opts, name, done)
  if not vim.env.TMUX then
    notify("not inside tmux")
    return done(false)
  end

  local pane = opts.reuse and find_pane(name, opts)
  if pane then
    return paste(pane, prompt, opts, action.submit, done)
  end

  local args = { "split-window", "-d", "-P", "-F", "#{pane_id}", "-t", vim.env.TMUX_PANE, "-c", vim.fn.getcwd() }
  vim.list_extend(args, opts.split or { "-h" })
  args[#args + 1] = opts.cmd
  pane = tmux(args)
  if not pane or pane == "" then
    notify("could not open tmux pane")
    return done(false)
  end
  panes[name] = pane
  if opts.focus then
    tmux({ "select-pane", "-t", pane })
  end
  when_ready(pane, opts, function()
    paste(pane, prompt, opts, action.submit, done)
  end, done)
end

function M.clipboard(prompt, ctx, action, opts, name, done)
  vim.fn.setreg("+", prompt)
  notify("prompt copied", vim.log.levels.INFO)
  done(true)
end

return M
