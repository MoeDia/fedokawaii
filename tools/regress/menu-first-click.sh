#!/usr/bin/env bash
# tools/regress/menu-first-click.sh — never again (r27-13a, bug 3: "the highlighted options are
# not active until I click the menu once"): a menu opened by its key under a resting pointer
# lights the row under it at once and answers its first click. Headless (tools/kit.sh, the real
# GPU): the calendar opened by Super+C, its keys found; opened again with the pointer resting on
# "next" — lit as it opens; one click, the pointer still: the month pages.
#   bash tools/regress/menu-first-click.sh [KIT OPTION…]   (e.g. --dwl /usr/local/bin/dwl)
# Exit 0 held · 1 broken (what, said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-click.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT   # (KEEP=1: the shots kept, the folder said)
cat >"$out/play.sh" <<PLAY
panel; nap 1.5
at 100 900; chord logo c; nap 1.2; shot open; key Escape; nap 0.6
k=\$(python3 -I "$here/shots.py" keys "\$KIT_OUT/open.png" 0,36,1920,600 | sed -n 2p)
[[ -n \$k ]] || { say "no keys found"; exit 0; }
read -r kx ky kw kh <<<"\$k"
say "next \$kx \$ky \$kw \$kh"
at \$((kx + kw / 2)) \$((ky + kh / 2)); chord logo c; nap 1.2; shot lit
click; nap 1.0; shot paged
PLAY
bash "$here/../kit.sh" --theme dark "$@" --out "$out" --play "$out/play.sh" play >"$out/kit.log" 2>&1 || { echo "menu-first-click: the kit failed: $(tail -n 2 "$out/kit.log")" >&2; exit 2; }
read -r _ kx ky kw _ < <(grep '^next ' "$out/play.log") || { echo "menu-first-click: the calendar's keys were not found" >&2; exit 1; }
accent=$(sed -n 's/^accent=//p' "$HOME/.config/fedokawaii/themes/dark/panel.conf")
cx=$((kx + kw / 2)) cy=$((ky + 2))
got=$(python3 -I "$here/shots.py" centre "$out/lit.png" "$cx" "$cy")
[[ $got == "$accent" ]] || { echo "menu-first-click: the key under the resting pointer is not lit as the menu opens ($got, not $accent)" >&2; exit 1; }
# (the month's heading row: the menu's top 40 px above its keys' row, well clear of them)
python3 -I "$here/shots.py" differ "$out/lit.png" "$out/paged.png" "$((kx - 140)),40,$((kw * 3 + 40)),40" \
  || { echo "menu-first-click: the first click did nothing (the month did not page)" >&2; exit 1; }
echo "menu-first-click: held — lit at open, the first click pages${KEEP:+ ($out)}"
