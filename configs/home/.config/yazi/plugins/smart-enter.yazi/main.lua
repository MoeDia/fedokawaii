--- @since 25.5.31
--- @sync entry
-- ~/.config/yazi/plugins/smart-enter.yazi — Enter goes into a folder, as → and l do (yazi's
-- own Enter opens a folder in neovim), and opens a file as yazi does: the selected ones, if
-- any, else the one under the cursor. The file dialog keeps its own Enter (kawa-pick).
-- After yazi-rs/plugins' smart-enter.yazi (MIT).
return {
	entry = function()
		local h = cx.active.current.hovered
		ya.emit(h and h.cha.is_dir and "enter" or "open", {})
	end,
}
