-- kawa-card.yazi — the preview of what has no picture (a binary, an empty file; yazi.toml's last previewer): a card of its
-- facts on the lists' columns (§7 Facts: a key muted, two columns, its value in the words' ink), never an empty pane.
-- What it is comes from `file`, as yazi's own fallback asks it, wrapped at a word.
local M = {}

local function facts(job)
	local cha, rows = job.file.cha, {}
	local function add(k, v) if v and v ~= "" then rows[#rows + 1] = { k, v } end end
	local out = Command(os.getenv("YAZI_FILE_ONE") or "file"):arg({ "-bL", "--", tostring(job.file.path or job.file.url) }):output()
	add("what", out and (out.stdout:gsub("%s+$", "")) or "")
	local n, u = cha.len or 0, { "B", "KB", "MB", "GB", "TB" }
	local i = 1
	while n >= 1024 and i < #u do n, i = n / 1024, i + 1 end
	add("size", string.format((i == 1 or n >= 10) and "%.0f %s" or "%.1f %s", n, u[i]))
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
			lines[#lines + 1], word = word:sub(1, w), word:sub(w + 1)
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

return M
