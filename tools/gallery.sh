#!/usr/bin/env bash
# tools/gallery.sh — every surface of the desktop shot in both themes, for the side-by-side
# audit (docs/design-system.md: one grammar): a headless dwl on the real GPU (tools/kit.sh), each
# surface opened as a person opens it (its key or its bar command), shot, closed; then for each
# a contact sheet — dark | light, cropped to what the surface drew, at 1× — and one index sheet.
#   bash tools/gallery.sh [--only NAME,NAME…] [--out DIR] [--record|--check] [KIT OPTION…]
#     (KIT OPTION e.g. --bin bin --repo-art: the repository's state before an apply)
#     --record  each surface's box (its frame and shadow, to the pixel) written to
#               tools/regress/gallery-expect.json — the reference a later build is held to
#     --check   never again: every surface the same box in dark and light (one grammar: a theme
#               is inks, never geometry) and the box the reference has (the calendar's height
#               and the power menu's width follow the month and the uptime: their place only)
# Out (default /dev/shm/r27/gallery): THEME/NAME.png (whole screens), NAME.png (dark | light),
# index.png (every sheet, a row each, halved), boxes.json. Exit 0 · 1 --check found a change
# (said) · 2 the kit could not run.
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=/dev/shm/r27/gallery only="" kit=() mode=""
while (($#)); do
  case $1 in
    --out) out=${2:?}; shift 2 ;;
    --only) only=${2:?}; shift 2 ;;
    --record|--check) mode=${1#--}; shift ;;
    *) kit+=("$1"); shift ;;
  esac
done
mkdir -p "$out"
# NAME|HOW IT OPENS (a play line)|HOW IT CLOSES|SECONDS TO DRAW — in the order a day meets them
SURFACES=(
  "bar|:|:|0.5"
  "launcher|chord logo space|key Escape|1.2"
  "launcher-sum|chord logo space; text '15% of 2400'|key Escape|1.5"
  "quick|setsid -f kawa-quick|key Escape|1.5"
  "sound|setsid -f kawa-quick sound|key Escape|1.5"
  "brightness|setsid -f kawa-quick brightness|key Escape|1.5"
  "dnd|setsid -f kawa-quick dnd|key Escape|1.2"
  "calendar|setsid -f kawa-calendar|key Escape|1.5"
  "timer|setsid -f kawa-timer|key Escape|1.5"
  "drives|setsid -f kawa-drives|key Escape|1.5"
  "downloads|setsid -f kawa-downloads|key Escape|1.5"
  "power|setsid -f kawa-power|key Escape|1.5"
  "help|chord logo slash|key Escape|1.5"
  "level|kawa-osd \"\$ICON_VOL_2\" volume 47|:|0.4"
  "notice|notify-send -a desktop -- \"\$ICON_PICTURE  wallpaper\" 'a new one every four hours: on'|:|0.8"
  "notice-critical|notify-send -a desktop -u critical -- \"\$ICON_DRIVE  backup\" 'the drive is full — nothing was backed up'|makoctl dismiss -a|0.8"
  "system|chord logo u|key Escape|2.5"
  "clipboard|chord logo v|key Escape|2.5"
  "wallpaper|chord logo w|key Escape|3"
  "books|chord logo r|key Escape|3"
  "files|setsid -f kawa-file --choose|key Escape|2.5"
  "calculator|kawa-term --app kawa-calc Calculator kawa-calc >/dev/null 2>&1 & nap 2; text '5 ft to cm'|chord logo q|1.5"
  "git|kawa-term --app kawa-git Git kawa-git >/dev/null 2>&1 &|chord logo q|2.5"
  "terminal|chord logo Return|chord logo q|1.5"
  "yazi|chord logo e|chord logo q|2.5"
  "btop|setsid -f kawa-term --float --once btop btop 140x41 -- btop|chord logo q|3"
  "notes|chord logo n|chord logo n|3"
)
cat >"$out/play.sh" <<'PLAY'
. "$HOME/.config/fedokawaii/icons.sh"
for t in "the first line of a poem about ink" "rm -rf ~/tmp/old" "15% of 2400 = 360"; do printf '%s' "$t" | cliphist store; done
mkdir -p "$HOME/repos/demo" && git -C "$HOME/repos/demo" init -q 2>/dev/null
panel; warm; nap 1.5
PLAY
for s in "${SURFACES[@]}"; do
  IFS='|' read -r name open close wait <<<"$s"
  [[ -z $only || ,$only, == *",$name,"* ]] || continue
  printf '%s\nnap %s\nshot %s\n%s\nnap 0.8\n' "$open" "$wait" "$name" "$close" >>"$out/play.sh"
done
for th in dark light; do
  bash "$here/kit.sh" --theme "$th" --time 600 "${kit[@]}" --out "$out/$th" --play "$out/play.sh" play >"$out/kit-$th.log" 2>&1 \
    || { echo "gallery: the kit failed ($th): $(tail -n 2 "$out/kit-$th.log")" >&2; exit 2; }
done
# the sheets: each surface cropped to its ink (what differs from the ground, the bar left out
# but for the bar's own), dark | light on a mid-grey card, labelled; the index halved
python3 -I - "$out" <<'EOF'
import os, sys
from PIL import Image, ImageChops, ImageDraw
out = sys.argv[1]
names = [f[:-4] for f in sorted(os.listdir(os.path.join(out, "dark"))) if f.endswith(".png")]
order = [l.split("shot ", 1)[1].strip() for l in open(os.path.join(out, "play.sh")) if l.startswith("shot ")]
names = [n for n in order if n in names]
sheets = []
for n in names:
    crops = []
    for th in ("dark", "light"):
        p = os.path.join(out, th, n + ".png")
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGB")
        W, H = im.size
        if n == "bar":
            box = (0, 0, W, 40)
        else:
            g = im.getpixel((5, H - 5))
            d = ImageChops.difference(im.crop((0, 40, W, H)), Image.new("RGB", (W, H - 40), g)).getbbox()
            box = (max(0, d[0] - 12), max(0, d[1] + 40 - 12), min(W, d[2] + 12), min(H, d[3] + 40 + 12)) if d else (0, 0, W, 40)
        crops.append(im.crop(box))
    if not crops:
        continue
    w = sum(c.width for c in crops) + 12 * (len(crops) + 1); h = max(c.height for c in crops) + 36
    sheet = Image.new("RGB", (w, h), (90, 90, 90)); dr = ImageDraw.Draw(sheet)
    dr.text((12, 6), n, fill=(235, 235, 235))
    x = 12
    for c in crops:
        sheet.paste(c, (x, 24)); x += c.width + 12
    sheet.save(os.path.join(out, n + ".png")); sheets.append(sheet)
if sheets:
    W = max(s.width for s in sheets) // 2; H = sum(s.height // 2 + 6 for s in sheets)
    idx = Image.new("RGB", (W, H), (60, 60, 60)); y = 0
    for s in sheets:
        t = s.resize((s.width // 2, s.height // 2)); idx.paste(t, (0, y)); y += t.height + 6
    idx.save(os.path.join(out, "index.png"))
print(f"gallery: {len(sheets)} surfaces → {out}")
EOF
# each surface's box: what differs from the ground below the bar's rows (the bar: its own rows)
python3 -I - "$out" <<'EOF' || exit 2
import json, os, sys
from PIL import Image, ImageChops
out = sys.argv[1]; boxes = {}
for th in ("dark", "light"):
    for f in sorted(os.listdir(os.path.join(out, th))):
        if not f.endswith(".png"):
            continue
        im = Image.open(os.path.join(out, th, f)).convert("RGB"); W, H = im.size; g = im.getpixel((2, 1))
        top = 0 if f == "bar.png" else 28
        bot = 28 if f == "bar.png" else H
        d = ImageChops.difference(im.crop((0, top, W, bot)), Image.new("RGB", (W, bot - top), g)).getbbox()
        boxes.setdefault(f[:-4], {})[th] = [d[0], d[1] + top, d[2], d[3] + top] if d else None
json.dump(boxes, open(os.path.join(out, "boxes.json"), "w"), indent=1, sort_keys=True)
EOF
ref=$here/regress/gallery-expect.json
case $mode in
  record)
    python3 -I -c 'import json, sys
b = json.load(open(sys.argv[1]))
json.dump({n: v["dark"] for n, v in sorted(b.items()) if v.get("dark") == v.get("light")}, open(sys.argv[2], "w"), indent=1)
print(f"gallery: {len(b)} boxes → {sys.argv[2]}")' "$out/boxes.json" "$ref" ;;
  check)
    python3 -I - "$out/boxes.json" "$ref" <<'EOF' || exit 1
import json, sys
b = json.load(open(sys.argv[1])); ref = json.load(open(sys.argv[2])); bad = []
PLACE_ONLY = {"calendar": "x", "power": "y"}       # (the month's rows, the uptime's figures)
for n, v in sorted(b.items()):
    if v.get("dark") != v.get("light"):
        bad.append(f"{n}: dark {v.get('dark')} ≠ light {v.get('light')}")
    want, got = ref.get(n), v.get("dark")
    if want is None or got is None:
        if want != got:
            bad.append(f"{n}: {'no reference' if want is None else 'not drawn'}")
    elif n in PLACE_ONLY:
        mid = lambda a, i: a[i] + a[i + 2]
        if PLACE_ONLY[n] == "x" and (mid(got, 0) != mid(want, 0) or got[1] != want[1]):
            bad.append(f"{n}: centred on {mid(got, 0) / 2}, top {got[1]} — the reference {mid(want, 0) / 2}, {want[1]}")
        if PLACE_ONLY[n] == "y" and (mid(got, 1) != mid(want, 1) or mid(got, 0) != mid(want, 0)):
            bad.append(f"{n}: its middle {mid(got, 0) / 2}, {mid(got, 1) / 2} — the reference {mid(want, 0) / 2}, {mid(want, 1) / 2}")
    elif got != want:
        bad.append(f"{n}: {got} — the reference {want}")
for m in sorted(set(ref) - set(b)):
    bad.append(f"{m}: not shot")
print("\n".join("gallery: " + x for x in bad) if bad else f"gallery: held — {len(b)} surfaces, each the same in both themes and as the reference")
sys.exit(1 if bad else 0)
EOF
    ;;
esac
