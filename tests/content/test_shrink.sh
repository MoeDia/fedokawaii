#!/usr/bin/env bash
# tests/content/test_shrink.sh — kawa-shrink (Super+Z, Alt+S in yazi) with the real ImageMagick
# and Ghostscript: pictures under a size (email, chat, one you type) and no larger than the
# screen they are for, turned into JPEG, WebP or PNG; PDFs made smaller; the result beside the
# original and on the clipboard. The clipboard is a stand-in (one item: its type in $CB.type,
# its bytes in $CB.data) and the menu one that answers $PICK (a row's words) or $SIZE.
. "$(dirname "$0")/../lib/harness.sh"
command -v magick >/dev/null && command -v gs >/dev/null || { printf '  – skipped: needs magick and gs\n'; done_; exit; }

setup() {
  sandbox
  config .config/fedokawaii/icons.sh
  export CB=$TMP/clipboard XDG_RUNTIME_DIR=$TMP/run; mkdir -m 700 -p "$XDG_RUNTIME_DIR"
  stub wl-copy 'if [ "$1" = --clear ]; then rm -f "$CB.type" "$CB.data"; exit 0; fi
t=text/plain; [ "$1" = --type ] && t=$2; cat >"$CB.data.w"; mv -f "$CB.data.w" "$CB.data"; printf %s "$t" >"$CB.type.w"; mv -f "$CB.type.w" "$CB.type"'
  stub wl-paste 'case "$1" in
  --list-types) [ -e "$CB.type" ] && cat "$CB.type" && echo ;;
  --no-newline) [ "$3" = "$(cat "$CB.type" 2>/dev/null)" ] && cat "$CB.data" || exit 1 ;;
esac'
  # the menu: the row holding $PICK (its number, with --index), or $SIZE typed; Esc: no PICK
  stub kawa-menu 'rows=$(cat); echo "$*" >>"$TMP/menu.args"
case " $* " in *" --index "*) [ -n "$PICK" ] || exit 1
  printf "%s\n" "$rows" | grep -nF -- "$PICK" | head -n1 | cut -d: -f1 | awk "{ print \$1 - 1 }" ;;
*) [ -n "$SIZE" ] || exit 1; echo "$SIZE" ;; esac'
  A=$TMP/photos; mkdir -p "$A"
  # a 3200×2400 photo: noise, as a camera's (it does not compress), with words of where in it
  magick -size 3200x2400 plasma:fractal -attenuate 0.4 +noise Gaussian -set comment "taken at home, 25.2N 55.3E" \
    -quality 97 "$A/beach.jpg" 2>/dev/null
  magick -size 1200x900 plasma: "$A/screen.png"
}
size() { stat -c %s -- "$1"; }
dims() { magick "$1[0]" -format '%w %h' info:; }
shrink() { PICK=$1 SIZE=${SIZE:-} kawa-shrink "${@:2}"; }

case_ "email: a JPEG under 1 MB, no larger than 2560 px, beside the photo — and on the clipboard as itself"
setup
rc 0 shrink "email · under 1 MB" "$A/beach.jpg"
r="$A/beach (email).jpg"
[[ -s $r ]] && _ok || _no "no $r: $(ls "$A" | tr '\n' '|')"
(($(size "$r") <= 1000000)) && _ok || _no "$(size "$r") bytes"
read -r w h <<<"$(dims "$r")"; ((w <= 2560 && h <= 2560 && w > 2000)) && _ok || _no "${w}×$h"
eq "$(cat "$CB.type")" image/jpeg; cmp -s "$CB.data" "$r" && _ok || _no "the clipboard holds something else"
called '^notify-send -a desktop .* MB → [0-9]+ KB beach \(email\)\.jpg · on the clipboard \(Ctrl\+V\)'
eq "$(magick "$r" -format '%c' info: 2>/dev/null)" "" "where it was taken went with the metadata"
has "$(magick "$A/beach.jpg" -format '%c' info: 2>/dev/null)" "25.2N" "(the photo itself has it)"
[[ -s $A/beach.jpg ]] && _ok || _no "the original is gone"
case_ "the menu: what it holds and how big, then only what fits it (pictures: no PDF rows)"
has "$(cat "$TMP/menu.args")" "--title 1 picture · "
case_ "chat: under 500 KB, no larger than 1600 px; again: (1), nothing overwritten"
rc 0 shrink "chat · under 500 KB" "$A/beach.jpg"; rc 0 shrink "chat · under 500 KB" "$A/beach.jpg"
(($(size "$A/beach (chat).jpg") <= 500000)) && _ok || _no "$(size "$A/beach (chat).jpg") bytes"
read -r w h <<<"$(dims "$A/beach (chat).jpg")"; ((w <= 1600 && h <= 1600)) && _ok || _no "${w}×$h"
[[ -s "$A/beach (chat) (1).jpg" ]] && _ok || _no "the second went over the first"
case_ "a size of your own: typed (150 KB) — under it, even if the picture must get smaller"
SIZE="150 KB" rc 0 shrink "a size of your own" "$A/beach.jpg"
r="$A/beach (under 150 KB).jpg"; (($(size "$r") <= 150000)) && _ok || _no "$(size "$r" 2>&1) bytes"
for s in 1.5mb "2 MB" 300 "750 kb"; do
  SIZE=$s rc 0 shrink "a size of your own" "$A/screen.png"
done
ls "$A" | grep -q 'screen (under 1.5 MB).jpg' && _ok || _no "1.5mb not read: $(ls "$A" | tr '\n' '|')"
ls "$A" | grep -q 'screen (under 300 KB).jpg' && _ok || _no "300 (KB) not read"
case_ "a size that is no size: said, nothing made"
SIZE="small please" shrink "a size of your own" "$A/screen.png"; eq "$?" 1
called 'notify-send .*not a size: small please'
case_ "as WebP · as JPEG · as PNG: the same picture, that kind, beside it"
setup
rc 0 shrink "as WebP" "$A/screen.png"; eq "$(file -b --mime-type "$A/screen.webp")" image/webp
eq "$(dims "$A/screen.webp")" "1200 900" "the same size"
eq "$(cat "$CB.type")" image/webp
rc 0 shrink "as JPEG" "$A/screen.png"; eq "$(file -b --mime-type "$A/screen.jpg")" image/jpeg
rc 0 shrink "as PNG" "$A/beach.jpg"; eq "$(file -b --mime-type "$A/beach.png")" image/png
rc 0 shrink "as JPEG" "$A/beach.jpg"; [[ -s "$A/beach (1).jpg" ]] && _ok || _no "a JPEG as JPEG: not beside it"
case_ "two pictures: both done, the clipboard holds them as files (text/uri-list)"
setup
rc 0 shrink "chat · under 500 KB" "$A/beach.jpg" "$A/screen.png"
eq "$(cat "$CB.type")" text/uri-list
has "$(cat "$CB.data")" "file://$A/beach%20%28chat%29.jpg"; has "$(cat "$CB.data")" "file://$A/screen%20%28chat%29.jpg"
not_called 'notify-send .*files copied' "kawa-clipfiles said so too"
called 'notify-send .*beach \(chat\)\.jpg and 1 more'

case_ "a PDF full of pictures: email makes it smaller, beside it"
setup
magick "$A/beach.jpg" -units PixelsPerInch -density 300 -quality 95 "$A/scan.pdf"   # (a 300 dpi scan)
rc 0 shrink "PDF · email" "$A/scan.pdf"
r="$A/scan (email).pdf"; [[ -s $r ]] && _ok || _no "no $r"
(($(size "$r") < $(size "$A/scan.pdf") / 2)) && _ok || _no "$(size "$A/scan.pdf") → $(size "$r")"
eq "$(file -b --mime-type "$r")" application/pdf
eq "$(cat "$CB.type")" text/uri-list; has "$(cat "$CB.data")" "file://$A/scan%20%28email%29.pdf"
case_ "a PDF that would come out no smaller: left as it is, and that one on the clipboard"
magick -size 200x100 xc:white "$A/tiny.pdf"
rc 0 shrink "PDF · smallest" "$A/tiny.pdf"
[[ ! -e "$A/tiny (smallest).pdf" ]] && _ok || _no "a larger copy kept"
has "$(cat "$CB.data")" "file://$A/tiny.pdf"
case_ "a PDF and a picture together: each its own rows"
rc 0 shrink "PDF · print" "$A/scan.pdf" "$A/beach.jpg"
m=$(tail -n1 "$TMP/menu.args"); has "$m" "1 picture, 1 PDF"

# ── what was copied ────────────────────────────────────────────────────────────────────
case_ "files copied in yazi (Ctrl+C): those"
setup
kawa-clipfiles copy "$A/screen.png"
rc 0 shrink "as WebP"; [[ -s $A/screen.webp ]] && _ok || _no "not done"
case_ "a picture copied (a screenshot, an image in Brave): the result kept in ~/Pictures"
setup
wl-copy --type image/png <"$A/screen.png"
rc 0 shrink "chat · under 500 KB"
f=$(ls "$HOME/Pictures" 2>/dev/null)
[[ $f =~ ^copied\ [0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9.]{8}\ \(chat\)\.jpg$ ]] && _ok || _no "in ~/Pictures: [$f]"
eq "$(cat "$CB.type")" image/jpeg
case_ "nothing copied, text, or a file that is neither: said, no menu, exit 1"
setup; shrink "chat"; eq "$?" 1; called 'notify-send .*nothing to shrink'; [[ ! -e $TMP/menu.args ]] && _ok || _no "a menu opened"
printf 'hello' | wl-copy; shrink "chat"; eq "$?" 1
echo text >"$A/a.txt"; shrink "chat" "$A/a.txt"; eq "$?" 1
case_ "Esc in the menu: nothing made, exit 0"
setup; rc 0 shrink "" "$A/screen.png"; eq "$(ls "$A" | wc -l)" 2
case_ "wrong use: exit 2"
rc 2 kawa-shrink --bogus

case_ "its keys: Super+Z (dwl), Alt+S in yazi"
has "$(cat "$REPO/src/dwl/config.h")" 'XKB_KEY_z,                 spawn,            SHCMD("kawa-shrink")'
has "$(cat "$REPO/configs/home/.config/yazi/keymap.toml")" 'on = "<A-s>",      run = "shell --orphan -- kawa-shrink %s"'
done_
