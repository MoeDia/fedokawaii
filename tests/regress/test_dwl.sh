#!/usr/bin/env bash
# tests/regress/test_dwl.sh — never again a layout that holds the screen a quarter of a second
# (r26-fu-7: 250 → 60/50 ms, "the screen stalls when a window opens"), read from the patch itself.
. "$(dirname "$0")/lib.sh"

case_ "the layout's holds: the longest a screen waits for a window"
p=$REPO/src/dwl/dwl.patch
r=$(sed -n 's/^+#define HOLD_RESIZE_MS \([0-9]*\).*/\1/p' "$p") m=$(sed -n 's/^+#define HOLD_MAP_MS \([0-9]*\).*/\1/p' "$p")
[[ -n $r && -n $m ]] && _ok || _no "HOLD_RESIZE_MS or HOLD_MAP_MS not in the patch"
((${r:-999} <= 60)) && _ok || _no "a resize holds the screen $r ms (at most 60)"
((${m:-999} <= 50)) && _ok || _no "a new window holds the screen $m ms (at most 50)"
item r26-fu-7 "a resize holds at most $r ms, a new window $m ms"
done_
