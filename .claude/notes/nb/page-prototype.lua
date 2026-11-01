-- prototype (not shipped): the notebook page — heading in the tabline, a blank winbar, ruled rows to the page's
-- foot, a vermilion margin rule (statuscolumn), a blank statusline, the footer a float on the last row
local mood = os.getenv("MOOD") or "dark"
local C = mood == "dark"
  and { ground = "#181715", edge = "#2d251e", edge2 = "#3c2f22", faint = "#907e5d", muted = "#cab596", text = "#e7cfa1", strong = "#f5ecc2", accent = "#eb5324", accent_text = "#f47b58" }
  or  { ground = "#e8e3c2", edge = "#dfcc9c", edge2 = "#d7bc8c", faint = "#8b917f", muted = "#586459", text = "#122625", strong = "#121b1b", accent = "#a84222", accent_text = "#a84222" }
vim.o.termguicolors = true
vim.o.number = false; vim.o.ruler = false; vim.o.showmode = false; vim.o.cmdheight = 0
vim.o.laststatus = 2; vim.o.showtabline = 2; vim.o.wrap = true; vim.o.linebreak = true
vim.opt.fillchars = { eob = " ", stl = " ", stlnc = " " }
local hl = function(n, v) vim.api.nvim_set_hl(0, n, v) end
hl("Normal", { fg = C.text, bg = C.ground }); hl("TabLineFill", { bg = C.ground }); hl("WinBar", { bg = C.ground })
hl("StatusLine", { bg = C.ground }); hl("StatusLineNC", { bg = C.ground })
hl("KawaRule", { underline = true, sp = C.edge2 }); hl("KawaMargin", { fg = C.accent, bg = C.ground })
hl("KawaIcon", { fg = C.accent_text, bg = C.ground }); hl("KawaName", { fg = C.strong, bg = C.ground }); hl("KawaStitch", { fg = C.edge2, bg = C.ground })
hl("KawaMuted", { fg = C.muted, bg = C.ground }); hl("KawaDay", { fg = C.accent_text, underline = true, sp = C.edge2 })
local W = vim.o.columns
local function head()
  local right = "No. 37   2026 . 11 . 01"
  local left = "  N  notes "
  local fill = W - #left - #right - 4
  return "%#KawaIcon#  ▤%#KawaName#  notes %#KawaStitch#" .. string.rep("─", fill) .. " %#KawaMuted#" .. right .. "%#TabLineFill#  "
end
vim.o.tabline = head()
vim.o.winbar = " "
vim.o.statusline = " "
vim.o.statuscolumn = "%#KawaMargin#  │ "
local buf = vim.api.nvim_get_current_buf()
local lines = { "2026-10-31 · Sat", "", "tea with the bank at ten — bring the letter", "the chess opening: e4, then the knight before the bishop", "", "2026-11-01 · Sun", "", "a long line to see the wrap: the words go on past the right edge of the page and come back under the margin rule, on the next ruled row", "the last line" }
vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
local ns = vim.api.nvim_create_namespace("page")
local n = vim.api.nvim_buf_line_count(buf)
for i = 0, n - 1 do
  local day = lines[i + 1]:match("^%d%d%d%d%-%d%d%-%d%d")
  vim.api.nvim_buf_set_extmark(buf, ns, i, 0, { line_hl_group = "KawaRule" })
  if day then vim.api.nvim_buf_set_extmark(buf, ns, i, 0, { end_col = #lines[i + 1], hl_group = "KawaDay" }) end
end
local w = vim.api.nvim_win_get_width(0)
local rows = {}
for _ = 1, vim.o.lines do rows[#rows + 1] = { { string.rep(" ", w), "KawaRule" } } end
vim.api.nvim_buf_set_extmark(buf, ns, n - 1, 0, { virt_lines = rows })
local fb = vim.api.nvim_create_buf(false, true)
local foot = "  ~/Notes/notes.md  ·  saved as you go  ·  super+n puts it away"
vim.api.nvim_buf_set_lines(fb, 0, -1, false, { foot })
vim.api.nvim_buf_set_extmark(fb, ns, 0, 0, { end_col = #foot, hl_group = "KawaMuted" })
vim.api.nvim_open_win(fb, false, { relative = "editor", row = vim.o.lines - 1, col = 0, width = W, height = 1, focusable = false, style = "minimal", zindex = 40 })
vim.api.nvim_win_set_cursor(0, { n, #lines[n] })
