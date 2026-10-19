#!/usr/bin/env bash
# tests/look/test_wallpaper.sh — kawa-wallpaper: each theme's own wallpaper, drawn at full
# quality at every monitor's exact size; the picker; its previews. ImageMagick is the real one
# (the pictures are checked to the pixel); swaybg, the monitors (wlr-randr), fzf and the
# picker's window are stand-ins (the pack's fetching: test_pack.sh).
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"
need magick python3 flock

setup() {
  look
  unset WAYLAND_DISPLAY
  SHARE=$HOME/.local/share/fedokawaii; PACK=$SHARE/wallpapers CACHE=$HOME/.cache/kawa-wallpaper
  STATE=$HOME/.local/state/fedokawaii WP=$HOME/Pictures/Wallpapers
  # swaybg: keeps its arguments, and stays running (a long sleep in the process table)
  argv swaybg 'bash -c '"'"'exec -a "$0" /bin/sleep 300'"'"' "fake-swaybg-of-$FAKE_TMP" >/dev/null 2>&1 &
echo "swaybg $!" >>"$FAKE_PROCS"'
  # setsid -f CMD: CMD at once (so its arguments are there to check); plain setsid: the real one
  stub setsid '[ "$1" = -f ] && { shift; exec "$@"; }; exec /usr/bin/setsid "$@"'
  stub sleep
  screens "DP-1 1920x1080@143.981003"
  # shellcheck source=/dev/null
  . "$HOME/.config/fedokawaii/icons.sh"
}
running() { pgrep -x swaybg | wc -l; }                  # swaybg processes alive now
settled() {   # settled N — swaybg processes alive, once the killed ones are gone (5 s at most)
  local n i; for i in {1..250}; do n=$(running); ((n <= $1)) && break; /bin/sleep 0.02; done; echo "$n"
}
last() { ncalls swaybg; }
art() {   # art NAME [WxH] [GRAVITY-TEST] — a pack picture (NAME.src, as fetched: a JPEG) for the
  # current theme folder given in NAME's path; a smooth gradient, or with "split" its top
  # quarter red and the rest blue (to see which part a crop keeps)
  local f=$1 size=${2:-3840x2160}
  mkdir -p "$(dirname "$f")"
  if [[ ${3:-} == split ]]; then
    magick -size "${size%x*}x$(( ${size#*x} / 4 ))" xc:red -size "${size%x*}x$(( ${size#*x} * 3 / 4 ))" xc:blue -append "JPG:$f"
  else magick -size "$size" gradient:'#203050'-'#e0c080' "JPG:$f"; fi
}
px() { magick "$1" -format "%[pixel:p{$2,$3}]" info: 2>/dev/null; }
photo() { mkdir -p "$(dirname "$1")"; magick -size 64x40 gradient:red-blue "$1"; }   # photo FILE
shown() { args_of swaybg "${1:-$(last)}" | sed -n '/^-i$/{n;p}' | head -n1; }        # the first picture handed over
colours() { magick "$1" -format '%k' info: 2>/dev/null; }
cover_of() {   # cover_of SRC — the drawing kawa-wallpaper keeps of SRC for the 1080p monitor
  local k; k=$(printf '%s\n' c1 "$1" "$(stat -c %Y "$1")" 1920 1080 center | sha1sum); printf '%s' "$CACHE/1920x1080-${k%% *}.png"
}

# ── --restore: the theme's choice, every monitor at its size ───────────────────
setup
case_ "before the pack is here: the theme's plain ground, nothing else"
rc 0 kawa-wallpaper --restore
args_eq swaybg 1 -c '#0f0e0c'
eq "$(running)" 1 "one swaybg"

case_ "with the pack: the theme's default, drawn at the monitor's exact size at full quality"
setup
art "$PACK/dark/ink-ridges-night.src"
rc 0 kawa-wallpaper --restore
img=$(shown)
args_eq swaybg 1 -c '#0f0e0c' -o DP-1 -i "$img" -m fill
[[ $img == "$CACHE"/1920x1080-*.png ]] && _ok || _no "not a cached 1080p picture: $img"
eq "$(size_of "$img")" 1920x1080
(( $(colours "$img") > 500 )) && _ok || _no "only $(colours "$img") colours: redrawn coarsely, not at full quality"

case_ "two monitors of different sizes, one turned, one switched off: each its own size"
setup
art "$PACK/dark/ink-ridges-night.src"
screens "DP-1 2560x1440@164.998993" "HDMI-A-1 3840x2160@60.000000" "DP-2 1920x1080 turned" "DP-3 1920x1080 off"
rc 0 kawa-wallpaper --restore
a=$(args_of swaybg)
for o in DP-1:2560x1440 HDMI-A-1:3840x2160 DP-2:1080x1920; do
  f=$(grep -A2 -x "${o%:*}" <<<"$a" | sed -n 3p)
  eq "$(size_of "$f")" "${o#*:}" "${o%:*}"
done
lacks "$a" DP-3 "a switched-off monitor is left out"

case_ "the crop: from the middle, or towards the side the list names"
setup
{ echo "dark  tall-one  -  north   0  https://x/a.jpg  Test"; echo "dark  tall-two  -  center  0  https://x/b.jpg  Test"; } >>"$SHARE/wallpapers.list"
art "$PACK/dark/tall-one.src" 1920x2160 split; art "$PACK/dark/tall-two.src" 1920x2160 split
kawa-wallpaper --set pack:tall-one
[[ $(px "$(shown)" 960 2) =~ ^srgb\(2[0-9][0-9],[0-9],[0-9]\)$ ]] && _ok || _no "north: the top (red) not kept: $(px "$(shown)" 960 2)"
kawa-wallpaper --set pack:tall-two
[[ $(px "$(shown)" 960 2) =~ ^srgb\([0-9],[0-9],2[0-9][0-9]\)$ ]] && _ok || _no "centre: not the middle (blue at its top edge): $(px "$(shown)" 960 2)"

case_ "a custom mode with no refresh rate; no wlr-randr at all: the plain ground"
setup
art "$PACK/dark/ink-ridges-night.src"
screens "DP-1 1920x1200@none"
kawa-wallpaper --restore
eq "$(size_of "$(shown)")" 1920x1200 "16:10: covered and cut to size"
setup; art "$PACK/dark/ink-ridges-night.src"; hide wlr-randr
kawa-wallpaper --restore
args_eq swaybg 1 -c '#0f0e0c'

case_ "drawn once: a second restore uses the same file, nothing redrawn"
setup
art "$PACK/dark/ink-ridges-night.src"
kawa-wallpaper --restore; first=$(shown 1); t=$(stat -c %Y "$first")
/bin/sleep 1.1; kawa-wallpaper --restore
eq "$(shown 2)" "$first"; eq "$(stat -c %Y "$first")" "$t"
case_ "a picture replaced under the same name: drawn again"
art "$PACK/dark/ink-ridges-night.src" 3840x2160 split; touch -d '+5 seconds' "$PACK/dark/ink-ridges-night.src"
kawa-wallpaper --restore
[[ $(shown 3) != "$first" ]] && _ok || _no "the old drawing was shown"

case_ "the light theme: its own default (ink-ridges), ground and choice"
setup
ln -sfn themes/light "$HOME/.config/fedokawaii/current"
art "$PACK/light/ink-ridges.src"
kawa-wallpaper --restore
eq "$(args_of swaybg | head -n2 | tail -n1)" '#e9e1cb'
[[ -n $(shown) ]] && _ok || _no "ink-ridges not shown"
[[ ! -e $STATE/wallpaper-dark ]] && _ok || _no "the dark theme's choice was written by a light restore"

case_ "the old swaybg goes once the new one is up: one left after many changes"
setup
for _ in 1 2 3 4; do kawa-wallpaper --restore; done
eq "$(settled 1)" 1
eq "$(last)" 4

case_ "15 restores at once (quick theme switches): they queue, and one swaybg is left"
setup
pids=(); for _ in {1..15}; do kawa-wallpaper --restore & pids+=($!); done
codes=""; for p in "${pids[@]}"; do wait "$p"; codes+="$?"; done
eq "$codes" "000000000000000"
eq "$(settled 1)" 1

case_ "swaybg not installed: says so, exit 1, the old wallpaper stays and the choice is kept"
setup
art "$PACK/dark/moon-road-ink.src"
kawa-wallpaper --restore; old=$(pgrep -x swaybg)
echo "pack:ink-ridges-night" >"$STATE/wallpaper-dark"
hide swaybg
out=$(kawa-wallpaper --set pack:moon-road-ink 2>&1); r=$?
eq "$r" 1
has "$out" "swaybg"
alive "$old" && _ok || _no "the wallpaper on screen was taken down"
eq "$(cat "$STATE/wallpaper-dark")" "pack:ink-ridges-night"
rc 1 kawa-wallpaper --restore

# ── --set: a choice, remembered per theme ─────────────────────────────────────
case_ "a pack picture with a pair: both themes get the same place"
setup
art "$PACK/dark/ink-ridges-night.src" 1920x1080; art "$PACK/light/ink-ridges.src" 1920x1080
rc 0 kawa-wallpaper --set pack:ink-ridges-night
eq "$(cat "$STATE/wallpaper-dark")" pack:ink-ridges-night
eq "$(cat "$STATE/wallpaper-light")" pack:ink-ridges "the light theme: the same ridges by day"
art "$PACK/dark/seaside-train.src" 1920x1080
rc 0 kawa-wallpaper --set pack:seaside-train
eq "$(cat "$STATE/wallpaper-light")" pack:ink-ridges "no pair: the other theme keeps its own"

case_ "your own picture with an odd name: drawn to the screen's size (a small one enlarged to cover), remembered exactly"
setup
odd="$WP/my "'"best" it'\''s $(touch pwned) `id` ü日本 العربية -x.png'
photo "$odd"
( cd "$TMP" && kawa-wallpaper --set "$odd" ); r=$?
eq "$r" 0
eq "$(size_of "$(shown)")" 1920x1080
eq "$(cat "$STATE/wallpaper-dark")" "$odd"
[[ ! -e $TMP/pwned ]] && _ok || _no "a file name ran as a command"
kawa-wallpaper --restore
eq "$(shown 2)" "$(shown 1)" "the same drawing at login"

case_ "a name with a line break or a leading dash, set directly: still exact"
setup
nl="$WP/two"$'\n'"lines.png"; photo "$nl"
rc 0 kawa-wallpaper --set "$nl"
eq "$(size_of "$(shown)")" 1920x1080
eq "$(cat "$STATE/wallpaper-dark")" "$nl"
dash="$WP/-x.png"; photo "$dash"
rc 0 kawa-wallpaper --set "$dash"; eq "$(cat "$STATE/wallpaper-dark")" "$dash"

case_ "a choice that is gone: --set says no; --restore shows the default but keeps remembering it"
setup
art "$PACK/dark/ink-ridges-night.src" 1920x1080
rc 1 kawa-wallpaper --set "$WP/nothing.png"
eq "$(last)" 0 "nothing was drawn"
photo "$WP/later.png"; kawa-wallpaper --set "$WP/later.png"
mv "$WP/later.png" "$TMP/away.png"                 # (on a drive not there yet, or deleted)
rc 0 kawa-wallpaper --restore
eq "$(shown 2)" "$(cover_of "$PACK/dark/ink-ridges-night.src")" "the default (ink-ridges-night) instead"
eq "$(cat "$STATE/wallpaper-dark")" "$WP/later.png" "the choice is still yours"
mv "$TMP/away.png" "$WP/later.png"
kawa-wallpaper --restore
eq "$(shown 3)" "$(shown 1)" "back, with its picture"
echo "pack:retired-one" >"$STATE/wallpaper-dark"
rc 0 kawa-wallpaper --restore
eq "$(shown 4)" "$(cover_of "$PACK/dark/ink-ridges-night.src")" "a pack picture no longer there: the default"

case_ "--set by hand with a name relative to the folder you are in: remembered in full"
setup
photo "$WP/rel.png"
( cd "$WP" && kawa-wallpaper --set rel.png ); r=$?
eq "$r" 0
eq "$(cat "$STATE/wallpaper-dark")" "$WP/rel.png" "a full path: --restore at login finds it from any folder"
out=$(kawa-wallpaper --set "$WP/nope.png" 2>&1); r=$?
eq "$r" 1
has "$out" "nope.png" "a choice that is not there is named"

case_ "an empty or garbled state file: the default"
setup
art "$PACK/dark/ink-ridges-night.src" 1920x1080
mkdir -p "$STATE"; : >"$STATE/wallpaper-dark"
rc 0 kawa-wallpaper --restore
eq "$(shown)" "$(cover_of "$PACK/dark/ink-ridges-night.src")"
printf '\x00\xff garbage' >"$STATE/wallpaper-dark"
rc 0 kawa-wallpaper --restore
eq "$(shown 2)" "$(cover_of "$PACK/dark/ink-ridges-night.src")"
case_ "an old choice from before (the drawn Fuji, gone): the default"
echo fuji >"$STATE/wallpaper-dark"
rc 0 kawa-wallpaper --restore
eq "$(shown 3)" "$(cover_of "$PACK/dark/ink-ridges-night.src")"

case_ "HOME with a space: everything still lands where it should"
setup
mkdir -p "$TMP/my home"; cp -a "$HOME/." "$TMP/my home/"; export HOME="$TMP/my home"
SHARE=$HOME/.local/share/fedokawaii CACHE=$HOME/.cache/kawa-wallpaper PACK=$HOME/.local/share/fedokawaii/wallpapers
art "$PACK/dark/ink-ridges-night.src" 1920x1080
rc 0 kawa-wallpaper --restore
[[ $(shown) == "$CACHE"/1920x1080-*.png && -s $(shown) ]] && _ok || _no "not drawn into the cache: $(shown)"

case_ "no runtime folder: exit 1 with a plain message"
setup
export XDG_RUNTIME_DIR=$TMP/no-such-run
out=$(kawa-wallpaper --restore 2>&1); r=$?
eq "$r" 1
has "$out" "kawa-wallpaper:"
lacks "$out" "line "

case_ "--help, and a wrong option"
setup
out=$(kawa-wallpaper --help 2>&1); r=$?
eq "$r" 0; has "$out" "kawa-wallpaper --restore"
out=$(kawa-wallpaper --bogus 2>&1); r=$?
eq "$r" 2; has "$out" "usage: kawa-wallpaper"

# ── the picker ───────────────────────────────────────────────────────────────
# fzf: keeps the rows and its options, then answers as FZF_PICK says (a row's first field,
# or "esc"); the picker's window (kawa-float) runs its command in place
picker() {
  argv fzf 'cat >"$FAKE_TMP/rows"
case ${FZF_PICK:-esc} in esc) exit 130 ;; esac
grep -m1 -F "$FZF_PICK	" "$FAKE_TMP/rows" || exit 1'
  stub kawa-float 'while [ "$1" != "--" ]; do shift; done; shift; "$@"'
  stub kawa-cell 'echo 12x24'
}
rows() { cat "$TMP/rows"; }
nrows() { wc -l <"$TMP/rows"; }
setup; picker
case_ "before the pack, nothing of your own: no rows"
kawa-wallpaper --tui "$TMP/out"
eq "$(nrows)" 0
case_ "one picture of your own: listed"
photo "$WP/only one.png"
kawa-wallpaper --tui "$TMP/out"
eq "$(rows)" "$WP/only one.png	$ICON_FOLDER  only one.png"
rm "$WP/only one.png"

case_ "the pack and your own: the default first, the pack in list order, then yours"
# (the pack has one pair, the default's, listed apart: two more, of different lengths, for the ◐ column)
{ echo "dark  quay-night  quay-day  center  0  https://x/a.jpg  Test"; echo "dark  old-pier-at-night  old-pier  center  0  https://x/b.jpg  Test"; } >>"$SHARE/wallpapers.list"
art "$PACK/dark/ink-ridges-night.src" 64x40; art "$PACK/dark/moon-road-ink.src" 64x40; art "$PACK/dark/seaside-train.src" 64x40
art "$PACK/dark/mishima-mist.src" 64x40; art "$PACK/dark/quay-night.src" 64x40; art "$PACK/dark/old-pier-at-night.src" 64x40; art "$PACK/light/red-fuji.src" 64x40
photo "$WP/b.png"; photo "$WP/a.jpg"; photo "$WP/sub dir/c.webp"
kawa-wallpaper --tui "$TMP/out"
eq "$(sed -n 1p "$TMP/rows")" "default	$ICON_TORII  ink-ridges-night (default)"
eq "$(cut -f1 "$TMP/rows" | tr '\n' ' ')" "default pack:moon-road-ink pack:mishima-mist pack:seaside-train pack:quay-night pack:old-pier-at-night $WP/a.jpg $WP/b.png $WP/sub dir/c.webp "
has "$(rows)" "$WP/sub dir/c.webp	$ICON_FOLDER  sub dir/c.webp"
lacks "$(rows)" red-fuji "the other theme's pictures are not offered"

case_ "the ◐ marks of the paired pictures stand in one column"
cols=$(grep -F "$ICON_THEME" "$TMP/rows" | cut -f2 | while IFS= read -r l; do p=${l%%"$ICON_THEME"*}; p=$(sed 's/\x1b\[[0-9;]*m//g' <<<"$p"); echo "${#p}"; done | sort -u)
eq "$(wc -l <<<"$cols")" 1 "one column: $cols"
eq "$(grep -cF "$ICON_THEME" "$TMP/rows")" 2 "quay-night and old-pier-at-night have a pair"

case_ "your own pictures with odd names: listed with their full path; tab and line break left out"
setup; picker
for n in "my photo.png" "ü日本 العربية.jpg" "it's \"quoted\".png" '$(touch pwned).png' '`touch pwned2`.png' \
         "-leading.png" "UPPER.PNG" $'tab\there.png' $'new\nline.png' "notes.txt" "no-ext"; do
  photo "$WP/$n" 2>/dev/null || { mkdir -p "$WP"; echo x >"$WP/$n"; }
done
kawa-wallpaper --tui "$TMP/out"
for n in "my photo.png" "ü日本 العربية.jpg" "it's \"quoted\".png" '$(touch pwned).png' '`touch pwned2`.png' "-leading.png" "UPPER.PNG"; do
  has "$(rows)" "$WP/$n	$ICON_FOLDER  $n"
done
lacks "$(rows)" "tab"; lacks "$(rows)" "line.png"; lacks "$(rows)" "notes.txt"; lacks "$(rows)" "no-ext"
eq "$(nrows)" 7
[[ ! -e $TMP/pwned && ! -e pwned && ! -e $TMP/pwned2 ]] && _ok || _no "a file name ran as a command"

case_ "1000 pictures of your own: all listed, quickly"
setup; picker
mkdir -p "$WP"; photo "$TMP/one.png"
for i in $(seq -w 1 1000); do ln "$TMP/one.png" "$WP/p$i.png"; done
start=$(date +%s%N)
kawa-wallpaper --tui "$TMP/out"
ms=$(( ($(date +%s%N) - start) / 1000000 ))
eq "$(nrows)" 1000
((ms < 10000)) && _ok || _no "the list took $ms ms"
eq "$(sed -n '1000p' "$TMP/rows" | cut -f1)" "$WP/p1000.png"

case_ "the cursor starts on the current choice"
FZF_PICK=esc kawa-wallpaper --tui "$TMP/out"
echo "$WP/p0500.png" >"$STATE/wallpaper-dark"
kawa-wallpaper --tui "$TMP/out"
has "$(args_of fzf "$(ncalls fzf)")" "start:pos(500)"

case_ "Super+W, Enter on an odd name: set exactly, through the dissolve"
setup; picker
stubf kawa-veil <<'EOF'
while [ "$1" != "--" ]; do shift; done; shift; exec "$@"
EOF
odd="$WP/\$(touch pwned) it's.png"; photo "$odd"
FZF_PICK="$odd" kawa-wallpaper; r=$?
eq "$r" 0
called '^kawa-veil --dissolve --time 520 -- '
eq "$(size_of "$(shown)")" 1920x1080
eq "$(cat "$STATE/wallpaper-dark")" "$odd"
[[ ! -e $TMP/pwned ]] && _ok || _no "the name ran as a command"

case_ "Esc, or the current one again: nothing changes"
reset_calls
FZF_PICK=esc kawa-wallpaper; r=$?
eq "$r" 0; eq "$(last)" 1; not_called '^kawa-veil'
FZF_PICK="$odd" kawa-wallpaper
eq "$(last)" 1 "the same one: not drawn again"

case_ "Super+W again while the picker is open (kawa-float --once says 3): nothing"
stub kawa-float 'exit 3'; reset_calls
rc 0 kawa-wallpaper
not_called '^fzf'

# ── the preview pane ─────────────────────────────────────────────────────────
# (the picker's previews always have the cell the window measured: --tui exports it)
export KAWA_CELL=12x26
case_ "a preview: a sixel picture; broken or missing pictures just say 'no preview', quietly"
setup
photo "$WP/ok.png"
out=$(kawa-wallpaper --preview "$WP/ok.png" 2>"$TMP/err")
[[ $out == $'\eP'* ]] && _ok || _no "no sixel came out: ${out:0:40}"
eq "$(cat "$TMP/err")" ""
head -c 200 "$WP/ok.png" >"$WP/cut.png"; echo "not a picture" >"$WP/fake.jpg"
for f in "$WP/cut.png" "$WP/fake.jpg" "$WP/missing.png" pack:not-there ""; do
  out=$(kawa-wallpaper --preview "$f" 2>"$TMP/err")
  eq "$out" "  $ICON_PICTURE  no preview" "[$f]"
  eq "$(cat "$TMP/err")" "" "[$f]: nothing on stderr"
done
art "$PACK/dark/moon-road-ink.src" 1920x1080
out=$(kawa-wallpaper --preview pack:moon-road-ink 2>/dev/null); [[ $out == $'\eP'* ]] && _ok || _no "no pack preview"
out=$(FZF_PREVIEW_COLUMNS=1 FZF_PREVIEW_LINES=1 kawa-wallpaper --preview pack:moon-road-ink 2>"$TMP/err")
eq "$(cat "$TMP/err")" "" "a tiny pane: no error"

case_ "--warm (while the picker is open): every preview drawn ahead; month-old ones cleared"
setup
photo "$WP/a.png"; photo "$WP/b.png"
mkdir -p "$CACHE/preview"; : >"$CACHE/preview/old.six"; touch -d '40 days ago' "$CACHE/preview/old.six"
kawa-wallpaper --warm
eq "$(find "$CACHE/preview" -name '*.six' | wc -l)" 2 "the two pictures"
[[ ! -e $CACHE/preview/old.six ]] && _ok || _no "a month-old preview was kept"
before=$(find "$CACHE/preview" -name '*.six' -printf '%f %T@\n' | sort)
kawa-wallpaper --preview "$WP/a.png" >/dev/null
eq "$(find "$CACHE/preview" -name '*.six' -printf '%f %T@\n' | sort)" "$before" "showing one draws nothing new: it was ready"

case_ "a preview killed half-way (fzf kills one you moved on from): its half-made file cleared next time"
setup
photo "$WP/a.png"; mkdir -p "$CACHE/preview"
: >"$CACHE/preview/abc.six.4242.tmp"; touch -d '5 minutes ago' "$CACHE/preview/abc.six.4242.tmp"
: >"$CACHE/preview/def.six.4343.tmp"                  # (one being drawn right now: left alone)
kawa-wallpaper --warm
[[ ! -e $CACHE/preview/abc.six.4242.tmp ]] && _ok || _no "the half-made preview stayed"
[[ -e $CACHE/preview/def.six.4343.tmp ]] && _ok || _no "a preview being drawn was removed"

done_
