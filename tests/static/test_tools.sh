#!/usr/bin/env bash
# tests/static/test_tools.sh — the measuring tools themselves (tools/px.py on a picture with known
# answers drawn here; tools/hl-dwl.sh and tools/shot.sh: their arguments) — a tool that measures
# wrong would pass a wrong design. framestat.py has its own: tests/session/test_framelog.sh.
. "$(dirname "$0")/../lib/harness.sh"
sandbox
PX=$REPO/tools/px.py
img=$TMP/known.png
python3 -I - "$img" <<'PY'
import sys
from PIL import Image
im = Image.new("RGB", (100, 40), (16, 16, 24))          # ground
for x in range(10, 30):                                 # a red box 20×10 at 10,5
    for y in range(5, 15): im.putpixel((x, y), (207, 86, 54))
for x in range(38, 48):                                 # a gold box 10×10 at 38,5 (gap 8)
    for y in range(5, 15): im.putpixel((x, y), (201, 164, 92))
for x in range(52, 60):                                 # a box 8×20 at 52,10 (gap 4)
    for y in range(10, 30): im.putpixel((x, y), (200, 200, 200))
im.save(sys.argv[1])
PY
case_ "px.py gaps: the spans along x and the gaps between them (8 and 4), lead and trail"
out=$(python3 "$PX" gaps "$img" x --json)
eq "$(python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["spans"], d["gaps"], d["lead"], d["trail"], d["background"])' <<<"$out")" \
   "[[10, 20], [38, 10], [52, 8]] [8, 4] 10 40 #101018"
case_ "px.py boxes: three, where they are, their sizes"
eq "$(python3 "$PX" boxes "$img" --json | python3 -c 'import json,sys; print([(b["x"],b["y"],b["w"],b["h"]) for b in json.load(sys.stdin)])')" \
   "[(10, 5, 20, 10), (38, 5, 10, 10), (52, 10, 8, 20)]"
case_ "px.py runs: a row's colour stripes; a column's"
eq "$(python3 "$PX" runs "$img" row 7 --json | python3 -c 'import json,sys; print([(r["from"],r["len"],r["colour"]) for r in json.load(sys.stdin)][:3])')" \
   "[(0, 10, '#101018'), (10, 20, '#cf5636'), (30, 8, '#101018')]"
eq "$(python3 "$PX" runs "$img" col 55 --json | python3 -c 'import json,sys; print([r["len"] for r in json.load(sys.stdin)])')" "[10, 20, 10]"
case_ "px.py centre: the red box alone in its region is centred (0 0); off by one when the region shifts"
eq "$(python3 "$PX" centre "$img" --region 5,0,30,20 --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["dx"], d["dy"])')" "0.0 0.0"
eq "$(python3 "$PX" centre "$img" --region 4,0,30,20 --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["dx"])')" "1.0"
case_ "px.py hist and diff: the commonest colour; a picture against itself, against a changed one"
eq "$(python3 "$PX" hist "$img" --top 1 --json | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["colour"])')" "#101018"
eq "$(python3 "$PX" diff "$img" "$img" --json)" '{"differ": 0, "box": null}'
python3 -I -c "from PIL import Image; import sys; im=Image.open(sys.argv[1]); im.putpixel((70,30),(255,255,255)); im.save(sys.argv[2])" "$img" "$TMP/b.png"
eq "$(python3 "$PX" diff "$img" "$TMP/b.png" --json)" '{"differ": 1, "box": [70, 30, 1, 1]}'
case_ "px.py misuse: exit 2; an unreadable picture: exit 1"
rc 2 python3 "$PX" nothing "$img"
rc 2 python3 "$PX"
rc 1 python3 "$PX" hist "$TMP/none.png"
case_ "hl-dwl.sh and shot.sh: usage and refusals (no session started)"
rc 2 bash "$REPO/tools/hl-dwl.sh"
rc 2 bash "$REPO/tools/hl-dwl.sh" "$TMP/none.sh"
rc 2 bash "$REPO/tools/shot.sh" "bad name!"
done_
