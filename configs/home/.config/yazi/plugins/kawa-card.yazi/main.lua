-- kawa-card.yazi — the preview of what has no picture (a binary, an empty file; yazi.toml's last previewer): a card of its
-- facts on the lists' columns (§7 Facts: a key muted, two columns, its value in the words' ink), never an empty pane.
-- What it is comes from `file`, as yazi's own fallback asks it, wrapped at a word.
-- Tab's pop-up (yazi.toml's spotters) is the same card in the pop-ups' frame (M:spot, below).
local M = {}

local function amount(n)
	local u, i = { "B", "KB", "MB", "GB", "TB" }, 1
	while n >= 1024 and i < #u do n, i = n / 1024, i + 1 end
	return string.format((i == 1 or n >= 10) and "%.0f %s" or "%.1f %s", n, u[i])
end

local function facts(job)
	local cha, rows = job.file.cha, {}
	local function add(k, v) if v and v ~= "" then rows[#rows + 1] = { k, v } end end
	local out = Command(os.getenv("YAZI_FILE_ONE") or "file"):arg({ "-bL", "--", tostring(job.file.path or job.file.url) }):output()
	-- (what a person asks of a program, not its build's fingerprint)
	local what = out and out.stdout:gsub("%s+$", ""):gsub(", version 1 %(SYSV%)", ""):gsub(", interpreter [^,]*", ""):gsub(", BuildID[^,]*", ""):gsub(", for GNU/Linux [^,]*", "") or ""
	add("what", what)
	add("size", amount(cha.len or 0))
	if cha.mtime and cha.mtime > 0 then add("changed", (os.date("%d %b %Y %H:%M", math.floor(cha.mtime)):gsub("^0", ""))) end
	add("rights", cha.perm and cha:perm() or "")
	return rows
end

-- the words cut at a word's end to fit, a line each (never "…", never mid-word unless one word is wider than the room)
local function wrap(s, w)
	local lines, cur = {}, ""
	for found in s:gmatch("%S+") do
		local word = found
		while ui.width(word) > w do
			if cur ~= "" then lines[#lines + 1], cur = cur, "" end
			local part, used = "", 0                        -- (by characters and their columns: a name may be Japanese)
			for ch in word:gmatch("[\1-\127\194-\244][\128-\191]*") do
				if used + ui.width(ch) > w then break end
				part, used = part .. ch, used + ui.width(ch)
			end
			if part == "" then break end
			lines[#lines + 1], word = part, word:sub(#part + 1)
		end
		if cur == "" then cur = word
		elseif ui.width(cur) + 1 + ui.width(word) <= w then cur = cur .. " " .. word
		else lines[#lines + 1], cur = cur, word end
	end
	if cur ~= "" then lines[#lines + 1] = cur end
	return lines
end

function M:peek(job)
	local a, name, key, lines = job.area, tostring(job.file.name), 0, {}
	local rows = facts(job)
	for _, r in ipairs(rows) do key = math.max(key, ui.width(r[1])) end
	local at, room = 5, a.w - 5 - key - 2                -- (the names' column, a row's: the cursor's cell, the icon, its air)
	lines[#lines + 1] = ui.Line { string.rep(" ", at), ui.Span(name):fg("23") }
	lines[#lines + 1] = ui.Line ""
	for _, r in ipairs(rows) do
		for i, l in ipairs(wrap(r[2], math.max(8, room))) do
			lines[#lines + 1] = ui.Line {
				string.rep(" ", at),
				ui.Span(string.format("%-" .. key .. "s  ", i == 1 and r[1] or "")):fg("21"),
				l,
			}
		end
	end
	ya.preview_widget(job, ui.Text(lines):area(a))
end

function M:seek() end

-- ── Tab's pop-up ─────────────────────────────────────────────────────────────────────────
-- §4's ring, §7's heading inside it (the icon in the accent, two columns, the name, a space, the rule), a row of paper, the
-- facts: as tall as they are, 56 columns wide (a narrower window narrows it: yazi's Position clamps), j and k move the band over
-- them, c c copies a value (yazi's table does both). As in the other pop-ups the band starts a column clear of the ring, the words
-- 16 px inside it.
local WIDE, I_FOLDER, I_FILE, I_LINK, I_MARKED = 56, "\u{FE031}", "\u{FE03D}", "\u{FE043}", "\u{FE04F}"

local function pos(h, top, right, bottom, left)
	return ui.Pos({ "center", w = WIDE, h = h }):pad(ui.Pad(top, right, bottom, left))
end

-- FACTS: { { key, value }, … }; a value too long for the room goes on under itself, cut at its words. The first drawing places the
-- band (FIRST); a later one, a folder's sum growing, leaves it where j and k have put it.
local function draw(job, first, icon, title, rows)
	local key = 0
	for _, r in ipairs(rows) do key = math.max(key, ui.width(r[1])) end
	local room, height, cells = WIDE - 2 * 2 - 2 - key - 2 - 2, 0, {}
	for _, r in ipairs(rows) do
		local lines = wrap(r[2], room)
		height = height + #lines
		cells[#cells + 1] = ui.Row({ "", ui.Line(r[1]):fg("21"), ui.Text(lines) }):height(#lines)
	end
	local h, inner = height + 4, WIDE - 2 * 3
	local name = wrap(title, inner - 3 - 3)[1] or ""
	local heading = ui.Line {
		ui.Span(icon):fg("20"),
		"  ",
		ui.Span(name):fg("23"),
		" ",
		ui.Span(string.rep("─", inner - 3 - ui.width(name) - 1)):fg("19"),
	}
	ya.spot_widgets(job, {
		ui.Clear(pos(h, 0, 0, 0, 0)),
		ui.Border(ui.Edge.ALL):area(pos(h, 0, 0, 0, 0)):style(th.spot.border),
		heading:area(pos(h, 1, 3, h - 2, 3)),
		ui.Table(cells)
			:area(pos(h, 3, 2, 1, 2))
			:row(first and math.min(job.skip, #cells - 1) or nil)
			:col(2)
			:row_style(th.spot.tbl_cell)
			:cell_style(th.spot.tbl_cell)
			:widths { ui.Constraint.Length(2), ui.Constraint.Length(key + 2), ui.Constraint.Fill(1) },
	})
end

-- urls' sizes summed as they come, each sum handed on (a tenth of a second apart, and the last); the folders' stay with yazi
local function count(urls, each)
	local sum, last, sizes = 0, ya.time(), {}
	each(sum, false)                                     -- (the card at once, a slow disk's first answer or not)
	for _, url in ipairs(urls) do
		local it, size = fs.calc_size(url), 0
		while it do
			local next, now = it:recv(), ya.time()
			if not next then
				if it.cha.is_dir then sizes[url] = size end
				break
			end
			size, sum = size + next, sum + next
			if now >= last + 0.1 then
				last = now
				each(sum, false)
			end
		end
	end
	each(sum, true)
	for url, size in pairs(sizes) do
		ya.emit("update_files", { op = fs.op("size", { url = url.trail, sizes = { [url.key] = size } }) })
	end
end

local function counted(n, word) return n == 1 and ("1 " .. word) or (n .. " " .. word .. "s") end

local selected = ya.sync(function()
	local urls = {}
	for _, f in pairs(cx.active.selected) do urls[#urls + 1] = f.url end
	return urls
end)

local function so_far(sum, done)
	if done then return amount(sum) end
	return sum > 0 and (amount(sum) .. " so far") or "counting"
end

function M:spot(job)
	if job.mime and job.mime:find("^multi/") then
		local urls, folders = selected(), 0
		for _, url in ipairs(urls) do
			local cha = fs.cha(url)
			if cha and cha.is_dir then folders = folders + 1 end
		end
		local kinds = {}
		if folders > 0 then kinds[#kinds + 1] = counted(folders, "folder") end
		if #urls > folders then kinds[#kinds + 1] = counted(#urls - folders, "file") end
		local first = true
		return count(urls, function(sum, done)
			draw(job, first, I_MARKED, #urls .. " marked", { { "what", table.concat(kinds, " · ") }, { "size", so_far(sum, done) } })
			first = false
		end)
	end

	local file, cha, rows = job.file, job.file.cha, facts(job)
	local function after(word, row)
		for i, r in ipairs(rows) do
			if r[1] == word then return table.insert(rows, i + 1, row) end
		end
	end
	if cha.btime and cha.btime > 0 then
		after("changed", { "created", (os.date("%d %b %Y %H:%M", math.floor(cha.btime)):gsub("^0", "")) })
	end
	if cha.uid and cha.gid then
		local who, group = ya.user_name(cha.uid), ya.group_name(cha.gid)
		if who then rows[#rows + 1] = { "owner", who .. ((group and group ~= who) and (" · " .. group) or "") } end
	end
	if file.link_to then after("what", { "points to", tostring(file.link_to) }) end
	if not cha.is_dir then return draw(job, true, file.link_to and I_LINK or I_FILE, tostring(file.name), rows) end

	-- a folder: it says so in the desktop's word; its size grows while yazi sums it
	local function set(word, value)
		for _, r in ipairs(rows) do
			if r[1] == word then r[2] = value return end
		end
		table.insert(rows, 1, { word, value })
	end
	set("what", "folder")
	local first = true
	count({ file.url }, function(sum, done)
		set("size", so_far(sum, done))
		draw(job, first, I_FOLDER, tostring(file.name), rows)
		first = false
	end)
end

return M
