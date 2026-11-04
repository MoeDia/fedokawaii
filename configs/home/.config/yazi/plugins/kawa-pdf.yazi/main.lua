--- @since 26.9.1
-- ~/.config/yazi/plugins/kawa-pdf.yazi — a PDF's preview: yazi's own (its page drawn by
-- pdftoppm, J/K turning the pages), but a PDF locked with a password says so in the desktop's
-- words — the lock icon, locked, and that Enter opens it in the reader, which asks for the password —
-- instead of pdftoppm's "Failed to convert PDF to image, stderr: Command Line Error: Incorrect
-- password" — said as kawa-rar says a locked archive and the lists say what is not there (§7: from
-- the first row, the lock in the icon column, the words on the names' column; never centred).
-- Any other PDF that cannot be drawn says why in one line. yazi.toml puts it before
-- the preset (whose name a plugin of ours cannot take: yazi keeps its own).
-- After yazi's preset pdf.lua (v26.9.1, MIT): kept in step with the yazi lib/upstream.sh pins.

local M = {}
local ICON_LOCK = "\243\190\128\160" -- Sumi Icons: lock (U+FE020), as in icons.sh

-- (pdftoppm's words for a PDF that needs a password to be opened)
local function locked(stderr) return stderr:find("Incorrect password", 1, true) ~= nil end

local NAME_AT = "  " -- (the cursor's cell and the icon's column, as the lists' rows)
local function say(job, lines) ya.preview_widget(job, ui.Text(lines):area(job.area)) end
-- words on the names' column, faint, wrapped at a word to the pane's width W (never cut inside one)
local function hint(words, w)
	local rows, line = {}, ""
	local function put() rows[#rows + 1] = ui.Line(NAME_AT .. "   " .. line):fg("darkgray") end
	for word in words:gmatch("%S+") do
		if line ~= "" and ui.Line(line .. " " .. word):width() > w then
			put()
			line = word
		else
			line = line == "" and word or line .. " " .. word
		end
	end
	if line ~= "" then put() end
	return rows
end

function M:peek(job)
	local start, cache = os.clock(), ya.file_cache(job)
	if not cache then
		return
	end

	local ok, err, bound, lock = self:preload(job)
	if bound and bound > 0 then
		return ya.emit("peek", { bound - 1, only_if = job.file.url, upper_bound = true })
	elseif lock then
		local rows = { ui.Line { ui.Span(NAME_AT .. ICON_LOCK):fg("red"), ui.Span("  locked") } }
		for _, r in ipairs(hint("Enter opens it: the reader asks the password", job.area.w - 5)) do
			rows[#rows + 1] = r
		end
		return say(job, rows)
	elseif not ok or err then
		return ya.preview_widget(job, err)
	end

	ya.sleep(math.max(0, rt.preview.image_delay / 1000 + start - os.clock()))

	local _, err = ya.image_show(cache, job.area)
	ya.preview_widget(job, err)
end

function M:seek(job)
	local h = cx.active.current.hovered
	if h and h.url == job.file.url then
		local step = ya.clamp(-1, job.units, 1)
		ya.emit("peek", { math.max(0, cx.active.preview.skip + step), only_if = job.file.url })
	end
end

function M:preload(job)
	local cache = ya.file_cache(job)
	if not cache or fs.cha(cache) then
		return true
	end

	-- stylua: ignore
	local output, err = Command("pdftoppm")
		:arg({
			"-f", job.skip + 1,
			"-l", job.skip + 1,
			"-singlefile",
			"-jpeg", "-jpegopt", "quality=" .. rt.preview.image_quality,
			tostring(job.file.path), tostring(cache),
		})
		:output()

	if not output then
		return true, Err("PDF not drawn: pdftoppm did not start (%s)", err)
	elseif not output.status.success then
		if locked(output.stderr) then
			return true, nil, nil, true
		end
		local pages = job.skip > 0 and tonumber(output.stderr:match("the last page %((%d+)%)"))
		local why = (output.stderr:match("[^\n]+") or ""):gsub("^Command Line Error: ", ""):gsub("^Syntax Error: ", "")
		return true, Err("PDF not drawn: %s", why), pages
	end

	return ya.image_precache(Url(cache .. ".jpg"), cache)
end

return M
