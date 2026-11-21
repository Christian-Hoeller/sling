local M = {}

M.footer = " <C-s> submit · <Esc> cancel "

---Multi-line prompt in a floating window. Text wraps at a fixed width.
---`<C-s>` (any mode) or `<CR>` (normal mode) submits, `<Esc>`/`q` (normal mode) closes.
---`lines` prefills the window, the cursor starts at the end of the text.
---`keys` adds mappings (normal and insert mode) that get the buffer and window.
---@param opts { title: string, width: integer, min_height: integer, max_height: integer, lines?: string[], footer?: string, keys?: table<string, fun(buf: integer, win: integer)> }
---@param on_done fun(text: string, submitted: boolean)
function M.open(opts, on_done)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  -- own filetype so completion plugins can ignore it, highlighted as markdown
  vim.bo[buf].filetype = "sling"
  pcall(vim.treesitter.start, buf, "markdown")
  -- blink.cmp and others that honor it
  vim.b[buf].completion = false
  if opts.lines and #opts.lines > 0 then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, opts.lines)
  end

  local width = math.min(opts.width, vim.o.columns - 4)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = opts.min_height,
    row = math.floor((vim.o.lines - opts.min_height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " " .. opts.title .. " ",
    title_pos = "center",
    footer = opts.footer or M.footer,
    footer_pos = "right",
  })
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  if package.loaded.cmp then
    -- applies to the current buffer, the window above is focused
    require("cmp").setup.buffer({ enabled = false })
  end

  local done = false
  local function finish(submitted)
    if done then
      return
    end
    done = true
    local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    vim.cmd.stopinsert()
    -- run after the window is gone so the callback acts on the original window
    vim.schedule(function()
      on_done(text, submitted)
    end)
  end

  local map = function(mode, lhs, fn)
    vim.keymap.set(mode, lhs, fn, { buffer = buf, nowait = true })
  end
  local submit = function()
    finish(true)
  end
  local close = function()
    finish(false)
  end
  map({ "n", "i" }, "<C-s>", submit)
  map("n", "<CR>", submit)
  map("n", "<Esc>", close)
  map("n", "q", close)
  for lhs, fn in pairs(opts.keys or {}) do
    map({ "n", "i" }, lhs, function()
      fn(buf, win)
    end)
  end

  -- grow with the wrapped text, between min_height and max_height
  local function resize()
    if not vim.api.nvim_win_is_valid(win) then
      return
    end
    local rows = vim.api.nvim_win_text_height(win, {}).all
    local height = math.max(opts.min_height, math.min(opts.max_height, rows))
    if height ~= vim.api.nvim_win_get_height(win) then
      vim.api.nvim_win_set_height(win, height)
    end
  end
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, { buffer = buf, callback = resize })
  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = buf,
    once = true,
    callback = function()
      -- closing a window inside WinLeave is not allowed
      vim.schedule(close)
    end,
  })

  resize()
  vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(buf), 0 })
  vim.cmd.startinsert({ bang = true })
end

return M
