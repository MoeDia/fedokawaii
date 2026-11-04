-- ~/.config/nvim/lua/config/options.lua — read by LazyVim after its own options: ours win.
-- The clipboard: copies (y) to the desktop's, deletes kept in the editor, p the newest copy
-- wherever it was made (config/clipboard.lua: why)
require("config.clipboard").setup()

-- The command line and the messages: nvim's own ui2 (0.12), no plugin in between, and no row given
-- up for them: a message comes and goes above the status line, the command line opens over it
require("vim._core.ui2").enable({ msg = { target = "msg" } })
vim.o.cmdheight = 0
-- The status line, from the first frame on (config/statusline.lua)
require("config.statusline").setup()

-- The window's title names the program in front, for Super+/ (kawa-help shows its keys first):
-- "nvim", or what runs in the terminal buffer in front (lazygit from Space g g). nvim puts the
-- title it found back as it ends (foot's title stack), so yazi or lazygit that started it is
-- named again
vim.o.title = true
vim.o.titlestring = "nvim"
local function kawa_title()
  -- (a terminal buffer's name is term://DIR//PID:COMMAND — the program, without its path)
  local buf = vim.api.nvim_get_current_buf()
  local cmd = vim.bo[buf].buftype == "terminal" and vim.api.nvim_buf_get_name(buf):match("^term://.-//%d+:(%S+)")
  local name = cmd and cmd:match("([^/]+)$") or "nvim"
  if vim.o.titlestring ~= name then vim.o.titlestring = name end
end
local group = vim.api.nvim_create_augroup("kawa_title", { clear = true })
vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "TermOpen" }, { group = group, callback = kawa_title })
-- a terminal that ends (q in lazygit) is still the buffer in front as it ends, and its float
-- closes without a BufEnter for the file: the title is read again a tick later
vim.api.nvim_create_autocmd("TermClose", { group = group, callback = function() vim.schedule(kawa_title) end })
