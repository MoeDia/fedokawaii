#!/usr/bin/env bash
# tests/menus/test_calendar.sh — kawa-calendar (the clock, Super+C): a month as a dropdown,
# Monday first, today in [brackets], previous / next / back to today. "Now" is a stand-in
# (date without -d answers for $NOW); every other date sum is the real date's. Month edges:
# leap and plain Februaries, months starting on a Monday or a Sunday, six-week months, the
# turn of the year both ways; the [dd] marker on every weekday; the centred title; locales.
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
grid() { fz_rows "${1:-}" | sed -n '2,/previous$/p' | sed '$d'; }     # the week rows of menu N
W() { fz_arg width "${1:-}"; }

# ── a month ───────────────────────────────────────────────────────────────────────────
case_ "October 2026, today Friday the 16th: the grid, today bracketed and selected, a dropdown"
setup 2026-10-16; answer esc; cal; rc 0 true
eq "$(fz_rows | sed -n 1p | sed 's/^ *//')" "Mo  Tu  We  Th  Fr  Sa  Su"
eq "$(grid | sed 's/^ *//; s/  */ /g')" $'1 2 3 4\n5 6 7 8 9 10 11\n12 13 14 15 [16] 17 18\n19 20 21 22 23 24 25\n26 27 28 29 30 31'
eq "$(fz_arg select-index)" 3 "today's week selected"
eq "$(fz_arg anchor)" top-right; eq "$(fz_arg lines)" 10
lacks "$(fz_rows)" "back to today" "this month: no way back needed"
fits
case_ "the days sit under their weekday's name (each column 4 wide)"
h=$(fz_rows | sed -n 1p); r=$(fz_rows | grep -F '[16]'); r2=$(fz_rows | grep -F ' 23 ')
eq "$(awk -v s="$h" 'BEGIN{print index(s, "Fr")}')" "$(awk -v s="$r" 'BEGIN{print index(s, "16")}')" "16 right under Fr"
eq "$(awk -v s="$h" 'BEGIN{print index(s, "Fr")}')" "$(awk -v s="$r2" 'BEGIN{print index(s, "23")}')" "23 too"
case_ "the title: the month short and in English, centred over the grid to the column"
t=$(fz_arg mesg); eq "$(sed "s/^ *//" <<<"$t")" "Oct 2026"
python3 -I - "$(W)" "$t" "$h" <<'EOF' && _ok || _no "title off centre"
import sys
w, t, h = int(sys.argv[1]), sys.argv[2], sys.argv[3]
ink = lambda s: (len(s) - len(s.lstrip()), len(s.rstrip()))   # first and past-last column
(a, b), (c, d) = ink(t), ink(h)
sys.exit(0 if (a + b) == (c + d) == w else 1)   # the same middle, and that the box's middle
EOF

case_ "today on every weekday: the [dd] marker whole, never cut by fuzzel's last column"
for d in 12 13 14 15 16 17 18; do
  setup "2026-10-$d"; answer esc; cal
  has "$(fz_rows)" "[$d]" "the $d-th"; fits "" "today the $d-th"
done
case_ "today a Sunday at the end of a week row (Oct 18 2026): the row has its closing bracket"
setup 2026-10-18; answer esc; cal
r=$(fz_rows | grep -F '[18]'); eq "${r: -4}" "[18]"
(( $(cols "$r") <= $(W) - 1 )) && _ok || _no "the [18] row is $(cols "$r") columns: fuzzel cuts it to '[18…' at width $(W)"
case_ "today the 1st and a Monday (Feb 1 2027): the marker first in its row"
setup 2027-02-01; answer esc; cal
eq "$(grid | sed -n 1p | sed 's/^ *//')" "[ 1]  2   3   4   5   6   7"

# ── month edges ───────────────────────────────────────────────────────────────────────
weeks() { grid "$@" | grep -c .; }
lastday() { grid "$@" | tr -s ' []' '\n' | grep -v '^$' | tail -n1; }
case_ "February in a leap year (2028): 29 days"
setup 2028-02-10; answer esc; cal; eq "$(lastday)" 29; eq "$(fz_arg mesg | sed 's/^ *//')" "Feb 2028"
case_ "February in a plain year (2026): 28 days, starting on a Sunday: alone in its first row"
setup 2026-02-10; answer esc; cal; eq "$(lastday)" 28
eq "$(grid | sed -n 1p | sed 's/^ *//')" "1" ; eq "$(grid | sed -n 1p | awk '{print length}')" "$(fz_rows | sed -n 1p | awk '{print length}')" "under Su"
eq "$(weeks)" 5
case_ "February 2027 starts on a Monday: exactly four rows"
setup 2027-02-10; answer esc; cal; eq "$(weeks)" 4; eq "$(lastday)" 28
case_ "February 2100 (not a leap year) and 2000 (a leap year)"
setup 2100-02-03; answer esc; cal; eq "$(lastday)" 28
setup 2000-02-03; answer esc; cal; eq "$(lastday)" 29
case_ "a six-week month (March 2026: the 1st a Sunday, 31 days), paged to: still fits 10 lines"
setup 2026-02-10; answer "pick next" esc; cal
eq "$(fz_arg mesg 2 | sed 's/^ *//')" "Mar 2026"; eq "$(weeks 2)" 6; eq "$(lastday 2)" 31
eq "$(fz_rows 2 | wc -l)" 10 "header, 6 weeks, previous, next, back to today"
fits 2
case_ "a six-week month as this month (August 2026: the 1st a Saturday)"
setup 2026-08-20; answer esc; cal; eq "$(weeks)" 6; eq "$(lastday)" 31; fits

# ── paging ────────────────────────────────────────────────────────────────────────────
case_ "December → next → January of the next year, → next → February"
setup 2026-12-05; answer "pick next" enter esc; cal
eq "$(fz_arg mesg 1 | sed 's/^ *//')" "Dec 2026"; eq "$(fz_arg mesg 2 | sed 's/^ *//')" "Jan 2027"
eq "$(fz_arg mesg 3 | sed 's/^ *//')" "Feb 2027" "Enter again pages again"
lacks "$(fz_rows 2)" "[" "no today marker in another month"
case_ "January → previous → December of the year before"
setup 2027-01-31; answer "pick previous" enter esc; cal
eq "$(fz_arg mesg 2 | sed 's/^ *//')" "Dec 2026"; eq "$(fz_arg mesg 3 | sed 's/^ *//')" "Nov 2026"
case_ "the choice stays on previous / next while paging"
eq "$(fz_rows 2 | sed -n "$(($(fz_arg select-index 2) + 1))p" | sed 's/^ *//')" "$(fz_rows 2 | grep previous | sed 's/^ *//')"
case_ "on the 31st, next is the next month (not two ahead), previous the one before"
setup 2026-01-31; answer "pick next" "pick previous" "pick previous" esc; cal
eq "$(for n in 1 2 3 4; do fz_arg mesg $n | sed 's/^ *//'; echo; done | tr '\n' ',')" "Jan 2026,Feb 2026,Jan 2026,Dec 2025,"
case_ "back to today: this month again, today selected, the way back gone"
setup 2026-10-16; answer "pick next" "pick next" "pick back to today" esc; cal
eq "$(fz_arg mesg 4 | sed 's/^ *//')" "Oct 2026"; eq "$(fz_arg select-index 4)" 3; lacks "$(fz_rows 4)" "back to today"
has "$(fz_rows 2)" "back to today"
case_ "a day row, Esc, a click outside, typed text: closes, exit 0"
for a in "row 3" esc lost "typed 12"; do setup; answer "$a"; rc 0 cal; eq "$(fz_n)" 1; done
case_ "a long way back and forth (24 months each way): the right month, no error"
setup 2026-10-16; for _ in {1..24}; do answer "pick next"; done; answer esc; cal
eq "$(fz_arg mesg 25 | sed 's/^ *//')" "Oct 2028"
setup 2026-10-16; for _ in {1..24}; do answer "pick previous"; done; answer esc; cal
eq "$(fz_arg mesg 25 | sed 's/^ *//')" "Oct 2024"

# ── locales, use ──────────────────────────────────────────────────────────────────────
case_ "Turkish, Arabic, Japanese, German locales: the month and days stay English"
for loc in tr_TR.UTF-8 ar_EG.UTF-8 ja_JP.UTF-8 de_DE.UTF-8; do
  setup 2026-05-16; answer esc; env "$(locale_ "$loc")" LC_ALL="$loc" kawa-calendar 2>/dev/null
  eq "$(fz_arg mesg | sed 's/^ *//')" "May 2026" "$loc"; has "$(fz_rows | sed -n 1p)" "Mo  Tu" "$loc"
  has "$(fz_rows)" "[16]" "$loc"; fits "" "$loc"
done
case_ "LC_TIME alone set to Arabic (LANG English): still English"
setup 2026-05-16; answer esc; env "$(locale_ ar_EG.UTF-8)" LC_TIME=ar_EG.UTF-8 kawa-calendar 2>/dev/null
eq "$(fz_arg mesg | sed 's/^ *//')" "May 2026"
case_ "--help: what it is, exit 0; anything else: exit 2, no menu"
setup; has "$(kawa-calendar --help)" "this month as a dropdown"; rc 0 kawa-calendar --help
rc 2 kawa-calendar next; eq "$(fz_n)" 0

done_
