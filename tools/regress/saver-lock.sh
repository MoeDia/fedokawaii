#!/usr/bin/env bash
# tools/regress/saver-lock.sh — away and back (bug 1, "no extra wake press lost"): the screensaver as
# swayidle starts it after 15 minutes (kawa-saver --idle) shows with the lock under it; the first key
# only washes the cloth off a lock already up — the scene on the screen, nothing typed —, and the
# keys after it go into the password at once: two keys, two marks in the scene's row. Headless
# (tools/kit.sh, the real GPU), the installed saver, lock and module; logger stood in for.
#   bash tools/regress/saver-lock.sh [KIT OPTION…]
#   LOCK_HOME=DIR …   the lock's files before they are applied (as tools/regress/lock-start.sh)
# Exit 0 held · 1 broken (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-saver.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
src=${LOCK_HOME:-$HOME} art=${LOCK_HOME:-$HOME}/.local/share/fedokawaii/dark
[[ -s $art/lock-scene.txt ]] || { echo "saver-lock: no scene in $art (fedokawaii apply)" >&2; exit 1; }
cat >"$out/play.sh" <<'PLAY'
mkdir -p "$HOME/.local/share/fedokawaii" "$HOME/.local/lib" "$KIT_OUT/stub"
ln -s "$REAL/.local/share/fedokawaii/dark" "$REAL/.local/share/fedokawaii/light" "$HOME/.local/share/fedokawaii/"
ln -s "$REAL/.local/lib/fedokawaii" "$HOME/.local/lib/fedokawaii"
if [[ $REAL != "$CALLER" ]]; then
  cp "$REAL/.config/fedokawaii/lock.ui" "$HOME/.config/fedokawaii/lock.ui"
  for t in dark light; do cp "$REAL/.config/fedokawaii/themes/$t/"{gtklock.css,saver.conf} "$HOME/.config/fedokawaii/themes/$t/"; done
fi
printf '#!/bin/sh\nexit 0\n' >"$KIT_OUT/stub/logger"; chmod +x "$KIT_OUT/stub/logger"
PATH="$KIT_OUT/stub:$PATH" KAWA_LOCK_SLEEP=0 kawa-saver --idle >"$KIT_OUT/saver.log" 2>&1 &
nap 3; shot saver
key space; nap 1.2; shot woke
# (a gate in the scene: the secret key opens it first, as a person does)
grep -q '^gate ' "$HOME/.local/share/fedokawaii/dark/lock-scene.txt" && { key Tab; nap 0.7; }
shot open
text "ab"; nap 0.3; shot typed
PLAY
sed -i "1i REAL=$src CALLER=$HOME" "$out/play.sh"
bash "$here/../kit.sh" --theme dark "$@" --out "$out" --play "$out/play.sh" play >"$out/kit.log" 2>&1 || { echo "saver-lock: the kit failed: $(tail -n 2 "$out/kit.log")" >&2; exit 2; }
for s in saver woke open typed; do [[ -s $out/$s.png ]] || { echo "saver-lock: no shot ($s)" >&2; exit 2; }; done
# (the still part of the scene against the shot, and the marks in its row: the scene's own words)
verdict=$(python3 -I - "$out" "$art" "$src/.config/fedokawaii/themes/dark/saver.conf" <<'PY'
import re
import sys
import numpy as np
from PIL import Image
out, art = sys.argv[1], sys.argv[2]
conf = open(sys.argv[3]).read()
img = Image.open(f"{art}/lock-scene.png").convert("RGB")
kv = {}
for line in open(f"{art}/lock-scene.txt"):
    w = line.split("#")[0].split()
    if w:
        kv.setdefault(w[0], []).append(w[1:])
rx, ry, pitch, rn = map(int, kv["row"][0])
mw, mh = (int(v) for v in kv["marks"][0][:2])
gate = [int(v) for v in kv["gate"][0]]
want = np.asarray(img)
def look(name):
    got = np.asarray(Image.open(f"{out}/{name}.png").convert("RGB"))
    # (what is still: all but the flames, the strips, the gate and the row)
    keep = np.ones(want.shape[:2], bool)
    fw, fh = (int(v) for v in kv["frames"][0][:2])
    for fx, fy in (map(int, f) for f in kv.get("flame", [])):
        keep[fy:fy + fh, fx:fx + fw] = False
    for a in kv.get("anim", []):
        x, y, w, h = (int(v) for v in a[1:5])
        keep[y:y + h, x:x + w] = False
    keep[gate[1]:gate[1] + gate[3], gate[0]:gate[0] + gate[2]] = False
    keep[ry - mh:ry + mh, rx - mw:rx + pitch * rn + mw] = False
    same = (np.abs(got.astype(int) - want).sum(-1) < 12)[keep].mean()
    # (a mark in a slot of the row: most of the slot not the open mouth it lies on; the thin caret is not one)
    marks = sum((np.abs(got[ry - mh // 2:ry + mh // 2, rx + pitch * i - mw // 2:rx + pitch * i + mw // 2].astype(int)
                        - want[ry - mh // 2:ry + mh // 2, rx + pitch * i - mw // 2:rx + pitch * i + mw // 2]).sum(-1) > 30).mean() > .15 for i in range(rn))
    return same, marks
s0, _ = look("saver"); s1, _ = look("woke"); _, m1 = look("open"); s2, m2 = look("typed")
# (the seal: its red, an area as big as it, the digits cut out; a third of the frame: tests/look/test_saver.sh)
ink = tuple(int(v, 16) for v in re.findall("..", re.search(r"^seal=(\w+)", conf, re.M).group(1)))
shot = np.asarray(Image.open(f"{out}/saver.png").convert("RGB"), int)
red = (np.abs(shot - ink).sum(-1) < 30).sum()
print(f"{s0 * 100:.0f} {s1 * 100:.2f} {m1} {s2 * 100:.2f} {m2} {red}")
PY
) || { echo "saver-lock: the shots could not be read" >&2; exit 2; }
read -r saver woke m1 typed m2 red <<<"$verdict"
((red > 10000)) || { echo "saver-lock: no seal on the screensaver ($red pixels of its ink)" >&2; exit 1; }
((${saver%.*} < 90)) || { echo "saver-lock: the screensaver did not show over the lock ($saver % of the scene showing)" >&2; exit 1; }
[[ ${woke%.*} -ge 99 ]] || { echo "saver-lock: after the first key the screen is not the lock's scene ($woke %)" >&2; exit 1; }
((m1 == 0)) || { echo "saver-lock: the key that ended the screensaver was typed ($m1 marks)" >&2; exit 1; }
((m2 == 2)) || { echo "saver-lock: two keys after it gave $m2 marks — a key was lost or doubled" >&2; exit 1; }
[[ ${typed%.*} -ge 99 ]] || { echo "saver-lock: typing moved the scene ($typed % of its still pixels)" >&2; exit 1; }
echo "saver-lock: held — the saver over the lock, the first key only washed it off, the next two typed"
