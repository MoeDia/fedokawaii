#!/usr/bin/env bash
# tests/content/test_lessons_course.sh — the whole course, not a lesson at a time (sa12): every written lesson
# sits in its syllabus day and part, needs only what is taught before it, a day is 25 to 30 minutes, Part 2's
# runs replayed in day order from an empty dojo each fail before their steps and pass after, every ask's proof
# passes against the repo. The folder is docs/lessons once days.tsv is there, else its wip (lessons not yet in days).
. "$(dirname "$0")/lib.sh"
sandbox
F=$REPO/docs/lessons; [[ -n $(grep -v "^#" "$F/days.tsv") ]] || F=$F/wip
case_ "every lesson's check, in the syllabus order"
out=$(python3 -B -I "$C/lessons_course.py" "$F" "$REPO/docs/lessons/syllabus.tsv" "$REPO" 2>&1)
eq "$(grep -c '^FAIL' <<<"$out")" 0 "$(grep '^FAIL' <<<"$out" | head -n 5)"
[[ $(grep -c '^ok day [0-9]* [a-z0-9-]*: ' <<<"$out") -gt 40 ]] && _ok || _no "too few checks ran: $out"

case_ "a broken lesson is caught: a check that already passes, a need not taught yet, a day too long, an example that prints otherwise"
W=$TMP/course; mkdir -p "$W"; cp "$F"/*.md "$W/"
sed -i 's/^needs: .*/needs: [triad]/' "$W/variables.md"
sed -i 's/^minutes: .*/minutes: 25/' "$W/numbers.md"
sed -i 's/^I am learning Python$/I am learning C/' "$W/first-print.md"
out=$(python3 -B -I "$C/lessons_course.py" "$W" "$REPO/docs/lessons/syllabus.tsv" "$REPO" 2>&1)
has "$out" "variables needs triad" "no complaint about the need"
has "$out" "minutes, a day is" "no complaint about the day"
has "$out" "FAIL day 1 first-print: example prints its output: printed" "no complaint about the example"
done_
