#!/usr/bin/env bash
# tests/content/test_sixel.sh — the two picture helpers the books, clipboard and wallpaper
# windows draw with: kawa-sixel (a picture → a sixel, its ground left undrawn) read back
# pixel by pixel (sixel.py), and kawa-cell (the terminal's cell size) in a terminal of its
# own (pty_run.py) that answers, answers late, answers nonsense or never answers.
. "$(dirname "$0")/lib.sh"
sandbox
pic() { magick "$@" png:- 2>/dev/null; }                    # pic ARG… — a PNG on stdout
cell() { python3 -I "$C/pty_run.py" --timeout 5 "$@"; }     # cell [--answer Q R] [--delay S] -- CMD

# ── kawa-sixel ───────────────────────────────────────────────────────────────
case_ "a picture: one sixel, exactly its own size, unset pixels left unset, nothing around it"
info=$(pic -size 20x13 xc:'#d0583a' | kawa-sixel 0f0e0c | sixel_info)
eq "$(jget p2 <<<"$info")" 1
eq "$(jget raster <<<"$info")" "[1, 1, 20, 13]"
eq "$(jget bbox <<<"$info")" "[0, 0, 20, 13]"
eq "$(jget ends_with_band_break <<<"$info")" False "a band break at the end draws an empty band under it"
eq "$(jrepr before <<<"$info")$(jrepr after <<<"$info")" "''''"

case_ "the ground colour is not drawn (the terminal's own shows): dark and light"
info=$(pic -size 20x13 xc:'#0f0e0c' -fill '#d0583a' -draw 'rectangle 5,3 14,9' | kawa-sixel 0f0e0c | sixel_info)
eq "$(jget bbox <<<"$info")" "[5, 3, 15, 10]"; eq "$(jget colours <<<"$info")" '["82,35,23"]'
info=$(pic -size 20x13 xc:'#e9e1cb' -fill '#3f6185' -draw 'rectangle 0,0 19,5' | kawa-sixel e9e1cb | sixel_info)
eq "$(jget bbox <<<"$info")" "[0, 0, 20, 6]" "on paper"
case_ "within one unit of the ground (dither specks) is ground too; two units off is drawn"
eq "$(pic -size 8x6 xc:'#120f0c' | kawa-sixel 0f0e0c | sixel_info | jget drawn)" 0 "#120f0c: 7,6,5 % — one unit from 6,5,5"
eq "$(pic -size 8x6 xc:'#151410' | kawa-sixel 0f0e0c | sixel_info | jget drawn)" 48 "#151410: 8,8,6 % — two units off"
eq "$(pic -size 8x6 xc:'#0f0e0c' | kawa-sixel 0F0E0C | sixel_info | jget drawn)" 0 "the colour in capitals"

case_ "sizes: 1×1, a height that is not a whole band, a very wide strip"
info=$(pic -size 1x1 xc:'#d0583a' | kawa-sixel 0f0e0c | sixel_info)
eq "$(jget raster <<<"$info")" "[1, 1, 1, 1]"; eq "$(jget drawn <<<"$info")" 1
eq "$(pic -size 9x7 xc:'#d0583a' | kawa-sixel 0f0e0c | sixel_info | jget bbox)" "[0, 0, 9, 7]"
eq "$(pic -size 3000x2 xc:'#d0583a' | kawa-sixel 0f0e0c | sixel_info | jget raster)" "[1, 1, 3000, 2]"
case_ "a huge picture (4000×3000) comes out whole"
s=$EPOCHREALTIME
# (its size read from the sixel's head: reading back 12 million pixels here would take longer)
eq "$(pic -size 4000x3000 xc:'#7fb8b0' | kawa-sixel 0f0e0c | head -c 40 | grep -ao '"1;1;[0-9]*;[0-9]*')" '"1;1;4000;3000'
e=$EPOCHREALTIME; printf '    (4000×3000: %d ms)\n' $(( (${e/./} - ${s/./}) / 1000 ))

case_ "not a picture, an empty input, a picture cut short: fails, quietly (fzf shows stderr)"
out=$(printf 'just some text\n' | kawa-sixel 0f0e0c 2>&1); r=$?
eq "$r" 1; eq "$out" ""
out=$(kawa-sixel 0f0e0c </dev/null 2>&1); r=$?
eq "$r" 1; eq "$out" ""
pic -size 300x200 plasma: >"$TMP/whole.png"; head -c 200 "$TMP/whole.png" >"$TMP/cut.png"
err=$(kawa-sixel 0f0e0c <"$TMP/cut.png" 2>&1 >/dev/null)
eq "$err" ""
case_ "ImageMagick missing: fails quietly"
out=$(PATH=$(without magick) kawa-sixel 0f0e0c <"$TMP/whole.png" 2>&1); r=$?
eq "$r" 1; eq "$out" ""

case_ "Turkish and Arabic locales: the same sixel, and no stray files where it runs"
want=$(pic -size 20x13 xc:'#d0583a' | kawa-sixel 0f0e0c)
mkdir -p "$TMP/cwd"
for l in tr_TR ar_EG; do
  if locale_of $l; then
    eq "$(cd "$TMP/cwd" && pic -size 20x13 xc:'#d0583a' | LC_ALL=$LOC kawa-sixel 0f0e0c)" "$want" "$l"
  else skip "no $l.UTF-8 locale"; fi
done
eq "$(ls -A "$TMP/cwd")" "" "a file left in the folder it ran in"
unset LOCPATH

case_ "misuse: no colour, a colour that is not RRGGBB; --help"
for a in "" 0f0e0 '#0f0e0c' zzzzzz 0f0e0c0; do rc 2 kawa-sixel "$a" </dev/null; done
has "$(kawa-sixel 2>&1 </dev/null)" "usage: kawa-sixel RRGGBB"
rc 0 kawa-sixel --help; has "$(kawa-sixel --help)" "sixel"

# ── kawa-cell ────────────────────────────────────────────────────────────────
case_ "not in a terminal: foot's 9×21 at once"
s=$EPOCHREALTIME; out=$(kawa-cell </dev/null); e=$EPOCHREALTIME
eq "$out" 9x21; (( ${e/./} - ${s/./} < 300000 )) && _ok || _no "it waited for an answer that cannot come"

case_ "the terminal answers: its cell (foot at scale 1, at scale 2, another font)"
has "$(cell --answer '\x1b[16t' '\x1b[6;21;9t' -- kawa-cell)" $'9x21\r'
has "$(cell --answer '\x1b[16t' '\x1b[6;42;18t' -- kawa-cell)" $'18x42\r'
has "$(cell --answer '\x1b[16t' '\x1b[6;25;11t' -- kawa-cell)" $'11x25\r'
case_ "keys typed just before the answer do not spoil it"
has "$(cell --answer '\x1b[16t' 'ab\x1b[6;42;18t' -- kawa-cell)" $'18x42\r'

case_ "the terminal never answers: 9×21 within about half a second, no hang"
s=$EPOCHREALTIME; out=$(cell -- kawa-cell); r=$?; e=$EPOCHREALTIME
eq "$r" 0 "(124: it hung until killed)"; has "$out" $'9x21\r'
(( ${e/./} - ${s/./} < 2000000 )) && _ok || _no "took $(( (${e/./} - ${s/./}) / 1000 )) ms"
case_ "an answer too late (1.5 s): 9×21, no hang"
s=$EPOCHREALTIME; out=$(cell --delay 1.5 --answer '\x1b[16t' '\x1b[6;42;18t' -- kawa-cell); e=$EPOCHREALTIME
has "$out" $'9x21\r'; (( ${e/./} - ${s/./} < 2000000 )) && _ok || _no "took $(( (${e/./} - ${s/./}) / 1000 )) ms"

case_ "a nonsense answer: 9×21"
for a in '\x1b[6;abc;9t' '\x1b[6;0;0t' '\x1b[6;5;2t' '\x1b[6;99999;9t' 'xyz t'; do
  has "$(cell --answer '\x1b[16t' "$a" -- kawa-cell)" $'9x21\r' "answer $a"
done

case_ "the terminal is left as it was, and the answer never shows on screen"
out=$(cell --answer '\x1b[16t' '\x1b[6;42;18t' -- bash -c 'a=$(stty -g); kawa-cell >/dev/null; b=$(stty -g); [[ $a == "$b" ]] && echo same')
has "$out" same; lacks "$out" "6;42;18"
out=$(cell -- bash -c 'a=$(stty -g); kawa-cell >/dev/null; b=$(stty -g); [[ $a == "$b" ]] && echo same')
has "$out" same "after no answer too"

case_ "misuse and help"
rc 2 kawa-cell --bogus; rc 2 kawa-cell 9x21
rc 0 kawa-cell --help; has "$(kawa-cell --help)" "cell"

done_
