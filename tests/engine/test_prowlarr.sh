#!/usr/bin/env bash
# tests/engine/test_prowlarr.sh — Prowlarr on demand, from the two places that start it and
# then go on without it: setup.sh's prowlarr_up (setup, update, repair, the Fedora move) and
# the `prowlarr` shell command (its web page). A start that fails is stopped again: left
# alone, the unit's Restart=on-failure would try it every 10 s until the next boot.
# (kawa-torrra and verify already stop it: tests/engine/test_torrra.sh, tests/installer.)
# Then setup.sh's other torrent steps, as functions: torrra_up (torrra at its pinned version
# with its libraries at the versions it was released with, pipx's own `torrra` kept off your
# PATH, the load probe that verify shares) and torrent_port (the firewall, never reloaded).
. "$(dirname "$0")/lib.sh"
KEY=a1b2c3d4e5f60718293a4b5c6d7e8f90

# systemd --user: $TMP/active while Prowlarr runs; $TMP/start-fails makes every start fail
user_systemd() {
  stub systemctl 'case "$*" in
  *is-active*) [ -e "'"$TMP"'/active" ]; exit $? ;;
  *" start "*|*" restart "*) [ -e "'"$TMP"'/start-fails" ] && { echo "Job for prowlarr.service failed." >&2; exit 1; }; : >"'"$TMP"'/active" ;;
  *" stop "*) rm -f "'"$TMP"'/active" ;;
esac'
}

# ── setup.sh's prowlarr_up ───────────────────────────────────────────────────
# its own functions, as setup.sh has them, run as setup runs a step (errexit); the user's
# commands run as you here; podman knows the key and has the image; curl is Prowlarr's API
up_world() {
  sandbox; user_systemd; stub sleep
  { sed -n '/^prowlarr_image() {/p' "$REPO/setup.sh"
    for f in prowlarr_key prowlarr_accepts prowlarr_up; do sed -n "/^$f() {/,/^}/p" "$REPO/setup.sh"; done; } >"$TMP/fns.sh"
  [[ $(grep -c '() {' "$TMP/fns.sh") == 4 ]] || { echo "fixture: setup.sh's Prowlarr functions not found" >&2; exit 1; }
  stub podman 'case "$*" in *"secret inspect"*) printf %s '"$KEY"' ;; esac'
  stub curl 'cat >/dev/null; [ -e "'"$TMP"'/key-refused" ] && exit 22; exit 0'
  mkdir -p "$HOME/.config/fedokawaii"
  printf 'PROWLARR_API_KEY=%s\n' "$KEY" >"$HOME/.config/fedokawaii/secrets.sh"; chmod 600 "$HOME/.config/fedokawaii/secrets.sh"
}
up() {   # → $OUT, $RC
  OUT=$(LOG_FILE=$TMP/fk.log STATE_DIR=$TMP/state REPO_DIR=$REPO TARGET_HOME=$HOME TARGET_USER=$(id -un) \
        TARGET_UID=$(id -u) TARGET_GID=$(id -g) bash -c 'set -Eeuo pipefail
    . "$1/lib/common.sh"; . "$2"; as_user() { "$@"; }
    prowlarr_up' _ "$REPO" "$TMP/fns.sh" 2>&1); RC=$?
}
stops_after() {   # a stop of prowlarr.service comes after the last (re)start
  awk '/^systemctl .*(start|restart) prowlarr.service/ { s = NR } /^systemctl .*stop .*prowlarr.service/ { t = NR }
       END { exit !(s && t > s) }' "$CALLS"
}

case_ "prowlarr_up: a working Prowlarr is started, checked, and put back to sleep"
up_world; up; eq "$RC" 0 "$OUT"
called '^systemctl --user restart prowlarr.service'; stops_after && _ok || _no "not stopped again"
case_ "prowlarr_up: one that does not start — said, and stopped again (never left retrying every 10 s)"
up_world; : >"$TMP/start-fails"; up; eq "$RC" 1
has "$OUT" "Prowlarr did not start"; stops_after && _ok || _no "left starting: $(tail -n3 "$CALLS" | tr '\n' '|')"
case_ "prowlarr_up: one that does not take the key — said, and stopped again too"
up_world; : >"$TMP/key-refused"; up; eq "$RC" 1
has "$OUT" "does not take the key"; stops_after && _ok || _no "left running"
case_ "…but one you had running already (its page open) is left running"
up_world; : >"$TMP/active"                                  # (its unit current: no restart)
mkdir -p "$HOME/.config/containers/systemd"; cp "$REPO/system/prowlarr.container" "$HOME/.config/containers/systemd/"
: >"$TMP/key-refused"; up; eq "$RC" 1; not_called 'stop'; [[ -e $TMP/active ]] && _ok || _no "your Prowlarr was stopped"

# ── the `prowlarr` shell command ─────────────────────────────────────────────
sh_world() {
  sandbox; user_systemd; stub xdg-open
  sed -n '/^prowlarr() {/,/^}/p' "$REPO/configs/home/.bashrc.d/fedokawaii.sh" >"$TMP/fn.sh"
  [[ -s $TMP/fn.sh ]] || { echo "fixture: the prowlarr function is not in .bashrc.d/fedokawaii.sh" >&2; exit 1; }
}
pw() { OUT=$(bash -c '. "$1"; shift; prowlarr "$@"' _ "$TMP/fn.sh" "$@" 2>&1); RC=$?; }

case_ "prowlarr: started (the wait said), then its page opened"
sh_world; pw; eq "$RC" 0; has "$OUT" "starting Prowlarr"
called '^systemctl --user start prowlarr.service'; called '^xdg-open http://localhost:9696'; not_called ' stop '
case_ "prowlarr, already running: the page only, no wait to announce"
sh_world; : >"$TMP/active"; pw; eq "$RC" 0; lacks "$OUT" "starting"; called '^xdg-open'
case_ "prowlarr, a start that fails: said, stopped again (never left retrying), no page"
sh_world; : >"$TMP/start-fails"; pw; eq "$RC" 1
has "$OUT" "Prowlarr did not start"; has "$OUT" "journalctl --user -u prowlarr"
called '^systemctl --user stop --no-block prowlarr.service'; not_called xdg-open
case_ "prowlarr stop"
sh_world; : >"$TMP/active"; pw stop; eq "$RC" 0; called '^systemctl --user stop prowlarr.service'; [[ ! -e $TMP/active ]] && _ok || _no "still running"

# ── setup.sh's torrra_up ─────────────────────────────────────────────────────
# a venv of the real python3 with the stand-in torrra (fixtures/torrra: its screens fail to
# load while $FAKE_TEXTUAL_BROKEN exists); the two system files it installs pointed into
# the test's folder; pipx a stand-in that records where it would put its `torrra`
D=$(cd "$(dirname "$0")" && pwd)
TV=$(sed -n 's/^TORRRA_VERSION=//p' "$REPO/lib/upstream.sh")
tu_world() {
  sandbox; stub sleep; stub restorecon
  V=$HOME/.local/share/pipx/venvs/torrra SYS=$TMP/sys
  local pyv; pyv=$(python3 -c 'import sys; print(f"python{sys.version_info[0]}.{sys.version_info[1]}")')
  mkdir -p "$V/bin" "$V/lib/$pyv/site-packages" "$SYS/usr/local/bin" "$SYS/etc/profile.d" "$HOME/.local/bin"
  ln -s "$(command -v python3)" "$V/bin/python"; : >"$V/bin/torrra"
  printf 'home = %s\ninclude-system-site-packages = false\n' "$(dirname "$(command -v python3)")" >"$V/pyvenv.cfg"
  cp -r "$D/fixtures/torrra/." "$V/lib/$pyv/site-packages/"
  printf 'Metadata-Version: 2.1\nName: torrra\nVersion: %s\n' "$TV" >"$V/lib/$pyv/site-packages/torrra-2.5.1.dist-info/METADATA"
  sed -n '/^torrra_up() {/,/^}/p' "$REPO/setup.sh" >"$TMP/tu.sh"
  sed -i -e "s|/usr/local/bin/kawa-torrra|$SYS/usr/local/bin/kawa-torrra|g" \
         -e "s|/etc/profile.d/kawa-torrra.sh|$SYS/etc/profile.d/kawa-torrra.sh|g" "$TMP/tu.sh"
  # (both rewrites made, and no path of this machine's own left in it)
  { grep -q "$SYS/usr/local/bin/kawa-torrra" "$TMP/tu.sh" && grep -q "$SYS/etc/profile.d/kawa-torrra.sh" "$TMP/tu.sh" \
      && ! grep -Eq '(^|[ "=])/(usr|etc)/' "$TMP/tu.sh"; } || { echo "fixture: torrra_up's system paths not pointed into the test" >&2; exit 1; }
  stub pipx 'printf %s "${PIPX_BIN_DIR:-}" >"'"$TMP"'/pipx-bin-dir"
case " $* " in *" install "*) rm -f "${FAKE_TEXTUAL_BROKEN:-/nonexistent}"
  b=${PIPX_BIN_DIR:-$HOME/.local/bin}; mkdir -p "$b"; ln -sfn "'"$V"'/bin/torrra" "$b/torrra" ;; esac'
  unset FAKE_TEXTUAL_BROKEN
}
tu() {   # → $OUT, $RC
  OUT=$(LOG_FILE=$TMP/fk.log STATE_DIR=$TMP/state REPO_DIR=$REPO TARGET_HOME=$HOME TARGET_USER=$(id -un) \
        TARGET_UID=$(id -u) TARGET_GID=$(id -g) TORRRA_VENV=.local/share/pipx/venvs/torrra TORRRA_VERSION=$TV \
        bash -c 'set -Eeuo pipefail; . "$1/lib/common.sh"; . "$2"; as_user() { "$@"; }; torrra_up' _ "$REPO" "$TMP/tu.sh" 2>&1); RC=$?
}
C=$REPO/system/torrra-constraints.txt

case_ "torrra_up, torrra working: nothing installed — pipx's old \`torrra\` link in ~/.local/bin taken out"
tu_world; ln -s "$V/bin/torrra" "$HOME/.local/bin/torrra"
tu; eq "$RC" 0 "$OUT"; not_called '^pipx'
[[ ! -e $HOME/.local/bin/torrra && ! -L $HOME/.local/bin/torrra ]] && _ok || _no "the raw torrra is still on your PATH"
[[ -x $SYS/usr/local/bin/kawa-torrra ]] && _ok || _no "kawa-torrra not installed"
case_ "…a torrra of your own there (a script, a link elsewhere) is left alone"
tu_world; printf '#!/bin/sh\n' >"$HOME/.local/bin/torrra"; tu; eq "$RC" 0; [[ -f $HOME/.local/bin/torrra ]] && _ok || _no "your script went"
tu_world; ln -s /bin/true "$HOME/.local/bin/torrra"; tu; [[ -L $HOME/.local/bin/torrra ]] && _ok || _no "your link went"
case_ "torrra_up, Textual broken under torrra: the load probe sees it — installed again, with the pinned libraries"
tu_world; export FAKE_TEXTUAL_BROKEN=$TMP/textual-broken; : >"$FAKE_TEXTUAL_BROKEN"
tu; eq "$RC" 0 "$OUT"
called "^pipx install --force --python python3.13 --pip-args=-c $C torrra==$TV$"
case_ "…and pipx's own \`torrra\` kept in pipx's folder, never on your PATH"
eq "$(cat "$TMP/pipx-bin-dir" 2>/dev/null)" "$HOME/.local/share/pipx/bin"
[[ ! -e $HOME/.local/bin/torrra && ! -L $HOME/.local/bin/torrra ]] && _ok || _no "pipx linked torrra into ~/.local/bin"
unset FAKE_TEXTUAL_BROKEN
case_ "torrra_up, broken and not mended by the install: said, not passed over"
tu_world; stub pipx; export FAKE_TEXTUAL_BROKEN=$TMP/textual-broken; : >"$FAKE_TEXTUAL_BROKEN"
tu; eq "$RC" 1; has "$OUT" "is installed but does not load"; unset FAKE_TEXTUAL_BROKEN

case_ "the constraints: torrra's libraries at the versions it was released with; libtorrent and certifi free"
[[ -f $C ]] && _ok || _no "no $C"
bad=$(grep -Ev '^(#|$)' "$C" 2>/dev/null | grep -Ev '^[a-z0-9][a-z0-9._-]*==[0-9][0-9A-Za-z.+-]*$'); eq "$bad" "" "not NAME==VERSION: $bad"
for p in textual==8.0.1 rich==14.2.0 httpx==0.28.1 click==8.3.1; do grep -qx "$p" "$C" 2>/dev/null && _ok || _no "$p not pinned"; done
for p in libtorrent certifi torrra; do grep -Eq "^$p==" "$C" 2>/dev/null && _no "$p pinned" || _ok; done
case_ "the update still moves libtorrent alone (only-if-needed, no constraints in the way)"
grep -q 'pipx runpip torrra install --quiet --upgrade' "$REPO/setup.sh" && grep -q -- '--upgrade-strategy only-if-needed "torrra==$TORRRA_VERSION" libtorrent' "$REPO/setup.sh" && _ok || _no "the update's libtorrent step changed"

case_ "verify's load check sees a broken Textual too (it loads torrra's screens)"
tu_world
vp=$(sed -n "s|.*venvs/torrra/bin/python\" -I -c '\\([^']*\\)' \"\$TORRRA_VERSION\".*|\\1|p" "$REPO/verify.sh")
[[ -n $vp ]] && _ok || _no "verify's torrra check not found"
if python3 -c 'import sys; sys.exit(sys.version_info[:2] != (3, 13))'; then
  "$V/bin/python" -I -c "$vp" "$TV" 2>/dev/null && _ok || _no "a working torrra fails verify's check"
else _ok; fi
: >"$TMP/textual-broken"
FAKE_TEXTUAL_BROKEN=$TMP/textual-broken "$V/bin/python" -I -c "$vp" "$TV" 2>/dev/null && _no "a broken Textual passes verify's check" || _ok

# ── setup.sh's torrent_port ──────────────────────────────────────────────────
# firewalld: its saved ports in $TMP/fw-perm, its running ones in $TMP/fw-run; a reload
# makes the running ones the saved ones (dropping what was added only while it runs)
tp_world() {
  sandbox
  sed -n '/^torrent_port() {/,/^}/p' "$REPO/setup.sh" >"$TMP/tp.sh"
  : >"$TMP/fw-perm"; : >"$TMP/fw-run"
  stub firewall-cmd 'f="$TMP/fw-run"; for a in "$@"; do [ "$a" = --permanent ] && f="$TMP/fw-perm"; done
for a in "$@"; do case $a in
  --state) [ -e "$TMP/fw-down" ] && exit 252; exit 0 ;;
  --query-port=*) grep -qx "${a#--query-port=}" "$f"; exit $? ;;
  --add-port=*) echo "${a#--add-port=}" >>"$f" ;;
  --reload) cp "$TMP/fw-perm" "$TMP/fw-run" ;;
esac; done'
}
tp() { OUT=$(LOG_FILE=$TMP/fk.log bash -c 'set -Eeuo pipefail; . "$1/lib/common.sh"; . "$2"; torrent_port' _ "$REPO" "$TMP/tp.sh" 2>&1); RC=$?; }
both() { printf '%s\n' 6881/tcp 6881/udp; }

case_ "torrent_port, 6881 open already (saved and running): nothing changed, firewalld not reloaded"
tp_world; both >"$TMP/fw-perm"; both >"$TMP/fw-run"; tp; eq "$RC" 0 "$OUT"
not_called 'add-port'; not_called 'reload'
case_ "torrent_port, closed: opened, saved and running, without a reload"
tp_world; tp; eq "$RC" 0 "$OUT"
eq "$(sort "$TMP/fw-perm" | tr '\n' ' ')" "6881/tcp 6881/udp "; eq "$(sort "$TMP/fw-run" | tr '\n' ' ')" "6881/tcp 6881/udp "
not_called 'reload'
case_ "torrent_port, saved but not running (another rule added at run time stays): opened while it runs"
tp_world; both >"$TMP/fw-perm"; echo 8080/tcp >"$TMP/fw-run"; tp; eq "$RC" 0
has "$(cat "$TMP/fw-run")" "8080/tcp" "a rule added while firewalld runs was dropped"; has "$(cat "$TMP/fw-run")" "6881/udp"
not_called '\-\-permanent \-\-add-port'
case_ "torrent_port, firewalld not running: said, nothing done"
tp_world; : >"$TMP/fw-down"; tp; eq "$RC" 0; has "$OUT" "firewalld is not running"; not_called 'port'

done_
