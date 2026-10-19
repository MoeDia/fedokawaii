#!/usr/bin/env bash
# tests/content/test_shrink.sh — kawa-shrink (Super+Z, Alt+S in yazi) with the real ImageMagick
# and Ghostscript: pictures under a size (email, chat, one you type) and no larger than the
# screen they are for, turned into JPEG, WebP or PNG; PDFs made smaller; the result beside the
# original and on the clipboard. The clipboard is a stand-in (one item: its type in $CB.type,
# its bytes in $CB.data) and the menu one that answers $PICK (a row's words) or $SIZE. With the
# clipboard history open (Super+V), the history is a stand-in (fake_cliphist.py) and so is
# the window's fzf; kawa-clip itself is real.
. "$(dirname "$0")/../lib/harness.sh"
command -v magick >/dev/null && command -v gs >/dev/null || { printf '  – skipped: needs magick and gs\n'; done_; exit; }

setup() {
  sandbox
  config .config/fedokawaii/icons.sh
  export CB=$TMP/clipboard XDG_RUNTIME_DIR=$TMP/run; mkdir -m 700 -p "$XDG_RUNTIME_DIR"
  # (WATCH set: then what the session's wl-paste --watch does — the copy into the history)
  stub wl-copy 'if [ "$1" = --clear ]; then rm -f "$CB.type" "$CB.data"; exit 0; fi
t=text/plain; [ "$1" = --type ] && t=$2; cat >"$CB.data.w"; mv -f "$CB.data.w" "$CB.data"; printf %s "$t" >"$CB.type.w"; mv -f "$CB.type.w" "$CB.type"
[ -n "$WATCH" ] && CLIPBOARD_STATE=data kawa-clip --store <"$CB.data"'
  stub wl-paste 'case "$1" in
  --list-types) [ -e "$CB.type" ] && cat "$CB.type" && echo ;;
  --no-newline) [ "$3" = "$(cat "$CB.type" 2>/dev/null)" ] && cat "$CB.data" || exit 1 ;;
esac'
  # the menu: the row holding $PICK (its number, with --index), or $SIZE typed; Esc: no PICK
  stub kawa-menu 'rows=$(cat); echo "$*" >>"$TMP/menu.args"
[ -n "$MENU_HOOK" ] && sh -c "$MENU_HOOK"
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
shrink() { PICK=$1 SIZE=${SIZE:-} MENU_HOOK=${MENU_HOOK:-} kawa-shrink "${@:2}"; }

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
called 'notify-send .*tiny\.pdf · on the clipboard.* · 1 no smaller than it was: the original'
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

# ── an entry of the clipboard history (Super+V open: Super+Z is dwl's, so it comes here) ──
# hist_setup — a history of its own; open_window — Super+V's window: the real kawa-clip --tui,
# its fzf a stand-in that waits for $TMP/close; cursor ID — the cursor moved onto entry ID (what
# fzf's focus binding runs); close_window — Esc
hist_setup() {
  setup
  export CLIP_DB=$TMP/clip; mkdir -p "$CLIP_DB"
  stub cliphist "exec python3 -I '$REPO/tests/content/fake_cliphist.py' \"\$@\""
  stub kawa-cell 'echo 9x21'; stub curl
  stub fzf 'cat >/dev/null; while [ ! -e "$TMP/close" ]; do sleep 0.05; done'
}
put() { python3 -I "$REPO/tests/content/fake_cliphist.py" store; }     # stdin → a new entry
newest() { ls "$CLIP_DB" | sort -n | tail -n1; }
open_window() {
  rm -f "$TMP/close"; kawa-clip --tui & WIN=$!
  on_exit "touch '$TMP/close' 2>/dev/null; kill $WIN 2>/dev/null"
  for _ in {1..100}; do [[ -s $XDG_RUNTIME_DIR/kawa-clip.current ]] && break; sleep 0.05; done
}
cursor() { kawa-clip --focus "$WIN" "$1"; }
close_window() { touch "$TMP/close"; wait "$WIN" 2>/dev/null; }
until_newest_is() {   # until_newest_is FILE — wait for the watcher's copy of FILE in the history
  local _; for _ in {1..100}; do cmp -s "$CLIP_DB/$(newest)" "$1" && return 0; sleep 0.05; done; return 1
}

case_ "Super+V open, the cursor on a picture: that one is shrunk — not what the clipboard holds"
hist_setup
put <"$A/screen.png"; printf 'some words' | put          # 1: the picture, 2: text
wl-copy --type image/jpeg <"$A/beach.jpg"                  # (the clipboard: another picture)
open_window; cursor 1
rc 0 shrink "chat · under 500 KB"
has "$(cat "$TMP/menu.args")" "--title 1 picture · $(awk -v b="$(size "$A/screen.png")" 'BEGIN { if (b < 1000000) printf "%d KB", b / 1000 + 0.5; else printf "%.1f MB", b / 1000000 }')"
f=$(ls "$HOME/Pictures" 2>/dev/null)
[[ $f =~ ^copied\ [0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9.]{8}\ \(chat\)\.jpg$ ]] && _ok || _no "in ~/Pictures: [$f]"
eq "$(dims "$HOME/Pictures/$f")" "1200 900" "the screenshot's size (the beach photo is 3200×2400, and 1600 at most after)"
eq "$(cat "$CB.type")" image/jpeg; cmp -s "$CB.data" "$HOME/Pictures/$f" && _ok || _no "the clipboard holds something else"
close_window

case_ "… converted again, and again (a result of Super+Z is a picture like any other): a new file each time"
hist_setup; WATCH=1; export WATCH
put <"$A/screen.png"
open_window; cursor 1
rc 0 shrink "chat · under 500 KB"; r1=$HOME/Pictures/$(ls "$HOME/Pictures" | head -n1)
until_newest_is "$r1" && _ok || _no "the result is not in the history"
for _ in {1..40}; do grep -q '^curl ' "$CALLS" && break; sleep 0.05; done   # (the watcher, then the window poked)
called "^curl .*--unix-socket $XDG_RUNTIME_DIR/kawa-clip.sock .*reload\\(.*kawa-clip --list\\)\\+first"
cursor "$(newest)"                                           # (fzf: reload, the cursor on the top one)
rc 0 shrink "as WebP"
r2=$(ls "$HOME/Pictures"/*.webp 2>/dev/null); [[ -s $r2 ]] && _ok || _no "no WebP: $(ls "$HOME/Pictures" | tr '\n' '|')"
eq "$(file -b --mime-type "$r2")" image/webp; eq "$(cat "$CB.type")" image/webp
until_newest_is "$r2" && _ok || _no "the WebP is not in the history"
cursor "$(newest)"
rc 0 shrink "chat · under 500 KB"
eq "$(ls "$HOME/Pictures" | wc -l)" 3 "three results, none over another: $(ls "$HOME/Pictures" | tr '\n' '|')"
r3=$(ls -t "$HOME/Pictures" | head -n1); eq "$(file -b --mime-type "$HOME/Pictures/$r3")" image/jpeg
cmp -s "$CB.data" "$HOME/Pictures/$r3" && _ok || _no "the third is not on the clipboard"
case_ "… the same choice twice on the same entry: two files, the second numbered"
cursor 1; rc 0 shrink "as PNG"; rc 0 shrink "as PNG"
eq "$(ls "$HOME/Pictures" | grep -c '\.png$')" 2
unset WATCH; close_window

case_ "Super+V open, the cursor on text: nothing to shrink — even with a picture on the clipboard"
hist_setup
printf 'just words' | put; wl-copy --type image/png <"$A/screen.png"
open_window; cursor 1
shrink "chat"; eq "$?" 1
called 'notify-send .*nothing to shrink.*the entry under the cursor'; [[ ! -e $TMP/menu.args ]] && _ok || _no "a menu opened"
eq "$(ls "$HOME/Pictures" 2>/dev/null)" ""
case_ "… the search matching nothing (no cursor), or an entry forgotten meanwhile: the same"
kawa-clip --focus "$WIN"; shrink "chat"; eq "$?" 1
cursor 99; shrink "chat"; eq "$?" 1
not_called 'kawa-menu'
close_window

case_ "Super+V open, the cursor on files copied in yazi (their file:// links): those files"
hist_setup
printf 'file://%s\r\n' "$(sed 's/ /%20/g' <<<"$A/screen.png")" | put
open_window; cursor 1
rc 0 shrink "as WebP"; [[ -s $A/screen.webp ]] && _ok || _no "not done: $(ls "$A" | tr '\n' '|')"
close_window

case_ "the window closed while the menu is up (dwl, or Esc): the entry taken before still is the one"
hist_setup
put <"$A/screen.png"; open_window; cursor 1
MENU_HOOK='touch "$TMP/close"; sleep 0.3' rc 0 shrink "as JPEG"
wait "$WIN" 2>/dev/null
[[ ! -e $XDG_RUNTIME_DIR/kawa-clip.current ]] && _ok || _no "the window's file stayed"
eq "$(ls "$HOME/Pictures" | grep -c '\.jpg$')" 1

case_ "a window gone without a word (killed: its file left): ignored — the clipboard it is"
hist_setup
printf 'just words' | put; wl-copy --type image/png <"$A/screen.png"
sh -c 'exit 0' & dead=$!; wait "$dead"
printf '%s 1\n' "$dead" >"$XDG_RUNTIME_DIR/kawa-clip.current"
rc 1 kawa-clip --held
rc 0 shrink "as WebP"; eq "$(ls "$HOME/Pictures" | grep -c '^copied .*\.webp$')" 1 "the clipboard's picture, as WebP"
case_ "… its pid now another program's: ignored too"
sleep 30 & other=$!; on_exit "kill $other 2>/dev/null"
printf '%s 1\n' "$other" >"$XDG_RUNTIME_DIR/kawa-clip.current"
rc 1 kawa-clip --held; rc 0 shrink "as PNG"
kill "$other" 2>/dev/null

case_ "its keys: Super+Z (dwl), Alt+S in yazi"
has "$(cat "$REPO/src/dwl/config.h")" 'XKB_KEY_z,                 spawn,            SHCMD("kawa-shrink")'
has "$(cat "$REPO/configs/home/.config/yazi/keymap.toml")" 'on = "<A-s>",      run = "shell --orphan -- kawa-shrink %s"'
done_
