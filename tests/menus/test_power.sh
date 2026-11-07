#!/usr/bin/env bash
# tests/menus/test_power.sh — kawa-power: each choice (systemctl, loginctl and the lock are
# stand-ins), a choice the system refuses, the uptime in its title at the edges of each form
# (/proc/uptime replaced in a namespace of its own), and the menu's lines (the panel's format).
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"

setup() {
  menus_sandbox
  stub systemctl; stub loginctl; stub kawa-lock; stub pkill; stub logger; stub wlopm
}
power() {   # power [SECONDS] — kawa-power, the machine up for SECONDS (default: as it is)
  if [[ -n ${1:-} ]] && ((NS)); then
    printf '%s.37 1234.56\n' "$1" >"$TMP/uptime"
    ns "mount --bind '$TMP/uptime' /proc/uptime" kawa-power
  else kawa-power; fi
}
. "$REPO/configs/home/.config/fedokawaii/icons.sh"

# ── the choices ───────────────────────────────────────────────────────────────────────
case_ "the dialog: five seals, each its drawn picture and its word, the uptime in its foot; the desktop dimmed; centred; restart and shut down ask for a second press"
setup; answer esc; power
eq "$(fz_rows | sed '$d' | tr '\n' '|')" "seal	@t-lock	lock		l|seal	@t-sleep	sleep		s|seal	@t-logout	log out		o|seal	@t-restart	restart	press again to restart	r|seal	@t-off	shut down	press again to shut down	d|" "a seal a choice, its letter underlined"
eq "$(fz_rows | tail -n1 | cut -f1)" foot; eq "$(fz_rows | tail -n1 | cut -f2 | cut -c1-3)" "up " "the uptime in its foot"
eq "$(fz_arg select)" "" "it opens on lock, the first"
eq "$(fz_arg dim)" set "the desktop dimmed"
eq "$(fz_arg width)" ""; eq "$(fz_arg lines)" ""; eq "$(fz_arg title)" ""; eq "$(fz_arg index)" set; eq "$(fz_arg drop)" "" "centred"
fits
case_ "…and each seal's picture is drawn (panel-art.txt)"
for n in t-lock t-sleep t-logout t-restart t-off; do grep -q "^@$n\$" "$REPO/configs/home/.config/fedokawaii/panel-art.txt" && _ok || _no "no $n"; done

act() { setup; answer "pick $1"; power; }
case_ "lock: the lock screen"
act lock; called '^kawa-lock --sleep$'; not_called '^systemctl'
case_ "sleep: at once — the screens dark and locked (kawa-lock --now), then suspended; no lock shown on the way"
act sleep; eq "$(grep -E '^(kawa-lock|wlopm|systemctl)' "$CALLS" | tr '\n' '|')" "kawa-lock --now|systemctl suspend|"
not_called '^sleep '; grep -q 'KAWA_SLEEP_BEAT' "$REPO/bin/kawa-power" && _no "a beat on the lock is back" || _ok
case_ "… each step in the journal (the health report reads it): asked, then handed to the system"
eq "$(grep -E '^(logger|kawa-lock|systemctl)' "$CALLS" | tr '\n' '|')" \
  "logger -t kawa-power -- sleep requested|kawa-lock --now|systemctl suspend|logger -t kawa-power -- suspend asked of the system|"
case_ "sleep, but the lock screen did not come up: no suspend (never an unlocked sleep), the screens lit again, the journal says so"
setup; stub kawa-lock '[ "$1" = --now ] && exit 1; exit 0'; answer "pick sleep"; power; not_called '^systemctl suspend'
called '^kawa-lock --screens on$'
called '^logger -t kawa-power -- not locked — no sleep$'
case_ "log out: dwl ended at once (nothing waited for first)"
setup; answer "pick log out"; power
eq "$(grep -E '^pkill' "$CALLS" | tr '\n' '|')" "pkill -xu $UID dwl|"
case_ "restart, shut down: systemctl reboot / poweroff"
act restart; called '^systemctl reboot$'; not_called '^pkill' "(restart: logind tells the programs)"
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
eq "$(grep '^kawa-lock' "$CALLS" | tr '\n' '|')" "kawa-lock --now|kawa-lock --screens on|" "the screens on again: no sleep, no black screen"

case_ "kawa-power sleep (the Sleep key): no menu — locked first, then suspended"
setup; rc 0 kawa-power sleep; eq "$(fz_n)" 0
eq "$(grep -E '^(kawa-lock|systemctl)' "$CALLS" | tr '\n' '|')" "kawa-lock --now|systemctl suspend|"
called '^logger -t kawa-power -- sleep requested$'
case_ "kawa-power sleep (no menu) refused by the system: the notice with its icon, the screens on again"
setup; stub systemctl 'echo "Failed to suspend system via logind: Sleep verb \"suspend\" not supported" >&2; exit 1'
rc 1 kawa-power sleep
called "^notify-send -a desktop -u critical -- $ICON_POWER  power could not sleep"
eq "$(grep '^kawa-lock' "$CALLS" | tr '\n' '|')" "kawa-lock --now|kawa-lock --screens on|"
case_ "kawa-power sleep, but the lock screen did not come up: no suspend"
setup; stub kawa-lock '[ "$1" = --now ] && exit 1; exit 0'; kawa-power sleep; not_called '^systemctl suspend'

case_ "--help: what it is, exit 0; anything else: exit 2, no menu"
setup; has "$(kawa-power --help)" "lock, sleep, log out"; rc 0 kawa-power --help
rc 2 kawa-power now; eq "$(fz_n)" 0

# ── the uptime in its foot ─────────────────────────────────────────────────────────────────────
if ((NS)); then
  up() { setup; answer esc; power "$1"; fz_rows | tail -n1 | cut -f2; }
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
  case_ "a Turkish or Arabic locale: the same ten characters"
  for loc in tr_TR.UTF-8 ar_EG.UTF-8; do
    setup; printf '90061.5 0\n' >"$TMP/uptime"; answer esc
    ns "mount --bind '$TMP/uptime' /proc/uptime" env "$(locale_ "$loc")" LC_ALL="$loc" kawa-power 2>/dev/null
    eq "$(fz_rows | tail -n1 | cut -f2)" "up 01d 01h" "$loc"; fits "" "$loc"
  done
else
  echo "  (uptime cases skipped: no user namespaces here to stand in for /proc/uptime)"
fi

done_
