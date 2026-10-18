#!/usr/bin/env python3
"""tools/build-width.py — art/fusion-wide.txt (the letters Fusion Pixel draws two columns wide
below U+3000) → configs/home/.config/fedokawaii/width.sh, the menus' width helper: `cols TEXT`
prints how many columns TEXT takes in a menu, `cut_cols TEXT N` cuts it to fit N, `heading
KANJI NAME W` heads a part of a menu. `--check` exits 1 when width.sh is not what the
list makes (tests/static runs it)."""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SRC = ROOT / "art/fusion-wide.txt"
OUT = ROOT / "configs/home/.config/fedokawaii/width.sh"


def spans():
    out = []
    for line in SRC.read_text(encoding="utf-8").splitlines():
        if line.startswith("#"):
            continue
        for item in line.split():
            a, _, b = item.partition("-")
            out.append((int(a, 16), int(b or a, 16)))
    return out


def render():
    # a bracket expression of the letters themselves (bash under C.UTF-8 ranges by code point);
    # ] and - never occur in the list, so no escaping is needed
    expr = "".join(chr(a) if a == b else f"{chr(a)}-{chr(b)}" for a, b in spans())
    return f"""# ~/.config/fedokawaii/width.sh — made by tools/build-width.py from art/fusion-wide.txt; do not edit.
# shellcheck shell=bash disable=SC2034
# cols TEXT — how many columns TEXT takes in a menu (fuzzel, in Fusion Pixel): what a
# terminal counts (wc -L: a Japanese letter two), and one more for each letter below U+3000
# that the font draws two columns wide (─ … → — © and the like), which a terminal counts as one.
FUSION_WIDE='[{expr}]'
cols() {{
  local LC_ALL=C.UTF-8 t=$1 n
  n=${{t//$FUSION_WIDE/}}
  printf '%s\\n' $(( $(LC_ALL=C.UTF-8 wc -L <<<"$t") + ${{#t}} - ${{#n}} ))
}}
# cut_cols TEXT N — TEXT in at most N columns; cut, it ends in "…" (two columns in the font),
# never mid-letter and with no space before the "…" (counted in letters, whatever the locale)
cut_cols() {{
  local LC_ALL=C.UTF-8 t=$1 n=$2
  (( $(cols "$t") <= n )) && {{ printf '%s' "$t"; return; }}
  t=${{t:0:n-2}}
  while (( $(cols "$t") > n - 2 )); do t=${{t%?}}; done
  printf '%s…' "${{t%"${{t##*[! ]}}"}}"
}}
# heading KANJI NAME W — a part's heading in a menu W columns wide, as Super+U heads its
# parts: the kanji (12 px) over the icons, then ICON_GAP (icons.sh: 2 px) and two spaces, so
# the name starts where the entries' names do (an icon is 14 px), then a rule of en dashes
# (6 px each) to the last pixel the menu shows whole (W × 6 − 10)
heading() {{
  local LC_ALL=C.UTF-8 h="$1${{ICON_GAP:-}}  $2 " i n
  n=$(( $3 - 7 - $(cols "$2") ))
  for ((i = 0; i < n; i++)); do h+='–'; done
  printf '%s' "$h"
}}
"""


if __name__ == "__main__":
    text = render()
    if sys.argv[1:] == ["--check"]:
        sys.exit(0 if OUT.read_text(encoding="utf-8") == text else 1)
    OUT.write_text(text, encoding="utf-8")
    print(f"{OUT.relative_to(ROOT)}: {len(spans())} ranges")
