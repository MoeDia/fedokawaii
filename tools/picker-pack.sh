#!/usr/bin/env bash
# tools/picker-pack.sh — the owner's picker page (r28 f16b): every option of the sheets alone and every motion as a video,
# in ~/.local/share/r28/img/hi/: re-rendered from the sheets' tools, headless (tools/kit.sh --tree), nothing applied.
#   bash tools/picker-pack.sh stills|motions  (after tools/kit-tree.sh; ONLY=ab: those sets' motions)
# Exit 0 · 1 a shot missing
set -u
here=$(cd "$(dirname "$0")" && pwd)
repo=${here%/*}
export PATH=$HOME/.local/bin:$PATH
tree=$HOME/.cache/r28/kit-tree
HI=$HOME/.local/share/r28/img/hi
W=/dev/shm/r28/f16b
mkdir -p "$HI" "$W"
pack() { python3 -B "$here/picker-pack.py" "$@"; }
kit() { bash "$here/kit.sh" --tree "$tree" "$@"; }
walls() {
  pack wall "$HOME/.local/share/fedokawaii/wallpapers/dark/sakurada-rain.src" "$W/wall-dark.png"
  pack wall "$HOME/.local/share/fedokawaii/wallpapers/light/paper-plane.src" "$W/wall-light.png"
}

# the play of the power dialog's two states (its systemctl a stand-in, as tools/regress/power-dialog.sh)
power_play() {
  cat >"$W/power.sh" <<'PLAY'
mkdir -p "$KIT_OUT/stub"; printf '#!/bin/sh\n' >"$KIT_OUT/stub/systemctl"; chmod +x "$KIT_OUT/stub/systemctl"
export PATH=$KIT_OUT/stub:$PATH
panel; ready
setsid -f kawa-power; nap 1.2; shot power-rest
key Right Right Right Right; nap 0.5; key Return; nap 0.15; shot power-armed
PLAY
  cat >"$W/books.sh" <<'PLAY'
panel; warm; nap 1.5
chord logo r; nap 3; shot books
PLAY
}

stills() {
  walls
  [[ -f $W/lock/light-3.png ]] || python3 -B "$here/lock-options.py" render "$W/lock"
  pack lock "$W" "$HI"
  power_play
  # the mocks' words and the throw-away prompt font
  python3 -B "$here/prompt-options.py" gen "$W/prompt"
  pdftoppm -f 1 -l 1 -singlefile -png -r 72 <(magick -size 595x842 xc:white pdf:-) "$W/cover"
  local m n f o
  for m in dark light; do
    kit --theme "$m" --wall "$W/wall-$m.png" --out "$W/$m" --time 150 --play "$W/power.sh" bar play || return 1
    kit --theme "$m" --wall "$W/wall-$m.png" --out "$W/$m" system || return 1
    kit --theme "$m" --wall "$W/wall-$m.png" --out "$W/$m" --time 60 --play "$W/books.sh" play || return 1
    pack window "$W" "$W/$m/system.png" "$HI/h1-0-$m.png" "$m"
    pack window "$W" "$W/$m/books.png" "$HI/h2-0-$m.png" "$m"
    n=0
    for f in now:now one:'1 tanzaku' two:'2 obi' three:'3 rakkan'; do
      sed "s/^for o in .*; do\$/for o in '$f'; do/" "$W/prompt/mock-$m.sh" >"$W/prompt/one-$m.sh"
      kit --theme "$m" --wall "$W/wall-$m.png" --fontdir "$W/prompt/font" --out "$W/$m/p" --tui "66x6:$W/prompt/one-$m.sh" tui || return 1
      pack window "$W" "$W/$m/p/tui.png" "$HI/d-$n-$m.png" "$m"
      n=$((n + 1))
    done
    for o in u1:1:86x13:h1 u2:2:98x11:h1 r1:1:86x17:h2 r2:2:66x19:h2; do
      IFS=: read -r l n sz s <<<"$o"
      printf 'exec bash %q %q %q\n' "$here/menu-options.mock" "$l" "$W/cover.png" >"$W/menu-$l.sh"
      kit --theme "$m" --wall "$W/wall-$m.png" --out "$W/$m/$l" --tui "$sz:$W/menu-$l.sh" tui || return 1
      pack window "$W" "$W/$m/$l/tui.png" "$HI/$s-$n-$m.png" "$m"
    done
  done
  pack bar "$W" "$HOME/.cache/claude-fontpick/jf" "$HI"     # (Shinonome 16, kept there since the font trials)
  pack power "$W" "$HI"
  bash "$here/helium-options.sh" "$W/helium-sheet.jpg" && pack helium /dev/shm/r28/f15/run "$W" "$HI"
}

# the motions: SET N NAME_IN_CONFIG OPEN_MS CLOSE_MS [WAVE]; a dwl for each (a scratch copy of the kit tree's), the kit's play recorded
build() {
  local st=$1 n=$2 name=$3 a=$4 b=$5 wave=${6:-} s=$W/dwl-src wlr
  . "$repo/lib/manifest.sh"
  wlr=$(sed -n 's/^DWL_WLROOTS="\([^"]*\)".*/\1/p' "$repo/fedokawaii.conf")
  [[ -d $s ]] || cp -a "$tree/src/dwl" "$s"
  cp "$repo/src/dwl/config.h" "$s/config.h"
  case $st in
    a) sed -i "s/anim_motion  *= [A-Za-z]*;/anim_motion = $name;/; s/anim_open_ms  *= [0-9]*;/anim_open_ms = $a;/; s/anim_close_ms  *= [0-9]*;/anim_close_ms = $b;/" "$s/config.h" ;;
    b) sed -i "s/anim_tag_motion  *= TagStrip;/anim_tag_motion = $name;/; s/anim_tag_ms  *= 450;/anim_tag_ms = $a;/; s/anim_tag_wave  *= 48;/anim_tag_wave = $wave;/" "$s/config.h" ;;
    c) sed -i "s/anim_scroll_motion  *= [A-Za-z]*;/anim_scroll_motion = $name;/; s/anim_unroll_ms  *= [0-9]*;/anim_unroll_ms = $a;/; s/anim_rollup_ms  *= [0-9]*;/anim_rollup_ms = $b;/" "$s/config.h" ;;
  esac
  make -C "$s" -j"$(nproc)" "${DWL_MAKE[@]}" "WLR_INCS=$(<"/usr/local/lib/fedokawaii-wlroots-$wlr/cflags")" \
    "WLR_LIBS=-L/usr/local/lib/fedokawaii-wlroots-$wlr/lib -lwlroots-$wlr -Wl,--disable-new-dtags,-rpath,/usr/local/lib/fedokawaii-wlroots-$wlr/lib" >"$W/build.log" 2>&1 \
    || { tail -n 5 "$W/build.log"; return 1; }
  mkdir -p "$W/dwl"; cp "$s/dwl" "$W/dwl/$st-$n"
}
play_of() {
  # (a region in lossless x264: 3 times the frames of a whole screen in ffv1, which drops most of a motion)
  printf 'REC=%s\nGEOM=%q\n' "$W/rec/$1.mkv" "$2"
  cat <<'PLAY'
start() {
  if [[ $GEOM == all ]]; then wf-recorder -y -c ffv1 -f "$REC" >/dev/null 2>&1 & 
  else wf-recorder -y -g "$GEOM" -c libx264 -x yuv444p -p preset=ultrafast -p crf=0 -f "$REC" >/dev/null 2>&1 & fi
  R=$!; nap 1
}
stop() { nap 1; kill -INT "$R"; wait "$R" 2>/dev/null; }   # (the recorder loses its last frames: a tail to lose)
PLAY
  case $1 in
    a) cat <<'PLAY'
# (real tiled windows beside others, by the key: a window of app-id float takes the scroll's motion, and a window alone
# fills the screen, where dwl has no motion)
chord logo Return; nap 1.5; text 'ls -a'; key Return; nap 0.8
chord logo Return; nap 1.5; text 'cal'; key Return; nap 0.8
start
chord logo Return; nap 1.0; chord logo q; nap 0.8
chord logo Return; nap 1.0; chord logo q; nap 0.8
stop
PLAY
      ;;
    b) cat <<'PLAY'
chord logo Return; nap 1.5; text 'ls -a'; key Return; nap 0.8
chord logo Return; nap 1.5
chord logo 2; nap 1
chord logo Return; nap 1.2; text 'cal'; key Return; nap 0.6
chord logo 1; nap 1.2
start
chord logo 2; nap 0.8
chord logo 1; nap 0.8
chord logo 2; nap 0.8
chord logo 1; nap 0.8
stop
PLAY
      ;;
    c) cat <<'PLAY'
for t in "the first line of a poem about ink" "15% of 2400 = 360" "wlroots release notes" "kuniyoshi, the earth spider"; do printf '%s' "$t" | cliphist store; done
panel; warm; nap 1.5
chord logo v; nap 1.5; key Escape; nap 1
start
chord logo v; nap 0.8; key Escape; nap 0.8
chord logo v; nap 0.8; key Escape; nap 0.8
stop
PLAY
      ;;
  esac
}
motions() {
  mkdir -p "$W/rec"
  local st n name a b wave geom out g
  # (the warm window's region: from a whole-screen recording of the motion that travels furthest, omori)
  [[ ${ONLY:-c} == *c* ]] || geom=none
  [[ ${geom:-} ]] || { build c 2 ScrollOmori 460 240 || return 1
  play_of c all >"$W/rec/c.sh"
  kit --theme dark --wall "$W/wall-dark.png" --dwl "$W/dwl/c-2" --time 90 --out "$W/rec/out" --play "$W/rec/c.sh" play >"$W/rec/c.log" 2>&1 </dev/null || return 1
  out=$(pack motion "$W/rec/c.mkv" "$W/rec" c 2 460 auto) || return 1
  printf '%s\n' "$out"
  geom=$(sed -n 's/.*crop \([0-9]*\):\([0-9]*\):\([0-9]*\):\([0-9]*\)$/\3,\4 \1x\2/p' <<<"$out")
  [[ $geom ]] || return 1
  rm -f "$W/rec/c.mkv"; }
  while read -r st n name a b wave; do
    [[ $st && ${ONLY:-$st} == *$st* ]] || continue
    build "$st" "$n" "$name" "$a" "$b" "$wave" || return 1
    case $st in a) g="320,180 1280x720" ;; b) g="320,34 1280x720" ;; c) g=$geom ;; esac
    play_of "$st" "$g" >"$W/rec/$st.sh"
    rm -f "$W/rec/$st.mkv"
    kit --theme dark --wall "$W/wall-dark.png" --dwl "$W/dwl/$st-$n" --time 90 --out "$W/rec/out" --play "$W/rec/$st.sh" play >"$W/rec/$st.log" 2>&1 </dev/null \
      || { echo "kit failed $st-$n: $(tail -n 2 "$W/rec/$st.log")"; return 1; }
    pack motion "$W/rec/$st.mkv" "$HI" "$st" "$n" "$a" iw:ih:0:0 </dev/null || return 1
    rm -f "$W/rec/$st.mkv"
  done <<'TABLE'
a 0 MotionHop 450 400
a 1 MotionSeal 150 110
a 2 MotionShoji 190 150
a 3 MotionKasumi 220 170
b 0 TagStrip 450 0 48
b 1 TagHayate 220 0 0
b 2 TagScroll 420 0 48
b 3 TagFusuma 300 0 0
c 0 ScrollRod 300 240
c 1 ScrollKakejiku 380 280
c 2 ScrollOmori 460 240
c 3 ScrollMakimono 340 260
TABLE
}

case ${1:-} in
  stills) stills ;;
  motions) motions ;;
  *) echo "picker-pack: stills|motions" >&2; exit 2 ;;
esac
