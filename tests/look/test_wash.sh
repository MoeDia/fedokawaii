#!/usr/bin/env bash
# tests/look/test_wash.sh — kawa-wash, the one transition's three words to dwl (its fifo,
# $XDG_RUNTIME_DIR/dwl-warm): "cover" waits for dwl's "covered" (a fifo of its own in the runtime
# folder, gone afterwards) and never holds a change up for more than a second; "go" and "drop" are
# one line each; outside the desktop, nothing at once. dwl's side (the snapshot, the bleed, the
# pointer) is tools/regress/wash.sh: headless, on the GPU.
. "$(dirname "$0")/../lib/harness.sh"
sandbox
F=$XDG_RUNTIME_DIR/dwl-warm

case_ "--help, and wrong use: exit 2"
rc 0 kawa-wash --help; has "$(kawa-wash --help)" "kawa-wash cover"
rc 2 kawa-wash; rc 2 kawa-wash bogus

case_ "outside the desktop (no dwl's fifo): every word does nothing, at once"
t0=$EPOCHREALTIME; rc 0 kawa-wash cover; rc 0 kawa-wash go; rc 0 kawa-wash drop
(( ${EPOCHREALTIME/[.,]/} - ${t0/[.,]/} < 300000 )) && _ok || _no "it waited for a dwl that is not there"

case_ "cover: the line dwl reads, its answer read from a fifo of our own in the runtime folder — back as soon as dwl answers, the fifo gone"
mkfifo "$F"
# (a stand-in dwl: reads one line, answers "covered" where it is told, after 150 ms)
( exec 3<>"$F"; read -r w c path <&3; echo "$w $c $path" >"$TMP/line"; sleep 0.15
  [[ -p $path ]] && echo covered >"$path" ) & dw=$!
t0=$EPOCHREALTIME; rc 0 kawa-wash cover; ms=$(( (${EPOCHREALTIME/[.,]/} - ${t0/[.,]/}) / 1000 ))
wait "$dw"
read -r w c path <"$TMP/line"
eq "$w $c" "wash cover"; has "$path" "$XDG_RUNTIME_DIR/kawa-wash." "the answer's fifo in the runtime folder"
((ms >= 140 && ms < 600)) && _ok || _no "back after $ms ms (dwl answered after 150)"
[[ ! -e $path ]] && _ok || _no "its fifo was left behind"

case_ "a dwl that never answers (an old one): back after a second, all the same — a switch is never held up"
( exec 3<>"$F"; read -r _ <&3; sleep 2 ) & dw=$!
t0=$EPOCHREALTIME; rc 0 kawa-wash cover; ms=$(( (${EPOCHREALTIME/[.,]/} - ${t0/[.,]/}) / 1000 ))
((ms >= 900 && ms < 1500)) && _ok || _no "back after $ms ms, not about 1000"
kill "$dw" 2>/dev/null; wait "$dw" 2>/dev/null
eq "$(find "$XDG_RUNTIME_DIR" -name 'kawa-wash.*' | wc -l)" 0 "no answer fifo left"

case_ "go and drop: one line each, never waiting on the fifo"
( exec 3<>"$F"; read -r a <&3; read -r b <&3; printf '%s\n%s\n' "$a" "$b" >"$TMP/lines" ) & dw=$!
rc 0 kawa-wash go; rc 0 kawa-wash drop
wait "$dw"
eq "$(cat "$TMP/lines")" "wash go"$'\n'"wash drop"

case_ "kawa-theme and kawa-wallpaper ask for it: covered before the change, washed off after it (the old kawa-saver --wash gone)"
has "$(sed -n '/^wash_begin()/,/^}/p' "$REPO/bin/kawa-theme")" "kawa-wash cover"
has "$(sed -n '/^wash_end()/,/^}/p' "$REPO/bin/kawa-theme")" "kawa-wash go"
has "$(cat "$REPO/bin/kawa-theme")" "kawa-wash drop" "a press during a switch drops its wash"
w=$(sed -n '/^  --set)/,/took "set/p' "$REPO/bin/kawa-wallpaper")
has "$w" "kawa-wash cover"; has "$w" "kawa-wash go"
[[ $(grep -n 'kawa-wash cover' <<<"$w" | cut -d: -f1) -lt $(grep -n 'apply "$c"' <<<"$w" | cut -d: -f1) ]] && _ok || _no "the wallpaper changes before the cover"
for f in kawa-theme kawa-wallpaper; do lacks "$(cat "$REPO/bin/$f")" "saver --wash"; done
has "$(sed -n '/^    sel=\$(/,/^      --bind="load/p' "$REPO/bin/kawa-wallpaper")" "--no-clear" "the picker closes on its own page (bug 5: never a wiped terminal dissolving)"

done_
