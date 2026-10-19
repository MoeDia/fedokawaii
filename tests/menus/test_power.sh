#!/usr/bin/env bash
# tests/menus/test_power.sh — kawa-power: each choice (systemctl, loginctl and the lock are
# stand-ins), a choice the system refuses, the uptime in its title at the edges of each form
# (/proc/uptime replaced in a namespace of its own), and the rows and title all centred alike.
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"

setup() {
  menus_sandbox
  stub systemctl; stub loginctl; stub kawa-lock; stub pkill; stub logger; stub wlopm
  export KAWA_SLEEP_BEAT=0                          # (the beat on the lock before a sleep: timed below)
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
eq "$(fz_rows | sed 's/^ *.  //; s/ *$//' | tr '\n' ',')" "lock,sleep,log out,restart,shut down," "the rows right under the uptime, one row apart (no empty row: no headings here)"
eq "$(fz_arg select-index)" 0 "the cursor on lock"
eq "$(fz_arg width)" 25; eq "$(fz_arg lines)" 5; eq "$(fz_arg index)" set; eq "$(fz_arg anchor)" "" "centred"
has "$(fz_arg mesg)" "$ICON_HOURGLASS  up "
fits
case_ "every row: the icon and label block starts in the same column (6 spaces in)"
eq "$(fz_rows | sed 's/^\( *\).*/\1/' | awk '{print length}' | sort -u)" 6
eq "$(fz_rows | python3 -I "$MD/cols.py" --px | sort -u)" 116 "all 116 px: an 80 px block (icon 14, 2 spaces, 9 letters) 36 px in, 34 from the end of 150 — centred to a pixel"

act() { setup; answer "pick $1"; power; }
case_ "lock: the lock screen"
act lock; called '^kawa-lock --sleep$'; not_called '^systemctl'
case_ "sleep: locked first, the screens to black, then suspended"
act sleep; eq "$(grep -E '^(kawa-lock|wlopm|systemctl)' "$CALLS" | tr '\n' '|')" "kawa-lock |wlopm --off *|systemctl suspend|"
case_ "… each step in the journal (the health report reads it): asked, then handed to the system"
eq "$(grep -E '^(logger|kawa-lock|systemctl)' "$CALLS" | tr '\n' '|')" \
  "logger -t kawa-power -- sleep requested|kawa-lock |systemctl suspend|logger -t kawa-power -- suspend asked of the system|"
case_ "… a beat on the drawn lock before the screens go black (0.8 s unless KAWA_SLEEP_BEAT says): the hand-off seen, never a flash"
grep -q 'sleep "${KAWA_SLEEP_BEAT:-0.8}"' "$REPO/bin/kawa-power" && _ok || _no "the default beat is not 0.8 s"
setup; KAWA_SLEEP_BEAT=1 kawa-power sleep & p=$!; /bin/sleep 0.5
not_called '^wlopm'; wait "$p"; called '^wlopm --off \*$'
case_ "sleep, but the lock screen did not come up: no suspend (never an unlocked sleep), and the journal says so"
setup; stub kawa-lock 'exit 1'; answer "pick sleep"; power; not_called '^systemctl suspend'
called '^logger -t kawa-power -- not locked — no sleep$'
case_ "log out: Steam closed properly first (its saves to Steam Cloud), then dwl ended"
setup; stub kawa-steam; answer "pick log out"; power
eq "$(grep -E '^(kawa-steam|pkill)' "$CALLS" | tr '\n' '|')" "kawa-steam --quit logout|pkill -xu $UID dwl|"
case_ "restart, shut down: systemctl reboot / poweroff"
act restart; called '^systemctl reboot$'; not_called '^kawa-steam' "(restart: kawa-steam --guard, told by logind)"
act "shut down"; called '^systemctl poweroff$'
not_called '^loginctl'
case_ "Esc, a click outside, typed text: nothing happens, exit 0"
for a in esc lost "typed reboot"; do setup; answer "$a"; rc 0 power; not_called '^(systemctl|kawa-lock|pkill)'; done

case_ "restart refused (another user logged in, an inhibitor): a notice with logind's reason"
setup; stub systemctl 'echo "User kawab is logged in on tty2. Please retry operation after closing inhibitors and logging out other users." >&2; exit 1'
answer "pick restart"; rc 1 power
called 'notify-send -a desktop -u critical -- .*power could not restart .*User kawab is logged in on tty2'
case_ "shut down refused without a password agent (polkit): a notice"
setup; stub systemctl 'echo "Failed to power off system via logind: Interactive authentication required." >&2; exit 1'
answer "pick shut down"; rc 1 power
called 'notify-send -a desktop -u critical -- .*power could not shut down .*Interactive authentication required'
case_ "sleep refused (no suspend on this machine): a notice"
setup; stub systemctl 'echo "Failed to suspend system via logind: Sleep verb \"suspend\" not supported" >&2; exit 1'
answer "pick sleep"; rc 1 power
called 'notify-send -a desktop -u critical -- .*power could not sleep .*not supported'
called '^logger -t kawa-power -- could not sleep — Failed to suspend system via logind'
eq "$(grep '^wlopm' "$CALLS" | tr '\n' '|')" "wlopm --off *|wlopm --on *|" "the screens on again: no sleep, no black screen"

case_ "kawa-power sleep (the Sleep key): no menu — locked first, then suspended"
setup; rc 0 kawa-power sleep; eq "$(fz_n)" 0
eq "$(grep -E '^(kawa-lock|systemctl)' "$CALLS" | tr '\n' '|')" "kawa-lock |systemctl suspend|"
called '^logger -t kawa-power -- sleep requested$'
case_ "kawa-power sleep (no menu) refused by the system: the notice with its icon, the screens on again"
setup; stub systemctl 'echo "Failed to suspend system via logind: Sleep verb \"suspend\" not supported" >&2; exit 1'
rc 1 kawa-power sleep
called "^notify-send -a desktop -u critical -- $ICON_POWER  power could not sleep"
eq "$(grep '^wlopm' "$CALLS" | tr '\n' '|')" "wlopm --off *|wlopm --on *|"
case_ "kawa-power sleep, but the lock screen did not come up: no suspend"
setup; stub kawa-lock 'exit 1'; kawa-power sleep; not_called '^systemctl suspend'

case_ "--help: what it is, exit 0; anything else: exit 2, no menu"
setup; has "$(kawa-power --help)" "lock, sleep, log out"; rc 0 kawa-power --help
rc 2 kawa-power now; eq "$(fz_n)" 0

# ── the uptime in the title ───────────────────────────────────────────────────────────
if ((NS)); then
  up() { setup; answer esc; power "$1"; t=$(fz_arg mesg); printf '%s' "${t#*"$ICON_HOURGLASS"  }"; }
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
  case_ "the title stands as the rows do whatever the uptime: 6 spaces, its icon over theirs, its words over their labels (two spaces, as theirs)"
  for s in 0 86399 86400 8639999 8640000 99999999; do
    setup; answer esc; power "$s"; t=$(fz_arg mesg)
    eq "$(printf '%s\n' "$t" | python3 -I "$MD/cols.py" --px)" 122 "uptime $s s"; eq "${t%%[! ]*}" "      " "uptime $s s: six spaces"
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
