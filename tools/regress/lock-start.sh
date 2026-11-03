#!/usr/bin/env bash
# tools/regress/lock-start.sh — the lock comes up (every update proves it: lib/guard.sh
# desktop_starts): kawa-lock in a headless kit — gtklock with its layout and kawa-lockmod, the
# installed ones — locks the session within 3 s, and the screen shows the mood's scene at whole
# pixels, pixel for pixel against lock-scene.png (the flames and the password's row aside: they
# move), not the desktop and not gtklock's plain line. Nothing is written to the journal (logger
# stood in for). Headless (tools/kit.sh, the real GPU).
#   bash tools/regress/lock-start.sh [KIT OPTION…]
#   LOCK_HOME=DIR …   a home of the lock's files before they are applied: its share/fedokawaii,
#                     lib/fedokawaii, lock.ui and the themes' gtklock.css (with --bin bin: kawa-lock)
# Exit 0 held · 1 broken (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-lock.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
src=${LOCK_HOME:-$HOME} art=${LOCK_HOME:-$HOME}/.local/share/fedokawaii/dark
[[ -s $art/lock-scene.png && -s $art/lock-scene.txt && -s $art/lock-flame.png ]] || { echo "lock-start: no scene in $art (fedokawaii apply)" >&2; exit 1; }
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
say "locked $? $(( (${EPOCHREALTIME/[.,]/} - t0) / 1000 ))"
nap 1; shot lock
PLAY
sed -i "1i REAL=$src CALLER=$HOME" "$out/play.sh"
bash "$here/../kit.sh" --theme dark "$@" --out "$out" --play "$out/play.sh" play >"$out/kit.log" 2>&1 || { echo "lock-start: the kit failed: $(tail -n 2 "$out/kit.log")" >&2; exit 2; }
read -r _ rc ms <"$out/play.log" 2>/dev/null || { echo "lock-start: the play said nothing" >&2; exit 2; }
((rc == 0)) || { echo "lock-start: kawa-lock failed (exit $rc): $(tail -n 1 "$out/kawa-lock.log")" >&2; exit 1; }
((ms <= 3000)) || { echo "lock-start: locked only after $ms ms" >&2; exit 1; }
[[ -s $out/lock.png ]] || { echo "lock-start: no shot" >&2; exit 2; }
# (the shot against the scene at the screen's whole scale, its moving parts left out)
verdict=$(python3 -I - "$out/lock.png" "$art" <<'PY'
import sys
import numpy as np
from PIL import Image
shot = np.asarray(Image.open(sys.argv[1]).convert("RGB"))
img = Image.open(f"{sys.argv[2]}/lock-scene.png").convert("RGB")
kv = {}
for line in open(f"{sys.argv[2]}/lock-scene.txt"):
    w = line.split("#")[0].split()
    if w:
        kv.setdefault(w[0], []).append([int(v) if v.isdigit() else v for v in w[1:]])
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
same = (got == want).all(axis=2)[keep].mean()
print(f"{same * 100:.2f} {n}")
PY
) || { echo "lock-start: the shot could not be read" >&2; exit 2; }
read -r pct n <<<"$verdict"
[[ ${pct%.*} -ge 99 ]] || { echo "lock-start: the screen is not the scene — $pct % of its still pixels match (×$n)" >&2; exit 1; }
echo "lock-start: held — locked in $ms ms, the dark scene ×$n on the screen ($pct % of its still pixels exact)"
