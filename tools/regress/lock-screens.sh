#!/usr/bin/env bash
# tools/regress/lock-screens.sh — never again a lock that leaves the screens lit, or eats a key (the owner,
# 26 Oct 01:48: "when the lock screen is showing and nothing happens for 5 seconds, the monitors turn
# off; any key or move lights them again straight onto the lock — no extra wake press lost"): the
# installed lock in a headless kit, kawa-lock's `--screens` stood in for (its note and a log: no
# wlopm, no journal); six times nothing for a while (6 s, then 9: dark under 2 s, then over 3), then a
# key — dark 5 s after the last input each time, lit by the key; a key after more than 2 s of dark
# only wakes, one within 2 s is typed.
#   bash tools/regress/lock-screens.sh [KIT OPTION…]
#   LOCK_HOME=DIR …   the lock's files before they are applied (as tools/regress/lock-start.sh)
# Exit 0 held · 1 broken (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-screens.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
src=${LOCK_HOME:-$HOME} art=${LOCK_HOME:-$HOME}/.local/share/fedokawaii/dark
[[ -s $art/lock-scene.txt ]] || { echo "lock-screens: no scene in $art (fedokawaii apply)" >&2; exit 1; }
cat >"$out/play.sh" <<'PLAY'
mkdir -p "$HOME/.local/share/fedokawaii" "$HOME/.local/lib" "$KIT_OUT/stub"
ln -s "$REAL/.local/share/fedokawaii/dark" "$REAL/.local/share/fedokawaii/light" "$HOME/.local/share/fedokawaii/"
ln -s "$REAL/.local/lib/fedokawaii" "$HOME/.local/lib/fedokawaii"
if [[ $REAL != "$CALLER" ]]; then
  cp "$REAL/.config/fedokawaii/lock.ui" "$HOME/.config/fedokawaii/lock.ui"
  for t in dark light; do cp "$REAL/.config/fedokawaii/themes/$t/gtklock.css" "$HOME/.config/fedokawaii/themes/$t/"; done
fi
printf '#!/bin/sh\nexit 0\n' >"$KIT_OUT/stub/logger"
# (kawa-lock as it is, but --screens: the note the module reads, and a line with the moment)
printf '#!/bin/sh\nif [ "$1" = --screens ]; then echo "$(date +%%s.%%N) $2" >>"%s/screens.log"; echo "$2" >"$XDG_RUNTIME_DIR/kawa-screens"; exit 0; fi\nexec %s "$@"\n' \
  "$KIT_OUT" "$(command -v kawa-lock)" >"$KIT_OUT/stub/kawa-lock"
chmod +x "$KIT_OUT/stub/logger" "$KIT_OUT/stub/kawa-lock"
export PATH="$KIT_OUT/stub:$PATH"
KAWA_LOCK_SLEEP=0 kawa-lock >"$KIT_OUT/kawa-lock.log" 2>&1
echo "$(date +%s.%N) locked" >>"$KIT_OUT/screens.log"
for i in 1 2 3 4 5 6; do
  nap $((i % 2 ? 6 : 9))
  echo "$(date +%s.%N) key" >>"$KIT_OUT/screens.log"; key x      # (pressed ~0.3 s after the line)
  nap 0.4; shot "k$i" 940,650 160x40
done
PLAY
sed -i "1i REAL=$src CALLER=$HOME" "$out/play.sh"
bash "$here/../kit.sh" --theme dark "$@" --out "$out" --play "$out/play.sh" --time 150 play >"$out/kit.log" 2>&1 || { echo "lock-screens: the kit failed: $(tail -n 2 "$out/kit.log")" >&2; exit 2; }
[[ -s $out/screens.log && -s $out/k6.png ]] || { echo "lock-screens: the play left no log or shots" >&2; exit 2; }
# (each key: the moment of the last input before it, the dark's start, the light's; typed or not by
# the marks in the row — the scene's own middle ink, counted at the row's places)
python3 -I - "$out" "$art" <<'PY'
import sys
from PIL import Image
out, art = sys.argv[1], sys.argv[2]
kv = {}
for line in open(f"{art}/lock-scene.txt"):
    w = line.split("#")[0].split()
    if w:
        kv.setdefault(w[0], []).append(w[1:])
rx, ry, pitch, rn = map(int, kv["row"][0])
core = tuple(int(kv["mark"][0][1][i:i + 2], 16) for i in (0, 2, 4))
ev = [(float(t), w) for t, w in (line.split() for line in open(f"{out}/screens.log"))]
def marks(i):     # (the shot is 940,650 160x40 of a 1080p screen, ×3)
    im = Image.open(f"{out}/k{i}.png").convert("RGB")
    return sum(im.getpixel((3 * (rx + pitch * j) + 1 - 940, 3 * ry + 1 - 650)) == core
               for j in range(rn) if 0 <= 3 * (rx + pitch * j) + 1 - 940 < im.width)
bad, last, seen, typed_before = [], None, 0, 0
for t, w in ev:
    if w in ("locked", "key"):
        if w == "key":
            seen += 1
            darks = [u for u, v in ev if v == "off" and last <= u <= t]
            lights = [u for u, v in ev if v == "on" and t <= u <= t + 1.0]
            if not darks:
                bad.append(f"key {seen}: no dark 5 s after the last input")
            elif not 4.4 <= darks[0] - last <= 6.7:
                bad.append(f"key {seen}: dark {darks[0] - last:.2f} s after the last input (5 to 6, and the press's 0.3)")
            if not lights:
                bad.append(f"key {seen}: the screens not lit within 1 s")
            n = marks(seen)
            dark_for = t - darks[0] if darks else 0
            # (wtype presses ~0.3 s after the line: within 2 s it counts, beyond 2.5 s it only wakes)
            if dark_for + 0.3 < 1.7 and n != min(typed_before + 1, rn):
                bad.append(f"key {seen}: dark {dark_for:.2f} s — it should have been typed")
            if dark_for > 2.5 and n != typed_before:
                bad.append(f"key {seen}: dark {dark_for:.2f} s — it should only have woken the screens")
            typed_before = n
        last = t
print("; ".join(bad) if bad else f"held — {seen} keys")
sys.exit(1 if bad else 0)
PY
rc=$?
((rc == 0)) && { echo "lock-screens: held — dark 5 s after each last input, lit by every key, a key after over 2 s of dark only woke"; exit 0; }
echo "lock-screens: broken (above)" >&2; exit 1
