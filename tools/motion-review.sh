#!/usr/bin/env bash
# tools/motion-review.sh — dwl's motion for the owner's design review (his page plays an animated WebP): a
# kit run recorded (wf-recorder, frames by their own times), each event at real speed then at a third of it.
# A recording's pace is only for looking: timing is judged from dwl's frame log (tools/anim-check.sh).
#   bash tools/motion-review.sh OUTDIR PREFIX [KIT OPTION…]   → OUTDIR/PREFIX-{windows,workspaces,menus}.webp
# Exit 0 · 2 the kit could not run.
set -u
here=$(cd "$(dirname "$0")" && pwd)
outdir=${1:?}; prefix=${2:?}; shift 2
W=$(mktemp -d /dev/shm/motion-review.XXXXXX)
trap 'rm -rf "$W"' EXIT
mkdir -p "$outdir"
for scene in windows:dark workspaces:dark menus:light; do
  name=${scene%:*} mood=${scene#*:}
  {
    printf 'REC=%s/%s.mkv\n' "$W" "$name"
    cat <<'PLAY'
for t in "the first line of a poem about ink" "15% of 2400 = 360"; do printf '%s' "$t" | cliphist store; done
panel; warm; nap 1.5
PLAY
    printf 'swaybg -i %q -m fill >/dev/null 2>&1 &\nnap 0.8\n' "/dev/shm/r27/pack/wall-$mood.png"
    cat <<'PLAY'
chord logo Return; nap 1.5; text 'ls -a'; key Return; nap 0.8
chord logo Return; nap 1.5
chord logo 2; nap 1
chord logo Return; nap 1.2; text 'cal'; key Return; nap 0.6
chord logo 1; nap 1.2
start() { wf-recorder -y -c ffv1 -f "$REC" >/dev/null 2>&1 & R=$!; nap 1; }
stop() { kill -INT "$R"; wait "$R" 2>/dev/null; }
PLAY
    case $name in
      windows) cat <<'PLAY'
start
chord logo Return; nap 1.1
chord logo q; nap 1.1
chord logo Return; nap 1.1
chord logo q; nap 1.1
stop
PLAY
        ;;
      workspaces) cat <<'PLAY'
start
chord logo 2; nap 1.1
chord logo 1; nap 1.1
chord logo 3; nap 1.1
chord logo 1; nap 1.1
stop
PLAY
        ;;
      menus) cat <<'PLAY'
start
setsid -f kawa-quick; nap 1.1
key Escape; nap 0.9
chord logo space; nap 1.1
key Escape; nap 0.9
chord logo r; nap 1.3
key Escape; nap 0.9
chord logo u; nap 1.2
key Escape; nap 0.9
stop
PLAY
        ;;
    esac
  } >"$W/$name.sh"
  bash "$here/kit.sh" --theme "$mood" --time 90 "$@" --out "$W/$name" --play "$W/$name.sh" play >"$W/$name.log" 2>&1 \
    || { echo "motion-review: the kit failed ($name): $(tail -n 2 "$W/$name.log")" >&2; exit 2; }
  mkdir -p "$W/f-$name"
  ffmpeg -v error -i "$W/$name.mkv" -fps_mode passthrough "$W/f-$name/%05d.png" || exit 2
  ffprobe -v error -select_streams v -show_entries frame=pts_time -of csv=p=0 "$W/$name.mkv" >"$W/$name.pts"
  python3 -I - "$W/f-$name" "$W/$name.pts" "$outdir/$prefix-$name.webp" "$name" <<'PY' || exit 2
import glob, sys
from PIL import Image
frames, pts, out, name = sys.argv[1:]
files = sorted(glob.glob(frames + "/*.png"))
times = [float(x.strip().strip(",")) for x in open(pts) if x.strip()]
times, files = times[:len(files)], files[:len(times)]
SCALE = 960 / 1920
if name == "menus":                 # (a menu at its real size: the part of the screen they use)
    view = lambda im: im.crop((480, 0, 1920, 810)).resize((960, 540), Image.LANCZOS)
else:
    view = lambda im: im.resize((960, 540), Image.LANCZOS)
keep, dur = [], []
for i, f in enumerate(files):
    d = int(((times[i + 1] - times[i]) if i + 1 < len(times) else 0.5) * 1000)
    if keep and dur[-1] < 20:       # (a browser plays nothing shorter: its time joins the last frame's)
        dur[-1] += d
        continue
    keep.append(f)
    dur.append(d)
pics = [view(Image.open(f).convert("RGB")) for f in keep]
pics[0].save(out, format="WEBP", save_all=True, append_images=pics[1:] + pics, loop=0, quality=72, method=2,
             duration=[max(d, 20) for d in dur] + [max(d, 20) * 3 for d in dur])
print(f"motion-review: {out}: {len(pics)} frames")
PY
done
