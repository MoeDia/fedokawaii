#!/usr/bin/env bash
# tests/session/test_cursor.sh — the pointer's image is always the one of what is under it.
# The busy watch that stayed on the wallpaper after login (the tracker's SLP-04): dwl 0.9's motionnotify looked up
# the surface under the cursor before moving it, so every motion was judged at the place the
# pointer had just left. A flick ending on another surface in one event (off a loading window
# — Steam's splash, a browser restoring its tabs — onto the wallpaper or the bar) left the old
# window the pointer's focus and its image until the mouse moved again. src/dwl/dwl.patch
# looks again once the cursor has moved (undercursor()).
# (Shown on a headless dwl: an X11 window with the watch cursor, the pointer jumped onto the
# gap beside it in one event — the watch stayed before the change, the arrow after.)
. "$(dirname "$0")/../lib/harness.sh"

P=$REPO/src/dwl/dwl.patch
case_ "motionnotify looks under the cursor again after moving it, before the pointer's focus is given"
out=$(python3 -I - "$P" <<'EOF'
import re, sys
# the hunks the patch makes in motionnotify (upstream: the move is followed by the update of
# selmon, then the drag icon — the second look goes between, before the focus is given)
hunks = re.split(r"(?m)^(?=@@ )", open(sys.argv[1]).read())
ok = any("motionnotify(" in h.splitlines()[0] for h in hunks
         if re.search(r"(?m)^ \t\t\tselmon = xytomon\(cursor->x, cursor->y\);\n \t}\n \n(\+[^\n]*\n)*\+\tif \(time\)\n\+\t\tundercursor\(&surface, &c, &l, &sx, &sy\);\n", h))
print("" if ok else "no look under the cursor once it has moved (after selmon's update, in motionnotify)")
EOF
)
[[ -z $out ]] && _ok || _no "$out"
case_ "undercursor keeps a held button's surface (a drag out of a window stays with it)"
grep -q '^+	if (cursor_mode == CurPressed && !seat->drag' <(sed -n '/^+undercursor(/,/^+}/p' "$P") && _ok || _no "undercursor lost the held-button rule"

done_
