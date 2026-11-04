#!/usr/bin/env bash
# tools/regress/saver-dark.sh — away for long (bug 1, "a frozen picture, then a sudden cut"): the screens go dark over the
# screensaver and it stops: no frame asked for, no step, no CPU. A key lights them; it holds the sleeping picture while
# the monitor finds its signal, then the world wakes onto the lock. Headless (tools/kit.sh, the real GPU), the installed
# saver, lock and module; logger stood in for.
#   bash tools/regress/saver-dark.sh [KIT OPTION…]
#   LOCK_HOME=DIR …   the lock's files before they are applied (as tools/regress/lock-start.sh)
# Exit 0 held · 1 broken (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-saverdark.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
src=${LOCK_HOME:-$HOME}
cat >"$out/play.sh" <<'PLAY'
mkdir -p "$HOME/.local/share/fedokawaii" "$HOME/.local/lib" "$KIT_OUT/stub"
ln -s "$REAL/.local/share/fedokawaii/dark" "$REAL/.local/share/fedokawaii/light" "$HOME/.local/share/fedokawaii/"
ln -s "$REAL/.local/lib/fedokawaii" "$HOME/.local/lib/fedokawaii"
if [[ $REAL != "$CALLER" ]]; then
  cp "$REAL/.config/fedokawaii/lock.ui" "$HOME/.config/fedokawaii/lock.ui"
  for t in dark light; do cp "$REAL/.config/fedokawaii/themes/$t/"{gtklock.css,saver.conf} "$HOME/.config/fedokawaii/themes/$t/"; done
fi
printf '#!/bin/sh\nexit 0\n' >"$KIT_OUT/stub/logger"; chmod +x "$KIT_OUT/stub/logger"
cpu() { local s; read -r s <"/proc/$1/stat"; s=${s##*) }; set -- $s; echo $((${12} + ${13})); }
PATH="$KIT_OUT/stub:$PATH" KAWA_LOCK_SLEEP=0 kawa-saver --idle >"$KIT_OUT/saver.log" 2>&1 & S=$!
nap 3; shot asleep
wlopm --off '*'; nap 2.5
a=$(cpu "$S"); nap 6; b=$(cpu "$S")
say "ticks in the dark: $((b - a)) in 6 s"
wlopm --on '*' >/dev/null 2>&1 &
key space; nap 0.5; shot held
nap 1.8; shot woke
kill -0 "$S" 2>/dev/null && say "still running" || say "gone"
PLAY
sed -i "1i REAL=$src CALLER=$HOME" "$out/play.sh"
bash "$here/../kit.sh" --theme dark --time 60 "$@" --out "$out" --play "$out/play.sh" play >"$out/kit.log" 2>&1 || { echo "saver-dark: the kit failed: $(tail -n 2 "$out/kit.log")" >&2; exit 2; }
for s in asleep held woke; do [[ -s $out/$s.png ]] || { echo "saver-dark: no shot ($s)" >&2; exit 2; }; done
ticks=$(sed -n 's/^ticks in the dark: \([0-9]*\).*/\1/p' "$out/play.log")
grep -q '^gone$' "$out/play.log" || { echo "saver-dark: it had not gone 2.3 s after the key" >&2; exit 1; }
((ticks <= 3)) || { echo "saver-dark: it worked in the dark ($ticks ticks in 6 s, want at most 3)" >&2; exit 1; }
verdict=$(python3 -I - "$out" <<'PY'
import sys
import numpy as np
from PIL import Image
o = sys.argv[1]
a, h, w = (np.asarray(Image.open(f"{o}/{n}.png").convert("RGB"), float) for n in ("asleep", "held", "woke"))
print(f"{(np.abs(a - h).sum(-1) > 90).mean():.3f} {(np.abs(h - w).sum(-1) > 90).mean():.3f}")
PY
) || { echo "saver-dark: the shots could not be read" >&2; exit 2; }
read -r sleep_moved wake_moved <<<"$verdict"
python3 -I -c 'import sys; sys.exit(0 if float(sys.argv[1]) < 0.05 else 1)' "$sleep_moved" || { echo "saver-dark: 0.5 s after the key it no longer shows the sleeping picture ($sleep_moved of the screen changed)" >&2; exit 1; }
python3 -I -c 'import sys; sys.exit(0 if float(sys.argv[1]) > 0.1 else 1)' "$wake_moved" || { echo "saver-dark: the world did not wake onto the lock ($wake_moved of the screen changed)" >&2; exit 1; }
echo "saver-dark: held — $ticks ticks in 6 s in the dark, the sleeping picture while the monitor comes, then the lock"
