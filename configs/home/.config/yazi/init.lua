-- ~/.config/yazi/init.lua — yazi's frame in the desktop's measure (theme.sh installs it).
-- For yazi 26.x. Each change wraps yazi's own component and steps aside if that changes.

-- Every row keeps one free column at each side, as the panes already do (yazi leaves one
-- left of the parent column and one right of the preview) and as the pop-ups do (fzf
-- --margin=0,1): the header and the status line get theirs here. (The tab bar gets its
-- column from theme.toml's [tabs] sep_outer; the header's count of selected files already
-- ends one column short of the edge.)
local header_new = Header.new
function Header:new(area, ...)
	return header_new(self, area and area:pad(ui.Pad(0, 0, 0, 1)) or area, ...)
end
Status:children_add(function() return " " end, 0, Status.LEFT)
Status:children_add(function() return " " end, 9000, Status.RIGHT)

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

-- The parent column never narrower than the home folder's names need ("Downloads": 15
-- columns with its margins and the free column before the rail), e.g. in the file dialog
-- or a window of 60–80 columns; the list gives up the difference while it keeps 24.
local PARENT_MIN, CURRENT_MIN = 15, 24
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
-- stitch (╌, as under every heading), one free column at each end like every other row.
local rails_build = Rails.build
function Rails:build(...)
	if not stacked(self._chunks) then return rails_build(self, ...) end
	local area = self._chunks[3] { h = 1 }:pad(ui.Pad.x(1))
	self._children = {
		{
			_id = "rail-middle",
			reflow = function() return {} end, -- (not a target for the mouse: nothing to drag)
			redraw = function()
				return { ui.Bar(ui.Edge.TOP):area(area):symbol("╌"):style(th.mgr.border_style) }
			end,
		},
	}
end

-- A narrow window keeps its status line on one line: what it cannot hold goes, the least
-- needed first — the permissions, the size, the percentage — and the file's name is cut
-- to the room left (…in its middle).
local DROP = { 4, 2, 5 } -- yazi's ids: perm, length, percent
function Status:children_redraw(side)
	local lines = {}
	for _, c in ipairs(side == self.RIGHT and self._right or self._left) do
		if not (self._skip and self._skip[c.id]) then
			lines[#lines + 1] = (type(c[1]) == "string" and self[c[1]] or c[1])(self)
		end
	end
	return ui.Line(lines)
end
local status_name, status_redraw = Status.name, Status.redraw
function Status:name()
	local s = status_name(self)
	if self._room and type(s) == "string" then
		return ui.truncate(s, { max = math.max(0, self._room) })
	end
	return s
end
function Status:redraw()
	self._skip, self._room = {}, nil
	local function wide() return self:children_redraw(self.LEFT):width() + self:children_redraw(self.RIGHT):width() end
	for _, id in ipairs(DROP) do
		if wide() <= self._area.w then break end
		self._skip[id] = true
	end
	local over = wide() - self._area.w
	if over > 0 then
		self._room = ui.Line { status_name(self) }:width() - over
	end
	return status_redraw(self)
end

-- ── the file dialog: kawa-pick starts yazi with KAWA_PICK=<mode> ─────────────────────
-- Dressed like the other pop-ups: the title in a rule along the top (vermilion icon, name,
-- the folder in the quiet colour), the keys along the bottom, the count at the right.
local PICK = {
	open1   = { "open file",    "enter open  ·  / find  ·  . hidden  ·  esc cancel" },
	openN   = { "open files",   "space mark  ·  enter open  ·  esc cancel" },
	folder1 = { "open folder",  "enter choose  ·  q this folder  ·  esc cancel" },
	folderN = { "open folders", "space mark  ·  enter choose  ·  q this folder  ·  esc cancel" },
	save    = { "save file",    "enter save  ·  r rename  ·  esc cancel" },
}
local pick = PICK[os.getenv("KAWA_PICK") or ""]
if pick then
	local ICON = "\243\190\128\177" -- Sumi Icons: folder (U+FE031), as in icons.sh
	Header:children_remove(1, Header.LEFT) -- the bare path
	Header:children_add(function(self)
		local room = self._area.w - 1 - (self._right_width or 0)
		local head = ui.Line {
			ui.Span("─ "):fg("darkgray"),
			ui.Span(ICON):fg("lightred"),
			ui.Span(" " .. pick[1] .. " "):fg("gray"),
		}
		local where = ya.readable_path(tostring(self._current.cwd)) .. self:flags()
		-- (a long folder loses its start, "…" in its place — the "· " before it stays)
		where = ui.truncate(where, { max = math.max(0, room - head:width() - 4), rtl = true })
		local line = ui.Line { head, ui.Span("· " .. where .. " "):fg("darkgray") }
		return ui.Line { line, ui.Span(string.rep("─", math.max(0, room - line:width()))):fg("darkgray") }
	end, 1000, Header.LEFT)
	for id = 1, 6 do -- mode, size, name · permissions, percent, position
		Status:children_remove(id, id <= 3 and Status.LEFT or Status.RIGHT)
	end
	Status:children_add(function() return ui.Span("  " .. pick[2]):fg("darkgray") end, 1000, Status.LEFT)
	Status:children_add(function(self)
		local n = #self._current.files
		return ui.Span(string.format("%d/%d", math.min(self._current.cursor + 1, n), n)):fg("darkgray")
	end, 1000, Status.RIGHT)
end
