-- ~/.config/fedokawaii/notes.lua — the notes window (kawa-notes, Super+N): neovim as a page.
-- Neovim's whole configuration in that window (nvim -u): not LazyVim and its forty plugins,
-- which took most of a second to start for a page of text — so the window has its text the
-- moment it appears, and goes as fast. Kept from the editor: its colours (the gruvbox
-- palette of ~/.config/nvim/lua/plugins/colorscheme.lua, read from there), the clipboard as
-- the editor keeps it (~/.config/nvim/lua/config/clipboard.lua: a copy goes to the desktop's,
-- what you delete stays here), the mouse, undo that outlives the window, searches that ignore
-- case. A text screen like every other one (docs/design-system.md §7, screen.sh): along the
-- top its heading — the note icon in accent_text, two columns, the name in text, the rule in
-- edge2 to the right edge, two columns in; the text four columns in, where a list's rows have
-- their glyph; along the bottom, the footer in muted: the file and the keys, instead of the
-- editor's statusline. The inks are the theme's, read from ~/.config/fedokawaii/current/
-- colors.sh, and again whenever the theme switches.

vim.loader.enable()                        -- (Lua byte-compiled once, read from the cache after)
-- neovim's new message UI (ui2, 0.12 — its own windows for messages and the command line): with
-- the old message grid and no command line (cmdheight 0, below) every write cleared the line a
-- message would take — the footer — and drew it again a frame later: the footer blinked at each
-- save (seen frame by frame, 1 Nov). The window is otherwise drawn pixel for pixel the same.
-- (a neovim without it keeps the page working; tests/content/test_notes.sh holds the installed
-- one to having it, so an update that drops it is caught, not lived with)
pcall(function() require("vim._core.ui2").enable() end)
dofile(vim.fn.stdpath("config") .. "/lua/config/clipboard.lua").setup()   -- (by its path: any runtime path)
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

local where = os.getenv("KAWA_NOTES_WHERE") or "~/Notes/notes.md"   -- (shown as it is: the footer is a float, no statusline's %)
local ICON_NOTE = "\243\190\128\188" -- Sumi Icons: note (U+FE03C), as in icons.sh
local ICON_TODO = "\243\190\131\140" -- the to-do's tanzaku (U+FE0CC)
local BOX = { [false] = "\243\190\128\179", [true] = "\243\190\128\178" }   -- box-off (U+FE033), box-on (U+FE032)
local TODO = os.getenv("KAWA_TODO") or vim.fn.expand("~/Notes/todo.md")

local function colours()
  -- the theme's inks (colors.sh, written by tools/build-themes.py): the current one's, or —
  -- no theme switched on yet — the dark one's, from its own file (no colour is written here)
  local c = { GROUND = false, EDGE2 = false, MUTED = false, TEXT = false, ACCENT = false, ACCENT_TEXT = false }
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
  for name, k in pairs({ KawaIcon = "ACCENT_TEXT", KawaName = "TEXT", KawaStitch = "EDGE2", KawaMuted = "MUTED" }) do
    vim.api.nvim_set_hl(0, name, { fg = "#" .. c[k], bg = g })
  end
  vim.api.nvim_set_hl(0, "KawaGround", { bg = g })
  -- the paper (T21, .claude/notes/notes-notebook.md): a rule under every row in edge2, the margin
  -- rule in vermilion, a day's line in accent_text on its rule
  vim.api.nvim_set_hl(0, "KawaRule", { underline = true, sp = "#" .. c.EDGE2 })
  vim.api.nvim_set_hl(0, "KawaMargin", { fg = "#" .. c.ACCENT, bg = g })
  vim.api.nvim_set_hl(0, "KawaDay", { fg = "#" .. c.ACCENT_TEXT, underline = true, sp = "#" .. c.EDGE2 })
  vim.api.nvim_set_hl(0, "TabLine", { bg = g }); vim.api.nvim_set_hl(0, "TabLineFill", { bg = g })
  vim.api.nvim_set_hl(0, "TabLineSel", { bg = g }); vim.api.nvim_set_hl(0, "NormalFloat", { bg = g })
  vim.api.nvim_set_hl(0, "KawaDone", { fg = "#" .. c.MUTED, bg = g, strikethrough = true })   -- (a to-do done)
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
local function footer_of(name) return "  " .. name .. "  ·  saved as you go  ·  super+n puts it away" end
local function todo_footer(name, typing)   -- (the keys of the moment: an item typed, or the list)
  return "  " .. name .. (typing and "  ·  esc: the list" or "  ·  space ticks") .. "  ·  tab: the notes"
end
-- the page's foot (T21: margins that never move): no statusline — the window runs to the last
-- row, and two floats lie over its last two: a row of paper, then the footer; scrolloff keeps the
-- pen five rows from the edge — never under the floats, three ruled rows of fresh paper ahead of
-- it as it goes down the page, however far the page scrolls (the play's frames: T21)
local foot = {}
local ROOM = 5                                -- the pen's rows to the window's foot: the floats' two, three of paper
local function foot_rows(text)
  local function float(i, row, line, hl)
    local f = foot[i] or {}
    if not (f.buf and vim.api.nvim_buf_is_valid(f.buf)) then f.buf = vim.api.nvim_create_buf(false, true) end
    vim.api.nvim_buf_set_lines(f.buf, 0, -1, false, { line })
    vim.api.nvim_buf_clear_namespace(f.buf, -1, 0, -1)
    if hl and #line > 2 then vim.api.nvim_buf_set_extmark(f.buf, vim.api.nvim_create_namespace("kawa_foot"), 0, 2, { end_col = #line, hl_group = hl }) end
    local cfg = { relative = "editor", row = row, col = 0, width = vim.o.columns, height = 1, focusable = false, style = "minimal", zindex = 40 }
    if f.win and vim.api.nvim_win_is_valid(f.win) then vim.api.nvim_win_set_config(f.win, cfg)
    else f.win = vim.api.nvim_open_win(f.buf, false, cfg) end
    vim.wo[f.win].winhighlight = "Normal:KawaGround,NormalFloat:KawaGround,EndOfBuffer:KawaGround"
    foot[i] = f
  end
  float(1, vim.o.lines - 2, "", nil)
  float(2, vim.o.lines - 1, text, "KawaMuted")
end
local foot_text = footer_of(where)
local function page_footer()
  pcall(function() require("lualine").hide({ place = { "statusline" }, unhide = false }) end)
  vim.o.laststatus = 0
  vim.o.cmdheight = 0
  vim.o.scrolloff = ROOM
  foot_rows(foot_text)
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
-- (the page shows what was typed: no markdown highlighting, so none of its conceal — a "[ ]", a
-- link's address, "**" stay as written (the master, 2 Nov); tree-sitter's stop brings the old
-- syntax back, so that goes off after it. Conceal hides a day's "## " alone: the rules' extmark.
-- Again after a reload — the day's heading written by kawa-notes is one —: the reload's FileType
-- starts markdown's highlighting anew)
local function plain(b)
  pcall(vim.treesitter.stop, b)
  vim.bo[b].syntax = "OFF"
end
local function page()
  local b = vim.api.nvim_get_current_buf()
  if vim.bo[b].buftype ~= "" then return end
  vim.opt_local.number = false
  vim.opt_local.relativenumber = false
  vim.opt_local.signcolumn = "no"
  -- the margin: two columns of paper, the vermilion rule, a column — the words at the fourth, where
  -- a list row's glyph stands (as the fold column's four did); drawn on the ruled rows below the
  -- text too (statuscolumn runs for virtual lines)
  vim.opt_local.statuscolumn = "%#KawaGround#  %#KawaMargin#│%#KawaGround# "
  vim.opt_local.foldcolumn = "0"
  vim.opt_local.foldmethod = "manual"
  vim.opt_local.foldenable = false
  vim.opt_local.spell = false
  vim.opt_local.cursorline = false          -- (a page: no bar across it, only the cursor)
  vim.opt_local.wrap = true
  vim.opt_local.linebreak = true
  vim.opt_local.fillchars:append({ wbr = " ", eob = " " })   -- (no ~ under the last line: a page ends in paper)
  local name = b == notes and where or vim.fn.fnamemodify(vim.api.nvim_buf_get_name(b), ":~")
  local is_todo = vim.api.nvim_buf_get_name(b) == TODO
  plain(b)
  vim.opt_local.conceallevel = 2
  vim.opt_local.concealcursor = "n"
  -- (the heading in the tabline — the editor's top row, never scrolled — and a blank winbar under
  -- it: the §3 blank line, there at every scroll position)
  -- (the tabline fills %= with spaces, not the winbar's ─: the rule is drawn out, edge2, from after
  -- the name to the page's right edge, where the paper's rules end too — a notebook's lines run to
  -- its edge — again at each resize)
  local icon, word = is_todo and ICON_TODO or ICON_NOTE, is_todo and "to-do" or "notes"
  local n = vim.o.columns - vim.api.nvim_strwidth("  " .. icon .. "  " .. word .. " ")
  vim.o.showtabline = 2
  vim.o.tabline = "%#KawaGround#  %#KawaIcon#" .. icon .. "%#KawaGround#  %#KawaName#" .. word
    .. " %#KawaStitch#" .. string.rep("─", math.max(2, n))
  vim.opt_local.winbar = "%#KawaGround# "
  foot_text = is_todo and todo_footer(name, vim.api.nvim_get_mode().mode:sub(1, 1) == "i") or footer_of(name)
  foot_rows(foot_text)
  -- (LazyVim formats a file on every write when a formatter knows it — the Markdown extra
  -- does: here that would rewrite the page under your fingers, key by key)
  vim.b[b].autoformat = false
end
-- the paper's rules (T21, .claude/notes/notes-notebook.md): every line ruled across the whole
-- row (line_hl_group: wrapped rows too), the page below the last line ruled to its foot
-- (virt_lines, as many as the screen has rows — the window's are fewer: never short of paper); a
-- day's line ("## 2026-11-01 · Sun", as the file keeps it) its date in accent_text, the "## "
-- hidden. The whole page laid again when the count
-- of lines changes (14 000 lines take 3.9 ms, measured), else the line typed on alone — a day's
-- line edited in place keeps its look whole. Laid before the screen is drawn: on each change
-- (TextChanged/I) and right after the window's own edits (a start's -c precedes TextChanged)
local rules = vim.api.nvim_create_namespace("kawa_rules")
local DAY = "^## %d%d%d%d%-%d%d%-%d%d"          -- a day's line, as kawa-notes writes it
local ruled = {}                              -- buffer → the line count its rules were laid for
-- The page under the last line: one mark per buffer, held at the last line's END —
-- and moved there INSIDE every change that makes a new last line (on_lines, before the command
-- works out its view): o, p, :put, Go add a line after the last, below the mark, and the command's
-- own scroll would see the pen forty rows down and jump the page (the master, 2 Nov: verdict 2's
-- must-fix 1; a Return at the end splits the line, which takes the mark along by itself)
-- (a namespace of its own: a clear of the rules never takes the paper, nor gives its id to a rule)
local paperns = vim.api.nvim_create_namespace("kawa_paper")
local paper, attached, sheet = {}, {}, { cols = 0, lines = 0 }
local seen_top = {}                           -- window → its top line at the last look (keep_room, below)
local function rows()                         -- the paper's virtual rows, as many as the screen has
  if sheet.cols ~= vim.o.columns or sheet.lines ~= vim.o.lines then
    local row = { { string.rep(" ", vim.o.columns), "KawaRule" } }
    sheet = { cols = vim.o.columns, lines = vim.o.lines }
    for i = 1, vim.o.lines do sheet[i] = row end
  end
  return { unpack(sheet, 1, sheet.lines) }
end
local function to_end(b)                      -- the paper under the last line, as it is now — the one paper
  local n = vim.api.nvim_buf_line_count(b)      -- (a reload strands a mark: never two); left as it is when
  local line = vim.api.nvim_buf_get_lines(b, n - 1, n, false)[1] or ""   -- it is there already (laid again,
  local size = vim.o.columns .. "x" .. vim.o.lines                       -- the window scrolled a second row)
  local at = paper[b] and vim.api.nvim_buf_get_extmark_by_id(b, paperns, paper[b].id, {}) or {}
  if at[1] == n - 1 and at[2] == #line and paper[b].size == size then return end
  vim.api.nvim_buf_clear_namespace(b, paperns, 0, -1)
  paper[b] = { id = vim.api.nvim_buf_set_extmark(b, paperns, n - 1, #line, { virt_lines = rows() }), size = size }
end
local function lay(b, r, line, last)          -- one line's marks: its rule, a day's date, the page under the last
  vim.api.nvim_buf_set_extmark(b, rules, r, 0, { line_hl_group = "KawaRule" })
  if line:match(DAY) then
    vim.api.nvim_buf_set_extmark(b, rules, r, 0, { end_col = 3, conceal = "" })
    vim.api.nvim_buf_set_extmark(b, rules, r, 3, { end_col = #line, hl_group = "KawaDay", priority = 200 })
  end
  if last then to_end(b) end
end
local function rule(b, force)
  if not vim.api.nvim_buf_is_loaded(b) or vim.bo[b].buftype ~= "" then return end   -- (at -u time the file is not read yet: BufWinEnter lays them)
  if not attached[b] then
    attached[b] = true
    vim.api.nvim_buf_attach(b, false, {
      on_lines = function(_, buf, _, _, last_old, last_new)
        if last_new ~= last_old and paper[buf] then to_end(buf) end
      end,
      on_detach = function(_, buf) attached[buf], paper[buf], ruled[buf] = nil, nil, nil end,
    })
  end
  local n = vim.api.nvim_buf_line_count(b)
  if force or ruled[b] ~= n then
    ruled[b] = n
    vim.api.nvim_buf_clear_namespace(b, rules, 0, -1)
    for i, line in ipairs(vim.api.nvim_buf_get_lines(b, 0, -1, false)) do lay(b, i - 1, line, i == n) end
  elseif b == vim.api.nvim_get_current_buf() then
    local r = vim.api.nvim_win_get_cursor(0)[1] - 1
    vim.api.nvim_buf_clear_namespace(b, rules, r, r + 1)
    lay(b, r, vim.api.nvim_buf_get_lines(b, r, r + 1, false)[1], r == n - 1)
  end
end
-- The page moves by LINES (a notebook's: a wrapped line leaves the top whole, two rows at once),
-- here and in neovim's own scrolling alike.
-- the pen above the floats, paper ahead: a resize (the window's first size reaches neovim after it
-- started) keeps the cursor's place as a fraction of the window, not scrolloff — so the page is
-- moved up until the pen has its rows again (the master, 2 Nov: a start on a written day)
local function pen_room()
  for _ = 1, vim.o.lines do
    if vim.fn.winline() <= vim.fn.winheight(0) - ROOM then return end   -- (first: the view as it stands)
    local v = vim.fn.winsaveview()
    if v.topline >= v.lnum then return end
    v.topline = v.topline + 1
    vim.fn.winrestview(v)
  end
end
-- the page opens on a day's line (the master, 2 Nov: never mid-day): the latest day whose line
-- leaves the pen its room above it as well (scrolloff keeps ROOM rows on both sides) — today's
-- own line when today fills that much, else the day before it and so on — on the page's first
-- row; the pen's room below kept first: a day too long for it opens as the pen needs (pen_room)
local function on_day()
  local pen = vim.fn.line(".")
  local lines = vim.api.nvim_buf_get_lines(0, 0, pen - 1, false)
  for i = #lines, 1, -1 do
    if i == 1 or lines[i]:match(DAY) then
      local above = vim.api.nvim_win_text_height(0, { start_row = i - 1, end_row = pen - 2 }).all
      if above + 1 > vim.fn.winheight(0) - ROOM then break end
      if above >= ROOM or i == 1 then vim.fn.winrestview({ topline = i, topfill = 0 }); return end
    end
  end
  pen_room()
end
page()
rule(notes, true)
vim.api.nvim_create_autocmd("BufWinEnter", {
  group = group, callback = function(ev) page(); rule(ev.buf, true); seen_top[vim.api.nvim_get_current_win()] = nil end,
})
vim.api.nvim_create_autocmd("FileChangedShellPost", { group = group, callback = function(ev) plain(ev.buf); rule(ev.buf, true) end })
-- after every change and every move, the pen keeps its room: scrolloff alone keeps it for a step of
-- one row, but a jump to the end — a paste, lines given at once, the to-do opened at its end — lands
-- the pen on the window's last row, under the floats, and scrolloff keeps it there (the master, 2 Nov:
-- verdict 2's must-fix 2). (Safe since the paper moves inside the change: asking the pen's row then
-- never sees a new line below the old paper)
-- A scroll he made is his (the master, verdict 4): when the page went UP since the last look —
-- only he scrolls it up: Ctrl+Y, Ctrl+B, the wheel — the view stays and the PEN yields, up a line
-- at a time into its room; otherwise the view follows the pen (pen_room). Neovim's own scrolloff
-- does the same, but the paper's rows meet it under the floats. (Another page in the window, or its
-- own opening, is no scroll of his: forgotten there.)
local function pen_yield()
  local room = vim.fn.winheight(0) - ROOM
  for _ = 1, vim.o.lines do
    local r, c = unpack(vim.api.nvim_win_get_cursor(0))
    if vim.fn.winline() <= room or r <= vim.fn.line("w0") then return end
    local up = vim.api.nvim_buf_get_lines(0, r - 2, r - 1, false)[1] or ""
    vim.api.nvim_win_set_cursor(0, { r - 1, math.min(c, #up) })
  end
end
local function keep_room()
  local w, top = vim.api.nvim_get_current_win(), vim.fn.line("w0")
  if seen_top[w] and top < seen_top[w] then pen_yield() else pen_room() end
  seen_top[w] = vim.fn.line("w0")
end
-- (a typed key is a change, never a scroll of his: CursorMovedI follows the pen; and the TextChanged
-- that leaving typing brings, with no new change in it, is only a look — the master, verdict 5)
local ticks = {}
local function follow()
  pen_room()
  seen_top[vim.api.nvim_get_current_win()] = vim.fn.line("w0")
end
vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
  group = group,
  callback = function(ev)
    rule(ev.buf)
    if ev.buf ~= vim.api.nvim_get_current_buf() then return end
    local tick = vim.b[ev.buf].changedtick
    if ticks[ev.buf] == tick then keep_room() else follow() end
    ticks[ev.buf] = tick
  end,
})
-- (leaving typing after a wheel up — the wheel moves no pen in typing, nor tells anyone: neovim's
-- own check as typing ends would scroll the page back to the pen; the pen yields first, its row
-- counted without that check)
vim.api.nvim_create_autocmd("InsertLeave", {
  group = group,
  callback = function(ev)
    ticks[ev.buf] = vim.b[ev.buf].changedtick
    local w, top = vim.api.nvim_get_current_win(), vim.fn.winsaveview().topline
    if not (seen_top[w] and top < seen_top[w]) then return end
    local room, r = vim.fn.winheight(0) - ROOM, vim.api.nvim_win_get_cursor(0)[1]
    while r > top and vim.api.nvim_win_text_height(0, { start_row = top - 1, end_row = r - 1 }).all > room do r = r - 1 end
    if r ~= vim.api.nvim_win_get_cursor(0)[1] then vim.api.nvim_win_set_cursor(0, { r, 0 }) end
    seen_top[w] = top
  end,
})
vim.api.nvim_create_autocmd("CursorMovedI", { group = group, callback = follow })
vim.api.nvim_create_autocmd({ "CursorMoved", "WinScrolled" }, { group = group, callback = keep_room })
vim.api.nvim_create_autocmd("VimResized", {
  group = group,
  callback = function()   -- (the pen at the notes' end, as they open: on a day's line again)
    page(); rule(vim.api.nvim_get_current_buf(), true)
    if vim.api.nvim_get_current_buf() == notes and vim.fn.line(".") == vim.fn.line("$") then on_day() else pen_room() end
  end,
})

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
local todo_open, todo_tidy                  -- (the to-do's, below)
local function notes_open()                 -- the page turned back: the notes, typing at their end
  todo_tidy()
  vim.api.nvim_win_set_buf(0, buf)
  rule(buf)
  local n = vim.api.nvim_buf_line_count(buf)
  vim.api.nvim_win_set_cursor(0, { n, #vim.api.nvim_buf_get_lines(buf, n - 1, n, false)[1] })
  on_day()
  vim.cmd("startinsert!")
end
function _G.kawa_notes_hidden()
  todo_tidy()
  save_all()
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
  rule(buf)
  vim.api.nvim_win_set_cursor(0, { n + 1, 0 })
  on_day()
  vim.cmd("startinsert!")
  return ""
end

-- ── the to-do (owner 2026-10-25 18:48): a page beside the notes — dead simple: things to do,
-- each with a box; done ones struck through; nothing else (no dates, no reminders). One file,
-- ~/Notes/todo.md, a line a thing: "[ ] call the bank", "[x] buy rice" (readable anywhere). The
-- page draws the box over those four characters — on the notes' text column, the words two
-- columns after it, as a list row's glyph and name stand (docs/design-system.md §7). Tab (not
-- typing) turns from one page to the other. The to-do opens as the notes do: typing, on a fresh
-- item at its end (the master, 2 Nov: the first key a word, never a command); esc or an empty
-- item's enter gives the list — an item left with no words goes —, where space ticks or unticks,
-- enter adds one under the cursor, dd takes one away. Tab is its only way in (owner, 1 Nov:
-- Super+N alone, never Super+U). Saved as you go, as the notes are.
local ns = vim.api.nvim_create_namespace("kawa_todo")
local todo                                  -- its buffer, once opened
local ITEM = "^%[([ xX])%] "                -- an item: its box, a space, its words
local function todo_marks()
  if not (todo and vim.api.nvim_buf_is_valid(todo)) then return end
  vim.api.nvim_buf_clear_namespace(todo, ns, 0, -1)
  for i, line in ipairs(vim.api.nvim_buf_get_lines(todo, 0, -1, false)) do
    local m = line:match(ITEM)
    if m then
      local done = m ~= " "
      -- (the icon one cell, drawn across two — foot's overflow into the space after it —, then two of air)
      vim.api.nvim_buf_set_extmark(todo, ns, i - 1, 0, {
        virt_text = { { BOX[done], done and "KawaMuted" or "KawaIcon" }, { "   ", "KawaGround" } },
        virt_text_pos = "overlay",
      })
      if done and #line > 4 then
        vim.api.nvim_buf_set_extmark(todo, ns, i - 1, 4, { end_col = #line, hl_group = "KawaDone" })
      end
    end
  end
end
local function item_at(row)                 -- the line, and whether it is an item
  local line = vim.api.nvim_buf_get_lines(todo, row - 1, row, false)[1] or ""
  return line, line:match(ITEM) ~= nil
end
local function new_item(row, words)         -- an item put in after line ROW, typing at its words
  local empty = vim.api.nvim_buf_line_count(todo) == 1 and item_at(1) == ""
  if empty then row = 0 end                 -- (an empty page: its one line becomes the item)
  vim.api.nvim_buf_set_lines(todo, row, empty and 1 or row, false, { "[ ] " .. (words or "") })
  if vim.api.nvim_get_mode().mode:sub(1, 1) == "i" then
    vim.api.nvim_win_set_cursor(0, { row + 1, 4 })
  else                                      -- (from the page: typing at its end, after the box)
    vim.api.nvim_win_set_cursor(0, { row + 1, 0 })
    vim.cmd("startinsert!")
  end
end
todo_tidy = function()                      -- an item with no words goes (an enter too many)
  if not (todo and vim.api.nvim_buf_is_valid(todo)) then return end
  local lines = vim.api.nvim_buf_get_lines(todo, 0, -1, false)
  for i = #lines, 1, -1 do
    if lines[i]:match("^%[[ xX]%] *$") then vim.api.nvim_buf_set_lines(todo, i - 1, i, false, {}) end
  end
end
todo_open = function()
  if not (todo and vim.api.nvim_buf_is_valid(todo)) then
    vim.fn.mkdir(vim.fs.dirname(TODO), "p")
    todo = vim.fn.bufadd(TODO)
    vim.fn.bufload(todo)
    vim.bo[todo].buflisted = true
    local k = function(lhs, fn, modes) vim.keymap.set(modes or "n", lhs, fn, { buffer = todo, nowait = true }) end
    k("<Space>", function()                  -- tick or untick (a line of words: made an item)
      local r = vim.api.nvim_win_get_cursor(0)[1]
      local line, is = item_at(r)
      if is then
        local m = line:match(ITEM)
        vim.api.nvim_buf_set_text(todo, r - 1, 1, r - 1, 2, { m == " " and "x" or " " })
      elseif line:match("%S") then
        vim.api.nvim_buf_set_text(todo, r - 1, 0, r - 1, 0, { "[ ] " })
      end
    end)
    k("<CR>", function() new_item(vim.api.nvim_win_get_cursor(0)[1]) end)
    k("o", function() new_item(vim.api.nvim_win_get_cursor(0)[1]) end)
    k("O", function() new_item(vim.api.nvim_win_get_cursor(0)[1] - 1) end)
    -- typing: enter gives the next item (the words after the cursor go with it); on an empty one
    -- the list ends; backspace never goes into the box — on an empty item it takes the item
    -- away and goes on at the end of the one before. (Keys returned, not typed again: they act
    -- in their place, however fast the keys come)
    local function at() local r, c = unpack(vim.api.nvim_win_get_cursor(0)); return r, c, item_at(r) end
    _G.kawa_todo = {
      enter = function()
        local r, c, line = at()
        if not line:sub(5):match("%S") then
          vim.api.nvim_buf_set_lines(todo, r - 1, r, false, {})
          return vim.cmd("stopinsert")
        end
        -- (split at the cursor: no space left at the end of one or the start of the other)
        local head = line:sub(1, 4) .. line:sub(5, c):gsub("%s+$", "")
        vim.api.nvim_buf_set_lines(todo, r - 1, r, false, { head })
        new_item(r, (line:sub(c + 1):gsub("^%s+", "")))
      end,
      back = function()
        local r, _, line = at()
        if not line:sub(5):match("%S") and r > 1 then
          vim.api.nvim_buf_set_lines(todo, r - 1, r, false, {})
          local prev = vim.api.nvim_buf_get_lines(todo, r - 2, r - 1, false)[1]
          vim.api.nvim_win_set_cursor(0, { r - 1, #prev })
        end
      end,
    }
    vim.keymap.set("i", "<CR>", function()
      local _, _, _, is = at()
      return is and "<Cmd>lua kawa_todo.enter()<CR>" or "<CR>"
    end, { buffer = todo, expr = true })
    vim.keymap.set("i", "<BS>", function()
      local _, c, _, is = at()
      if is and c <= 4 then return "<Cmd>lua kawa_todo.back()<CR>" end
      return "<BS>"
    end, { buffer = todo, expr = true })
    -- the cursor never on the box: on an item it stays at its words
    local function off_box()
      local r, c = unpack(vim.api.nvim_win_get_cursor(0))
      local _, is = item_at(r)
      if is and c < 4 then vim.api.nvim_win_set_cursor(0, { r, 4 }) end
    end
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, { group = group, buffer = todo, callback = off_box })
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufEnter" }, {
      group = group, buffer = todo, callback = todo_marks,
    })
    vim.keymap.set({ "n", "i" }, "<Tab>", notes_open, { buffer = todo })
    -- typing ended: an item left with no words goes; the footer names the keys of the moment
    vim.api.nvim_create_autocmd("InsertLeave", {
      group = group, buffer = todo, callback = function() todo_tidy(); todo_marks(); rule(todo); off_box() end,
    })
    vim.api.nvim_create_autocmd("ModeChanged", {
      group = group, buffer = todo,
      callback = function()
        foot_text = todo_footer(vim.fn.fnamemodify(TODO, ":~"), vim.api.nvim_get_mode().mode:sub(1, 1) == "i")
        foot_rows(foot_text)
      end,
    })
  end
  vim.api.nvim_win_set_buf(0, todo)
  todo_tidy()
  new_item(vim.api.nvim_buf_line_count(todo))   -- (a fresh one at the end, typing: as the notes open)
  todo_marks()
  rule(todo)
  vim.cmd("startinsert!")
end
-- tab turns the page, typing or not (the notes open typing: a tab there would be typed)
vim.keymap.set({ "n", "i" }, "<Tab>", function() todo_open() end, { buffer = buf })