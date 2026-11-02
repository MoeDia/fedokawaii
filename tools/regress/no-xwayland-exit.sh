#!/usr/bin/env bash
# tools/regress/no-xwayland-exit.sh — never again a crash as dwl ends when Xwayland could not start
# (3 Nov: its two listeners were unlinked though never attached — a segfault at every exit of a dwl
# that ran without it): dwl headless in a user namespace that cannot see the owner of
# /tmp/.X11-unix (so Xwayland refuses it), ended by its startup script after a second.
#   bash tools/regress/no-xwayland-exit.sh [DWL]   (default the installed /usr/local/bin/dwl)
# Exit 0 it ended cleanly · 1 it crashed (its status said) · 2 the check could not run
set -u
bin=${1:-/usr/local/bin/dwl}
[[ -x $bin ]] || { echo "no-xwayland-exit: no dwl at $bin" >&2; exit 2; }
rt=$(mktemp -d /tmp/regress-nox.XXXXXX) || exit 2
trap 'rm -rf "$rt"' EXIT
chmod 700 "$rt"
env -u WAYLAND_DISPLAY -u DISPLAY -u DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR="$rt" WLR_BACKENDS=headless \
  WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 WLR_HEADLESS_OUTPUTS=1 \
  timeout 30 unshare --user --map-user="$(id -u)" --map-group="$(id -g)" --pid --fork --mount-proc --kill-child \
  "$bin" -s 'sleep 1; kill $PPID' >"$rt/log" 2>&1
rc=$?
grep -q 'failed to setup XWayland' "$rt/log" || { echo "no-xwayland-exit: Xwayland started after all — nothing proven (exit $rc)" >&2; exit 2; }
((rc == 0)) && { echo "no-xwayland-exit: dwl ran without Xwayland and ended cleanly"; exit 0; }
echo "no-xwayland-exit: dwl without Xwayland ended with status $rc$( ((rc > 128)) && echo " (signal $((rc - 128)))")"
exit 1
