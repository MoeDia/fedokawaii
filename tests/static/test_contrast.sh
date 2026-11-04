#!/usr/bin/env bash
# tests/static/test_contrast.sh — what is selected or highlighted stands out (the owner, 2026-10-27
# 19:19: "a highlighted row's contents are not contrasty enough"): tools/contrast.py measures every
# such state of every surface, both themes, from the files the desktop ships — the words on the
# lacquer ≥ 7 : 1, icons and matched letters ≥ 4.5, a large glyph or a meter's level ≥ 3; by APCA
# too (--apca: every role's words on the grounds, Lc 75 / 60 / 45 / 30) — and the surfaces that
# draw by colour name (quick settings) still use the names it measures.
. "$(dirname "$0")/../lib/harness.sh"
sandbox

case_ "tools/contrast.py: every pair at or over its threshold, both themes"
out=$(python3 -I "$REPO/tools/contrast.py" 2>&1); rc=$?
eq "$rc" 0 "$(grep '✘' <<<"$out" | head -5)"
has "$out" "0 under their threshold"
# (both themes, every surface it knows: a parser that silently read nothing would pass)
eq "$(grep -c '^✔ dark ' <<<"$out")" "$(grep -c '^✔ light ' <<<"$out")" "dark and light measured alike"
(( $(grep -c '^✔ ' <<<"$out") >= 40 )) && _ok || _no "fewer pairs than the surfaces have: $(tail -1 <<<"$out")"

case_ "it fails a pair under its threshold (a selected row's words back on the vermilion)"
G=$TMP/copy; mkdir -p "$G"; cp -r "$REPO"/{tools,configs} "$G/"
sed -i 's/fg+:25:regular,bg:-1,bg+:24/fg+:17:regular,bg:-1,bg+:16/' "$G/configs/home/.config/fedokawaii/fzf.opts"
out=$(python3 -I "$G/tools/contrast.py" --quiet 2>&1); rc=$?
eq "$rc" 1 "a 5.1 : 1 row passed"
has "$out" "the row under the cursor: its words"

case_ "it fails the prompt's ink moved off its papers (foot's 30 dark the faint grey: every block under)"
sed -i '/^\[colors-dark\]/,/^\[/s/^30=.*/30=907e5d/' "$G/configs/home/.config/foot/foot.ini"
out=$(python3 -I "$G/tools/contrast.py" --quiet 2>&1); rc=$?
eq "$rc" 1 "the prompt's words at a grey ink passed"
has "$out" "the folder's words on their paper"; has "$out" "the time and the jobs on their paper"

case_ "tools/contrast.py --apca: every role and pair at its APCA level, both themes (T19m: light words on sumi)"
out=$(python3 -I "$REPO/tools/contrast.py" --apca --quiet 2>&1); rc=$?
eq "$rc" 0 "$(grep '✘' <<<"$out" | head -5)"
has "$out" "APCA: 0 under their level"
has "$out" "◇ light"     # (the seal's black numeral: measured, kept by his word)

case_ "it fails the dark words back at their old lightness (text Lc 68, under 75)"
G2=$TMP/copy2; mkdir -p "$G2"; cp -r "$REPO"/{tools,configs} "$G2/"
sed -i 's/p\["text"\] = mix("Ecru", "Ivory Buff", 0.90/p["text"] = mix("Ecru", "Ivory Buff", 0.45/' "$G2/tools/wada-palette.py"
out=$(python3 -I "$G2/tools/contrast.py" --apca --quiet 2>&1); rc=$?
eq "$rc" 1 "the dark text at Lc 68 passed"
has "$out" "text on ground"

case_ "…and it fails word inks too close to tell apart (strong back at Lc 88: 10 over text, the step is 15)"
G3=$TMP/copy3; mkdir -p "$G3"; cp -r "$REPO"/{tools,configs} "$G3/"
sed -i 's/p\["strong"\] = w("Sulpher Yellow", "dark.strong")/p["strong"] = mix("Ivory Buff", "Sulpher Yellow", 0.55, "dark.strong")/' "$G3/tools/wada-palette.py"
out=$(python3 -I "$G3/tools/contrast.py" --apca --quiet 2>&1); rc=$?
eq "$rc" 1 "a 10-Lc step passed"
has "$out" "strong over text"

case_ "every menu's selected row is the seal's tint, its 2 px edge the pointer: fzf's bg+ 24 (select), fg+ 25 (text_on_select), pointer 16 (accent), every other ink its own (no :strip)"
has "$(cat "$REPO/configs/home/.config/fedokawaii/fzf.opts")" "fg+:25:regular,bg:-1,bg+:24"
has "$(cat "$REPO/configs/home/.config/fedokawaii/fzf.opts")" "pointer:16"
has "$(cat "$REPO/configs/home/.config/fedokawaii/fzf.opts")" "--pointer='@ICON_BAND_EDGE@'"
lacks "$(cat "$REPO/configs/home/.config/fedokawaii/fzf.opts")" ":strip"

case_ "quick settings' cursor draws with the names contrast.py measures"
src=$(cat "$REPO/bin/kawa-panel")
has "$src" '"label": "text_on_select"'
has "$src" '"fill": "select"'
has "$src" '"edge": "select_edge" if bare'
lacks "$src" '"fill": "accent", "frame": None'

done_
