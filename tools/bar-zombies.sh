#!/usr/bin/env bash
# tools/bar-zombies.sh — the bar keeps its children whole through what a session does to it
# (ledger r27-found-1): in the kit (tools/kit.sh, the repository's bar config and style), its
# stylesheet edited three times (waybar reloads it itself: reload_style_on_change) and its
# modules poked and woken as dwl and the menus do (kawa-dwlstatus --poke every signal the
# config names, --wake) ten times each. Asserted: waybar still runs, the same children as
# before (no module restarted), no zombie child, the last edit drawn on the bar.
#   bash tools/bar-zombies.sh [--out DIR]   (default /dev/shm/r27/bar-zombies)
# Exit 0 all held · 1 one did not (the lines say which) · 2 the kit could not run.
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=/dev/shm/r27/bar-zombies
[[ ${1:-} == --out ]] && { out=$2; shift 2; }
(($# == 0)) || { echo "usage: bash tools/bar-zombies.sh [--out DIR]" >&2; exit 2; }
mkdir -p "$out"; play=$out/play.sh
export PATH=$HOME/.local/bin:$PATH   # (the kit's own scripts: the loop's PATH lacks them)
cat >"$play" <<'PLAY'
wb=$(pgrep -o -x -P $$ waybar)
kids() { ps --ppid "$wb" -o pid=,comm= | sort | tr -s ' \n' ' '; }
nap 4
before=$(kids)
for i in 1 2 3; do printf '\n/* bar-zombies %s */\n' "$i" >>"$HOME/.config/waybar/style.css"; nap 1; done
for i in 1 2 3 4 5 6 7 8 9 10; do kawa-dwlstatus --poke 8 9 10 11 12 13 14 15 18 19 20 21 22; kawa-dwlstatus --wake; done
nap 2
printf '\n#custom-torii { color: #00ff00; }\n' >>"$HOME/.config/waybar/style.css"; nap 3
shot bar 0,0 1920x40
say "alive $(kill -0 "$wb" 2>/dev/null && echo yes || echo no)"
# (every child it had still its own — an interval module's command may come and go meanwhile)
gone=""
for p in $(awk '{ for (i = 1; i <= NF; i += 2) print $i }' <<<"$before"); do
  [[ $(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ') == "$wb" ]] || gone+=" $p"
done
say "same $([[ -z $gone ]] && echo yes || echo "no: gone$gone (before: $before; now: $(kids))")"
say "zombies $(ps --ppid "$wb" -o stat= | grep -c Z)"
PLAY
bash "$here/kit.sh" --repo-art --time 120 --play "$play" --out "$out" play >"$out/kit.log" 2>&1 \
  || { echo "bar-zombies: the kit did not run — $(tail -n 2 "$out/kit.log")" >&2; exit 2; }
log=$(cat "$out/play.log")
green=$(python3 -I -c 'import sys; from PIL import Image; print(sum(1 for p in Image.open(sys.argv[1]).convert("RGB").get_flattened_data() if p == (0, 255, 0)))' "$out/bar.png" 2>/dev/null) || green=0
r=0
for w in "alive yes" "same yes" "zombies 0"; do
  if grep -qx "$w" <<<"$log"; then echo "ok   $w"; else echo "FAIL $(grep -m1 "^${w%% *} " <<<"$log")"; r=1; fi
done
if ((green > 0)); then echo "ok   the last edit drawn ($green px)"; else echo "FAIL the last edit not drawn on the bar"; r=1; fi
exit "$r"
