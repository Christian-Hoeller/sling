local M = {}

local VISUAL = { v = true, V = true, ["\22"] = true }

---Lazily computed template variables. Each one receives the base context.
---@type table<string, fun(ctx: table): string>
M.vars = {
  file = function(ctx)
    return vim.fn.fnamemodify(ctx.path, ":.")
  end,
  abs_file = function(ctx)
    return ctx.path
  end,
  dir = function(ctx)
    return vim.fn.fnamemodify(ctx.path, ":.:h")
  end,
  cwd = function()
    return vim.fn.getcwd()
  end,
  filetype = function(ctx)
    return vim.bo[ctx.buf].filetype
  end,
  start_line = function(ctx)
    return tostring(ctx.start_line)
  end,
  end_line = function(ctx)
    return tostring(ctx.end_line)
  end,
  lines = function(ctx)
    if ctx.start_line == ctx.end_line then
      return tostring(ctx.start_line)
    end
    return ctx.start_line .. "-" .. ctx.end_line
  end,
  selection = function(ctx)
    return table.concat(ctx.text, "\n")
  end,
  diagnostics = function(ctx)
    local out = {}
    for _, d in ipairs(vim.diagnostic.get(ctx.buf)) do
      if d.lnum + 1 >= ctx.start_line and d.lnum + 1 <= ctx.end_line then
        local severity = vim.diagnostic.severity[d.severity] or "INFO"
        out[#out + 1] = ("- L%d [%s] %s"):format(d.lnum + 1, severity, (d.message:gsub("\n", " ")))
      end
    end
    return table.concat(out, "\n")
  end,
}

---Capture buffer, range and selected text. In normal mode the range is the cursor line.
---Must be called while the visual selection is still active.
---@param range? { [1]: integer, [2]: integer } explicit line range, e.g. from a command
function M.capture(range)
  local buf = vim.api.nvim_get_current_buf()
  local mode = vim.fn.mode()
  local ctx = { buf = buf, path = vim.api.nvim_buf_get_name(buf), visual = VISUAL[mode] == true }

  if range then
    ctx.start_line, ctx.end_line = range[1], range[2]
    ctx.text = vim.api.nvim_buf_get_lines(buf, range[1] - 1, range[2], false)
  elseif ctx.visual then
    local from, to = vim.fn.getpos("v"), vim.fn.getpos(".")
    ctx.text = vim.fn.getregion(from, to, { type = mode })
    ctx.start_line = math.min(from[2], to[2])
    ctx.end_line = math.max(from[2], to[2])
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
  else
    local line = vim.api.nvim_win_get_cursor(0)[1]
    ctx.start_line, ctx.end_line = line, line
    ctx.text = vim.api.nvim_buf_get_lines(buf, line - 1, line, false)
  end
  return ctx
end

---Replace `{name}` placeholders. Unknown names are left untouched.
---@param template string
---@param ctx table
---@param extra? table<string, fun(ctx: table): string>
function M.render(template, ctx, extra)
  local rendered = template:gsub("{([%w_]+)}", function(name)
    if ctx[name] ~= nil and type(ctx[name]) == "string" then
      return ctx[name]
    end
    local var = (extra and extra[name]) or M.vars[name]
    if var then
      return var(ctx) or ""
    end
  end)
  return vim.trim(rendered) .. (template:match(" $") and " " or "")
end

return M
