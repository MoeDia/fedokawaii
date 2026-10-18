#!/usr/bin/env bash
# tests/static/test_pointers.sh — the Sumi pointers as committed (tools/build-cursors.py →
# configs/system/usr/share/icons/Sumi-dark, Sumi-light), read the way a compositor reads them:
#   · every name a program may ask for is there, in both variants — the CSS / Wayland
#     cursor-shape names, X11's cursor font names and the hashes Qt and older toolkits use —
#     and nothing falls through to another theme (no Inherits)
#   · every other name is listed in art/cursor-names.txt with a pointer drawn in both variants
#     (theme.sh makes it a link beside it: the toolkit itself holds no links)
#   · every file is a real Xcursor file holding 24, 32 and 48 px, each a square of its size,
#     the same frames at every size; 48 is exactly the 24 px pictures with each pixel doubled
#   · each pixel fully opaque or clear
#   · only the palettes' ink, rim and wash — vermilion on the two "not here" seals alone
#   · each hotspot is on a drawn pixel, the symmetric shapes' their exact middle; busy's (the
#     ensō) the middle of the circle: as far from the stroke left, right and up
#   · the two variants are the same drawings: same names, hotspots and frames
# (That the files match art/cursors.txt is test_generated's: the generator run on a copy.)
. "$(dirname "$0")/../lib/harness.sh"
sandbox
ICONS=$REPO/configs/system/usr/share/icons
declare -A OTHER=()   # art/cursor-names.txt: OTHER[NAME]=the pointer it leads to
while read -r n p; do [[ -z $n || $n == \#* ]] || OTHER[$n]=$p; done <"$REPO/art/cursor-names.txt"

# the names programs ask by
NAMES=(
  # CSS cursors = the Wayland cursor-shape protocol's (v1 and v2)
  default context-menu help pointer progress wait cell crosshair text vertical-text alias copy
  move no-drop not-allowed grab grabbing e-resize n-resize ne-resize nw-resize s-resize se-resize
  sw-resize w-resize ew-resize ns-resize nesw-resize nwse-resize col-resize row-resize all-scroll
  zoom-in zoom-out dnd-ask all-resize
  # X11's cursor font and the old toolkits' names
  left_ptr arrow top_left_arrow left_arrow right_ptr X_cursor x-cursor hand1 hand2 hand pointing_hand
  xterm ibeam watch left_ptr_watch half-busy question_arrow whats_this left_ptr_help cross tcross
  cross_reverse diamond_cross plus fleur size_all crossed_circle forbidden circle openhand
  closedhand dnd-none dnd-no-drop dnd-copy dnd-link dnd-move link zoom_in zoom_out
  sb_h_double_arrow sb_v_double_arrow h_double_arrow v_double_arrow left_side right_side top_side
  bottom_side size_hor size_ver size_fdiag size_bdiag bd_double_arrow fd_double_arrow
  top_left_corner top_right_corner bottom_left_corner bottom_right_corner split_h split_v
  # the hashes (Qt, and toolkits before the names above)
  9d800788f1b08800ae810202380a0822 e29285e634086352946a0e7090d73106 00000000000000020006000e7e9ffc3f
  08e8e1c95fe2fc01f976f1e063a24ccd 3ecb610c1bf2410f44200f48c40d3599 d9ce0ab605698f320427677b458ad60b
  5c6cd98b3f3ebcb1f9c7f1c204630408 3085a0e285430894940527032f8b26df 640fb0e74195791501fd1ed57b41487f
  a2a266d0498c3104214a47bd64ab0fc8 1081e37283d90000800003c07f3ef6bf 6407b0e94181790501fd1e167b474872
  b66166c04f8c3109214a4fbd64a50fc8 4498f0e0c1937ffe01fd06f973665830 9081237383d90e509aa00f00170e968f
  5aca4d189052212118709018842178c0 9141b49c8149039304290b508d208c40 208530c400c041818281048008011002
  03b6e0fcb3499374a867c041f52298f0 028006030e0e7ebffc7f7070c0600140 00008160000006810000408080010102
  c7088f0f3e6c8088236ef8e1e3e70000 fcf1c3c7cd4491d801f1e1c78f100000 14fef782d02440884392942c11205230
  2870a09082c103050810ffdffffe0204
)

case_ "both variants: an index.theme each, under its own name, inheriting nothing"
for v in dark light; do
  t=$ICONS/Sumi-$v/index.theme
  has "$(cat "$t" 2>/dev/null)" "Name=Sumi-$v" "Sumi-$v/index.theme"
  lacks "$(cat "$t" 2>/dev/null)" "Inherits" "Sumi-$v falls through to another theme"
done

case_ "every name a program may ask for is there, in both variants"
for v in dark light; do
  for n in "${NAMES[@]}"; do [[ -s $ICONS/Sumi-$v/cursors/${OTHER[$n]:-$n} ]] && _ok || _no "Sumi-$v: no $n"; done
done

case_ "every other name leads to a pointer drawn in both variants, and is not drawn itself"
for n in "${!OTHER[@]}"; do
  p=${OTHER[$n]}
  [[ $p != */* && -f $ICONS/Sumi-dark/cursors/$p && -f $ICONS/Sumi-light/cursors/$p ]] && _ok || _no "$n → $p: not drawn"
  [[ ! -e $ICONS/Sumi-dark/cursors/$n ]] && _ok || _no "$n is drawn and named both"
done
eq "$(find "$ICONS" -type l | wc -l)" 0 "links in the toolkit (theme.sh makes them)"

case_ "the files, the pixels, the hotspots: read as a compositor reads them"
out=$(python3 -I - "$ICONS" "$REPO/tools/build-themes.py" <<'EOF'
import importlib.util, pathlib, struct, sys
icons, themes = pathlib.Path(sys.argv[1]), sys.argv[2]
spec = importlib.util.spec_from_file_location("themes", themes)
t = importlib.util.module_from_spec(spec); spec.loader.exec_module(t)
bad = []

def read(path):
    """An Xcursor file → {size: [(w, h, xhot, yhot, delay, pixels)]}, or a reason it is not one."""
    b = path.read_bytes()
    if b[:4] != b"Xcur":
        return "not an Xcursor file"
    hsize, version, ntoc = struct.unpack_from("<III", b, 4)
    if hsize != 16 or ntoc < 1:
        return f"a bad header ({hsize}, {ntoc} entries)"
    out = {}
    for i in range(ntoc):
        typ, sub, pos = struct.unpack_from("<III", b, 16 + 12 * i)
        if typ != 0xFFFD0002:
            return f"entry {i} is no image"
        head, ctyp, size, ver, w, h, xh, yh, delay = struct.unpack_from("<9I", b, pos)
        if (head, ctyp, size, ver) != (36, typ, sub, 1):
            return f"image {i}: its chunk header does not match the table"
        px = struct.unpack_from(f"<{w * h}I", b, pos + 36)
        out.setdefault(size, []).append((w, h, xh, yh, delay, px))
    return out

SYMMETRIC = {"text", "vertical-text", "crosshair", "cell", "move", "not-allowed", "ew-resize",
             "ns-resize", "nwse-resize", "nesw-resize", "col-resize", "row-resize"}
SEALS = {"not-allowed", "no-drop"}                           # vermilion: theirs alone
seen = {}
for v in ("dark", "light"):
    palette = {0xFF000000 | int(c, 16) for c in (t.P[v][k] for k in ("strong", "muted"))}
    palette.add(0xFF000000 | int(t.P[v]["ground" if v == "dark" else "hi"], 16))
    vermilion = 0xFF000000 | int(t.P[v]["accent"], 16)
    for f in sorted((icons / f"Sumi-{v}" / "cursors").iterdir()):
        if f.is_symlink():
            continue
        name, cur = f.name, read(f)
        if isinstance(cur, str):
            bad.append(f"Sumi-{v}/{name}: {cur}"); continue
        if sorted(cur) != [24, 32, 48]:
            bad.append(f"Sumi-{v}/{name}: sizes {sorted(cur)}, not 24 32 48"); continue
        if len({len(fr) for fr in cur.values()}) != 1:
            bad.append(f"Sumi-{v}/{name}: a different number of frames at each size")
        for size, frames in cur.items():
            for k, (w, h, xh, yh, delay, px) in enumerate(frames):
                where = f"Sumi-{v}/{name} {size} px, frame {k + 1}"
                if (w, h) != (size, size):
                    bad.append(f"{where}: {w}×{h}, not a {size} px square")
                if not (0 <= xh < w and 0 <= yh < h):
                    bad.append(f"{where}: hotspot {xh},{yh} outside the picture")
                    continue
                if len(frames) > 1 and delay == 0:
                    bad.append(f"{where}: animated, but no delay")
                stray = {p for p in px if p and p not in palette | ({vermilion} if name in SEALS else set())}
                if stray:
                    bad.append(f"{where}: colours not the palette's: {', '.join(f'{p:08x}' for p in sorted(stray)[:4])}")
                if name in SEALS and vermilion not in px:
                    bad.append(f"{where}: the seal is not vermilion")
                if name == "wait":                    # the middle of the circle (its gap is below)
                    def reach(dx, dy):
                        x, y, n = xh, yh, 0
                        while 0 <= x < w and 0 <= y < h and px[y * w + x] == 0:
                            x, y, n = x + dx, y + dy, n + 1
                        return n
                    half = 1 if size == 48 else 0         # (a doubled pixel: its middle is between two)
                    if not reach(-1, 0) == reach(1, 0) - half == reach(0, -1) > 1:
                        bad.append(f"{where}: the hotspot {xh},{yh} is not the circle's middle "
                                   f"(clear left {reach(-1, 0)}, right {reach(1, 0)}, up {reach(0, -1)})")
                    continue
                if px[yh * w + xh] == 0:
                    bad.append(f"{where}: the hotspot {xh},{yh} is on a clear pixel")
                if name in SYMMETRIC:
                    xs = [i % w for i, p in enumerate(px) if p]
                    ys = [i // w for i, p in enumerate(px) if p]
                    half = 1 if size == 48 else 0         # (a doubled pixel: its middle is between two)
                    if (min(xs) + max(xs), min(ys) + max(ys)) != (2 * xh + half, 2 * yh + half):
                        bad.append(f"{where}: the hotspot {xh},{yh} is not the middle of "
                                   f"{min(xs)}…{max(xs)} × {min(ys)}…{max(ys)}")
        for i, (a, b) in enumerate(zip(cur[24], cur[48])):       # 48: the 24 px pictures, doubled
            w = a[0]
            want = tuple(a[5][(y // 2) * w + x // 2] for y in range(2 * w) for x in range(2 * w))
            if b[5] != want or (b[2], b[3]) != (2 * a[2], 2 * a[3]) or b[4] != a[4]:
                bad.append(f"Sumi-{v}/{name}: 48 px frame {i + 1} is not the 24 px one doubled")
        shape = {s: [(fr[2], fr[3], fr[4], tuple(p != 0 for p in fr[5])) for fr in frames]
                 for s, frames in cur.items()}
        if name in seen and seen[name] != shape:
            bad.append(f"{name}: Sumi-dark and Sumi-light are not the same drawing")
        seen[name] = shape
print("\n".join(bad))
EOF
)
while IFS= read -r ln; do [[ -n $ln ]] && _no "$ln"; done <<<"$out"
eq "$out" ""

case_ "the busy pointers are animated (the ensō drawn), the rest still"
for v in dark light; do
  for n in wait progress; do
    c=$(python3 -I -c 'import struct,sys; b=open(sys.argv[1],"rb").read(); print(struct.unpack_from("<I",b,12)[0])' "$ICONS/Sumi-$v/cursors/$n")
    ((c > 3 * 4)) && _ok || _no "Sumi-$v/$n: $c images — not an animation"
  done
  c=$(python3 -I -c 'import struct,sys; b=open(sys.argv[1],"rb").read(); print(struct.unpack_from("<I",b,12)[0])' "$ICONS/Sumi-$v/cursors/default")
  eq "$c" 3 "Sumi-$v/default: three sizes, one picture each"
done

done_
