-- ~/.config/mpv/scripts/kawa-resume.lua — keep-open leaves a finished file paused on its
-- last frame, and quitting there would save that spot: the next time it would open at the
-- very end. So at the end of a file its saved position is dropped (it opens at the start
-- next time) until you seek back into it, when saving on quit is back on.
local wanted = mp.get_property_bool("save-position-on-quit")
mp.observe_property("eof-reached", "bool", function(_, eof)
    if not wanted then return end
    if eof then mp.commandv("delete-watch-later-config") end
    mp.set_property_bool("save-position-on-quit", not eof)
end)
