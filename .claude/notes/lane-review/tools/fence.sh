#!/usr/bin/env bash
# run a command cut off from his session
exec env -u WAYLAND_DISPLAY -u DISPLAY DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent XDG_RUNTIME_DIR=/dev/shm/lane-review/rt "$@"
