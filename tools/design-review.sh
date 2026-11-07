#!/usr/bin/env bash
# tools/design-review.sh — the pack for the owner's design review on his remote page (CLAUDE.md DESIGN
# REVIEW, plan T19p): every surface drawn for real in both moods (tools/gallery.sh and the plays below in
# tools/kit.sh's headless dwl), one PNG a surface in .claude/review/current/ with its note beside it and
# questions.md; the pack before is moved to .claude/review/YYYY-MM-DD[-N]/. The words are in
# tools/design-review.txt (a surface a line) and tools/design-review-questions.md.
#   bash tools/design-review.sh [--fresh] [KIT OPTION…]
#     --fresh  every shot again; otherwise only what /dev/shm/r27/pack does not hold yet
#     KIT OPTION e.g. --bin bin --repo-art: the repository's state before an apply
# Exit 0 · 1 a surface has no shot (said) · 2 a kit could not run.
set -u
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/.." && pwd)
W=/dev/shm/r27/pack kit=()
while (($#)); do
  case $1 in
    --fresh) rm -rf "${W:?}"; shift ;;
    *) kit+=("$1"); shift ;;
  esac
done
mkdir -p "$W"
[[ -s $W/gallery/index.png ]] || bash "$here/gallery.sh" --out "$W/gallery" "${kit[@]}" || exit 2
# the wallpapers as the desktop shows them: the 640 × 360 art at ×3, whole pixels
python3 -I - "$repo/art/masters/out" "$W" <<'PY'
import sys
from PIL import Image
src, out = sys.argv[1:]
for mood, name in (("dark", "fudo-flames"), ("light", "feather-robe-tennin")):
    im = Image.open(f"{src}/{name}.png").convert("RGB")
    im.resize((im.width * 3, im.height * 3), Image.NEAREST).save(f"{out}/wall-{mood}.png")
PY
cat >"$W/desk.sh" <<'PLAY'
mood=$(basename "$(readlink "$HOME/.config/fedokawaii/current")")
for t in "the first line of a poem about ink" "rm -rf ~/tmp/old" "15% of 2400 = 360"; do printf '%s' "$t" | cliphist store; done
panel; warm; nap 1.5
swaybg -i "$PACK/wall-$mood.png" -m fill >/dev/null 2>&1 &
nap 1; shot wall
chord logo Return; nap 1.5; text 'fetch'; key Return; nap 2
chord logo Return; nap 1.5; text 'nvim ~/.bashrc'; key Return; nap 3
chord logo e; nap 3
shot desktop
setsid -f kawa-quick; nap 1.5; shot desktop-quick; key Escape; nap 1
PLAY
# (on the flat ground, so each page crops to its surface; the kit's empty home seeded with what a real day has)
cat >"$W/surf.sh" <<'PLAY'
mkdir -p "$KIT_OUT/stub" "$HOME/Books" "$HOME/.cache/fedokawaii" "$HOME/.local/share/fedokawaii"
# (his sound devices as PipeWire said them at the pack's making; no PipeWire in the kit)
printf '#!/bin/sh\ncat "%s/pw-dump.json"\n' "$PACK" >"$KIT_OUT/stub/pw-dump"
printf '#!/bin/sh\ncase "$2" in *SINK*) echo "Volume: 0.47";; *) echo "Volume: 0.80";; esac\n' >"$KIT_OUT/stub/wpctl"
chmod +x "$KIT_OUT/stub/"*
for b in "Logical Chess, Move by Move" "The Elements of Typographic Style" "Designing Design" "Hokusai: The Great Picture Book" "Grid Systems in Graphic Design" "Build Up Your Chess 1"; do cp "$PACK/book.pdf" "$HOME/Books/$b.pdf"; done
ln -s "$REAL/.local/share/fedokawaii/wallpapers" "$REAL/.local/share/fedokawaii/wallpapers.list" "$HOME/.local/share/fedokawaii/"
cp -a "$REAL/.cache/fedokawaii/wallpaper-previews" "$REAL/.cache/fedokawaii/wallpaper-screens" "$HOME/.cache/fedokawaii/"
d=$HOME/repos/demo; mkdir -p "$d"; cd "$d" && git init -q
for c in "first page" "the margin rule held" "scrolls without a jump"; do echo "$c" >>notes.md; git add notes.md; git -c user.name=dia -c user.email=dia@fedokawaii commit -qm "$c"; done
echo more >>notes.md; cd
export PATH="$KIT_OUT/stub:$PATH"
panel; warm; nap 1.5
setsid -f kawa-quick sound; nap 1.5; shot sound-real; key Escape; nap 1
chord logo u; nap 3; shot system-0
for n in 1 2 3 4; do key Tab; nap 1; shot "system-$n"; done
key Escape; nap 1
chord logo n; nap 3
text 'the first line of a poem about ink'; key Return
text 'the second one, on the rule, with the margin held'; key Return; nap 1
shot notes-typed
key Tab; nap 1.5
text 'buy sumi ink'; key Return; text 'answer the design review'; key Return; nap 1
shot todo
key Escape; chord logo n; nap 1
chord logo w; nap 4; shot wallpaper-real; key Escape; nap 1
chord logo r; nap 4; shot books-real; key Escape; nap 1
kawa-term --app kawa-git Git sh -c "cd '$d' && exec kawa-git" >/dev/null 2>&1 &
nap 3; shot git-real; chord logo q; nap 1
setsid -f kawa-calc
nap 1; text '5 ft to cm'; nap 1.5; shot calculator-real; key Escape; nap 1
chord logo Return; nap 1.5
text "cd '$d' && git log --oneline"; key Return; nap 1
text 'ls -a'; key Return; nap 1.5; shot terminal-real; chord logo q; nap 1
setsid -f zathura "$PACK/book.pdf" >/dev/null 2>&1; nap 3; shot pdf; chord logo q; nap 1
PLAY
cat >"$W/lock.sh" <<'PLAY'
mkdir -p "$HOME/.local/share/fedokawaii" "$HOME/.local/lib" "$KIT_OUT/stub"
ln -s "$REAL/.local/share/fedokawaii/dark" "$REAL/.local/share/fedokawaii/light" "$HOME/.local/share/fedokawaii/"
ln -s "$REAL/.local/lib/fedokawaii" "$HOME/.local/lib/fedokawaii"
printf '#!/bin/sh\nexit 0\n' >"$KIT_OUT/stub/logger"; chmod +x "$KIT_OUT/stub/logger"
PATH="$KIT_OUT/stub:$PATH" KAWA_LOCK_SLEEP=0 kawa-saver --idle >"$KIT_OUT/saver.log" 2>&1 &
nap 3; shot saver
key space; nap 1.2; shot lock
text "ab"; nap 0.3; shot lock-typed
PLAY
magick -size 595x842 xc:white "$W/book.pdf"
sed -i "1i PACK=$W" "$W/desk.sh"
sed -i "1i PACK=$W REAL=$HOME" "$W/surf.sh"
sed -i "1i REAL=$HOME" "$W/lock.sh"
# his session, read only: the bar as it is now (the kit has no services: no sound, weather …), its devices
b=$(pgrep -x waybar | sed -n 1p)
if [[ -n $b && ! -s $W/live-bar.png ]]; then
  (
    while IFS= read -r -d '' kv; do
      case $kv in WAYLAND_DISPLAY=* | XDG_RUNTIME_DIR=*) export "${kv?}" ;; esac
    done </proc/"$b"/environ
    grim -g "0,0 1920x28" "$W/live-bar.png"
    pw-dump | jq '[.[] | select(.type == "PipeWire:Interface:Device" or (.type == "PipeWire:Interface:Metadata" and .props["metadata.name"] == "default")
      or (.type == "PipeWire:Interface:Node" and ((.info.props["media.class"] // "") | test("^Audio/(Sink|Source)$"))))]' >"$W/pw-dump.json"
  )
fi
for mood in dark light; do
  [[ -s $W/$mood/desktop.png ]] || bash "$here/kit.sh" --theme "$mood" --time 300 "${kit[@]}" --out "$W/$mood" --play "$W/desk.sh" play >"$W/desk-$mood.log" 2>&1 \
    || { echo "design-review: the desk play failed ($mood): $(tail -n 2 "$W/desk-$mood.log")" >&2; exit 2; }
  [[ -s $W/$mood/sound-real.png ]] || bash "$here/kit.sh" --theme "$mood" --time 300 "${kit[@]}" --out "$W/$mood" --play "$W/surf.sh" play >"$W/surf-$mood.log" 2>&1 \
    || { echo "design-review: the surfaces' play failed ($mood): $(tail -n 2 "$W/surf-$mood.log")" >&2; exit 2; }
  [[ -s $W/$mood/lock.png ]] || bash "$here/kit.sh" --theme "$mood" --time 120 "${kit[@]}" --out "$W/$mood" --play "$W/lock.sh" play >"$W/lock-$mood.log" 2>&1 \
    || { echo "design-review: the lock play failed ($mood): $(tail -n 2 "$W/lock-$mood.log")" >&2; exit 2; }
done
# the old pack aside, once
review=$repo/.claude/review cur=$review/current
if [[ -d $cur ]] && [[ -n $(ls -A "$cur") ]]; then
  old=$review/$(date +%F) n=1
  while [[ -e $old ]]; do n=$((n + 1)); old=$review/$(date +%F)-$n; done
  mv "$cur" "$old"
fi
mkdir -p "$cur"
python3 -I - "$W" "$cur" "$here/design-review.txt" "$repo/art/masters" <<'PY' || exit 1
"""Each line of design-review.txt: NAME | SHOT | HOW | NOTE. HOW: ink (cropped to what the surface drew,
dark and light side by side while they fit the page's 1040 px, else one above the other) · bar (the top rows in
three strips, the middle group whole, each mood and the live session's: readable at 1×) · full (the whole screen, one above the other)
· masters MOOD (the mood's pictures as a sheet)."""
import glob, os, re, sys
from PIL import Image, ImageChops
W, cur, words, masters = sys.argv[1:]
GUTTER, CARD, FIT = 16, (88, 84, 78), 1020
def shot(name, mood):
    for p in (f"{W}/{mood}/{name}.png", f"{W}/gallery/{mood}/{name}.png"):
        if os.path.exists(p):
            return Image.open(p).convert("RGB")
    return None
def ink(im):
    W_, H = im.size
    g = im.getpixel((5, H - 5))
    d = ImageChops.difference(im.crop((0, 40, W_, H)), Image.new("RGB", (W_, H - 40), g)).getbbox()
    return im.crop((max(0, d[0] - 14), max(0, d[1] + 40 - 14), min(W_, d[2] + 14), min(H, d[3] + 40 + 14))) if d else im.crop((0, 0, W_, 40))
def sheet(ims, across):
    if across:
        w = sum(i.width for i in ims) + GUTTER * (len(ims) - 1); h = max(i.height for i in ims)
    else:
        w = max(i.width for i in ims); h = sum(i.height for i in ims) + GUTTER * (len(ims) - 1)
    out = Image.new("RGB", (w, h), CARD); x = y = 0
    for i in ims:
        out.paste(i, (x, y))
        if across: x += i.width + GUTTER
        else: y += i.height + GUTTER
    return out
n = 0; missing = []
for line in open(words, encoding="utf-8"):
    line = line.rstrip("\n")
    if not line or line.startswith("#"):
        continue
    name, src, how, note = (p.strip() for p in line.split("|", 3))
    n += 1
    if how.startswith("masters"):
        mood = how.split()[1]; names = []; block = {}
        for t in re.split(r"(?m)^\[", open(f"{masters}/masters.toml", encoding="utf-8").read())[1:]:
            k = t.split("]", 1)[0]
            if re.search(r'(?m)^theme\s*=\s*"%s"' % mood, t):
                names.append(k)
        ims = [Image.open(f"{masters}/out/{k}.png").convert("RGB") for k in names]
        cols = 3; rows = (len(ims) + cols - 1) // cols
        page = Image.new("RGB", (cols * 640 + (cols - 1) * GUTTER, rows * 360 + (rows - 1) * GUTTER), CARD)
        for i, im in enumerate(ims):
            page.paste(im, ((i % cols) * (640 + GUTTER), (i // cols) * (360 + GUTTER)))
    else:
        dark, light = shot(src, "dark"), shot(src, "light")
        if dark is None or light is None:
            missing.append(f"{name}: no shot {src}")
            continue
        if how == "ink":
            d, l = ink(dark), ink(light)
            page = sheet([d, l], d.width + l.width + GUTTER <= FIT)
        elif how == "bar":
            H = 28
            live = f"{W}/live-bar.png"
            bars = [dark, light] + ([Image.open(live).convert("RGB")] if os.path.exists(live) else [])
            page = sheet([m.crop((x, 0, x + 640, H)) for m in bars for x in (0, 640, 1280)], False)
        else:
            page = sheet([dark, light], False)
    base = f"{n:02d}-{name}"
    page.save(f"{cur}/{base}.png", optimize=True)
    with open(f"{cur}/{base}.md", "w", encoding="utf-8") as f:
        f.write(note + "\n")
for m in missing:
    print("design-review:", m, file=sys.stderr)
print(f"design-review: {n - len(missing)} pages → {cur}")
sys.exit(1 if missing else 0)
PY
cp "$here/design-review-questions.md" "$cur/questions.md"
# the motion (a kit recording each, the slowest part: only with --fresh or when none is there), the lanes' pages
[[ -s $W/motion/00-windows.webp ]] || bash "$here/motion-review.sh" "$W/motion" 00 "${kit[@]}" || exit 2
for m in windows workspaces menus; do cp "$W/motion/00-$m.webp" "$cur/00-motion-$m.webp"; done
cat >"$cur/00-motion-windows.md" <<'EOF'
Motion. Real speed, then a third of it. A window rises from 120 px below its place on a spring, growing, and settles; closing, it sinks away, fading. Windows making room flow to their places.
EOF
cat >"$cur/00-motion-workspaces.md" <<'EOF'
Motion. Real speed, then a third of it. Both workspaces flow on one strip, the lacquer rail between them, a wave through the windows: left to a higher workspace, right to a lower one.
EOF
cat >"$cur/00-motion-menus.md" <<'EOF'
Motion. Real speed, then a third of it. Every menu and popup unrolls behind a scroll's rod, as Super+U and Super+N do, and rolls up closing.
EOF
bash "$here/review-gather.sh"
