-- ~/.config/fedokawaii/notes.lua — the notes window (kawa-notes, Super+N): neovim as a page.
-- Run by kawa-notes inside its window (luafile). A text screen like every other one
-- (docs/design-system.md §7, screen.sh): along the top its heading — "記  notes ╌╌╌╌" — the
-- kanji in accent_text, the name in text, the stitch in edge2 to the right edge, two columns
-- in; the text four columns in, where a list's rows have their glyph; along the bottom, the
-- footer in muted: the file and the keys, instead of the editor's statusline. The inks are
-- the theme's, read from ~/.config/fedokawaii/current/colors.sh, and again whenever the theme
-- switches.

local where = (os.getenv("KAWA_NOTES_WHERE") or "~/Notes/notes.md"):gsub("%%", "%%%%")

local function colours()
  -- (the dark theme's, should the file be missing)
  local c = { GROUND = "0f0e0c", EDGE2 = "3d372f", MUTED = "877f6f", TEXT = "cfc3a6", ACCENT_TEXT = "d15b3d" }
  local f = io.open(vim.fn.expand("~/.config/fedokawaii/current/colors.sh"))
  if f then
    for line in f:lines() do
      local k, v = line:match("^C_([%u_]+)=(%x%x%x%x%x%x)")
      if k and c[k] then c[k] = v end
    end
    f:close()
  end
  local g = "#" .. c.GROUND
  for name, k in pairs({ KawaKanji = "ACCENT_TEXT", KawaName = "TEXT", KawaStitch = "EDGE2", KawaMuted = "MUTED" }) do
    vim.api.nvim_set_hl(0, name, { fg = "#" .. c[k], bg = g })
  end
  vim.api.nvim_set_hl(0, "KawaGround", { bg = g })
  vim.api.nvim_set_hl(0, "StatusLine", { bg = g })
  vim.api.nvim_set_hl(0, "StatusLineNC", { bg = g })
  -- the margin is plain page, not a strip of its own
  vim.api.nvim_set_hl(0, "FoldColumn", { bg = g })
  vim.api.nvim_set_hl(0, "WinBar", { bg = g })
  vim.api.nvim_set_hl(0, "WinBarNC", { bg = g })
end

-- the bottom line, as every text screen's footer: the file and the keys, muted, two columns
-- in (the editor's own statusline — lualine — is for code; here it is put away, also after
-- it loads, and after a theme switch sets it up again)
local function footer_of(name)
  return "%#KawaGround#  %#KawaMuted#" .. name .. "  ·  saved as you type  ·  super+n puts it away%=%#KawaGround# "
end
local footer = footer_of(where)
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

-- a page rather than code: no line numbers, signs, folds or spell marks; four columns of
-- margin (where a list row's glyph stands: the margin, the cursor's column, two spaces); long lines wrapped at words. Another file
-- opened in the window (:e ~/Notes/japan-trip.md) is a page too, its name in the footer
local notes = vim.api.nvim_get_current_buf()
local function page()
  local b = vim.api.nvim_get_current_buf()
  if vim.bo[b].buftype ~= "" then return end
  vim.opt_local.number = false
  vim.opt_local.relativenumber = false
  vim.opt_local.signcolumn = "no"
  vim.opt_local.statuscolumn = ""
  vim.opt_local.foldcolumn = "4"
  vim.opt_local.foldmethod = "manual"
  vim.opt_local.foldenable = false
  vim.opt_local.spell = false
  vim.opt_local.cursorline = false          -- (a page: no bar across it, only the cursor)
  vim.opt_local.wrap = true
  vim.opt_local.linebreak = true
  vim.opt_local.fillchars:append({ wbr = "╌" })
  local name = b == notes and where
    or vim.fn.fnamemodify(vim.api.nvim_buf_get_name(b), ":~"):gsub("%%", "%%%%")
  -- (the stitch: the winbar's fill, ╌ in edge2, from after the name to two columns short of the edge)
  vim.opt_local.winbar = "%#KawaGround#  %#KawaKanji#記%#KawaGround#  %#KawaName#notes %#KawaStitch#%=%#KawaGround#  "
  vim.wo.statusline = footer_of(name)
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
