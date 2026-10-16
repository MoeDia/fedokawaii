#!/usr/bin/env bash
# tests/look/test_wallpaper.sh — kawa-wallpaper: each theme's own wallpaper, drawn at every
# monitor's exact size; the picker; the pack fetched from GitHub. ImageMagick is the real one
# (the pictures are checked to the pixel); swaybg, the monitors (wlr-randr), fzf, the
# picker's window and curl are stand-ins — nothing is ever downloaded.
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
art() {   # art FILE — a 640×360 pack picture: a one-pixel black-and-white checkerboard
  mkdir -p "$(dirname "$1")"
  magick -size 640x360 pattern:gray50 "PNG24:$1"
}
px() { magick "$1" -format "%[pixel:p{$2,$3}]" info: 2>/dev/null; }
photo() { mkdir -p "$(dirname "$1")"; magick -size 64x40 gradient:red-blue "$1"; }   # photo FILE

# ── --restore: the theme's choice, every monitor at its size ───────────────────
setup
case_ "first login, no pack: the drawn Fuji, made at the monitor's exact size"
rc 0 kawa-wallpaper --restore
args_eq swaybg 1 -c '#0f0e0c' -o '*' -i "$SHARE/dark/pattern.png" -m tile \
  -o DP-1 -i "$CACHE/default-dark-1920x1080.png" -m fill
eq "$(size_of "$CACHE/default-dark-1920x1080.png")" 1920x1080
eq "$(running)" 1 "one swaybg"

case_ "two monitors of different sizes, one turned, one switched off: each its own size"
setup
screens "DP-1 2560x1440@164.998993" "HDMI-A-1 3840x2160@60.000000" "DP-2 1920x1080 turned" "DP-3 1920x1080 off"
rc 0 kawa-wallpaper --restore
a=$(args_of swaybg)
has "$a" $'-o\nDP-1\n-i\n'"$CACHE/default-dark-2560x1440.png"
has "$a" $'-o\nHDMI-A-1\n-i\n'"$CACHE/default-dark-3840x2160.png"
has "$a" $'-o\nDP-2\n-i\n'"$CACHE/default-dark-1080x1920.png" "the turned screen: tall"
lacks "$a" DP-3 "a switched-off monitor is left out"
eq "$(size_of "$CACHE/default-dark-3840x2160.png")" 3840x2160
eq "$(size_of "$CACHE/default-dark-1080x1920.png")" 1080x1920

case_ "a custom mode with no refresh rate, and no wlr-randr at all"
setup
screens "DP-1 1920x1200@none"
kawa-wallpaper --restore
has "$(args_of swaybg)" "default-dark-1920x1200.png"
setup; hide wlr-randr
kawa-wallpaper --restore
args_eq swaybg 1 -c '#0f0e0c' -o '*' -i "$SHARE/dark/pattern.png" -m tile

case_ "with the pack: the theme's default picture, each art pixel a crisp square (1080p ×3, 1440p ×4, 4K ×6)"
setup
art "$PACK/dark/dawn-mart.png"
screens "DP-1 1920x1080" "DP-2 2560x1440" "DP-3 3840x2160" "DP-4 1920x1200"
kawa-wallpaper --restore
a=$(args_of swaybg)
has "$a" $'-o\n*\n-i\n'"$PACK/dark/dawn-mart.png"$'\n-m\nfill'
for s in 1920x1080:3 2560x1440:4 3840x2160:6; do
  f=$CACHE/dark-dawn-mart-${s%:*}.png n=${s#*:}
  eq "$(size_of "$f")" "${s%:*}"
  eq "$(px "$f" $((n - 1)) $((n - 1)))" "$(px "$f" 0 0)" "${s%:*}: an art pixel fills $n × $n"
  [[ $(px "$f" "$n" $((n - 1))) != "$(px "$f" 0 0)" ]] && _ok || _no "${s%:*}: the next art pixel starts at $n"
done
eq "$(size_of "$CACHE/dark-dawn-mart-1920x1200.png")" 1920x1200 "16:10: covered and cut to size"

case_ "the light theme: its own art, ground and choice"
setup
ln -sfn themes/light "$HOME/.config/fedokawaii/current"
kawa-wallpaper --restore
args_eq swaybg 1 -c '#e9e1cb' -o '*' -i "$SHARE/light/pattern.png" -m tile \
  -o DP-1 -i "$CACHE/default-light-1920x1080.png" -m fill
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
kawa-wallpaper --restore; old=$(pgrep -x swaybg)
echo "pack:dawn-mart" >"$STATE/wallpaper-dark"
hide swaybg
out=$(kawa-wallpaper --set fuji 2>&1); r=$?
eq "$r" 1
has "$out" "swaybg"
alive "$old" && _ok || _no "the wallpaper on screen was taken down"
eq "$(cat "$STATE/wallpaper-dark")" "pack:dawn-mart"
rc 1 kawa-wallpaper --restore

# ── --set: a choice, remembered per theme ─────────────────────────────────────
case_ "a pack picture with a pair: both themes get the same place"
setup
art "$PACK/dark/canal-walk-night.png"; art "$PACK/light/canal-walk.png"
rc 0 kawa-wallpaper --set pack:canal-walk-night
eq "$(cat "$STATE/wallpaper-dark")" pack:canal-walk-night
eq "$(cat "$STATE/wallpaper-light")" pack:canal-walk "the light theme: the same canal by day"
art "$PACK/dark/pixel-alley.png"
rc 0 kawa-wallpaper --set pack:pixel-alley
eq "$(cat "$STATE/wallpaper-light")" pack:canal-walk "no pair: the other theme keeps its own"

case_ "your own picture with an odd name: handed to swaybg exactly, remembered exactly"
setup
odd="$WP/my "'"best" it'\''s $(touch pwned) `id` ü日本 العربية -x.png'
photo "$odd"
( cd "$TMP" && kawa-wallpaper --set "$odd" ); r=$?
eq "$r" 0
args_eq swaybg 1 -c '#0f0e0c' -i "$odd" -m fill
eq "$(cat "$STATE/wallpaper-dark")" "$odd"
[[ ! -e $TMP/pwned ]] && _ok || _no "a file name ran as a command"
kawa-wallpaper --restore
args_eq swaybg 2 -c '#0f0e0c' -i "$odd" -m fill

case_ "a name with a line break or a leading dash, set directly: still exact"
setup
nl="$WP/two"$'\n'"lines.png"; photo "$nl"
rc 0 kawa-wallpaper --set "$nl"
args_eq swaybg 1 -c '#0f0e0c' -i "$nl" -m fill
kawa-wallpaper --restore
args_eq swaybg 2 -c '#0f0e0c' -i "$nl" -m fill

case_ "a choice that is gone: --set says no; --restore shows the default but keeps remembering it"
setup
rc 1 kawa-wallpaper --set "$WP/nothing.png"
eq "$(last)" 0 "nothing was drawn"
photo "$WP/later.png"; kawa-wallpaper --set "$WP/later.png"
mv "$WP/later.png" "$TMP/away.png"                 # (on a drive not there yet, or deleted)
rc 0 kawa-wallpaper --restore
args_eq swaybg 2 -c '#0f0e0c' -o '*' -i "$SHARE/dark/pattern.png" -m tile \
  -o DP-1 -i "$CACHE/default-dark-1920x1080.png" -m fill
eq "$(cat "$STATE/wallpaper-dark")" "$WP/later.png" "the choice is still yours"
mv "$TMP/away.png" "$WP/later.png"
kawa-wallpaper --restore
args_eq swaybg 3 -c '#0f0e0c' -i "$WP/later.png" -m fill
echo "pack:retired-one" >"$STATE/wallpaper-dark"
rc 0 kawa-wallpaper --restore
has "$(args_of swaybg 4)" "default-dark-1920x1080.png" "a pack picture no longer there: the default"

case_ "--set by hand with a name relative to the folder you are in: remembered in full"
setup
photo "$WP/rel.png"
( cd "$WP" && kawa-wallpaper --set rel.png ); r=$?
eq "$r" 0
eq "$(cat "$STATE/wallpaper-dark")" "$WP/rel.png" "a full path: --restore at login finds it from any folder"
args_eq swaybg 1 -c '#0f0e0c' -i "$WP/rel.png" -m fill
out=$(kawa-wallpaper --set "$WP/nope.png" 2>&1); r=$?
eq "$r" 1
has "$out" "nope.png" "a choice that is not there is named"

case_ "an empty or garbled state file: the default"
setup
mkdir -p "$STATE"; : >"$STATE/wallpaper-dark"
rc 0 kawa-wallpaper --restore
has "$(args_of swaybg)" "default-dark-1920x1080.png"
printf '\x00\xff garbage' >"$STATE/wallpaper-dark"
rc 0 kawa-wallpaper --restore
has "$(args_of swaybg 2)" "default-dark-1920x1080.png"

case_ "the env file missing (a broken install): the wallpaper still comes up"
setup
rm "$HOME/.config/fedokawaii/env"
err=$(kawa-wallpaper --restore 2>&1); r=$?
eq "$r" 0
eq "$err" ""
has "$(args_of swaybg)" "default-dark-1920x1080.png"

case_ "the art missing (no theme.sh yet): a plain ground, no error"
setup
rm -f "$SHARE"/dark/*.png
rc 0 kawa-wallpaper --restore
args_eq swaybg 1 -c '#0f0e0c'

case_ "HOME with a space: everything still lands where it should"
setup
mkdir -p "$TMP/my home"; cp -a "$HOME/." "$TMP/my home/"; export HOME="$TMP/my home"
SHARE=$HOME/.local/share/fedokawaii CACHE=$HOME/.cache/kawa-wallpaper
rc 0 kawa-wallpaper --restore
args_eq swaybg 1 -c '#0f0e0c' -o '*' -i "$SHARE/dark/pattern.png" -m tile \
  -o DP-1 -i "$CACHE/default-dark-1920x1080.png" -m fill

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
  stub kawa-cell 'echo 9x21'
}
rows() { cat "$TMP/rows"; }
nrows() { wc -l <"$TMP/rows"; }
setup; picker
case_ "nothing but the drawn Fuji: one row"
kawa-wallpaper --tui "$TMP/out"
eq "$(rows)" "default	$ICON_TORII fuji by night (default)"
case_ "one picture of your own: listed after the default"
photo "$WP/only one.png"
kawa-wallpaper --tui "$TMP/out"
eq "$(nrows)" 2
eq "$(sed -n 2p "$TMP/rows")" "$WP/only one.png	$ICON_FOLDER only one.png"
rm "$WP/only one.png"

case_ "the pack and your own: the default first, the drawn Fuji, the pack in list order, then yours"
art "$PACK/dark/dawn-mart.png"; art "$PACK/dark/canal-walk-night.png"; art "$PACK/dark/pixel-alley.png"
art "$PACK/dark/enso.png"; art "$PACK/light/station-street.png"
photo "$WP/b.png"; photo "$WP/a.jpg"; photo "$WP/sub dir/c.webp"
kawa-wallpaper --tui "$TMP/out"
eq "$(sed -n 1p "$TMP/rows")" "default	$ICON_TORII dawn-mart (default)"
eq "$(sed -n 2p "$TMP/rows")" "fuji	$ICON_PICTURE fuji by night (drawn)"
eq "$(cut -f1 "$TMP/rows" | tr '\n' ' ')" "default fuji pack:pixel-alley pack:canal-walk-night pack:enso $WP/a.jpg $WP/b.png $WP/sub dir/c.webp "
has "$(rows)" "$WP/sub dir/c.webp	$ICON_FOLDER sub dir/c.webp"
lacks "$(rows)" station-street "the other theme's pictures are not offered"

case_ "the ◐ marks of the paired pictures stand in one column"
cols=$(grep -F "$ICON_THEME" "$TMP/rows" | cut -f2 | while IFS= read -r l; do p=${l%%"$ICON_THEME"*}; p=$(sed 's/\x1b\[[0-9;]*m//g' <<<"$p"); echo "${#p}"; done | sort -u)
eq "$(wc -l <<<"$cols")" 1 "one column: $cols"
eq "$(grep -cF "$ICON_THEME" "$TMP/rows")" 2 "canal-walk-night and enso have a pair"

case_ "your own pictures with odd names: listed with their full path; tab and line break left out"
setup; picker
for n in "my photo.png" "ü日本 العربية.jpg" "it's \"quoted\".png" '$(touch pwned).png' '`touch pwned2`.png' \
         "-leading.png" "UPPER.PNG" $'tab\there.png' $'new\nline.png' "notes.txt" "no-ext"; do
  photo "$WP/$n" 2>/dev/null || { mkdir -p "$WP"; echo x >"$WP/$n"; }
done
kawa-wallpaper --tui "$TMP/out"
for n in "my photo.png" "ü日本 العربية.jpg" "it's \"quoted\".png" '$(touch pwned).png' '`touch pwned2`.png' "-leading.png" "UPPER.PNG"; do
  has "$(rows)" "$WP/$n	$ICON_FOLDER $n"
done
lacks "$(rows)" "tab"; lacks "$(rows)" "line.png"; lacks "$(rows)" "notes.txt"; lacks "$(rows)" "no-ext"
eq "$(nrows)" 8
[[ ! -e $TMP/pwned && ! -e pwned && ! -e $TMP/pwned2 ]] && _ok || _no "a file name ran as a command"

case_ "1000 pictures of your own: all listed, quickly"
setup; picker
mkdir -p "$WP"; photo "$TMP/one.png"
for i in $(seq -w 1 1000); do ln "$TMP/one.png" "$WP/p$i.png"; done
start=$(date +%s%N)
kawa-wallpaper --tui "$TMP/out"
ms=$(( ($(date +%s%N) - start) / 1000000 ))
eq "$(nrows)" 1001
((ms < 10000)) && _ok || _no "the list took $ms ms"
eq "$(sed -n '1001p' "$TMP/rows" | cut -f1)" "$WP/p1000.png"

case_ "the cursor starts on the current choice"
FZF_PICK=esc kawa-wallpaper --tui "$TMP/out"
echo "$WP/p0500.png" >"$STATE/wallpaper-dark"
kawa-wallpaper --tui "$TMP/out"
has "$(args_of fzf "$(ncalls fzf)")" "start:pos(501)"

case_ "Super+W, Enter on an odd name: set exactly, through the dissolve"
setup; picker
stubf kawa-veil <<'EOF'
while [ "$1" != "--" ]; do shift; done; shift; exec "$@"
EOF
odd="$WP/\$(touch pwned) it's.png"; photo "$odd"
FZF_PICK="$odd" kawa-wallpaper; r=$?
eq "$r" 0
called '^kawa-veil --dissolve --time 520 -- '
args_eq swaybg 1 -c '#0f0e0c' -i "$odd" -m fill
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

case_ "without the transition built: set directly"
setup; picker
photo "$WP/x.png"
FZF_PICK="$WP/x.png" kawa-wallpaper
args_eq swaybg 1 -c '#0f0e0c' -i "$WP/x.png" -m fill

# ── the preview pane ─────────────────────────────────────────────────────────
case_ "a preview: a sixel picture; broken or missing pictures just say 'no preview', quietly"
setup
photo "$WP/ok.png"
out=$(kawa-wallpaper --preview "$WP/ok.png" 2>"$TMP/err")
[[ $out == $'\eP'* ]] && _ok || _no "no sixel came out: ${out:0:40}"
eq "$(cat "$TMP/err")" ""
head -c 200 "$WP/ok.png" >"$WP/cut.png"; echo "not a picture" >"$WP/fake.jpg"
for f in "$WP/cut.png" "$WP/fake.jpg" "$WP/missing.png" pack:not-there ""; do
  out=$(kawa-wallpaper --preview "$f" 2>"$TMP/err")
  eq "$out" "  $ICON_PICTURE no preview" "[$f]"
  eq "$(cat "$TMP/err")" "" "[$f]: nothing on stderr"
done
art "$PACK/dark/enso.png"
out=$(kawa-wallpaper --preview pack:enso 2>/dev/null); [[ $out == $'\eP'* ]] && _ok || _no "no pack preview"
out=$(kawa-wallpaper --preview fuji 2>/dev/null); [[ $out == $'\eP'* ]] && _ok || _no "no fuji preview"
out=$(FZF_PREVIEW_COLUMNS=1 FZF_PREVIEW_LINES=1 kawa-wallpaper --preview fuji 2>"$TMP/err")
eq "$(cat "$TMP/err")" "" "a tiny pane: no error"

case_ "--warm (while the picker is open): every preview drawn ahead; month-old ones cleared"
setup
photo "$WP/a.png"; photo "$WP/b.png"
mkdir -p "$CACHE/preview"; : >"$CACHE/preview/old.six"; touch -d '40 days ago' "$CACHE/preview/old.six"
kawa-wallpaper --warm
eq "$(find "$CACHE/preview" -name '*.six' | wc -l)" 3 "fuji and the two pictures"
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
