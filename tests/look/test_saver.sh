#!/usr/bin/env bash
# tests/look/test_saver.sh — kawa-saver, the screensaver (src/kawa-saver, C): built here as
# theme.sh builds it (when this machine has cc and Wayland's headers), then everything it
# decides before it shows — switched off (the lock alone), the lock already up, one at a time,
# its colours —, what it draws, measured from render.c's frames (the same world with no screen),
# its source's promises (input held and never passed on, the lock behind it); and kawa-idle,
# which starts it: never while something plays. On a screen: tools/regress/saver-lock.sh, saver-dark.sh.
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"
SRC=$REPO/src/kawa-saver

case_ "the sources: built as theme.sh builds it, without a warning (and the world with no screen, for the rest of this test)"
look
if command -v cc >/dev/null && pkg-config --exists wayland-client wayland-scanner wayland-protocols libpng 2>/dev/null; then
  B=$TMP/build; mkdir -p "$B"; cp "$SRC"/* "$B/"
  make -s -C "$B" O="$B" >"$TMP/make.log" 2>&1 && _ok || _no "it does not build: $(head -n 5 "$TMP/make.log")"
  make -s -C "$B" O="$B" render >>"$TMP/make.log" 2>&1 && _ok || _no "the renderer does not build: $(head -n 5 "$TMP/make.log")"
  lacks "$(cat "$TMP/make.log")" "warning"
  SAVER=$B/kawa-saver RENDER=$B/kawa-saver-render
else
  echo "  (no cc or Wayland headers here: built by theme.sh only)"; SAVER="" RENDER=""
fi
grep -q 'TOOLS=(.*kawa-saver' "$REPO/theme.sh" && _ok || _no "theme.sh does not build it"
case_ "no kanji in it: he keeps them to the stamps, the lock's quote and the day; no sashiko, no dots left"
eq "$(python3 -I -c '
import sys, unicodedata
print("".join(c for f in sys.argv[1:] for c in open(f, encoding="utf-8").read() if unicodedata.east_asian_width(c) == "W"))' "$SRC/kawa-saver.c" "$SRC/world.h" "$SRC/render.c")" ""
for w in hitomezashi sashiko sew_step stitch_frame glyphs.h; do lacks "$(cat "$SRC/kawa-saver.c" "$SRC/world.h" "$SRC/Makefile")" "$w"; done

if [[ -n $SAVER ]]; then
  saver() { env -u WAYLAND_DISPLAY -u WAYLAND_SOCKET "$SAVER" "$@"; }
  W=$HOME/.local/state/fedokawaii/saver
  config .config/fedokawaii/themes .local/share/fedokawaii/dark .local/share/fedokawaii/light
  ln -sfn themes/dark "$HOME/.config/fedokawaii/current"

  stub kawa-lock                                    # (the lock behind it: a stand-in)
  case_ "--help, and wrong use: exit 2"
  rc 0 saver --help; has "$(saver --help)" "any input ends it"
  rc 2 saver --bogus; rc 2 saver --pace 0; rc 2 saver --idle 10

  case_ "the one transition is dwl's now (kawa-wash): no --wash here, no grim"
  rc 2 saver --wash
  src=$(cat "$SRC/kawa-saver.c" "$SRC/world.h")
  lacks "$src" "wash_frame"; lacks "$src" '"grim"'
  case_ "--idle (away 15 min): switched off in quick settings, the lock alone at once"
  mkdir -p "${W%/*}"; echo off >"$W"
  rc 0 saver --idle; called '^kawa-lock $'
  case_ "--idle, but it cannot show (no screen here): said — and the lock comes all the same"
  echo on >"$W"; reset_calls
  out=$(saver --idle 2>&1); has "$out" "no Wayland session"; called '^kawa-lock $'
  case_ "a look at it (no --idle) that cannot show: said, exit 1, nothing locks"
  reset_calls; out=$(saver 2>&1); eq "$?" 1; has "$out" "no Wayland session"; not_called '^kawa-lock'
  rm -f "$W"

  case_ "locked (kawa-lock's mark): nothing to show — the lock is over everything"
  : >"$XDG_RUNTIME_DIR/kawa-lock.locked"
  out=$(saver 2>&1); eq "$?$out" 0
  rm -f "$XDG_RUNTIME_DIR/kawa-lock.locked"

  case_ "one at a time: a second one while the first shows leaves at once"
  exec 7>"$XDG_RUNTIME_DIR/kawa-saver.lock"; flock 7
  out=$(saver 2>&1); eq "$?$out" 0
  exec 7>&-

  case_ "its colours: the theme's saver.conf, all ten — missing, it says what to repair"
  names="spark_hot spark spark_cool spark_dim drift drift_lo seal seal_hot seal_cut shade "
  for t in dark light; do
    eq "$(grep -c '^[a-z0-9_]*=[0-9a-f]\{6\}$' "$REPO/configs/home/.config/fedokawaii/themes/$t/saver.conf")" 10 "$t"
    eq "$(sed -n 's/=.*//p' "$REPO/configs/home/.config/fedokawaii/themes/$t/saver.conf" | grep -v '^#' | tr '\n' ' ')" "$names" "$t: the names kawa-saver reads"
  done
  has "$(cat "$SRC/world.h")" '"spark_hot", "spark", "spark_cool", "spark_dim", "drift", "drift_lo", "seal", "seal_hot", "seal_cut", "shade",'
  rm "$HOME/.config/fedokawaii/current"
  out=$(saver 2>&1); eq "$?" 1; has "$out" "saver.conf"; has "$out" "fedokawaii repair"
  ln -sfn themes/dark "$HOME/.config/fedokawaii/current"
fi

case_ "the scene, both moods: its words built from the lock's art as it is now (tools/build-saver.py after any change to it); the painting the lock's own file, the figure asleep a patch over it"
for t in dark light; do
  d=$REPO/configs/home/.local/share/fedokawaii/$t
  python3 -I - "$d" "$t" <<'PY' && _ok || _no "$t: run tools/build-saver.py"
import hashlib, pathlib, sys
from PIL import Image
d, mood = pathlib.Path(sys.argv[1]), sys.argv[2]
kv = {}
for line in open(d / "saver-scene.txt", encoding="utf-8"):
    w = line.split("#")[0].split()
    if w:
        kv.setdefault(w[0], []).append(w[1:])
sums = hashlib.sha256()
for f in sorted(d.glob("lock-*")):
    sums.update(f.name.encode() + f.read_bytes())
assert kv["lock"][0][0] == sums.hexdigest()[:16], "the lock's art changed since"
W, H = map(int, kv["size"][0])
assert kv["wall"][0][0] == "lock-scene.png", "the painting is not the lock's own"
assert Image.open(d / kv["wall"][0][0]).size == (W, H), "the painting's size"
assert len(kv["torch"]) >= 1, "no fire"
assert len(kv["patch"]) == 1, "the sleeper: one patch"
name, x, y = kv["patch"][0][0], int(kv["patch"][0][1]), int(kv["patch"][0][2])
pw, ph = Image.open(d / name).size
assert 0 <= x and 0 <= y and x + pw <= W and y + ph <= H and pw * ph < W * H / 3, f"{name}: outside the painting, or no patch at all ({pw} x {ph})"
cx, cy = map(int, kv["centre"][0])
assert x <= cx <= x + pw + W // 4 and y <= cy + H // 3, "the patch is not on the figure"
assert 2 <= len(kv["spot"]) <= 4, "the seal's spots"
sw, sh = int(kv["seal"][0][0]), int(kv["seal"][0][1])
for sx, sy in ((int(a), int(b)) for a, b in kv["spot"]):
    assert W * .25 < sx < W * .75 and H * .25 < sy < H * .75 and abs(sx - W / 2) > W * .15, f"a spot not near a third of the frame: {sx} {sy}"
    assert 0 <= sx - sw // 2 - 56 and sx + sw // 2 + 56 <= W and 0 <= sy - sh // 2 - 56 and sy + sh // 2 + 56 <= H, f"the seal leaves the frame at {sx} {sy}"
for a in kv.get("anim", []):
    assert not a[0].startswith("lock-fig-"), "a strip tied to the figure"
    w, h, n = int(a[3]), int(a[4]), int(a[5])
    assert Image.open(d / a[0]).size == (w * n, h), f"{a[0]}: not the strip it says"
s = kv["seal"][0]
assert Image.open(d / "saver-seal.png").size == (int(s[0]) + 10 * int(s[2]), int(s[1])), "the seal's atlas"
PY
done

if [[ -n $RENDER ]]; then
  mkdir -p "$HOME/.config/fedokawaii"
  for t in dark light; do
    case_ "$t: the world with no screen: asleep the painting lies in the dark but round its fires, the figure shut-eyed and breathing, its air moves, a seal holds the time; a step costs next to nothing"
    ln -sfn "themes/$t" "$HOME/.config/fedokawaii/current"
    o=$TMP/r-$t; mkdir -p "$o"
    out=$("$RENDER" "$o" --steps 730 --every 43 --fall --wake --frames 60 --clock 09:41 --seed 3 2>&1); rc=$?
    eq "$rc" 0 "the renderer: $out"
    py=$(python3 -I - "$o" "$REPO/configs/home/.local/share/fedokawaii/$t" "$t" "$REPO/configs/home/.config/fedokawaii/themes/$t/saver.conf" <<'PY'
import glob, re, sys
import numpy as np
from PIL import Image
o, d, mood = sys.argv[1:4]
kv = {}
for line in open(f"{d}/saver-scene.txt", encoding="utf-8"):
    w = line.split("#")[0].split()
    if w:
        kv.setdefault(w[0], []).append(w[1:])
paint = np.asarray(Image.open(f"{d}/{kv['wall'][0][0]}").convert("RGB"), float)
cx, cy = map(int, kv["centre"][0])
H, W = paint.shape[:2]
a = np.asarray(Image.open(f"{o}/step-000344.ppm").convert("RGB"), float)
b = np.asarray(Image.open(f"{o}/step-000688.ppm").convert("RGB"), float)
yy, xx = np.mgrid[0:H, 0:W]
fires = np.zeros((H, W), bool)
for t in kv["torch"]:
    fires |= np.hypot(xx - int(t[0]), yy - int(t[1])) < 120
far = np.ones((H, W), bool)
for t in kv["torch"]:
    far &= np.hypot(xx - int(t[0]), yy - int(t[1])) > int(t[2])
ratio_near = a[fires].sum() / max(1, paint[fires].sum())
ratio_far = a[far].sum() / max(1, paint[far].sum())
print(f"near {ratio_near:.2f} far {a[far].mean() if mood == 'dark' else ratio_far:.2f}")
moved = (np.abs(a - b).sum(-1) > 12).mean()
print(f"moved {moved:.4f}")
# the sleeper: the patch on the frame, not the lock's eyes; its middle lit by its own breath, dim, never black
pn, px, py = kv["patch"][0][0], int(kv["patch"][0][1]), int(kv["patch"][0][2])
patch = np.asarray(Image.open(f"{d}/{pn}").convert("RGB"), float)
lock_there = paint[py:py + patch.shape[0], px:px + patch.shape[1]]
assert (np.abs(patch - lock_there).sum(-1) > 30).mean() > .01, "the patch is the lock's own picture"
m = a[cy - 60:cy + 60, cx - 120:cx + 120].mean()
print(f"sleeper {m / max(1, paint[cy - 60:cy + 60, cx - 120:cx + 120].mean()):.2f}")
# the breath: the figure's light at the middle, over a breath
bs = [np.asarray(Image.open(f).convert("RGB"), float)[cy - 60:cy + 60, cx - 120:cx + 120].mean() for f in sorted(glob.glob(f"{o}/step-*.ppm"))]
print(f"breath {max(bs) - min(bs):.2f}")
# the seal: its ink, and through its digits the painting
ink = np.array([int(v, 16) for v in re.findall("..", re.search(r"^seal=(\w+)", open(sys.argv[4]).read(), re.M).group(1))], float)
red = (np.abs(b - ink).sum(-1) < 40).mean() * W * H
print(f"seal {red:.0f}")
fall = sorted(glob.glob(f"{o}/fall-*.ppm"))
wake = sorted(glob.glob(f"{o}/wake-*.ppm"))
key = lambda f: (np.asarray(Image.open(f).convert("RGB")) == [255, 0, 255]).all(-1).mean()
print(f"fall {key(fall[0]):.3f} {key(fall[-1]):.3f}")
print(f"wake {key(wake[0]):.3f} {key(wake[-1]):.3f}")
PY
)
    read -r _ near _ far <<<"$(sed -n 's/^near/near/p' <<<"$py")"
    if [[ $t == dark ]]; then
      python3 -I -c "import sys; n, f = float(sys.argv[1]), float(sys.argv[2]); sys.exit(0 if n > 0.85 and f < 32 else 1)" "$near" "$far" && _ok || _no "the dark: near the fire $near of the painting's light, far from it $far of 255 (want > 0.85, < 32)"
    else
      python3 -I -c "import sys; n, f = float(sys.argv[1]), float(sys.argv[2]); sys.exit(0 if n > 0.9 and 0.6 < f < 0.95 else 1)" "$near" "$far" && _ok || _no "the light: near the lantern $near of the painting's light, far from it $far (want > 0.9, 0.6–0.95)"
    fi
    read -r _ moved <<<"$(sed -n 's/^moved/moved/p' <<<"$py")"
    python3 -I -c "import sys; sys.exit(0 if float(sys.argv[1]) > 0.0005 else 1)" "$moved" && _ok || _no "nothing moved between two moments ($moved of the screen)"
    read -r _ f0 f1 <<<"$(sed -n 's/^fall/fall/p' <<<"$py")"
    python3 -I -c "import sys; a, b = float(sys.argv[1]), float(sys.argv[2]); sys.exit(0 if a > 0.95 and b < 0.01 else 1)" "$f0" "$f1" && _ok || _no "the fall: from nothing ($f0 clear) to the painting whole ($f1 clear)"
    read -r _ w0 w1 <<<"$(sed -n 's/^wake/wake/p' <<<"$py")"
    python3 -I -c "import sys; a, b = float(sys.argv[1]), float(sys.argv[2]); sys.exit(0 if a < 0.01 and b > 0.9 else 1)" "$w0" "$w1" && _ok || _no "the wake: from the painting whole ($w0 clear) to the lock all clear of it ($w1 clear)"
    read -r _ sleeper <<<"$(sed -n 's/^sleeper/sleeper/p' <<<"$py")"
    python3 -I -c "import sys; v = float(sys.argv[1]); sys.exit(0 if 0.15 < v < 0.75 else 1)" "$sleeper" && _ok || _no "the sleeper: its middle at $sleeper of the painting's light, not dim, or lost"
    read -r _ breath <<<"$(sed -n 's/^breath/breath/p' <<<"$py")"
    python3 -I -c "import sys; sys.exit(0 if float(sys.argv[1]) > 0.8 else 1)" "$breath" && _ok || _no "the sleeper does not breathe ($breath levels over a breath)"
    read -r _ red <<<"$(sed -n 's/^seal/seal/p' <<<"$py")"
    ((red > 10000)) && _ok || _no "no seal on the frame ($red pixels of its ink)"
    # the seal: a minute on, stamped elsewhere, across the frame, each near a third of it
    seals=$(grep '^seal ' <<<"$out")
    eq "$(wc -l <<<"$seals")" 2 "730 steps from 09:41: two stamps ($seals)"
    has "$seals" "seal 0941 "; has "$seals" "seal 0942 "
    python3 -I - "$REPO/configs/home/.local/share/fedokawaii/$t/saver-scene.txt" "$seals" <<'PY' && _ok || _no "the seal does not move across the frame, or leaves its spots: $seals"
import math, sys
spots, sw, sh = [], 0, 0
for line in open(sys.argv[1], encoding="utf-8"):
    w = line.split()
    if w and w[0] == "spot":
        spots.append((int(w[1]), int(w[2])))
    if w and w[0] == "seal":
        sw, sh = int(w[1]), int(w[2])
pts = [tuple(map(int, l.split()[2:4])) for l in sys.argv[2].splitlines()]
assert math.dist(pts[0], pts[1]) > 300
for x, y in pts:
    assert min(math.dist((x + sw // 2, y + sh // 2), s) for s in spots) < 58
PY
    us=$(sed -n 's/^a step: \([0-9]*\) µs.*/\1/p' <<<"$out")
    ((us < 4000)) && _ok || _no "a step costs $us µs on average"
  done
fi

case_ "input: the keyboard held while it shows, every key and button waited out, any of them ends it"
sc=$(cat "$SRC/kawa-saver.c")
has "$sc" "zwlr_layer_surface_v1_set_keyboard_interactivity(o->layer, 1)"
has "$sc" "ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY"
has "$sc" "if (t - leave_at > (idle_mode ? 15000 : 3000))" "never held for good: 3 s, 15 s waiting for the lock"
has "$sc" "if (held == 0)" "without a lock: gone once every key is up"
for f in kb_key pt_button pt_axis pt_motion; do grep -A12 "^static void $f" "$SRC/kawa-saver.c" | grep -q leave_now && _ok || _no "$f does not end it"; done

case_ "--idle: the lock started once the painting covers the screen (under it: dwl keeps the saver over the lock), so the first input only opens the painting onto a lock already up; one not up yet started at the first input, and the world wakes only once it is (no key slips through)"
m=$(sed -n '/^int main/,/^}/p' "$SRC/kawa-saver.c")
grep -A3 'if (lock_due && t >= lock_due) {' <<<"$m" | grep -q 'lock_due = 0;' && grep -A4 'if (lock_due && t >= lock_due) {' <<<"$m" | grep -q 'lock_start();' && _ok || _no "--idle does not lock as it covers the screen"
has "$m" 'if (locked() && !idle_mode)' "--idle while locked already: the saver over the lock"
has "$m" 'if (lock_up() && !falling && t >= wake_from) {' "the world wakes only over a lock that is up"
has "$m" 'if (!idle_mode && t >= next_look) {' "its own lock never ends it"
grep -A9 '^static void leave_now' "$SRC/kawa-saver.c" | grep -q 'if (idle_mode && !lock_started)' && _ok || _no "leave_now: no --idle branch"
grep -A9 '^static void leave_now' "$SRC/kawa-saver.c" | grep -q 'lock_start();' && _ok || _no "the first input does not start the lock"
b=$(sed -n '/^static void lock_start(void)$/,/^}/p' "$SRC/kawa-saver.c")
has "$b" 'execlp("kawa-lock", "kawa-lock", (char *)NULL);'; lacks "$b" "waitpid" "started, not waited for (the painting stays up meanwhile)"
has "$(sed -n '/^static bool lock_up(void)$/,/^}/p' "$SRC/kawa-saver.c")" "waitpid(lock_pid, NULL, WNOHANG)"
case_ "over the lock: opaque while it sleeps (nothing under it drawn, no frames for the lock), clear as it opens; the screens dark: no steps, no frames"
has "$sc" 'wl_surface_set_opaque_region(o->surface, r);'; has "$sc" 'wl_surface_set_opaque_region(o->surface, NULL);'
has "$(sed -n '/^static void wake_begin/,/^}/p' "$SRC/kawa-saver.c")" "opaque(false);"
has "$m" 'if (!dark && t >= next) {' "no step in the dark"
has "$m" 'dark ? 1000' "a look a second, no more, in the dark"
has "$(sed -n '/^static void leave_now/,/^}/p' "$SRC/kawa-saver.c")" 'screens_dark(leave_at) ? WOKEN_MS : 0' "screens lit by the key: the monitor finds its signal before the world wakes"

# ── kawa-idle: away 15 min the screensaver (and the lock), 30 min dark — never while playing ──
look
argv kawa-saver; argv kawa-lock
n=$TMP/n
stub playerctl 'c=$(cat "'"$n"'" 2>/dev/null || echo 0); echo $((c + 1)) >"'"$n"'"; [ "$c" -lt "${PLAYING:-0}" ] && echo Playing || echo Paused'
stub systemd-inhibit '[ -e "$FAKE_TMP/inhibit" ] && echo "helium 1000 me 4242 helium idle Playing video block"; exit 0'
argv sleep
case_ "nothing playing: away runs the screensaver (--idle), dark the screens off"
rc 0 kawa-idle away; args_eq kawa-saver 1 --idle
rc 0 kawa-idle dark; args_eq kawa-lock 1 --screens off
eq "$(ncalls sleep)" 0 "no wait"
case_ "music playing (MPRIS): it waits, a look every 30 s, and goes on once it stops"
look; argv kawa-saver; argv kawa-lock; argv sleep; n=$TMP/n
stub playerctl 'c=$(cat "'"$n"'" 2>/dev/null || echo 0); echo $((c + 1)) >"'"$n"'"; [ "$c" -lt 2 ] && echo Playing || echo Paused'
stub systemd-inhibit
rc 0 kawa-idle away
eq "$(ncalls sleep)" 2 "two looks while it played"; args_eq sleep 1 30; args_eq kawa-saver 1 --idle
case_ "an idle lock in logind (systemd-inhibit --what=idle): it waits too"
look; argv kawa-saver; argv kawa-lock
stub playerctl; : >"$TMP/inhibit"
stub systemd-inhibit '[ -e "'"$TMP"'/inhibit" ] && echo "helium 1000 me 4242 helium idle Playing video block"; exit 0'
stub sleep 'rm -f "'"$TMP"'/inhibit"'
rc 0 kawa-idle dark; args_eq kawa-lock 1 --screens off; called '^sleep 30$'
case_ "back (a key, a move): a wait still running ends there — nothing shows, nothing locks"
look; argv kawa-saver
stub playerctl 'echo Playing'; stub systemd-inhibit; stub sleep '/bin/sleep 0.1'
kawa-idle away & p=$!
for _ in {1..20}; do grep -q '^sleep' "$CALLS" && break; /bin/sleep 0.1; done
rc 0 kawa-idle back
for _ in {1..30}; do kill -0 "$p" 2>/dev/null || break; /bin/sleep 0.1; done
kill -0 "$p" 2>/dev/null && { _no "the wait outlived the return"; kill "$p"; } || _ok
eq "$(ncalls kawa-saver)" 0
case_ "one of each at a time; wrong use: exit 2"
rc 2 kawa-idle; rc 2 kawa-idle soon; rc 0 kawa-idle --help

done_
