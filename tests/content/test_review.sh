#!/usr/bin/env bash
# tests/content/test_review.sh — the daily review (lib/review.py, sb03): cards due after 1, 3, 7, 14 days,
# a wrong answer back the next day one step down, learned after 3 right answers on different days, five
# cards a session taken in turn from different lessons, a streak, a quiet rank, the week's look back.
. "$(dirname "$0")/lib.sh"
sandbox
R=$TMP/reviews
rv() { python3 -B -I -c "
import sys; sys.path.insert(0, '$REPO/lib')
import review as r
$1"; }
DECK="deck = {f'{l}#{n}': ('q', 'a', l) for l in ('aa', 'bb', 'cc') for n in (1, 2, 3)}"

case_ "a card is due the day after its lesson, then 3, 7 and 14 days after each right answer"
out=$(rv "$DECK
done = {'aa': '2026-01-01'}
d = lambda rows, t: r.due(deck, done, rows, t, 9)
print(len(d([], '2026-01-01')), len(d([], '2026-01-02')))
rows = [('2026-01-02', 'aa#1', True)]
print(len(d(rows, '2026-01-04')), len(d(rows, '2026-01-05')))
rows += [('2026-01-05', 'aa#1', True)]
print('aa#1' in d(rows, '2026-01-11'), 'aa#1' in d(rows, '2026-01-12'))
rows += [('2026-01-12', 'aa#1', True), ('2026-01-26', 'aa#1', True)]
print('aa#1' in d(rows, '2026-02-08'), 'aa#1' in d(rows, '2026-02-09'))")
eq "$out" $'0 3\n2 3\nFalse True\nFalse True' "schedule"

case_ "a wrong answer brings the card back next day, one step down"
out=$(rv "$DECK
done = {'aa': '2026-01-01'}
rows = [('2026-01-02', 'aa#1', True), ('2026-01-05', 'aa#1', True), ('2026-01-12', 'aa#1', False)]
print('aa#1' in r.due(deck, done, rows, '2026-01-12', 9), 'aa#1' in r.due(deck, done, rows, '2026-01-13', 9))
rows += [('2026-01-13', 'aa#1', True)]
print(r.states(deck, done, rows)['aa#1']['due'])")
eq "$out" $'False True\n2026-01-20' "wrong"

case_ "five cards at most, turns taken between lessons, a card answered today waits"
out=$(rv "$DECK
done = {'aa': '2026-01-01', 'bb': '2026-01-01', 'cc': '2026-01-01'}
p = r.due(deck, done, [], '2026-01-02')
print(len(p), [c.split('#')[0] for c in p])
print(len(r.due(deck, done, [('2026-01-02', c, True) for c in p], '2026-01-02', 9)))")
eq "$out" $'5 [\'aa\', \'bb\', \'cc\', \'aa\', \'bb\']\n4' "session"

case_ "learned after 3 right answers on different days (same day twice counts once); new before its lesson"
out=$(rv "$DECK
done = {'aa': '2026-01-01', 'bb': '2026-01-01'}
rows = [('2026-01-02', 'aa#1', True), ('2026-01-02', 'aa#2', True), ('2026-01-05', 'aa#1', True), ('2026-01-06', 'bb#1', True)]
print(sorted(r.concepts(deck, done, rows).items()))
rows += [('2026-01-12', 'aa#2', True)]
print(r.concepts(deck, done, rows)['aa'])")
eq "$out" $'[(\'aa\', \'practising\'), (\'bb\', \'practising\'), (\'cc\', \'new\')]\nlearned' "learned"

case_ "streak, rank and the week look back; the record keeps good lines and passes over bad ones"
printf '2026-01-02\taa#1\tright\njunk\n2026-01-03\taa#1\twrong\n2026-01-03\taa#9x\tright\n' >"$R"
out=$(rv "rows = r.read_reviews('$R'); print(len(rows))
r.add_review('$R', 'aa#2', True, '2026-01-04'); print(len(r.read_reviews('$R')))
done = {'aa': '2026-01-01'}
print(r.streak(done, r.read_reviews('$R'), '2026-01-04'), r.streak(done, r.read_reviews('$R'), '2026-01-05'), r.streak(done, r.read_reviews('$R'), '2026-01-07'))
print(r.rank(done, r.read_reviews('$R')), r.rank({}, []))
print(r.look_back(done, r.read_reviews('$R'), '2026-01-07'))")
eq "$out" $'2\n3\n4 4 0\n(\'white belt\', 7) (\'white belt\', 0)\n{\'lessons\': 1, \'right\': 2, \'wrong\': 1, \'days\': 4}' "numbers"
done_
