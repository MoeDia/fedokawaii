--- @sync peek
-- kawa-folder.yazi — a folder's preview: yazi's own (preset/plugins/folder.lua, 26.9.1), with what is not there yet said quietly
-- where a row's name would stand (§1 faint; never centred, never "…"): an empty folder, one still being read, one that cannot be.
local M = {}

local function quiet(job, s)
	ya.preview_widget(job, ui.Line { ui.Span("     " .. s):fg("22") }:area(job.area))
end

function M:peek(job)
	local folder = cx.active.preview.folder
	if not folder then
		return quiet(job, "loading")
	elseif folder.cwd ~= job.file.url then
		return
	end

	local bound = math.max(0, #folder.files - job.area.h)
	if job.skip > bound then
		return ya.emit("peek", { bound, only_if = job.file.url, upper_bound = true })
	end

	if #folder.files == 0 then
		local done, err = folder.stage()
		return quiet(job, not done and "loading" or err and ("cannot be read: " .. tostring(err)) or "empty")
	end

	local left, right = {}, {}
	for _, f in ipairs(folder.window) do
		local entity = Entity:new(f)
		left[#left + 1], right[#right + 1] = entity:redraw(), Linemode:new(f):redraw()
		local max = math.max(0, job.area.w - right[#right]:width())
		left[#left]:truncate { max = max, ellipsis = entity:ellipsis(max) }
	end

	local marker_area = job.area { x = math.max(0, job.area.x - 1) }
	ya.preview_widget(job, {
		ui.List(left):area(job.area),
		ui.Text(right):area(job.area):align(ui.Align.RIGHT),
		table.unpack(Marker:new(marker_area, folder):redraw()),
	})
end

function M:seek(job)
	local folder = cx.active.preview.folder
	if folder and folder.cwd == job.file.url then
		local step = math.floor(job.units * job.area.h / 10)
		local bound = math.max(0, #folder.files - job.area.h)
		ya.emit("peek", { ya.clamp(0, cx.active.preview.skip + step, bound), only_if = job.file.url })
	end
end

return M
