#!/usr/bin/env bash
# tools/regress/lock-gate.sh — the lock's gate (the owner, 4 Nov: "he faces me; a secret key opens his mouth; I type;
# he closes his mouth like he ate it"; the same for the angel): the installed lock in a headless kit, both moods —
# shut at rest, a key does nothing, Tab opens it, keys show as marks in it, Enter shuts it, a wrong word (the kit's
# PAM says no to all) opens it again; the screens dark, Tab lights them onto the gate already opening.
#   bash tools/regress/lock-gate.sh [KIT OPTION…]
#   LOCK_HOME=DIR …   the lock's files before they are applied (as tools/regress/lock-start.sh)
# Exit 0 held · 1 broken (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-gate.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
src=${LOCK_HOME:-$HOME}
grep -q '^gate ' "$src/.local/share/fedokawaii/dark/lock-scene.txt" 2>/dev/null \
  || { echo "lock-gate: no gate in the scene ($src): fedokawaii apply" >&2; exit 2; }
cat >"$out/play.sh" <<'PLAY'
mkdir -p "$HOME/.local/share/fedokawaii" "$HOME/.local/lib" "$KIT_OUT/stub"
ln -s "$REAL/.local/share/fedokawaii/dark" "$REAL/.local/share/fedokawaii/light" "$HOME/.local/share/fedokawaii/"
ln -s "$REAL/.local/lib/fedokawaii" "$HOME/.local/lib/fedokawaii"
if [[ $REAL != "$CALLER" ]]; then
  cp "$REAL/.config/fedokawaii/lock.ui" "$HOME/.config/fedokawaii/lock.ui"
  for t in dark light; do cp "$REAL/.config/fedokawaii/themes/$t/gtklock.css" "$HOME/.config/fedokawaii/themes/$t/"; done
fi
printf '#!/bin/sh\nexit 0\n' >"$KIT_OUT/stub/logger"; chmod +x "$KIT_OUT/stub/logger"
PATH="$KIT_OUT/stub:$PATH" KAWA_LOCK_SLEEP=0 kawa-lock >"$KIT_OUT/kawa-lock.log" 2>&1
nap 1; shot shut
text "xy"; nap 0.3; shot typed-shut
key Tab; nap 0.7; shot open
text "abc"; nap 0.3; shot typed
key Return; nap 0.6; shot eaten
nap 2.5; shot after
key Escape; nap 0.7; printf 'off\n' >"$XDG_RUNTIME_DIR/kawa-screens"; touch -d '-1 minute' "$XDG_RUNTIME_DIR/kawa-screens"
key Tab; nap 0.7; shot dark-tab
PLAY
sed -i "1i REAL=$src CALLER=$HOME" "$out/play.sh"
for mood in dark light; do
  bash "$here/../kit.sh" --theme "$mood" --time 40 "$@" --out "$out/$mood" --play "$out/play.sh" play >"$out/$mood.log" 2>&1 \
    || { echo "lock-gate: the kit failed ($mood): $(tail -n 2 "$out/$mood.log")" >&2; exit 2; }
done
python3 -I - "$out" "$src" <<'PY_END'
import sys
import numpy as np
from PIL import Image
out, src = sys.argv[1:]
bad = []
for mood in ("dark", "light"):
    kv, anims = {}, []
    for line in open(f"{src}/.local/share/fedokawaii/{mood}/lock-scene.txt"):
        w = line.split("#")[0].split()
        if w and w[0] == "anim":
            anims.append(tuple(map(int, w[2:6])))
        elif w:
            kv[w[0]] = w[1:]
    gx, gy, gw, gh, gn = map(int, kv["gate"])
    ms = int(kv.get("markscale", ["1"])[0])
    k = 1920 // int(kv["size"][0])           # (the scene's pixel on the 1080p screen)
    frames = np.asarray(Image.open(f"{src}/.local/share/fedokawaii/{mood}/lock-gate.png").convert("RGB"))
    still = np.ones((gh, gw), bool)          # (what the scene's life moves over the gate left out)
    for ax, ay, aw, ah in anims:
        still[max(ay - gy, 0):max(ay + ah - gy, 0), max(ax - gx, 0):max(ax + aw - gx, 0)] = False
    def same(n, f, dx=0):                    # (the row's marks and the caret left out: most of its pixels)
        a = np.asarray(Image.open(f"{out}/{mood}/{n}.png").convert("RGB"))
        got = a[k * gy:k * (gy + gh):k, k * (gx + dx):k * (gx + dx + gw):k]
        return float((got == frames[:gh, f * gw:(f + 1) * gw]).all(axis=2)[still].mean())
    want = {"shut": 0, "typed-shut": 0, "open": gn - 1, "typed": gn - 1, "after": gn - 1, "dark-tab": gn - 1}
    for n, f in want.items():
        v = same(n, f)
        if v < 0.97:
            bad.append(f"{mood} {n}: {v:.1%} of the gate is its frame {f}")
    # (eaten: shut, or already in the wrong word's shake, a pixel aside, or spat open again: the kit's PAM says no at once)
    v = max(same("eaten", f, dx) for f in (0, gn - 1) for dx in (-ms, 0, ms))
    if v < 0.97:
        bad.append(f"{mood} eaten: {v:.1%} of the gate is shut or spat open")
print("lock-gate: " + ("; ".join(bad) if bad else "held — shut at rest, a key nothing, Tab open, Enter shut, a wrong word open again, Tab on dark screens open, both moods"))
sys.exit(1 if bad else 0)
PY_END
