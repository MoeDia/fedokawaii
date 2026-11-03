#!/usr/bin/env bash
# tools/regress/lock-start.sh — the lock comes up (every update proves it: lib/guard.sh
# desktop_starts): kawa-lock in a headless kit — gtklock with its layout and kawa-lockmod, the
# installed ones — locks the session within 3 s, and the screen shows the mood's scene at whole
# pixels, pixel for pixel against lock-scene.png (the flames and the password's row aside: they
# move) — the instant the lock is up and a second later: not the desktop, not gtklock's own line
# for a single frame (the master's T20 review 1: it eased in for ~140 ms). Both moods, a kit each.
# Nothing is written to the journal (logger stood in for). Headless (tools/kit.sh, the real GPU).
#   bash tools/regress/lock-start.sh [KIT OPTION…]
#   LOCK_HOME=DIR …   a home of the lock's files before they are applied: its share/fedokawaii,
#                     lib/fedokawaii, lock.ui and the themes' gtklock.css (with --bin bin: kawa-lock)
# Exit 0 held · 1 broken (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-lock.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
src=${LOCK_HOME:-$HOME}
for mood in dark light; do
  a=$src/.local/share/fedokawaii/$mood
  [[ -s $a/lock-scene.png && -s $a/lock-scene.txt && -s $a/lock-flame.png ]] || { echo "lock-start: no $mood scene in $a (fedokawaii apply)" >&2; exit 1; }
done
cat >"$out/play.sh" <<'PLAY'
mkdir -p "$HOME/.local/share/fedokawaii" "$HOME/.local/lib" "$KIT_OUT/stub"
ln -s "$REAL/.local/share/fedokawaii/dark" "$REAL/.local/share/fedokawaii/light" "$HOME/.local/share/fedokawaii/"
ln -s "$REAL/.local/lib/fedokawaii" "$HOME/.local/lib/fedokawaii"
if [[ $REAL != "$CALLER" ]]; then   # (LOCK_HOME: its layout and look too)
  cp "$REAL/.config/fedokawaii/lock.ui" "$HOME/.config/fedokawaii/lock.ui"
  for t in dark light; do cp "$REAL/.config/fedokawaii/themes/$t/gtklock.css" "$HOME/.config/fedokawaii/themes/$t/"; done
fi
printf '#!/bin/sh\nexit 0\n' >"$KIT_OUT/stub/logger"; chmod +x "$KIT_OUT/stub/logger"   # (his journal untouched)
t0=${EPOCHREALTIME/[.,]/}
PATH="$KIT_OUT/stub:$PATH" KAWA_LOCK_SLEEP=0 kawa-lock >"$KIT_OUT/kawa-lock.log" 2>&1
r=$?; shot first                       # (the instant it is up: a line easing in would show here)
say "locked $r $(( (${EPOCHREALTIME/[.,]/} - t0) / 1000 ))"
nap 1; shot lock
PLAY
sed -i "1i REAL=$src CALLER=$HOME" "$out/play.sh"
said=()
for mood in dark light; do
  o=$out/$mood art=$src/.local/share/fedokawaii/$mood
  bash "$here/../kit.sh" --theme "$mood" "$@" --out "$o" --play "$out/play.sh" play >"$o.log" 2>&1 || { echo "lock-start: the kit failed ($mood): $(tail -n 2 "$o.log")" >&2; exit 2; }
  read -r _ rc ms <"$o/play.log" 2>/dev/null || { echo "lock-start: the play said nothing ($mood)" >&2; exit 2; }
  ((rc == 0)) || { echo "lock-start: kawa-lock failed in $mood (exit $rc): $(tail -n 1 "$o/kawa-lock.log")" >&2; exit 1; }
  ((ms <= 3000)) || { echo "lock-start: $mood locked only after $ms ms" >&2; exit 1; }
  [[ -s $o/first.png && -s $o/lock.png ]] || { echo "lock-start: no shot ($mood)" >&2; exit 2; }
  # (each shot against the scene at the screen's whole scale, its moving parts left out)
  verdict=$(python3 -I - "$o" "$art" <<'PY'
import sys
import numpy as np
from PIL import Image
o, art = sys.argv[1], sys.argv[2]
img = Image.open(f"{art}/lock-scene.png").convert("RGB")
kv = {}
for line in open(f"{art}/lock-scene.txt"):
    w = line.split("#")[0].split()
    if w:
        kv.setdefault(w[0], []).append([int(v) if v.isdigit() else v for v in w[1:]])
out = []
for name in ("first", "lock"):
    shot = np.asarray(Image.open(f"{o}/{name}.png").convert("RGB"))
    H, W = shot.shape[:2]
    n = max(1, min(W // img.width, H // img.height))
    ox, oy = (W - n * img.width) // 2, (H - n * img.height) // 2
    want = np.asarray(img.resize((img.width * n, img.height * n), Image.NEAREST))
    got = shot[oy:oy + want.shape[0], ox:ox + want.shape[1]]
    keep = np.ones(want.shape[:2], bool)
    fw, fh, _ = kv["frames"][0] if "flame" in kv else (0, 0, 0)
    for fx, fy in kv.get("flame", []):
        keep[n * fy:n * (fy + fh), n * fx:n * (fx + fw)] = False
    rx, ry, pitch, rn = kv["row"][0]
    keep[n * (ry - 3):n * (ry + 4), n * (rx - 2):n * (rx + pitch * rn + 3)] = False
    out.append(str(int((~(got == want).all(axis=2))[keep].sum())))   # (pixels off the scene)
print(*out, n)
PY
  ) || { echo "lock-start: the shots could not be read ($mood)" >&2; exit 2; }
  read -r first last n <<<"$verdict"
  ((first == 0 && last == 0)) || { echo "lock-start: the $mood screen is not the scene — $first pixels off it at once, $last a second later (×$n)" >&2; exit 1; }
  said+=("$mood in $ms ms")
done
echo "lock-start: held — the scene ×$n, not a pixel off it at once nor a second later: ${said[*]}"
