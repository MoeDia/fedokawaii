-- feasibility: ruled lines across the whole width, text rows and the empty page below
vim.o.termguicolors = true
vim.o.number = false; vim.o.laststatus = 0; vim.o.ruler = false; vim.o.showmode = false
vim.opt.fillchars = { eob = " " }
vim.api.nvim_set_hl(0, "Normal", { fg = "#d8c79a", bg = "#181715" })
vim.api.nvim_set_hl(0, "KawaRule", { underline = true, sp = "#4a3a2a" })
local buf = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "2026-11-01 · Sun", "", "the first thought of the day, a long line that wraps when it reaches the right edge of the page", "a short one", "" })
local ns = vim.api.nvim_create_namespace("rule")
local function draw()
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local n = vim.api.nvim_buf_line_count(buf)
  for i = 0, n - 1 do vim.api.nvim_buf_set_extmark(buf, ns, i, 0, { line_hl_group = "KawaRule" }) end
  local w = vim.api.nvim_win_get_width(0)
  local rows = {}
  for _ = 1, vim.o.lines do rows[#rows + 1] = { { string.rep(" ", w), "KawaRule" } } end
  vim.api.nvim_buf_set_extmark(buf, ns, n - 1, 0, { virt_lines = rows })
end
draw()
