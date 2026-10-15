--- @sync entry
-- ~/.config/fedokawaii/yazi-pick/kawa-pick.yazi — the file dialog's Enter and Esc (yazi 26.x).
-- Enter: into a folder while opening files (yazi itself would hand the folder back and
-- kawa-pick would restart yazi in it: a flash); otherwise yazi's own open = choose.
-- Esc: first what yazi's Esc undoes (marks, visual mode, filter, find, search), then cancel,
-- as Esc closes every other pop-up of the desktop.
return {
	entry = function(_, job)
		local mode, tab = os.getenv("KAWA_PICK") or "", cx.active
		if job.args[1] == "esc" then
			local cur = tab.current
			if tab.mode.is_visual or #tab.selected > 0 or cur.files.filter or tab.finder or cur.cwd.spec.is_search then
				return ya.emit("escape", {})
			end
			return ya.emit("quit", { no_cwd_file = true })
		end
		local h = tab.current.hovered
		if h and h.cha.is_dir and mode:match("^open") and #tab.selected == 0 then
			return ya.emit("enter", {})
		end
		ya.emit("open", {})
	end,
}
