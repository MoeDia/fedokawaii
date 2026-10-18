#!/usr/bin/env bash
# tests/menus/test_quick.sh — kawa-quick, quick settings' model (the panel, kawa-panel, draws
# it: test_panel.sh): what --state says for the machine's state (wired, a Wi-Fi by its name,
# offline, a VPN; a Bluetooth adapter or none, on, off, blocked, the devices connected; the
# night light; FreeSync; do not disturb; the theme; the brightness, the sound, the wallpaper;
# drives), what each --do does, and the toggle that opens and closes the panel.
# The machine is made up: nmcli, busctl, bluetoothctl, makoctl, gammastep (a process table in
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
  stub makoctl 'if [ "$1 $2" = "mode -t" ]; then grep -qx "$3" "$W/modes" && sed -i "/^$3\$/d" "$W/modes" || echo "$3" >>"$W/modes"
else cat "$W/modes"; fi'
  stub kawa-theme '[ "$1" = toggle ] || exit 2
cd "$HOME/.config/fedokawaii" && if [ "$(readlink current)" = themes/dark ]; then ln -sfn themes/light current; else ln -sfn themes/dark current; fi'
  stub kawa-drives '[ "$1" = list ] && cat "$W/drives"'
  stub kawa-backup 'case $1 in status) cat "$W/backup" ;; esac'; echo never >"$W/backup"
  stub sleep
  # the brightness kawa-brightness last read (its --level), the sound's level (wpctl)
  stub kawa-brightness '[ "$1" = --level ] && cat "$W/bright" 2>/dev/null'; echo 70 >"$W/bright"
  stub wpctl '[ "$1" = get-volume ] && cat "$W/vol"'; echo 'Volume: 0.62' >"$W/vol"
  for s in kawa-audio kawa-float kawa-screenshot kawa-wallpaper kawa-power; do stub "$s"; done
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
  eq "$keys" "theme,brightness,night,vrr,wallpaper,sound,nettype,network,bluetooth,devices,drives,backup,dnd,"
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
eq "$(st theme)" light; eq "$(st drives)" "STICK 1 +11"; eq "$(st night)" on; eq "$(st backup)" "1000 days ago"
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
echo pack:canal-walk-night >"$HOME/.local/state/fedokawaii/wallpaper-dark"; eq "$(st wallpaper)" canal-walk-night
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
called '^kawa-float --once network network 80x25 -- nmtui$'
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
  case_ "bluetoothd not running: off, at once (busctl fails; bluetoothctl gets 2 s at most)"
  setup; : >"$W/bt"; SECONDS=0; eq "$(st bluetooth)" off
  ((SECONDS <= 4)) && _ok || _no "took ${SECONDS}s"
  case_ "switching it: off → on → off, the state following"
  setup; echo 'b false' >"$W/bt"; rc 0 quick --do bluetooth; eq "$(st bluetooth)" on
  rc 0 quick --do bluetooth; eq "$(st bluetooth)" off
  called '^bluetoothctl power on$'; called '^bluetoothctl power off$'
  case_ "Bluetooth blocked by rfkill: switching on fails — a notice says why, exit 1"
  setup; echo 'b false' >"$W/bt"; : >"$W/rfkill"; rc 1 quick --do bluetooth
  eq "$(st bluetooth)" off
  called 'notify-send -a desktop .*Bluetooth.*rfkill unblock bluetooth'
  case_ "devices: the ones connected now — none, one by its name, more by their count; off while Bluetooth is"
  setup; eq "$(st devices)" none
  echo "Device AA:BB:CC:DD:EE:FF WH-1000XM5" >"$W/btdev"; eq "$(st devices)" WH-1000XM5
  printf 'Device AA:BB:CC:DD:EE:FF WH-1000XM5\nDevice 11:22:33:44:55:66 Keychron K2\n' >"$W/btdev"; eq "$(st devices)" "2 connected"
  echo 'b false' >"$W/bt"; eq "$(st devices)" off
  case_ "devices: bluetui in a floating terminal of its own (once)"
  setup; rc 0 quick --do devices
  called "^kawa-float --once pair pair a device 96x29 -- bluetui\$"
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
m() { (STEAM=yes SPOTIFY=yes; . "$REPO/lib/manifest.sh"; eval "$1"); }
lacks " $(m 'manifest_all amd' | tr '\n' ' ') " " blueman "; has " $(m 'manifest_all amd' | tr '\n' ' ') " " bluez "
has " $(m 'echo "${FORBIDDEN_PKGS[*]}"') " " blueman "; has " $(m 'echo "${RETIRED_PKGS[*]}"') " " blueman "
has "$(grep -E '^bluetui ' "$REPO/tests/static/fixtures/programs.txt")" "upstream"
lacks "$(cat "$REPO/tests/static/fixtures/programs.txt" "$REPO/src/dwl/config.h")" blueman

# ── night light ───────────────────────────────────────────────────────────────────────
case_ "night light off → on: gammastep starts at the configured place"
setup; rc 0 quick --do night
called '^setsid -f gammastep -l 25.35:55.40 -t 6500:4200$'; eq "$(st night)" on
case_ "night light on → off: signalled twice (the fade ends at once), off when it returns"
setup; echo gammastep >"$W/procs"; rc 0 quick --do night
eq "$(grep -c '^pkill -xu [0-9]* gammastep$' "$CALLS")" 2 "two signals"
eq "$(st night)" off "off at once, not still fading"
case_ "night light on → off → on, fast: one gammastep in the end, the state right each time"
setup; echo gammastep >"$W/procs"
quick --do night; a=$(st night); quick --do night; b=$(st night); quick --do night; c=$(st night)
eq "$a $b $c" "off on off"
quick --do night; eq "$(grep -c . "$W/procs")" 1 "one gammastep running"
case_ "gammastep started with stdin on /dev/null (not closed: the next file it opens is not fd 0)"
setup; quick --do night; eq "$(cat "$W/gammastep.stdin")" "stdin: /dev/null"
case_ "gammastep missing: it stays off, no loop, no error on screen"
setup; : >"$W/no-gammastep"; out=$(quick --do night 2>&1); eq "$out" ""; eq "$(st night)" off

# ── do not disturb, the theme, FreeSync, the levels, the rest ────────────────────────
case_ "dnd: mako's mode switched, the bar's seal poked, the state following"
setup; quick --do dnd; eq "$(st dnd)" on; quick --do dnd; eq "$(st dnd)" off
eq "$(grep -c '^makoctl mode -t do-not-disturb$' "$CALLS")" 2
called '^kawa-dwlstatus --poke 12$'
case_ "dnd while a screen is shared (mode sharing): still its own switch"
setup; echo sharing >"$W/modes"; quick --do dnd
eq "$(sort "$W/modes" | tr '\n' ' ')" "do-not-disturb sharing "
case_ "theme: kawa-theme toggle, and the state follows"
setup; rc 0 quick --do theme; called '^kawa-theme toggle$'; eq "$(st theme)" light
case_ "FreeSync: in games → always → off → in games, written where dwl reads it"
setup; a=$(st vrr); quick --do vrr; b=$(st vrr); quick --do vrr; c=$(st vrr); quick --do vrr; d=$(st vrr)
eq "$a / $b / $c / $d" "in games / always / off / in games"
eq "$(cat "$HOME/.config/fedokawaii/vrr")" games
grep -q '%s/.config/fedokawaii/vrr' "$REPO/src/dwl/dwl.patch" && _ok || _no "dwl reads another file"
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
case_ "each of the others opens its own window or menu"
for pair in "sound:^kawa-audio *$" "drives:^kawa-drives *$" "wallpaper:^kawa-wallpaper *$" \
            "screenshot:^kawa-screenshot region$" "power:^kawa-power *$"; do
  setup; rc 0 quick --do "${pair%%:*}"; called "${pair#*:}"
done
case_ "a home folder with a space in its name: the same"
setup; mv "$HOME" "$TMP/my home"; export HOME="$TMP/my home"
quick --do theme 2>"$TMP/err"; eq "$(cat "$TMP/err")" ""; eq "$(st theme)" light

# ── the panel: open, closed ────────────────────────────────────────────────────────────
case_ "kawa-quick alone: the running panel (its pid file, its own command line) is asked — SIGUSR1"
setup
python3 -I -c 'import signal, sys, time
signal.signal(signal.SIGUSR1, lambda *a: open(sys.argv[1], "a").write("toggle\n"))
open(sys.argv[2], "w").close(); time.sleep(30)' "$TMP/got" "$TMP/up" kawa-panel & pp=$!
for _ in {1..50}; do [[ -e $TMP/up ]] && break; sleep 0.05; done
mkdir -p "$XDG_RUNTIME_DIR"; echo "$pp" >"$XDG_RUNTIME_DIR/kawa-panel.pid"
rc 0 quick; rc 0 quick
for _ in {1..50}; do [[ $(grep -c toggle "$TMP/got" 2>/dev/null) == 2 ]] && break; sleep 0.05; done
eq "$(grep -c toggle "$TMP/got" 2>/dev/null)" 2; not_called '^setsid'
kill "$pp" 2>/dev/null; wait "$pp" 2>/dev/null
case_ "no panel running (or the pid file names another program): one is started, open"
rc 0 quick; called '^setsid -f kawa-panel --open$'
reset_calls; echo $$ >"$XDG_RUNTIME_DIR/kawa-panel.pid"; rc 0 quick; called '^setsid -f kawa-panel --open$'

# ── use, locale ───────────────────────────────────────────────────────────────────────
case_ "--help: what it is, exit 0; anything else: exit 2"
setup; out=$(kawa-quick --help); rc 0 kawa-quick --help; has "$out" "quick settings"; has "$out" "--state"
rc 2 kawa-quick --bogus; rc 2 kawa-quick extra; rc 2 kawa-quick --state extra
rc 2 kawa-quick --do; rc 2 kawa-quick --do bogus; rc 2 kawa-quick --do night extra
not_called '^(kawa-theme|makoctl mode -t|setsid|kawa-float|bluetoothctl power)'
case_ "a Turkish or Arabic locale: the same keys and values"
for loc in tr_TR.UTF-8 ar_EG.UTF-8; do
  setup; QENV=("$(locale_ "$loc")" "LC_ALL=$loc")
  eq "$(state 2>/dev/null | cut -f1 | head -n 6 | tr '\n' ' ')" "theme brightness night vrr wallpaper sound " "$loc"
  eq "$(st dnd)" off "$loc"
done
QENV=(LC_ALL=C.UTF-8)

done_
