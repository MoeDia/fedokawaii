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
Entity:children_add(function() return " " end, 1500) -- (the cell between the cursor's column and the icon)

-- The heading: the folder icon in accent_text, two columns, NAME in strong — then, the file
-- dialog's, the folder it is in, muted — a space and the rule (─, edge2) to its end. A folder
-- too long loses its start, nothing in its place; two stitches at least stay.
local FOLDER = "\243\190\128\177" -- Sumi Icons: folder (U+FE031), as in icons.sh
local function heading(self, name, place)
	local room = self._area.w - (self._right_width or 0)
	local head = ui.Line { ui.Span(FOLDER):fg("20"), ui.Span("  ") }
	local tail = place and cut(place, math.max(0, room - head:width() - ui.Line { name }:width() - 5), true)
	if place then
		head = ui.Line { head, ui.Span(name):fg("23"), ui.Span("  " .. tail .. " "):fg("21") }
	else
		head = ui.Line { head, ui.Span(cut(name, math.max(0, room - head:width() - 3), true) .. " "):fg("23") }
	end
	return ui.Line { head, ui.Span(string.rep("─", math.max(0, room - head:width()))):style(th.mgr.border_style) }
end
Header:children_remove(1, Header.LEFT) -- (the bare path)
local HEAD = Header:children_add(function(self)
	return heading(self, ya.readable_path(tostring(self._current.cwd)) .. self:flags())
end, 1000, Header.LEFT)

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

-- The footer: the hovered file's facts, muted — its size, its permissions — from column 0, its
-- place in the list at the right; the mode's word only when it is not the usual one (select,
-- unset), in its colour. Never the obvious (its name is on the cursor's row). A narrow window
-- keeps it on one line: the permissions go first, then the size.
local SEP = "  ·  "
for id = 1, 6 do Status:children_remove(id, id <= 3 and Status.LEFT or Status.RIGHT) end
local function place(self)
	local n = #self._current.files
	return string.format("%d/%d", math.min(self._current.cursor + 1, n), n)
end
local FACTS = Status:children_add(function(self)
	local h, m, parts = self._current.hovered, self._tab.mode, {}
	if m.is_select or m.is_unset then parts[#parts + 1] = tostring(m) end
	if h then
		parts[#parts + 1] = ya.readable_size(h.cha.len or 0)
		parts[#parts + 1] = h.cha:perm() or ""
	end
	-- (spans afresh for each try: a line takes the spans it is made of)
	local function line()
		local t = { ui.Span("  ") }
		for i, p in ipairs(parts) do
			if i > 1 then t[#t + 1] = ui.Span(SEP):fg("21") end
			t[#t + 1] = (i == 1 and p == tostring(m)) and ui.Span(p):style(self:style().main) or ui.Span(p):fg("21")
		end
		return ui.Line(t)
	end
	local room = self._area.w - wide(place(self)) - 4
	while #parts > 0 and line():width() > room do parts[#parts] = nil end
	return line()
end, 1000, Status.LEFT)
Status:children_add(function(self) return ui.Line { ui.Span(place(self)):fg("21"), ui.Span("  ") } end, 1000, Status.RIGHT)

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
