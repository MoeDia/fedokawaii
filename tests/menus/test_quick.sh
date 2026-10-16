#!/usr/bin/env bash
# tests/menus/test_quick.sh — kawa-quick, quick settings: every row, what it shows for the
# machine's state (wired, Wi-Fi, offline, a VPN; a Bluetooth adapter or none, on, off,
# blocked; the night light; do not disturb; the theme; drives) and what each choice does.
# The machine is made up: nmcli, busctl, bluetoothctl, makoctl, gammastep (a process table in
# a file), kawa-theme, kawa-drives and kawa-weather are stand-ins; whether there is a
# Bluetooth adapter is a tmpfs over /sys/class in a namespace of its own (ns). The backup row
# shows what kawa-backup status says (a stand-in: $W/backup).
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"

setup() {
  menus_sandbox; config .config/fedokawaii/env
  W=$TMP/world; mkdir -p "$W"; export W
  printf '%s\n' ethernet:connected wifi:disconnected 'loopback:connected (externally)' >"$W/nm"
  echo 'b true' >"$W/bt"; : >"$W/procs"; echo default >"$W/modes"; : >"$W/drives"; BT=1
  stub kawa-weather 'printf "%s  Sharjah  +31°C  Clear\n" "$(printf "\363\276\200\220")"'
  stub nmcli '[ -f "$W/nm.missing" ] && exit 127; [ "$*" = "-t -f TYPE,STATE device" ] && cat "$W/nm"'
  # bluetoothd answering on the system bus (Powered as busctl prints it), or not running
  stub busctl '[ -s "$W/bt" ] || exit 1; cat "$W/bt"'
  stub bluetoothctl 'case "$1" in
  show) [ -s "$W/bt" ] || { /bin/sleep 5; exit 1; }; [ "$(cat "$W/bt")" = "b true" ] && echo "	Powered: yes" || echo "	Powered: no" ;;
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
  for s in kawa-brightness kawa-audio kawa-float kawa-screenshot kawa-wallpaper kawa-help fedokawaii kawa-config kawa-power; do stub "$s"; done
}
QENV=(LC_ALL=C.UTF-8)
quick() {   # quick — kawa-quick on the made-up machine (an adapter or none: $BT; locale: $QENV)
  if ((NS)); then
    ns "mount -t tmpfs none /sys/class$( ((BT)) && printf '; mkdir -p /sys/class/bluetooth/hci0')" env "${QENV[@]}" kawa-quick
  else env "${QENV[@]}" kawa-quick; fi
}
row() { fz_rows "${2:-}" | grep -m1 -F "  $1 " ; }        # row NAME [MENU] — the row of NAME
st() { local r; r=$(row "$@"); r=${r:19}; printf '%s' "${r% }"; }   # st NAME [MENU] — its state
icon() { local r; r=$(row "$@"); printf '%s' "${r:0:1}"; }         # icon NAME [MENU] — its icon
. "$HOME/.config/fedokawaii/icons.sh" 2>/dev/null || true
setup; . "$HOME/.config/fedokawaii/icons.sh"

# ── what it shows ─────────────────────────────────────────────────────────────────────
case_ "every row, in order, each with its state; the weather on top; a dropdown 38 wide"
answer esc; quick; rc 0 true
names=$(fz_rows | sed 's/^.  //; s/  .*//; s/ *$//' | tr '\n' ',')
if ((NS)); then
  eq "$names" "theme,brightness,night light,wallpaper,sound,network,bluetooth,pair a device,drives,backup,do not disturb,screenshot,keybindings,system,change,power,"
else has "$names" "theme,brightness,night light,wallpaper,sound,network,"; fi
eq "$(fz_arg mesg)" "$ICON_SUN  Sharjah  +31°C  Clear"
eq "$(fz_arg anchor)" top-right; eq "$(fz_arg width)" 38; eq "$(fz_arg index)" set
eq "$(fz_arg lines)" "$(fz_rows | wc -l)" "as many lines as rows"
eq "$(fz_arg select-index)" 0 "the theme row first"
eq "$(st theme)" "$ICON_BOX_ON dark  $ICON_BOX_OFF light" "the theme: a two-way switch, dark lit"
eq "$(icon network)" "$ICON_ETHERNET"; eq "$(st network)" ethernet
eq "$(st 'night light')" off; eq "$(st 'do not disturb')" off; eq "$(icon 'do not disturb')" "$ICON_BELL"
eq "$(st drives)" none; eq "$(st screenshot)" region
eq "$(st backup)" never; eq "$(icon backup)" "$ICON_ARCHIVE"
((NS)) && eq "$(st bluetooth)" on
fits

case_ "the widest states still fit: light theme, 12 drives plugged in, everything on, a backup 1000 days ago"
ln -sfn themes/light "$HOME/.config/fedokawaii/current"; echo gammastep >"$W/procs"; echo "1000 days ago" >"$W/backup"
printf 'do-not-disturb\nsharing\n' >"$W/modes"
for i in {1..12}; do printf '/dev/sd%s1\t/dev/sd%s\tSTICK %s\t8G\tvfat\t\n' "$i" "$i" "$i"; done >"$W/drives"
answer esc; quick
eq "$(st theme)" "$ICON_BOX_OFF dark  $ICON_BOX_ON light"
eq "$(st drives)" "12 plugged in"; eq "$(st 'night light')" on; eq "$(st backup)" "1000 days ago"
eq "$(st 'do not disturb')" on "on, though sharing is on too"; eq "$(icon 'do not disturb')" "$ICON_BELL_OFF"
fits
case_ "a drive with two file systems counts once"
printf '/dev/sdb1\t/dev/sdb\tA\n/dev/sdb2\t/dev/sdb\tB\n/dev/mmcblk0p1\t/dev/mmcblk0\tC\n' >"$W/drives"
answer esc; quick; eq "$(st drives)" "2 plugged in"

# ── the network row ───────────────────────────────────────────────────────────────────
nm() { printf '%s\n' "$@" >"$W/nm"; answer esc; quick; }
case_ "network: Wi-Fi only"
setup; nm wifi:connected ethernet:unavailable 'loopback:connected (externally)'
eq "$(st network)" wifi; eq "$(icon network)" "$ICON_WIFI"
case_ "network: wired and Wi-Fi both up: the first nmcli lists"
nm ethernet:connected wifi:connected; eq "$(st network)" ethernet
case_ "network: nothing connected (cable out, no Wi-Fi joined): offline"
nm ethernet:unavailable wifi:disconnected 'wifi-p2p:disconnected' 'loopback:connected (externally)'
eq "$(st network)" offline; eq "$(icon network)" "$ICON_OFFLINE"
case_ "network: Wi-Fi radio off, or blocked by rfkill (nmcli: unavailable): offline"
nm 'ethernet:unavailable' 'wifi:unavailable'; eq "$(st network)" offline
case_ "network: no Wi-Fi device at all, joining (still connecting): offline"
nm 'ethernet:connecting (getting IP configuration)'; eq "$(st network)" offline
case_ "network: a VPN listed first (WireGuard holding the default route): still the Wi-Fi"
nm wireguard:connected wifi:connected 'loopback:connected (externally)'
eq "$(st network)" wifi; eq "$(icon network)" "$ICON_WIFI"
nm 'tun:connected (externally)' ethernet:connected; eq "$(st network)" ethernet
nm bridge:connected ethernet:connected; eq "$(st network)" ethernet "a bridge for virtual machines over the cable"
case_ "network: a phone's mobile data (gsm) listed before the Wi-Fi: still the Wi-Fi; alone: its own name"
nm gsm:connected wifi:connected; eq "$(st network)" wifi
nm gsm:connected ethernet:unavailable; eq "$(st network)" gsm
case_ "network: a cable another tool configured (connected externally): wired"
nm 'ethernet:connected (externally)' 'loopback:connected (externally)'; eq "$(st network)" ethernet
case_ "network: nmcli missing or NetworkManager not running: offline, and the menu still opens"
: >"$W/nm.missing"; answer esc; quick; eq "$(st network)" offline; rm "$W/nm.missing"
stub nmcli 'echo "Error: NetworkManager is not running." >&2; exit 8'; answer esc; quick; eq "$(st network)" offline
case_ "network: garbage from nmcli (escaped colons, empty lines): offline, no error"
stub nmcli 'printf "\n:\nwifi\\\\:x:connected\n::::\n"'; out=$(answer esc; quick 2>&1); eq "$out" ""
eq "$(st network)" offline
case_ "network: choosing it opens nmtui in a floating window (once)"
setup; answer "pick network"; quick
called '^kawa-float --once network network 80x25 -- nmtui$'
case_ "SSIDs never reach the menu (nmtui lists them): odd names cannot break a row"
setup; nmcalls=$(answer esc; quick; grep -c '^nmcli' "$CALLS")
eq "$nmcalls" 1; called '^nmcli -t -f TYPE,STATE device$'

# ── Bluetooth ─────────────────────────────────────────────────────────────────────────
if ((NS)); then
  case_ "no Bluetooth adapter: no Bluetooth rows, and bluetoothd is never asked"
  setup; BT=0; answer esc; quick
  lacks "$(fz_rows)" bluetooth; lacks "$(fz_rows)" "pair a device"
  not_called '^busctl'; not_called '^bluetoothctl'
  case_ "an adapter, powered off: off"
  setup; echo 'b false' >"$W/bt"; answer esc; quick; eq "$(st bluetooth)" off
  case_ "bluetoothd not running: off, at once (busctl fails; bluetoothctl gets 2 s at most)"
  setup; : >"$W/bt"; answer esc; SECONDS=0; quick; eq "$(st bluetooth)" off
  ((SECONDS <= 4)) && _ok || _no "took ${SECONDS}s"
  case_ "toggling it: off → on → off, the menu reopening with the new state on the same row"
  setup; echo 'b false' >"$W/bt"; answer "pick bluetooth" "pick bluetooth" esc; quick
  called '^bluetoothctl power on$'; called '^bluetoothctl power off$'
  eq "$(st bluetooth 2)" on; eq "$(st bluetooth 3)" off
  eq "$(fz_arg select-index 2)" "$(fz_rows 1 | grep -n -m1 '  bluetooth ' | cut -d: -f1 | awk '{print $1 - 1}')" "the bluetooth row stays selected"
  case_ "Bluetooth blocked by rfkill: switching on fails — a notice says why"
  setup; echo 'b false' >"$W/bt"; : >"$W/rfkill"; answer "pick bluetooth" esc; quick
  eq "$(st bluetooth 2)" off
  called 'notify-send -a desktop .*Bluetooth.*rfkill unblock bluetooth'
  case_ "pair a device: bluetui in a floating terminal of its own (once), and the menu closes"
  setup; answer "pick pair a device"; quick
  called "^kawa-float --once pair pair a device 96x29 -- bluetui\$"; eq "$(fz_n)" 1
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
m() { (. "$REPO/lib/manifest.sh"; eval "$1"); }
lacks " $(m 'manifest_all amd' | tr '\n' ' ') " " blueman "; has " $(m 'manifest_all amd' | tr '\n' ' ') " " bluez "
has " $(m 'echo "${FORBIDDEN_PKGS[*]}"') " " blueman "; has " $(m 'echo "${RETIRED_PKGS[*]}"') " " blueman "
has "$(grep -E '^bluetui ' "$REPO/tests/static/fixtures/programs.txt")" "upstream"
lacks "$(cat "$REPO/tests/static/fixtures/programs.txt" "$REPO/src/dwl/config.h")" blueman

# ── night light ───────────────────────────────────────────────────────────────────────
case_ "night light off → on: gammastep starts at the configured place, the row says on"
setup; answer "pick night light" esc; quick
called '^setsid -f gammastep -l 25.35:55.40 -t 6500:4200$'
eq "$(st 'night light' 1)" off; eq "$(st 'night light' 2)" on
case_ "night light on → off: signalled twice (the fade ends at once), the row says off"
setup; echo gammastep >"$W/procs"; answer "pick night light" esc; quick
eq "$(grep -c '^pkill -xu [0-9]* gammastep$' "$CALLS")" 2 "two signals"
eq "$(st 'night light' 2)" off "off when the menu reopens, not still fading"
case_ "night light on → off → on, fast: one gammastep in the end, the rows right each time"
setup; echo gammastep >"$W/procs"
answer "pick night light" "pick night light" "pick night light" esc; quick
eq "$(st 'night light' 1) $(st 'night light' 2) $(st 'night light' 3) $(st 'night light' 4)" "on off on off"
answer "pick night light" esc; quick
eq "$(grep -c . "$W/procs")" 1 "one gammastep running"
case_ "gammastep started with stdin on /dev/null (not closed: the next file it opens is not fd 0)"
setup; answer "pick night light" esc; quick
eq "$(cat "$W/gammastep.stdin")" "stdin: /dev/null"
case_ "gammastep missing: the row stays off, no loop, no error on screen"
setup; : >"$W/no-gammastep"; out=$(answer "pick night light" esc; quick 2>&1); eq "$out" ""
eq "$(st 'night light' 2)" off; eq "$(fz_n)" 2

# ── do not disturb, the theme, the screenshot, the rest ───────────────────────────────
case_ "do not disturb: mako's mode toggled, the bar's seal poked, the row and bell follow"
setup; answer "pick do not disturb" "pick do not disturb" esc; quick
eq "$(grep -c '^makoctl mode -t do-not-disturb$' "$CALLS")" 2
called '^kawa-dwlstatus --poke 12$'
eq "$(st 'do not disturb' 2)" on; eq "$(icon 'do not disturb' 2)" "$ICON_BELL_OFF"
eq "$(st 'do not disturb' 3)" off
case_ "do not disturb while a screen is shared (mode sharing): still its own switch"
setup; echo sharing >"$W/modes"; answer "pick do not disturb" esc; quick
eq "$(sort "$W/modes" | tr '\n' ' ')" "do-not-disturb sharing "
case_ "theme: kawa-theme toggle, and the switch flips on the same row"
setup; answer "pick theme" esc; quick
called '^kawa-theme toggle$'
eq "$(st theme 2)" "$ICON_BOX_OFF dark  $ICON_BOX_ON light"; eq "$(fz_arg select-index 2)" 0
case_ "the weather is asked once, not again after each toggle"
eq "$(grep -c '^kawa-weather' "$CALLS")" 1
case_ "screenshot: the menu closes first, then the region picker"
setup; answer "pick screenshot"; quick
called '^sleep 0.2$'; called '^kawa-screenshot region$'; eq "$(fz_n)" 1
case_ "backup: the last backup's age (kawa-backup status: not set up · never · 3 days ago); choosing it: the backup, in its window"
setup; echo "not set up" >"$W/backup"; answer esc; quick; eq "$(st backup)" "not set up"
echo "3 days ago" >"$W/backup"; answer "pick backup"; quick; called '^kawa-backup --window$'; eq "$(fz_n)" 2 "the menu closes"
case_ "backup: the real kawa-backup status — never, then yesterday — from its record and the drive named in settings"
setup; rm -f "$STUBS/kawa-backup"; toolkit BACKUP_TARGET=KINGSTON   # (the theme's env still names none)
answer esc; quick; eq "$(st backup)" never
mkdir -p "$HOME/.local/state/fedokawaii"; printf '%s\t1 B\tKINGSTON\n' "$(( $(date +%s) - 86400 ))" >"$HOME/.local/state/fedokawaii/last-backup"
answer esc; quick; eq "$(st backup)" yesterday
case_ "each of the other rows opens its own window or menu"
for pair in "brightness:^kawa-brightness *$" "sound:^kawa-audio *$" "drives:^kawa-drives *$" "wallpaper:^kawa-wallpaper *$" \
            "keybindings:^kawa-help *$" "system:^fedokawaii --window$" "change:^kawa-config *$" "power:^kawa-power *$"; do
  setup; answer "pick ${pair%%:*}"; quick; called "${pair#*:}"
done
case_ "Esc, a click outside, typed text that matches nothing: closes, nothing else happens"
for a in esc lost "typed wifi off"; do
  setup; reset_calls; answer "$a"; rc 0 quick
  not_called '^(kawa-theme|makoctl mode -t|setsid|kawa-float|bluetoothctl power)'
done

case_ "a home folder with a space in its name: the same menu"
setup; mv "$HOME" "$TMP/my home"; export HOME="$TMP/my home"
answer "pick theme" esc; quick 2>"$TMP/err"; eq "$(cat "$TMP/err")" ""
eq "$(st theme 2)" "$ICON_BOX_OFF dark  $ICON_BOX_ON light"; fits

# ── use, locale ───────────────────────────────────────────────────────────────────────
case_ "--help: what it is, exit 0; anything else: exit 2, no menu"
setup; out=$(kawa-quick --help); rc 0 kawa-quick --help; has "$out" "quick settings"
rc 2 kawa-quick --bogus; rc 2 kawa-quick extra; eq "$(fz_n)" 0
case_ "a Turkish or Arabic locale: the same rows, all fitting"
for loc in tr_TR.UTF-8 ar_EG.UTF-8; do
  setup; QENV=("$(locale_ "$loc")" "LC_ALL=$loc"); answer esc; quick 2>/dev/null; fits "" "$loc"
  has "$(fz_rows)" "do not disturb"
done
QENV=(LC_ALL=C.UTF-8)

done_
