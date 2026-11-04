#!/usr/bin/env bash
# tools/regress/refresh.sh — Super+Ctrl+R (T20r; the owner, 2 Nov: "a good refresh shortcut"): a headless kit
# with windows on three workspaces, one of them fullscreen; the bar, the notices and quick settings hung
# (SIGSTOP); one press: each is back, a new process, nothing stopped; every window where it was, to the pixel
# (all below the bar, on two workspaces, also while the bar is away); then ten presses in a row: one bar, the
# same picture.
#   bash tools/regress/refresh.sh [KIT OPTION…]   (e.g. --bin bin --repo-art before an apply)
# Exit 0 held · 1 broken (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-refresh.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
cat >"$out/play.sh" <<'PLAY_END'
press() { wtype -s 300 -M logo -M ctrl -k r -m ctrl -m logo; }
win() { foot sh -c 'seq 1 40; printf "\033[?25l"; exec sleep 300' & nap 0.9; }   # (no blinking cursor in the pictures)
panel
swayidle -w timeout 3600 true >/dev/null 2>&1 &
nap 1
win; win
chord logo 2; nap 0.7; win
chord logo 3; nap 0.7; win; chord logo f; nap 1
shot before-3
chord logo 1; nap 1.2
shot before-1
b=$(pgrep -x waybar); m=$(pgrep -x mako); p=$(pgrep -x kawa-panel)
say "old $b $m $p"
kill -STOP "$b" "$p"
press
nap 1
shot during-1
nap 5
say "new $(pgrep -x waybar | tr '\n' ' ')| $(pgrep -x kawa-panel | tr '\n' ' ')"
say "states $(for q in $(pgrep -x waybar) $(pgrep -x kawa-panel); do awk '{print $3}' /proc/$q/stat; done | tr '\n' ' ')"
shot after-1
chord logo 3; nap 1.2
shot after-3
chord logo 1; nap 1
# (the notices from here: dwl's own commands have no bus in a kit, it runs outside dbus-run-session)
pgrep -x mako >/dev/null || { mako >/dev/null 2>&1 & nap 1; }
m=$(pgrep -x mako); say "notices-old $m"
kill -STOP "$m"
rm -f "$XDG_RUNTIME_DIR/kawa-refresh.last"
kawa-refresh; say "script $?"
say "notices-new $(pgrep -x mako | tr '\n' ' ')"
say "notices-state $(awk '{print $3}' /proc/$(pgrep -xo mako)/stat)"
nap 2.5
rm -f "$XDG_RUNTIME_DIR/kawa-refresh.last"
for _ in 1 2 3 4 5 6 7 8 9 10; do wtype -M logo -M ctrl -k r -m ctrl -m logo; sleep 0.1; done
nap 6
say "mashed $(pgrep -xc waybar) $(pgrep -xc kawa-panel)"
shot mashed
PLAY_END
bash "$here/../kit.sh" --theme dark "$@" --time 200 --out "$out/k" --play "$out/play.sh" play >"$out/kit.log" 2>&1 \
  || { echo "refresh: the kit failed: $(tail -n 2 "$out/kit.log")" >&2; exit 2; }
fail=0
no() { echo "refresh: $*" >&2; fail=1; }
log=$out/k/play.log
[[ -s $log ]] || { echo "refresh: the play said nothing" >&2; exit 2; }
read -r _ ob _ op < <(grep '^old ' "$log")
IFS='|' read -r nb np < <(sed -n 's/^new //p' "$log")
for pair in "bar:$ob:$nb" "quick settings:$op:$np"; do
  IFS=: read -r name o n <<<"$pair"; n=${n// /}
  [[ -n $n ]] || { no "$name did not come back"; continue; }
  [[ $n != "$o" ]] || no "$name: still the hung process ($o)"
done
grep -q '^states .*T' "$log" && no "something is still stopped: $(grep '^states' "$log")"
mo=$(sed -n 's/^notices-old //p' "$log"); mn=$(sed -n 's/^notices-new //p' "$log"); mn=${mn// /}
[[ -n $mn && $mn != "$mo" ]] || no "the notices: hung $mo, now [$mn]"
grep -q '^notices-state [SR]' "$log" || no "the notices: $(grep '^notices-state' "$log")"
grep -q '^script 0$' "$log" || no "kawa-refresh said: $(grep '^script' "$log")"
grep -q '^mashed 1 1$' "$log" || no "ten presses: $(grep '^mashed' "$log" || echo 'no line') (one bar, one quick settings wanted)"
# (below the bar: the bar's own cells change with the clock)
same() { python3 -I - "$out/k/$1.png" "$out/k/$2.png" <<'PY'
import sys
from PIL import Image, ImageChops
a, b = (Image.open(p).convert("RGB") for p in sys.argv[1:3])
W, H = a.size
d = ImageChops.difference(a.crop((0, 40, W, H)), b.crop((0, 40, W, H))).getbbox()
print("same" if d is None else f"differs in {d} (below the bar's 40 rows)")
PY
}
for p in "before-1 during-1" "before-1 after-1" "before-3 after-3" "before-1 mashed"; do
  # shellcheck disable=SC2086  # two names
  r=$(same $p); [[ $r == same ]] || no "$p: $r"
done
((fail)) && { cat "$log" >&2; exit 1; }
echo "refresh: held — the hung bar, notices and quick settings back, new; every window where it was; ten presses, one of each"
