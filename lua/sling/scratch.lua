local M = {}

---One scratch file per working directory, `{file}` references are relative to it.
local function path()
  local name = vim.fn.getcwd():gsub("[/\\:]", "%%")
  return vim.fn.stdpath("state") .. "/sling/scratch/" .. name .. ".md"
end

local function trim_end(lines)
  while #lines > 0 and vim.trim(lines[#lines]) == "" do
    table.remove(lines)
  end
  return lines
end

---@return string[]
function M.read()
  local file = path()
  if vim.fn.filereadable(file) == 0 then
    return {}
  end
  return trim_end(vim.fn.readfile(file))
end

---Save the lines, an empty scratch removes the file.
---@param lines string[]
function M.write(lines)
  local file = path()
  lines = trim_end(vim.list_extend({}, lines))
  if #lines == 0 then
    os.remove(file)
    return
  end
  vim.fn.mkdir(vim.fn.fnamemodify(file, ":h"), "p")
  vim.fn.writefile(lines, file)
end

---Append `text` below the existing lines, separated by an empty line.
---@param text string
---@return string[] lines the whole scratch
function M.append(text)
  local lines = M.read()
  if #lines > 0 then
    lines[#lines + 1] = ""
  end
  vim.list_extend(lines, vim.split(text, "\n"))
  M.write(lines)
  return lines
end

---Drop `head` from the top of the scratch. Entries collected after it stay;
---a scratch that no longer starts with `head` is left alone.
---@param head string[]
function M.remove_head(head)
  local lines = M.read()
  if not vim.deep_equal(vim.list_slice(lines, 1, #head), head) then
    return
  end
  -- +2 skips the empty separator line
  M.write(vim.list_slice(lines, #head + 2))
end

return M
