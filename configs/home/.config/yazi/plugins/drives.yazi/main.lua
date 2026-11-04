--- @since 26.5.6
-- ~/.config/yazi/plugins/drives.yazi — the drives in yazi (M) and in the file dialog: USB
-- sticks, external disks, SD cards, as kawa-drives lists them. Enter opens one (mounted
-- first if need be: an encrypted one asks for its passphrase) and goes there · e ejects
-- its drive (closed, switched off; a notice says when it is safe to unplug) · Esc closes.
-- Modelled on yazi-rs/plugins' mount.yazi (MIT), dressed like the desktop's pop-ups.

local ICON_DRIVE = "\243\190\129\132" -- Sumi Icons: drive (U+FE044), as in icons.sh
local WIDTH = 66 -- columns, the ring included

local toggle_ui = ya.sync(function(self)
	if self.children then
		Modal:children_remove(self.children)
		self.children = nil
		ps.unsub("mount") -- (closed: other mounts no longer concern it)
	else
		self.children = Modal:children_add(self, 10)
		self.cursor = 0 -- (each time from the top: not where it was left last time)
	end
	ui.render()
end)

local set_rows = ya.sync(function(self, rows, busy)
	self.rows = rows
	if busy ~= nil then
		self.busy = busy or nil
	end
	self.cursor = math.max(0, math.min(self.cursor or 0, #rows - 1))
	ui.render()
end)

local set_busy = ya.sync(function(self, busy)
	self.busy = busy
	ui.render()
end)

local move = ya.sync(function(self, step)
	local n = #(self.rows or {})
	self.cursor = n == 0 and 0 or ya.clamp(0, (self.cursor or 0) + step, n - 1)
	ui.render()
end)

local hovered = ya.sync(function(self) return (self.rows or {})[(self.cursor or 0) + 1] end)

local set_cursor = ya.sync(function(self, n)
	self.cursor = n
	ui.render()
end)

-- the row of the drive yazi stands in (a file system of it), if any
local function inside(rows, here)
	for i, r in ipairs(rows) do
		if r.dir ~= "" and (here == r.dir or here:sub(1, #r.dir + 1) == r.dir .. "/") then
			return i
		end
	end
end

local all_rows = ya.sync(function(self) return self.rows or {} end)

local cwd = ya.sync(function() return tostring(cx.active.current.cwd) end)

local subscribe = ya.sync(function()
	ps.unsub("mount")
	ps.sub("mount", function() ya.emit("plugin", { "drives", "refresh" }) end)
end)

-- kawa-drives list: DEVICE DISK LABEL SIZE TYPE FOLDER, one file system per line
local function obtain()
	local out = Command("kawa-drives"):arg("list"):stdout(Command.PIPED):stderr(Command.NULL):output()
	local rows = {}
	for line in ((out and out.stdout) or ""):gmatch("[^\n]+") do
		local f = {}
		for v in (line .. "\t"):gmatch("([^\t]*)\t") do
			f[#f + 1] = v
		end
		if #f >= 5 then
			rows[#rows + 1] = { dev = f[1], disk = f[2], label = f[3], size = f[4], fs = f[5], dir = f[6] or "" }
		end
	end
	return rows
end

local function run(args)
	local out = Command("kawa-drives"):arg(args):stdout(Command.PIPED):stderr(Command.NULL):output()
	return out and out.status and out.status.success and (out.stdout:gsub("\n+$", "")) or nil
end

local M = {
	keys = {
		{ on = "<Esc>", run = "quit" },
		{ on = "q", run = "quit" },
		{ on = "M", run = "quit" },
		{ on = "<Enter>", run = "open" },
		{ on = "l", run = "open" },
		{ on = "<Right>", run = "open" },
		{ on = "e", run = "eject" },
		{ on = "k", run = "up" },
		{ on = "<Up>", run = "up" },
		{ on = "j", run = "down" },
		{ on = "<Down>", run = "down" },
	},
}

function M:new(area)
	self:layout(area)
	return self
end

function M:layout(area)
	local n = math.max(1, #(self.rows or {}))
	local w = math.min(WIDTH, area.w)
	local h = math.min(n + 6, area.h) -- the ring, the heading, a free row, the rows, a free row, the keys, the ring
	self._area = ui.Rect {
		x = area.x + math.floor((area.w - w) / 2),
		y = area.y + math.floor((area.h - h) / 2),
		w = w,
		h = h,
	}
end

-- a label too long for its room is cut there, nothing put in its place (never "…": the
-- desktop's rule; init.lua's cut() for the panes, this one for the popup)
local function cut(s, max)
	local keep, w = {}, 0
	for _, c in utf8.codes(s) do
		local ch = utf8.char(c)
		w = w + ui.Line(ch):width()
		if w > max then break end
		keep[#keep + 1] = ch
	end
	return table.concat(keep)
end

-- A drive as §7's row: its picture at column 1 (accent_text while open), the label at column 4, its size, file system and
-- state at the row's end, a column in, the inks of a value (muted, faint; open in strong)
local function row_line(r, width)
	local state = r.dir ~= "" and "open" or "closed"
	local label = cut(r.label, math.max(1, width - 31))
	local tail = string.format("%7s  %-6s %-6s ", r.size, r.fs:sub(1, 6), state)
	local gap = math.max(1, width - 4 - ui.Line(label):width() - ui.Line(tail):width())
	return {
		ui.Span(" "),
		ui.Span(ICON_DRIVE):fg(r.dir ~= "" and "20" or "21"),
		ui.Span("  " .. label .. string.rep(" ", gap)),
		ui.Span(string.format("%7s  ", r.size)):fg("21"),
		ui.Span(string.format("%-6s ", r.fs:sub(1, 6))):fg("22"),
		ui.Span(string.format("%-6s ", state)):fg(r.dir ~= "" and "23" or "22"),
	}
end

function M:reflow() return { self } end

-- The pop-up as every other (the patched yazi's frame.rs, §7): the ring — ui.Border's plain one —, the heading inside it (the
-- icon in accent_text, two columns, the name in strong, the rule), a row of paper, the rows, a row of paper, its key
function M:redraw()
	local a = self._area
	local inner = a:pad(ui.Pad(1, 3, 1, 3))
	local out = {
		ui.Clear(a),
		ui.Border(ui.Edge.ALL):area(a):type(ui.Border.PLAIN):style(th.pick.border),
	}
	local function row(y, line) out[#out + 1] = line:area(inner { y = inner.y + y, h = 1 }) end
	local rule = string.rep("─", math.max(0, inner.w - 3 - 6 - 1))
	row(0, ui.Line { ui.Span(ICON_DRIVE):fg("20"), ui.Span("  "), ui.Span("drives"):fg("23"), ui.Span(" "), ui.Span(rule):fg("19") })
	local rows = self.rows or {}
	if #rows == 0 then
		row(2, ui.Line(ui.Span("    " .. (self.busy or "nothing plugged in")):fg("22")))
	end
	for i, r in ipairs(rows) do
		if i - 1 == self.cursor then
			-- (the cursor's fill a cell past the content each side, its edge in the seal's red, every ink its own)
			local spans = row_line(r, inner.w)
			table.insert(spans, 1, ui.Span("▎"):fg("16"))
			spans[#spans + 1] = ui.Span(" ")
			out[#out + 1] = ui.Line(spans):style(th.cmp.active):area(inner { x = inner.x - 1, w = inner.w + 2, y = inner.y + 1 + i, h = 1 })
		else
			row(1 + i, ui.Line(row_line(r, inner.w)))
		end
	end
	-- (its own key alone, §7: the tile of cells U+FF001, U+FF000 + its letter, U+FF002; what it does muted)
	local foot = inner.y + 2 + math.max(1, #rows) + 1
	out[#out + 1] = (self.busy and ui.Line(ui.Span(self.busy):fg("22"))
		or ui.Line { ui.Span("\u{FF001}\u{FF065}\u{FF002}"):fg("21"), ui.Span(" eject"):fg("21") }):area(inner { y = foot, h = 1 })
	return out
end

function M:entry(job)
	local a = job.args[1]
	if a == "refresh" then
		return set_rows(obtain())
	end

	toggle_ui()
	local rows = obtain()
	set_rows(rows)
	-- standing in a drive: the cursor starts on it (e ejects what you are looking at)
	local at = inside(rows, cwd())
	if at then
		set_cursor(at - 1)
	end
	subscribe()
	while true do
		local idx = ya.which { cands = self.keys, silent = true }
		local act = idx and self.keys[idx].run or "quit"
		if act == "quit" then
			break
		elseif act == "up" then
			move(-1)
		elseif act == "down" then
			move(1)
		elseif act == "open" then
			local r = hovered()
			if r then
				set_busy("opening " .. r.label)
				local dir = run { "open", r.dev }
				set_busy(nil)
				if dir and dir ~= "" then
					ya.emit("cd", { dir })
					break
				end
				set_rows(obtain()) -- (the notice says why not)
			end
		elseif act == "eject" then
			local r = hovered()
			if r then
				-- yazi standing in the drive would keep it busy: step out first
				local now = all_rows()
				local at_now = inside(now, cwd())
				if at_now and now[at_now].disk == r.disk then
					ya.emit("cd", { os.getenv("HOME") or "/" })
				end
				-- handed off, and the list closed: the keys go back to yazi at once, and an eject
				-- still flushing a slow stick goes on even if yazi ends (its notice says "safe to
				-- unplug", or which program still uses the drive)
				Command("setsid"):arg({ "-f", "kawa-drives", "eject", r.dev }):cwd("/"):status()
				break
			end
		end
	end
	toggle_ui()
end

function M:click() end
function M:scroll() end
function M:touch() end

return M
