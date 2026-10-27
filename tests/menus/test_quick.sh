#!/usr/bin/env bash
# tests/menus/test_quick.sh — kawa-quick, quick settings' model (the panel, kawa-panel, draws
# it: test_panel.sh): what --state says for the machine's state (wired, a Wi-Fi by its name,
# offline, a VPN; a Bluetooth adapter or none, on, off, blocked, the devices connected; the
# night light; FreeSync; do not disturb; the theme; the brightness, the sound, the wallpaper;
# drives), what each --do does, do not disturb's own dropdown (kawa-quick dnd: its lines for each
# state, what each choice sets, a timed one's end handed to systemd) and the toggle that opens
# and closes the panel.
# The machine is made up: nmcli, busctl, bluetoothctl, makoctl (its modes in a file), systemd-run
# and systemctl (logged), gammastep (a process table in
# a file), kawa-theme, kawa-drives and kawa-weather are stand-ins; whether there is a
# Bluetooth adapter is a tmpfs over /sys/class in a namespace of its own (ns). The backup row
# shows what kawa-backup status says (a stand-in: $W/backup).
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"

setup() {
  menus_sandbox; config .config/fedokawaii/env
  W=$TMP/world; mkdir -p "$W"; export W
  printf '%s\n' 'ethernet:connected:Wired connection 1' wifi:disconnected: 'loopback:connected (externally):lo' >"$W/nm"
  echo 'b true' >"$W/bt"; : >"$W/procs"; echo default >"$W/modes"; : >"$W/drives"; BT=1
  local sun; sun=$(. "$REPO/configs/home/.config/fedokawaii/icons.sh"; printf %s "$ICON_SUN")   # (the bar's sun, by name)
  stub kawa-weather '[ "$1" = --bar ] && printf "{\"text\":\"%s +31°\",\"tooltip\":\"Sharjah\"}\n" "'"$sun"'"'
  stub nmcli '[ -f "$W/nm.missing" ] && exit 127; [ "$*" = "-t -f TYPE,STATE,CONNECTION device" ] && cat "$W/nm"'
  # bluetoothd answering on the system bus (Powered as busctl prints it), or not running
  stub busctl '[ -s "$W/bt" ] || exit 1; cat "$W/bt"'
  stub bluetoothctl 'case "$1" in
  show) [ -s "$W/bt" ] || { /bin/sleep 5; exit 1; }; [ "$(cat "$W/bt")" = "b true" ] && echo "	Powered: yes" || echo "	Powered: no" ;;
  devices) [ "$2" = Connected ] && cat "$W/btdev" 2>/dev/null ;;
  power) [ -s "$W/bt" ] || { /bin/sleep 5; exit 1; }
         if [ "$2" = on ] && [ -e "$W/rfkill" ]; then echo "Failed to set power on: org.bluez.Error.Blocked"; exit 1; fi
         [ "$2" = on ] && echo "b true" >"$W/bt" || echo "b false" >"$W/bt"; echo "Changing power $2 succeeded" ;;
esac'
  # gammastep: a name in $W/procs while it runs; the first signal starts its fade (it keeps
  # running), the second ends it
  stub pgrep 'grep -qx gammastep "$W/procs" 2>/dev/null; exit $?'
  stub pkill 'grep -qx gammastep "$W/procs" || exit 1
if [ -e "$W/fading" ]; then : >"$W/procs"; rm -f "$W/fading"; else : >"$W/fading"; fi'
  stub setsid '[ "$2" = gammastep ] || exit 0
echo "stdin: $(readlink /proc/$$/fd/0 || echo closed)" >>"$W/gammastep.stdin"
[ -e "$W/no-gammastep" ] || echo gammastep >>"$W/procs"'
  # mako's modes, in $W/modes: makoctl mode lists them, -a adds one, -r takes one away
  stub makoctl 'case "$*" in
  "mode") cat "$W/modes" ;;
  "mode -a "*) grep -qx "$3" "$W/modes" || echo "$3" >>"$W/modes" ;;
  "mode -r "*) sed -i "/^$3\$/d" "$W/modes" ;;
  *) echo "makoctl: not stubbed: $*" >&2; exit 1 ;;
esac'
  stub systemctl; stub systemd-run          # (a timed quiet time's end: logged, nothing really scheduled)
  stub kawa-theme '[ "$1" = toggle ] || exit 2
cd "$HOME/.config/fedokawaii" && if [ "$(readlink current)" = themes/dark ]; then ln -sfn themes/light current; else ln -sfn themes/dark current; fi'
  stub kawa-drives '[ "$1" = list ] && cat "$W/drives"'
  stub kawa-backup 'case $1 in status) cat "$W/backup" ;; esac'; echo never >"$W/backup"
  stub sleep; stub gammastep                       # (started through setsid: never itself)
  # the brightness kawa-brightness last read (its --level), the sound's level (wpctl)
  stub kawa-brightness '[ "$1" = --level ] && cat "$W/bright" 2>/dev/null'; echo 70 >"$W/bright"
  stub wpctl '[ "$1" = get-volume ] && cat "$W/vol"'; echo 'Volume: 0.62' >"$W/vol"
  for s in kawa-panel kawa-term kawa-screenshot kawa-wallpaper kawa-power kawa-record; do stub "$s"; done
  stub kawa-brightness '[ "$1" = --level ] && { cat "$W/bright" 2>/dev/null; exit; }; echo "$1" >"$W/bright"'
  stub wpctl 'case $1 in get-volume) cat "$W/vol" ;; set-volume) echo "Volume: 0.$(printf %02d "${3%%%}")" >"$W/vol" ;; esac'
}
QENV=(LC_ALL=C.UTF-8)
quick() {   # quick [ARG…] — kawa-quick on the made-up machine (an adapter or none: $BT; locale: $QENV)
  if ((NS)); then
    ns "mount -t tmpfs none /sys/class$( ((BT)) && printf '; mkdir -p /sys/class/bluetooth/hci0')" env "${QENV[@]}" kawa-quick "$@"
  else env "${QENV[@]}" kawa-quick "$@"; fi
}
state() { quick --state; }
st() { state | sed -n "s/^$1\t//p"; }     # st KEY — its value now
. "$HOME/.config/fedokawaii/icons.sh" 2>/dev/null || true
setup; . "$HOME/.config/fedokawaii/icons.sh"

# ── what it says ──────────────────────────────────────────────────────────────────────
case_ "--state: every key, in order, one KEY<TAB>VALUE a line"
out=$(state); rc 0 quick --state
keys=$(cut -f1 <<<"$out" | tr '\n' ',')
if ((NS)); then
  eq "$keys" "theme,brightness,night,vrr,wallpaper,sound,nettype,network,bluetooth,devices,drives,backup,dnd,saver,record,vrrnow,"
else has "$keys" "theme,brightness,night,vrr,wallpaper,sound,nettype,network,"; fi
eq "$(grep -vc $'^[a-z]*\t' <<<"$out")" 0 "every line a key, a tab, a value"
eq "$(st theme)" dark; eq "$(st nettype)" ethernet; eq "$(st network)" wired
eq "$(st brightness)" 70%; eq "$(st sound)" 62%; eq "$(st wallpaper)" default; eq "$(st vrr)" "in games"
eq "$(st night)" off; eq "$(st dnd)" off; eq "$(st drives)" none; eq "$(st backup)" never
eq "$(st weather)" "" "no weather: the bar shows it, right above the panel"
not_called '^kawa-weather' "the panel never asks for it"
((NS)) && eq "$(st bluetooth)" on
case_ "the widest states: light theme, 12 drives plugged in, everything on, a backup 1000 days ago — whole (the panel cuts them to its tiles)"
ln -sfn themes/light "$HOME/.config/fedokawaii/current"; echo gammastep >"$W/procs"; echo "1000 days ago" >"$W/backup"
printf 'do-not-disturb\nsharing\n' >"$W/modes"
for i in {1..12}; do printf '/dev/sd%s1\t/dev/sd%s\tSTICK %s\t8G\tvfat\t\n' "$i" "$i" "$i"; done >"$W/drives"
eq "$(st theme)" light; eq "$(st drives)" "STICK 1 +11"; eq "$(st night)" 4000K; eq "$(st backup)" "1000 days ago"
eq "$(st dnd)" on "on, though sharing is on too"
case_ "a drive with two file systems counts once"
printf '/dev/sdb1\t/dev/sdb\tA\n/dev/sdb2\t/dev/sdb\tB\n/dev/mmcblk0p1\t/dev/mmcblk0\tC\n' >"$W/drives"
eq "$(st drives)" "A +1" "the first one's name and how many more (the count alone is the bar's)"
case_ "one drive: its name and size, whole"
printf '/dev/sdb1\t/dev/sdb\tSANDISK EXTREME PRO\t58G\texfat\t\n' >"$W/drives"; eq "$(st drives)" "SANDISK EXTREME PRO 58G"
case_ "the sound muted, no output at all; no DDC/CI monitor; a picture of your own on the wallpaper"
setup; echo 'Volume: 0.40 [MUTED]' >"$W/vol"; : >"$W/bright"; mkdir -p "$HOME/.local/state/fedokawaii"
echo "$HOME/Pictures/Wallpapers/my beach photo, from the long summer.jpg" >"$HOME/.local/state/fedokawaii/wallpaper-dark"
eq "$(st sound)" muted; eq "$(st brightness)" "no DDC/CI"; eq "$(st wallpaper)" "my beach photo, from the long summer"
echo pack:mishima-mist >"$HOME/.local/state/fedokawaii/wallpaper-dark"; eq "$(st wallpaper)" mishima-mist
stub wpctl 'exit 1'; eq "$(st sound)" "no output"
case_ "a name with a tab or a line break in it: one line still"
setup; mkdir -p "$HOME/.local/state/fedokawaii"; printf '%s\n' "$HOME/Pictures/a"$'\t'"b.jpg" >"$HOME/.local/state/fedokawaii/wallpaper-dark"
eq "$(st wallpaper)" "a b"; eq "$(state | grep -c .)" "$(state | cut -f1 | grep -c '^[a-z]*$')"

# ── the network ────────────────────────────────────────────────────────────────────────
nm() { printf '%s\n' "$@" >"$W/nm"; }
case_ "network: Wi-Fi only: its name"
setup; nm 'wifi:connected:Home Net 5G' ethernet:unavailable: 'loopback:connected (externally):lo'
eq "$(st network)" "Home Net 5G"; eq "$(st nettype)" wifi
case_ "network: wired and Wi-Fi both up: the first nmcli lists"
nm ethernet:connected:eth wifi:connected:Home; eq "$(st network)" wired
case_ "network: nothing connected (cable out, no Wi-Fi joined): offline"
nm ethernet:unavailable wifi:disconnected 'wifi-p2p:disconnected' 'loopback:connected (externally)'
eq "$(st network)" offline; eq "$(st nettype)" offline
case_ "network: Wi-Fi radio off, or blocked by rfkill (nmcli: unavailable): offline"
nm 'ethernet:unavailable' 'wifi:unavailable'; eq "$(st network)" offline
case_ "network: no Wi-Fi device at all, joining (still connecting): offline"
nm 'ethernet:connecting (getting IP configuration)'; eq "$(st network)" offline
case_ "network: a VPN listed first (WireGuard holding the default route): still the Wi-Fi"
nm wireguard:connected:wg0 wifi:connected:Home 'loopback:connected (externally):lo'
eq "$(st network)" Home; eq "$(st nettype)" wifi
nm 'tun:connected (externally):tun0' ethernet:connected:eth; eq "$(st network)" wired
nm bridge:connected:br0 ethernet:connected:eth; eq "$(st network)" wired "a bridge for virtual machines over the cable"
case_ "network: a phone's mobile data (gsm) listed before the Wi-Fi: still the Wi-Fi; alone: its own name"
nm gsm:connected:phone wifi:connected:Home; eq "$(st network)" Home
nm gsm:connected:phone ethernet:unavailable:; eq "$(st network)" gsm
case_ "network: a cable another tool configured (connected externally): wired"
nm 'ethernet:connected (externally):x' 'loopback:connected (externally):lo'; eq "$(st network)" wired
case_ "network: a Wi-Fi without a connection name: Wi-Fi"
nm 'wifi:connected:'; eq "$(st network)" Wi-Fi
case_ "network: nmcli missing or NetworkManager not running: offline, and the rest still said"
: >"$W/nm.missing"; eq "$(st network)" offline; eq "$(st theme)" dark; rm "$W/nm.missing"
stub nmcli 'echo "Error: NetworkManager is not running." >&2; exit 8'; eq "$(st network)" offline
case_ "network: garbage from nmcli (escaped colons, empty lines): offline, no error"
stub nmcli 'printf "\n:\nwifi\\\\:x:connected\n::::\n"'; out=$(quick --state 2>&1 >/dev/null); eq "$out" ""
eq "$(st network)" offline
case_ "network: nmtui in a floating window (once)"
setup; rc 0 quick --do network
called '^kawa-term --float --once network network 80x25 -- nmtui$'
case_ "nmcli asked once for everything (SSIDs never reach a menu row: nmtui lists them)"
setup; reset_calls; state >/dev/null; eq "$(grep -c '^nmcli' "$CALLS")" 1; called '^nmcli -t -f TYPE,STATE,CONNECTION device$'

# ── Bluetooth ─────────────────────────────────────────────────────────────────────────
if ((NS)); then
  case_ "no Bluetooth adapter: no bluetooth or devices, and bluetoothd is never asked"
  setup; BT=0; reset_calls; out=$(state)
  lacks "$out" bluetooth; lacks "$out" devices
  not_called '^busctl'; not_called '^bluetoothctl'
  case_ "an adapter, powered off: off"
  setup; echo 'b false' >"$W/bt"; eq "$(st bluetooth)" off
  case_ "bluetoothd not running: off, at once (busctl fails) — bluetoothctl never asked instead"
  setup; : >"$W/bt"; reset_calls; SECONDS=0; eq "$(st bluetooth)" off
  ((SECONDS <= 2)) && _ok || _no "took ${SECONDS}s"; not_called '^bluetoothctl'
  case_ "switching it: off → on → off, the state following"
  setup; echo 'b false' >"$W/bt"; rc 0 quick --do bluetooth; eq "$(st bluetooth)" on; eq "$(kawa-state get bluetooth)" on "kept"
  rc 0 quick --do bluetooth; eq "$(st bluetooth)" off; eq "$(kawa-state get bluetooth)" off "kept"
  called '^bluetoothctl power on$'; called '^bluetoothctl power off$'
  case_ "Bluetooth blocked by rfkill: switching on fails — a notice says why, exit 1"
  setup; echo 'b false' >"$W/bt"; : >"$W/rfkill"; rc 1 quick --do bluetooth
  eq "$(st bluetooth)" off; rc 1 kawa-state get bluetooth   # (a switch that failed is not kept)
  called 'notify-send -a desktop .*Bluetooth.*rfkill unblock bluetooth'
  case_ "devices: the ones connected now — none, one by its name, more by their count; off while Bluetooth is"
  setup; eq "$(st devices)" none
  echo "Device AA:BB:CC:DD:EE:FF WH-1000XM5" >"$W/btdev"; eq "$(st devices)" WH-1000XM5
  printf 'Device AA:BB:CC:DD:EE:FF WH-1000XM5\nDevice 11:22:33:44:55:66 Keychron K2\n' >"$W/btdev"; eq "$(st devices)" "2 connected"
  echo 'b false' >"$W/bt"; eq "$(st devices)" off
  case_ "devices: bluetui in a floating terminal of its own (once)"
  setup; rc 0 quick --do devices
  called "^kawa-term --float --once pair pair a device 96x29 -- bluetui\$"
  not_called 'setsid|blueman'
fi
case_ "bluetui's config: TOML, Esc quits (its own key q does too); its colours are the terminal's"
f=$REPO/configs/home/.config/bluetui/config.toml
eq "$(python3 -I -c 'import sys, tomllib; c = tomllib.load(open(sys.argv[1], "rb")); print(c.get("esc_quit"), sorted(c))' "$f")" "True ['esc_quit']"
lacks "$(cat "$f")" "#[0-9a-f]"
case_ "bluetui comes from lib/upstream.sh, pinned (a static x86_64 binary, v0.8.2); blueman is forbidden and retired"
e=$(. "$REPO/lib/upstream.sh"; printf '%s\n' "${UPSTREAM[@]}" | grep '^bluetui|')
eq "$(cut -d'|' -f2-4,6 <<<"$e")" "pythops/bluetui|v0.8.2|bluetui-x86_64-linux-musl|bluetui"
[[ $(cut -d'|' -f5 <<<"$e") =~ ^[0-9a-f]{64}$ ]] && _ok || _no "no SHA-256 pinned"
m() { (STEAM=yes; . "$REPO/lib/manifest.sh"; eval "$1"); }
lacks " $(m 'manifest_all amd' | tr '\n' ' ') " " blueman "; has " $(m 'manifest_all amd' | tr '\n' ' ') " " bluez "
has " $(m 'echo "${FORBIDDEN_PKGS[*]}"') " " blueman "; has " $(m 'echo "${RETIRED_PKGS[*]}"') " " blueman "
has "$(grep -E '^bluetui ' "$REPO/tests/static/fixtures/programs.txt")" "upstream"
lacks "$(cat "$REPO/tests/static/fixtures/programs.txt" "$REPO/src/dwl/config.h")" blueman

# ── night light (kawa-night): as you set it, day and night alike, kept across logins ───
nl() { echo "$HOME/.local/state/fedokawaii/night"; }   # (each sandbox its own HOME)
case_ "night light off → on: one gammastep at the kept warmth (4000 K at first), day and night alike — never by the sun"
setup; rc 0 quick --do night
called '^setsid -f gammastep -m wayland -r -l 0:0 -t 4000:4000$'; eq "$(st night)" 4000K
eq "$(cat "$(nl)")" "on 4000" "kept: the next login finds it on"
case_ "night light on → off: it ends (gone when kawa-night returns), and off is kept"
setup; echo gammastep >"$W/procs"; mkdir -p "$(dirname "$(nl)")"; echo "on 3500" >"$(nl)"; rc 0 quick --do night
eq "$(st night)" off "off at once"
eq "$(cat "$(nl)")" "off 3500" "off kept, the warmth too"
case_ "night light on → off → on, fast: one gammastep in the end, the state right each time"
setup; echo gammastep >"$W/procs"
quick --do night; a=$(st night); quick --do night; b=$(st night); quick --do night; c=$(st night)
eq "$a $b $c" "off 4000K off"
quick --do night; eq "$(grep -c . "$W/procs")" 1 "one gammastep running"
case_ "warmer, cooler (the wheel over the tile): a step of 500 K, on, within 5500…2500 K, kept"
setup; quick --do warmer; eq "$(st night)" 3500K; eq "$(cat "$(nl)")" "on 3500"
for _ in 1 2 3 4; do quick --do warmer; done; eq "$(st night)" 2500K "no warmer than 2500 K"
for _ in 1 2 3 4 5 6 7 8; do quick --do cooler; done; eq "$(st night)" 5500K "no cooler than 5500 K"
called '^setsid -f gammastep -m wayland -r -l 0:0 -t 5500:5500$'
case_ "at login (autostart: kawa-night restore): as last left — on at its warmth, or off"
setup; mkdir -p "$(dirname "$(nl)")"; echo "on 3000" >"$(nl)"; rc 0 kawa-night restore
called '^setsid -f gammastep -m wayland -r -l 0:0 -t 3000:3000$'; eq "$(st night)" 3000K
setup; mkdir -p "$(dirname "$(nl)")"; echo "off 3000" >"$(nl)"; rc 0 kawa-night restore; not_called '^setsid'; eq "$(st night)" off
setup; rc 0 kawa-night restore; not_called '^setsid' "never set: off"
setup; mkdir -p "$(dirname "$(nl)")"; echo "on 9999" >"$(nl)"; kawa-night restore; called '^setsid -f gammastep .* -t 4000:4000$' "a warmth it does not know: the default"
grep -q '^kawa-night restore' "$REPO/configs/home/.config/dwl/autostart.sh" && _ok || _no "autostart does not restore it"
grep -q 'gammastep -l' "$REPO/configs/home/.config/dwl/autostart.sh" && _no "autostart still starts gammastep by the sun" || _ok
case_ "gammastep started with stdin on /dev/null (not closed: the next file it opens is not fd 0)"
setup; quick --do night; eq "$(cat "$W/gammastep.stdin")" "stdin: /dev/null"
case_ "gammastep not starting: it stays off, no loop, no error on screen"
setup; : >"$W/no-gammastep"; out=$(quick --do night 2>&1); eq "$out" ""; eq "$(st night)" off
case_ "kawa-night: --help, and anything else is wrong use"
setup; rc 0 kawa-night --help; has "$(kawa-night --help)" "never follows the sun"; rc 2 kawa-night brighter

# ── the screensaver ──────────────────────────────────────────────────────────────────────
case_ "the screensaver: on (after 15 min) unless switched off; a click switches it, kept for kawa-saver"
setup; eq "$(st saver)" "15 min"
SV=$HOME/.local/state/fedokawaii/saver
quick --do saver; eq "$(st saver)" off; eq "$(cat "$SV")" off
quick --do saver; eq "$(st saver)" "15 min"; eq "$(cat "$SV")" on
echo 7 >"$SV"; eq "$(st saver)" "15 min" "anything but off: on (kawa-saver reads it so too)"

# ── do not disturb, the theme, FreeSync, the levels, the rest ────────────────────────
case_ "dnd: a switch — mako's quiet mode added, then taken away; kept for the next login; the bar's bell poked"
setup; quick --do dnd; eq "$(st dnd)" on; eq "$(kawa-state get dnd)" on "kept for the next login"
quick --do dnd; eq "$(st dnd)" off; eq "$(kawa-state get dnd)" off
eq "$(grep -c '^makoctl mode -a do-not-disturb$' "$CALLS")" 1; eq "$(grep -c '^makoctl mode -r do-not-disturb$' "$CALLS")" 1
not_called '^makoctl mode -t' "(the old toggle is gone: what it does is added or removed, never guessed)"
eq "$(grep -c '^kawa-dwlstatus --poke 12$' "$CALLS")" 2 "the bell poked at every change"
case_ "dnd while a screen is shared (mode sharing): still its own switch"
setup; echo sharing >"$W/modes"; quick --do dnd
eq "$(sort "$W/modes" | tr '\n' ' ')" "do-not-disturb sharing "
quick --do dnd; eq "$(sort "$W/modes" | tr '\n' ' ')" "sharing " "off again: the share's mode is left as it is"

# ── do not disturb: set (--do dnd on|off|hour|morning) ────────────────────────────────
modes() { sort "$W/modes" | paste -sd' '; }                       # mako's modes now
rec() { echo "$XDG_RUNTIME_DIR/kawa-dnd.until"; }                  # a timed one's record: EPOCH CHOICE
# tz_at HOUR — a fixed-offset zone in which it is HOUR o'clock now: the morning (8:00) it
# offers is today's before 8:00, tomorrow's after it
tz_at() { printf 'KAWA%s' "$(( $(date -u +%-H) - $1 ))"; }
case_ "dnd on: the quiet mode added, kept for the next login, no timer; the timer of an earlier timed one stopped"
setup; rc 0 quick --do dnd on
eq "$(st dnd)" on; eq "$(modes)" "default do-not-disturb"; eq "$(kawa-state get dnd)" on "an untimed one is kept"
called '^makoctl mode -a do-not-disturb$'; called '^systemctl --user stop kawa-dnd-end.timer kawa-dnd-end.service$'
called '^kawa-dwlstatus --poke 12$'; not_called '^systemd-run'
[[ ! -e $(rec) ]] && _ok || _no "a record of an end for an untimed one: $(cat "$(rec)")"
case_ "dnd off: the quiet mode taken away (the others left), kept off, the bell poked, the timer stopped"
setup; printf 'default\ndo-not-disturb\nsharing\n' >"$W/modes"; kawa-state set dnd on; echo "$(( $(date +%s) + 600 )) hour" >"$(rec)"
rc 0 quick --do dnd off
eq "$(st dnd)" off; eq "$(modes)" "default sharing"; eq "$(kawa-state get dnd)" off
called '^makoctl mode -r do-not-disturb$'; called '^systemctl --user stop kawa-dnd-end.timer kawa-dnd-end.service$'; called '^kawa-dwlstatus --poke 12$'
[[ ! -e $(rec) ]] && _ok || _no "the record of its end is still there"
case_ "dnd for an hour: the end handed to a systemd timer (an hour on), the quiet mode added, NOT kept across a login, the record 'EPOCH hour' written"
setup; t0=$EPOCHSECONDS; rc 0 quick --do dnd hour
eq "$(st dnd)" on; eq "$(modes)" "default do-not-disturb"; eq "$(kawa-state get dnd)" off "timed: a login ends it, so it is not kept"
called "^systemd-run --user --quiet --collect --unit=kawa-dnd-end --on-active=(3600|3599)s --timer-property=AccuracySec=1s --setenv=PATH=$PATH -- kawa-quick --do dnd end\$"
has "$(grep '^systemd-run ' "$CALLS")" "--setenv=PATH=$PATH" "the end runs with this PATH (your systemd's has no ~/.local/bin: kawa-state, kawa-dwlstatus)"
read -r end choice <"$(rec)"; eq "$choice" hour
((end >= t0 + 3600 && end <= EPOCHSECONDS + 3600)) && _ok || _no "the end $((end - t0)) s from the start, not 3600"
called '^kawa-dwlstatus --poke 12$'
# (the order that matters: an earlier timer stopped first, or the new one would go with it)
eq "$(grep -E '^(systemctl --user stop|systemd-run|makoctl mode -a)' "$CALLS" | awk '{ printf "%s|", $1 }')" \
  "systemctl|systemd-run|makoctl|" "stopped, then scheduled, then quiet"
case_ "dnd until the morning (8:00), before 8:00: today's, the timer for the seconds to it"
setup; tz=$(tz_at 3); t0=$(TZ=$tz date +%s); want=$(TZ=$tz date -d 'today 08:00' +%s)
TZ=$tz rc 0 quick --do dnd morning
read -r end choice <"$(rec)"; eq "$choice" morning; eq "$end" "$want" "today at 8:00"
n=$(grep -Eo -- '--on-active=[0-9]+s' "$CALLS" | tr -dc 0-9); ((n >= want - t0 - 3 && n <= want - t0 + 3)) && _ok || _no "the timer is for ${n}s, not $((want - t0))s"
eq "$(modes)" "default do-not-disturb"; eq "$(kawa-state get dnd)" off "timed: not kept"
called ' -- kawa-quick --do dnd end$'
case_ "dnd until the morning, after 8:00: tomorrow's"
setup; tz=$(tz_at 12); t0=$(TZ=$tz date +%s); want=$(TZ=$tz date -d 'tomorrow 08:00' +%s)
TZ=$tz rc 0 quick --do dnd morning
read -r end choice <"$(rec)"; eq "$end" "$want" "tomorrow at 8:00"
n=$(grep -Eo -- '--on-active=[0-9]+s' "$CALLS" | tr -dc 0-9); ((n >= want - t0 - 3 && n <= want - t0 + 3)) && _ok || _no "the timer is for ${n}s, not $((want - t0))s"
((n > 0 && n <= 24 * 3600)) && _ok || _no "a timer of ${n}s is not within a day"
case_ "dnd timed, then another: the first one's timer stopped and its record replaced; then on: no end at all"
setup; rc 0 quick --do dnd hour; rc 0 quick --do dnd morning
eq "$(grep -c '^systemctl --user stop kawa-dnd-end.timer kawa-dnd-end.service$' "$CALLS")" 2 "each change stops the one before"
eq "$(cut -d' ' -f2 "$(rec)")" morning
rc 0 quick --do dnd on; [[ ! -e $(rec) ]] && _ok || _no "an untimed one with an end on record"
eq "$(kawa-state get dnd)" on; eq "$(modes)" "default do-not-disturb"
case_ "dnd: the timer that ends it runs kawa-quick --do dnd end — quiet over, record gone, the state follows, the bell poked; only the timer stopped, never the service it runs in (that would kill it first)"
setup; rc 0 quick --do dnd hour; reset_calls; rc 0 quick --do dnd end
eq "$(st dnd)" off; eq "$(modes)" default; [[ ! -e $(rec) ]] && _ok || _no "the record is left"
called '^systemctl --user stop kawa-dnd-end.timer$'; not_called 'stop kawa-dnd-end.timer kawa-dnd-end.service'
called '^makoctl mode -r do-not-disturb$'; called '^kawa-dwlstatus --poke 12$'; eq "$(kawa-state get dnd)" off
case_ "dnd timed, but systemd cannot set its end: NO quiet at all (one that never ended would hide every notice for good), a notice says why"
setup; stub systemd-run 'exit 1'
for w in hour morning; do
  reset_calls; quick --do dnd "$w" >/dev/null 2>&1
  eq "$(modes)" default "$w: mako's modes untouched"; eq "$(st dnd)" off
  not_called '^makoctl mode -a'; [[ ! -e $(rec) ]] && _ok || _no "$w: a record of an end that was never set"
  called "^notify-send -a desktop -- $ICON_BELL_OFF  do not disturb its end could not be set \(systemd --user\) — it stays off\$"
  called '^kawa-dwlstatus --poke 12$'
  eq "$(kawa-state get dnd)" off "$w: nothing kept"
done
case_ "dnd until the morning, the morning not worked out (date fails): nothing set, exit 1"
setup; stub date '[ "$*" = "-d today 08:00 +%s" ] && exit 1; exec /bin/date "$@"'
rc 1 quick --do dnd morning; eq "$(modes)" default; not_called '^makoctl mode -a'; not_called '^systemd-run'
case_ "dnd: wrong use — a word it does not know, a third argument"
setup; rc 2 quick --do dnd bogus; rc 2 quick --do dnd on extra; rc 2 kawa-quick --do dnd hours
not_called '^makoctl'

# ── do not disturb: its dropdown (kawa-quick dnd) ─────────────────────────────────────
# the bar's quiet bell opens it: a part line, then off · for an hour · until the morning · on,
# the one in force an "on" line with the cursor on it
dndm() { env "${QENV[@]}" kawa-quick dnd; }                       # the dropdown, on the made-up machine
kinds() { fz_rows | cut -f1 | tr '\n' ' '; }
names() { fz_rows | cut -f3 | tr '\n' '|'; }
case_ "the dropdown, nothing set: a part line (the quiet bell, do not disturb), four rows, off in force — an on line, the cursor on it"
setup; answer esc; rc 0 dndm
eq "$(fz_rows | sed -n 1p | cut -f1-3)" "part	$ICON_BELL_OFF	do not disturb" "the heading: the quiet bell, the name"
eq "$(fz_rows | sed -n 1p | cut -f4)" "" "nothing timed: no end at the heading's end"
eq "$(names)" "do not disturb|off|for an hour|until the morning|on|"
eq "$(fz_rows | sed -n '2,5p' | cut -f2 | tr '\n' ' ')" "$ICON_BELL $ICON_HOURGLASS $ICON_MOON $ICON_BELL_OFF " "each its own icon: the bell, the hourglass, the moon, the quiet bell"
eq "$(kinds)" "part on row row row " "off is in force"
eq "$(fz_arg select)" 1 "the cursor on it"; eq "$(fz_arg drop)" set "a dropdown from the bar"; eq "$(fz_arg index)" set; eq "$(fz_arg middle)" "" "under its own tile, not the date's middle"
eq "$(fz_rows | sed -n 2p | cut -f4)" "notices as they come"; eq "$(fz_rows | sed -n 5p | cut -f4)" "until you turn it off"
fits
case_ "… the hour's and the morning's words: until H:MM an hour on, 8:00 (today's, before 8:00) or 8:00 tomorrow"
setup; answer esc; a=$(date -d '+1 hour' +%-H:%M); rc 0 dndm; b=$(date -d '+1 hour' +%-H:%M)
v=$(fz_rows | sed -n 3p | cut -f4); [[ $v == "until $a" || $v == "until $b" ]] && _ok || _no "an hour on is [$v], not until $a"
setup; answer esc; QENV=(LC_ALL=C.UTF-8 "TZ=$(tz_at 3)"); rc 0 dndm
eq "$(fz_rows | sed -n 4p | cut -f4)" "8:00" "before 8:00: this morning's"
setup; answer esc; QENV=(LC_ALL=C.UTF-8 "TZ=$(tz_at 12)"); rc 0 dndm
eq "$(fz_rows | sed -n 4p | cut -f4)" "8:00 tomorrow" "after 8:00: tomorrow's"
QENV=(LC_ALL=C.UTF-8)
case_ "the dropdown, on with no end (quiet until you turn it off): on is the line in force, the cursor on it, no end at the heading"
setup; echo do-not-disturb >>"$W/modes"; answer esc; rc 0 dndm
eq "$(kinds)" "part row row row on "; eq "$(fz_arg select)" 4; eq "$(fz_rows | sed -n 1p | cut -f4)" ""
case_ "the dropdown, timed for an hour: for an hour is the line in force, the end at the heading's end (until H:MM)"
setup; echo do-not-disturb >>"$W/modes"; end=$(( $(date +%s) + 2400 )); echo "$end hour" >"$(rec)"; answer esc; rc 0 dndm
eq "$(kinds)" "part row on row row "; eq "$(fz_arg select)" 2
eq "$(fz_rows | sed -n 1p | cut -f4)" "$(date -d "@$end" '+until %-H:%M')" "the heading's end: when it ends"
case_ "the dropdown, timed until the morning: until the morning is the line in force"
setup; echo do-not-disturb >>"$W/modes"; end=$(( $(date +%s) + 7200 )); echo "$end morning" >"$(rec)"; answer esc; rc 0 dndm
eq "$(kinds)" "part row row on row "; eq "$(fz_arg select)" 3
eq "$(fz_rows | sed -n 1p | cut -f4)" "$(date -d "@$end" '+until %-H:%M')"
case_ "the dropdown, a record that is stale or broken, or the quiet mode already off: only what mako says counts"
setup; echo do-not-disturb >>"$W/modes"; echo "$(( $(date +%s) - 30 )) hour" >"$(rec)"; answer esc; rc 0 dndm
eq "$(kinds)" "part row row row on " "an end gone by with the mode still on: the plain quiet"
eq "$(fz_rows | sed -n 1p | cut -f4)" "" "… no end shown"
for junk in "x hour" "" "0 morning"; do
  setup; echo do-not-disturb >>"$W/modes"; printf '%s\n' "$junk" >"$(rec)"; answer esc; rc 0 dndm
  eq "$(kinds)" "part row row row on " "[$junk]: the plain quiet"
done
setup; echo "$(( $(date +%s) + 3000 )) hour" >"$(rec)"; answer esc; rc 0 dndm
eq "$(kinds)" "part on row row row " "mako not quiet (a login ended it): off is in force, whatever the record says"
eq "$(fz_arg select)" 1
case_ "the dropdown: a choice sets it (the line's number) — off, an hour, the morning, on; the part line is no choice"
setup; echo do-not-disturb >>"$W/modes"; answer "row 1"; rc 0 dndm
eq "$(modes)" default "off: the quiet mode taken away"; called '^makoctl mode -r do-not-disturb$'
setup; answer "row 2"; rc 0 dndm
eq "$(modes)" "default do-not-disturb" "an hour: quiet"; called '^systemd-run --user --quiet --collect --unit=kawa-dnd-end --on-active=(3600|3599)s '
eq "$(cut -d' ' -f2 "$(rec)")" hour
setup; answer "row 3"; rc 0 dndm
eq "$(modes)" "default do-not-disturb" "the morning: quiet"; eq "$(cut -d' ' -f2 "$(rec)")" morning
setup; answer "row 4"; rc 0 dndm
eq "$(modes)" "default do-not-disturb" "on: quiet"; not_called '^systemd-run'; eq "$(kawa-state get dnd)" on
setup; echo do-not-disturb >>"$W/modes"; answer "row 0"; rc 0 dndm
eq "$(modes)" "default do-not-disturb" "the part line: nothing changed"; not_called '^(makoctl mode -[ar]|systemd-run|kawa-dwlstatus)'
case_ "the dropdown dismissed (Esc, a click outside, its tile again): nothing set, exit 0"
for a in esc lost; do setup; answer "$a"; rc 0 dndm; eq "$(modes)" default "$a"; not_called '^(makoctl mode -[ar]|systemd-run|systemctl|kawa-dwlstatus)'; done
case_ "kawa-quick dnd takes no argument (a second one is wrong use, exit 2, no menu); --help names it"
setup; rc 2 kawa-quick dnd extra; rc 2 kawa-quick dnd sound; eq "$(fz_n)" 0 "no menu for a wrong use"
has "$(kawa-quick --help)" "kawa-quick dnd" "--help names it"
case_ "theme: kawa-theme toggle, and the state follows"
setup; rc 0 quick --do theme; called '^kawa-theme toggle$'; eq "$(st theme)" light
case_ "FreeSync: in games → always → off → in games, written where dwl reads it"
setup; a=$(st vrr); quick --do vrr; b=$(st vrr); quick --do vrr; c=$(st vrr); quick --do vrr; d=$(st vrr)
eq "$a / $b / $c / $d" "in games / always / off / in games"
eq "$(cat "$HOME/.config/fedokawaii/vrr")" games
grep -q '%s/.config/fedokawaii/vrr' "$REPO/src/dwl/dwl.patch" && _ok || _no "dwl reads another file"
case_ "FreeSync: dwl told at once (SIGUSR1: it reads the file again) — only a dwl that catches it"
setup
python3 -I -c '
import signal, sys
signal.signal(signal.SIGUSR1, lambda *a: open(sys.argv[1], "a").write("USR1\n"))
open(sys.argv[1] + ".up", "w").close()
while True: signal.pause()' "$TMP/dwl.got" & dwl=$!
/bin/sleep 300 & old=$!                     # (a dwl without the handler: the signal would end it)
for _ in {1..300}; do [[ -e $TMP/dwl.got.up ]] && break; /bin/sleep 0.01; done
# (pgrep -xu UID dwl: in the namespace (ns) kawa-quick's own UID is 0, outside it the user's)
stub pgrep '[ "$1 $3" = "-xu dwl" ] && { echo '"$dwl"'; echo '"$old"'; exit 0; }; exit 1'
rc 0 quick --do vrr
for _ in {1..100}; do [[ -s $TMP/dwl.got ]] && break; /bin/sleep 0.02; done
eq "$(cat "$TMP/dwl.got" 2>/dev/null)" USR1 "dwl told"
kill -0 "$old" 2>/dev/null && _ok || _no "a dwl without the handler was killed"
kill "$dwl" "$old" 2>/dev/null; wait "$dwl" "$old" 2>/dev/null
case_ "brightness N: every monitor set to N % (kawa-brightness), the state following"
setup; rc 0 quick --do brightness 40; called '^kawa-brightness 40$'; eq "$(st brightness)" 40%
rc 0 quick --do brightness 0; rc 0 quick --do brightness 100
rc 2 quick --do brightness 101; rc 2 quick --do brightness; rc 2 quick --do brightness x; rc 2 quick --do brightness 4 5
case_ "volume N: unmuted and set to N % (wpctl), the state following"
setup; echo 'Volume: 0.40 [MUTED]' >"$W/vol"; rc 0 quick --do volume 55
called '^wpctl set-mute @DEFAULT_AUDIO_SINK@ 0$'; called '^wpctl set-volume @DEFAULT_AUDIO_SINK@ 55%$'
eq "$(st sound)" 55%
rc 2 quick --do volume 150; rc 2 quick --do volume
case_ "backup: the last backup's age (kawa-backup status: not set up · never · 3 days ago); its window"
setup; echo "not set up" >"$W/backup"; eq "$(st backup)" "not set up"
rc 0 quick --do backup; called '^kawa-backup --window$'
case_ "backup: the real kawa-backup status — never, then yesterday — from its record and the drive named in settings"
setup; rm -f "$STUBS/kawa-backup"; toolkit BACKUP_TARGET=KINGSTON   # (the theme's env still names none)
eq "$(st backup)" never
mkdir -p "$HOME/.local/state/fedokawaii"; printf '%s\t1 B\tKINGSTON\n' "$(( $(date +%s) - 86400 ))" >"$HOME/.local/state/fedokawaii/last-backup"
eq "$(st backup)" yesterday
case_ "record: on while kawa-record's own wf-recorder runs; off with none, or a pid now another program's"
setup; eq "$(st record)" off
cp /bin/sleep "$TMP/wf-recorder"; "$TMP/wf-recorder" 30 & wf=$!; on_exit "kill $wf 2>/dev/null"
echo "$wf 1 /tmp/x.mp4" >"$XDG_RUNTIME_DIR/kawa-record"; eq "$(st record)" on
sleep 30 & other=$!; on_exit "kill $other 2>/dev/null"; echo "$other 1 /tmp/x.mp4" >"$XDG_RUNTIME_DIR/kawa-record"; eq "$(st record)" off
case_ "each of the others opens its own window or menu"
for pair in "sound:^kawa-panel (toggle sound|--sound)$" "drives:^kawa-drives *$" "wallpaper:^kawa-wallpaper *$" \
            "screenshot:^kawa-screenshot region$" "power:^kawa-power *$" "record:^kawa-record *$" "ocr:^kawa-screenshot text$"; do
  setup; rc 0 quick --do "${pair%%:*}"; called "${pair#*:}"
done
case_ "a home folder with a space in its name: the same"
setup; mv "$HOME" "$TMP/my home"; export HOME="$TMP/my home"
quick --do theme 2>"$TMP/err"; eq "$(cat "$TMP/err")" ""; eq "$(st theme)" light

# ── the panel: open, closed ────────────────────────────────────────────────────────────
case_ "kawa-quick alone, sound, brightness: the running panel (its pid file, its own command line) asked through its fifo — a line each, no process started"
setup
mkdir -p "$XDG_RUNTIME_DIR"; rm -f "$XDG_RUNTIME_DIR/kawa-panel.in"; mkfifo "$XDG_RUNTIME_DIR/kawa-panel.in"; exec 6<>"$XDG_RUNTIME_DIR/kawa-panel.in"
python3 -I -c 'import time; time.sleep(30)' kawa-panel & pp=$!
for _ in {1..20}; do grep -qa kawa-panel "/proc/$pp/cmdline" 2>/dev/null && break; sleep 0.05; done
echo "$pp" >"$XDG_RUNTIME_DIR/kawa-panel.pid"
rc 0 quick; rc 0 quick sound; rc 0 quick brightness
got=""; for _ in 1 2 3; do read -r -t 2 -u 6 l && got+="$l|"; done
eq "$got" "toggle quick|toggle sound|toggle brightness|"; not_called '^setsid'
rc 2 quick sound extra
kill "$pp" 2>/dev/null; wait "$pp" 2>/dev/null; exec 6<&-; rm -f "$XDG_RUNTIME_DIR/kawa-panel.in"
case_ "no panel running (or the pid file names another program): one is started, open"
rc 0 quick; called '^setsid -f kawa-panel --open$'
reset_calls; echo $$ >"$XDG_RUNTIME_DIR/kawa-panel.pid"; rc 0 quick; called '^setsid -f kawa-panel --open$'
reset_calls; rc 0 quick sound; called '^setsid -f kawa-panel --sound$'

# ── use, locale ───────────────────────────────────────────────────────────────────────
case_ "--help: what it is, exit 0; anything else: exit 2"
setup; out=$(kawa-quick --help); rc 0 kawa-quick --help; has "$out" "quick settings"; has "$out" "--state"
rc 2 kawa-quick --bogus; rc 2 kawa-quick extra; rc 2 kawa-quick --state extra
rc 2 kawa-quick --do; rc 2 kawa-quick --do bogus; rc 2 kawa-quick --do night extra
not_called '^(kawa-theme|makoctl mode -t|setsid|kawa-term --float|bluetoothctl power)'
case_ "a Turkish or Arabic locale: the same keys and values"
for loc in tr_TR.UTF-8 ar_EG.UTF-8; do
  setup; QENV=("$(locale_ "$loc")" "LC_ALL=$loc")
  eq "$(state 2>/dev/null | cut -f1 | head -n 6 | tr '\n' ' ')" "theme brightness night vrr wallpaper sound " "$loc"
  eq "$(st dnd)" off "$loc"
done
QENV=(LC_ALL=C.UTF-8)

done_
