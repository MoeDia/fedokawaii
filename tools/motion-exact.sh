#!/usr/bin/env bash
# tools/motion-exact.sh — one motion option rendered frame-exact (r28 m1), for the owner's picker page: a test build of dwl
# (ANIM_STEPCLOCK, the repository's patch and config with the option switched on) in the kit (tools/kit.sh --tree), its animation
# clock stepped 1/60 s a frame and each frame taken by screencopy (tools/motion-exact.py): nothing dropped, whatever the PC's load.
# Open and close (a workspace: there and back), each twice, half a second's rest after each.
#   bash tools/motion-exact.sh SET N MOOD [OUT]   (after tools/kit-tree.sh) → OUT/SET-N-MOOD.mp4 -slow.mp4 -strip.png .png; OUT default hi/
#   python3 -B tools/motion-exact.py pairs ~/.cache/r28/motion [SET]   every pair of the options made so far compared
# SET N come from the table at the end: a new option needs its row. Exit 0 · 1 a duration off the design by over a frame · 2 could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
repo=${here%/*}
export PATH=$HOME/.local/bin:$PATH
st=${1:?set}; n=${2:?n}; mood=${3:?mood}; out=${4:-$HOME/.local/share/r28/img/hi}
tree=$HOME/.cache/r28/kit-tree
W=/dev/shm/r28/motion-exact; run=$W/$st-$n-$mood
exact=$here/motion-exact.py
REST=30

row=$(awk -v s="$st" -v n="$n" '$1 == s && $2 == n' <<'TABLE'
a 0 MotionHop 450 400
a 1 MotionSeal 150 110
a 2 MotionShoji 190 150
a 3 MotionKasumi 220 170
a 4 MotionMado 260 190
a 5 MotionMozaiku 300 220
a 6 MotionKushi 240 180
a 7 MotionMon 300 200
b 0 TagStrip 450 450 48
b 1 TagHayate 220 220 0
b 2 TagScroll 420 420 48
b 3 TagFusuma 300 300 0
b 4 TagHeya 360 360 0
b 5 TagHitomi 420 420 0
b 6 TagHishi 440 440 0
b 7 TagSuna 340 340 0
c 2 ScrollOmori 460 240
TABLE
)
[[ $row ]] || { echo "motion-exact: no row for $st $n" >&2; exit 2; }
read -r _ _ name open close wave <<<"$row"

# the dwl: the repository's patch on the pinned commit, never the kit tree's older build
build() {
  local s=$W/dwl-src wlr pin
  . "$repo/lib/manifest.sh"
  wlr=$(sed -n 's/^DWL_WLROOTS="\([^"]*\)".*/\1/p' "$repo/fedokawaii.conf")
  pin=$(sed -n 's/^DWL_COMMIT="\([^"]*\)".*/\1/p' "$repo/fedokawaii.conf")
  rm -rf "$s"
  git -c advice.detachedHead=false clone -q "$tree/src/dwl" "$s" && git -C "$s" -c advice.detachedHead=false checkout -q -f "$pin" && git -C "$s" apply "$repo/src/dwl/dwl.patch" || return 1
  cp "$repo/src/dwl/config.h" "$s/config.h"
  case $st in
    a) sed -i "s/anim_motion  *= [A-Za-z]*;/anim_motion = $name;/; s/anim_open_ms  *= [0-9]*;/anim_open_ms = $open;/; s/anim_close_ms  *= [0-9]*;/anim_close_ms = $close;/" "$s/config.h" ;;
    b) sed -i "s/anim_tag_motion  *= [A-Za-z]*;/anim_tag_motion = $name;/; s/anim_tag_ms  *= [0-9]*;/anim_tag_ms = $open;/; s/anim_tag_wave  *= [0-9]*;/anim_tag_wave = $wave;/" "$s/config.h" ;;
    c) sed -i "s/anim_scroll_motion  *= [A-Za-z]*;/anim_scroll_motion = $name;/; s/anim_unroll_ms  *= [0-9]*;/anim_unroll_ms = $open;/; s/anim_rollup_ms  *= [0-9]*;/anim_rollup_ms = $close;/" "$s/config.h" ;;
  esac
  make -C "$s" -j"$(nproc)" "${DWL_MAKE[@]}" "XWAYLAND=-DXWAYLAND -DANIM_STEPCLOCK" "WLR_INCS=$(<"/usr/local/lib/fedokawaii-wlroots-$wlr/cflags")" \
    "WLR_LIBS=-L/usr/local/lib/fedokawaii-wlroots-$wlr/lib -lwlroots-$wlr -Wl,--disable-new-dtags,-rpath,/usr/local/lib/fedokawaii-wlroots-$wlr/lib" >"$W/build.log" 2>&1 \
    || { tail -n 5 "$W/build.log" >&2; return 1; }
  cp "$s/dwl" "$run/dwl"
}

frames_of() { echo $(( ($1 * 60 + 999) / 1000 + REST )); }

play() {
  printf 'EX=%q\nRUN=%q\nOPENF=%q\nCLOSEF=%q\n' "$exact" "$run" "$(frames_of "$open")" "$(frames_of "$close")"
  cat <<'PLAY'
ex() { python3 -B "$EX" "$@"; }
# (the key, then a wait in stopped time: the client takes what real time it takes; its animation starts when the clock moves)
ev() { "$@"; nap 1.2; }
PLAY
  case $st in
    a) cat <<'PLAY'
chord logo Return; nap 1.5; text 'ls -a'; key Return; nap 0.8
chord logo Return; nap 1.5; text 'cal'; key Return; nap 0.8
ex freeze
ex frames "$RUN/00-rest" 12
ev chord logo Return; ex frames "$RUN/01-open" "$OPENF"
ev chord logo q; ex frames "$RUN/02-close" "$CLOSEF"
ev chord logo Return; ex frames "$RUN/03-open" "$OPENF"
ev chord logo q; ex frames "$RUN/04-close" "$CLOSEF"
PLAY
      ;;
    b) cat <<'PLAY'
chord logo Return; nap 1.5; text 'ls -a'; key Return; nap 0.8
chord logo Return; nap 1.5
chord logo 2; nap 1
chord logo Return; nap 1.2; text 'cal'; key Return; nap 0.6
chord logo 1; nap 1.2
ex freeze
ex frames "$RUN/00-rest" 12
ev chord logo 2; ex frames "$RUN/01-open" "$OPENF"
ev chord logo 1; ex frames "$RUN/02-close" "$CLOSEF"
ev chord logo 2; ex frames "$RUN/03-open" "$OPENF"
ev chord logo 1; ex frames "$RUN/04-close" "$CLOSEF"
PLAY
      ;;
    c) cat <<'PLAY'
for t in "the first line of a poem about ink" "15% of 2400 = 360" "wlroots release notes" "kuniyoshi, the earth spider"; do printf '%s' "$t" | cliphist store; done
panel; warm; nap 1.5
chord logo v; nap 1.5; key Escape; nap 1
ex freeze
ex frames "$RUN/00-rest" 12
ev chord logo v; ex frames "$RUN/01-open" "$OPENF"
ev key Escape; ex frames "$RUN/02-close" "$CLOSEF"
ev chord logo v; ex frames "$RUN/03-open" "$OPENF"
ev key Escape; ex frames "$RUN/04-close" "$CLOSEF"
PLAY
      ;;
  esac
}

rm -rf "$run"; mkdir -p "$run" "$out"
[[ ${KEEP:-} ]] || trap 'rm -rf "$run"' EXIT
build || exit 2
wall=$W/wall-$mood.png
if [[ ! -f $wall ]]; then
  case $mood in dark) src=dark/sakurada-rain.src ;; light) src=light/paper-plane.src ;; esac
  python3 -B "$here/picker-pack.py" wall "$HOME/.local/share/fedokawaii/wallpapers/$src" "$wall" || exit 2
fi
play >"$run/play.sh"
bash "$here/kit.sh" --tree "$tree" --theme "$mood" --wall "$wall" --dwl "$run/dwl" --time 300 --out "$run/kit" --play "$run/play.sh" play >"$run/kit.log" 2>&1 </dev/null \
  || { echo "motion-exact: the kit failed: $(tail -n 2 "$run/kit.log")" >&2; exit 2; }
[[ -d $run/04-close ]] || { echo "motion-exact: no frames: $(tail -n 3 "$run/kit.log")" >&2; exit 2; }
python3 -B "$exact" make "$run" "$out" "$st" "$n" "$mood" "$open" "$close" "$HOME/.cache/r28/motion"
