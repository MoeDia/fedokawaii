#!/usr/bin/env bash
# tests/look/test_screenshot.sh — kawa-screenshot: Print (a region), Shift+Print (the whole
# screen), Super+Print (a region, then satty). slurp, grim, wl-copy and satty are stand-ins
# that keep what they were given; the notice's thumbnail is drawn by the real ImageMagick.
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"
need magick flock

setup() {
  look
  SHOTS=$HOME/Pictures/Screenshots
  magick -size 300x100 gradient:red-blue "$TMP/shot.png"
  # slurp: a region, or Esc ($TMP/esc), or held at a gate ($TMP/gate.slurp.use)
  argv slurp '[ -e "$FAKE_TMP/gate.slurp.use" ] && { : >"$FAKE_TMP/gate.slurp.in"; while [ ! -e "$FAKE_TMP/gate.slurp" ]; do /bin/sleep 0.02; done; }
[ -e "$FAKE_TMP/esc" ] && exit 1
echo "10,20 300x100"'
  # grim [-g GEOM] FILE|-: the picture (with the call's number after it: every shot differs)
  argv grim 'for a; do out=$a; done
n=$(grep -c "^grim" "$FAKE_TMP/calls.log")
if [ "$out" = - ]; then cat "$FAKE_TMP/shot.png"; printf "%s" "$n"
else { cat "$FAKE_TMP/shot.png"; printf "%s" "$n"; } >"$out"; fi'
  # wl-copy: what reached the clipboard, and whether the shot's lock came with it
  argv wl-copy 'cat >"$FAKE_TMP/clip"; [ -e /proc/$$/fd/9 ] && echo "lock held" >>"$FAKE_TMP/fd9"; exit 0'
  argv satty 'cat >"$FAKE_TMP/satty.in"; [ -e /proc/$$/fd/9 ] && echo "lock held" >>"$FAKE_TMP/fd9"; exit 0'
  argv notify-send
  stub date 'exec /bin/date -d "2026-10-16 09:30:05" "$@"'
  # shellcheck source=/dev/null
  . "$HOME/.config/fedokawaii/icons.sh"
  F=$SHOTS/2026-10-16_09-30-05.png
}
shots() { find "$SHOTS" -type f 2>/dev/null | sort; }

# ── the three keys ───────────────────────────────────────────────────────────
setup
case_ "Print: a region in the theme's vermilion, saved, copied as a picture, a notice with its thumbnail"
rc 0 kawa-screenshot
args_eq slurp 1 -b '#0f0e0c66' -c '#d0583aff' -s '#d0583a22' -w 2
args_eq grim 1 -g "10,20 300x100" "$F"
args_eq wl-copy 1 --type image/png
cmp -s "$TMP/clip" "$F" && _ok || _no "the clipboard does not hold the saved picture"
args_eq notify-send 1 -a desktop -i "$XDG_RUNTIME_DIR/kawa-screenshot-icon.png" "$ICON_CAMERA  Screenshot copied" "2026-10-16_09-30-05.png"
eq "$(size_of "$XDG_RUNTIME_DIR/kawa-screenshot-icon.png")" 64x64 "a square thumbnail"
[[ ! -e $TMP/fd9 ]] && _ok || _no "the clipboard keeps the shot's lock (the next Print would do nothing)"

case_ "the light theme: the selection in its own vermilion"
setup
ln -sfn themes/light "$HOME/.config/fedokawaii/current"
kawa-screenshot region
args_eq slurp 1 -b '#0f0e0c66' -c '#c0462aff' -s '#c0462a22' -w 2

case_ "Shift+Print: the whole screen, no region asked"
setup
rc 0 kawa-screenshot full
eq "$(ncalls slurp)" 0
args_eq grim 1 "$F"
args_eq wl-copy 1 --type image/png

case_ "Super+Print: a region into satty (it saves or copies itself); the keys are free meanwhile"
setup
rc 0 kawa-screenshot edit
args_eq grim 1 -g "10,20 300x100" -
args_eq satty 1 --filename - --output-filename "$F"
head -c 8 "$TMP/satty.in" | od -An -c | grep -q 'P   N   G' && _ok || _no "satty got no picture"
eq "$(ncalls wl-copy)" 0 "no copy of its own (satty's Enter copies)"
[[ ! -e $TMP/fd9 ]] && _ok || _no "satty holds the shot's lock: Print does nothing while it is open"
eq "$(shots)" "" "nothing saved until satty saves"

case_ "Esc in the region picker: nothing saved, copied or shown"
setup; : >"$TMP/esc"
for m in region edit; do rc 0 kawa-screenshot "$m"; done
eq "$(ncalls grim)" 0; eq "$(ncalls notify-send)" 0; eq "$(shots)" ""

case_ "two shots in the same second (and a third): -2, -3, none overwritten"
setup
kawa-screenshot full; kawa-screenshot full; kawa-screenshot region
eq "$(shots | tr '\n' ' ')" "$SHOTS/2026-10-16_09-30-05-2.png $SHOTS/2026-10-16_09-30-05-3.png $F "
[[ $(cat "$F" "$SHOTS"/*-2.png "$SHOTS"/*-3.png | md5sum) != "$(cat "$F" "$F" "$F" | md5sum)" ]] \
  && ! cmp -s "$F" "$SHOTS/2026-10-16_09-30-05-2.png" && _ok || _no "a shot was overwritten"

case_ "Print again while picking a region (a held key): the second does nothing"
setup; : >"$TMP/gate.slurp.use"
kawa-screenshot & first=$!
at_gate slurp || _no "the first never asked for a region"
start=$SECONDS
rc 0 kawa-screenshot; rc 0 kawa-screenshot full
((SECONDS - start < 3)) && _ok || _no "the second waited"
eq "$(ncalls slurp)" 1
open_gate slurp; wait "$first"
eq "$(ncalls grim)" 1

# ── the folder ───────────────────────────────────────────────────────────────
case_ "the Screenshots folder missing: made"
setup
rm -rf "$HOME/Pictures"
rc 0 kawa-screenshot full
[[ -s $F ]] && _ok || _no "not saved"

case_ "a folder with a space and unicode in its name"
setup
d="$HOME/Pictures/my shots 写真"
sed -i "s|^SCREENSHOT_DIR=.*|SCREENSHOT_DIR=\"$d\"|" "$HOME/.config/fedokawaii/env"
rc 0 kawa-screenshot full
[[ -s $d/2026-10-16_09-30-05.png ]] && _ok || _no "not saved in the folder with a space"

case_ "a folder that cannot be made: a notice says so, before any region is asked"
setup
: >"$TMP/afile"
sed -i "s|^SCREENSHOT_DIR=.*|SCREENSHOT_DIR=\"$TMP/afile/Screenshots\"|" "$HOME/.config/fedokawaii/env"
out=$(kawa-screenshot 2>&1); r=$?
eq "$r" 1
eq "$(ncalls slurp)" 0 "no region asked for nothing"
has "$(args_of notify-send)" "not saved"
lacks "$out" "line "
setup; mkdir -p "$SHOTS"
if ro "$SHOTS"; then
  out=$(kawa-screenshot 2>&1); r=$?
  rw "$SHOTS"
  eq "$r" 1 "a read-only folder"
  eq "$(ncalls slurp)" 0
  has "$(args_of notify-send)" "not saved"
fi

# ── missing or failing helpers ───────────────────────────────────────────────
case_ "satty missing: Super+Print still keeps the shot (saved and copied), and says why"
setup
hide satty
rc 0 kawa-screenshot edit
[[ -s $F ]] && _ok || _no "the shot was lost"
args_eq wl-copy 1 --type image/png
has "$(args_of notify-send)" "satty"

case_ "the clipboard helper missing or failing: saved, and the notice says saved, not copied"
setup
hide wl-copy
rc 0 kawa-screenshot full
has "$(args_of notify-send)" "Screenshot saved"
setup
argv wl-copy 'exit 1'
rc 0 kawa-screenshot full
has "$(args_of notify-send)" "Screenshot saved"

case_ "grim failing (no screen to capture): exit 1, a notice, no empty file"
setup
argv grim 'exit 1'
rc 1 kawa-screenshot full
has "$(args_of notify-send)" "Screenshot failed"
eq "$(shots)" ""

case_ "ImageMagick missing: the notice shows the shot itself as its picture"
setup
hide magick
rc 0 kawa-screenshot full
has "$(args_of notify-send)" $'-i\n'"$F"

case_ "an Arabic locale: the file name keeps plain digits"
if command -v localedef >/dev/null && [[ -e /usr/share/i18n/locales/ar_EG ]]; then
  setup; mkdir -p "$TMP/locale"; localedef -i ar_EG -f UTF-8 "$TMP/locale/ar_EG.UTF-8" 2>/dev/null
  stub date 'exec /bin/date -d "2026-10-16 09:30:05" "$@"'
  LOCPATH=$TMP/locale LC_ALL=ar_EG.UTF-8 kawa-screenshot full
  [[ -s $F ]] && _ok || _no "named otherwise: $(shots)"
fi

case_ "no runtime folder: exit 1 with a plain message"
setup
export XDG_RUNTIME_DIR=$TMP/no-such-run
out=$(kawa-screenshot full 2>&1); r=$?
eq "$r" 1; has "$out" "kawa-screenshot:"; lacks "$out" "line "

case_ "--help, and a wrong mode"
setup
out=$(kawa-screenshot --help 2>&1); r=$?
eq "$r" 0; has "$out" "kawa-screenshot [region|full|edit]"
eq "$(ncalls grim)" 0 "--help takes no shot"
out=$(kawa-screenshot window 2>&1); r=$?
eq "$r" 2; has "$out" "usage: kawa-screenshot"
eq "$(ncalls slurp)$(ncalls grim)" 00

done_
