-- kawa-count.yazi — how many a folder holds, for the list's size column (init.lua's how_big): a fetcher (yazi.toml), so every
-- folder on the page says it at once, not only the ones the cursor has been over. Read in the background, at most LIMIT names;
-- a folder that cannot be read says nothing. Nothing here counts as a task: fetchers are yazi's own preparing (never in the footer).
local M = {}
local LIMIT = 10000

local keep = ya.sync(function(_, found)
	for url, n in pairs(found) do Holds[url] = n end
	ui.render()
end)

function M:fetch(job)
	return ya.co(function()
		local found = {}
		for _, file in ipairs(job.files) do
			local names = fs.read_dir(file.url, { limit = LIMIT, resolve = false })
			if names then found[tostring(file.url)] = #names < LIMIT and tostring(#names) or "10k+" end
			coroutine.yield(file, {})
		end
		if next(found) then keep(found) end
	end)
end

return M
