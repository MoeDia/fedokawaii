#!/usr/bin/env bash
# tests/content/test_clip.sh — kawa-clip (Super+V) against a stand-in clipboard history that
# answers as cliphist 0.7 does (fake_cliphist.py): text with newlines, tabs and leading
# dashes, a huge copy, pictures of every kind Go reads, binary data, a broken picture, an
# empty history, and wl-copy or cliphist missing. fzf and the window are stand-ins; the
# previews are drawn for real (ImageMagick, kawa-sixel) and read back pixel by pixel.
. "$(dirname "$0")/lib.sh"

setup() {   # setup — a fresh sandbox, an empty history, the window's parts as stand-ins
  sandbox
  export CLIP_DB=$TMP/clip COPIED=$TMP/copied FZF_ARGS=$TMP/fzf.args FZF_IN=$TMP/fzf.in FZF_ENV=$TMP/fzf.env
  mkdir -p "$CLIP_DB"
  stub cliphist "exec python3 -I '$C/fake_cliphist.py' \"\$@\""
  stub wl-copy 'cat >"$COPIED"'
  stub setsid '[ "$1" = -f ] && shift; exec "$@"'
  stub kawa-float; stub kawa-cell 'echo 9x21'
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

# ── the list ─────────────────────────────────────────────────────────────────
setup
put 'line one\n\tline two\twith tab\nline three'
put -- '-rf --no-preserve-root /'
put '日本語 العربية $(touch %s/pwned) `id`' "$TMP"
magick -size 640x480 xc:'#5f7fa0' png:- | python3 -I "$C/fake_cliphist.py" store
magick -size 64x32 xc:'#5f7fa0' jpg:- | python3 -I "$C/fake_cliphist.py" store
binary | python3 -I "$C/fake_cliphist.py" store
out=$(kawa-clip --list)
case_ "the list: newest first, each row its cliphist id, a tab, and what it shows"
eq "$(cut -f1 <<<"$out" | tr '\n' ' ')" "6 5 4 3 2 1 "
has "$out" $'1\tline one line two with tab line three' "newlines and tabs read as spaces"
has "$out" $'2\t-rf --no-preserve-root /' "a leading dash is just text"
has "$out" $'3\t日本語 العربية $(touch '"$TMP"'/pwned) `id`'
[[ ! -e $TMP/pwned ]] && _ok || _no "a copied \$(…) ran"
case_ "pictures are named: kind, size in pixels and bytes"
has "$out" $'4\t'"$ICON_PICTURE png picture  640×480  ·  "
has "$out" $'5\t'"$ICON_PICTURE jpeg picture  64×32  ·  "
case_ "binary data that is not a picture: a row of its own, named"
eq "$(grep $'^6\t' <<<"$out")" $'6\t'"$ICON_BOX_OFF data  ·  not text"

case_ "an escape in a copy (colour codes, a clear-screen): shown as ^[, never acted on"
setup
put 'red \033[31mtext\033[0m, a clear \033[2J and a bell \a'
out=$(kawa-clip --list)
lacks "$out" $'\e' "an escape in the list (fzf --ansi would act on it)"
has "$out" $'1\tred ^[[31mtext^[[0m, a clear ^[[2J and a bell \a' "(other control characters: fzf shows them as ^G)"
case_ "bytes that are not text (cliphist shows them as �): a 'data' row, not the scrambling bytes"
binary | python3 -I "$C/fake_cliphist.py" store
eq "$(kawa-clip --list | grep $'^2\t')" $'2\t'"$ICON_BOX_OFF data  ·  not text"
case_ "an escape in a text's preview: shown as ^[; tabs and lines kept; Windows line ends quiet"
eq "$(prev 1)" $'  red ^[[31mtext^[[0m, a clear ^[[2J and a bell \a'
put 'one\r\ntwo\tcolumns\r\n'
eq "$(prev 3)" $'  one\n  two\tcolumns'

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
eq "$(prev 1)" $'  line one\n  \tline two\twith tab\n  line three'
put -- '--version'
eq "$(prev 2)" '  --version' "a leading dash is shown, not taken as an option"

case_ "a huge copy: the first 64 KiB, two columns in"
python3 -c 'print("x" * 300000, end="")' | python3 -I "$C/fake_cliphist.py" store
id=$(newest); out=$(prev "$id")
eq "${#out}" $((65536 + 2))

case_ "code, mail and keys are text too (not 'application/…, N bytes')"
put 'const fs = require("fs");\nfunction f(a) { return a + 1; }\nmodule.exports = f;\n'
has "$(prev "$(newest)")" '  const fs = require("fs");' "JavaScript"
put 'From: a@example.com\nTo: b@example.com\nSubject: hi\n\nbody\n'
has "$(prev "$(newest)")" '  Subject: hi' "an e-mail"
put -- '-----BEGIN PGP PUBLIC KEY BLOCK-----\nmQENBF\n-----END PGP PUBLIC KEY BLOCK-----\n'
has "$(prev "$(newest)")" '  -----BEGIN PGP PUBLIC KEY BLOCK-----' "a PGP key"
put '{"a": [1, 2]}'
eq "$(prev "$(newest)")" '  {"a": [1, 2]}' "JSON"

case_ "binary data: its kind and size, not its bytes"
binary | python3 -I "$C/fake_cliphist.py" store
eq "$(prev "$(newest)")" "  $ICON_BOX_OFF application/octet-stream, 3000 bytes"
head -c 100 /dev/zero | python3 -I "$C/fake_cliphist.py" store
eq "$(prev "$(newest)")" "  $ICON_BOX_OFF application/octet-stream, 100 bytes" "zero bytes"

case_ "no XDG_RUNTIME_DIR (a shell outside the session): the preview and the copy still work"
eq "$(env -u XDG_RUNTIME_DIR FZF_PREVIEW_COLUMNS=74 FZF_PREVIEW_LINES=9 kawa-clip --preview 1 2>&1)" $'  line one\n  \tline two\twith tab\n  line three'
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
[[ $out == *$'\e'Pq* || $out == *$'\e'P0\;1\;* || $out == "  $ICON_PICTURE picture (png)" ]] && _ok \
  || _no "neither a picture nor its kind: ${out:0:80}"
printf 'GIF89a\x10\x00\x10\x00garbage' | python3 -I "$C/fake_cliphist.py" store
eq "$(prev "$(newest)" 2>&1)" "  $ICON_PICTURE picture (gif)" "a header and nothing after it"

case_ "a preview too short or too narrow for a picture: its kind in words"
eq "$(LINES_=2 prev 1 2>&1)" "  $ICON_PICTURE picture (png)"
eq "$(COLS=0 prev 1 2>&1)" "  $ICON_PICTURE picture (png)"
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
eq "$(prev 1 2>/dev/null)" "  $ICON_PICTURE picture (png)"

case_ "a preview killed half-way (fzf kills one when you move on): its copy does not stay in memory"
setup
magick -size 640x480 xc:'#5f7fa0' png:- | python3 -I "$C/fake_cliphist.py" store
stub magick 'sleep 30'
/usr/bin/setsid kawa-clip --preview 1 >/dev/null 2>&1 & pg=$!
for _ in {1..50}; do (($(count "$XDG_RUNTIME_DIR"/kawa-clip.*))) && break; sleep 0.05; done
kill -KILL -- -"$pg" 2>/dev/null; wait "$pg" 2>/dev/null
left=$(count "$XDG_RUNTIME_DIR"/kawa-clip.*)
eq "$left" 1 "(the test itself: a leftover to clean)"
kawa-clip --tui
eq "$(count "$XDG_RUNTIME_DIR"/kawa-clip.*)" 0 "the next window clears what killed previews left"

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
has "$out" "forget all 2 entries?"; eq "$(kawa-clip --list | wc -l)" 2
python3 -I "$C/pty_run.py" --answer '[y/N] ' '\r' -- kawa-clip --wipe >/dev/null
eq "$(kawa-clip --list | wc -l)" 2 "Enter (any other key) keeps them"
python3 -I "$C/pty_run.py" --answer '[y/N] ' 'Y' -- kawa-clip --wipe >/dev/null
eq "$(kawa-clip --list | wc -l)" 0
case_ "ctrl+x with nothing to forget: no question"
out=$(python3 -I "$C/pty_run.py" -- kawa-clip --wipe); r=$?
eq "$r" 0; lacks "$out" "forget"
case_ "ctrl+x without a terminal to ask in: nothing forgotten"
put 'one'
/usr/bin/setsid -w kawa-clip --wipe </dev/null >/dev/null 2>&1
eq "$(kawa-clip --list | wc -l)" 1

# ── the window ───────────────────────────────────────────────────────────────
case_ "Super+V: the floating window, once"
setup; reset_calls
kawa-clip
called "^kawa-float --once clipboard clipboard 76x25 -- $REPO/bin/kawa-clip --tui\$"

case_ "inside: fzf with the desktop's options file, the list, the cell size for the previews"
setup; put 'one'; put 'two'
export FZF_DEFAULT_OPTS='--bogus'; stub kawa-cell 'echo 18x42'
kawa-clip --tui; unset FZF_DEFAULT_OPTS
eq "$(cat "$FZF_IN")" "$(kawa-clip --list)"
has "$(cat "$FZF_ENV")" "FZF_DEFAULT_OPTS_FILE=$HOME/.config/fedokawaii/fzf.opts"
lacks "$(cat "$FZF_ENV")" "FZF_DEFAULT_OPTS=" "a FZF_DEFAULT_OPTS of the user's own is not mixed in"
has "$(cat "$FZF_ENV")" "KAWA_CELL=18x42"
has "$(cat "$FZF_ARGS")" "newest first"
case_ "inside: the cell size unknown → foot's 9×21"
stub kawa-cell 'exit 1'; kawa-clip --tui
has "$(cat "$FZF_ENV")" "KAWA_CELL=9x21"
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
eq "$(sh -c "${pcmd//\{1\}/1}" 2>&1)" "  hello there" "the preview, run as fzf runs it (sh -c)"
eq "$(bash -c "${pcmd//\{1\}/1}" 2>&1)" "  hello there" "and with bash as \$SHELL"
ccmd=$(grep -F -- "--bind=enter:become(" "$FZF_ARGS"); ccmd=${ccmd#--bind=enter:become(}; ccmd=${ccmd%)}
sh -c "${ccmd//\{1\}/1}"; eq "$(cat "$COPIED")" "hello there" "enter, run as fzf runs it"

case_ "a held Super+V (20 presses): one window, one list"
setup; put 'one'
stub kawa-float; rm -f "$STUBS/kawa-float"       # the real one, its terminal a slow stand-in
stub footclient 'while [ "$1" != -- ]; do shift; done; shift; sleep 1; exec "$@"'
for _ in {1..20}; do kawa-clip & done; wait
eq "$(grep -c '^footclient' "$CALLS")" 1 "footclient started once"
eq "$(grep -c '^fzf' "$CALLS")" 1

case_ "misuse and help"
setup
rc 2 kawa-clip --bogus; rc 2 kawa-clip list
has "$(kawa-clip --bogus 2>&1)" "usage: kawa-clip"
rc 0 kawa-clip --help; has "$(kawa-clip --help)" "Super+V"

done_
