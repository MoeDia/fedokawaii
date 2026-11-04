#!/usr/bin/env bash
# tools/regress/menu-first-click.sh — never again (r27-13a, bug 3: "the highlighted options are
# not active until I click the menu once"): a menu opened by its key under a resting pointer
# lights the row under it at once and answers its first click. Headless (tools/kit.sh, the real
# GPU): the calendar opened by Super+C, the pointer resting on its "next" hint: lit as it opens; one
# click, the pointer still: the month pages. The timer opened under the pointer: the row under it
# tinted at once, one click: that timer runs.
#   bash tools/regress/menu-first-click.sh [KIT OPTION…]   (e.g. --dwl /usr/local/bin/dwl)
# Exit 0 held · 1 broken (what, said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-click.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT   # (KEEP=1: the shots kept, the folder said)
# (the calendar 362 × 248 under the bar's middle: its frame from x 779, its top on y 33; its hints' row 193 under the top,
#  "next" from x 119 of the frame, 50 wide. The timer's first lengths from 78, 20 px each: the third its 25 min)
cat >"$out/play.sh" <<PLAY
panel; nap 1.5
say "select \$(sed -n 's/^select=//p' "\$HOME/.config/fedokawaii/current/panel.conf")"
at 100 900; chord logo c; nap 1.2; shot open; key Escape; nap 0.6
at $((779 + 119 + 25)) $((33 + 193 + 10)); chord logo c; nap 1.2; shot lit
click; nap 1.0; shot paged; key Escape; nap 0.6
at 960 128; setsid -f kawa-timer; nap 1.2; shot row
click; nap 0.8; say "timer \$(cut -d' ' -f1,3 "\$XDG_RUNTIME_DIR/kawa-timer" 2>/dev/null)"
kawa-timer cancel
PLAY
bash "$here/../kit.sh" --theme dark "$@" --out "$out" --play "$out/play.sh" play >"$out/kit.log" 2>&1 || { echo "menu-first-click: the kit failed: $(tail -n 2 "$out/kit.log")" >&2; exit 2; }
select=$(sed -n 's/^select //p' "$out/play.log")
python3 -I "$here/shots.py" differ "$out/open.png" "$out/lit.png" "$((779 + 100)),$((33 + 193)),90,20" \
  || { echo "menu-first-click: the hint under the resting pointer is not lit as the menu opens" >&2; exit 1; }
python3 -I "$here/shots.py" differ "$out/lit.png" "$out/paged.png" "$((779 + 17)),$((33 + 17)),120,20" \
  || { echo "menu-first-click: the first click did nothing (the month did not page)" >&2; exit 1; }
got=$(python3 -I "$here/shots.py" centre "$out/row.png" 960 119)
[[ $got == "$select" ]] || { echo "menu-first-click: the row under the resting pointer is not tinted as the menu opens ($got, not $select)" >&2; exit 1; }
grep -q '^timer timer 25$' "$out/play.log" || { echo "menu-first-click: the first click on the row did nothing ($(grep '^timer' "$out/play.log"))" >&2; exit 1; }
echo "menu-first-click: held — lit at open, the first click pages, the row's first click runs${KEEP:+ ($out)}"
