#!/usr/bin/env bash
# tests/content/test_clip.sh — kawa-clip (Super+V) against a stand-in clipboard history that
# answers as cliphist 0.7 does (fake_cliphist.py): text with newlines, tabs and leading
# dashes, a huge copy, pictures of every kind Go reads, binary data, a broken picture, an
# empty history, and wl-copy or cliphist missing; and what is kept of each copy (--store,
# behind wl-paste --watch): a screenshot, Brave's "Copy image", spreadsheet cells, a secret,
# copies too big, the hundredth. fzf, wl-paste and the window are stand-ins; the previews are
# drawn for real (ImageMagick, kawa-sixel) and read back pixel by pixel.
. "$(dirname "$0")/lib.sh"

setup() {   # setup — a fresh sandbox, an empty history, the window's parts as stand-ins
  sandbox
  export CLIP_DB=$TMP/clip COPIED=$TMP/copied FZF_ARGS=$TMP/fzf.args FZF_IN=$TMP/fzf.in FZF_ENV=$TMP/fzf.env
  mkdir -p "$CLIP_DB"
  stub cliphist "exec python3 -I '$C/fake_cliphist.py' \"\$@\""
  stub wl-copy 'cat >"$COPIED"'
  stub setsid '[ "$1" = -f ] && shift; exec "$@"'
  stub kawa-term; stub kawa-cell 'echo 9x21'
  # fzf: what it was given (one argument per line, its list, its environment)
  stub fzf 'for a; do printf "%s\n" "$a"; done >"$FZF_ARGS"; cat >"$FZF_IN"; env >"$FZF_ENV"'
}
put() { printf "$@" | python3 -I "$C/fake_cliphist.py" store; }      # put FORMAT ARG… — a new copy
newest() { ls "$CLIP_DB" | sort -n | tail -n1; }
# 3000 bytes of binary data that `file` calls just that (random bytes are, now and then, a
# TGA picture or a DOS program to it)
binary() { python3 -I -c 'import sys; sys.stdout.buffer.write((bytes(range(255, -1, -1)) * 12)[:3000])'; }
prev() { FZF_PREVIEW_COLUMNS=${COLS:-74} FZF_PREVIEW_LINES=${LINES_:-9} KAWA_CELL=9x21 kawa-clip --preview "$@"; }
. "$HOME/.config/fedokawaii/icons.sh" 2>/dev/null || . "$REPO/configs/home/.config/fedokawaii/icons.sh"
# rows LIST — the list's rows as words: its own inks (screen.sh's: 38;5;N and the reset) out, the
# row's indent and glyph out (checked on their own), its padding as two spaces — "ID<tab>name  value"
rows() { sed -e $'s/\e\\[38;5;[0-9]*m//g; s/\e\\[0m//g' -e $'s/\t  [^ ]*  /\t/; s/   */  /g'; }

# ── the list ─────────────────────────────────────────────────────────────────
setup
put 'line one\n\tline two\twith tab\nline three'
put -- '-rf --no-preserve-root /'
put '日本語 العربية $(touch %s/pwned) `id`' "$TMP"
magick -size 640x480 xc:'#5f7fa0' png:- | python3 -I "$C/fake_cliphist.py" store
magick -size 64x32 xc:'#5f7fa0' jpg:- | python3 -I "$C/fake_cliphist.py" store
binary | python3 -I "$C/fake_cliphist.py" store
raw=$(kawa-clip --list); out=$(rows <<<"$raw")
case_ "the list: newest first, each row its cliphist id, a tab, and what it shows"
eq "$(cut -f1 <<<"$out" | tr '\n' ' ')" "6 5 4 3 2 1 "
case_ "a row as every text screen's (screen.sh): two spaces, the glyph in muted, two spaces, the name; a value right-aligned at the window's 76th column, muted"
eq "$(grep $'^4\t' <<<"$raw" | cut -f2 | sed -e $'s/\e\\[[0-9;]*m//g' | LC_ALL=C.UTF-8 wc -L)" 76
has "$raw" $'4\t  \e[38;5;21m'"$ICON_PICTURE"$'\e[0m  png picture  '
has "$raw" $'3\t  \e[38;5;21m'"$ICON_CLIPBOARD"$'\e[0m  日本語'
eq "$(FZF_COLUMNS=60 kawa-clip --list | grep $'^4\t' | cut -f2 | sed -e $'s/\e\\[[0-9;]*m//g' | LC_ALL=C.UTF-8 wc -L)" 58 "a reload: fzf's width less a column each side"
has "$out" $'1\tline one line two with tab line three' "newlines and tabs read as spaces"
has "$out" $'2\t-rf --no-preserve-root /' "a leading dash is just text"
has "$out" $'3\t日本語 العربية $(touch '"$TMP"'/pwned) `id`'
[[ ! -e $TMP/pwned ]] && _ok || _no "a copied \$(…) ran"
case_ "pictures are named: kind, size in pixels and bytes"
has "$out" $'4\tpng picture  640×480 · '
has "$out" $'5\tjpeg picture  64×32 · '
case_ "binary data that is not a picture: a row of its own, named"
eq "$(grep $'^6\t' <<<"$out")" $'6\tdata  not text'
has "$raw" $'6\t  \e[38;5;21m'"$ICON_BOX_OFF"

case_ "an escape in a copy (colour codes, a clear-screen): shown as ^[, never acted on"
setup
put 'red \033[31mtext\033[0m, a clear \033[2J and a bell \a'
out=$(kawa-clip --list | rows)
lacks "$out" $'\e' "an escape in the list (fzf --ansi would act on it)"
has "$out" $'1\tred ^[[31mtext^[[0m, a clear ^[[2J and a bell \a' "(other control characters: fzf shows them as ^G)"
case_ "bytes that are not text (cliphist shows them as �): a 'data' row, not the scrambling bytes"
binary | python3 -I "$C/fake_cliphist.py" store
eq "$(kawa-clip --list | rows | grep $'^2\t')" $'2\tdata  not text'
case_ "an escape in a text's preview: shown as ^[; tabs and lines kept; Windows line ends quiet"
eq "$(prev 1)" $'   red ^[[31mtext^[[0m, a clear ^[[2J and a bell \a'
put 'one\r\ntwo\tcolumns\r\n'
eq "$(prev 3)" $'   one\n   two\tcolumns'

case_ "an empty history: no rows, no error"
setup
eq "$(kawa-clip --list 2>&1)" ""; rc 0 kawa-clip --list

case_ "cliphist missing: no rows, no error"
setup
eq "$(PATH=$(without cliphist) kawa-clip --list 2>&1)" ""

# ── the preview: text ────────────────────────────────────────────────────────
case_ "text: the whole of it, two columns in, tabs and lines kept"
setup
put 'line one\n\tline two\twith tab\nline three'
eq "$(prev 1)" $'   line one\n   \tline two\twith tab\n   line three'
put -- '--version'
eq "$(prev 2)" '   --version' "a leading dash is shown, not taken as an option"

case_ "a huge copy: the first 64 KiB, three columns in (the list's glyphs' column)"
python3 -c 'print("x" * 300000, end="")' | python3 -I "$C/fake_cliphist.py" store
id=$(newest); out=$(prev "$id")
eq "${#out}" $((65536 + 3))

case_ "code, mail and keys are text too (not 'application/…, N bytes')"
put 'const fs = require("fs");\nfunction f(a) { return a + 1; }\nmodule.exports = f;\n'
has "$(prev "$(newest)")" '   const fs = require("fs");' "JavaScript"
put 'From: a@example.com\nTo: b@example.com\nSubject: hi\n\nbody\n'
has "$(prev "$(newest)")" '   Subject: hi' "an e-mail"
put -- '-----BEGIN PGP PUBLIC KEY BLOCK-----\nmQENBF\n-----END PGP PUBLIC KEY BLOCK-----\n'
has "$(prev "$(newest)")" '   -----BEGIN PGP PUBLIC KEY BLOCK-----' "a PGP key"
put '{"a": [1, 2]}'
eq "$(prev "$(newest)")" '   {"a": [1, 2]}' "JSON"

case_ "binary data: its kind and size, not its bytes"
binary | python3 -I "$C/fake_cliphist.py" store
eq "$(prev "$(newest)")" "   $ICON_BOX_OFF  application/octet-stream, 3000 bytes"
head -c 100 /dev/zero | python3 -I "$C/fake_cliphist.py" store
eq "$(prev "$(newest)")" "   $ICON_BOX_OFF  application/octet-stream, 100 bytes" "zero bytes"

case_ "no XDG_RUNTIME_DIR (a shell outside the session): the preview and the copy still work"
eq "$(env -u XDG_RUNTIME_DIR FZF_PREVIEW_COLUMNS=74 FZF_PREVIEW_LINES=9 kawa-clip --preview 1 2>&1)" $'   line one\n   \tline two\twith tab\n   line three'
rc 0 env -u XDG_RUNTIME_DIR kawa-clip --copy 1

case_ "the preview of an id that is not there (forgotten meanwhile), or not an id: nothing"
eq "$(prev 999 2>&1)" ""; eq "$(prev '1;touch x' 2>&1)" ""; eq "$(prev '' 2>&1)" ""
rc 0 prev 999

# ── the preview: pictures ────────────────────────────────────────────────────
# the area: 74 columns × (9 − 2) lines of 9×21 px = 666 × 147; one line of ground above it
case_ "a picture: scaled to fit, centred to the pixel, a line of ground above, nothing drawn on the ground"
setup
magick -size 640x480 xc:'#5f7fa0' png:- | python3 -I "$C/fake_cliphist.py" store
info=$(prev 1 | sixel_info)
eq "$(jget p2 <<<"$info")" 1 "unset pixels must stay unset (the terminal's own ground shows)"
eq "$(jget raster <<<"$info")" "[1, 1, 666, 168]"
eq "$(jget bbox <<<"$info")" "[235, 21, 431, 168]" "196×147: 235 px each side, the area's full height"
eq "$(jget ends_with_band_break <<<"$info")" False "no empty band under it"
eq "$(jrepr after <<<"$info")" "'\\n'" "the cursor on the line under it"

case_ "a small picture is never enlarged; odd margins trimmed by a row, never resampled"
magick -size 64x32 xc:'#d0583a' png:- | python3 -I "$C/fake_cliphist.py" store
info=$(prev 2 | sixel_info)
eq "$(jget bbox <<<"$info")" "[301, 79, 365, 110]" "64×31, 301 px each side, 58 above and below"
eq "$(jget drawn <<<"$info")" $((64 * 31))

case_ "a 1×1 picture: one pixel, in the middle"
magick -size 1x1 xc:'#d0583a' png:- | python3 -I "$C/fake_cliphist.py" store
info=$(prev 3 | sixel_info)
eq "$(jget drawn <<<"$info")" 1; eq "$(jget bbox <<<"$info")" "[332, 94, 333, 95]"

case_ "a huge picture (3000×2000) and a very tall one (800×16000): scaled into the area"
magick -size 3000x2000 xc:'#7fb8b0' png:- | python3 -I "$C/fake_cliphist.py" store
eq "$(prev 4 | sixel_info | jget bbox)" "[223, 21, 443, 168]" "220×147"
magick -size 800x16000 xc:'#7fb8b0' png:- | python3 -I "$C/fake_cliphist.py" store
eq "$(prev 5 | sixel_info | jget bbox)" "[330, 21, 336, 168]" "7 × 147, trimmed to 6 so the margins match"

case_ "the other kinds cliphist names: JPEG, GIF (its first frame), BMP"
magick -size 64x32 xc:'#d0583a' jpg:- | python3 -I "$C/fake_cliphist.py" store
has "$(prev 6 | sixel_info | jget raster)" "666, 168"
magick -size 64x32 xc:'#d0583a' xc:'#5f7fa0' -loop 0 gif:- | python3 -I "$C/fake_cliphist.py" store
has "$(prev 7 | sixel_info | jget colours)" "82,35,23" "the first frame's colour"
lacks "$(prev 7 | sixel_info | jget colours)" "37,50,63" "not the second frame's"
magick -size 64x32 xc:'#d0583a' bmp:- | python3 -I "$C/fake_cliphist.py" store
has "$(prev 8 | sixel_info | jget raster)" "666, 168"

case_ "a broken picture (cut short): its kind in words, nothing on stderr"
magick -size 640x480 plasma: png:- 2>/dev/null | head -c 300 | python3 -I "$C/fake_cliphist.py" store
id=$(newest); err=$(prev "$id" 2>&1 >/dev/null); out=$(prev "$id" 2>/dev/null)
eq "$err" "" "an fzf preview shows stderr"
[[ $out == *$'\e'Pq* || $out == *$'\e'P0\;1\;* || $out == "   $ICON_PICTURE  picture (png)" ]] && _ok \
  || _no "neither a picture nor its kind: ${out:0:80}"
printf 'GIF89a\x10\x00\x10\x00garbage' | python3 -I "$C/fake_cliphist.py" store
eq "$(prev "$(newest)" 2>&1)" "   $ICON_PICTURE  picture (gif)" "a header and nothing after it"

case_ "a preview too short or too narrow for a picture: its kind in words"
eq "$(LINES_=2 prev 1 2>&1)" "   $ICON_PICTURE  picture (png)"
eq "$(COLS=0 prev 1 2>&1)" "   $ICON_PICTURE  picture (png)"
has "$(COLS=1 prev 1 | sixel_info | jget raster)" "[1, 1, 9, 168]" "one column: a picture one column wide"

case_ "Turkish and Arabic locales: the list and the picture as in English, no stray files"
want_l=$(kawa-clip --list); want_p=$(prev 1)
mkdir -p "$TMP/cwd"
for l in tr_TR ar_EG; do
  if locale_of $l; then
    eq "$(cd "$TMP/cwd" && LC_ALL=$LOC kawa-clip --list)" "$want_l" "$l: the list"
    eq "$(cd "$TMP/cwd" && LC_ALL=$LOC prev 1)" "$want_p" "$l: the picture"
  else skip "no $l.UTF-8 locale"; fi
done
eq "$(ls -A "$TMP/cwd")" "" "a file left in the folder it ran in"
unset LOCPATH

case_ "kawa-sixel failing: the kind in words, never its error"
stub kawa-sixel 'cat >/dev/null; echo "kawa-sixel: boom" >&2; exit 1'
eq "$(prev 1 2>/dev/null)" "   $ICON_PICTURE  picture (png)"

case_ "a preview killed half-way (fzf kills one when you move on): its copy does not stay in memory"
setup
magick -size 640x480 xc:'#5f7fa0' png:- | python3 -I "$C/fake_cliphist.py" store
stub magick 'sleep 30'
KAWA_CELL=9x21 /usr/bin/setsid kawa-clip --preview 1 >/dev/null 2>&1 & pg=$!
for _ in {1..50}; do (($(count "$XDG_RUNTIME_DIR"/kawa-clip.*))) && break; sleep 0.05; done
kill -KILL -- -"$pg" 2>/dev/null; wait "$pg" 2>/dev/null
left=$(count "$XDG_RUNTIME_DIR"/kawa-clip.*)
eq "$left" 1 "(the test itself: a leftover to clean)"
kawa-clip --tui
eq "$(count "$XDG_RUNTIME_DIR"/kawa-clip.*)" 0 "the next window clears what killed previews left"

# ── what is kept: --store, behind wl-paste --watch ───────────────────────────
# offer TYPE… — the copy on the clipboard is offered in these types (wl-paste --list-types);
# each one's bytes are $TMP/offer/TYPE (/ as _). store [STATE] — wl-paste --watch's call:
# what it chose on stdin (from $TMP/stdin), CLIPBOARD_STATE as given (data by default)
offer() { printf '%s\n' "$@" >"$TMP/types"; }
bytes() { mkdir -p "$TMP/offer"; cat >"$TMP/offer/${1//\//_}"; }
store() { CLIPBOARD_STATE=${1:-data} kawa-clip --store <"$TMP/stdin"; }
store_setup() {
  setup
  stub wl-paste 'case $1 in --list-types) cat "$TMP/types" ;; --no-newline) [ "$2" = --type ] && t=$(printf %s "$3" | tr / _) && cat "$TMP/offer/$t" ;; esac'
}
newest_bytes() { cat "$CLIP_DB/$(newest)"; }

case_ "a screenshot (a picture and nothing else): kept as the picture, named in the list"
store_setup
magick -size 1920x1080 xc:'#d0583a' png:- >"$TMP/shot.png"
offer image/png; bytes image/png <"$TMP/shot.png"; cp "$TMP/shot.png" "$TMP/stdin"
rc 0 store
cmp -s "$CLIP_DB/1" "$TMP/shot.png" && _ok || _no "the screenshot's bytes changed on the way"
has "$(kawa-clip --list | rows)" $'1\tpng picture  1920×1080 · '
has "$(prev 1 | sixel_info | jget raster)" "666, 168" "previewed as a sixel"

case_ "Brave's Copy image (the picture, its <img> tag and its link — wl-paste hands over the link): the picture"
store_setup
magick -size 640x480 xc:'#7fb8b0' png:- >"$TMP/cat.png"
offer text/html image/png text/plain 'text/plain;charset=utf-8'
bytes image/png <"$TMP/cat.png"; printf 'https://example.com/cat.png\n' >"$TMP/stdin"
rc 0 store
cmp -s "$(ls -d "$CLIP_DB"/* | sort -V | tail -n1)" "$TMP/cat.png" && _ok || _no "not the picture: $(kawa-clip --list)"
eq "$(ls "$CLIP_DB" | wc -l)" 1 "one entry: the picture, not its link beside it"
called '^wl-paste --no-newline --type image/png$'
case_ "… its link a data: URL, or no plain text offered at all (only the <img> tag): the picture too"
printf 'data:image/png;base64,iVBORw0KGgo=' >"$TMP/stdin"; magick -size 20x10 xc:'#d0583a' png:- | bytes image/png
store; eq "$(file -b --mime-type "$CLIP_DB/$(newest)")" image/png
offer text/html image/png; printf '<img src="https://example.com/a.png">' >"$TMP/stdin"
magick -size 30x10 xc:'#d0583a' png:- | bytes image/png
store; eq "$(file -b --mime-type "$CLIP_DB/$(newest)")" image/png
case_ "… PNG when the picture is offered in several kinds; else the first kind offered"
offer image/bmp image/png; magick -size 40x10 xc:'#5f7fa0' bmp:- | bytes image/bmp; magick -size 40x10 xc:'#5f7fa0' png:- | bytes image/png
: >"$TMP/stdin"; reset_calls; store; called '^wl-paste --no-newline --type image/png$'
offer image/jpeg image/bmp; magick -size 50x10 xc:'#5f7fa0' jpg:- | bytes image/jpeg
reset_calls; store; called '^wl-paste --no-newline --type image/jpeg$'
eq "$(file -b --mime-type "$CLIP_DB/$(newest)")" image/jpeg

case_ "text that comes with a picture of itself (cells from a spreadsheet, a paragraph): the text"
store_setup
offer 'text/plain;charset=utf-8' text/html image/png image/bmp
magick -size 64x32 xc:'#d0583a' png:- | bytes image/png
printf 'name\tamount\nrent\t4500\n' >"$TMP/stdin"
rc 0 store
eq "$(newest_bytes)" $'name\tamount\nrent\t4500'
not_called '^wl-paste --no-newline'
case_ "… and two links, or a sentence with a link in it, are text too"
printf 'https://a.example\nhttps://b.example\n' >"$TMP/stdin"; store
eq "$(newest_bytes)" $'https://a.example\nhttps://b.example'
printf 'the cat: https://example.com/cat.png' >"$TMP/stdin"; store
eq "$(newest_bytes)" 'the cat: https://example.com/cat.png'
case_ "plain text, no picture: kept as it came, byte for byte"
offer 'text/plain;charset=utf-8' text/plain UTF8_STRING
printf -- '-n\ttab \\ $(id)\n' >"$TMP/stdin"; store
eq "$(od -c <"$CLIP_DB/$(newest)")" "$(printf -- '-n\ttab \\ $(id)\n' | od -c)"

case_ "a copy marked secret (a password manager's): not kept, nothing asked of the clipboard"
store_setup; offer 'text/plain;charset=utf-8' x-kde-passwordManagerHint; printf 'hunter2' >"$TMP/stdin"
rc 0 store sensitive
eq "$(ls "$CLIP_DB" | wc -l)" 0; not_called '^wl-paste'
case_ "the clipboard cleared by its program: the newest entry goes, as cliphist does it"
offer 'text/plain;charset=utf-8'; printf 'one' >"$TMP/stdin"; store; printf 'two' >"$TMP/stdin"; store
: >"$TMP/stdin"; store clear
eq "$(newest_bytes)" one
case_ "a copy kawa-clipkeep offers again (its program closed): stored when it was made, not twice"
store_setup; offer 'text/plain;charset=utf-8' application/x-kawa-clipkeep; printf 'kept' >"$TMP/stdin"
rc 0 store; eq "$(ls "$CLIP_DB" | wc -l)" 0

case_ "a copy bigger than 20 MiB is not kept — up to 20 MiB is, text or picture"
store_setup
offer image/png; head -c $((20 << 20)) /dev/zero | bytes image/png; : >"$TMP/stdin"
store; eq "$(stat -c %s "$CLIP_DB/1" 2>&1)" $((20 << 20))
head -c $((20 << 20 + 1)) /dev/zero | bytes image/png; store
eq "$(ls "$CLIP_DB" | wc -l)" 1 "a picture one byte over"
offer 'text/plain;charset=utf-8'; python3 -c 'print("x" * (20 * 1024 * 1024 + 1), end="")' >"$TMP/stdin"; store
eq "$(ls "$CLIP_DB" | wc -l)" 1 "text one byte over"

case_ "the history keeps the newest 100 (cliphist is told so at every copy)"
store_setup; offer 'text/plain;charset=utf-8'
for i in $(seq 1 105); do printf 'copy %d' "$i" >"$TMP/stdin"; store; done
eq "$(kawa-clip --list | wc -l)" 100
eq "$(kawa-clip --list | rows | head -n1 | cut -f2)" "copy 105"; eq "$(kawa-clip --list | rows | tail -n1 | cut -f2)" "copy 6"
has "$(cat "$CLIP_DB.log")" "-max-items 100 store"

case_ "nothing left behind in the runtime folder"
eq "$(count "$XDG_RUNTIME_DIR"/kawa-clip-store.*)" 0

# ── copy, forget, forget all ─────────────────────────────────────────────────
case_ "enter: the entry back on the clipboard, byte for byte, by a wl-copy of its own"
setup
put -- '-n\ttab\nnewline \\ backslash'
rc 0 kawa-clip --copy 1
called '^setsid -f wl-copy'
eq "$(od -c <"$COPIED")" "$(printf -- '-n\ttab\nnewline \\ backslash' | od -c)"
magick -size 64x32 xc:'#d0583a' png:- | tee "$TMP/pic.png" | python3 -I "$C/fake_cliphist.py" store
rc 0 kawa-clip --copy 2
cmp -s "$COPIED" "$TMP/pic.png" && _ok || _no "the picture's bytes changed on the way"
case_ "enter on a picture: offered as the picture it is (image/png, image/jpeg) — text as wl-copy finds it"
called '^wl-copy --type image/png$'; called '^wl-copy $'
magick -size 64x32 xc:'#d0583a' jpg:- | python3 -I "$C/fake_cliphist.py" store
reset_calls; rc 0 kawa-clip --copy 3; called '^wl-copy --type image/jpeg$'

case_ "copy of an entry that is gone, or not an id: fails, the clipboard untouched"
setup; reset_calls
rc 1 kawa-clip --copy 7; rc 1 kawa-clip --copy ''; rc 1 kawa-clip --copy '1 2'
not_called wl-copy

case_ "wl-copy missing: fails with a notice naming it, nothing half-done"
setup; put 'hello'
rc 1 env PATH="$(without wl-copy)" kawa-clip --copy 1
called 'notify-send -a desktop .*wl-copy'

case_ "ctrl+d: that entry forgotten, the others kept; a wrong id forgets nothing"
setup; put 'one'; put 'two'; put 'three'
rc 0 kawa-clip --delete 2
eq "$(kawa-clip --list | cut -f1 | tr '\n' ' ')" "3 1 "
rc 0 kawa-clip --delete 'x'; rc 0 kawa-clip --delete ''
eq "$(kawa-clip --list | wc -l)" 2

case_ "ctrl+x: asks first — y forgets them all, anything else keeps them"
setup; put 'one'; put 'two'
out=$(python3 -I "$C/pty_run.py" --answer '[y/N] ' 'n' -- kawa-clip --wipe)
has "$out" "forget all 2 entries, and empty the clipboard?"; eq "$(kawa-clip --list | wc -l)" 2
python3 -I "$C/pty_run.py" --answer '[y/N] ' '\r' -- kawa-clip --wipe >/dev/null
eq "$(kawa-clip --list | wc -l)" 2 "Enter (any other key) keeps them"
python3 -I "$C/pty_run.py" --answer '[y/N] ' 'Y' -- kawa-clip --wipe >/dev/null
eq "$(kawa-clip --list | wc -l)" 0
called "^wl-copy --clear$"
case_ "ctrl+x with nothing to forget: no question"
out=$(python3 -I "$C/pty_run.py" -- kawa-clip --wipe); r=$?
eq "$r" 0; lacks "$out" "forget"
case_ "ctrl+x without a terminal to ask in: nothing forgotten"
put 'one'
/usr/bin/setsid -w kawa-clip --wipe </dev/null >/dev/null 2>&1
eq "$(kawa-clip --list | wc -l)" 1

# ── the window ───────────────────────────────────────────────────────────────
case_ "Super+V's own command (kawa-clip): the warm window shown or put away — kawa-warm's toggle (the window itself: kawa-warm runs --tui in it)"
setup; reset_calls; stub kawa-warm
kawa-clip
called "^kawa-warm clip\$"; not_called '^fzf'
grep -q 'clip) *title=clipboard size=80x27 *cmd=(kawa-clip --tui)' "$REPO/bin/kawa-warm" && _ok || _no "kawa-warm's clipboard window is not 80×27 on --tui"

case_ "inside: fzf with the desktop's options file, the list, the cell size for the previews"
setup; put 'one'; put 'two'
export FZF_DEFAULT_OPTS='--bogus'; stub kawa-cell 'echo 18x42'
kawa-clip --tui; unset FZF_DEFAULT_OPTS
eq "$(cat "$FZF_IN")" "$(kawa-clip --list)"
has "$(cat "$FZF_ENV")" "FZF_DEFAULT_OPTS_FILE=$HOME/.config/fedokawaii/fzf.opts"
lacks "$(cat "$FZF_ENV")" "FZF_DEFAULT_OPTS=" "a FZF_DEFAULT_OPTS of the user's own is not mixed in"
has "$(cat "$FZF_ENV")" "KAWA_CELL=18x42"
has "$(cat "$FZF_ARGS")" "newest first"
case_ "inside: the terminal does not say its cell size → the window ends (no guessed size)"
stub kawa-cell 'exit 1'; rm -f "$FZF_ENV"; rc 1 kawa-clip --tui; [[ ! -e $FZF_ENV ]] && _ok || _no "fzf ran with a guessed cell"
case_ "inside, nothing copied yet: the title says so"
setup; kawa-clip --tui
has "$(cat "$FZF_ARGS")" "nothing copied yet"
case_ "inside, cliphist missing: the title says that instead"
PATH=$(without cliphist) kawa-clip --tui
has "$(cat "$FZF_ARGS")" "cliphist is missing"

case_ "a home with a space, an accent and a quote: every key's command still finds the script"
setup; odd_home kawa-clip
put 'hello there'
"$HOME/.local/bin/kawa-clip" --tui
for key in "--preview=" "--bind=enter:become(" "--bind=ctrl-d:execute-silent("; do
  line=$(grep -F -- "$key" "$FZF_ARGS")
  [[ -n $line ]] && _ok || _no "no $key"
done
pcmd=$(grep -F -- "--preview=" "$FZF_ARGS"); pcmd=${pcmd#--preview=}
eq "$(sh -c "${pcmd//\{1\}/1}" 2>&1)" "   hello there" "the preview, run as fzf runs it (sh -c)"
eq "$(bash -c "${pcmd//\{1\}/1}" 2>&1)" "   hello there" "and with bash as \$SHELL"
ccmd=$(grep -F -- "--bind=enter:become(" "$FZF_ARGS"); ccmd=${ccmd#--bind=enter:become(}; ccmd=${ccmd%)}
sh -c "${ccmd//\{1\}/1}"; eq "$(cat "$COPIED")" "hello there" "enter, run as fzf runs it"

# ── Super+Z on an entry: the cursor's entry kept while the window is open ────
# (the window's fzf a stand-in that waits for $TMP/close; the bindings run as fzf runs them)
cur() { cat "$XDG_RUNTIME_DIR/kawa-clip.current" 2>/dev/null; }
open_window() {   # open_window [setsid] — kawa-clip --tui in the background, WIN its pid
  rm -f "$TMP/close" "$FZF_ARGS"
  stub fzf 'for a; do printf "%s\n" "$a"; done >"$FZF_ARGS"; cat >/dev/null; while [ ! -e "$TMP/close" ]; do sleep 0.05; done'
  : >"$XDG_RUNTIME_DIR/kawa-warm-clip.shown"    # (shown: kawa-warm --shown's mark)
  "$@" kawa-clip --tui 2>/dev/null & WIN=$!     # (bash says "Hangup" of a hung-up fzf)
  on_exit "touch '$TMP/close' 2>/dev/null; kill $WIN 2>/dev/null"
  for _ in {1..100}; do [[ -s $FZF_ARGS && -n $(cur) ]] && break; sleep 0.05; done
}
bind() {          # bind EVENT ID [VAR=VALUE…] — run that binding's command as fzf would ({1}: ID)
  local c; c=$(grep -F -- "--bind=$1:" "$FZF_ARGS"); c=${c#--bind=$1:execute-silent(}
  c=${c%%)+execute-silent(*}; c=${c%)}                 # (the first command)
  env "${@:3}" sh -c "${c//\{1\}/$2}"
}
case_ "the window open: the file says so — its pid, nothing under the cursor yet"
setup; put 'one'; put 'two'; put 'three'
open_window
eq "$(cur)" "$WIN "
rc 0 kawa-clip --held; eq "$(kawa-clip --held)" ""
case_ "… the warm window put away (kawa-warm --hidden took its mark): no window for Super+Z"
rm "$XDG_RUNTIME_DIR/kawa-warm-clip.shown"; rc 1 kawa-clip --held; : >"$XDG_RUNTIME_DIR/kawa-warm-clip.shown"
case_ "… the cursor moved (fzf's focus event): that entry, for Super+Z (kawa-clip --held)"
bind focus 2 >/dev/null 2>&1
eq "$(cur)" "$WIN 2"; eq "$(kawa-clip --held)" 2
case_ "… a new result (a search, a reload — the cursor on another entry in the same place): that one"
bind result 3 FZF_MATCH_COUNT=3 >/dev/null 2>&1
eq "$(kawa-clip --held)" 3
case_ "… the search matching nothing (fzf runs no {1} command then): no entry under the cursor"
c=$(grep -F -- "--bind=result:" "$FZF_ARGS"); c=${c#*+execute-silent(}; c=${c%)}
FZF_MATCH_COUNT=0 sh -c "$c"; eq "$(cur)" "$WIN "
FZF_MATCH_COUNT=0 bash -c "$c"; eq "$(cur)" "$WIN " "(with bash as \$SHELL)"
bind focus 1 >/dev/null 2>&1; FZF_MATCH_COUNT=2 sh -c "$c"; eq "$(kawa-clip --held)" 1 "matches: left as it is"
case_ "… fzf listens on its socket, for the history's reload"
has "$(cat "$FZF_ARGS")" "--listen=$XDG_RUNTIME_DIR/kawa-clip.sock"
has "$(cat "$FZF_ARGS")" "super+z shrink" "the footer names the key"
case_ "a new copy while it is open (--store): the window's list reloaded, the cursor on the newest"
stub curl
store_setup_keep() { stub wl-paste 'case $1 in --list-types) echo "text/plain;charset=utf-8" ;; esac'; }
store_setup_keep; printf 'four' | CLIPBOARD_STATE=data kawa-clip --store
called "^curl .*--unix-socket $XDG_RUNTIME_DIR/kawa-clip.sock --data-binary reload\\($REPO/bin/kawa-clip --list\\)\\+first http://localhost/\$"
eq "$(kawa-clip --list | rows | head -n1 | cut -f2)" four
case_ "Esc: the window's file goes with it; then there is no window (--held: exit 1)"
touch "$TMP/close"; wait "$WIN"
[[ ! -e $XDG_RUNTIME_DIR/kawa-clip.current ]] && _ok || _no "the file stayed: $(cur)"
rc 1 kawa-clip --held
case_ "… and a copy then pokes nothing"
reset_calls; printf 'five' | CLIPBOARD_STATE=data kawa-clip --store; not_called '^curl'
case_ "closed from outside (dwl hangs up its process group): the file goes too"
open_window /usr/bin/setsid
eq "$(cur)" "$WIN "
kill -HUP -- "-$WIN"; { wait "$WIN"; } 2>/dev/null
[[ ! -e $XDG_RUNTIME_DIR/kawa-clip.current ]] && _ok || _no "the file stayed: $(cur)"
case_ "a file left by a window killed outright (its pid gone, or now another program's): no window"
sh -c 'exit 0' & dead=$!; wait "$dead"
printf '%s 1\n' "$dead" >"$XDG_RUNTIME_DIR/kawa-clip.current"; rc 1 kawa-clip --held
sleep 30 & other=$!; on_exit "kill $other 2>/dev/null"
printf '%s 1\n' "$other" >"$XDG_RUNTIME_DIR/kawa-clip.current"; rc 1 kawa-clip --held
reset_calls; printf 'six' | CLIPBOARD_STATE=data kawa-clip --store; not_called '^curl'
kill "$other" 2>/dev/null
case_ "… nor do odd lines in it count: --focus takes a pid and an id, nothing else"
rc 0 kawa-clip --focus 'x' 1; rc 0 kawa-clip --focus "$$" '1;touch x'
eq "$(cur)" "$other 1" "unchanged"

if [[ -z $REAL_FZF ]] || ! command -v curl >/dev/null; then
  skip "no fzf or curl here: the window's events are not run for real"
else
  case_ "for real (fzf $("$REAL_FZF" --version | cut -d' ' -f1)): the cursor followed, a new copy shown on top and under it, the file gone when it closes"
  setup; put 'one'; put 'two'; put 'three'
  config .config/fedokawaii/fzf.opts; stub fzf "exec '$REAL_FZF' \"\$@\""; : >"$XDG_RUNTIME_DIR/kawa-warm-clip.shown"
  # ↓ twice (the list is newest first): entry 1; then a copy comes; the window is hung up at 6 s
  python3 -I "$C/pty_run.py" --cols 80 --rows 27 --send 1.5 '\x1b[B' --send 2 '\x1b[B' --hangup 6 -- kawa-clip --tui >/dev/null 2>&1 &
  pty=$!; on_exit "kill $pty 2>/dev/null"
  for _ in {1..60}; do [[ $(kawa-clip --held 2>/dev/null) == 1 ]] && break; sleep 0.05; done
  eq "$(kawa-clip --held)" 1 "the cursor two down, on the oldest"
  store_setup_keep; printf 'four' | CLIPBOARD_STATE=data kawa-clip --store
  for _ in {1..60}; do [[ $(kawa-clip --held 2>/dev/null) == 4 ]] && break; sleep 0.05; done
  eq "$(kawa-clip --held)" 4 "the new copy, on top, under the cursor"
  wait "$pty"
  [[ ! -e $XDG_RUNTIME_DIR/kawa-clip.current && ! -e $XDG_RUNTIME_DIR/kawa-clip.sock ]] && _ok || _no "left: $(ls "$XDG_RUNTIME_DIR")"
fi

case_ "misuse and help"
setup
rc 2 kawa-clip --bogus; rc 2 kawa-clip list
has "$(kawa-clip --bogus 2>&1)" "usage: kawa-clip"
rc 0 kawa-clip --help; has "$(kawa-clip --help)" "Super+V"

done_
