#!/usr/bin/env bash
# tests/regress/test_counts.sh — what he asked for by number (r24-20, r27-dec-4f) or by size (r24-19,
# r25-17), counted in the files that make it.
. "$(dirname "$0")/lib.sh"

case_ "a hundred wallpapers: the pack's list, both moods"
n=$(grep -cE '^(dark|light) ' "$REPO/configs/home/.local/share/fedokawaii/wallpapers.list")
d=$(grep -cE '^dark ' "$REPO/configs/home/.local/share/fedokawaii/wallpapers.list")
l=$(grep -cE '^light ' "$REPO/configs/home/.local/share/fedokawaii/wallpapers.list")
((n >= 100)) && _ok || _no "$n wallpapers in the list (he asked for 100)"
((d > 0 && l > 0)) && _ok || _no "dark $d, light $l: a mood with none"
item r24-20 "$n wallpapers: $d dark, $l light"

case_ "ten demons and ten angels from the old masters"
read -r dm am < <(python3 -I - "$REPO/art/masters/masters.toml" <<'PY'
import sys, tomllib
t = tomllib.load(open(sys.argv[1], "rb"))
print(*(sum(isinstance(r, dict) and r.get("theme") == m for r in t.values()) for m in ("dark", "light")))
PY
)
((${dm:-0} >= 10)) && _ok || _no "$dm demons (he asked for about ten)"
((${am:-0} >= 10)) && _ok || _no "$am angels (he asked for about ten)"
item "r27-dec-4f r27-18-walls" "$dm demons, $am angels"

case_ "the Learn book: long, Python and Rust by levels, exercises, the part on AI"
b=$REPO/docs/fedokawaii-learn.md
w=$(wc -w <"$b") ex=$(grep -cE '^#.*[Ee]xercise' "$b") py=$(grep -cE '^# .*Python level [1-4]' "$b")
((w >= 80000)) && _ok || _no "$w words (the book he asked to be long had 90k)"
((ex >= 50)) && _ok || _no "$ex exercise headings"
((py >= 4)) && _ok || _no "$py chapters of Python's levels"
grep -qE '^# .*Rust' "$b" && _ok || _no "no Rust part"
grep -qE '^# .*(Claude|AI\b)' "$b" && _ok || _no "no part on AI and Claude Code"
item "r24-19 r25-17" "$w words, $py Python chapters by level, Rust, the AI part, $ex exercise headings"
done_
