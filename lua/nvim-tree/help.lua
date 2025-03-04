local keymap = require "nvim-tree.keymap"

local PAT_MOUSE = "^<.*Mouse"
local PAT_CTRL = "^<C%-"
local PAT_SPECIAL = "^<.+"

local WIN_HL = table.concat({
  "Normal:NvimTreeNormal",
  "CursorLine:NvimTreeCursorLine",
}, ",")

local M = {
  config = {},

  -- one and only buf/win
  bufnr = nil,
  winnr = nil,
}

--- Shorten and normalise a vim command lhs
--- @param lhs string
--- @return string
local function tidy_lhs(lhs)
  -- nvim_buf_get_keymap replaces leading "<" with "<lt>" e.g. "<lt>CTRL-v>"
  lhs = lhs:gsub("^<lt>", "<")

  -- shorten ctrls
  if lhs:lower():match "^<ctrl%-" then
    lhs = lhs:lower():gsub("^<ctrl%-", "<C%-")
  end

  -- uppercase ctrls
  if lhs:lower():match "^<c%-" then
    lhs = lhs:upper()
  end

  -- space is not escaped
  lhs = lhs:gsub(" ", "<Space>")

  return lhs
end

--- Remove prefix 'nvim-tree: '
--- Hardcoded to keep default_on_attach simple
--- @param desc string
--- @return string
local function tidy_desc(desc)
  return desc and desc:gsub("^nvim%-tree: ", "") or ""
end

--- sort vim command lhs roughly as per :help index
--- @param a string
--- @param b string
local function sort_lhs(a, b)
  -- mouse first
  if a:match(PAT_MOUSE) and not b:match(PAT_MOUSE) then
    return true
  elseif not a:match(PAT_MOUSE) and b:match(PAT_MOUSE) then
    return false
  end

  -- ctrl next
  if a:match(PAT_CTRL) and not b:match(PAT_CTRL) then
    return true
  elseif not a:match(PAT_CTRL) and b:match(PAT_CTRL) then
    return false
  end

  -- special next
  if a:match(PAT_SPECIAL) and not b:match(PAT_SPECIAL) then
    return true
  elseif not a:match(PAT_SPECIAL) and b:match(PAT_SPECIAL) then
    return false
  end

  -- remainder alpha
  return a:gsub("[^a-zA-Z]", "") < b:gsub("[^a-zA-Z]", "")
end

--- Compute all lines for the buffer
--- @return table strings of text
--- @return table arrays of arguments 3-6 for nvim_buf_add_highlight()
--- @return number maximum length of text
local function compute()
  local hl = { { "NvimTreeRootFolder", 0, 0, 18 } }
  local width = 0

  -- formatted lhs and desc from active keymap
  local mappings = vim.tbl_map(function(map)
    return { lhs = tidy_lhs(map.lhs), desc = tidy_desc(map.desc) }
  end, keymap.get_keymap())

  -- sort roughly by lhs
  table.sort(mappings, function(a, b)
    return sort_lhs(a.lhs, b.lhs)
  end)

  -- longest lhs and description
  local max_lhs = 0
  local max_desc = 0
  for _, l in pairs(mappings) do
    max_lhs = math.max(#l.lhs, max_lhs)
    max_desc = math.max(#l.desc, max_desc)
  end

  local lines = { ("nvim-tree mappings%sexit: q"):format(string.rep(" ", max_desc + max_lhs - 23)) }
  local fmt = string.format(" %%-%ds %%-%ds", max_lhs, max_desc)
  for i, l in ipairs(mappings) do
    -- format in left aligned columns
    local line = string.format(fmt, l.lhs, l.desc)
    table.insert(lines, line)
    width = math.max(#line, width)

    -- highlight lhs
    table.insert(hl, { "NvimTreeFolderName", i, 0, #l.lhs + 1 })
  end

  return lines, hl, width
end

--- close the window and delete the buffer, if they exist
local function close()
  if M.winnr then
    vim.api.nvim_win_close(M.winnr, true)
    M.winnr = nil
  end
  if M.bufnr then
    vim.api.nvim_buf_delete(M.bufnr, { force = true })
    M.bufnr = nil
  end
end

--- open a new window and buffer
local function open()
  -- close existing, shouldn't be necessary
  close()

  -- text and highlight
  local lines, hl, width = compute()

  -- create the buffer
  M.bufnr = vim.api.nvim_create_buf(false, true)

  -- populate it
  vim.api.nvim_buf_set_lines(M.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M.bufnr, "modifiable", false)

  -- highlight it
  for _, h in ipairs(hl) do
    vim.api.nvim_buf_add_highlight(M.bufnr, -1, h[1], h[2], h[3], h[4])
  end

  -- open a very restricted window
  M.winnr = vim.api.nvim_open_win(M.bufnr, true, {
    relative = "editor",
    border = "single",
    width = width,
    height = #lines,
    row = 1,
    col = 0,
    style = "minimal",
    noautocmd = true,
  })

  -- style it a bit like the tree
  vim.wo[M.winnr].winhl = WIN_HL
  vim.wo[M.winnr].cursorline = M.config.cursorline

  -- quit binding
  vim.keymap.set(
    "n",
    "q",
    close,
    { desc = "nvim-tree: exit help", buffer = M.bufnr, noremap = true, silent = true, nowait = true }
  )

  -- close window and delete buffer on leave
  vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
    buffer = M.bufnr,
    once = true,
    callback = close,
  })
end

function M.toggle()
  if M.winnr or M.bufnr then
    close()
  else
    open()
  end
end

function M.setup(opts)
  M.config.cursorline = opts.view.cursorline
end

return M
