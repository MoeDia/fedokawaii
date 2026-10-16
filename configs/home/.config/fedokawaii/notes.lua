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
-- margin (the lists' margin, pointer and gap); long lines wrapped at words. Another file
-- opened in the window (:e ~/Notes/japan-trip.md) is a page too, its name in the rule
local notes = vim.api.nvim_get_current_buf()
local function page()
  local b = vim.api.nvim_get_current_buf()
  if vim.bo[b].buftype ~= "" then return end
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
  local name = b == notes and where
    or vim.fn.fnamemodify(vim.api.nvim_buf_get_name(b), ":~"):gsub("%%", "%%%%")
  vim.opt_local.winbar = " %#KawaRule#─ %#KawaIcon#" .. icon .. " %#KawaName#notes %#KawaRule#· "
    .. name .. " %=%#KawaGround# "
  vim.wo.statusline = footer
  -- (LazyVim formats a file on every write when a formatter knows it — the Markdown extra
  -- does: here that would rewrite the page under your fingers, key by key)
  vim.b[b].autoformat = false
end
page()
vim.api.nvim_create_autocmd("BufWinEnter", { group = group, callback = function() page() end })

-- every change written at once (`update`: only when there is one): however the window
-- goes, nothing is lost. Super+Q closes the terminal under neovim, which then exits on the
-- spot — no autocommand runs on a hang-up — so a change still waiting for a pause in the
-- typing would be gone. A write per change is cheap here: fsync is off in this window (no
-- wait for the disk on every key; the kernel writes it out within seconds, and kawa-notes
-- has it written out as soon as the window is gone).
vim.o.fsync = false
local buf = notes

-- the notes changed elsewhere while the window is open (a sync tool, another editor, a
-- line added from a shell): the page takes the change in at once, and a write never stops
-- to ask "the file has been changed — write anyway? (y/n)" (that question would eat the
-- next key, and either answer loses something). A change that lands in the very moment
-- you type wins over that one key. Deleted elsewhere: the page stays, and the next write
-- puts the file back.
vim.o.autoread = true
local real = vim.uv.fs_realpath(vim.api.nvim_buf_get_name(buf))
local function stamp()   -- the file as it is on disk now: when, and how big
  local st = real and vim.uv.fs_stat(real)
  return st and string.format("%d.%d:%d", st.mtime.sec, st.mtime.nsec, st.size) or ""
end
local seen = stamp()     -- …as this window last wrote or read it
local function fresh()   -- take in what changed on disk (nothing happens when nothing did)
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_call(buf, function() vim.cmd("silent! checktime") end)
    seen = stamp()
  end
end
vim.api.nvim_create_autocmd("FileChangedShell", {
  buffer = buf,
  callback = function() vim.v.fcs_choice = vim.v.fcs_reason == "deleted" and "" or "reload" end,
})
vim.api.nvim_create_autocmd("BufWritePost", { buffer = buf, callback = function() seen = stamp() end })
-- (the folder is watched, not the file: a sync tool puts a new file in its place)
local watch = real and vim.uv.new_fs_event()
if watch then
  local name = vim.fs.basename(real)
  watch:start(vim.fs.dirname(real), {}, function(err, file)
    if not err and file == name then vim.schedule(fresh) end
  end)
end

local function save()
  if not vim.api.nvim_buf_is_valid(buf) then return end
  -- (written elsewhere since: taken in first — after this key's event, as neovim checks a
  -- file only then)
  if stamp() ~= seen then return vim.schedule(function() fresh(); save() end) end
  vim.api.nvim_buf_call(buf, function() vim.cmd("silent! update") end)
end
vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "InsertLeave", "FocusLost", "BufLeave", "VimLeavePre" }, {
  group = group,
  callback = function(ev)
    if ev.buf == buf then return save() end
    -- (another file opened here: saved as you type too, as the line along the bottom says)
    if vim.bo[ev.buf].buftype == "" and vim.api.nvim_buf_get_name(ev.buf) ~= "" then
      vim.api.nvim_buf_call(ev.buf, function() vim.cmd("silent! update") end)
    end
  end,
})
