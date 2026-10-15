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

-- The parent column never narrower than the home folder's names need ("Downloads": 15
-- columns with its margins and the free column before the rail), e.g. in a stacked window
-- or the file dialog; the list gives up the difference.
local PARENT_MIN = 15
local tab_layout = Tab.layout
function Tab:layout(...)
	tab_layout(self, ...)
	local c = self._chunks
	if c and #c == 3 and c[1].w > 0 and c[1].w < PARENT_MIN and c[2].w > 40 then
		local d = PARENT_MIN - c[1].w
		self._chunks = { c[1] { w = PARENT_MIN }, c[2] { x = c[2].x + d, w = c[2].w - d }, c[3] }
	end
end

-- One free column on both sides of every rail, as in the pop-ups (13 px): the parent and
-- current lists (and their highlight) stop one column before the rail on their right, and
-- the preview stands one column off the rail on its left.
local tab_build = Tab.build
function Tab:build(...)
	tab_build(self, ...)
	for _, c in ipairs(self._children or {}) do
		if c._area and (c._id == "parent" or c._id == "current") then
			c._area = c._area:pad(ui.Pad(0, 1, 0, 0))
		elseif c._id == "preview" and c._area then
			c._area = c._area:pad(ui.Pad(0, 0, 0, 1))
		end
	end
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
	local ICON = "\243\190\128\178" -- Sumi Icons: folder (U+FE032), as in icons.sh
	Header:children_remove(1, Header.LEFT) -- the bare path
	Header:children_add(function(self)
		local room = self._area.w - 1 - (self._right_width or 0)
		local head = ui.Line {
			ui.Span("─ "):fg("darkgray"),
			ui.Span(ICON):fg("lightred"),
			ui.Span(" " .. pick[1] .. " "):fg("gray"),
		}
		local where = ya.readable_path(tostring(self._current.cwd)) .. self:flags()
		where = ui.truncate("· " .. where, { max = math.max(0, room - head:width() - 2), rtl = true })
		local line = ui.Line { head, ui.Span(where .. " "):fg("darkgray") }
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
