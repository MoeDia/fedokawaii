#!/usr/bin/env bash
# tests/regress/test_isolation.sh — never again a test or a probe on his screen (r27-leak: ten notices
# through the runner's own session bus) or a scratch run killing his session (r27-incident-kill: 60 of
# his programs), and no folder left in /tmp after a run (r27-test-leftovers).
. "$(dirname "$0")/lib.sh"

case_ "a test cannot reach his session: its Wayland name, session bus and runtime folder are the sandbox's"
real_bus=${DBUS_SESSION_BUS_ADDRESS:-}
sandbox
[[ $XDG_RUNTIME_DIR == "$TMP"/* ]] && _ok || _no "the runtime folder is $XDG_RUNTIME_DIR"
[[ $HOME == "$TMP"/* ]] && _ok || _no "the home is $HOME"
[[ $DBUS_SESSION_BUS_ADDRESS == *"$TMP"/* ]] && _ok || _no "the session bus is $DBUS_SESSION_BUS_ADDRESS"
[[ ! -e $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY ]] && _ok || _no "a compositor answers on $WAYLAND_DISPLAY"
[[ -z ${DISPLAY:-} && -z ${WAYLAND_SOCKET:-} ]] && _ok || _no "a display is left: ${DISPLAY:-}${WAYLAND_SOCKET:-}"
[[ $DBUS_SESSION_BUS_ADDRESS != "$real_bus" ]] && _ok || _no "the runner's own session bus"
item "r27-leak r27-leak-2 r27-53-harness" "home, runtime, bus and display all inside the sandbox"

case_ "a headless run is fenced: a PID namespace of its own, the kit goes through it"
hl=$REPO/tools/hl-dwl.sh
has "$(grep -E '^fence=' "$hl")" "--pid" "tools/hl-dwl.sh runs in the session's own PID space"
has "$(grep -E '^fence=' "$hl")" "--kill-child" "a run outliving its dwl"
grep -q 'hl-dwl.sh' "$REPO/tools/kit.sh" && _ok || _no "tools/kit.sh no longer goes through hl-dwl.sh"
item r27-incident-kill "hl-dwl.sh: unshare --pid --kill-child; tools/kit.sh inside it"

case_ "a test leaves nothing behind: a whole test's folder gone at its end, its processes with it"
d=$(mktemp -d "$TMP/left.XXXXXX")
out=$(TMPDIR=$d bash -c '. "$1/tests/lib/harness.sh"; sandbox; (TMP=$TMP exec -a kawa-leftover sleep 60) & disown; case_ x; _ok; done_' _ "$REPO" 2>&1)
has "$out" "1 passed"
eq "$(find "$d" -mindepth 1 | wc -l)" 0 "left in the temporary folder: $(find "$d" -mindepth 1 | head -n 3)"
item r27-test-leftovers "a sandbox's folder and its background process gone with the test"
done_
