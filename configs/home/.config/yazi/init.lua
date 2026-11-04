-- ~/.config/yazi/init.lua — yazi's frame in the desktop's measure (theme.sh installs it).
-- For yazi 26.x. Each change wraps yazi's own component and steps aside if that changes.

-- Never an ellipsis (the desktop's rule): a name, a folder, a title too long for its room is
-- cut there, nothing put in its place — yazi's own "…" (and "….ext") are taken out.
-- cut(TEXT, MAX, FROM_END) → TEXT in MAX columns or fewer, its end (or, FROM_END, its start) cut
local function wide(s) return ui.Line { s }:width() end
local function cut(s, max, from_end)
	if wide(s) <= max then return s end
	local cps = {}
	for _, c in utf8.codes(s) do cps[#cps + 1] = utf8.char(c) end
	local keep, w = {}, 0
	for k = 1, #cps do
		local c = cps[from_end and #cps + 1 - k or k]
		w = w + wide(c)
		if w > max then break end
		keep[#keep + 1] = c
	end
	if from_end then
		for i = 1, #keep // 2 do keep[i], keep[#keep + 1 - i] = keep[#keep + 1 - i], keep[i] end
	end
	return table.concat(keep)
end
function Entity:ellipsis() return "" end

-- ── the grid of every text screen (docs/design-system.md §7) ──────────────────────────
-- A heading on the first row, a blank row under it, the panes, the footer on the last row.
-- Across: the margin and the cursor's column (the lacquer of the cursor's row starts there),
-- then a heading's icon at column 0, rows' icons at column 1, their names at column 4; the
-- heading's rule and the footer's right end two columns short of the edge, as they begin.
local root_layout = Root.layout
function Root:layout(...)
	root_layout(self, ...)
	local c = self._chunks
	if c and #c == 4 and c[1].h == 1 and c[3].h > 1 then
		self._chunks = { c[1] { h = 2 }, c[2] { y = c[2].y + 1 }, c[3] { y = c[3].y + 1, h = c[3].h - 1 }, c[4] }
	end
end
local header_new = Header.new
function Header:new(area, ...)
	return header_new(self, area and area:pad(ui.Pad(0, 2, 0, 2)) or area, ...)
end
-- the cell between the cursor's column and the icon: yazi 26.9.1's Entity children are padding 1000,
-- icon 2000, prefix 3000, highlights 4000, found 5000, symlink 6000 (preset/components/entity.lua) — a
-- yazi that renumbers them moves this cell (test_yazi's frame case would see the column move)
Entity:children_add(function() return " " end, 1500)

-- The cursor's row (§5): a 2 px edge in the seal's red, the fill and its ink yazi's own (theme.toml's [indicator])
local entity_padding = Entity.padding
function Entity:padding()
	if self._file.is_hovered and self._file.in_current then return ui.Span("▎"):fg("16") end
	return entity_padding(self)
end

-- The list's two columns (yazi.toml: linemode = "kawa"; §7 Files): how big, how old — numbers tabular and right-aligned
-- in muted, their units faint; on the cursor's row the row's own ink. A folder says how many it holds once read.
-- A window too narrow gives up the age, then the size: the names keep their room.
local LIST_W = 200
local current_redraw = Current.redraw
function Current:redraw()
	LIST_W = self._area.w
	return current_redraw(self)
end
local function amount(file, number, unit, nw, uw)
	local n = string.format("%" .. nw .. "s", number)
	local u = string.format("%-" .. uw .. "s", unit)
	if file.is_hovered then return ui.Span(n .. " " .. u) end
	-- (bold(true) takes a folder row's bold away: the list draws the row's style first, under this)
	return ui.Line { ui.Span(n .. " "):fg("21"):bold(true), ui.Span(u):fg("22"):bold(true) }
end
local function how_big(file)
	if file.cha.is_dir then
		local read = cx.active:history(file.url)
		return read and tostring(#read.files) or "", ""
	end
	local n, units = file.cha.len or 0, { "B", "KB", "MB", "GB", "TB" }
	local i = 1
	while n >= 1024 and i < #units do n, i = n / 1024, i + 1 end
	return (i == 1 or n >= 10) and string.format("%.0f", n) or string.format("%.1f", n), units[i]
end
local function how_old(file)
	local t = file.cha.mtime
	if not t or t == 0 then return "", "" end
	local s = math.max(0, os.time() - math.floor(t))
	if s < 60 then return "now", "" end
	for _, u in ipairs { { 31536000, "y" }, { 2592000, "mo" }, { 604800, "w" }, { 86400, "d" }, { 3600, "h" }, { 60, "m" } } do
		if s >= u[1] then return tostring(s // u[1]), u[2] end
	end
end
function Linemode:kawa()
	local f = self._file
	if LIST_W < 44 then return "" end
	local big = amount(f, how_big(f), select(2, how_big(f)), 4, 2)
	if LIST_W < 64 then return big end
	local age, unit = how_old(f)
	return ui.Line { big, "  ", amount(f, age, unit, 3, 2) }
end

-- What is not there yet, said quietly where a row's name would stand (§1: faint; never centred, never
-- "…"): an empty folder, one still being read, a filter that finds nothing, one that cannot be read —
-- in this folder's list (a folder's preview: plugins/kawa-folder.yazi says the same)
local NAME_AT = "     "                        -- (the cursor's cell, column 0, the icon and its air)
local function nothing(area, folder)
	local s = "loading"
	if folder and folder.files.filter then
		s = "nothing matches"
	elseif folder then
		local done, err = folder.stage()
		s = not done and "loading" or err and ("cannot be read: " .. tostring(err)) or "empty"
	end
	return ui.Line { ui.Span(NAME_AT .. s):fg("22") }:area(area)
end
function Current:empty()
	return { nothing(self._area, self._folder), table.unpack(Dnd:new(self._area):redraw()) }
end
-- The heading: the folder icon in accent_text, two columns, the path as a breadcrumb — the folders above in
-- muted, the one you are in in strong, what narrows it (a filter, a search) muted after it — then, the file
-- dialog's, NAME in strong and the folder it is in, muted — a space and the rule (─, edge2) to its end. A folder
-- too long loses its start, nothing in its place; two stitches at least stay.
local FOLDER = "\243\190\128\177" -- Sumi Icons: folder (U+FE031), as in icons.sh
local function crumbs(path, flags, max)
	local p = cut(path, math.max(1, max - wide(flags)), true)
	local up, here = p:match("^(.*/)([^/]+)$")
	if not up then up, here = "", p end
	return ui.Line { ui.Span(up):fg("21"), ui.Span(here):fg("23"), ui.Span(flags):fg("21") }
end
local function heading(self, name, place, flags)
	local room = self._area.w - (self._right_width or 0)
	local head = ui.Line { ui.Span(FOLDER):fg("20"), ui.Span("  ") }
	local tail = place and cut(place, math.max(0, room - head:width() - ui.Line { name }:width() - 5), true)
	if place then
		head = ui.Line { head, ui.Span(name):fg("23"), ui.Span("  " .. tail .. " "):fg("21") }
	else
		head = ui.Line { head, crumbs(name, flags or "", room - head:width() - 3), ui.Span(" ") }
	end
	return ui.Line { head, ui.Span(string.rep("─", math.max(0, room - head:width()))):style(th.mgr.border_style) }
end
-- Tabs (two folders or more, `t`): §7's tab grammar under the heading — each the folder icon, two
-- columns, its folder's name; the one shown in strong with ▔ in accent under its name alone, the
-- others muted; gaps of three; a name too long cut, nothing in its place (yazi's own cut adds "…");
-- then a row of paper. A click picks one, as yazi's own.
function Tabs.height() return #cx.tabs > 1 and 3 or 0 end
function Tabs:redraw()
	if self.height() < 1 then return {} end
	local a = self._area:pad(ui.Pad(0, 2, 0, 2))
	local room = math.max(4, (a.w - 3 * (#cx.tabs - 1)) // #cx.tabs - 3)
	local top, under, x = {}, {}, a.x
	for i = 1, #cx.tabs do
		local shown, name = i == cx.tabs.idx, cut(cx.tabs[i].name, room)
		if i > 1 then top[#top + 1], under[#under + 1], x = ui.Span("   "), ui.Span("   "), x + 3 end
		self._offsets[i] = x
		top[#top + 1] = ui.Span(FOLDER .. "  "):fg(shown and "20" or "21")
		top[#top + 1] = ui.Span(name):fg(shown and "23" or "21")
		under[#under + 1] = ui.Span("   ")
		under[#under + 1] = shown and ui.Span(string.rep("▔", wide(name))):fg("16") or ui.Span(string.rep(" ", wide(name)))
		x = x + 3 + wide(name)
	end
	return { ui.Line(top):area(a { h = 1 }), ui.Line(under):area(a { y = a.y + 1, h = 1 }) }
end

Header:children_remove(1, Header.LEFT) -- (the bare path)
local HEAD = Header:children_add(function(self)
	return heading(self, ya.readable_path(tostring(self._current.cwd)), nil, self:flags())
end, 1000, Header.LEFT)
-- What is marked or waiting to be pasted: a muted fact at the rule's end, no block of colour
function Header:count()
	local marked, yanked = #self._tab.selected, #cx.yanked
	if marked > 0 then return ui.Line { " ", ui.Span(marked .. " marked"):fg("21") } end
	if yanked > 0 then return ui.Line { " ", ui.Span(yanked .. (cx.yanked.is_cut and " to move" or " to copy")):fg("21") } end
	return ""
end

-- The panes by the window's size, chosen again whenever it changes (a tiled window does,
-- each time a window opens or closes beside it). Wide, the preview gets the most room; in
-- between, yazi's own 1:4:3; narrower than 60 columns the parent column goes, and the list
-- and the preview share the window — one above the other when it is tall, side by side
-- when it is not; narrower than 40 (and short), the list alone. A ratio of your own
-- (yazi.toml's [mgr] ratio, or a rail dragged with the mouse) is kept as you set it.
local DEFAULT = { 1, 4, 3 }
local function panes(w, h) -- → "cols"/"rows", the ratio
	if w >= 120 then return "cols", { 1, 3, 4 } end
	if w >= 60 then return "cols", DEFAULT end
	if h >= 28 then return "rows", { 0, 1, 1 } end
	if w >= 40 then return "cols", { 0, 1, 1 } end
	return "cols", { 0, 1, 0 }
end

-- The parent column never narrower than the home folder's names need ("Downloads": 17
-- columns with its margins, its icon, the icon's second half and the free column before the rail), e.g. in the file dialog
-- or a window of 60–80 columns; the list gives up the difference while it keeps 24.
local PARENT_MIN, CURRENT_MIN = 17, 24
local tab_layout = Tab.layout
function Tab:layout(...)
	local r, a = rt.mgr.ratio, self._area
	if r[1] ~= DEFAULT[1] or r[2] ~= DEFAULT[2] or r[3] ~= DEFAULT[3] then
		tab_layout(self, ...)
	else
		local mode, ratio = panes(a.w, a.h)
		if mode == "rows" then
			-- the list on top, the preview below it (its first row is the rule between them)
			local top = (a.h + 1) // 2
			self._chunks = { a { w = 0 }, a { h = top }, a { y = a.y + top, h = a.h - top } }
		else
			local all = ratio[1] + ratio[2] + ratio[3]
			self._chunks = ui.Layout()
				:direction(ui.Layout.HORIZONTAL)
				:constraints({
					ui.Constraint.Ratio(ratio[1], all),
					ui.Constraint.Ratio(ratio[2], all),
					ui.Constraint.Ratio(ratio[3], all),
				})
				:split(a)
		end
	end
	local c = self._chunks
	local d = c and #c == 3 and c[1].w > 0 and PARENT_MIN - c[1].w or 0
	if d > 0 and c[2].w - d >= CURRENT_MIN then
		self._chunks = { c[1] { w = PARENT_MIN }, c[2] { x = c[2].x + d, w = c[2].w - d }, c[3] }
	end
end
local function stacked(c) return c and #c == 3 and c[3].y > c[2].y end

-- One free column on both sides of every rail, as in the pop-ups (13 px): the parent list
-- (and its highlight) stops one column before its rail, the current list keeps one column
-- off the rails on both sides, and the preview stands one column off the rail on its left.
-- With no parent column the list starts one column in, as the header and the status line
-- do; stacked, the preview starts under the rule, its text where the list's is.
local tab_build = Tab.build
function Tab:build(...)
	tab_build(self, ...)
	local c, rows = self._chunks, stacked(self._chunks)
	for _, child in ipairs(self._children or {}) do
		if child._area and child._id == "parent" then
			child._area = child._area:pad(ui.Pad(0, 1, 0, 0))
		elseif child._area and child._id == "current" then
			child._area = child._area:pad(ui.Pad(0, (c[3].w > 0 and not rows) and 1 or 0, 0, c[1].w > 0 and 1 or 0))
		elseif child._id == "preview" and child._area then
			child._area = rows and c[3]:pad(ui.Pad(1, 1, 0, 1)) or child._area:pad(ui.Pad(0, 0, 0, 1))
		end
	end
end

-- Stacked, the rails become one rule between the list and the preview: the desktop's
-- rule (─, solid, as under every heading), one free column at each end like every other row.
local rails_build = Rails.build
function Rails:build(...)
	if not stacked(self._chunks) then return rails_build(self, ...) end
	local area = self._chunks[3] { h = 1 }:pad(ui.Pad.x(1))
	self._children = {
		{
			_id = "rail-middle",
			reflow = function() return {} end, -- (not a target for the mouse: nothing to drag)
			redraw = function()
				return { ui.Bar(ui.Edge.TOP):area(area):symbol("─"):style(th.mgr.border_style) }
			end,
		},
	}
end

-- The footer: the hovered file's facts, muted — its size, when it changed, its permissions — from column 0, its
-- place in the list at the right; the mode's word only when it is not the usual one (select,
-- unset), in its colour. Never the obvious (its name is on the cursor's row). A narrow window
-- keeps it on one line: the permissions go first, then the date, then the size.
local SEP = "  ·  "
local function changed(t)
	if not t or t == 0 then return nil end
	t = math.floor(t)
	return (os.date(os.date("%Y", t) == os.date("%Y") and "%d %b %H:%M" or "%d %b %Y", t):gsub("^0", ""))
end
for id = 1, 6 do Status:children_remove(id, id <= 3 and Status.LEFT or Status.RIGHT) end
local function place(self)
	local n = #self._current.files
	return string.format("%d/%d", math.min(self._current.cursor + 1, n), n)
end
local FACTS = Status:children_add(function(self)
	local h, m, parts = self._current.hovered, self._tab.mode, {}
	if m.is_select or m.is_unset then parts[#parts + 1] = tostring(m) end
	if h then
		local n, unit = how_big(h)
		if unit ~= "" then parts[#parts + 1] = n .. " " .. unit
		elseif n == "0" then parts[#parts + 1] = "empty"
		elseif n ~= "" then parts[#parts + 1] = n .. (n == "1" and " item" or " items") end
		parts[#parts + 1] = changed(h.cha.mtime)
		parts[#parts + 1] = h.cha:perm()
	end
	-- (spans afresh for each try: a line takes the spans it is made of)
	local function line()
		local t = { ui.Span("  ") }
		for i, p in ipairs(parts) do
			if i > 1 then t[#t + 1] = ui.Span(SEP):fg("22") end
			t[#t + 1] = (i == 1 and p == tostring(m)) and ui.Span(p):style(self:style().main) or ui.Span(p):fg("21")
		end
		return ui.Line(t)
	end
	local room = self._area.w - wide(place(self)) - 4
	while #parts > 0 and line():width() > room do parts[#parts] = nil end
	return line()
end, 1000, Status.LEFT)
Status:children_add(function(self) return ui.Line { ui.Span(place(self)):fg("21"), ui.Span("  ") } end, 1000, Status.RIGHT)

-- The footer's progress: a muted fact before the place, no block of colour; a failure in accent_text
function Progress:redraw()
	local s = cx.tasks.summary
	if s.total == 0 then return {} end
	local words = (s.percent and string.format("%d %%", math.floor(s.percent)) .. SEP or "") .. (s.total - s.success) .. " left"
	return { ui.Clear(self._area), ui.Line(ui.Span(words):fg(s.failed == 0 and "21" or "20")):area(self._area):align(ui.Align.RIGHT) }
end

-- The task window's rows (the frame and its heading: the patched yazi): §7's row — the kind's icon at column 1, what it
-- is at column 4, how far at the last column — with a meter of ten segments under it, a row of paper after each
local TASK = {
	FileCopy = "\u{FE03D}", FileMove = "\u{FE031}", FileDelete = "\u{FF00B}",
	FileDownload = "\u{FE042}", FileUpload = "\u{FE0A8}",
}
local LIT, OFF = "\u{FE0BF}", "\u{FE0C0}" -- Sumi Icons: read, read-off (a meter's segments, §7)
function Tasks:layout() self._area = self._area end
function Tasks:redraw()
	local out, a = {}, self._area
	if #cx.tasks.snaps == 0 then return { ui.Line(ui.Span(" none"):fg("22")):area(a { h = 1 }) } end
	for i, snap in ipairs(cx.tasks.snaps) do
		local y = a.y + (i - 1) * 3
		if y + 1 >= a.bottom then break end
		local label, count, failed = self:progress(snap)
		local right = label and string.format("%d %%", math.floor(snap.percent or 0)) or (snap.running and "running" or "failed")
		if count then right = count .. "  " .. right end
		local title = cut(snap.title, math.max(4, a.w - 5 - wide(right) - 2))
		local row = ui.Line { " ", ui.Span(TASK[snap.prog.kind] or "\u{FE030}"):fg("21"), "  ", title }
		local here = i == cx.tasks.cursor + 1
		if here then
			out[#out + 1] = ui.Bar(ui.Edge.LEFT):area(a { x = a.x - 1, y = y, w = 1, h = 1 }):symbol("▎"):style(ui.Style():fg("16"):bg("24"))
			row = row:style(th.tasks.hovered)
		end
		out[#out + 1] = row:area(a { y = y, h = 1 })
		out[#out + 1] = ui.Line(ui.Span(right):fg(failed and "20" or "21")):area(a { y = y, h = 1 }):align(ui.Align.RIGHT)
		if label then
			local lit = math.floor((snap.percent or 0) / 10 + 0.5)
			out[#out + 1] = ui.Line { "    ", ui.Span(string.rep(LIT, lit)):fg(failed and "20" or "21"), ui.Span(string.rep(OFF, 10 - lit)):fg("19") }:area(a { y = y + 1, h = 1 })
		end
	end
	return out
end

-- ── the file dialog: kawa-pick starts yazi with KAWA_PICK=<mode> ─────────────────────
-- Dressed like the other text screens (docs/design-system.md §7): along the top a heading —
-- the folder icon in vermilion, two columns, the dialog's name, then the folder it is in,
-- muted, and the rule (─) to the edge; on the last line its own keys (never the obvious:
-- Enter, Esc — Super+/ has those), each key in the words' ink and what it does muted, four
-- columns apart; the count at the right.
local PICK = {
	open1   = { "open file",    { "/", "find", ".", "hidden" } },
	openN   = { "open files",   { "space", "mark" } },
	folder1 = { "open folder",  { "q", "this folder" } },
	folderN = { "open folders", { "space", "mark", "q", "this folder" } },
	save    = { "save file",    { "r", "rename" } },
	back    = { "as it was",    { "space", "mark", "q", "this folder" } },
}
local pick = PICK[os.getenv("KAWA_PICK") or ""]
-- (taking back: the heading says when — KAWA_PICK_TITLE, "as it was at 16:00" — and the snapshot's
-- copy of your home, KAWA_PICK_ROOT, is named as home is: ~)
local pick_title, pick_root = os.getenv("KAWA_PICK_TITLE"), os.getenv("KAWA_PICK_ROOT")
if pick then
	Header:children_remove(HEAD, Header.LEFT)
	Header:children_add(function(self)
		local cwd = tostring(self._current.cwd)
		if pick_root and (cwd == pick_root or cwd:sub(1, #pick_root + 1) == pick_root .. "/") then
			cwd = "~" .. cwd:sub(#pick_root + 1)
		else
			cwd = ya.readable_path(cwd)
		end
		return heading(self, pick_title or pick[1], cwd .. self:flags())
	end, 1000, Header.LEFT)
	Status:children_remove(FACTS, Status.LEFT)
	Status:children_add(function()
		local spans, k = { ui.Span("  ") }, pick[2]
		-- (q with marks takes the marked — the plugin's q — and says so)
		if #cx.active.selected > 0 and k[#k] == "this folder" and k[1] == "space" then
			k = { k[1], k[2], k[3], "the marked" }
		end
		for i = 1, #k, 2 do
			if i > 1 then spans[#spans + 1] = ui.Span("    ") end
			spans[#spans + 1] = ui.Span(k[i])
			spans[#spans + 1] = ui.Span("  " .. k[i + 1]):fg("21")
		end
		return ui.Line(spans)
	end, 1000, Status.LEFT)
end

-- Super+Z and Super+D are dwl's keys, which yazi never sees: kawa-shrink and kawa-file find the
-- yazi in the focused window by $XDG_RUNTIME_DIR/kawa-yazi.ID — "PID<tab>TIME<tab>FOLDER",
-- rewritten as it is used (a move, a folder) — then run on its selection, or the file under
-- its cursor (files.sh: yazi_focused)
do
	local run, id = os.getenv("XDG_RUNTIME_DIR"), os.getenv("YAZI_ID")
	local stat = io.open("/proc/self/stat")
	local pid = stat and stat:read("*n")
	if stat then stat:close() end
	local function mark()
		local f = run and id and pid and io.open(run .. "/kawa-yazi." .. id, "w")
		if not f then return end
		f:write(string.format("%d\t%.3f\t%s\n", pid, ya.time(), tostring(cx.active.current.cwd)))
		f:close()
	end
	ps.sub("hover", mark)
	ps.sub("cd", mark)
end
