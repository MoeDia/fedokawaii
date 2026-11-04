#!/usr/bin/env bash
# tools/regress/tv-frames.sh — never again a television that skips or leaves a stray pixel (r27-bar-10,
# the master's trace of 1 Nov: "the bar's TV icon checked frame by frame"): the real bar on the real
# GPU, a video playing (a stand-in player and meter: 60 frames a second, as cava's), the first tile
# on the right shot as fast as grim goes. Every shot must be one of art/icons.txt's four frames —
# in order, round and round, six a second — and nothing else in that tile may move.
#   bash tools/regress/tv-frames.sh [KIT OPTION…]
# Exit 0 held · 1 broken (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-tv.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
kit=() given=""
while (($#)); do case $1 in --bin) given=$2; shift 2 ;; *) kit+=("$1"); shift ;; esac; done
b=$out/bin; mkdir "$b"
if [[ -n $given ]]; then for f in "$given"/*; do ln -s "$(realpath "$f")" "$b/"; done; fi
cat >"$b/playerctl" <<'STUB_END'
#!/bin/sh
row=$(printf 'mpv\037Playing\037\037A film\037file:///v/film.mkv\037')
case "$*" in
  *--follow*) printf '%s\n' "$row"; exec sleep 300 ;;
  *metadata*) printf '%s\n' "$row" ;;
esac
STUB_END
cat >"$b/cava" <<'STUB_END'
#!/usr/bin/env python3
import time
t, frame = time.monotonic(), "5;" * 16
while True:
    print(frame, flush=True)
    t += 1 / 60
    time.sleep(max(0, t - time.monotonic()))
STUB_END
printf '#!/bin/sh\nexec sleep 300\n' >"$b/pw-metadata"
chmod +x "$b"/playerctl "$b"/cava "$b"/pw-metadata
cat >"$out/play.sh" <<'PLAY_END'
nap 3
t=$(($(date +%s) + 3))
while (($(date +%s) < t)); do grim -g "1300,0 620x27" "$KIT_OUT/f-$(date +%s%N).png"; done
PLAY_END
for th in dark light; do
  bash "$here/../kit.sh" --theme "$th" "${kit[@]}" --bin "$b" --time 150 --out "$out/$th" --play "$out/play.sh" play >"$out/kit-$th.log" 2>&1 \
    || { echo "tv-frames: the kit failed: $(tail -n 2 "$out/kit-$th.log")" >&2; exit 2; }
done
python3 -I "$here/shots.py" tv "$here/../../art/icons.txt" "$out/dark" "$out/light"
