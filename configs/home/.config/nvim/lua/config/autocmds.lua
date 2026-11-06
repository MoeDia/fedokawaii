-- ~/.config/nvim/lua/config/autocmds.lua — what happens by itself when something happens.
local group = vim.api.nvim_create_augroup("kawa", { clear = true })
local on = vim.api.nvim_create_autocmd

-- What you copy flashes for a moment.
on("TextYankPost", { group = group, callback = function() vim.hl.on_yank() end })

-- A file changed outside neovim (git, a formatter) is read again when you come back to the window.
on({ "FocusGained", "TermClose", "TermLeave" }, { group = group, command = "checktime" })

-- A file opens with the cursor where you left it.
on("BufReadPost", {
  group = group,
  callback = function(ev)
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(ev.buf) then pcall(vim.api.nvim_win_set_cursor, 0, mark) end
  end,
})

-- Saving into a folder that does not exist yet makes the folder.
on("BufWritePre", {
  group = group,
  callback = function(ev)
    if not ev.match:match("^%w+://") then vim.fn.mkdir(vim.fn.fnamemodify(ev.match, ":p:h"), "p") end
  end,
})

-- Typing in a Markdown file (lua/config/markdown.lua): set up with the first such file.
on({ "BufReadPre", "BufNewFile" }, {
  group = group,
  pattern = { "*.md", "*.markdown" },
  once = true,
  callback = function() require("config.markdown").setup() end,
})

-- Colours by the code's real structure: treesitter starts on any kind of file with a parser (pcall:
-- most kinds of file have none, and that is no error).
on("FileType", { group = group, callback = function(ev) pcall(vim.treesitter.start, ev.buf) end })

-- The language servers, with the first file of a kind that has one: a text file or a commit message
-- never pays for them. A tick later: the file's first frame does not wait (lua/config/lsp.lua).
on("FileType", {
  group = group,
  pattern = { "python", "rust", "lua", "toml" },
  once = true,
  callback = function() vim.schedule(function() require("config.lsp") end) end,
})
