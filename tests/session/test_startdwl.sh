#!/usr/bin/env bash
# tests/session/test_startdwl.sh — start-dwl, the session the login starts: the environment it
# sets, dwl with the autostart, the rescue screen when dwl cannot start (repair builds it
# again: there is no second dwl to fall back on), and a second start while the desktop runs.
# dwl is a stand-in in a fake /usr/local/bin; ldd says when it lacks a library.
# Run with sh as Fedora has it (bash in its POSIX mode) and with dash where there is one.
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"

setup() {   # setup — start-dwl rendered as setup.sh installs it, its /usr/local/bin under $TMP
  sandbox
  BIN=$TMP/root/usr/local/bin; mkdir -p "$BIN" "$TMP/shbin"
  sed -e 's|@KB_LAYOUTS@|us,ara|' -e 's|@KB_TOGGLE@|grp:alt_shift_toggle|' -e "s|/usr/local/bin/dwl|$BIN/dwl|g" \
    -e "s|/etc/profile.d/fedokawaii-home.sh|$REPO/system/fedokawaii-home.sh|" "$REPO/system/start-dwl" >"$TMP/start-dwl"
  cp "$BASH" "$TMP/shbin/sh"             # bash started as sh: its POSIX mode, Fedora's /bin/sh (a copy, not a link)
  # the autostart: only says that it ran (dwl runs it through sh -c, as the real dwl does)
  mkdir -p "$HOME/.config/dwl"
  printf '#!/bin/sh\necho "autostart ran in $HOME" >>"%s/autostart.ran"\n' "$TMP" >"$HOME/.config/dwl/autostart.sh"
  chmod +x "$HOME/.config/dwl/autostart.sh"
  LOG=$HOME/.cache/dwl.log
  export KAWA_SYSFS=$TMP/sysfs; mkdir -p "$KAWA_SYSFS/class/drm"   # (no graphics card, unless gpus says)
  stub systemctl; stub bash; stub pgrep 'exit 1'; stub systemd-cat 'cat >>"$TMP/journal"'
  stub ldd 'for f; do :; done; [ -e "$f.nolib" ] && printf "\tlibwlroots-0.20.so => not found\n"; printf "\tlibc.so.6 => /lib64/libc.so.6\n"'
}
# dwl NAME BODY — a stand-in for /usr/local/bin/NAME: logs its arguments and environment, runs
# the startup command like dwl (sh -c), then BODY (exit 1: it stopped at once…)
dwl() {
  printf '#!/bin/sh\nprintf "%%s\\n" "%s $*" >>"%s"\nenv >"%s/%s.env"\n[ "$1" = -s ] && sh -c "$2" </dev/null\necho "%s said something" >&2\n%s\n' \
    "$1" "$CALLS" "$TMP" "$1" "$1" "${2:-exit 0}" >"$BIN/$1"
  chmod +x "$BIN/$1"
}
# gpus NAME[:VRAM]… — the graphics cards in the fake sysfs, each with its video memory in bytes
# (none given: a card that does not say it); a screen's socket beside them (card0-DP-1)
gpus() {
  local g; rm -rf "$KAWA_SYSFS/class/drm"; mkdir -p "$KAWA_SYSFS/class/drm/card0-DP-1"
  for g; do
    mkdir -p "$KAWA_SYSFS/class/drm/${g%%:*}/device"
    [[ $g == *:* ]] && echo "${g#*:}" >"$KAWA_SYSFS/class/drm/${g%%:*}/device/mem_info_vram_total"
  done
}
nolib() { : >"$BIN/$1.nolib"; }   # nolib NAME — ldd: NAME misses a library
envof() { grep -E "^$2=" "$TMP/$1.env" | cut -d= -f2-; }   # envof NAME VAR — what NAME was given
start() {   # start — start-dwl as the login runs it, with the shell under test ($SHL)
  local sh=$TMP/shbin/sh; [[ $SHL == dash ]] && sh=$(command -v dash)
  OUT=$("$sh" "$TMP/start-dwl" </dev/null 2>&1); RC=$?
}

SHS=(sh=bash); command -v dash >/dev/null && SHS+=(dash)
for SHL in "${SHS[@]}"; do
setup; n=" [$SHL]"

case_ "a normal login: dwl with the autostart, the session's environment, the log fresh$n"
dwl dwl; echo "the last session" >"$LOG"
start
eq "$RC" 0; called "^dwl -s $HOME/.config/dwl/autostart.sh$"; not_called "^bash"
has "$(cat "$TMP/autostart.ran")" "autostart ran in $HOME"
eq "$(envof dwl PATH)" "$HOME/.local/bin:$PATH:$HOME/.local/share/cargo/bin" "the home's .local/bin first: the kawa-* helpers; rustup's Rust last"
for v in "XDG_DATA_HOME=$HOME/.local/share" "XDG_STATE_HOME=$HOME/.local/state" "CARGO_HOME=$HOME/.local/share/cargo" \
         "RUSTUP_HOME=$HOME/.local/share/rustup" "HISTFILE=$HOME/.local/state/bash/history" "NPM_CONFIG_CACHE=$HOME/.cache/npm"; do
  eq "$(envof dwl "${v%%=*}")" "${v#*=}" "the session keeps programs' files in place: ${v%%=*}"
done
[[ -d $HOME/.local/state/bash ]] && _ok || _no "the history's folder made"
for v in XDG_SESSION_TYPE=wayland XDG_SESSION_DESKTOP=dwl XDG_CURRENT_DESKTOP=wlroots XKB_DEFAULT_LAYOUT=us,ara \
         XKB_DEFAULT_OPTIONS=grp:alt_shift_toggle "QT_QPA_PLATFORM=wayland;xcb" QT_QPA_PLATFORMTHEME=qt6ct \
         GDK_BACKEND=wayland,x11 GTK_USE_PORTAL=1 _JAVA_AWT_WM_NONREPARENTING=1 EDITOR=nvim VISUAL=nvim \
         TERMINAL=foot BROWSER=brave-origin XCURSOR_THEME=default XCURSOR_SIZE=24; do
  eq "$(envof dwl "${v%%=*}")" "${v#*=}" "${v%%=*}"
done
eq "$(envof dwl SDL_VIDEODRIVER)" "" "SDL_VIDEODRIVER not set (old SDL2 games)"
eq "$(envof dwl WLR_DRM_DEVICES)" "" "no graphics card found: WLR_DRM_DEVICES not set (wlroots picks)"
has "$(cat "$LOG")" "dwl said something"; lacks "$(cat "$LOG")" "the last session"
case_ "the session before is kept beside the new log (dwl.log.old: what a crash said)$n"
eq "$(cat "$LOG.old")" "the last session"
case_ "logged out: the graphical session ends for systemd (queued: the login screen comes back at once), its display leaves systemd's environment$n"
called "^systemctl --user --no-block stop dwl-session.target$"
called "^systemctl --user unset-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE$"
case_ "two graphics cards (the CPU's own beside a graphics card): dwl draws on the one with the most video memory$n"
dwl dwl; gpus card0:536870912 card1:17163091968; start
eq "$RC" 0; eq "$(envof dwl WLR_DRM_DEVICES)" /dev/dri/card1; has "$(cat "$LOG")" "drawing on card1, the one with the most video memory"
gpus card0:17163091968 card1:536870912; start; eq "$(envof dwl WLR_DRM_DEVICES)" /dev/dri/card0 "the card first this time"
case_ "one graphics card, its memory not said (Intel's): that one$n"
gpus card0; start; eq "$(envof dwl WLR_DRM_DEVICES)" /dev/dri/card0
case_ "two cards, neither saying its video memory: WLR_DRM_DEVICES not set, and the log says why$n"
gpus card0 card1; start; eq "$(envof dwl WLR_DRM_DEVICES)" ""; has "$(cat "$LOG")" "2 graphics cards, none saying its video memory"
case_ "start-dwl --gpu (the login screen's cage): the same card as WLR_DRM_DEVICES=…, nothing when it cannot tell — dwl not started$n"
sh=$TMP/shbin/sh; [[ $SHL == dash ]] && sh=$(command -v dash)
: >"$CALLS"; gpus card0:536870912 card1:17163091968
eq "$("$sh" "$TMP/start-dwl" --gpu 2>/dev/null)" "WLR_DRM_DEVICES=/dev/dri/card1"
gpus card0 card1; eq "$("$sh" "$TMP/start-dwl" --gpu 2>/dev/null)" ""
not_called "^dwl"; gpus
case_ "start-dwl --gpu says nothing on the console (greetd hands the login's command tty1: a line there shows at every boot and logout) — its note goes to the journal$n"
rm -f "$TMP/journal"; gpus card0:536870912 card1:17163091968
eq "$("$sh" "$TMP/start-dwl" --gpu 2>&1)" "WLR_DRM_DEVICES=/dev/dri/card1" "only the card, nothing else, on stdout and stderr together"
called "^systemd-cat -t start-dwl$"; has "$(cat "$TMP/journal")" "drawing on card1, the one with the most video memory"
gpus card0 card1; eq "$("$sh" "$TMP/start-dwl" --gpu 2>&1)" "" "nothing at all when it cannot tell"
has "$(cat "$TMP/journal")" "2 graphics cards, none saying its video memory"; gpus

case_ "no autostart (Setup without Theme): dwl alone, with upstream defaults$n"
setup; dwl dwl; rm "$HOME/.config/dwl/autostart.sh"; start
eq "$RC" 0; called "^dwl $"; [[ ! -e $TMP/autostart.ran ]] && _ok || _no "an autostart ran"

case_ "dwl stops at once (a config.h mistake): a rescue screen with its exit and what to do, a shell — not a login that loops; one try$n"
setup; dwl dwl 'exit 1'; start
has "$OUT" "The desktop could not start: dwl stopped at once (exit 1)."
has "$OUT" "fedokawaii repair"; has "$OUT" "$LOG"; has "$OUT" "Ctrl+D logs out"
has "$(cat "$LOG")" "dwl said something"; called "^bash -l$"; eq "$(grep -c '^dwl ' "$CALLS")" 1 "tried once"
case_ "dwl crashes at once (killed by a signal): the same$n"
setup; dwl dwl 'kill -KILL $$'; start
has "$OUT" "dwl stopped at once (exit 137)"; called "^bash -l$"
case_ "… and the half-started session is ended for systemd first (no portals waiting for a dead display)$n"
called "^systemctl --user stop dwl-session.target$"; called "unset-environment WAYLAND_DISPLAY"
case_ "dwl not installed: the rescue screen says so$n"
setup; start
has "$OUT" "The desktop could not start: dwl is not installed ($BIN/dwl)."; called "^bash -l$"
case_ "dwl missing a library: the rescue screen names it, dwl never run$n"
setup; dwl dwl; nolib dwl; start
has "$OUT" "dwl is missing a library (libwlroots-0.20.so)"; not_called "^dwl -s"; called "^bash -l$"
case_ "logged out right away (exit 0 at once): no rescue$n"
setup; dwl dwl 'exit 0'; start
eq "$RC" 0; not_called "^bash"; called "stop dwl-session.target"

case_ "a second start while the desktop runs: refused, the running session's log untouched$n"
setup; dwl dwl; echo "the running session" >"$LOG"; stub pgrep 'echo 4242'
start
eq "$RC" 1; has "$OUT" "already running"; has "$OUT" "4242"
not_called "^dwl"; not_called "^systemctl"; not_called "^bash"
eq "$(cat "$LOG")" "the running session"; [[ ! -e $LOG.old ]] && _ok || _no "the running session's log was moved"
called "^pgrep -xu $(id -u) "
case_ "started on a Fedora 45 text console (kmscon): handed to the helper kmscon names, which runs it again without kmscon's marks$n"
setup; dwl dwl; chmod +x "$TMP/start-dwl"
stub kmscon-launch-gui '"$@"'
KMS_START_SCRIPT=kmscon-launch-gui TERM_SESSION_TYPE=kms start
eq "$RC" 0; called "^kmscon-launch-gui env -u KMS_START_SCRIPT -u TERM_SESSION_TYPE KAWA_KMSCON=1 $TMP/start-dwl$"
called "^dwl -s $HOME/.config/dwl/autostart.sh$"; eq "$(grep -c '^dwl' "$CALLS")" 1 "dwl started once"
eq "$(envof dwl KMS_START_SCRIPT)" "" "the session does not think it is on kmscon"; eq "$(envof dwl TERM_SESSION_TYPE)" ""
eq "$(envof dwl KAWA_KMSCON)" "" "the hand-over's own mark stays with start-dwl"
case_ "… handed over, and dwl cannot start: the rescue text, then back to the console's own shell (none started under the hidden screen)$n"
setup; dwl dwl 'exit 3'; chmod +x "$TMP/start-dwl"; stub kmscon-launch-gui '"$@"'
KMS_START_SCRIPT=kmscon-launch-gui start
has "$OUT" "The desktop could not start: dwl stopped at once (exit 3)."; has "$OUT" "fedokawaii repair"
called "^kmscon-launch-gui "; not_called "^bash -l$"
case_ "… a helper named that is not there: the session starts as on any console$n"
setup; dwl dwl; KMS_START_SCRIPT=no-such-helper start
eq "$RC" 0; called "^dwl -s"
case_ "… and a second start while the desktop runs is refused before any hand-over$n"
setup; dwl dwl; stub kmscon-launch-gui '"$@"'; stub pgrep 'echo 4242'
KMS_START_SCRIPT=kmscon-launch-gui start
eq "$RC" 1; has "$OUT" "already running"; not_called "^kmscon-launch-gui"

case_ "leftovers of a session that crashed (Wayland socket and lock, the bar's folder, a float lock): a normal start$n"
setup; dwl dwl
mkdir -p "$XDG_RUNTIME_DIR/dwl-bar/DP-1"; : >"$XDG_RUNTIME_DIR/wayland-0"; : >"$XDG_RUNTIME_DIR/wayland-0.lock"
: >"$XDG_RUNTIME_DIR/kawa-term-books.lock"; start
eq "$RC" 0; called "^dwl -s"; not_called "^bash"

case_ "a home folder with a space, or a space and a quote: the autostart still runs$n"
for h in "my home" "my home's"; do
  setup; dwl dwl; H2="$TMP/$h"; mkdir -p "$H2/.config/dwl"; cp -p "$HOME/.config/dwl/autostart.sh" "$H2/.config/dwl/"
  HOME=$H2 start
  eq "$RC" 0; has "$(cat "$TMP/autostart.ran" 2>/dev/null)" "autostart ran in $H2" "[$h]"; [[ -s $H2/.cache/dwl.log ]] && _ok || _no "no log in [$h]"
done
done

case_ "dwl crashes after a while (not at once): the session simply ends — even if the clock was set back meanwhile"
# (dual boot: Windows keeps the hardware clock in local time, Fedora reads it as UTC, and
# chrony sets the clock back four hours a minute into the session)
SHL=sh=bash; setup; dwl dwl 'sleep 5.5; exit 139'
printf '%s\n' 1700014400 1700000000 >"$TMP/clock"
stub date 'n=$(head -n1 "'"$TMP"'/clock"); sed -i 1d "'"$TMP"'/clock"; echo "${n:-1700000000}"'
start
eq "$RC" 0; not_called "^bash"; called "stop dwl-session.target"

case_ "start-dwl is clean POSIX sh (bash -n, dash -n, shellcheck)"
rc 0 bash -n "$REPO/system/start-dwl"
command -v dash >/dev/null && { rc 0 dash -n "$REPO/system/start-dwl"; }
rc 0 shellcheck -S warning -s sh "$REPO/system/start-dwl"

done_
