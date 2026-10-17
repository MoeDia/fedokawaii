#!/usr/bin/env bash
# tests/menus/test_power.sh — kawa-power: each choice (systemctl, loginctl and the lock are
# stand-ins), a choice the system refuses, the uptime in its title at the edges of each form
# (/proc/uptime replaced in a namespace of its own), and the rows and title all centred alike.
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"

setup() {
  menus_sandbox
  stub systemctl; stub loginctl; stub kawa-lock; stub pkill
}
power() {   # power [SECONDS] — kawa-power, the machine up for SECONDS (default: as it is)
  if [[ -n ${1:-} ]] && ((NS)); then
    printf '%s.37 1234.56\n' "$1" >"$TMP/uptime"
    ns "mount --bind '$TMP/uptime' /proc/uptime" kawa-power
  else kawa-power; fi
}
. "$REPO/configs/home/.config/fedokawaii/icons.sh"

# ── the choices ───────────────────────────────────────────────────────────────────────
case_ "the menu: five choices, centred, 25 wide, the uptime on top"
setup; answer esc; power
eq "$(fz_rows | sed 's/^ *.  //; s/ *$//' | tr '\n' ',')" "lock,sleep,log out,restart,shut down,"
eq "$(fz_arg width)" 25; eq "$(fz_arg lines)" 5; eq "$(fz_arg index)" set; eq "$(fz_arg anchor)" "" "centred"
has "$(fz_arg mesg)" "$ICON_HOURGLASS up "
fits
case_ "every row: the icon and label block starts in the same column (6 spaces in)"
eq "$(fz_rows | sed 's/^\( *\).*/\1/' | awk '{print length}' | sort -u)" 6
eq "$(fz_rows | python3 -I "$MD/cols.py" | sort -u)" 19 "all 19 columns: the block is 13, centred in 25"

act() { setup; answer "pick $1"; power; }
case_ "lock: the lock screen"
act lock; called '^kawa-lock --sleep$'; not_called '^systemctl'
case_ "sleep: locked first, then suspended"
act sleep; eq "$(grep -E '^(kawa-lock|systemctl)' "$CALLS" | tr '\n' '|')" "kawa-lock |systemctl suspend|"
case_ "sleep, but the lock screen did not come up: no suspend (never an unlocked sleep)"
setup; stub kawa-lock 'exit 1'; answer "pick sleep"; power; not_called '^systemctl suspend'
case_ "log out: dwl ended (or the build before it, dwl.prev)"
act "log out"; called '^pkill -xu '"$UID"' dwl\(\\\.prev\)\?$'
case_ "restart, shut down: systemctl reboot / poweroff"
act restart; called '^systemctl reboot$'
act "shut down"; called '^systemctl poweroff$'
not_called '^loginctl'
case_ "Esc, a click outside, typed text: nothing happens, exit 0"
for a in esc lost "typed reboot"; do setup; answer "$a"; rc 0 power; not_called '^(systemctl|kawa-lock|pkill)'; done

case_ "restart refused (another user logged in, an inhibitor): a notice with logind's reason"
setup; stub systemctl 'echo "User kawab is logged in on tty2. Please retry operation after closing inhibitors and logging out other users." >&2; exit 1'
answer "pick restart"; rc 1 power
called 'notify-send -a desktop -u critical Power could not restart .*User kawab is logged in on tty2'
case_ "shut down refused without a password agent (polkit): a notice"
setup; stub systemctl 'echo "Failed to power off system via logind: Interactive authentication required." >&2; exit 1'
answer "pick shut down"; rc 1 power
called 'notify-send -a desktop -u critical Power could not shut down .*Interactive authentication required'
case_ "sleep refused (no suspend on this machine): a notice"
setup; stub systemctl 'echo "Failed to suspend system via logind: Sleep verb \"suspend\" not supported" >&2; exit 1'
answer "pick sleep"; rc 1 power
called 'notify-send -a desktop -u critical Power could not sleep .*not supported'

case_ "--help: what it is, exit 0; anything else: exit 2, no menu"
setup; has "$(kawa-power --help)" "lock, sleep, log out"; rc 0 kawa-power --help
rc 2 kawa-power now; eq "$(fz_n)" 0

# ── the uptime in the title ───────────────────────────────────────────────────────────
if ((NS)); then
  up() { setup; answer esc; power "$1"; t=$(fz_arg mesg); printf '%s' "${t#*"$ICON_HOURGLASS" }"; }
  case_ "uptime: always 'up' and ten characters, at the edges of each form"
  eq "$(up 0)" "up 00h 00m" "just booted"
  eq "$(up 59)" "up 00h 00m"
  eq "$(up 60)" "up 00h 01m"
  eq "$(up $((23 * 3600 + 59 * 60 + 59)))" "up 23h 59m" "a second short of a day"
  eq "$(up 86400)" "up 01d 00h" "a day"
  eq "$(up $((99 * 86400 + 23 * 3600 + 59 * 60)))" "up 99d 23h" "the last of the days form"
  eq "$(up $((100 * 86400)))" "up 14w 02d" "100 days: weeks"
  eq "$(up $((99 * 7 * 86400 + 6 * 86400)))" "up 99w 06d" "the most it can say"
  eq "$(up $((100 * 7 * 86400 + 3 * 86400)))" "up 99w 06d" "more than 99 weeks: the most it can say, not a wrong remainder"
  eq "$(up $((2000 * 7 * 86400)))" "up 99w 06d"
  case_ "the title is centred over the rows whatever the uptime: 6 spaces, then 13 columns"
  for s in 0 86399 86400 8639999 8640000 99999999; do
    setup; answer esc; power "$s"; t=$(fz_arg mesg)
    eq "$(cols "$t")" 19 "uptime $s s"; eq "${t%%[! ]*}" "      " "uptime $s s: six spaces"
  done
  case_ "a Turkish or Arabic locale: the same ten characters"
  for loc in tr_TR.UTF-8 ar_EG.UTF-8; do
    setup; printf '90061.5 0\n' >"$TMP/uptime"; answer esc
    ns "mount --bind '$TMP/uptime' /proc/uptime" env "$(locale_ "$loc")" LC_ALL="$loc" kawa-power 2>/dev/null
    has "$(fz_arg mesg)" "up 01d 01h"; fits "" "$loc"
  done
else
  echo "  (uptime cases skipped: no user namespaces here to stand in for /proc/uptime)"
fi

done_
