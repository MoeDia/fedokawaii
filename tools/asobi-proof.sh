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
#   sudo bash tools/asobi-proof.sh vt2      as the desktop's user asks, on the real screen, 2 min at most: a game frozen
#                                           behind the desktop and thawed, Steam closed for Bottles, Bottles and back
#   sudo bash tools/asobi-proof.sh seat     on the real screen, 90 s at most: a controller (a virtual one: uinput) is whoever's
#                                           VT is in front; Steam's own exit ends the world and brings the desktop back
#   sudo bash tools/asobi-proof.sh cycles   only VT switches on an empty VT (the desktop's side: its bar), 20 s
#   sudo bash tools/asobi-proof.sh manager  the desktop's own manager has none of the world's walls, and any other
#                                           user's starts: a throw-away user's, for real, then gone (his is not restarted)
#   sudo ASOBI_PROOF_EXE=F bash tools/asobi-proof.sh windows
#                                           F, a Windows program, through the drop folder into a bottle, on the real screen
#   sudo ASOBI_PROOF_GAME=G bash tools/asobi-proof.sh proton
#                                           G, a Windows game in the library, through Proton on the real screen, no sign-in
#   sudo bash tools/asobi-proof.sh all      walls, reset, manager (never vt, cycles: they take the owner's screen)
# Writes what it saw to ${ASOBI_PROOF_OUT:-/dev/shm/r27/asobi-proof}. Exit 0 all held · 1 something did not.
set -u
export LC_ALL=C.UTF-8 PATH=/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
[[ $EUID -eq 0 ]] || { echo "run as root" >&2; exit 2; }
OUT=${ASOBI_PROOF_OUT:-/dev/shm/r27/asobi-proof}; mkdir -p "$OUT"
HOLDER=asobi-proof-holder
WHO=asobi W=/home/asobi DROP=/home/.asobi/drop SNAPS=/home/.asobi/snapshots STEAM_DATA=/home/asobi/.var/app/com.valvesoftware.Steam
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
  echo "what the desktop's user may ask of root, and nothing more (no dialog can come: --no-ask-password)"
  holds "a job of the world's"         runuser -u "$DESK" -- systemctl --no-ask-password start kawa-asobi-op@status.service
  # (the round's own rule lets the desktop's user do anything: gone at its end, and the two lines mean nothing until then)
  if [[ -e /etc/polkit-1/rules.d/00-fedokawaii-round.rules ]]; then
    echo "  --    another unit: not judged, the round's own polkit rule is in place"
  else
    never "another unit: the watch"    runuser -u "$DESK" -- systemctl --no-ask-password start kawa-asobi-watch.service
    never "another unit: polkit"       runuser -u "$DESK" -- systemctl --no-ask-password restart polkit.service
  fi
  never "a job with a name of its own making" runuser -u "$DESK" -- systemctl --no-ask-password start 'kawa-asobi-op@reset:UP.service'
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

# The walls belong to the world's own manager. On the template they kept every other user's from starting
# (4 Nov 2026: ProtectHome over /run/user, "Failed to allocate manager object"), seen only at his next login.
manager() {
  local who=asobi-probe-$$ id
  echo "the desktop's own manager"
  holds "it runs"                        systemctl is-active --quiet "user@$DESK_UID.service"
  holds "no drop-in of the world's on it" bash -c '[[ $(systemctl show -P DropInPaths user@'"$DESK_UID"'.service) != *asobi* ]]'
  holds "no drop-in for every user@ but the one of its timeouts" bash -c '[[ $(ls /etc/systemd/system/user@.service.d/) == fedokawaii.conf ]]'
  holds "ProtectHome no, PrivateTmp no"  bash -c '[[ $(systemctl show -P ProtectHome user@'"$DESK_UID"'.service) == no && $(systemctl show -P PrivateTmp user@'"$DESK_UID"'.service) == no ]]'
  echo "the template, for real: a throw-away user's manager starts as the desktop's would"
  useradd --no-create-home --home-dir /nonexistent --shell /usr/sbin/nologin "$who" || { no "the throw-away user"; return; }
  id=$(id -u "$who")
  holds "user@$id starts"                systemctl start "user@$id.service"
  holds "and answers"                    runuser -u "$who" -- env "XDG_RUNTIME_DIR=/run/user/$id" systemctl --user is-system-running --wait
  holds "its runtime folder is writable" runuser -u "$who" -- touch "/run/user/$id/.probe"
  systemctl stop "user@$id.service" "user-runtime-dir@$id.service" 2>/dev/null
  userdel "$who" 2>/dev/null; groupdel "$who" 2>/dev/null
  never "and gone"                       id -u "$who"
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
  # (a compositor without its socket, its runtime folder remade under it: nothing can look at the screen)
  [[ -S /run/user/$DESK_UID/$DESK_WL ]] || { printf '  --    %s: not looked at, the desktop has no Wayland socket\n' "$1"; return 0; }
  # (the bar's left end, its torii and its workspace stamps: stable, and a window drawn there instead is not it)
  for t in {1..24}; do
    as_desk grim -g "0,0 150x27" - 2>/dev/null >"$OUT/$1.png"
    [[ $1 == bar-before ]] && { cp "$OUT/$1.png" "$OUT/bar-model.png"; n=0; break; }
    n=$(magick compare -metric AE -fuzz 8% "$OUT/bar-model.png" "$OUT/$1.png" null: 2>&1 | sed 's/ .*//'); n=${n%%.*}
    [[ $n =~ ^[0-9]+$ ]] || n=99999   # (an empty picture: the desktop's screen is not back yet)
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
  local dead=asobi-proof-deadman
  [[ $(cat /sys/class/tty/tty0/active) == tty1 ]] || { no "the desktop is not in front: not now"; return; }
  bar_shown bar-before || return
  systemd-run --quiet --unit="$dead" --collect --on-active=45 chvt 1
  chvt 8; sleep 3; chvt 1
  bar_shown bar-clean
  for _ in 1 2 3; do chvt 8; sleep 2; chvt 1; sleep 0.7; done
  chvt 8; sleep 2; chvt 1
  bar_shown bar-quick
  systemctl stop "$dead.timer" 2>/dev/null
}

# The key itself, through a virtual keyboard: the input wall ignores those (each face's start puts it up), so lifted for it
super_g() {
  rm -f /run/udev/rules.d/60-kawa-asobi.rules; udevadm control --reload; sleep 0.5
  python3 -I "$(dirname "$0")/uinput-key.py" LEFTMETA+G
}
# (however a proof on the real screen ends, even a bug in it: the desktop in front, the world closed)
screen_back() { chvt 1; systemctl stop kawa-asobi.service; systemctl stop kawa-asobi-bottles.service; systemctl stop asobi-proof-deadman.timer; } 2>/dev/null
# the real session on the real screen. The dead man's switch needs no one: at 90 s the desktop is in front
vt_proof() {
  trap screen_back EXIT
  local dead=asobi-proof-deadman t card before sid
  [[ $(cat /sys/class/tty/tty0/active) == tty1 ]] || { no "the desktop is not in front: not now"; return; }
  bar_shown bar-before || return
  systemd-run --quiet --unit="$dead" --collect --on-active=90 bash -c 'chvt 1; systemctl stop kawa-asobi.service; systemctl stop kawa-asobi-bottles.service'
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
  # how long the screen stays black: a picture of the screen until it holds more than a few colours
  for t in {1..30}; do
    gs_env xprop -root -f GAMESCOPECTRL_REQUEST_SCREENSHOT 32c -set GAMESCOPECTRL_REQUEST_SCREENSHOT 1 2>/dev/null
    sleep 1
    inside_user cat /tmp/gamescope.png >"$OUT/world.png" 2>/dev/null
    [[ $(magick "$OUT/world.png" -format '%k' info: 2>/dev/null || echo 0) -gt 50 ]] && break
  done
  ok "the first picture of Steam, $(($(date +%s) - $(date -d "$before" +%s))) s after the key"
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
  gs_env xprop -root GAMESCOPE_VRR_ENABLED GAMESCOPE_VRR_CAPABLE GAMESCOPE_VRR_FEEDBACK >"$OUT/vrr-atoms.txt" 2>&1
  echo "back, as Super+G does it (the key itself: a virtual keyboard, the input wall lifted for it)"
  super_g
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
  t=$(date +%s%N)
  systemctl stop kawa-asobi.service
  ok "closed in $(( ($(date +%s%N) - t) / 1000000 )) ms"
  for t in {1..40}; do [[ $(cat /sys/class/tty/tty0/active) == tty1 ]] && break; sleep 0.25; done
  holds "closed: the desktop in front"   test "$(cat /sys/class/tty/tty0/active)" = tty1
  holds "the state says off"             test "$(cat /run/kawa-asobi/state)" = off
  [[ $(cat /sys/class/tty/tty0/active) == tty1 ]] || chvt 1
  systemctl stop "$dead.timer" 2>/dev/null
  bar_shown bar-closed
  journalctl -t kawa-asobi --since "$before" --no-pager -o cat >"$OUT/session-journal.txt" 2>&1
  journalctl _UID="$UID_W" --since "$before" --no-pager -o cat >"$OUT/world-journal.txt" 2>&1
}
# frozen with a game behind the desktop, thawed in front; Steam closed for Bottles: both as the desktop's user asks
vt2_proof() {
  local dead=asobi-proof-deadman t uid_slice ask=(runuser -u "$DESK" -- env "XDG_RUNTIME_DIR=/run/user/$DESK_UID" "HOME=$DESK_HOME" "$DESK_HOME/.local/bin/kawa-asobi")
  trap screen_back EXIT
  [[ $(cat /sys/class/tty/tty0/active) == tty1 ]] || { no "the desktop is not in front: not now"; return; }
  bar_shown bar-before || return
  systemd-run --quiet --unit="$dead" --collect --on-active=120 bash -c 'chvt 1; systemctl stop kawa-asobi.service; systemctl stop kawa-asobi-bottles.service'
  echo "in, as the desktop's user asks"
  holds "kawa-asobi enter"               "${ask[@]}" enter
  for t in {1..40}; do [[ $(cat /sys/class/tty/tty0/active) == tty8 ]] && break; sleep 0.25; done
  for t in {1..60}; do [[ $(cat /run/kawa-asobi/state 2>/dev/null) == front ]] && pgrep -u "$WHO" -f 'steam.*-gamepadui' >/dev/null && break; sleep 0.5; done
  holds "in front"                       test "$(cat /run/kawa-asobi/state)" = front
  sleep 12
  echo "a game in the world (its stand-in: a wineserver), Super+G"
  inside_user systemd-run --user --quiet --unit=asobi-proof-game --slice=app.slice bash -c 'exec -a wineserver sleep 300'
  sleep 0.5
  super_g
  sleep 3
  holds "the desktop in front"           test "$(cat /sys/class/tty/tty0/active)" = tty1
  holds "the world says frozen"          test "$(cat /run/kawa-asobi/state)" = frozen
  uid_slice=/sys/fs/cgroup/user.slice/user-$UID_W.slice/user@$UID_W.service/app.slice
  holds "its app.slice is frozen (the kernel's word)" grep -qx 'frozen 1' "$uid_slice/cgroup.events"
  local c0 c1; c0=$(awk '/^usage_usec/{print $2}' "$uid_slice/cpu.stat"); sleep 2; c1=$(awk '/^usage_usec/{print $2}' "$uid_slice/cpu.stat")
  holds "no CPU in 2 s ($(( (c1 - c0) / 1000 )) ms)" test $((c1 - c0)) -lt 20000
  bar_shown bar-frozen
  holds "its sound and portals still answer" inside_user wpctl status
  echo "in again, as Super+G asks"
  t=$(date +%s%N)
  holds "kawa-asobi enter"               "${ask[@]}" enter
  for _ in {1..40}; do [[ $(cat /run/kawa-asobi/state) == front ]] && break; sleep 0.1; done
  ok "thawed $(( ($(date +%s%N) - t) / 1000000 )) ms after the key"
  holds "VT 8 in front"                  test "$(cat /sys/class/tty/tty0/active)" = tty8
  holds "app.slice thawed"               grep -qx 'frozen 0' "$uid_slice/cgroup.events"
  sleep 2
  world_shot world-after-thaw
  holds "gamescope draws again"          test -s "$OUT/world-after-thaw.png"
  inside_user systemctl --user stop asobi-proof-game
  echo "Bottles, Steam closing first"
  t=$(date +%s%N)
  holds "kawa-asobi bottles"             "${ask[@]}" bottles
  for _ in {1..120}; do systemctl is-active --quiet kawa-asobi-bottles.service && pgrep -u "$WHO" -f 'com.usebottles.bottles|/bottles' >/dev/null && ! pgrep -u "$WHO" -x steam >/dev/null && break; sleep 0.5; done
  ok "Bottles up, Steam gone, $(( ($(date +%s%N) - t) / 1000000 )) ms after asking"
  holds "Steam closed"                   bash -c '! pgrep -u asobi -x steam'
  never "Steam closed clean (its own mark: no .crash)" test -e "$STEAM_DATA/.local/share/Steam/.crash"
  holds "Bottles running"                systemctl is-active --quiet kawa-asobi-bottles.service
  sleep 8
  holds "VT 8 in front"                  test "$(cat /sys/class/tty/tty0/active)" = tty8
  world_shot world-bottles
  super_g
  sleep 2
  holds "Super+G: the desktop in front"  test "$(cat /sys/class/tty/tty0/active)" = tty1
  [[ $(cat /sys/class/tty/tty0/active) == tty1 ]] || { chvt 1; sleep 1; }
  bar_shown bar-back
  t=$(date +%s%N)
  holds "kawa-asobi close"               "${ask[@]}" close
  ok "closed in $(( ($(date +%s%N) - t) / 1000000 )) ms"
  holds "closed"                         test "$(cat /run/kawa-asobi/state)" = off
  holds "the desktop still in front"     test "$(cat /sys/class/tty/tty0/active)" = tty1
  [[ $(cat /sys/class/tty/tty0/active) == tty1 ]] || chvt 1
  systemctl stop "$dead.timer" 2>/dev/null
  bar_shown bar-closed
}
# a controller is the seat's: yours on the desktop, the world's while it is in front; and Steam's own exit, no one closing it
seat_proof() {
  local dead=asobi-proof-deadman t ev="" ask=(runuser -u "$DESK" -- env "XDG_RUNTIME_DIR=/run/user/$DESK_UID" "HOME=$DESK_HOME" "$DESK_HOME/.local/bin/kawa-asobi")
  [[ $(cat /sys/class/tty/tty0/active) == tty1 ]] || { no "the desktop is not in front: not now"; return; }
  bar_shown bar-before || return
  python3 -I "$(dirname "$0")/uinput-key.py" --pad 95 & PAD=$!
  trap 'kill "$PAD" 2>/dev/null; screen_back' EXIT
  systemd-run --quiet --unit="$dead" --collect --on-active=90 bash -c 'chvt 1; systemctl stop kawa-asobi.service; systemctl stop kawa-asobi-bottles.service'
  for _ in {1..40}; do
    for t in /sys/class/input/event*; do [[ $(cat "$t/device/name" 2>/dev/null) == fedokawaii-check-pad ]] && ev=/dev/input/${t##*/}; done
    [[ -n $ev ]] && break
    sleep 0.25
  done
  [[ -n $ev ]] || { no "no controller came up"; return; }
  sleep 1
  holds "to udev it is a controller"     bash -c "udevadm info '$ev' | grep -q ID_INPUT_JOYSTICK=1"
  holds "on the desktop it is yours"     runuser -u "$DESK" -- test -r "$ev"
  never "and not the world's"            runuser -u "$WHO" -- test -r "$ev"
  holds "kawa-asobi enter"               "${ask[@]}" enter
  for t in {1..80}; do [[ $(cat /run/kawa-asobi/state 2>/dev/null) == front ]] && pgrep -u "$WHO" -x steam >/dev/null && break; sleep 0.25; done
  sleep 1
  holds "in front, it is the world's"    runuser -u "$WHO" -- test -r "$ev"
  never "and not yours"                  runuser -u "$DESK" -- test -r "$ev"
  sleep 14
  super_g
  sleep 2
  holds "Super+G: the desktop in front"  test "$(cat /sys/class/tty/tty0/active)" = tty1
  holds "behind, it is yours again"      runuser -u "$DESK" -- test -r "$ev"
  never "and not the world's"            runuser -u "$WHO" -- test -r "$ev"
  bar_shown bar-back
  echo "Steam's own exit, no one closing the world"
  holds "kawa-asobi enter"               "${ask[@]}" enter
  sleep 3
  holds "in front again"                 test "$(cat /sys/class/tty/tty0/active)" = tty8
  # (what Steam's own menu does: Steam ends by itself; everything after it is the world's own chain)
  sleep 12
  t=$(date +%s%N)
  inside_user env "HOME=$STEAM_DATA" "$STEAM_DATA/.local/share/Steam/ubuntu12_32/steam-runtime/amd64/usr/bin/steam-runtime-steam-remote" -shutdown >/dev/null 2>&1
  for _ in {1..160}; do systemctl is-active --quiet kawa-asobi.service || break; sleep 0.25; done
  never "the world ended by itself"      systemctl is-active --quiet kawa-asobi.service
  ok "the desktop back $(( ($(date +%s%N) - t) / 1000000 )) ms after Steam's exit"
  never "Steam ended clean (its own mark: no .crash)" test -e "$STEAM_DATA/.local/share/Steam/.crash"
  holds "the desktop in front"           test "$(cat /sys/class/tty/tty0/active)" = tty1
  holds "the state says off"             test "$(cat /run/kawa-asobi/state)" = off
  never "nothing of it left"             pgrep -u "$WHO"
  [[ $(cat /sys/class/tty/tty0/active) == tty1 ]] || chvt 1
  systemctl stop "$dead.timer" 2>/dev/null
  kill "$PAD" 2>/dev/null
  bar_shown bar-closed
}
# a picture of the world's screen, as gamescope takes it, to $OUT/NAME.png
world_shot() {
  inside_user rm -f /tmp/gamescope.png
  gs_env xprop -root -f GAMESCOPECTRL_REQUEST_SCREENSHOT 32c -set GAMESCOPECTRL_REQUEST_SCREENSHOT 1
  sleep 2
  inside_user cat /tmp/gamescope.png >"$OUT/$1.png" 2>/dev/null
}
# the two pictures differ by more than a cursor: something new on the screen, not the same window still
shows_new() {
  local n; n=$(magick compare -metric AE -fuzz 8% "$OUT/$1.png" "$OUT/$2.png" null: 2>&1 | sed 's/ .*//'); n=${n%%.*}
  [[ $n =~ ^[0-9]+$ ]] && ((n > 20000))
}
inside_user() {
  nsenter -t "$(systemctl show -P MainPID "user@$UID_W.service")" -m \
    setpriv --reuid="$WHO" --regid="$WHO" --init-groups env "HOME=$W" "XDG_RUNTIME_DIR=/run/user/$UID_W" "$@"
}
# (gamescope's X server, the only one in the world's own /tmp: its number depends on who else has one on this machine)
gs_env() {
  local s=/tmp/.X11-unix/X0
  s=$(inside_user bash -c 'for s in /tmp/.X11-unix/X*; do echo "$s"; break; done')
  inside_user env "DISPLAY=:${s##*/X}" "$@"
}
# A Windows program, the way the desktop's user would run one: dropped in ~/Drop, in a bottle Bottles makes from its
# own CLI inside the walls (its first run downloads a runner: minutes, the screen untouched), then on the real screen
# in the world's own gamescope; behind the desktop it is frozen like a game, in front it goes on. 2 min of the screen.
#   sudo ASOBI_PROOF_EXE=/path/to/program.exe bash tools/asobi-proof.sh windows
windows_proof() {
  local dead=asobi-proof-deadman t name exe=${ASOBI_PROOF_EXE:-} bottle=asobi-proof stub cli
  local ask=(runuser -u "$DESK" -- env "XDG_RUNTIME_DIR=/run/user/$DESK_UID" "HOME=$DESK_HOME" "$DESK_HOME/.local/bin/kawa-asobi")
  local bottles=$W/.var/app/com.usebottles.bottles/data/bottles/bottles
  [[ -s $exe ]] || { no "ASOBI_PROOF_EXE names no program"; return; }
  [[ $(cat /sys/class/tty/tty0/active) == tty1 ]] || { no "the desktop is not in front: not now"; return; }
  name=${exe##*/}
  echo "a bottle, inside the walls, the screen untouched"
  stub=$(mktemp -d /run/asobi-proof.XXXXXX); printf '#!/bin/sh\nexit 0\n' >"$stub/chvt"; chmod 0755 "$stub/chvt"
  KAWA_ASOBI_TEST_PATH=$stub:$PATH /usr/local/sbin/kawa-asobi-root prestart || { no "the world's walls would not go up"; rm -rf "$stub"; return; }
  systemd-run --quiet --unit="$HOLDER" --collect -p User="$WHO" -p PAMName=kawa-asobi sleep 900
  sleep 3
  cli=(nsenter -t "$(systemctl show -P MainPID "user@$UID_W.service")" -m setpriv --reuid="$WHO" --regid="$WHO" --init-groups
    env -i HOME="$W" USER="$WHO" LOGNAME="$WHO" LANG=C.UTF-8 PATH=/usr/bin:/bin "XDG_RUNTIME_DIR=/run/user/$UID_W" "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$UID_W/bus"
    flatpak run --nosocket=wayland --command=bottles-cli com.usebottles.bottles)
  if [[ -d $bottles/$bottle ]]; then ok "the bottle is there from an earlier run"
  else timeout 900 "${cli[@]}" new --bottle-name "$bottle" --environment application >"$OUT/bottle-new.txt" 2>&1
    holds "Bottles made it (first run: its runner downloaded through the walls)" test -d "$bottles/$bottle"
  fi
  timeout 180 "${cli[@]}" shell -b "$bottle" -i 'cmd /c ver' >"$OUT/bottle-ver.txt" 2>&1
  holds "wine answers in it"             grep -q 'Microsoft Windows' "$OUT/bottle-ver.txt"
  systemctl stop "$HOLDER" 2>/dev/null
  KAWA_ASOBI_TEST_PATH=$stub:$PATH /usr/local/sbin/kawa-asobi-root poststop
  rm -rf "$stub"
  [[ -d $bottles/$bottle ]] || return
  [[ -n ${ASOBI_PROOF_PREP_ONLY:-} ]] && return    # (the bottle alone: the screen another time)
  echo "it comes through the drop folder"
  runuser -u "$DESK" -- install -m 0644 "$exe" "$DROP/$name"
  bar_shown bar-before || return
  trap screen_back EXIT
  systemd-run --quiet --unit="$dead" --collect --on-active=150 bash -c 'chvt 1; systemctl stop kawa-asobi.service; systemctl stop kawa-asobi-bottles.service'
  echo "Bottles' face, on the real screen"
  holds "kawa-asobi bottles"             "${ask[@]}" bottles
  for t in {1..80}; do [[ $(cat /run/kawa-asobi/state 2>/dev/null) == front ]] && pgrep -u "$WHO" -f 'com.usebottles.bottles|/bottles' >/dev/null && break; sleep 0.5; done
  holds "in front"                       test "$(cat /run/kawa-asobi/state)" = front
  sleep 10
  world_shot before-program
  (gs_env "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$UID_W/bus" flatpak run --nosocket=wayland --env=GDK_BACKEND=x11 --command=bottles-cli com.usebottles.bottles \
    run -b "$bottle" -e "$DROP/$name" >"$OUT/program.txt" 2>&1 &)
  # (by its own name, the kernel's: not the command line of bottles-cli asking for it. Its wineserver comes first)
  for t in {1..60}; do pgrep -u "$WHO" -x "${name:0:15}" >/dev/null && pgrep -u "$WHO" -x wineserver >/dev/null && break; sleep 0.5; done
  holds "the program runs, from the drop folder" pgrep -u "$WHO" -x "${name:0:15}"
  holds "under wine, in the Flatpak's sandbox" pgrep -u "$WHO" -x wineserver
  sleep 8
  world_shot program
  holds "it is on the screen (program.png)" shows_new before-program program
  echo "Super+G: behind the desktop it is frozen; in front again it goes on"
  super_g
  sleep 3
  holds "the desktop in front"           test "$(cat /sys/class/tty/tty0/active)" = tty1
  holds "the world says frozen"          test "$(cat /run/kawa-asobi/state)" = frozen
  holds "kawa-asobi bottles, again"      "${ask[@]}" bottles
  for t in {1..40}; do [[ $(cat /run/kawa-asobi/state) == front ]] && break; sleep 0.1; done
  holds "in front, thawed"               grep -qx 'frozen 0' "/sys/fs/cgroup/user.slice/user-$UID_W.slice/user@$UID_W.service/app.slice/cgroup.events"
  sleep 2
  holds "the program still there"        pgrep -u "$WHO" -x "${name:0:15}"
  chvt 1
  holds "kawa-asobi close"               "${ask[@]}" close
  never "nothing of it left"             pgrep -u "$WHO"
  holds "the desktop in front"           test "$(cat /sys/class/tty/tty0/active)" = tty1
  systemctl stop "$dead.timer" 2>/dev/null
  bar_shown bar-closed
  rm -f "$DROP/$name"
}
# A Windows game of the world's own library through Proton, in Steam's Flatpak, as Steam would run it (its runtime, a
# prefix of its own, thrown away after; no sign-in, so a game that needs Steam itself will refuse): in Bottles' gamescope,
# which follows any window. DXVK's counter in the picture says how fast. 2 min of the screen. steam_appid.txt beside it, as
# long as it runs: Steamworks' way for a game started outside Steam (partner.steamgames.com/doc/sdk/api), else it asks
# Steam to start it and ends at once.
#   sudo ASOBI_PROOF_GAME=Blasphemous/Blasphemous.exe bash tools/asobi-proof.sh proton
proton_proof() {
  local dead=asobi-proof-deadman t game=${ASOBI_PROOF_GAME:-} pfx=asobi-proof-pfx exe id apps=$STEAM_DATA/.local/share/Steam/steamapps
  local ask=(runuser -u "$DESK" -- env "XDG_RUNTIME_DIR=/run/user/$DESK_UID" "HOME=$DESK_HOME" "$DESK_HOME/.local/bin/kawa-asobi")
  [[ -n $game ]] || { no "ASOBI_PROOF_GAME names no game"; return; }
  exe=${game##*/}; exe=${exe:0:15}
  id=$(grep -l "\"installdir\".*\"${game%%/*}\"" "$apps"/appmanifest_*.acf | sed -E 's/.*appmanifest_([0-9]+)\.acf/\1/')
  [[ $id =~ ^[0-9]+$ ]] || { no "no such game in the world's library"; return; }
  [[ $(cat /sys/class/tty/tty0/active) == tty1 ]] || { no "the desktop is not in front: not now"; return; }
  bar_shown bar-before || return
  APPID_FILE=$apps/common/${game%%/*}/steam_appid.txt
  trap 'rm -f "$APPID_FILE"; screen_back' EXIT
  runuser -u "$WHO" -- sh -c 'echo "$1" >"$2"' _ "$id" "$APPID_FILE"
  systemd-run --quiet --unit="$dead" --collect --on-active=170 bash -c 'chvt 1; systemctl stop kawa-asobi.service; systemctl stop kawa-asobi-bottles.service'
  holds "kawa-asobi bottles"             "${ask[@]}" bottles
  for t in {1..80}; do [[ $(cat /run/kawa-asobi/state 2>/dev/null) == front ]] && pgrep -u "$WHO" -f 'com.usebottles.bottles|/bottles' >/dev/null && break; sleep 0.5; done
  holds "in front"                       test "$(cat /run/kawa-asobi/state)" = front
  sleep 8
  world_shot before-game
  (gs_env "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$UID_W/bus" flatpak run --nosocket=wayland --command=bash com.valvesoftware.Steam -c '
    S=$HOME/.local/share/Steam P=$HOME/.cache/'"$pfx"'
    mkdir -p "$P"
    export STEAM_COMPAT_CLIENT_INSTALL_PATH=$S STEAM_COMPAT_DATA_PATH=$P DXVK_HUD=fps,devinfo PROTON_LOG=0
    exec "$S/steamapps/common/SteamLinuxRuntime_4/_v2-entry-point" --verb=waitforexitandrun -- \
      "$S/steamapps/common/Proton 11.0/proton" waitforexitandrun "$S/steamapps/common/'"$game"'"' >"$OUT/game.txt" 2>&1 &)
  # (by its own name, the kernel's: not the launcher's command line, which names it too)
  for t in {1..120}; do pgrep -u "$WHO" -x "$exe" >/dev/null && pgrep -u "$WHO" -x wineserver >/dev/null && break; sleep 0.5; done
  holds "the game runs, under Proton's wine" pgrep -u "$WHO" -x "$exe"
  ok "and it took $t half-seconds"
  for t in 1 2 3; do
    sleep 12
    world_shot "game-$t"
  done
  holds "it is on the screen (game-*.png)" shows_new before-game game-3
  "$DESK_HOME/.local/bin/kawa-display" --vrr >"$OUT/vrr.txt" 2>&1
  holds "FreeSync on with it"            grep -qP '\tyes\ton' "$OUT/vrr.txt"
  holds "still running"                  pgrep -u "$WHO" -x "$exe"
  echo "Super+G: frozen behind the desktop; in front again, on it goes"
  super_g
  sleep 3
  holds "the desktop in front"           test "$(cat /sys/class/tty/tty0/active)" = tty1
  holds "the world says frozen"          test "$(cat /run/kawa-asobi/state)" = frozen
  holds "in again"                       "${ask[@]}" bottles
  for t in {1..40}; do [[ $(cat /run/kawa-asobi/state) == front ]] && break; sleep 0.1; done
  sleep 5
  world_shot game-thawed
  holds "after the thaw, still running"  pgrep -u "$WHO" -x "$exe"
  chvt 1
  t=$(date +%s%N)
  holds "kawa-asobi close"               "${ask[@]}" close
  ok "closed in $(( ($(date +%s%N) - t) / 1000000 )) ms"
  never "nothing of it left"             pgrep -u "$WHO"
  systemctl stop "$dead.timer" 2>/dev/null
  rm -rf "$STEAM_DATA/.cache/$pfx" "$APPID_FILE"
  bar_shown bar-closed
}

case ${1:-} in
  walls) walls ;;
  reset) reset_proof ;;
  vt)    vt_proof ;;
  cycles) cycles ;;
  vt2)   vt2_proof ;;
  seat)  seat_proof ;;
  manager) manager ;;
  windows) windows_proof ;;
  proton) proton_proof ;;
  all)   walls; reset_proof; manager ;;
  *) echo "usage: sudo bash tools/asobi-proof.sh walls|reset|vt|vt2|seat|cycles|manager|windows|proton|all" >&2; exit 2 ;;
esac
echo
if ((fails)); then echo "$fails did not hold"; exit 1; fi
echo "all held"
