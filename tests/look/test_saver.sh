#!/usr/bin/env bash
# tests/look/test_saver.sh — kawa-saver, the screensaver (src/kawa-saver, C): built here as
# theme.sh builds it (when this machine has cc and Wayland's headers), then everything it
# decides before it shows — switched off (the lock alone), the lock already up, one at a time,
# its colours — and its source's promises (input held and never passed on, the lock behind
# it); and kawa-idle, which starts it: never while something plays.
# What it draws is seen in the renders (docs/build/render), not here: there is no screen.
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"
SRC=$REPO/src/kawa-saver

case_ "the sources: built as theme.sh builds it, without a warning"
look
if command -v cc >/dev/null && pkg-config --exists wayland-client wayland-scanner wayland-protocols 2>/dev/null; then
  B=$TMP/build; mkdir -p "$B"; cp "$SRC"/* "$B/"
  make -s -C "$B" O="$B" >"$TMP/make.log" 2>&1 && _ok || _no "it does not build: $(head -n 5 "$TMP/make.log")"
  lacks "$(cat "$TMP/make.log")" "warning"
  SAVER=$B/kawa-saver
else
  echo "  (no cc or Wayland headers here: built by theme.sh only)"; SAVER=""
fi
grep -q 'TOOLS=(.*kawa-saver' "$REPO/theme.sh" && _ok || _no "theme.sh does not build it"
glyphs=$(grep -c '^	{ "' "$SRC/glyphs.h")
k=$(sed -n 's/^SAVER_KANJI = "\([^"]*\)".*/\1/p' "$REPO/tools/build-art.py")
eq "$glyphs" "$(( $(python3 -I -c 'import sys; print(len(sys.argv[1]))' "$k") + 16 ))" "every kanji build-art.py draws, and 時 0-9 : space A P M"

if [[ -n $SAVER ]]; then
  saver() { env -u WAYLAND_DISPLAY -u WAYLAND_SOCKET "$SAVER" "$@"; }
  W=$HOME/.local/state/fedokawaii/saver
  config .config/fedokawaii/themes
  ln -sfn themes/dark "$HOME/.config/fedokawaii/current"

  stub kawa-lock                                    # (the lock behind it: a stand-in)
  case_ "--help, and wrong use: exit 2"
  rc 0 saver --help; has "$(saver --help)" "any input ends it"
  rc 2 saver --bogus; rc 2 saver --pace 0; rc 2 saver --idle 10

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

  case_ "its colours: the theme's saver.conf, all eight — missing, it says what to repair"
  for t in dark light; do
    eq "$(grep -c '^[a-z0-9_]*=[0-9a-f]\{6\}$' "$REPO/configs/home/.config/fedokawaii/themes/$t/saver.conf")" 8 "$t"
  done
  rm "$HOME/.config/fedokawaii/current"
  out=$(saver 2>&1); eq "$?" 1; has "$out" "saver.conf"; has "$out" "fedokawaii repair"
fi

case_ "input: the keyboard held while it shows, every key and button waited out, any of them ends it"
has "$(cat "$SRC/kawa-saver.c")" "zwlr_layer_surface_v1_set_keyboard_interactivity(o->layer, 1)"
has "$(cat "$SRC/kawa-saver.c")" "ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY"
has "$(cat "$SRC/kawa-saver.c")" "if (leaving && (held == 0 || t - leave_at > 3000))"
for f in kb_key pt_button pt_axis pt_motion; do grep -A12 "^static void $f" "$SRC/kawa-saver.c" | grep -q leave_now && _ok || _no "$f does not end it"; done

case_ "--idle: dismissed, the lock is brought up before the screensaver goes (no key slips through)"
has "$(cat "$SRC/kawa-saver.c")" "if (idle_mode && leaving)"
grep -B2 -A3 'if (idle_mode && leaving)' "$SRC/kawa-saver.c" | grep -q 'lock_now();' && _ok || _no "no lock before it goes"

# ── kawa-idle: away 15 min the screensaver (and the lock), 30 min dark — never while playing ──
look
argv kawa-saver; argv kawa-lock
n=$TMP/n
stub playerctl 'c=$(cat "'"$n"'" 2>/dev/null || echo 0); echo $((c + 1)) >"'"$n"'"; [ "$c" -lt "${PLAYING:-0}" ] && echo Playing || echo Paused'
stub systemd-inhibit '[ -e "$FAKE_TMP/inhibit" ] && echo "brave 1000 me 4242 brave idle Playing video block"; exit 0'
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
stub systemd-inhibit '[ -e "'"$TMP"'/inhibit" ] && echo "brave 1000 me 4242 brave idle Playing video block"; exit 0'
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
