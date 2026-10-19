#!/usr/bin/env bash
# tests/menus/test_calendar.sh — kawa-calendar (the clock, Super+C): a month as a dropdown in
# the panel's grid (cell lines), Monday first, today stamped, previous / next / today as keys. "Now" is a stand-in
# (date without -d answers for $NOW); every other date sum is the real date's. Month edges:
# leap and plain Februaries, months starting on a Monday or a Sunday, six-week months, the
# turn of the year both ways; today on every weekday; locales.
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"

setup() {
  menus_sandbox
  NOW=${1:-2026-10-16}; export NOW
  # shellcheck disable=SC2016  # (expanded by the stand-in)
  stub date 'for a; do case $a in -d*|--date*) exec /bin/date "$@" ;; esac; done
exec /bin/date -d "$NOW 13:00" "$@"'
}
cal() { kawa-calendar; }
. "$REPO/configs/home/.config/fedokawaii/icons.sh"
month() { fz_rows "${1:-}" | sed -n 1p | cut -f3; }                        # the heading's name
cells() { fz_rows "${1:-}" | grep '^cell' | sed 1,7d; }                    # the six weeks, in order
days() { cells "$@" | grep -v $'\tdim$' | cut -f2 | tr '\n' ' '; }         # this month's days
week() { cells "${2:-}" | sed -n "$(( ($1 - 1) * 7 + 1 )),$(( $1 * 7 ))p" | cut -f2,3 | tr '\t\n' ': ' | sed 's/: / /g; s/ $//'; }
lastday() { cells "$@" | grep -v $'\tdim$' | tail -n1 | cut -f2; }
today_() { cells "$@" | grep $'\ttoday$' | cut -f2; }
key_at() { fz_rows "${2:-}" | sed -n "$(( $1 + 1 ))p"; }                    # line N (0-based)

# ── a month ───────────────────────────────────────────────────────────────────────────
case_ "October 2026, today Friday the 16th: 暦 and the month, the weekdays, six weeks, today stamped, three keys"
setup 2026-10-16; answer esc; cal; rc 0 true
eq "$(fz_rows | sed -n 1p)" "part	暦	Oct 2026"
eq "$(fz_rows | sed -n '2,8p' | tr '\n' '|')" "cell	Mo	head|cell	Tu	head|cell	We	head|cell	Th	head|cell	Fr	head|cell	Sa	head|cell	Su	head|"
eq "$(cells | wc -l)" 42 "six weeks, always"
eq "$(week 1)" "28:dim 29:dim 30:dim 1 2 3 4" "September's last days dim before the 1st (a Thursday)"
eq "$(week 3)" "12 13 14 15 16:today 17 18" "today stamped"
eq "$(week 6)" "2:dim 3:dim 4:dim 5:dim 6:dim 7:dim 8:dim" "November's first days fill the sixth week"
eq "$(fz_rows | tail -n 3 | tr '\n' '|')" "key	$ICON_CHEVRON_LEFT	previous|key	$ICON_CHEVRON_RIGHT	next|key	$ICON_CALENDAR	today|"
eq "$(fz_rows | wc -l)" 53 "the heading, 7 weekdays, 42 days, 3 keys"
eq "$(fz_arg drop)" set "a dropdown"; eq "$(fz_arg select)" "" "opened clean"; eq "$(fz_arg width)" "" "sized by its grid"
fits
case_ "today on every weekday: stamped, in its weekday's column"
for d in 12 13 14 15 16 17 18; do
  setup "2026-10-$d"; answer esc; cal
  eq "$(today_)" "$d" "the $d-th"
  n=$(cells | grep -n $'\ttoday$' | cut -d: -f1); eq "$(( (n - 1) % 7 ))" "$(( d - 12 ))" "the $d-th under its weekday"
done
case_ "today the 1st and a Monday (Feb 1 2027): first in its row, nothing dim before it"
setup 2027-02-01; answer esc; cal
eq "$(week 1)" "1:today 2 3 4 5 6 7"

# ── month edges ───────────────────────────────────────────────────────────────────────
case_ "February in a leap year (2028): 29 days"
setup 2028-02-10; answer esc; cal; eq "$(lastday)" 29; eq "$(month)" "Feb 2028"
case_ "February in a plain year (2026): 28 days, starting on a Sunday: alone, last in its first row"
setup 2026-02-10; answer esc; cal; eq "$(lastday)" 28
eq "$(week 1)" "26:dim 27:dim 28:dim 29:dim 30:dim 31:dim 1"
case_ "February 2027 starts on a Monday: four weeks of its own, two of March's"
setup 2027-02-10; answer esc; cal; eq "$(lastday)" 28; eq "$(week 5)" "1:dim 2:dim 3:dim 4:dim 5:dim 6:dim 7:dim"
case_ "February 2100 (not a leap year) and 2000 (a leap year)"
setup 2100-02-03; answer esc; cal; eq "$(lastday)" 28
setup 2000-02-03; answer esc; cal; eq "$(lastday)" 29
case_ "a month over six weeks' rows (March 2026: the 1st a Sunday, 31 days), paged to"
setup 2026-02-10; answer "pick next" esc; cal
eq "$(month 2)" "Mar 2026"; eq "$(lastday 2)" 31; eq "$(week 6 2)" "30 31 1:dim 2:dim 3:dim 4:dim 5:dim"
eq "$(cells 2 | wc -l)" 42; fits 2
case_ "every day of a month once, in order"
setup 2026-08-20; answer esc; cal; eq "$(days)" "$(seq -s ' ' 1 31) "

# ── paging ────────────────────────────────────────────────────────────────────────────
case_ "December → next → January of the next year, → Enter again → February"
setup 2026-12-05; answer "pick next" enter esc; cal
eq "$(month 1)" "Dec 2026"; eq "$(month 2)" "Jan 2027"
eq "$(month 3)" "Feb 2027" "Enter again pages again"
eq "$(today_ 2)" "" "no day stamped in another month"
case_ "January → previous → December of the year before"
setup 2027-01-31; answer "pick previous" enter esc; cal
eq "$(month 2)" "Dec 2026"; eq "$(month 3)" "Nov 2026"
case_ "the cursor stays on the key that paged"
eq "$(key_at "$(fz_arg select 2)" 2)" "key	$ICON_CHEVRON_LEFT	previous"
case_ "on the 31st, next is the next month (not two ahead), previous the one before"
setup 2026-01-31; answer "pick next" "pick previous" "pick previous" esc; cal
eq "$(for n in 1 2 3 4; do month $n; done | tr '\n' ',')" "Jan 2026,Feb 2026,Jan 2026,Dec 2025,"
case_ "opened on the stroke of midnight at a month's end: the day it read, stamped in its month"
# (the clock reads 31 October for the first look at "now", 1 November from then on)
setup 2026-10-31; export NOWS=$TMP/nows
# shellcheck disable=SC2016  # (expanded by the stand-in)
stub date 'for a; do case $a in -d*|--date*) exec /bin/date "$@" ;; esac; done
n=$(cat "$NOWS" 2>/dev/null || echo 0); echo $((n + 1)) >"$NOWS"
[ "$n" = 0 ] && exec /bin/date -d "2026-10-31 23:59:59" "$@"; exec /bin/date -d "2026-11-01 00:00:00" "$@"'
answer esc; cal
eq "$(month)" "Oct 2026"; eq "$(today_)" 31
case_ "today: this month again, today stamped, the cursor on today"
setup 2026-10-16; answer "pick next" "pick next" "pick today" esc; cal
eq "$(month 4)" "Oct 2026"; eq "$(today_ 4)" 16; eq "$(key_at "$(fz_arg select 4)" 4)" "key	$ICON_CALENDAR	today"
case_ "Esc, a click outside, typed text: closes, exit 0"
for a in esc lost "typed 12"; do setup; answer "$a"; rc 0 cal; eq "$(fz_n)" 1; done
case_ "a long way back and forth (24 months each way): the right month, no error"
setup 2026-10-16; for _ in {1..24}; do answer "pick next"; done; answer esc; cal
eq "$(month 25)" "Oct 2028"
setup 2026-10-16; for _ in {1..24}; do answer "pick previous"; done; answer esc; cal
eq "$(month 25)" "Oct 2024"

# ── locales, use ──────────────────────────────────────────────────────────────────────
case_ "Turkish, Arabic, Japanese, German locales: the month and days stay English"
for loc in tr_TR.UTF-8 ar_EG.UTF-8 ja_JP.UTF-8 de_DE.UTF-8; do
  setup 2026-05-16; answer esc; env "$(locale_ "$loc")" LC_ALL="$loc" kawa-calendar 2>/dev/null
  eq "$(month)" "May 2026" "$loc"; eq "$(fz_rows | sed -n 2p)" "cell	Mo	head" "$loc"
  eq "$(today_)" 16 "$loc"; fits "" "$loc"
done
case_ "LC_TIME alone set to Arabic (LANG English): still English"
setup 2026-05-16; answer esc; env "$(locale_ ar_EG.UTF-8)" LC_TIME=ar_EG.UTF-8 kawa-calendar 2>/dev/null
eq "$(month)" "May 2026"
case_ "--help: what it is, exit 0; anything else: exit 2, no menu"
setup; has "$(kawa-calendar --help)" "this month as a dropdown"; rc 0 kawa-calendar --help
rc 2 kawa-calendar next; eq "$(fz_n)" 0

done_
