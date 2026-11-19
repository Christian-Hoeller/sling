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
    if not ctx.start_line then
      return ""
    elseif ctx.start_line == ctx.end_line then
      return tostring(ctx.start_line)
    end
    return ctx.start_line .. "-" .. ctx.end_line
  end,
  -- `@file#L1-5`, or one `@path` per line for file tree entries (folders end in `/`)
  ref = function(ctx)
    if not ctx.tree then
      return "@" .. vim.fn.fnamemodify(ctx.path, ":.") .. "#L" .. M.vars.lines(ctx)
    end
    local refs = {}
    for _, path in ipairs(ctx.paths) do
      local rel = vim.fn.fnamemodify(path, ":.")
      if vim.fn.isdirectory(path) == 1 then
        rel = rel:gsub("/$", "") .. "/"
      end
      refs[#refs + 1] = "@" .. rel
    end
    return table.concat(refs, "\n")
  end,
  selection = function(ctx)
    return table.concat(ctx.text, "\n")
  end,
  diagnostics = function(ctx)
    if not ctx.start_line then
      return ""
    end
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

---Path of the entry on a line of a file tree, keyed by filetype. Runs in the tree window.
---@type table<string, fun(line: integer): string?>
M.trees = {
  ["neo-tree"] = function(line)
    local state = require("neo-tree.sources.manager").get_state_for_window()
    local node = state and state.tree and state.tree:get_node(line)
    return node and node.path
  end,
  snacks_picker_list = function(line)
    local picker = Snacks.picker.get({ source = "explorer" })[1]
    local item = picker and picker.list:get(picker.list:row2idx(line))
    return item and item.file
  end,
  -- no per-line api, always the cursor entry
  NvimTree = function()
    local node = require("nvim-tree.api").tree.get_node_under_cursor()
    return node and node.absolute_path
  end,
  oil = function(line)
    local oil = require("oil")
    local entry, dir = oil.get_entry_on_line(0, line), oil.get_current_dir()
    return entry and dir and dir .. entry.name
  end,
}

---Unique paths of the tree entries on lines `first` to `last`.
local function tree_paths(tree, first, last)
  local paths, seen = {}, {}
  for line = first, last do
    local ok, path = pcall(tree, line)
    if ok and path and not seen[path] then
      seen[path] = true
      paths[#paths + 1] = path
    end
  end
  return paths
end

---Capture buffer, range and selected text. In normal mode the range is the cursor line.
---In a file tree the context is the entries in the range (`paths`), without lines.
---Must be called while the visual selection is still active.
---@param range? { [1]: integer, [2]: integer } explicit line range, e.g. from a command
---@param trees? table<string, fun(line: integer): string?> extra file trees
function M.capture(range, trees)
  local buf = vim.api.nvim_get_current_buf()
  local mode = vim.fn.mode()
  local ctx = { buf = buf, path = vim.api.nvim_buf_get_name(buf), visual = VISUAL[mode] == true }

  local from, to
  if range then
    ctx.start_line, ctx.end_line = range[1], range[2]
  elseif ctx.visual then
    from, to = vim.fn.getpos("v"), vim.fn.getpos(".")
    ctx.start_line = math.min(from[2], to[2])
    ctx.end_line = math.max(from[2], to[2])
  else
    local line = vim.api.nvim_win_get_cursor(0)[1]
    ctx.start_line, ctx.end_line = line, line
  end

  local ft = vim.bo[buf].filetype
  local tree = (trees and trees[ft]) or M.trees[ft]
  local paths = tree and tree_paths(tree, ctx.start_line, ctx.end_line) or {}
  if #paths > 0 then
    ctx.tree, ctx.paths, ctx.path, ctx.text = true, paths, paths[1], {}
    ctx.start_line, ctx.end_line = nil, nil
  elseif from then
    ctx.text = vim.fn.getregion(from, to, { type = mode })
  else
    ctx.text = vim.api.nvim_buf_get_lines(buf, ctx.start_line - 1, ctx.end_line, false)
  end

  if from then
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
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
