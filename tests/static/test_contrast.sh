#!/usr/bin/env bash
# tests/static/test_contrast.sh — what is selected or highlighted stands out (the owner, 2026-10-27
# 19:19: "a highlighted row's contents are not contrasty enough"): tools/contrast.py measures every
# such state of every surface, both themes, from the files the desktop ships — the words on the
# lacquer ≥ 7 : 1, icons and matched letters ≥ 4.5, a large glyph or a meter's level ≥ 3 — and the
# surfaces that draw by colour name (quick settings) still use the names it measures.
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
sed -i 's/fg+:25:regular:strip,bg:-1,bg+:24/fg+:17:regular:strip,bg:-1,bg+:16/' "$G/configs/home/.config/fedokawaii/fzf.opts"
out=$(python3 -I "$G/tools/contrast.py" --quiet 2>&1); rc=$?
eq "$rc" 1 "a 5.1 : 1 row passed"
has "$out" "the row under the cursor: its words"

case_ "every menu's selected row is the lacquer: fzf's bg+ 24 (select), fg+ 25 (text_on_select), :strip"
has "$(cat "$REPO/configs/home/.config/fedokawaii/fzf.opts")" "fg+:25:regular:strip,bg:-1,bg+:24"

case_ "quick settings' cursor draws with the names contrast.py measures"
src=$(cat "$REPO/bin/kawa-panel")
has "$src" 'ink = "text_on_select"'
has "$src" '"fill": "select"'
has "$src" '("text_on_select", "select_lo") if on'
lacks "$src" '"fill": "accent", "frame": None'

done_
