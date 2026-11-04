#!/usr/bin/env bash
# tools/panel-review.sh — the menus and panels rendered for a design review: each surface with a machine's real
# state (a stand-in kawa-quick says what a live PC says: the kit has no sound, no Bluetooth), in both moods, through the
# real desktop (tools/kit.sh: a headless dwl, the repository's bin and art), cropped to the surface, at 1× and 4×.
#   bash tools/panel-review.sh [--out DIR] [--only NAME,NAME…] [--themes "dark light"] [--mako BIN]
#     --mako BIN   the notices by this mako (a build of src/mako/mako.patch not yet installed)
#   Out (default .claude/review/next): NAME-1x.png NAME-4x.png, dark over light, on the moods' own grounds; and
#   DIR/raw/THEME/NAME.png, the whole screens tools/px.py measures.
set -u
here=$(cd "$(dirname "$0")" && pwd); repo=$(cd "$here/.." && pwd)
out=$repo/.claude/review/next only="" themes="dark light" mako=""
while (($#)); do
  case $1 in
    --out) out=${2:?}; shift 2 ;;
    --only) only=${2:?}; shift 2 ;;
    --themes) themes=${2:?}; shift 2 ;;
    --mako) mako=$(realpath "${2:?}"); shift 2 ;;
    *) echo "panel-review: unknown $1" >&2; exit 2 ;;
  esac
done
export PATH=$HOME/.local/bin:$PATH
mkdir -p "$out/raw"
W=$(mktemp -d /tmp/panel-review.XXXXXX); [[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$W"' EXIT; [[ ${KEEP:-} == 1 ]] && echo "panel-review: kept $W"
mkdir "$W/bin"
for f in "$repo"/bin/*; do ln -s "$f" "$W/bin/"; done
[[ -n $mako ]] && ln -s "$mako" "$W/bin/mako"
ln -s "$repo/system/fedokawaii" "$W/bin/fedokawaii"
# (nothing the shots press may reach the machine: the power dialog's second press stands in here; the PC is shared)
for c in systemctl loginctl reboot poweroff shutdown; do printf '#!/bin/sh\nexit 0\n' >"$W/bin/$c"; chmod +x "$W/bin/$c"; done
rm "$W/bin/kawa-quick"
cat >"$W/bin/kawa-quick" <<STUB
#!/usr/bin/env bash
# the kit's machine: what a live PC answers
if [[ \${1:-} == --state ]]; then
  th=dark; [[ \$(readlink "\$HOME/.config/fedokawaii/current") == */light ]] && th=light
  [[ -f \$XDG_RUNTIME_DIR/rv-muted ]] && m=on || m=off
  case \${2:-} in
    sound) printf 'sound\t62%%\nmuted\t%s\nmic\ton\n' "\$m"
           printf 'output\t51\t1\tLG\tHDMI / DisplayPort\tLG ULTRAGEAR\tNavi 48 HDMI/DP Audio Controller\tDigital Stereo (HDMI)\t\n'
           printf 'output\t52\t0\tRyzen HD Audio Controller Analog Stereo\tLine Out\tALC1220 Analog\tRyzen HD Audio Controller\tAnalog Stereo\t\n'
           printf 'output\t53\t0\tWH-1000XM4\t\tWH-1000XM4\t\t\tbluez5\n'
           printf 'input\t61\t1\tYeti\t\tYeti Stereo Microphone\tYeti Stereo Microphone\tAnalog Stereo\t\n'
           printf 'input\t62\t0\tRyzen\tRear Microphone\tALC1220 Analog\tRyzen HD Audio Controller\tAnalog Stereo\t\n' ;;
    brightness) printf 'brightness\t72%%\n' ;;
    *) printf 'theme\t%s\nbrightness\t72%%\nnight\t4000K\nvrr\tin games\nvrrnow\toff\nwallpaper\tthe-great-wave\nsound\t62%%\nmuted\t%s\n' "\$th" "\$m"
       printf 'nettype\tethernet\nnetwork\twired\nbluetooth\ton\ndevices\tWH-1000XM4\ndrives\t1 drive\nbackup\t3 days ago\ndnd\toff\nsaver\t15 min\nuptime\tup 03h 07m\nrecord\toff\nrgb\ton\nsharesound\toff\n' ;;
  esac
  exit 0
fi
[[ \${1:-} == --do ]] && exit 0
exec "$repo/bin/kawa-quick" "\$@"
STUB
chmod +x "$W/bin/kawa-quick"
# NAME|WHAT OPENS IT|KEYS ONCE OPEN|WHAT CLOSES IT
SURFACES=(
  "quick|setsid -f kawa-quick|:|key Escape"
  "quick-cursor|setsid -f kawa-quick|key Down Down Down Down|key Escape"
  "quick-meter|setsid -f kawa-quick|key Down|key Escape"
  "power|setsid -f kawa-power|:|key Escape"
  "power-shut|setsid -f kawa-power|key Right Right Right Right|key Escape"
  "power-ask|setsid -f kawa-power|key Right Right Right Right Return|key Escape"
  "calendar|setsid -f kawa-calendar|:|key Escape"
  "timer|setsid -f kawa-timer|:|key Escape"
  "timer-run|kawa-timer start 25; nap 0.3; setsid -f kawa-timer|:|key Escape; kawa-timer cancel"
  "sound|setsid -f kawa-quick sound|:|key Escape"
  "sound-cursor|setsid -f kawa-quick sound|key Down|key Escape"
  "brightness|setsid -f kawa-quick brightness|:|key Escape"
  "downloads|setsid -f kawa-downloads|:|key Escape"
  "help|chord logo slash|:|key Escape"
  "help-find|chord logo slash|text 'lock'|key Escape"
  "launcher|chord logo space|:|key Escape"
  "launcher-sum|chord logo space|text '15% of 2400'; nap 0.9|key Escape"
  "dialog-keys|rv_dialog|key Right|key Escape"
  "password|rv_password|text 'abc'|key Escape"
  "downloads-busy|rv_downloads|:|key Escape; rv_downloads_end"
  "dnd|setsid -f kawa-quick dnd|:|key Escape"
  "drives|setsid -f kawa-drives|:|key Escape"
  "weather|setsid -f kawa-weather|:|key Escape"
  "notice-critical|notify-send -a desktop -u critical -- \"\$ICON_DRIVE  backup\" 'the drive is full — nothing was backed up'|:|makoctl dismiss -a"
  "system|chord logo u|:|key Escape"
  "system-1|chord logo u; nap 2; key Tab|:|key Escape"
  "system-2|chord logo u; nap 2; key Tab Tab|:|key Escape"
  "system-3|chord logo u; nap 2; key Tab Tab Tab|:|key Escape"
  "system-4|chord logo u; nap 2; key Tab Tab Tab Tab|:|key Escape"
)
{
  echo '. "$HOME/.config/fedokawaii/icons.sh"'
  cat <<'WORDS'
rv_dialog() { printf 'note\tthe disk is nearly full: go on?\nkey\t\tgo on\nkey\t\tnot now\n' | kawa-menu >/dev/null & }
rv_password() { kawa-menu --prompt "" --password --title "report.pdf · password" </dev/null >/dev/null & }
rv_downloads() {
  mkdir -p "$XDG_RUNTIME_DIR/kawa-downloads"; sleep 40 & RV_SLEEP=$!
  printf 'ubuntu-26.04-desktop-amd64.iso\t2147483648\t5368709120\t/tmp/x\nDune Part Two 2160p.mkv\t10737418240\t21474836480\t/tmp/y\n' >"$XDG_RUNTIME_DIR/kawa-downloads/torrra.$RV_SLEEP"
  setsid -f kawa-downloads
}
rv_downloads_end() { kill "$RV_SLEEP" 2>/dev/null; rm -f "$XDG_RUNTIME_DIR"/kawa-downloads/torrra.*; }
# (a loaded PC draws a surface late, a list half-way: the shot waits for the screen to change from before it opened and
# to hold still, two grabs 0.3 s apart alike, 12 s at most)
rv_grab() { grim -t ppm - | md5sum; }
rv_still() {
  local before=$1 a="" b i
  for ((i = 0; i < 40; i++)); do
    b=$(rv_grab); [[ $b != "$before" && $b == "$a" ]] && return 0
    a=$b; sleep 0.3
  done
}
WORDS
  echo 'panel; ready; warm; nap 1.5'
  for s in "${SURFACES[@]}"; do
    IFS='|' read -r name open keys close <<<"$s"
    [[ -z $only || ,$only, == *",$name,"* ]] || continue
    printf 'RV_BEFORE=$(rv_grab)\n%s\nnap 0.9\n%s\nnap 0.5\nrv_still "$RV_BEFORE"\nshot %s\n%s\nnap 0.8\n' "$open" "$keys" "$name" "$close"
  done
} >"$W/play.sh"
# (the kit's ground is swaybg's; now and then, seen under load only, its picture goes and dwl's dark root shows — swaybg
# alive: said to main. A shot whose ground is not the mood's is no review: the run again, three at most)
bad_ground() {   # bad_ground THEME → the shots whose ground is not the mood's (a dialog's: dimmed, so only the undimmed)
  python3 -I - "$out/raw/$1" "$repo/configs/home/.config/fedokawaii/themes/$1/colors.sh" "$only" <<'CHECK'
import os, re, sys
from PIL import Image
g = re.search(r'C_GROUND="?([0-9a-f]{6})', open(sys.argv[2]).read()).group(1)
want = tuple(int(g[i:i + 2], 16) for i in (0, 2, 4))
only = sys.argv[3].split(",") if sys.argv[3] else None
for f in sorted(os.listdir(sys.argv[1])):
    if f.endswith(".png") and not f.startswith("power") and (not only or f[:-4] in only):
        px = Image.open(os.path.join(sys.argv[1], f)).convert("RGB").getpixel((3, 1076))
        if px != want:
            print(f[:-4])
CHECK
}
for th in $themes; do
  for try in 1 2 3; do
    nice -n 10 bash "$here/kit.sh" --theme "$th" --time 400 --dwl /usr/local/bin/dwl --bin "$W/bin" --repo-art \
      --out "$out/raw/$th" --play "$W/play.sh" play >"$W/kit-$th.log" 2>&1 \
      || { echo "panel-review: the kit failed ($th): $(tail -n 3 "$W/kit-$th.log")" >&2; exit 1; }
    [[ -z $(bad_ground "$th") ]] && break
    echo "panel-review: the ground went ($th, try $try): $(bad_ground "$th" | tr '\n' ' ')"
  done
done
python3 -I - "$out" "$themes" <<'CROP'
import os, sys
from collections import Counter
from PIL import Image, ImageChops
out, themes = sys.argv[1], sys.argv[2].split()
names = sorted({f[:-4] for th in themes for f in os.listdir(f"{out}/raw/{th}") if f.endswith(".png")})
for n in names:
    crops = []
    for th in themes:
        p = f"{out}/raw/{th}/{n}.png"
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGB")
        W, H = im.size
        g = Counter(im.crop((0, 40, W, H)).getdata()).most_common(1)[0][0]
        d = ImageChops.difference(im.crop((0, 30, W, H)), Image.new("RGB", (W, H - 30), g)).getbbox()
        box = (0, 0, W, 40) if not d else (max(0, d[0] - 16), max(0, d[1] + 30 - 16), min(W, d[2] + 16), min(H, d[3] + 30 + 16))
        crops.append(im.crop(box))
    if not crops:
        continue
    w, h = max(c.width for c in crops), sum(c.height for c in crops) + 8 * (len(crops) - 1)
    sheet = Image.new("RGB", (w, h), (90, 90, 90))
    y = 0
    for c in crops:
        sheet.paste(c, (0, y)); y += c.height + 8
    sheet.save(f"{out}/{n}-1x.png")
    sheet.resize((w * 4, h * 4), Image.NEAREST).save(f"{out}/{n}-4x.png")
print(f"panel-review: {len(names)} surfaces → {out}")
CROP
