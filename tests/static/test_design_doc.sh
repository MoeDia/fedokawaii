#!/usr/bin/env bash
# tests/static/test_design_doc.sh — docs/design-system.md, the single truth, read back: whole
# (no open questions, every section where scripts cite it, every file it names there), its
# palette equal to tools/wada-palette.py's, its contrast table equal to the measured one — and,
# for every surface already rebuilt to it (BUILT, §14), its numbers in that surface's files.
# A task of round 27 that rebuilds a surface adds it to BUILT with a check of its own below.
. "$(dirname "$0")/../lib/harness.sh"
sandbox
DOC=$REPO/docs/design-system.md
BUILT=(palette ui-face term-face menus bar windows notices)

case_ "whole: no open question left in it"
grep -nE '\b(TBD|TODO|FIXME|XXX)\b|\?\?' "$DOC" >"$TMP/open" && _no "$(head -3 "$TMP/open")" || _ok

case_ "the sections, numbered as the scripts cite them (§0–§15, in order)"
eq "$(grep -oE '^## [0-9]+\.' "$DOC" | tr -dc '0-9\n' | paste -sd ' ')" "0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15"

case_ "every file it names is in the repository"
grep -oE '`(bin|tools|configs|system|src|art|docs|lib|tests)/[^` ]+`' "$DOC" | tr -d '`' | sort -u >"$TMP/paths"
missing=$(while read -r p; do [[ -e $REPO/$p ]] || echo "$p"; done <"$TMP/paths")
eq "$missing" "" "named but not there: $missing"
[[ -s $TMP/paths ]] && _ok || _no "no paths read (the pattern?)"

case_ "the palette (§1): every token's hex, both moods, as tools/wada-palette.py makes it"
python3 -I - "$DOC" "$REPO/tools/wada-palette.py" >"$TMP/pal" <<'PY'
import importlib.util, re, sys
spec = importlib.util.spec_from_file_location("wp", sys.argv[2]); wp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wp)
P, kami, tile, editor = wp.palette()
want = {k: (P["dark"][k], P["light"][k]) for k in wp.DOC_TOKENS + wp.DOC_TERM}
want["tile"] = (tile["dark"], tile["light"])
got, bad = {}, []
for line in open(sys.argv[1], encoding="utf-8"):
    for tok, d, l in re.findall(r"\| `([a-z_0-9]+)` \| `([0-9a-f]{6})`[^|]*\| `([0-9a-f]{6})`[^|]*", line):
        got[tok] = (d, l)
for k, v in want.items():
    if got.get(k) != v:
        bad.append(f"{k}: doc {got.get(k)} palette {v}")
for k in got:
    if k not in want:
        bad.append(f"{k}: in the doc, not a token")
print(len(got)); print("\n".join(bad))
PY
eq "$(head -1 "$TMP/pal")" "$(( $(python3 -I -c 'import importlib.util,sys; s=importlib.util.spec_from_file_location("wp",sys.argv[1]); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); print(len(m.DOC_TOKENS)+len(m.DOC_TERM))' "$REPO/tools/wada-palette.py") + 1 ))" "tokens read from the doc"
eq "$(tail -n +2 "$TMP/pal")" "" "the doc and the palette differ"

case_ "the contrast table (§1) is the measured one (tools/wada-palette.py --table)"
python3 -I - "$DOC" "$REPO/tools/wada-palette.py" <<'PY' >"$TMP/con"
import importlib.util, re, sys
spec = importlib.util.spec_from_file_location("wp", sys.argv[2]); wp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wp)
P = wp.palette()[0]
roles = ["faint", "muted", "text", "strong", "accent_text", "asagi"]
bad = []; n = 0
for line in open(sys.argv[1], encoding="utf-8"):
    m = re.match(r"\| (dark|light) `(ground|key|surface)` \| (.*) \|$", line.strip())
    if not m: continue
    n += 1
    cells = [c.strip() for c in m.group(3).split("|")]
    for r, c in zip(roles, cells):
        meas = f"{wp.contrast(P[m.group(1)][r], P[m.group(1)][m.group(2)]):.1f}"
        if c != meas: bad.append(f"{m.group(1)} {m.group(2)} {r}: doc {c}, measured {meas}")
print(n); print("\n".join(bad))
PY
eq "$(head -1 "$TMP/con")" 4 "rows read"
eq "$(tail -n +2 "$TMP/con")" ""

# ── the surfaces rebuilt to it (§14) ───────────────────────────────────────────────────────────
built_palette() {   # the generated theme files carry the doc's inks
  local m; for m in dark light; do
    local f=$REPO/configs/home/.config/fedokawaii/themes/$m
    eq "$(sed -n 's/^ground=//p' "$f/panel.conf") $(sed -n 's/^accent=//p' "$f/panel.conf")" \
       "$(grep -oE '^\| `(ground|accent)` \| `[0-9a-f]{6}`[^|]*\| `[0-9a-f]{6}`' "$DOC" \
          | sed -E "s/.*\| \`([0-9a-f]{6})\`[^|]*\| \`([0-9a-f]{6})\`/\1 \2/" \
          | awk -v m="$m" '{print (m == "dark") ? $1 : $2}' | paste -sd ' ')" "$m: panel.conf's ground and accent"
  done
}
built_ui-face() {   # §2: Sumi UI as the doc's table says it is, and 14 px wherever it is set
  eq "$(python3 -I - "$REPO/system/fonts/SumiUI.ttf" "$DOC" <<'PY'
import re, sys
from PIL import Image, ImageDraw, ImageFont
f = ImageFont.truetype(sys.argv[1], 14)
def rows(ch):
    im = Image.new("1", (20, 20), 0); d = ImageDraw.Draw(im); d.fontmode = "1"; d.text((0, 0), ch, font=f, fill=1)
    ys = [y for y in range(20) for x in range(20) if im.getpixel((x, y))]
    return f"{min(ys)}–{max(ys)}" if min(ys) != max(ys) else f"{min(ys)}"
doc = open(sys.argv[2], encoding="utf-8").read()
table = dict((m.group(2), m.group(1)) for m in re.finditer(r"^\| ([0-9–]+) \| (.+?) \|$", doc.split("**Sumi UI's em**")[1].split("\n\n")[1], re.M))
got = {"kanji and kana (a column of air at their left)": rows("漢"), "capitals, digits, ascenders (10 rows)": rows("H"),
       "the x-height (7 rows)": rows("x"), "the minus — and every rule drawn beside words (§4)": rows("-")}
bad = [f"{k}: doc {table.get(k)}, font {v}" for k, v in got.items() if table.get(k) != v]
adv = {round(f.getlength(c)) for c in "Hil0@~"} | {round(f.getlength("漢")) // 2}
print(len(table), bad, sorted(adv))
PY
)" "5 [] [7]" "the em's rows and the cell, read from the doc's table, measured on the font"
  has "$(cat "$REPO/configs/home/.config/waybar/style.css")" "font-size: 14px;" "the bar"
  has "$(cat "$REPO/configs/home/.config/mako/config")" "14px" "the notices"
  eq "$(sed -n 's/^LINE = \([0-9]*\).*/\1/p; s/^COL = \([0-9]*\).*/\1/p' "$REPO/bin/kawa-panel" | paste -sd ' ')" "7 14" "kawa-panel's COL and LINE"
}
built_term-face() {   # §2: Sumi Term as the doc's table gives it — in foot, the alias, the pins
  local row px cell line
  row=$(grep -E '^\| \*\*Sumi Term\*\* \|' "$DOC")
  px=$(awk -F' \\| ' '{print $4}' <<<"$row"); cell=$(awk -F' \\| ' '{print $5}' <<<"$row"); line=$(awk -F' \\| ' '{print $6}' <<<"$row")
  eq "$px|$cell|$line" "16 px|8 × 20|20" "the doc's row (size, cell, line)"
  local ini=$REPO/configs/home/.config/foot/foot.ini
  has "$(cat "$ini")" "font=Sumi Term:pixelsize=${px% px},"; has "$(cat "$ini")" "line-height=${line}px"
  has "$(cat "$ini")" "pad=8x8" "foot's pad: 8, the screen's own cell of margin making 16"
  has "$(cat "$REPO/system/60-fedokawaii-pixel.conf")" "<family>Sumi Term</family>
    <prefer><family>UDEV Gothic NF</family></prefer>" "the alias"
  eq "$(. "$REPO/lib/upstream.sh"; printf '%s\n' "${TERM_FACE_FILES[@]}" | cut -d'|' -f1 | paste -sd ' ')" \
     "UDEVGothicNF-Regular.ttf UDEVGothicNF-Bold.ttf UDEVGothicNF-Italic.ttf UDEVGothicNF-BoldItalic.ttf" "its four files pinned"
}
built_menus() {   # §3–§4: the panels' and menus' grid — the doc's table read, kawa-panel's numbers the same
  eq "$(python3 -I - "$REPO/bin/kawa-panel" "$DOC" <<'PY'
import importlib.machinery, importlib.util, re, sys
sys.dont_write_bytecode = True   # (-I ignores PYTHONDONTWRITEBYTECODE: no bin/__pycache__ in the copy)
loader = importlib.machinery.SourceFileLoader("kawa_panel", sys.argv[1])
spec = importlib.util.spec_from_loader("kawa_panel", loader); kp = importlib.util.module_from_spec(spec); loader.exec_module(kp)
grid = open(sys.argv[2], encoding="utf-8").read().split("## 3. Grid")[1].split("## 4.")[0]
def row(name):
    m = re.search(r"^\| " + re.escape(name) + r" \| ([^|]+) \|", grid, re.M)
    return m.group(1).strip() if m else None
got = {"cell": f"{kp.CELL} × {kp.ROW}", "row": str(kp.ROW), "pad": str(kp.PAD), "hairline": str(kp.HAIR),
       "shadow": str(kp.SHADOW_B), "icon column": str(kp.GLYPH_COL), "content": str(kp.INNER),
       "tile": f"{kp.MON_W} × {kp.MON_H}", "key": f"{kp.KEY_H} high", "meter": f"{kp.SPAN} × {kp.SEG_H}",
       "gap": str(kp.GAP)}
bad = [f"{k}: doc {row(k)}, kawa-panel {v}" for k, v in got.items() if row(k) != v]
print(bad, kp.SEGS, kp.SEG_W, kp.DOT, kp.SHADOW_R, kp.NAME_X // kp.CELL, kp.HEAD_X // kp.CELL)
PY
)" "[] 20 6 6 1 4 3" "the doc's grid (§3) in kawa-panel: cell, row, pad, hairline, shadow, icon column, content, tile, key, meter, gap; 20 segments of 6; the dot 6; the shadow's column 1; a row's name at cell 4, a heading's at cell 3"
  has "$(cat "$REPO/configs/home/.config/mako/config")" "width=410" "a notice as wide as quick settings (§3: 410 with pad and hairlines)"
  lacks "$(grep -n 'part[^a-z]*[一-龯]' "$REPO"/bin/kawa-* 2>/dev/null)" "part" "no kanji heading in any menu (§13)"
}
built_bar() {   # §3, §8, §12: the bar's rows and spacing — the doc's numbers in waybar's config, its style and its pictures
  local doc cfg css
  doc=$(cat "$DOC"); cfg=$(sed 's#^ *//.*##' "$REPO/configs/home/.config/waybar/config.jsonc"); css=$(cat "$REPO/configs/home/.config/waybar/style.css")
  has "$doc" "| bar | 27 | — | 3 air, hairline, 20 paper, hairline, 2 shadow (§8) |" "the doc's bar: 27 rows"
  has "$cfg" '"height": 27,' "waybar's height: 27"
  has "$cfg" '"margin-bottom": -2,' "its zone ends on the lower hairline (the windows' tops on y 33)"
  has "$(cat "$REPO/src/dwl/config.h")" "outergappx       = 8;" "dwl's outer gap: the doc's 8 (§12)"
  eq "$(python3 -I -c 'from PIL import Image; import sys; print(Image.open(sys.argv[1]).size[1])' "$REPO/configs/home/.config/fedokawaii/themes/dark/kami-tile.png")" 27 "the tile's picture: 27 rows"
  has "$doc" "4 px between
the tiles of a group, 12 px between groups" "the doc's gaps"
  has "$css" "margin: 0 0 0 3px;" "within a group: 3 and the shadow's column (4)"
  has "$css" "#custom-tag1 { margin-left: 11px; }" "between groups: 11 and the shadow's column (12)"
  has "$doc" "the outer tiles' hairlines on x 8 and x 1911" "the doc's edges"
  has "$css" "#custom-torii { margin-left: 8px;" "the torii's hairline on x 8"
  has "$css" "#custom-menu  { margin-left: 11px; margin-right: 7px; }" "the cat's on x 1911 (its shadow's column and 7 to the edge)"
  lacks "$css" "kami-seal-narrow" "one seal for every numeral (10 × 10, §4)"
}
built_windows() {   # §4, §12: the windows' frame — the doc's numbers in dwl's config and colours
  local doc ch
  doc=$(cat "$DOC"); ch=$(cat "$REPO/src/dwl/config.h")
  has "$doc" "8 px between hairlines — window and window, window and the screen's edge, the bar's" "the doc's gaps"
  has "$ch" "borderpx         = 1;" "a 1 px hairline (§4)"
  has "$ch" "gappx            = 8;" "8 px between windows"
  has "$ch" "outergappx       = 8;" "8 px to the screen's edges and the bar's hairline"
  for t in dark light; do
    eq "$(grep -cE '^(focus|border|urgent|shadow1|shadow2) [0-9a-f]{8}$' "$REPO/configs/home/.config/fedokawaii/themes/$t/dwl.colors")" 5 "$t: the three hairlines and the shadow's two inks, RRGGBBAA"
  done
  has "$(cat "$REPO/src/dwl/dwl.patch")" "the shadow's parts, 4–6, lie outside the window" "the shadow outside the window, in the gap"
}
built_notices() {   # §4, §9: notices — the doc's numbers in mako's config, the frame in the desktop's mako
  local doc cfg
  doc=$(cat "$DOC"); cfg=$(cat "$REPO/configs/home/.config/mako/config")
  has "$doc" "a panel 47 cells wide (410 px)" "the doc's width"
  has "$cfg" $'\nwidth=410\n' "410 wide"; has "$cfg" $'\nborder-size=1\n' "a 1 px hairline"
  has "$cfg" $'\npadding=16\n' "16 px of pad"; has "$cfg" $'\nmargin=8\n' "8 px to the next and the edges"
  has "$cfg" $'\nhanging-indent=21\n' "the body under the title's words (the icon's 14 px, 7 of air)"
  eq "$(( $(sed -n 's/^height=//p' <<<"$cfg") - 2 - 32 ))" 140 "whole rows: seven of 20"
  for t in dark light; do
    has "$(cat "$REPO/configs/home/.config/fedokawaii/themes/$t/mako")" "shadow-color=#" "$t: the frame's shadow"
    has "$(cat "$REPO/configs/home/.config/fedokawaii/themes/$t/mako")" "summary-icon-color=#" "$t: the title's icon in its own ink"
  done
  has "$(cat "$REPO/src/mako/mako.patch")" "shadow-color" "the desktop's mako draws them (src/mako/mako.patch)"
}
for s in "${BUILT[@]}"; do
  case_ "§14 $s: rebuilt to the doc — its numbers in its files"
  "built_$s"
done
done_
