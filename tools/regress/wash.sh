#!/usr/bin/env bash
# tools/regress/wash.sh — never again (bug 5, r27: "a black box appears briefly, then the wallpaper
# changes"; r27-19: the wash 1.2 s, the pointer changing with it): the one transition, drawn by dwl
# (kawa-wash cover|go|drop, dwl.patch: washcover), headless on the real GPU —
#   · "covered" answered within 100 ms; what changes under the cover is not seen (a new wallpaper,
#     the theme's signal to dwl) — the pointer's new theme waits too
#   · "go": the ink bleeds the old picture away over 1200 ms (±1 frame), every step a frame, the
#     cells whole 3 × 3 squares on the screen's grid, only the old, the new and the wet rim's ink;
#     the pointer's new theme loaded once, as the ink reaches it (between the go and the end)
#   · a cover never told to go bleeds by itself after 3 s; "drop" takes it away at once
#   · the wallpaper picker (Super+W, both themes): Enter closes it on its own page (its preview
#     never turns into the bare ground — the black box) and it dissolves out over the wash
#   bash tools/regress/wash.sh [KIT OPTION…]   (e.g. --bin bin before an apply)
# Exit 0 held · 1 broken (said) · 2 could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-wash.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
fail=0
no() { echo "wash: $*" >&2; fail=1; }
dwl=$HOME/.local/src/dwl/dwl
for a; do [[ ${prev:-} == --dwl ]] && dwl=$a; prev=$a; done
magick -size 1920x1080 xc:'#c03020' "$out/old.png" && magick -size 1920x1080 xc:'#2040c0' "$out/new.png" \
  || { echo "wash: no ImageMagick" >&2; exit 2; }

# ── the mechanics, on a bare dwl ──
cat >"$out/inside.sh" <<EOF
O=$out R=\$XDG_RUNTIME_DIR
ask() { mkfifo "\$R/a\$1"; exec 3<>"\$R/a\$1"; t0=\$(date +%s%N)
  echo "wash cover \$R/a\$1" 1<>\$R/dwl-warm; read -r -t 2 ans <&3; t1=\$(date +%s%N)
  echo "\$1 \$ans \$(( (t1 - t0) / 1000000 ))" >>\$O/answers; exec 3<&-; }
swaybg -i \$O/old.png -m fill >/dev/null 2>&1 & sb=\$!
sleep 0.6; wlrctl pointer move 960 540; sleep 0.2
ask 1
kill \$sb; swaybg -i \$O/new.png -m fill >/dev/null 2>&1 & sb=\$!
sleep 0.3
for p in \$(pgrep -x dwl); do tr '\\0' '\\n' </proc/\$p/environ 2>/dev/null | grep -qx "XDG_RUNTIME_DIR=\$R" && kill -USR1 \$p; done
sleep 0.2
grim \$O/covered.png
echo "go \$(cat /proc/uptime)" >>\$O/marks
echo "wash go" 1<>\$R/dwl-warm
sleep 0.55; grim \$O/mid.png
sleep 1.0; grim \$O/after.png
ask 2
sleep 4.6; grim \$O/self.png
ask 3
kill \$sb; swaybg -i \$O/old.png -m fill >/dev/null 2>&1 & sb=\$!
sleep 0.5
echo "wash drop" 1<>\$R/dwl-warm
sleep 0.2; grim \$O/dropped.png
EOF
bash "$here/../hl-dwl.sh" "$out/inside.sh" --dwl "$dwl" --keep "$out/k" --time 40 >/dev/null 2>&1 \
  || { echo "wash: the headless run failed: $(tail -n 3 "$out/k/script.log" 2>/dev/null)" >&2; exit 2; }
while read -r n ans ms; do
  [[ $ans == covered ]] || no "cover $n: no answer"
  ((ms < 100)) || no "cover $n answered after $ms ms (100 at most)"
done <"$out/answers"
[[ $(wc -l <"$out/answers") == 3 ]] || no "$(wc -l <"$out/answers") answers, not 3"
r=$(python3 -I - "$out" <<'EOF'
import sys, os
from PIL import Image
o = sys.argv[1]
def colours(name):
    im = Image.open(os.path.join(o, name)).convert("RGB")
    return im, set(c for _, c in im.getcolors(1 << 24))
OLD, NEW = (192, 48, 32), (32, 64, 192)
res = []
_, c = colours("covered.png"); res.append("covered=" + ("old" if c == {OLD} else "seen"))
im, c = colours("mid.png")
W, H = im.size; px = im.load(); mixed = 0
for cy in range(0, H, 3):
    for cx in range(0, W, 3):
        v = px[cx, cy]
        if any(px[x, y] != v for y in range(cy, min(cy + 3, H)) for x in range(cx, min(cx + 3, W))):
            mixed += 1
res.append("mid=%d,%d,%d,%d" % (OLD in c, NEW in c, len(c), mixed))
_, c = colours("after.png"); res.append("after=" + ("new" if c == {NEW} else "not"))
_, c = colours("self.png"); res.append("self=" + ("new" if c == {NEW} else "not"))
_, c = colours("dropped.png"); res.append("dropped=" + ("old" if c == {OLD} else "not"))
print(" ".join(res))
EOF
)
for kv in $r; do
  case $kv in
    covered=old|after=new|self=new|dropped=old) ;;
    covered=*) no "the change showed through the cover" ;;
    after=*) no "1.5 s after the go the new picture is not all there" ;;
    self=*) no "a cover never told to go did not bleed by itself (3 s, then 1.2)" ;;
    dropped=*) no "a dropped cover still shows the old picture" ;;
    mid=1,1,3,0) ;;
    mid=*) no "mid-wash: old, new, colours, mixed cells = ${kv#mid=} (want 1,1,3,0: both pictures and the rim, every cell whole)" ;;
  esac
done
# the frame log: the bleed's steps (the one after the go), the pointer's theme (C)
python3 -I - "$out/k/frames.log" <<'EOF' || fail=1
import sys
A = []; C = []
for l in open(sys.argv[1]):
    f = l.split()
    if f and f[0] == "A" and len(f) > 3 and f[3] == "w":
        A.append((int(f[1]), float(f[4]), f[5]))
    elif f and f[0] == "C":
        C.append(int(f[1]))
# the bleeds: runs of steps, each from its first to the one at 1.0
runs = []; cur = []
for t, p, _ in A:
    if cur and p <= cur[-1][1]:
        runs.append(cur); cur = []
    cur.append((t, p))
if cur: runs.append(cur)
bleeds = [r for r in runs if len(r) > 3]
bad = 0
if len(bleeds) != 2:
    print("wash: %d bleeds in the log, not 2 (the go, the cover left alone; a drop has none)" % len(bleeds), file=sys.stderr); bad = 1
if bleeds:
    b = bleeds[0]
    start = b[0][0]; end = b[-1][0]
    ms = (end - start) / 1000
    gaps = [(b[i + 1][0] - b[i][0]) / 1000 for i in range(len(b) - 1)]
    if b[-1][1] != 1.0 or not 1190 <= ms <= 1215:
        print("wash: the bleed took %.1f ms to %.4f, not 1200 to 1" % (ms, b[-1][1]), file=sys.stderr); bad = 1
    if max(gaps) > 4 * 6.95:
        print("wash: a gap of %.1f ms between the bleed's steps" % max(gaps), file=sys.stderr); bad = 1
    inside = [c for c in C if start - 7000 <= c <= end]
    if len(inside) != 1:
        print("wash: the pointer's theme loaded %d times during the bleed, not once" % len(inside), file=sys.stderr); bad = 1
    elif inside[0] >= start + 600 * 1000:
        print("wash: the pointer (at the middle, where the ink lands first) changed %.0f ms into the bleed" % ((inside[0] - start) / 1000), file=sys.stderr); bad = 1
    if [c for c in C if start - 1000 * 1000 < c < start - 7000]:
        print("wash: the pointer changed under the cover, before the go", file=sys.stderr); bad = 1
sys.exit(bad)
EOF

# ── the wallpaper picker (Super+W): closed on its own page, dissolving over the wash ──
cat >"$out/play.sh" <<PLAY
mkdir -p "\$HOME/Pictures/Wallpapers"
cp $out/old.png "\$HOME/Pictures/Wallpapers/a-old.png"; cp $out/new.png "\$HOME/Pictures/Wallpapers/b-new.png"
kawa-wallpaper --set "\$HOME/Pictures/Wallpapers/a-old.png" >/dev/null 2>&1; nap 1
chord logo w; nap 3; key Down; nap 0.8
shot open
wf-recorder -y -f $out/rec-\$KIT_THEME.mkv -c ffv1 >/dev/null 2>&1 & rec=\$!
nap 0.8; key Return; nap 2.5
kill -INT \$rec; wait \$rec
PLAY
for th in dark light; do
  sed "s/\\\$KIT_THEME/$th/" "$out/play.sh" >"$out/play-$th.sh"
  bash "$here/../kit.sh" --theme "$th" "$@" --out "$out/$th" --play "$out/play-$th.sh" play >"$out/kit-$th.log" 2>&1 \
    || { echo "wash: the kit failed ($th): $(tail -n 2 "$out/kit-$th.log")" >&2; exit 2; }
  mkdir -p "$out/fr-$th"
  ffmpeg -loglevel error -i "$out/rec-$th.mkv" -fps_mode passthrough "$out/fr-$th/%04d.png" \
    || { echo "wash: no recording ($th)" >&2; exit 2; }
  ground=$(sed -n 's/^C_GROUND=//p' "$HOME/.config/fedokawaii/themes/$th/colors.sh" 2>/dev/null)
  python3 -I - "$out/$th/open.png" "$out/fr-$th" "${ground:-181715}" "$th" <<'EOF' || fail=1
import sys, os
from PIL import Image
op = Image.open(sys.argv[1]).convert("RGB"); d = sys.argv[2]; th = sys.argv[4]
g = tuple(int(sys.argv[3][i:i + 2], 16) for i in (0, 2, 4))
W, H = op.size
# the picker's preview: the largest run of the new picture's blue in the open shot
B = (32, 64, 192)
blue = lambda c: c[0] < 60 and 45 < c[1] < 85 and c[2] > 170    # (a sixel's blue: near B)
pts = [(x, y) for y in range(0, H, 2) for x in range(0, W, 2) if blue(op.getpixel((x, y)))]
if not pts:
    print("wash (%s): no preview in the open picker" % th, file=sys.stderr); sys.exit(1)
x0, x1 = min(p[0] for p in pts) + 4, max(p[0] for p in pts) - 4
y0, y1 = min(p[1] for p in pts) + 4, max(p[1] for p in pts) - 4
bad = 0
for f in sorted(os.listdir(d)):
    im = Image.open(os.path.join(d, f)).convert("RGB")
    n = sum(1 for y in range(y0, y1, 3) for x in range(x0, x1, 3) if im.getpixel((x, y)) == g)
    if n > 20:
        print("wash (%s): frame %s shows the bare ground where the preview was (%d dots): the black box" % (th, f, n), file=sys.stderr)
        bad = 1; break
last = Image.open(os.path.join(d, sorted(os.listdir(d))[-1])).convert("RGB")
if last.getpixel(((x0 + x1) // 2, (y0 + y1) // 2)) != B:
    print("wash (%s): the new wallpaper is not up after the picker closed" % th, file=sys.stderr); bad = 1
sys.exit(bad)
EOF
done
exit "$fail"
