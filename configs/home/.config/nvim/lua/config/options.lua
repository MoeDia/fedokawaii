-- ~/.config/nvim/lua/config/options.lua — how the editor behaves. :help 'name' explains any of them.

-- The numbers at the left: this line's own, and the distance to the others (5j lands where it says).
vim.o.number = true
vim.o.relativenumber = true
-- The column for git's and the servers' signs is always there: the text never jumps sideways.
vim.o.signcolumn = "yes"
-- The line the cursor is on stands out.
vim.o.cursorline = true
-- Four lines of air above and below the cursor, eight columns at its sides.
vim.o.scrolloff = 4
vim.o.sidescrolloff = 8
-- Long lines stay one row: code reads better; zh and zl look along them.
vim.o.wrap = false
-- A new window opens below, or to the right; the text of the one you are in does not move for it.
vim.o.splitbelow = true
vim.o.splitright = true
vim.o.splitkeep = "screen"
-- Below the last line of a file: nothing, not a column of ~.
vim.o.fillchars = "eob: ,fold: ,foldsep: ,diff:╱"
-- One status line, for all the windows.
vim.o.laststatus = 3
-- The status line's tile says the mode: neither neovim's own word for it, nor its ruler.
vim.o.showmode = false
vim.o.ruler = false
-- Tabs and spaces at a line's end show (a Tab where spaces were meant is a real bug in Python).
vim.o.list = true
-- A completion menu of ten rows at most.
vim.o.pumheight = 10
-- A long line that does wrap breaks at a word.
vim.o.linebreak = true
-- :grep uses ripgrep; its results go to the quickfix list.
vim.o.grepprg = "rg --vimgrep"
-- The mouse works everywhere.
vim.o.mouse = "a"
-- A Tab is two spaces, in the files that do not say otherwise (Python's and Rust's own say four).
vim.o.expandtab = true
vim.o.shiftwidth = 2
vim.o.tabstop = 2
-- A new line takes the indent the code asks for.
vim.o.smartindent = true
-- A search ignores case, until you type a capital.
vim.o.ignorecase = true
vim.o.smartcase = true
-- Undo survives closing the file.
vim.o.undofile = true
-- Closing unsaved work asks instead of failing.
vim.o.confirm = true
-- The block selection may go past the end of a short line.
vim.o.virtualedit = "block"
-- Markdown's marks vanish on lines the cursor is not on.
vim.o.conceallevel = 2
-- Folds by indent: z c closes, z o opens. Nothing walks the whole file for them, so it opens at
-- once; and every fold starts open.
vim.o.foldmethod = "indent"
vim.o.foldlevelstart = 99
-- A pending key waits 300 ms, then which-key shows what it can become.
vim.o.timeoutlen = 300
-- Git's signs and the swap file are written after 200 ms without a key.
vim.o.updatetime = 200

-- Completion as you type, neovim's own: the server's words first (o), then this file's (.), the
-- other windows' (w) and the open buffers' (b). The menu has one line for each, a window beside it
-- for the details, and nothing is chosen until you ask: Ctrl+N or Ctrl+P moves, Ctrl+Y takes it.
vim.o.autocomplete = true
vim.o.complete = "o,.,w,b"
vim.o.completeopt = "menuone,noselect,fuzzy,popup"

-- No providers for the old remote plugins: nothing here needs Python, Ruby, Perl or Node for that.
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_node_provider = 0

-- Mason's folder comes first on the PATH: the language servers it installed are found by name.
vim.env.PATH = vim.fn.stdpath("data") .. "/mason/bin:" .. vim.env.PATH

-- The clipboard: y copies to the desktop too, deletes stay here, p takes the newest copy
-- (lua/config/clipboard.lua says why).
require("config.clipboard").setup()

-- The command line and the messages: nvim's own ui2 (0.12), and no row given up for them: a message
-- comes and goes above the status line, the command line opens over it, and what is there to be
-- read (:ls, :registers, a shell command's output) stays in a pager, q closes.
require("vim._core.ui2").enable({
  msg = { target = "msg", targets = { list_cmd = "pager", shell_out = "pager", shell_err = "pager" } },
})
vim.o.cmdheight = 0
-- The status line, from the first frame on (lua/config/statusline.lua).
require("config.statusline").setup()

-- The window's title names the program in front, for Super+/ (kawa-help shows its keys first):
-- "nvim", or what runs in the terminal buffer in front (lazygit from Space g g). nvim puts the
-- title it found back as it ends (foot's title stack), so yazi or lazygit that started it is
-- named again.
vim.o.title = true
vim.o.titlestring = "nvim"
local function kawa_title()
  -- (a terminal buffer's name is term://DIR//PID:COMMAND: the program, without its path)
  local buf = vim.api.nvim_get_current_buf()
  local cmd = vim.bo[buf].buftype == "terminal" and vim.api.nvim_buf_get_name(buf):match("^term://.-//%d+:(%S+)")
  local name = cmd and cmd:match("([^/]+)$") or "nvim"
  if vim.o.titlestring ~= name then vim.o.titlestring = name end
end
local group = vim.api.nvim_create_augroup("kawa_title", { clear = true })
vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "TermOpen" }, { group = group, callback = kawa_title })
-- A terminal that ends (q in lazygit) is still the buffer in front as it ends, and its float
-- closes without a BufEnter for the file: the title is read again a tick later.
vim.api.nvim_create_autocmd("TermClose", { group = group, callback = function() vim.schedule(kawa_title) end })
