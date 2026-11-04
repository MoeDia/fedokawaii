#!/usr/bin/env bash
# tools/regress/saver-keys.sh — the screensaver's other ways out, on a real compositor (tools/kit.sh): a look at it (no --idle): a
# key ends it, the desktop as it was, nothing locks, the key reaches no window; away (--idle), a key while it is still coming over
# the screen: the lock comes all the same and the key is not typed; another screen shape (1280 × 1024): it fills it.
#   bash tools/regress/saver-keys.sh [KIT OPTION…]
#   LOCK_HOME=DIR …   the lock's files before they are applied (as tools/regress/lock-start.sh)
# Exit 0 held · 1 broken (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-saverkeys.XXXXXX)
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
gone() { local st; st=$(cat "/proc/$1/stat" 2>/dev/null); st=${st##*) }; [[ -z $st || ${st%% *} == Z ]]; }
shot before
# a look at it
kawa-saver >"$KIT_OUT/look.log" 2>&1 & S=$!
nap 2.5; shot look
key space; nap 0.8; shot after-look
gone "$S" && say "look: gone" || say "look: still there"
[[ -e $XDG_RUNTIME_DIR/kawa-lock.locked ]] && say "look: locked" || say "look: not locked"
# another shape
wlr-randr --output HEADLESS-1 --custom-mode 1280x1024 >/dev/null 2>&1; nap 0.8
kawa-saver >"$KIT_OUT/shape.log" 2>&1 & S=$!
nap 2.5; shot shape
key space; nap 0.8
gone "$S" && say "shape: gone" || say "shape: still there"
wlr-randr --output HEADLESS-1 --custom-mode 1920x1080@144Hz >/dev/null 2>&1; nap 0.8
# away, a key while it comes
PATH="$KIT_OUT/stub:$PATH" KAWA_LOCK_SLEEP=0 kawa-saver --idle >"$KIT_OUT/idle.log" 2>&1 & S=$!
nap 0.5
key space
for _ in {1..60}; do [[ -e $XDG_RUNTIME_DIR/kawa-lock.locked ]] && gone "$S" && break; nap 0.2; done   # (a loaded machine: gtklock takes its time)
shot fall-key
gone "$S" && say "fall: gone" || say "fall: still there"
[[ -e $XDG_RUNTIME_DIR/kawa-lock.locked ]] && say "fall: locked" || say "fall: not locked"
PLAY
sed -i "1i REAL=$src CALLER=$HOME" "$out/play.sh"
bash "$here/../kit.sh" --theme dark --time 60 "$@" --out "$out" --play "$out/play.sh" play >"$out/kit.log" 2>&1 || { echo "saver-keys: the kit failed: $(tail -n 2 "$out/kit.log")" >&2; exit 2; }
log=$(cat "$out/play.log")
for want in "look: gone" "look: not locked" "shape: gone" "fall: gone" "fall: locked"; do
  [[ $log == *"$want"* ]] || { echo "saver-keys: wanted [$want], the play says: $log" >&2; exit 1; }
done
verdict=$(python3 -I - "$out" <<'PY'
import sys
import numpy as np
from PIL import Image
o = sys.argv[1]
open_ = lambda n: np.asarray(Image.open(f"{o}/{n}.png").convert("RGB"), int)
b, l, a, sh = open_("before"), open_("look"), open_("after-look"), open_("shape")
print(f"{(np.abs(b - l).sum(-1) > 30).mean():.3f} {(np.abs(b - a).sum(-1) > 30).mean():.3f} {sh.shape[1]}x{sh.shape[0]} {(sh.sum(-1) == 0).mean():.3f}")
PY
) || { echo "saver-keys: the shots could not be read" >&2; exit 2; }
read -r look_moved after_moved size black <<<"$verdict"
python3 -I -c 'import sys; sys.exit(0 if float(sys.argv[1]) > 0.3 else 1)' "$look_moved" || { echo "saver-keys: the look did not show ($look_moved of the screen changed)" >&2; exit 1; }
python3 -I -c 'import sys; sys.exit(0 if float(sys.argv[1]) < 0.02 else 1)' "$after_moved" || { echo "saver-keys: the desktop not as it was after a look ($after_moved of it changed)" >&2; exit 1; }
[[ $size == 1280x1024 ]] || { echo "saver-keys: the shape's shot is $size" >&2; exit 2; }
python3 -I -c 'import sys; sys.exit(0 if float(sys.argv[1]) < 0.05 else 1)' "$black" || { echo "saver-keys: on another shape it leaves $black of the screen black" >&2; exit 1; }
echo "saver-keys: held — a look ends on a key and nothing locks; a key during the fall: the lock; another shape filled"
