#!/usr/bin/env bash
# tools/regress/calendar-middle.sh — never again (r27-13a, bug 7: "Super+C … should open right
# down in the middle of the bar where the date is, not on the right side"): the calendar's frame
# centred on the bar's middle group (the date's) to the pixel — opened by its key and by a click
# on the date alike. Headless (tools/kit.sh, the real GPU).
#   bash tools/regress/calendar-middle.sh [KIT OPTION…]
# Exit 0 held · 1 broken (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-middle.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
cat >"$out/play.sh" <<'PLAY'
panel; nap 1.5
at 300 700; chord logo c; nap 1.2; shot key; key Escape; nap 0.6
m=$(python3 -I "$KIT_HERE/regress/shots.py" middle "$KIT_OUT/key.png" 16) && read -r l r _ <<<"$m"
at $(((l + r) / 2 - 60)) 16; click; nap 1.2; shot click
PLAY
sed -i "1i KIT_HERE=$(cd "$here/.." && pwd)" "$out/play.sh"
bash "$here/../kit.sh" --theme dark "$@" --out "$out" --play "$out/play.sh" play >"$out/kit.log" 2>&1 || { echo "calendar-middle: the kit failed: $(tail -n 2 "$out/kit.log")" >&2; exit 2; }
read -r _ _ bar2 < <(python3 -I "$here/shots.py" middle "$out/key.png" 16) || { echo "calendar-middle: the bar's middle not found" >&2; exit 1; }
for s in key click; do
  [[ -s $out/$s.png ]] || { echo "calendar-middle: no shot ($s)" >&2; exit 1; }
  # (a row through the calendar's frame, under the bar: its two hairlines)
  read -r _ _ cal2 < <(python3 -I "$here/shots.py" edges "$out/$s.png" 60 0 1920) || { echo "calendar-middle: no calendar ($s)" >&2; exit 1; }
  # (the clock's scroll is odd — its kanji's ink is 13 px with its two sides alike, r27-14 — and
  # the calendar even — seven 40 px days, six 8 px gaps: their middles can be half a pixel
  # apart, ×2 one; anything more is a calendar off its date)
  ((cal2 - bar2 <= 1 && bar2 - cal2 <= 1)) || { echo "calendar-middle: opened by $s, its centre ×2 is $cal2, the bar's middle $bar2" >&2; exit 1; }
done
echo "calendar-middle: held — by its key and by a click, centred on the bar's middle (×2: $bar2)"
