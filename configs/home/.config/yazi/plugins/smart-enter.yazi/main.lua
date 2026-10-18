--- @since 25.5.31
--- @sync entry
-- ~/.config/yazi/plugins/smart-enter.yazi — Enter goes into a folder, as → and l do (yazi's
-- own Enter opens a folder in neovim), and opens files as yazi does: the selected ones, if
-- any, else the one under the cursor — a Xournal++ note (.xopp) in Xournal++, a table (.csv,
-- .tsv) in VisiData here in the window, as text opens in neovim (q brings yazi back), films
-- and music in the mpv window already open (kawa-play: yazi's own rule would start another
-- mpv each time; Alt+Enter does that, keymap.toml). The file dialog keeps its own Enter
-- (kawa-pick).
-- After yazi-rs/plugins' smart-enter.yazi (MIT).

-- a Xournal++ note is gzip inside: yazi's own rules would offer to unpack it
local function note(url) return tostring(url):lower():match("%.xopp$") ~= nil end
-- a table is text to yazi's own rules, which would open it in neovim
local function table_(url) return tostring(url):lower():match("%.[ct]sv$") ~= nil end

-- a film or a song (or a playlist of them): played in the mpv window open
local MEDIA = {}
for e in ("mkv mp4 m4v webm mov avi mpg mpeg ogv flv 3gp ts wmv mp3 flac ogg oga opus wav m4a aac wma m3u m3u8 pls"):gmatch("%S+") do
	MEDIA[e] = true
end
local function media(url) return MEDIA[(tostring(url):lower():match("%.([%w]+)$") or "")] == true end

-- the folders of the listing, by path (a selected folder named like a note stays a folder)
local function folders(tab)
	local out, files = {}, tab.current.files
	for i = 1, #files do
		if files[i].cha.is_dir then
			out[tostring(files[i].url)] = true
		end
	end
	return out
end

return {
	entry = function()
		local tab = cx.active
		local h = tab.current.hovered
		if h and h.cha.is_dir then
			return ya.emit("enter", {})
		end
		-- what opens: the selection (wherever the cursor is), else the file under the cursor
		local urls = {}
		for _, f in pairs(tab.selected) do
			-- (yazi 26 hands the selection over as Files, earlier ones as Urls)
			local ok, u = pcall(function() return f.url end)
			urls[#urls + 1] = ok and u or f
		end
		if #urls == 0 and h then
			urls[1] = h.url
		end
		local rest, tables, films, dirs = {}, {}, {}, nil
		for _, u in ipairs(urls) do
			if note(u) or table_(u) or media(u) then
				dirs = dirs or folders(tab)
			end
			if note(u) and not dirs[tostring(u)] then
				ya.emit("shell", { "xournalpp " .. ya.quote(tostring(u)), orphan = true })
			elseif table_(u) and not dirs[tostring(u)] then
				tables[#tables + 1] = ya.quote(tostring(u))
			elseif media(u) and not dirs[tostring(u)] then
				films[#films + 1] = ya.quote(tostring(u))
			else
				rest[#rest + 1] = u
			end
		end
		if #tables > 0 then
			-- all the tables in one VisiData, each a sheet (`--`: a name like -b is a file)
			ya.emit("shell", { "vd -- " .. table.concat(tables, " "), block = true })
		end
		if #films > 0 then
			-- in the order chosen: the first plays, the rest follow it (`--`: a name like -b is a file)
			ya.emit("shell", { "kawa-play -- " .. table.concat(films, " "), orphan = true })
		end
		if #rest > 0 then
			ya.emit("open", rest)
		end
	end,
}
