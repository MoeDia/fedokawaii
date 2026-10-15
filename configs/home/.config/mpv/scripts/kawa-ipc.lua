-- ~/.config/mpv/scripts/kawa-ipc.lua — every mpv window answers on its own socket,
-- $XDG_RUNTIME_DIR/mpv-<pid>.sock (a folder only you can open), so kawa-theme can hand
-- each running player the new theme's colours (load-config-file). Gone again when mpv quits.
-- A player started with its own --input-ipc-server (Syncplay, umpv, jellyfin-mpv-shim…)
-- keeps it: that program talks to mpv there (that one player then takes a theme change
-- when it next starts).
if mp.get_property("input-ipc-server", "") ~= "" then return end
local dir = os.getenv("XDG_RUNTIME_DIR")
if not dir or dir == "" then return end
local sock = dir .. "/mpv-" .. mp.get_property("pid") .. ".sock"
mp.set_property("input-ipc-server", sock)
mp.register_event("shutdown", function() os.remove(sock) end)
