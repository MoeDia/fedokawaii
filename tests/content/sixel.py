#!/usr/bin/env python3
"""sixel.py < OUTPUT — reads a sixel picture as a terminal would and prints what it drew, as
JSON: {"p2", "raster": [pan, pad, w, h], "width", "height", "bbox": [x0, y0, x1, y1] of the
pixels drawn (exclusive end, null when none), "drawn", "colours": the drawn colours as
"r,g,b" percents, "ends_with_band_break", "before", "after": the bytes outside the picture}.
A malformed picture prints {"error": "..."} and exits 1."""
import json, re, sys

raw = sys.stdin.buffer.read().decode("latin1")
def text(s): return s.encode("latin1").decode("utf-8", "replace")   # (words around it: UTF-8)
m = re.search(r"\x1bP([0-9;]*)q", raw)
if not m:
    print(json.dumps({"error": "no sixel introducer", "before": raw[:80]})); sys.exit(1)
end = raw.find("\x1b\\", m.end())
if end < 0:
    print(json.dumps({"error": "no string terminator"})); sys.exit(1)
params = [int(p) if p else 0 for p in m[1].split(";")] if m[1] else []
p2 = params[1] if len(params) > 1 else 0
body = raw[m.end():end]
raster = None
regs, cur = {}, None
x = band = 0
width = 0
drawn = {}                                   # (x, y) -> colour register
tokens = re.finditer(r'"([0-9;]*)|#(\d+)(?:;(\d+);(\d+);(\d+);(\d+))?|!(\d+)([?-~])|([?-~])|(\$)|(-)|(\s)|(.)', body)
last = None
for t in tokens:
    if t[1] is not None:
        if raster is None and x == 0 and band == 0:
            raster = [int(v) for v in t[1].split(";") if v]
        last = "raster"; continue
    if t[2] is not None:
        cur = int(t[2])
        if t[3] is not None:
            if t[3] != "2":
                print(json.dumps({"error": "colour space %s" % t[3]})); sys.exit(1)
            regs[cur] = (int(t[4]), int(t[5]), int(t[6]))
        last = "colour"; continue
    rep, ch = (int(t[7]), t[8]) if t[7] is not None else (1, t[9]) if t[9] is not None else (0, None)
    if ch is not None:
        bits = ord(ch) - 63
        if bits:
            for dx in range(rep):
                for i in range(6):
                    if bits >> i & 1:
                        drawn[(x + dx, band * 6 + i)] = cur
        x += rep; width = max(width, x); last = "data"; continue
    if t[10]: x = 0; last = "cr"; continue
    if t[11]: x = 0; band += 1; last = "nl"; continue
    if t[12]: continue
    print(json.dumps({"error": "unexpected %r" % t[13]})); sys.exit(1)
height = (band + (0 if last == "nl" else 1)) * 6
bbox = None
if drawn:
    xs = [p[0] for p in drawn]; ys = [p[1] for p in drawn]
    bbox = [min(xs), min(ys), max(xs) + 1, max(ys) + 1]
colours = sorted({"%d,%d,%d" % regs[c] for c in set(drawn.values()) if c in regs})
print(json.dumps({"p2": p2, "raster": raster, "width": width, "height": height, "bbox": bbox,
                  "drawn": len(drawn), "colours": colours, "ends_with_band_break": last == "nl",
                  "before": text(raw[:m.start()]), "after": text(raw[end + 2:])}, ensure_ascii=False))
