-- ~/.config/nvim/lua/config/keymaps.lua — your keys. Each line: the mode (n normal, i insert, x
-- selection), the key, what it does, and the words which-key shows. Neovim's own language keys need
-- no line here: K (what it is), g r n (rename), g r a (a fix), g r r (what uses it), g O (this
-- file's symbols), ] d and [ d (next and previous problem), ] b and [ b (next and previous buffer).
local map = vim.keymap.set
-- The project's folder (the nearest .git above this file), for the finders below.
local root = function() return require("config.root").get() end

-- Esc also clears the marks of the last search.
map("n", "<Esc>", "<Cmd>nohlsearch<CR>", { desc = "clear the search marks" })
-- Ctrl+S saves, in any mode, and leaves you in normal mode.
map({ "n", "i", "x" }, "<C-s>", "<Cmd>write<CR><Esc>", { desc = "save" })
-- Ctrl and a direction goes to the window that way.
map("n", "<C-h>", "<C-w>h", { desc = "the window to the left" })
map("n", "<C-j>", "<C-w>j", { desc = "the window below" })
map("n", "<C-k>", "<C-w>k", { desc = "the window above" })
map("n", "<C-l>", "<C-w>l", { desc = "the window to the right" })
-- Go to where this is defined (the server's answer).
map("n", "gd", vim.lsp.buf.definition, { desc = "go to the definition" })

-- Find: a window with a line to type in and the matches under it (snacks' picker).
map("n", "<leader><space>", function() Snacks.picker.files({ cwd = root() }) end, { desc = "find a file in the project" })
map("n", "<leader>/", function() Snacks.picker.grep({ cwd = root() }) end, { desc = "search the project's text" })
map("n", "<leader>,", function() Snacks.picker.buffers() end, { desc = "switch between open buffers" })
map("n", "<leader>fr", function() Snacks.picker.recent() end, { desc = "recent files" })
map("n", "<leader>fh", function() Snacks.picker.help() end, { desc = "search neovim's help" })
map("n", "<leader>fk", function() Snacks.picker.keymaps() end, { desc = "search every key" })
map("n", "<leader>fd", function() Snacks.picker.diagnostics() end, { desc = "every problem, in a list" })
-- The project as a tree, at the left.
map("n", "<leader>e", function() Snacks.explorer({ cwd = root() }) end, { desc = "the file tree" })

-- Close this buffer, the window stays.
map("n", "<leader>bd", function() Snacks.bufdelete() end, { desc = "close this buffer" })
-- Quit everything (it asks about unsaved work).
map("n", "<leader>qq", "<Cmd>qall<CR>", { desc = "quit everything" })
-- lazygit, in a window over the code.
map("n", "<leader>gg", function() Snacks.lazygit({ cwd = root() }) end, { desc = "lazygit" })
-- A terminal under the code; the same key hides it.
map("n", "<leader>ft", function() Snacks.terminal(nil, { cwd = root() }) end, { desc = "a terminal" })
-- Format this file, whatever its kind has a server for.
map({ "n", "x" }, "<leader>cf", function() vim.lsp.buf.format() end, { desc = "format" })
-- The plugin manager's window.
map("n", "<leader>l", "<Cmd>Lazy<CR>", { desc = "the plugins" })
