#!/usr/bin/env bash
# tools/asobi-proof.sh — the play world's promises proved on the machine it is installed on (root; a VM
# too, but for vt): every wall tried from inside, as the world's user, in the world's own namespaces.
#   sudo bash tools/asobi-proof.sh walls    no sudo, no home but its own, no one else's /tmp, /dev/shm or
#                                           processes, no polkit, no local service, no local network, the
#                                           Internet yes, the drop folder both ways
#   sudo bash tools/asobi-proof.sh reset    a snapshot, a change, a reset: the change gone; back again
#   sudo bash tools/asobi-proof.sh vt       the real thing on the real screen, 60 s at most (a dead man's
#                                           switch brings the desktop back): gamescope on the card, the mode,
#                                           FreeSync, the seat's sound and devices following, the way back
#   sudo bash tools/asobi-proof.sh cycles   only VT switches on an empty VT (the desktop's side: its bar), 20 s
#   sudo bash tools/asobi-proof.sh all      walls, then reset (never vt, cycles: they take the owner's screen)
# Writes what it saw to ${ASOBI_PROOF_OUT:-/dev/shm/r27/asobi-proof}. Exit 0 all held · 1 something did not.
set -u
export LC_ALL=C.UTF-8 PATH=/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
[[ $EUID -eq 0 ]] || { echo "run as root" >&2; exit 2; }
OUT=${ASOBI_PROOF_OUT:-/dev/shm/r27/asobi-proof}; mkdir -p "$OUT"
HOLDER=asobi-proof-holder
WHO=asobi W=/home/asobi DROP=/home/.asobi/drop SNAPS=/home/.asobi/snapshots
DESK=$(head -n1 /var/lib/fedokawaii/user | tr -d '[:space:]'); DESK_UID=$(id -u "$DESK"); DESK_HOME=$(getent passwd "$DESK" | cut -d: -f6)
UID_W=$(id -u "$WHO") || { echo "no user $WHO: the world is not installed" >&2; exit 1; }
fails=0
ok() { printf '  ok    %s\n' "$*"; }
no() { printf '  FAIL  %s\n' "$*"; fails=$((fails + 1)); }
holds() { local what=$1; shift; if "$@" >/dev/null 2>&1; then ok "$what"; else no "$what"; fi; }   # the command succeeds
never() { local what=$1; shift; if "$@" >/dev/null 2>&1; then no "$what"; else ok "$what"; fi; }   # the command fails

# ── in the world: its own manager's mount namespace, its user, its groups ──────────────────────
inside() {
  nsenter -t "$(systemctl show -P MainPID "user@$UID_W.service")" -m \
    setpriv --reuid="$WHO" --regid="$WHO" --init-groups env -i HOME="$W" USER="$WHO" LOGNAME="$WHO" \
    PATH=/usr/bin:/bin "XDG_RUNTIME_DIR=/run/user/$UID_W" "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$UID_W/bus" "$@"
}
world_up() {   # the session and its walls, without a compositor (a holder for the seat session)
  /usr/local/sbin/kawa-asobi-root prestart || { no "the world's walls would not go up"; return 1; }
  systemd-run --quiet --unit="$HOLDER" --collect -p User="$WHO" -p PAMName=kawa-asobi sleep 600
  sleep 2
  systemctl is-active --quiet "user@$UID_W.service" || { no "the world's user manager did not start"; return 1; }
}
world_down() {
  systemctl stop "$HOLDER" 2>/dev/null
  /usr/local/sbin/kawa-asobi-root poststop
}

walls() {
  local p sock marker=asobi-proof-$$ gw port=38471 listener
  echo "the account"
  holds "not in wheel"                 bash -c '[[ " $(id -nG asobi) " != *" wheel "* ]]'
  holds "no password (locked)"         bash -c '[[ $(passwd -S asobi | cut -d" " -f2) == L ]]'
  holds "no shell"                     bash -c '[[ $(getent passwd asobi | cut -d: -f7) == */nologin ]]'
  holds "no subordinate ids"           bash -c '! grep -q "^asobi:" /etc/subuid /etc/subgid'
  never "sudo, even outside the walls" runuser -u "$WHO" -- sudo -n true
  never "/home/$DESK, even outside the walls" runuser -u "$WHO" -- ls "$DESK_HOME"
  never "/etc/shadow"                  runuser -u "$WHO" -- cat /etc/shadow
  world_up || return
  # what the desktop's user leaves where anyone could read it: world-readable, on purpose
  runuser -u "$DESK" -- bash -c "umask 022; echo secret >/tmp/$marker; echo secret >/dev/shm/$marker; echo secret >/var/tmp/$marker"
  echo "from inside the walls"
  never "/home/$DESK is not even there"  inside test -e "$DESK_HOME"
  never "/root"                          inside ls /root
  holds "/home holds only the world"     bash -c '[[ $(nsenter -t "$(systemctl show -P MainPID user@'"$UID_W"'.service)" -m ls -A /home | tr "\n" " ") == ".asobi asobi " ]]'
  never "his marker in /tmp"             inside test -e "/tmp/$marker"
  never "his marker in /var/tmp"         inside test -e "/var/tmp/$marker"
  never "his marker in /dev/shm"         inside test -e "/dev/shm/$marker"
  never "his runtime folder"             inside test -e "/run/user/$DESK_UID"
  never "another user's process in /proc" inside bash -c 'for p in /proc/[0-9]*; do [[ $(stat -c %u "$p" 2>/dev/null) == '"$DESK_UID"' ]] && exit 0; done; exit 1'
  never "root's processes in /proc"      inside test -e /proc/1/cmdline
  never "the snapshots"                  inside ls "$SNAPS"
  never "/run/media, /mnt, /media"       inside ls /run/media/"$DESK"
  never "writing anywhere else (/etc)"   inside touch /etc/asobi-proof
  never "writing anywhere else (/home)"  inside touch /home/asobi-proof
  never "sudo"                           inside sudo -n true
  never "su"                             inside su -c true root </dev/null
  echo "polkit, as an active seat user would have it"
  for p in org.freedesktop.login1.power-off org.freedesktop.login1.reboot org.freedesktop.NetworkManager.network-control \
           org.freedesktop.NetworkManager.settings.modify.system org.freedesktop.udisks2.filesystem-mount \
           org.freedesktop.login1.set-self-linger org.freedesktop.systemd1.manage-units org.freedesktop.Flatpak.app-install; do
    never "$p" inside bash -c 'pkcheck --action-id "$1" --process $$' _ "$p"
  done
  # (the check itself can say yes: what the world is allowed)
  holds "and yes where it may: the switch back to the desktop" inside bash -c 'pkcheck --action-id org.freedesktop.login1.chvt --process $$'
  holds "login1's own word: CanPowerOff is no" bash -c '[[ $(nsenter -t "$(systemctl show -P MainPID user@'"$UID_W"'.service)" -m setpriv --reuid=asobi --regid=asobi --init-groups busctl --system call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanPowerOff) == *\"no\"* ]]'
  echo "the network"
  # a service of the desktop's, on the loopback and on this machine's own address
  runuser -u "$DESK" -- python3 -I -c "
import socket,time
s=socket.socket(); s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1); s.bind(('0.0.0.0',$port)); s.listen(); s.settimeout(40)
try:
    while True: s.accept()[0].close()
except OSError: pass
" &
  listener=$!
  sleep 0.5
  try_tcp() { inside python3 -I -c "import socket; s=socket.socket(); s.settimeout(4); s.connect(('$1',$2))"; }
  holds "(the listener answers the desktop)" python3 -I -c "import socket; s=socket.socket(); s.settimeout(2); s.connect(('127.0.0.1',$port))"
  never "a service of the desktop's on 127.0.0.1" try_tcp 127.0.0.1 "$port"
  p=$(ip -4 -o addr show scope global | awk '{print $4; exit}'); p=${p%/*}
  [[ -n $p ]] && never "a service of the desktop's on $p" try_tcp "$p" "$port"
  gw=$(ip -4 route show default | awk '{print $3; exit}')
  [[ -n $gw ]] && never "the local network ($gw)" try_tcp "$gw" 80
  holds "the Internet"                   try_tcp 1.1.1.1 443
  holds "names resolve (the DNS stub)"   inside python3 -I -c "import socket; socket.getaddrinfo('store.steampowered.com',443)"
  kill "$listener" 2>/dev/null; wait "$listener" 2>/dev/null
  echo "X11 and the abstract sockets"
  for sock in $(ss -xlH 2>/dev/null | awk '{print $5}' | grep -E '^@/tmp/\.X11-unix/X[0-9]+$'); do
    never "the desktop's X server ${sock#@}" inside python3 -I -c "
import socket,struct,sys
s=socket.socket(socket.AF_UNIX); s.settimeout(3); s.connect('\0${sock#@}')
s.sendall(struct.pack('<BxHHHHxx',0x6c,11,0,0,0))
sys.exit(0 if s.recv(1)[:1]==b'\x01' else 1)"
  done
  ss -xlH 2>/dev/null | awk '{print $5}' | grep '^@' | sed -E 's/[0-9a-f]{8,}/#/g' | sort -u >"$OUT/abstract-sockets.txt"
  echo "the drop folder"
  local f=$DROP/.proof-$$
  holds "the world writes"               inside bash -c "echo world >$f.w"
  holds "you read it, and delete it"     runuser -u "$DESK" -- bash -c "grep -qx world $f.w && rm -f $f.w"
  holds "you write"                      runuser -u "$DESK" -- bash -c "echo you >$f.d"
  holds "the world reads it"             inside grep -qx you "$f.d"
  runuser -u "$DESK" -- bash -c "echo private >$f.p; chmod 600 $f.p"
  /usr/local/sbin/kawa-asobi-root drop-fix
  holds "a private file too, once dropped" inside grep -qx private "$f.p"
  holds "the world deletes"              inside rm -f "$f.d" "$f.p"
  echo "the input wall"
  holds "a virtual keyboard is ignored while the world lives" test -s /run/udev/rules.d/60-kawa-asobi.rules
  rm -f "/tmp/$marker" "/dev/shm/$marker" "/var/tmp/$marker"
  world_down
  never "…and the walls are down again" nft list table inet kawa_asobi
  never "…as is the input wall" test -e /run/udev/rules.d/60-kawa-asobi.rules
  never "…no process of the world is left" pgrep -u "$WHO"
}

reset_proof() {
  local s=proof-$$ m=$W/.asobi-proof-marker
  echo "reset"
  rm -f "$m"
  holds "a snapshot"                     /usr/local/sbin/kawa-asobi-root op "snapshot:$s"
  runuser -u "$WHO" -- touch "$m"
  holds "the world changed"              test -e "$m"
  holds "reset to it"                    /usr/local/sbin/kawa-asobi-root op "reset:$s"
  never "the change is gone"             test -e "$m"
  holds "still a subvolume, still its own" bash -c 'btrfs subvolume show /home/asobi >/dev/null && [[ $(stat -c %a:%U /home/asobi) == 700:asobi ]]'
  holds "still its SELinux label"        bash -c '[[ $(stat -c %C /home/asobi) == *user_home_dir_t* ]]'
  local before; before=$(find "$SNAPS" -mindepth 1 -maxdepth 1 -name 'before-reset-*' -printf '%f\n' | sort | tail -n1)
  holds "what it replaced was kept ($before)" test -e "$SNAPS/$before/${m##*/}"
  holds "and a reset back to it"         /usr/local/sbin/kawa-asobi-root op "reset:$before"
  holds "the change is back"             test -e "$m"
  rm -f "$m"
  /usr/local/sbin/kawa-asobi-root op "delete:$s" || no "deleting $s"
  never "clean cannot be deleted"        /usr/local/sbin/kawa-asobi-root op delete:clean
  never "a bad name is refused"          /usr/local/sbin/kawa-asobi-root op "reset:../../etc"
  never "a snapshot that is not there"   /usr/local/sbin/kawa-asobi-root op reset:no-such-one
}

# ── the desktop's side of a VT switch: wlroots destroys every output when its session is paused, and makes
# new ones at the resume (handle_session_active), a cable pulled and plugged: the bar and the wallpaper
# must come back. His session's env, read from its bar (a kit's bar has a runtime folder of its own).
desk_env() {
  local b kv
  DESK_WL=""
  for b in $(pgrep -u "$DESK" -x waybar); do
    tr '\0' '\n' <"/proc/$b/environ" 2>/dev/null | grep -qx "XDG_RUNTIME_DIR=/run/user/$DESK_UID" || continue
    kv=$(tr '\0' '\n' <"/proc/$b/environ" | grep '^WAYLAND_DISPLAY=') || continue
    DESK_WL=${kv#*=} DESK_BAR=$b
    return 0
  done
  return 1
}
as_desk() { runuser -u "$DESK" -- env "HOME=$DESK_HOME" "XDG_RUNTIME_DIR=/run/user/$DESK_UID" "WAYLAND_DISPLAY=$DESK_WL" "$@"; }
bar_shown() {   # bar_shown NAME — the bar's row on the screen has its colours; what the desktop has kept, to $OUT/NAME.*
  local n=99999 t
  desk_env || { no "$1: no bar process"; return 1; }
  # (the bar's left end, its torii and its workspace stamps: stable, and a window drawn there instead is not it)
  for t in {1..24}; do
    as_desk grim -g "0,0 150x27" - 2>/dev/null >"$OUT/$1.png"
    [[ $1 == bar-before ]] && { cp "$OUT/$1.png" "$OUT/bar-model.png"; n=0; break; }
    n=$(magick compare -metric AE -fuzz 8% "$OUT/bar-model.png" "$OUT/$1.png" null: 2>&1 | sed 's/ .*//'); n=${n%%.*}; n=${n:-99999}
    ((n < 200)) && break
    sleep 0.5
  done
  as_desk wlr-randr >"$OUT/$1.outputs" 2>&1
  cp "$DESK_HOME/.cache/waybar.log" "$OUT/$1.waybar.log" 2>/dev/null
  tail -n 40 "$DESK_HOME/.cache/dwl.log" >"$OUT/$1.dwl.log" 2>/dev/null
  if ((n < 200)); then ok "$1: the bar is on the screen ($n pixels differ)"; return 0; fi
  no "$1: no bar on the screen, the process alive ($DESK_BAR, $n pixels differ); restarted through the session's keep"
  { for t in "/proc/$DESK_BAR/task/"*; do printf '%s %s\n' "$(cat "$t/comm")" "$(cat "$t/wchan")"; done
    if [[ -x ${ASOBI_PROOF_STACK:-}/usr/bin/eu-stack ]]; then LD_LIBRARY_PATH=$ASOBI_PROOF_STACK/usr/lib64 "$ASOBI_PROOF_STACK/usr/bin/eu-stack" -p "$DESK_BAR" -m 2>&1 | head -80; fi
    pgrep -a -P "$DESK_BAR"; } >"$OUT/$1.stuck.txt" 2>&1
  kill "$DESK_BAR" 2>/dev/null
  return 1
}
# a clean cycle and quick ones on an empty VT, no world at all: is it the switch itself that loses the bar?
cycles() {
  local dead=asobi-proof-deadman i
  [[ $(cat /sys/class/tty/tty0/active) == tty1 ]] || { no "the desktop is not in front: not now"; return; }
  bar_shown bar-before || return
  systemd-run --quiet --unit="$dead" --collect --on-active=45 chvt 1
  chvt 8; sleep 3; chvt 1
  bar_shown bar-clean
  for i in 1 2 3; do chvt 8; sleep 2; chvt 1; sleep 0.7; done
  chvt 8; sleep 2; chvt 1
  bar_shown bar-quick
  systemctl stop "$dead.timer" 2>/dev/null
}

# the real session on the real screen. The dead man's switch needs no one: at 90 s the desktop is in front
vt_proof() {
  local dead=asobi-proof-deadman t card before sid
  [[ $(cat /sys/class/tty/tty0/active) == tty1 ]] || { no "the desktop is not in front: not now"; return; }
  bar_shown bar-before || return
  systemd-run --quiet --unit="$dead" --collect --on-active=90 bash -c 'chvt 1; systemctl stop kawa-asobi.service kawa-asobi-bottles.service'
  before=$(date '+%F %T')
  echo "into the world"
  systemctl start --no-block kawa-asobi.service
  for t in {1..40}; do [[ $(cat /sys/class/tty/tty0/active) == tty8 ]] && break; sleep 0.25; done
  holds "VT 8 in front"                  test "$(cat /sys/class/tty/tty0/active)" = tty8
  sleep 6
  for t in $(loginctl list-sessions --no-legend | awk '$3 == "asobi" && $4 == "seat0" { print $1 }'); do
    [[ $(loginctl show-session "$t" -p State --value) == closing ]] || sid=$t
  done
  loginctl show-session "$sid" >"$OUT/session.txt" 2>&1
  holds "a seat session on it, active"   bash -c '[[ $(loginctl show-session '"$sid"' -p Active --value) == yes && $(loginctl show-session '"$sid"' -p VTNr --value) == 8 ]]'
  # (no world: nothing more to see, the desktop back at once)
  pgrep -u "$WHO" -f '^gamescope|/gamescope ' >/dev/null || { no "gamescope did not start"; chvt 1; systemctl stop kawa-asobi.service; systemctl stop "$dead.timer"; return; }
  ok "gamescope runs"
  holds "Steam's gamepad UI runs, in its Flatpak"  bash -c 'pgrep -u asobi -f "steam.*-gamepadui" >/dev/null'
  holds "/dev/uinput is the seat's"      runuser -u "$WHO" -- test -w /dev/uinput
  sleep 8
  card=$(for c in /sys/class/drm/card[0-9]*-*/status; do [[ $(cat "$c") == connected ]] && { c=${c%%-*}; echo "${c##*/card}"; break; }; done)
  cat "/sys/kernel/debug/dri/$card/state" >"$OUT/drm-state.txt" 2>&1
  holds "the screen at 1920x1080, 144 Hz" grep -qE 'mode:.*"1920x1080": 144' "$OUT/drm-state.txt"
  "$DESK_HOME/.local/bin/kawa-display" --vrr >"$OUT/vrr.txt" 2>&1
  holds "FreeSync on (the card's own word: VRR_ENABLED)" grep -qP '\tyes\ton' "$OUT/vrr.txt"
  inside_user gamemoded -s >"$OUT/gamemode.txt" 2>&1
  holds "GameMode on"                    grep -q 'is active' "$OUT/gamemode.txt"
  holds "the card at its full clocks"    test "$(cat "/sys/class/drm/card$card/device/power_dpm_force_performance_level")" = high
  holds "the desktop's idle held"        bash -c 'systemd-inhibit --list --no-pager --no-legend | grep -q "asobi.*idle"'
  holds "the world's share of the machine" test "$(systemctl show -P CPUWeight "user-$UID_W.slice")" = 400
  inside_user wpctl status >"$OUT/world-sound.txt" 2>&1
  holds "the sound card is the world's"  grep -qE 'Analog Stereo|Digital Stereo' "$OUT/world-sound.txt"
  inside_user env DISPLAY=:0 xprop -root -f GAMESCOPECTRL_REQUEST_SCREENSHOT 32c -set GAMESCOPECTRL_REQUEST_SCREENSHOT 1
  sleep 3
  inside_user cat /tmp/gamescope.png >"$OUT/world.png" 2>/dev/null
  echo "back, as Super+G does it (the key itself: a virtual keyboard, the input wall lifted for it)"
  rm -f /run/udev/rules.d/60-kawa-asobi.rules; udevadm control --reload; sleep 0.5
  python3 -I "$(dirname "$0")/uinput-key.py" LEFTMETA+G
  sleep 1.5
  holds "Super+G: the desktop in front"  test "$(cat /sys/class/tty/tty0/active)" = tty1
  [[ $(cat /sys/class/tty/tty0/active) == tty1 ]] || { chvt 1; sleep 1; }
  bar_shown bar-back-1
  sleep 1.5
  holds "the watch knows"                bash -c 'shopt -s extglob; [[ $(cat /run/kawa-asobi/state) == @(away|frozen) ]]'
  never "the desktop's idle free again"  bash -c 'systemd-inhibit --list --no-pager --no-legend | grep -q "asobi.*idle"'
  env "XDG_RUNTIME_DIR=/run/user/$DESK_UID" runuser -u "$DESK" -- wpctl status >"$OUT/desk-sound-back.txt" 2>&1
  holds "the sound card is yours again"  grep -q 'Analog Stereo' "$OUT/desk-sound-back.txt"
  echo "in again, out again at once, then in and closed (a quick double switch)"
  chvt 8; sleep 2
  holds "in front again"                 test "$(cat /run/kawa-asobi/state)" = front
  chvt 1; sleep 0.7; chvt 8; sleep 2
  chvt 1
  bar_shown bar-back-2
  chvt 8; sleep 2
  systemctl stop kawa-asobi.service
  for t in {1..40}; do [[ $(cat /sys/class/tty/tty0/active) == tty1 ]] && break; sleep 0.25; done
  holds "closed: the desktop in front"   test "$(cat /sys/class/tty/tty0/active)" = tty1
  holds "the state says off"             test "$(cat /run/kawa-asobi/state)" = off
  [[ $(cat /sys/class/tty/tty0/active) == tty1 ]] || chvt 1
  systemctl stop "$dead.timer" 2>/dev/null
  bar_shown bar-closed
  journalctl -t kawa-asobi --since "$before" --no-pager -o cat >"$OUT/session-journal.txt" 2>&1
  journalctl _UID="$UID_W" --since "$before" --no-pager -o cat >"$OUT/world-journal.txt" 2>&1
}
inside_user() {
  nsenter -t "$(systemctl show -P MainPID "user@$UID_W.service")" -m \
    setpriv --reuid="$WHO" --regid="$WHO" --init-groups env "HOME=$W" "XDG_RUNTIME_DIR=/run/user/$UID_W" "$@"
}

case ${1:-} in
  walls) walls ;;
  reset) reset_proof ;;
  vt)    vt_proof ;;
  cycles) cycles ;;
  all)   walls; reset_proof ;;
  *) echo "usage: sudo bash tools/asobi-proof.sh walls|reset|vt|all" >&2; exit 2 ;;
esac
echo
if ((fails)); then echo "$fails did not hold"; exit 1; fi
echo "all held"
