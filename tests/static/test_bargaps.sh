#!/usr/bin/env bash
# tests/static/test_bargaps.sh — the bar's spacing, worked out from the drawings and the style:
#   · an icon before a value (icons.sh's ICON_BAR_*): exactly 6 px from the icon's ink to the
#     value's (a letter's ink starts at its left edge), whatever the icon's own air; a
#     family's (vol-*, bri-*) ink starting at one place, so a level never moves the module
#   · every module with an icon and a value draws it with ICON_BAR_*, never "icon value"
#   · no module holds a fixed width (which would put paper after the value, not 18 px)
#   · the stitches 9 px from their neighbours' boxes; the edges' buttons 8 from the screen's
. "$(dirname "$0")/../lib/harness.sh"

case_ "ICON_BAR_*: 6 px from every icon's ink to the value's; one start in a family"
out=$(python3 -I - "$REPO" <<'EOF'
import re, sys
root = sys.argv[1]
src = open(root + "/tools/build-icons.py").read().split("if __name__")[0]
g = {"__name__": "bi", "__file__": root + "/tools/build-icons.py"}
exec(compile(src, "build-icons", "exec"), g)
icons = g["twins"](g["parse"](open(root + "/art/icons.txt").read()))
by_cp = {g["FIRST"] + i: ic for i, ic in enumerate(icons)}
bad, start = [], {}
for line in open(root + "/configs/home/.config/fedokawaii/icons.sh"):
    m = re.match(r"ICON_BAR_(\w+)=\$'(.*)'$", line.strip())
    if not m:
        continue
    text = bytes(int(h, 16) for h in m.group(2).split("\\x")[1:]).decode()
    x, ink = 0, None
    for ch in text:
        ic = by_cp[ord(ch)]
        cols = [i for r in ic["rows"] for i, c in enumerate(r) if c == "#"]
        if cols:
            ink = (x + ic["x"] + min(cols), x + ic["x"] + max(cols))
        x += ic["adv"]
    name = m.group(1).lower().replace("_", "-")
    if x - ink[1] - 1 != 6:
        bad.append(f"{name}: {x - ink[1] - 1} px to the value")
    start.setdefault(g["family"](name), set()).add(ink[0])
bad += [f"{f}: its icons start at {sorted(s)}" for f, s in start.items() if len(s) > 1]
print("\n".join(bad))
EOF
)
[[ -z $out ]] && _ok || _no "$out"

case_ "the modules draw an icon before a value with ICON_BAR_* (no space between)"
bad=$(grep -nE '\$ICON_(VOL_[0-4]|VOL_MUTE|BRI_[0-4]|MEMORY|USB|HOURGLASS)\b[^"]* (\$|%|<span)|"%s %s<span|"%s %d' \
  "$REPO/bin/kawa-volume" "$REPO/bin/kawa-brightness" "$REPO/bin/kawa-mem" "$REPO/bin/kawa-drives" "$REPO/bin/kawa-timer" \
  | grep -vE ':[0-9]+:\s*#|notify-send|line (row|on)')
[[ -z $bad ]] && _ok || _no "$bad"
for f in kawa-volume kawa-brightness kawa-mem kawa-drives kawa-timer kawa-weather; do
  grep -q 'ICON_BAR_' "$REPO/bin/$f" || _no "$f draws no ICON_BAR_"
done
grep -q 'bar_download' "$REPO/bin/kawa-downloads" && _ok || _no "kawa-downloads draws its icon with a space"

CSS=$REPO/configs/home/.config/waybar/style.css
case_ "no module of the bar holds a fixed width past its button's; the stitches 9 px off"
bad=$(grep -nE 'min-width: *[0-9]+px' "$CSS" | grep -vE 'min-width: *(0|1|23)px')
[[ -z $bad ]] && _ok || _no "$bad"
grep -qE '^\s*margin: 4px 9px 4px 9px;' "$CSS" && _ok || _no "the stitch's margins are not 9 | 9"
case_ "the left: 18 px from the torii's ink to the first seal, 6 between seals, 18 to the layout's and the title's ink"
grep -qE '^#custom-tag1 \{ margin-left: 12px; \}' "$CSS" && _ok || _no "first seal"
grep -qE '^#custom-tag9 \{ margin-left: 6px; \}' "$CSS" && _ok || _no "between seals"
grep -qE '^#custom-layout \{[^}]*margin-left: 13px;' "$CSS" && _ok || _no "layout"
grep -qE '^#custom-title +\{[^}]*padding: 0 12px 0 13px;' "$CSS" && _ok || _no "title"
case_ "the edges: the torii's and the cat's buttons 8 px from the screen's edges"
grep -qE '^#custom-torii \{ margin-left: 8px;' "$CSS" && _ok || _no "torii"
grep -qE '^#custom-menu \{[^}]*margin: 4px 8px 4px 4px; padding-right: 1px;' "$CSS" && _ok || _no "cat"

done_
