-- ~/.config/fedokawaii/notes.lua — the notes window (kawa-notes, Super+N): neovim as a page.
-- Run by kawa-notes inside its window (luafile). Like every popup of the desktop it has its
-- title in a rule across the top — "─ ✎ notes · ~/Notes/notes.md ───" — the rule and the
-- file in the terminal's colour 8, the icon in 9 (vermilion), the name in 7: the theme's,
-- read from ~/.config/fedokawaii/current/colors.sh, and again whenever the theme switches.
-- The text starts three columns in, under the icon, as a list's entries do; along the
-- bottom, as every popup has, a quiet line of keys instead of the editor's statusline.

local icon = os.getenv("KAWA_NOTES_ICON") or "✎"
local where = (os.getenv("KAWA_NOTES_WHERE") or "~/Notes/notes.md"):gsub("%%", "%%%%")

local function colours()
  local ground, ansi = "0f0e0c", {}
  local f = io.open(vim.fn.expand("~/.config/fedokawaii/current/colors.sh"))
  if f then
    for line in f:lines() do
      ground = line:match("^C_GROUND=(%x+)") or ground
      local list = line:match('^C_ANSI="([%x ]+)"')
      if list then for hex in list:gmatch("%x+") do ansi[#ansi + 1] = hex end end
    end
    f:close()
  end
  if #ansi < 16 then   -- (the dark theme's, should the file be missing)
    ansi = vim.split("2b2721 d64b4b 8e9a5b d29f45 5f7fa0 9079a9 5e9c95 cfc3a6 7a7262 e66a5f a8b46f e3b866 7f9dbd ab96c2 7fb8b0 ece3cc", " ")
  end
  local g = "#" .. ground
  for name, i in pairs({ KawaRule = 9, KawaIcon = 10, KawaName = 8 }) do   -- (ansi[] counts from 1)
    vim.api.nvim_set_hl(0, name, { fg = "#" .. ansi[i], bg = g })
  end
  vim.api.nvim_set_hl(0, "KawaGround", { bg = g })
  vim.api.nvim_set_hl(0, "StatusLine", { bg = g })
  vim.api.nvim_set_hl(0, "StatusLineNC", { bg = g })
  -- the margin is plain page, not a strip of its own
  vim.api.nvim_set_hl(0, "FoldColumn", { bg = g })
  vim.api.nvim_set_hl(0, "WinBar", { bg = g })
  vim.api.nvim_set_hl(0, "WinBarNC", { bg = g })
end

-- the bottom line, as the other popups' footers: the keys, quiet, under the text's column
-- (the editor's own statusline — lualine — is for code; here it is put away, also after
-- it loads, and after a theme switch sets it up again)
local footer = "%#KawaGround#   %#KawaRule#saved as you type  ·  super+n puts it away%=%#KawaGround# "
local function page_footer()
  pcall(function() require("lualine").hide({ place = { "statusline" }, unhide = false }) end)
  vim.o.laststatus = 2
  vim.o.cmdheight = 0
  vim.wo.statusline = footer
end

colours()
page_footer()
local group = vim.api.nvim_create_augroup("kawa_notes", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", {
  group = group,
  callback = function() colours(); vim.schedule(page_footer) end,
})
vim.api.nvim_create_autocmd("User", {
  group = group, pattern = { "VeryLazy", "LazyLoad" },
  callback = function() vim.defer_fn(page_footer, 30) end,
})

-- a page rather than code: no line numbers, signs, folds or spell marks; three columns of
-- margin (the lists' margin, pointer and gap); long lines wrapped at words
vim.opt_local.number = false
vim.opt_local.relativenumber = false
vim.opt_local.signcolumn = "no"
vim.opt_local.statuscolumn = ""
vim.opt_local.foldcolumn = "3"
vim.opt_local.foldmethod = "manual"
vim.opt_local.foldenable = false
vim.opt_local.spell = false
vim.opt_local.cursorline = false          -- (a page: no bar across it, only the cursor)
vim.opt_local.wrap = true
vim.opt_local.linebreak = true
vim.opt_local.fillchars:append({ wbr = "─" })
vim.opt_local.winbar = " %#KawaRule#─ %#KawaIcon#" .. icon .. " %#KawaName#notes %#KawaRule#· "
  .. where .. " %=%#KawaGround# "

-- every change written at once (`update`: only when there is one): however the window
-- goes, nothing is lost. Super+Q closes the terminal under neovim, which then exits on the
-- spot — no autocommand runs on a hang-up — so a change still waiting for a pause in the
-- typing would be gone. A write per change is cheap here: fsync is off in this window (no
-- wait for the disk on every key; the kernel writes it out within seconds, and kawa-notes
-- has it written out as soon as the window is gone).
vim.o.fsync = false
local buf = vim.api.nvim_get_current_buf()
-- (LazyVim formats a file on every write when a formatter knows it — the Markdown extra
-- does: here that would rewrite the page under your fingers, key by key)
vim.b[buf].autoformat = false
local function save()
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_call(buf, function() vim.cmd("silent! update") end)
  end
end
vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "InsertLeave", "FocusLost", "BufLeave", "VimLeavePre" }, {
  buffer = buf,
  callback = save,
})
