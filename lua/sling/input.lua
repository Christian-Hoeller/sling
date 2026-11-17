local M = {}

---Multi-line prompt in a floating window. Text wraps at a fixed width.
---`<C-s>` (any mode) or `<CR>` (normal mode) submits, `<Esc>`/`q` (normal mode) cancels.
---@param opts { title: string, width: integer, min_height: integer, max_height: integer }
---@param on_done fun(input?: string)
function M.open(opts, on_done)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"

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
    footer = " <C-s> submit · <Esc> cancel ",
    footer_pos = "right",
  })
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true

  local done = false
  local function finish(input)
    if done then
      return
    end
    done = true
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    vim.cmd.stopinsert()
    -- run after the window is gone so the callback acts on the original window
    vim.schedule(function()
      on_done(input)
    end)
  end

  local function submit()
    finish(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"))
  end

  local map = function(mode, lhs, fn)
    vim.keymap.set(mode, lhs, fn, { buffer = buf, nowait = true })
  end
  map({ "n", "i" }, "<C-s>", submit)
  map("n", "<CR>", submit)
  map("n", "<Esc>", finish)
  map("n", "q", finish)

  -- grow with the wrapped text, between min_height and max_height
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = buf,
    callback = function()
      if not vim.api.nvim_win_is_valid(win) then
        return
      end
      local rows = vim.api.nvim_win_text_height(win, {}).all
      local height = math.max(opts.min_height, math.min(opts.max_height, rows))
      if height ~= vim.api.nvim_win_get_height(win) then
        vim.api.nvim_win_set_height(win, height)
      end
    end,
  })
  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = buf,
    once = true,
    callback = function()
      -- closing a window inside WinLeave is not allowed
      vim.schedule(finish)
    end,
  })

  vim.cmd.startinsert()
end

return M
