#!/bin/bash
# shoot.sh — render fedokawaii's themed apps for real and capture them with grim.
#
#   sudo ./shoot.sh                 both themes (dark, then light)
#   sudo ./shoot.sh light           one theme
#   SHOOT_ONLY="bar menus" ./shoot.sh dark     only some groups:
#                                   bar menus notify term lock (default: all)
#
# The apps are the real ones at Fedora 44's versions (built into /opt/f44 by build.sh),
# run as the test user with the configs theme.sh installed, in a headless sway (standing
# in for dwl). Every theme gets a fresh session inside its own PID + mount + UTS namespace
# (hostname "fedokawaii", a Fedora 44 os-release): when the theme is done the namespace
# ends and takes every process it started with it. Shots → shots/<theme>/, logs →
# logs/<theme>/, a summary of what the apps printed → logs/warnings.txt.
set -uo pipefail
SELF=$(readlink -f "$0")
R=${SELF%/*}
K=${SHOOT_USER:-kawau}
F44=/opt/f44
X=/tmp/xdg-kawa                    # the session's XDG_RUNTIME_DIR
SH=/tmp/shoot-kawa                 # stubs, helpers, state: readable by $K ($R may not be)
OUT=$R/shots LOG=$R/logs
ONLY=${SHOOT_ONLY:-bar menus notify term lock}
GLS=${SHOOT_GLS:-/opt/kit-gls}       # a gtk-layer-shell typelib for python3.12 (the panel; see shot_menus)

say()  { printf '\e[1m[shoot %s]\e[0m %s\n' "$(date +%T)" "$*" >&2; }
warn() { printf '\e[33m[shoot]\e[0m %s\n' "$*" >&2; }
die()  { printf '\e[31m[shoot]\e[0m %s\n' "$*" >&2; exit 1; }
want() { [[ " $ONLY " == *" $1 "* ]]; }

KH=$(getent passwd "$K" | cut -d: -f6) || true
KUID=$(id -u "$K" 2>/dev/null) KGID=$(id -g "$K" 2>/dev/null)

# ──────────────────────────────────────────────────────────────────────────────────────
# outer: checks, staging, one namespace per theme, summary
# ──────────────────────────────────────────────────────────────────────────────────────
outer() {
  [[ $EUID -eq 0 ]] || die "run as root (it starts the session as $K inside namespaces)"
  [[ -n $KH && -d $KH ]] || die "no user $K"
  local themes=("$@") t b miss=()
  ((${#themes[@]})) || themes=(dark light)
  for t in "${themes[@]}"; do
    [[ $t == dark || $t == light ]] || die "unknown theme '$t' (dark|light)"
    [[ -d $KH/.config/fedokawaii/themes/$t ]] || die "$KH/.config/fedokawaii/themes/$t missing — run theme.sh --user $K"
  done
  for b in $F44/bin/{waybar,fuzzel,mako,makoctl,foot,footclient,swaylock,wireplumber,wpctl} \
           sway swaymsg grim swaybg wtype pipewire pw-cli pw-dump dbus-daemon notify-send jq setpriv unshare; do
    command -v "$b" >/dev/null || miss+=("$b")
  done
  ((${#miss[@]} == 0)) || die "missing: ${miss[*]} (see README.md)"
  python3 -c 'import PIL' 2>/dev/null || die "python3-PIL missing"
  for b in waybar mako fuzzel foot swaylock wireplumber sway pipewire; do   # a session not ours
    pgrep -u "$K" -x "$b" >/dev/null && { [[ -n ${SHOOT_ALLOW_OTHER:-} ]] && continue; die "$K already runs $b outside shoot.sh — stop it first (or SHOOT_ALLOW_OTHER=1)"; }
  done

  say "staging stubs and helpers in $SH"
  rm -rf "$SH"; install -d -m 755 "$SH"
  cp -a "$R/stubs" "$R/lib" "$R/xdg" "$R/sway.conf" "$SH/"
  chmod -R a+rX "$SH"
  install -d -m 755 -o "$K" -g "$K" "$SH/state"
  cat >"$SH/state/os-release" <<'EOF'
NAME="Fedora Linux"
VERSION="44 (Server Edition)"
RELEASE_TYPE=stable
ID=fedora
VERSION_ID=44
PLATFORM_ID="platform:f44"
PRETTY_NAME="Fedora Linux 44 (Server Edition)"
ANSI_COLOR="0;38;2;60;110;180"
CPE_NAME="cpe:/o:fedoraproject:fedora:44"
HOME_URL="https://fedoraproject.org/"
VARIANT="Server Edition"
VARIANT_ID=server
SUPPORT_END=2027-06-02
EOF

  # what setup.sh would have done on the real machine: the dconf defaults compiled, the
  # user's font cache fresh (the real tools: /usr/local/bin may hold test stand-ins)
  [[ -x /usr/bin/dconf ]] && /usr/bin/dconf update 2>/dev/null
  setpriv --reuid="$KUID" --regid="$KGID" --init-groups env HOME="$KH" /usr/bin/fc-cache "$KH/.local/share/fonts" >/dev/null 2>&1
  [[ -x $F44/bin/fc-cache ]] && setpriv --reuid="$KUID" --regid="$KGID" --init-groups \
    env HOME="$KH" LD_LIBRARY_PATH="$F44/lib" "$F44/bin/fc-cache" "$KH/.local/share/fonts" >/dev/null 2>&1

  demo_repo

  local before; before=$(readlink "$KH/.config/fedokawaii/current" 2>/dev/null)
  mkdir -p "$OUT" "$LOG"
  local rc=0
  for t in "${themes[@]}"; do
    say "── $t theme ─────────────────────────────"
    timeout -k 10 900 unshare --pid --fork --kill-child --mount --uts --mount-proc --propagation private \
      -- "$SELF" --inner "$t" || { rc=$?; warn "$t: the session ended with status $rc"; }
  done
  # leave the user's theme as it was
  if [[ -n $before ]]; then
    ln -sfn "$before" "$KH/.config/fedokawaii/current.shoot" && mv -fT "$KH/.config/fedokawaii/current.shoot" "$KH/.config/fedokawaii/current"
    chown -h "$K:$K" "$KH/.config/fedokawaii/current"
  fi
  rm -rf "${X:?}"/* 2>/dev/null
  summary "${themes[@]}"
  return $rc
}

demo_repo() {   # ~/repos/fedokawaii: a copy of the repo with work in progress, for the prompt
  local d=$KH/repos/fedokawaii g
  say "demo repository $d"
  rm -rf "$d" "$KH/repos/.remote"
  install -d -o "$K" -g "$K" "$KH/repos"
  g() { setpriv --reuid="$KUID" --regid="$KGID" --init-groups env -i HOME="$KH" PATH=/usr/bin:/bin \
          GIT_AUTHOR_NAME=kawau GIT_AUTHOR_EMAIL=kawau@fedokawaii GIT_COMMITTER_NAME=kawau \
          GIT_COMMITTER_EMAIL=kawau@fedokawaii GIT_CONFIG_NOSYSTEM=1 git -C "$d" "$@" >/dev/null 2>&1; }
  cp -a "${FEDOKAWAII_REPO:-/home/claude/fedokawaii}" "$d" 2>/dev/null || { warn "repo copy failed"; return; }
  rm -rf "$d/.git"; chown -R "$K:$K" "$d"
  g init -q -b main && g add -A && g commit -q -m "fedokawaii: initial" \
    && g clone -q --bare "$d" "$KH/repos/.remote/fedokawaii.git" \
    && g remote add origin "$KH/repos/.remote/fedokawaii.git" && g fetch -q origin \
    && g branch -q -u origin/main
  printf '\n<!-- draft -->\n' >>"$d/docs/fedokawaii-guide.md" 2>/dev/null || printf '\n' >>"$d/README.md"
  g commit -q -am "guide: draft"                               # ↑1
  printf '\n# tweak\n' >>"$d/theme.sh"; g add theme.sh            # +1
  printf '\n# wip\n' >>"$d/setup.sh"; printf '\n' >>"$d/verify.sh" # ~2
  printf 'notes\n' >"$d/TODO.txt"                                  # ?1
  chown -R "$K:$K" "$d" "$KH/repos"
}

summary() {   # the apps' own complaints, collected from every log
  local f t
  {
    echo "# What the real apps printed while loading the user's configs (shoot.sh $(date '+%F %T'))"
    for t in "$@"; do
      echo; echo "## $t"
      for f in "$LOG/$t"/*.log; do
        [[ -s $f ]] || continue
        grep -aE -i 'warn|error|fail|invalid|unknown|not found|deprecat|could not|cannot|unable|missing|critical' "$f" \
          | grep -avE 'rtkit|RealtimeKit|mod\.rt|libcamera|bluez|logind|modem-manager|portal|reserve-device|v4l2|module-dbus|system bus|dbus-daemon\[|Activating service' \
          | sed "s|^|${f##*/}: |" | head -40
      done
    done
  } >"$LOG/warnings.txt"
  say "warnings → $LOG/warnings.txt"
  for t in "$@"; do say "$(find "$OUT/$t" -name '*.png' 2>/dev/null | wc -l) PNGs in $OUT/$t"; done
}

# ──────────────────────────────────────────────────────────────────────────────────────
# inner: one theme, PID 1 of its own namespace
# ──────────────────────────────────────────────────────────────────────────────────────
T="" OT="" LT="" W="" BARH=27 KENV=()

k() {   # k CMD… — run as the user with the session's environment
  setpriv --reuid="$KUID" --regid="$KGID" --init-groups -- env -i "${KENV[@]}" "$@"
}
img() { python3 -I "$SH/lib/imgtool.py" "$@"; }

waitfor() {   # waitfor SECONDS DESCRIPTION CMD… — poll CMD every 0.1 s
  local t=$1 what=$2 i; shift 2
  for ((i = 0; i < t * 10; i++)); do "$@" >/dev/null 2>&1 && return 0; sleep 0.1; done
  warn "$T: timed out after ${t}s waiting for $what"; return 1
}

waitpid() {   # waitpid SECONDS PID — then kill it
  local i
  for ((i = 0; i < $1 * 10; i++)); do kill -0 "$2" 2>/dev/null || { wait "$2" 2>/dev/null; return 0; }; sleep 0.1; done
  kill "$2" 2>/dev/null; sleep 0.3; kill -9 "$2" 2>/dev/null; wait "$2" 2>/dev/null; return 1
}

session() {
  cd "$KH" || cd /     # the user's processes start here (footclient hands its cwd to the server)
  hostname fedokawaii
  mount --bind "$SH/state/os-release" /etc/os-release || warn "os-release bind failed"
  # the CPU meter's source (kawa-cpu reads the first line of /proc/stat): a steady synthetic
  # load, so the bar does not depend on what else this machine is doing (lib/fakestat.py)
  python3 -I "$SH/lib/fakestat.py" "$SH/state/stat" &
  waitfor 5 "the synthetic /proc/stat" test -s "$SH/state/stat" \
    && mount --bind "$SH/state/stat" /proc/stat || warn "/proc/stat stand-in failed: the real load shows"
  rm -rf "$X"; install -d -m 700 -o "$K" -g "$K" "$X"
  KENV=(
    HOME="$KH" USER="$K" LOGNAME="$K" SHELL=/bin/bash LANG=C.UTF-8 TZ=Asia/Dubai
    PATH="$SH/stubs:$F44/bin:$KH/.local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/bin"
    LD_LIBRARY_PATH="$F44/lib" TERMINFO_DIRS="$F44/share/terminfo:/usr/share/terminfo"
    XDG_RUNTIME_DIR="$X" DBUS_SESSION_BUS_ADDRESS="unix:path=$X/bus"
    XDG_SESSION_TYPE=wayland XDG_SESSION_DESKTOP=dwl XDG_CURRENT_DESKTOP=wlroots
    XKB_DEFAULT_LAYOUT=us,ara XKB_DEFAULT_OPTIONS=grp:alt_shift_toggle
    GDK_BACKEND=wayland,x11 QT_QPA_PLATFORM="wayland;xcb" QT_QPA_PLATFORMTHEME=qt6ct
    EDITOR=nvim VISUAL=nvim TERMINAL=foot BROWSER=brave-origin XCURSOR_THEME=Adwaita XCURSOR_SIZE=24
    STUB_STATE="$SH/state" XDG_STATE_HOME="$SH/state/xdg-state"
    # WirePlumber 0.5.18 (/opt/f44) must not pick up Ubuntu's 0.4 files in /usr/share
    WIREPLUMBER_DATA_DIR="$F44/share/wireplumber" WIREPLUMBER_CONFIG_DIR="$F44/share/wireplumber"
    # glib comes from /opt/f44 too: GSettings must still find the system's dconf backend,
    # or GTK quietly falls back to Adwaita instead of adw-gtk3
    GIO_EXTRA_MODULES=/usr/lib/x86_64-linux-gnu/gio/modules
  )
  echo 70 >"$SH/state/ddc-brightness"; chown "$K:$K" "$SH/state/ddc-brightness"

  say "$T: D-Bus, PipeWire, WirePlumber"
  k dbus-daemon --session --address="unix:path=$X/bus" --nofork --nopidfile >"$LT/dbus.log" 2>&1 &
  waitfor 10 "the session bus" test -S "$X/bus"
  k pipewire >"$LT/pipewire.log" 2>&1 &
  waitfor 10 "pipewire" test -S "$X/pipewire-0"
  k wireplumber >"$LT/wireplumber.log" 2>&1 &
  # the machine's audio devices, as the owner's (his report: an MSI board's ALC1220 behind the
  # Ryzen's HD audio controller, an RX 9060 XT's HDMI to an LG ULTRAGEAR): null devices
  # standing in for the ALSA cards, with the props ALSA gives a node (its nick, its profile's
  # description, its card and place on it); stubs/pw-dump adds the cards and their routes
  k pw-cli create-node adapter '{ factory.name=support.null-audio-sink node.name=alsa_output.pci-0000_15_00.6.analog-stereo node.description="Ryzen HD Audio Controller Analog Stereo" node.nick="ALC1220 Analog" device.profile.description="Analog Stereo" device.api=alsa card.profile.device=4 media.class=Audio/Sink object.linger=true audio.position=[FL FR] priority.session=1009 priority.driver=1009 }' >/dev/null
  k pw-cli create-node adapter '{ factory.name=support.null-audio-sink node.name=alsa_output.pci-0000_03_00.1.hdmi-stereo node.description="Navi 48 HDMI/DP Audio Controller Digital Stereo (HDMI)" node.nick="LG ULTRAGEAR" device.profile.description="Digital Stereo (HDMI)" device.api=alsa card.profile.device=3 media.class=Audio/Sink object.linger=true audio.position=[FL FR] priority.session=900 priority.driver=900 }' >/dev/null
  k pw-cli create-node adapter '{ factory.name=support.null-audio-sink node.name=alsa_input.pci-0000_15_00.6.analog-stereo node.description="Ryzen HD Audio Controller Analog Stereo" node.nick="ALC1220 Analog" device.profile.description="Analog Stereo" device.api=alsa card.profile.device=3 media.class=Audio/Source object.linger=true audio.position=[FL FR] priority.session=2009 priority.driver=2009 }' >/dev/null
  waitfor 15 "a default sink" k sh -c 'wpctl inspect @DEFAULT_AUDIO_SINK@ 2>&1 | grep -q "node.name = \"alsa_output.pci-0000_15"'
  waitfor 10 "a default source" k sh -c 'wpctl inspect @DEFAULT_AUDIO_SOURCE@ 2>&1 | grep -q "node.name = \"alsa_input"'
  k wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.62
  k wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 0.80
  sleep 0.5
  { k wpctl status; k sh -c 'pw-dump | jq -r ".[] | select(.type==\"PipeWire:Interface:Node\") | [.id, .info.props[\"media.class\"], .info.props[\"node.name\"], .info.props[\"node.description\"], .info.props[\"factory.name\"]] | @tsv"'; } >"$LT/audio.log" 2>&1

  say "$T: sway (headless, 1920×1080)"
  # window borders in the theme's own colours, read from its dwl.colors as dwl reads them
  # (sway.conf holds the dark ones: focus d0583a, border 877f6f, urgent 7fb8b0)
  local focus=d0583a border=877f6f urgent=7fb8b0 key val
  while read -r key val; do case $key in focus) focus=$val ;; border) border=$val ;; urgent) urgent=$val ;; esac
  done < <(grep -E '^(focus|border|urgent) [0-9a-fA-F]{6}$' "$KH/.config/fedokawaii/themes/$T/dwl.colors" 2>/dev/null)
  sed "s/#d0583a/#$focus/g; s/#877f6f/#$border/g; s/#7fb8b0/#$urgent/g" "$SH/sway.conf" >"$SH/sway-$T.conf"
  k env WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 WLR_HEADLESS_OUTPUTS=1 \
    sway ${SHOOT_SWAY_DEBUG:+-d} -c "$SH/sway-$T.conf" >"$LT/sway.log" 2>&1 &
  waitfor 20 "sway's IPC socket" compgen -G "$X/sway-ipc.*.sock"
  local wl; wl=$(cd "$X" && ls wayland-[0-9] 2>/dev/null | head -1)
  [[ -n $wl ]] || die "$T: sway did not start (see $LT/sway.log)"
  export XDG_RUNTIME_DIR=$X WAYLAND_DISPLAY=$wl SWAYSOCK; SWAYSOCK=$(compgen -G "$X/sway-ipc.*.sock" | head -1)
  KENV+=(WAYLAND_DISPLAY="$wl" SWAYSOCK="$SWAYSOCK")
  waitfor 10 "the output" swaymsg -t get_outputs
  # a keyboard for the whole session, as a desktop has one: the focused window gets keyboard
  # focus and shows it (foot draws a solid cursor then, a hollow one without focus)
  k wtype -s 3600000 >/dev/null 2>&1 &
  # as autostart's `systemctl --user import-environment`: D-Bus-activated services (the
  # portals, which tell waybar the desktop's colour scheme) reach this session
  k dbus-update-activation-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP \
    >/dev/null 2>&1 || warn "$T: dbus-update-activation-environment failed"

  # what dwl's autostart does, in its order (kawa-theme here is the switch to $T: run
  # as the veiled half of a switch, so it applies in one go without the transition)
  say "$T: kawa-display, kawa-theme $T (wallpaper)"
  k kawa-display >"$LT/kawa-display.log" 2>&1
  k env KAWA_VEILED=1 kawa-theme "$T" >"$LT/kawa-theme.log" 2>&1 || warn "$T: kawa-theme exited $?"
  [[ $(k kawa-theme get) == "$T" ]] || warn "$T: kawa-theme get says $(k kawa-theme get)"
  waitfor 15 "swaybg" pgrep -x swaybg
  sleep 1.5
  img grab "$W/wallpaper.ppm" && python3 -I -c 'import sys; from PIL import Image; Image.open(sys.argv[1]).save(sys.argv[2])' \
    "$W/wallpaper.ppm" "$OT/wallpaper.png"

  # a session that has been up a while has the forecast cached (kawa-weather fetches it in
  # the background; curl is stubbed: Open-Meteo's week, 33° and clear now)
  rm -f "$KH/.cache/kawa-weather.json" "$KH/.cache/kawa-weather.failed"
  k kawa-weather >/dev/null 2>&1
  waitfor 10 "the weather cache" test -s "$KH/.cache/kawa-weather.json"
  k mako >"$LT/mako.log" 2>&1 &
  k env ${SHOOT_FOOT_DEBUG:+WAYLAND_DEBUG=1} foot --server >"$LT/foot-server.log" 2>&1 &
  k gammastep >/dev/null 2>&1 &
  # dwl's status stream (src/dwl/dwl.patch printstatus): tags 1 2 4 5 occupied, 1 selected
  # with the focused window, 5 urgent; tiled layout; the first keyboard layout (US)
  mkfifo -m 600 "$X/dwl-status"; chown "$K:$K" "$X/dwl-status"
  k kawa-dwlstatus <"$X/dwl-status" >"$LT/kawa-dwlstatus.log" 2>&1 &
  exec 7>"$X/dwl-status"
  printf '%s\n' "DP-1 title ~/repos/fedokawaii" "DP-1 appid foot" "DP-1 fullscreen 0" "DP-1 floating 0" \
    "DP-1 selmon 1" "DP-1 tags 27 1 1 16" "DP-1 layout (@)" "DP-1 kblayout 0" >&7
  waitfor 10 "kawa-dwlstatus's files" test -s "$X/dwl-bar/kb.json"
  waitfor 10 "mako on the bus" k busctl --user status org.freedesktop.Notifications
  waitfor 10 "the foot server socket" compgen -G "$X/foot-$wl.sock"

  # Steam running and ready (the bar's gamepad): two sleeping processes named as Steam's
  mkdir -p "$X/fake-steam"; cp /bin/sleep "$X/fake-steam/steam"; cp /bin/sleep "$X/fake-steam/steamwebhelper"
  chown -R "$K:$K" "$X/fake-steam"
  k "$X/fake-steam/steam" 3600 & k "$X/fake-steam/steamwebhelper" 3600 &
  say "$T: waybar"
  WB_T0=$SECONDS
  k waybar >"$LT/waybar.log" 2>&1 &
  waitfor 20 "waybar on screen" bar_up || true
  libs_report
}

libs_report() {   # which drawing libraries each running app really mapped (and from where)
  local n pid
  {
    for n in waybar mako foot; do
      pid=$(pgrep -nx "$n") || continue
      printf '%s (pid %s):\n' "$n" "$pid"
      grep -oE '/[^ ]*/lib(pango|pangocairo|pangoft2|cairo|harfbuzz|freetype|fontconfig|pixman|gtk-3|gdk-3|glib|gio|fribidi|fcft|wayland-client|xkbcommon|gtk-layer-shell|wireplumber)[^/ ]*\.so[.0-9]*' \
        "/proc/$pid/maps" | sort -u | while read -r f; do printf '  %s\n' "$(readlink -f "$f")"; done
    done
  } >"$LT/libs.txt" 2>&1
}

bar_up() { img grab "$W/now.ppm" && [[ -n $(img bbox "$W/wallpaper.ppm" "$W/now.ppm") ]]; }

shot_bar() {
  local left=$((18 - (SECONDS - WB_T0)))
  ((left > 0)) && { say "$T: ${left}s for the CPU history to fill"; sleep "$left"; }
  img grab "$W/desk.ppm"
  local bb; read -r _ _ _ BARH <<<"$(img bbox "$W/wallpaper.ppm" "$W/desk.ppm")"
  [[ $BARH =~ ^[0-9]+$ && $BARH -lt 200 ]] || { warn "$T: bar height not found (bbox: $BARH)"; BARH=27; }
  python3 -I - "$W/desk.ppm" "$OT" "$BARH" <<'EOF'
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGB"); out = sys.argv[2]; h = int(sys.argv[3])
im.save(f"{out}/desktop.png")
bar = im.crop((0, 0, im.width, h)); bar.save(f"{out}/bar.png")
w = im.width
bar.crop((0, 0, w * 2 // 5, h)).save(f"{out}/bar-left.png")
bar.crop((w * 3 // 10, 0, w * 7 // 10, h)).save(f"{out}/bar-center.png")
bar.crop((w * 3 // 5, 0, w, h)).save(f"{out}/bar-right.png")
EOF
  say "$T: bar ${BARH} px high → bar.png, bar-left/center/right.png, desktop.png"
}

menu() {   # menu NAME CMD… — open a menu, capture it once drawn and still, close it
  menu_keys "$1" "" "${@:2}"
}
# menu_keys NAME KEYS CMD… — the same, KEYS typed into it first (wtype's arguments: -k Down,
# text…; " | " a pause, for a second menu to open) once it is drawn: the shot is what they
# made of it (a month paged, a size typed). The keyboard (wtype's virtual one) is made before
# the menu opens and waits for it: sway sends the focused surface a leave and an enter when a
# keyboard is added, and the panel takes a leave for a click outside — the menu would close
# (dwl adds keyboards to its group, with no such leave)
menu_keys() {
  local name=$1 keys=$2 pid r kp=""; shift 2
  : >"$LT/$name.log"
  img grab "$W/base.ppm"
  if [[ -n $keys ]]; then
    # shellcheck disable=SC2086  # (KEYS: wtype's own arguments)
    k wtype -s 2500 -d 40 ${keys//|/-s 900} >>"$LT/$name.log" 2>&1 &
    kp=$!
    sleep 0.4
  fi
  "$@" >>"$LT/$name.log" 2>&1 &
  pid=$!
  if [[ -n $kp ]]; then
    waitpid 15 "$kp" || warn "$T: $name: its keys had to be killed"
    sleep 0.6
  fi
  if r=$(img capture "$W/base.ppm" "$OT/$name-full.png" "$OT/$name.png" --mask-top "$BARH" \
           --timeout 10 --min 1.0 --settle 0.5 2>>"$LT/$name.log"); then
    say "$T: $name ($r)"
  else
    warn "$T: $name did not appear (see $LT/$name.log)"
  fi
  close_menus
  waitpid 5 "$pid" || warn "$T: $name had to be killed"
  img wait-same "$W/base.ppm" --mask-top "$BARH" --timeout 5 2>/dev/null || true
  # (a menu closed from outside counts as a click outside it, and the same menu asked for again
  # within 0.6 s is that click landing on its own button — kawa-menu's toggle: none opens)
  sleep 0.7
}
# close_menus — whatever menu is on screen goes, as another menu's key takes it away: the
# launcher (fuzzel) ended, the session panel told to close (SIGUSR2: a menu dismissed, its
# caller answered "dismissed")
close_menus() {
  local p
  pkill -x fuzzel 2>/dev/null
  p=$(cat "$X/kawa-panel.pid" 2>/dev/null) && [[ $p =~ ^[0-9]+$ ]] && kill -USR2 "$p" 2>/dev/null
  return 0
}

shot_menus() {
  local kcmd=(setpriv --reuid="$KUID" --regid="$KGID" --init-groups -- env -i "${KENV[@]}")
  # quick settings (kawa-panel, open for 6 s) as on the real machine, which has a Bluetooth
  # adapter (the dongle): only this panel's processes see a /sys/class/bluetooth/hci0.
  # (This machine's python3 has no working GTK bindings: the panel runs on its python3.12,
  # with a gtk-layer-shell built for them, in $GLS)
  local py="env GI_TYPELIB_PATH=$GLS/girepository-1.0 LD_LIBRARY_PATH=$GLS python3.12 \"\$(command -v kawa-panel)\""
  local qs="$py --open & p=\$!; sleep 6; kill \$p"
  menu menu-quick unshare --mount --propagation private -- sh -c \
    'mount -t tmpfs -o size=64k,mode=755 tmpfs /sys/class && mkdir -p /sys/class/bluetooth/hci0 && exec "$@"' \
    sh "${kcmd[@]}" sh -c "$qs"
  menu menu-quick-nobt k sh -c "$qs"
  # its siblings, opened by their keys (Super+A; the bar's brightness): the sound panel —
  # also muted (the level's squares hollow, unmute offered) — and the brightness slider
  menu menu-sound      k sh -c "${qs/--open/--sound}"
  menu menu-sound-muted k sh -c "wpctl set-mute @DEFAULT_AUDIO_SINK@ 1; ${qs/--open/--sound}; wpctl set-mute @DEFAULT_AUDIO_SINK@ 0"
  menu menu-brightness k sh -c "${qs/--open/--brightness}"
  # the dropdowns and the centred menus: kawa-menu asks the session's panel (kawa-panel --menu,
  # its socket), as autostart keeps one running on the real machine
  k sh -c "exec $py" >"$LT/panel.log" 2>&1 &
  waitfor 15 "the session panel's socket" test -S "$X/kawa-panel.sock"
  menu menu-power      k kawa-power
  menu menu-calendar   k kawa-calendar
  # … paged to the next month by its keys: the cursor stays on next
  menu_keys menu-calendar-next "-k Right -k Right -k Return" k kawa-calendar
  menu menu-timer      k kawa-timer
  # … with a timer running: its time left at the heading's end, cancel offered
  k kawa-timer start 25 >/dev/null 2>&1
  menu menu-timer-running k kawa-timer
  k kawa-timer cancel >/dev/null 2>&1
  menu menu-help       k kawa-help
  menu_keys menu-help-filter "volume" k kawa-help   # (typed: only the bindings it finds, under their parts)
  menu menu-change     k kawa-config
  menu menu-drives     k kawa-drives       # the drives (the bar's drive mark): stubs/lsblk's stick and disk
  menu menu-steam      k kawa-steam --menu # (stubs/steam: installed)
  # shrink (Super+Z) on a picture and a PDF: every part; then a size of one's own, typed
  install -m 644 -o "$K" "$OT/wallpaper.png" "$SH/state/holiday.png"
  python3 -I -c 'import sys; from PIL import Image; Image.new("RGB", (595, 842), "white").save(sys.argv[1])' "$SH/state/scan.pdf"
  chown "$K" "$SH/state/scan.pdf"
  menu menu-shrink     k kawa-shrink "$SH/state/holiday.png" "$SH/state/scan.pdf"
  menu_keys menu-shrink-size "-k Down -k Down -k Down -k Return | 750 -k space KB" k kawa-shrink "$SH/state/holiday.png"
  # share (the screen-share portal's chooser): a screen, two windows
  menu menu-share      k sh -c 'printf "%s\n" "Monitor: HEADLESS-1 Headless output" "Window: notes.md — nvim (a1b2c3d4)" "Window: Weekly sync — Brave (e5f6a7b8)" | kawa-share'
  menu menu-weather    k kawa-weather --menu   # the week (the bar's weather): stubs/curl's Open-Meteo forecast
  # … and as it is after three hours offline: the same days, their age said above them
  k sh -c 'touch -d "-3 hours" "$HOME/.cache/kawa-weather.json" && echo offline >"$HOME/.cache/kawa-weather.failed"'
  menu menu-weather-offline k kawa-weather --menu
  kill "$(cat "$X/kawa-panel.pid")" 2>/dev/null   # (the session panel: the menus done)
  # the launcher (Super+Space): fuzzel with the user's config; the applications are the
  # Fedora .desktop files of what setup.sh installs (xdg/), the icons Papirus
  menu launcher        k env XDG_DATA_DIRS="$SH/xdg/share" fuzzel
  # its configuration, checked by the app itself
  k fuzzel --check-config >"$LT/fuzzel-check-config.log" 2>&1; echo "exit $?" >>"$LT/fuzzel-check-config.log"
}

notice() {   # notice NAME CMD… — send a notification (or a level display), capture it, dismiss
  local name=$1 r; shift
  img grab "$W/base.ppm"
  "$@" >>"$LT/notify.log" 2>&1 &
  if r=$(img capture "$W/base.ppm" "$OT/$name-full.png" "$OT/$name.png" --mask-top "$BARH" \
           --timeout 6 --min 0.3 --settle 0.3 2>>"$LT/notify.log"); then
    say "$T: $name ($r)"
  else
    warn "$T: $name did not appear"
  fi
  wait $! 2>/dev/null
  k makoctl dismiss -a >/dev/null 2>&1
  img wait-same "$W/base.ppm" --mask-top "$BARH" --timeout 6 2>/dev/null || warn "$T: $name stayed on screen"
}

shot_notify() {
  local icons; icons=$(. "$KH/.config/fedokawaii/icons.sh"; printf '%s' "$ICON_CAMERA")
  # the desktop's own notice (kawa-screenshot): its picture as the icon
  local pic="$KH/Pictures/Screenshots/2026-10-15_09-41-27.png"
  install -d -o "$K" -g "$K" "$KH/Pictures/Screenshots"
  python3 -I -c 'import sys; from PIL import Image; Image.open(sys.argv[1]).crop((720, 760, 1200, 1080)).save(sys.argv[2])' \
    "$W/wallpaper.ppm" "$pic" 2>/dev/null; chown "$K:$K" "$pic"            # a region with Fuji in it
  # its icon: the square middle cut kawa-screenshot makes (the same command)
  local thumb="$KH/Pictures/Screenshots/.icon.png"
  magick "$pic" -resize '64x64^' -gravity center -extent 64x64 "$thumb"; chown "$K:$K" "$thumb"
  notice notify-normal k notify-send -a desktop -i "$thumb" "$icons  Screenshot copied" "${pic##*/}"
  rm -f "$pic" "$thumb"
  # an application's notice with a Papirus icon, title and a two-line body
  notice notify-app k notify-send -a "Brave Origin" -i brave-browser "Download complete" \
    "fedora-44-x86_64-netinst.iso was saved to Downloads (1.1 GB)"
  # critical: what autostart's keep() sends when a helper keeps crashing
  notice notify-critical k notify-send -u critical "waybar keeps stopping" \
    "it was restarted 4 times in a minute; see ~/.cache/dwl.log"
  # the drives, as udiskie hands them to kawa-drives (stubs/lsblk: a stick, open; a disk):
  # the stick opened (click: its files), then ejected ("safe to unplug")
  rm -f "$X/stub-drives-closed"
  notice notify-drive k kawa-drives event device_mounted /dev/sda1 True KINGSTON "Kingston DataTraveler 3.0"
  notice notify-eject k kawa-drives eject /dev/sda1
  rm -f "$X/stub-drives-closed" "$X/kawa-drives"/* 2>/dev/null; k kawa-dwlstatus --poke 13
  # the level display: the real scripts, the real wpctl (PipeWire), ddcutil stubbed
  k wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; k wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.57
  notice osd-volume k kawa-volume up                      # 57 % → 62 %
  echo 60 >"$SH/state/ddc-brightness"
  notice osd-brightness k kawa-brightness +10             # 60 % → 70 %
  notice osd-muted k kawa-volume mute                     # muted ("off")
  # the bar while muted (the volume module turns vermilion)
  img grab "$W/muted.ppm" && python3 -I -c 'import sys; from PIL import Image; im=Image.open(sys.argv[1]); im.crop((im.width*3//5,0,im.width,int(sys.argv[3]))).save(sys.argv[2])' \
    "$W/muted.ppm" "$OT/bar-right-muted.png" "$BARH"
  k wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
  # the mode seals: do-not-disturb (静, outlined), then a screen being shared (共有, vermilion)
  local mode
  for mode in do-not-disturb sharing; do
    k makoctl mode -s "$mode" >/dev/null 2>&1; k pkill -RTMIN+12 -x waybar; sleep 0.6
    img grab "$W/mode.ppm" && python3 -I -c 'import sys; from PIL import Image; im=Image.open(sys.argv[1]); im.crop((im.width*3//5,0,im.width,int(sys.argv[3]))).save(sys.argv[2])'       "$W/mode.ppm" "$OT/bar-right-$([[ $mode == sharing ]] && echo share || echo dnd).png" "$BARH"
  done
  k makoctl mode -s default >/dev/null 2>&1; k pkill -RTMIN+12 -x waybar
  k mako --help >/dev/null 2>&1   # (nothing: mako has no config check; its log has the warnings)
  k makoctl reload >>"$LT/notify.log" 2>&1 || echo "makoctl reload: exit $?" >>"$LT/notify.log"
}

foot_window() {   # foot_window APP_ID → "x,y wxh" of the newest such window
  swaymsg -t get_tree | jq -r --arg a "$1" \
    '[recurse(.nodes[]?, .floating_nodes[]?) | select(.app_id == $a)] | last | .rect | "\(.x),\(.y) \(.width)x\(.height)"' 2>/dev/null \
    | grep -v null
}

typeln() { k wtype -s 300 -d 12 "$1" -k Return; }   # one virtual keyboard per line; wait for its keymap before the first key

shot_term() {
  local repo=$KH/repos/fedokawaii geom pid
  # the terminal: footclient (the server is running) in the demo repository; real keys typed
  k footclient -D "$repo" >"$LT/footclient.log" 2>&1 &
  pid=$!
  waitfor 10 "the foot window" foot_window footclient || return
  sleep 1.2                                              # bash and the first prompt
  typeln "clear"; sleep 0.6                              # (the first prompt was ruled before
                                                         #  sway resized the window)
  typeln "sleep 3.2"; sleep 3.8                          # a command that takes > 3 s
  typeln "fetch neko"; sleep 0.8
  typeln "ls"; sleep 1.0
  geom=$(foot_window footclient)
  # a keyboard stays plugged in for the capture, so foot draws its focused cursor (the
  # headless seat has none of its own); the cursor blinks, and a new focus starts it lit
  k wtype -s 1500 >/dev/null 2>&1 &
  local kb=$!; sleep 0.3
  grim -g "$geom" "$OT/terminal.png" && say "$T: terminal.png ($geom)"
  grim "$OT/terminal-full.png"
  wait "$kb" 2>/dev/null
  typeln "exit"; waitpid 5 "$pid" || true

  # the 16 colours as swatches, with their numbers, then the same as text colours
  local sw='printf "\e[?25l\n"
for r in 0 8; do for i in $(seq $r $((r+7))); do printf " \e[48;5;%sm      \e[0m" $i; done; echo
for i in $(seq $r $((r+7))); do printf " \e[48;5;%sm      \e[0m" $i; done; echo
for i in $(seq $r $((r+7))); do printf "   %2d  " $i; done; echo; echo; done
for r in 0 8; do for i in $(seq $r $((r+7))); do printf "\e[38;5;%sm colour%-2d\e[0m" $i $i; done; echo; done
printf "\n \e[1mbold\e[0m  \e[2mdim\e[0m  \e[3mitalic\e[0m  \e[4munderline\e[0m  \e[7mreverse\e[0m  \e[9mstrike\e[0m\n"
exec sleep 86399'
  k footclient -a swatch -T colours bash -c "$sw" >>"$LT/footclient.log" 2>&1 &
  pid=$!
  waitfor 10 "the swatch window" foot_window swatch || return
  sleep 1.2
  geom=$(foot_window swatch)
  grim -g "$geom" "$OT/colors.png" && say "$T: colors.png ($geom)"
  pkill -u "$K" -fx 'sleep 86399' 2>/dev/null           # its window closes, footclient exits
  waitpid 5 "$pid" || true
  # the clipboard history (Super+V): kawa-clip opens its own floating window (fzf)
  k kawa-clip >"$LT/kawa-clip.log" 2>&1 &
  pid=$!
  if waitfor 10 "the clipboard window" foot_window float; then
    sleep 2
    geom=$(foot_window float)
    grim -g "$geom" "$OT/clipboard.png" && say "$T: clipboard.png ($geom)"
    grim "$OT/clipboard-full.png"
    k wtype -s 300 -k Down -s 300 -k Down; sleep 2.5      # the picture entry, previewed (-s: the keymap first)
    geom=$(foot_window float)
    grim -g "$geom" "$OT/clipboard-picture.png" && say "$T: clipboard-picture.png"
    k wtype -k Escape
  fi
  waitpid 5 "$pid" || true
  # the wallpaper picker (Super+W): its own floating window (fzf), the picture underneath
  k kawa-wallpaper >"$LT/kawa-wallpaper.log" 2>&1 &
  pid=$!
  if waitfor 10 "the wallpaper window" foot_window float; then
    sleep 4                                              # the previews drawn ahead
    k wtype -s 300 -k Down -s 300 -k Down; sleep 2.5
    geom=$(foot_window float)
    grim -g "$geom" "$OT/wallpaper-picker.png" && say "$T: wallpaper-picker.png ($geom)"
    grim "$OT/wallpaper-picker-full.png"
    k wtype -k Escape
  fi
  waitpid 10 "$pid" || true
  k foot --check-config >"$LT/foot-check-config.log" 2>&1; echo "exit $?" >>"$LT/foot-check-config.log"
}

shot_lock() {
  img grab "$W/base.ppm"
  k kawa-lock >"$LT/gtklock.log" 2>&1 &
  local r
  if r=$(img capture "$W/base.ppm" "$OT/lock.png" "$W/lock-crop.png" --timeout 10 --min 0.8 --settle 0.8 2>>"$LT/gtklock.log"); then
    say "$T: lock.png"
    # the middle at 1:1, and again with a password half typed (the ◆ dots)
    python3 -I -c 'import sys; from PIL import Image; im=Image.open(sys.argv[1]); w,h=im.size; im.crop((w//2-220,h//2-230,w//2+220,h//2+230)).save(sys.argv[2])' \
      "$OT/lock.png" "$OT/lock-center.png"
    k wtype "secret"; sleep 0.4
    grim "$W/typing.png" && python3 -I -c 'import sys; from PIL import Image; im=Image.open(sys.argv[1]); w,h=im.size; im.crop((w//2-220,h//2-230,w//2+220,h//2+230)).save(sys.argv[2])' \
      "$W/typing.png" "$OT/lock-typing-center.png"
  else
    warn "$T: the lock screen could not be captured (see $LT/gtklock.log)"
  fi
  pkill -x gtklock 2>/dev/null
}

time_switch() {   # how long a theme switch takes before anything moves (round 18 #141)
  local other=light i; [[ $T == light ]] && other=dark
  # 1. the apply alone, every command timed (bash xtrace with timestamps)
  k env KAWA_VEILED=1 PS4='+ $EPOCHREALTIME ' bash -x "$(k sh -c 'command -v kawa-theme')" "$other" >"$LT/switch-trace.log" 2>&1
  k env KAWA_VEILED=1 PS4='+ $EPOCHREALTIME ' bash -x "$(k sh -c 'command -v kawa-theme')" "$T" >>"$LT/switch-trace.log" 2>&1
  # 2. the full switch, veil and all: frames grabbed while it runs, first change timed
  img grab "$W/sw0.ppm"
  local t0; t0=$EPOCHREALTIME
  k kawa-theme "$other" >"$LT/switch-full.log" 2>&1 &
  local pid=$!
  for ((i = 1; i <= 60; i++)); do img grab "$W/sw$i.ppm"; echo "$i $EPOCHREALTIME" >>"$LT/switch-frames.log"; kill -0 $pid 2>/dev/null || break; done
  wait $pid; echo "total $(bc <<<"$EPOCHREALTIME - $t0") t0 $t0" >>"$LT/switch-frames.log"
  for ((j = 1; j <= i; j++)); do echo "$j $(img bbox "$W/sw0.ppm" "$W/sw$j.ppm")" ; done >>"$LT/switch-frames.log"
  k env KAWA_VEILED=1 kawa-theme "$T" >/dev/null 2>&1
}

inner() {
  T=$1 OT=$OUT/$1 LT=$LOG/$1 W=$SH/work-$1
  mkdir -p "$OT" "$LT"; rm -rf "$W"; mkdir -p "$W"
  # a full run starts clean; a partial one (SHOOT_ONLY) replaces only what it shoots
  # (apps.sh's app-*.png and logs/<theme>/apps/ are its own: left alone)
  [[ $ONLY == "bar menus notify term lock" ]] && { find "$OT" -maxdepth 1 -name '*.png' ! -name 'app-*' -delete; rm -f "$LT"/*.log; }
  session
  want bar    && shot_bar
  want menus  && shot_menus
  want notify && shot_notify
  want term   && shot_term
  want lock   && shot_lock
  want switch && time_switch
  # let the apps say goodbye (flushes their logs), then the namespace ends
  exec 7>&-
  pkill -TERM -u "$K" 2>/dev/null; sleep 1
  say "$T: done"
}

if [[ ${1:-} == --inner ]]; then
  shift; inner "$@"
else
  outer "$@"
fi
