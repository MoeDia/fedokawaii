--- @since 26.9.1
-- ~/.config/yazi/plugins/kawa-rar.yazi — a RAR archive's preview (a comic's .cbr too): its entries
-- from unrar, one a row at the names' column, J/K scrolling them — Fedora's 7-Zip has no RAR, so
-- yazi's own archive preview only errs on one. A locked one says so. Enter on one opens File tools
-- (kawa-file: unpack, list, test — unrar inside, a password asked in place: yazi.toml's [open]).
local M = {}
local ICON_FILE = "\243\190\128\189" -- Sumi Icons: file (U+FE03D), as in icons.sh
local ICON_LOCK = "\243\190\128\160" -- lock (U+FE020)
local NAME_AT = "  "                 -- (the cursor's cell and the icon's column, as the lists' rows)

local function say(job, lines) ya.preview_widget(job, ui.Text(lines):area(job.area)) end

function M:peek(job)
	local out = Command("unrar"):arg({ "lb", "-p-", "--", tostring(job.file.url) })
		:stdout(Command.PIPED):stderr(Command.PIPED):output()
	if not out or not out.status.success then
		local err = (out and (out.stderr .. out.stdout)) or "unrar did not run"
		if err:find("password", 1, true) or err:find("encrypted", 1, true) then
			return say(job, {
				ui.Line { ui.Span(NAME_AT .. ICON_LOCK):fg("red"), ui.Span("  locked") },
				ui.Line(NAME_AT .. "   Enter opens File tools: it asks the password"):fg("darkgray"),
			})
		end
		return say(job, { ui.Line(NAME_AT .. "   cannot be read: " .. (err:match("[^\n]+") or "?")):fg("darkgray") })
	end
	local rows, n = {}, 0
	for name in out.stdout:gmatch("[^\n]+") do
		n = n + 1
		if n > job.skip and #rows < job.area.h then
			rows[#rows + 1] = ui.Line(NAME_AT .. ICON_FILE .. "  " .. name)
		end
	end
	if job.skip > 0 and n < job.skip + job.area.h then   -- (scrolled past the end: back to the last page)
		return ya.emit("peek", { math.max(0, n - job.area.h), only_if = job.file.url, upper_bound = true })
	end
	say(job, rows)
end

function M:seek(job)
	local h = cx.active.current.hovered
	if h and h.url == job.file.url then
		ya.emit("peek", { math.max(0, cx.active.preview.skip + job.units), only_if = job.file.url })
	end
end

return M
