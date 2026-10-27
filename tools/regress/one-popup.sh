#!/usr/bin/env bash
# tools/regress/one-popup.sh — never again (r27-13a, bug 8: "make sure only 1 is open at a time
# and test it all possible combos"): every ordered pair of ten popups — Super+C U N V X A W R /
# Space — the first opened, then the second: one popup on the screen, always the second, at its
# own place (its box the same whatever came before it). Headless (tools/kit.sh, the real GPU);
# about ten minutes.
#   bash tools/regress/one-popup.sh [KIT OPTION…]
# Exit 0 held · 1 broken (each pair that broke it, said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-popup.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
keys=(c u n v x a w r slash space)
{
  echo "panel; warm; nap 1"; echo "at 300 700"
  for a in "${keys[@]}"; do for b in "${keys[@]}"; do
    [[ $a == "$b" ]] && continue
    echo "chord logo $a; nap 1.2"; echo "chord logo $b; nap 1.2"; echo "shot $a-then-$b"
    echo "chord logo 2; nap 0.4; chord logo 1; nap 0.8"
  done; done
} >"$out/play.sh"
bash "$here/../kit.sh" --theme dark "$@" --time 800 --out "$out" --play "$out/play.sh" play >"$out/kit.log" 2>&1 || { echo "one-popup: the kit failed: $(tail -n 2 "$out/kit.log")" >&2; exit 2; }
python3 -I - "$out" "$here/shots.py" <<'PY'
import collections, glob, importlib.util, os, sys
spec = importlib.util.spec_from_file_location("shots", sys.argv[2]); s = importlib.util.module_from_spec(spec); spec.loader.exec_module(s)
by_second, bad = collections.defaultdict(collections.Counter), []
shots = sorted(glob.glob(os.path.join(sys.argv[1], "*-then-*.png")))
for f in shots:
    name = os.path.basename(f)[:-4]; b = s.popups(f)
    if len(b) != 1:
        bad.append(f"{name}: {len(b)} popups")
    else:
        by_second[name.split("-then-")[1]][b[0]] += 1
for second, boxes in by_second.items():
    if len(boxes) > 1:
        bad.append(f"…-then-{second}: not always at its own place ({dict(boxes)})")
if len(shots) != 90:
    bad.append(f"{len(shots)} shots, not 90")
print("\n".join(bad) if bad else f"one-popup: held — 90 pairs, one popup each, the second at its own place")
sys.exit(1 if bad else 0)
PY
