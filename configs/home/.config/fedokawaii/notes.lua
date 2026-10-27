-- ~/.config/fedokawaii/notes.lua — the notes window (kawa-notes, Super+N): neovim as a page.
-- Neovim's whole configuration in that window (nvim -u): not LazyVim and its forty plugins,
-- which took most of a second to start for a page of text — so the window has its text the
-- moment it appears, and goes as fast. Kept from the editor: its colours (the gruvbox
-- palette of ~/.config/nvim/lua/plugins/colorscheme.lua, read from there), the system
-- clipboard, the mouse, undo that outlives the window, searches that ignore case. A text screen like every other one
-- (docs/design-system.md §7, screen.sh): along the top its heading — "記  notes ╌╌╌╌" — the
-- kanji in accent_text, the name in text, the stitch in edge2 to the right edge, two columns
-- in; the text four columns in, where a list's rows have their glyph; along the bottom, the
-- footer in muted: the file and the keys, instead of the editor's statusline. The inks are
-- the theme's, read from ~/.config/fedokawaii/current/colors.sh, and again whenever the theme
-- switches.

vim.loader.enable()                        -- (Lua byte-compiled once, read from the cache after)
vim.o.clipboard = "unnamedplus"
vim.o.mouse = "a"
vim.o.undofile = true
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.shortmess = vim.o.shortmess .. "I"   -- (no intro screen)
-- nothing ever written over the footer: with no command line (cmdheight 0, below) neovim
-- prints its messages on the bottom line itself — "-- INSERT --", the keys of a command
-- being typed, "written" after each save, the file's name and size — so while you typed,
-- the footer flickered between them and its own words. None of them is said here
vim.o.showmode = false
vim.o.showcmd = false
vim.o.ruler = false
vim.o.shortmess = vim.o.shortmess .. "WFcsS"
-- the editor's colours: gruvbox with the desktop's palette, as the editor's plugin spec
-- sets it up (its init, then its options) — from the plugin LazyVim keeps; plain colours
-- where it is not installed yet
do
  local dir = vim.fn.stdpath("data") .. "/lazy/gruvbox.nvim"
  local spec = vim.fn.stdpath("config") .. "/lua/plugins/colorscheme.lua"
  if vim.uv.fs_stat(dir) and vim.uv.fs_stat(spec) then
    vim.opt.rtp:prepend(dir)
    local ok = pcall(function()
      local s = dofile(spec)[1]
      s.init()
      require("gruvbox").setup(s.opts)
      vim.cmd.colorscheme("gruvbox")
    end)
    if not ok then vim.cmd.colorscheme("default") end
  end
end

local where = (os.getenv("KAWA_NOTES_WHERE") or "~/Notes/notes.md"):gsub("%%", "%%%%")

local function colours()
  -- the theme's inks (colors.sh, written by tools/build-themes.py): the current one's, or —
  -- no theme switched on yet — the dark one's, from its own file (no colour is written here)
  local c = { GROUND = false, EDGE2 = false, MUTED = false, TEXT = false, ACCENT_TEXT = false }
  local f = io.open(vim.fn.expand("~/.config/fedokawaii/current/colors.sh"))
    or io.open(vim.fn.expand("~/.config/fedokawaii/themes/dark/colors.sh"))
  if f then
    for line in f:lines() do
      local k, v = line:match("^C_([%u%d_]+)=(%x%x%x%x%x%x)")
      if k and c[k] == false then c[k] = v end
    end
    f:close()
  end
  for k, v in pairs(c) do
    if not v then error("notes: the theme has no C_" .. k .. " (~/.config/fedokawaii/current/colors.sh)") end
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
  return "%#KawaGround#  %#KawaMuted#" .. name .. "  ·  saved as you go  ·  super+n puts it away%=%#KawaGround# "
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

-- every change written (`update`: only when there is one) once you pause — a second
-- without a change — and at once as the window is put away (Super+N, Super+Q: dwl puts a warm
-- window away rather than closing it), as you leave the line you type on, or neovim. Only a
-- window ended outright (the session itself ending) within that second loses that second.
-- fsync is off in this window (no wait for the disk on each write; the kernel writes it out
-- within seconds, and kawa-notes has it written out as soon as the window is gone).
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
-- Written when you pause (a second without a change), and at once when you leave the line
-- you type on, the window or neovim — never a write per key, which redrew the page (its
-- footer flickered with every letter)
local pause = vim.uv.new_timer()
local function save_all()   -- the notes, and any other page open here with a change
  save()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if b ~= buf and vim.api.nvim_buf_is_loaded(b) and vim.bo[b].buftype == "" and vim.bo[b].modified
        and vim.api.nvim_buf_get_name(b) ~= "" then
      vim.api.nvim_buf_call(b, function() vim.cmd("silent! update") end)
    end
  end
end
vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
  group = group,
  callback = function(ev)
    if vim.bo[ev.buf].buftype ~= "" then return end
    pause:stop()
    pause:start(1000, 0, vim.schedule_wrap(save_all))
  end,
})
vim.api.nvim_create_autocmd({ "InsertLeave", "FocusLost", "BufLeave", "VimLeavePre" }, {
  group = group,
  callback = function(ev)
    if ev.buf == buf then pause:stop(); return save() end
    -- (another file opened here: saved as you go too, as the line along the bottom says)
    if vim.bo[ev.buf].buftype == "" and vim.api.nvim_buf_get_name(ev.buf) ~= "" then
      vim.api.nvim_buf_call(ev.buf, function() vim.cmd("silent! update") end)
    end
  end,
})

-- A warm window (kawa-warm): put away and shown again, never closed — kawa-warm calls these
-- through the page's socket (kawa-notes --inside listens). Going: saved, then the end of the
-- file tidied (kawa-notes --tidy: no blank lines, no heading left with nothing under it) and
-- taken in. Showing: today's heading (kawa-notes --today) taken in, and the notes (whatever
-- file was open) with the cursor on a fresh line at the end, typing — as the window always opens
local function run(arg)
  vim.fn.system({ "kawa-notes", arg })
  fresh()
end
function _G.kawa_notes_hidden()
  save()
  run("--tidy")
  return ""
end
function _G.kawa_notes_shown()
  save()
  run("--today")
  vim.cmd("silent! wall")                     -- (another file open here: saved, and the notes back)
  vim.api.nvim_win_set_buf(0, buf)
  local n = vim.api.nvim_buf_line_count(buf)
  vim.api.nvim_buf_set_lines(buf, n, n, false, { "" })
  vim.api.nvim_win_set_cursor(0, { n + 1, 0 })
  vim.cmd("startinsert!")
  return ""
end
