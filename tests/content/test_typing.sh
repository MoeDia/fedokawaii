#!/usr/bin/env bash
# tests/content/test_typing.sh — kawa-typing (Super+U, learning → typing). The course's table against its document,
# then the program itself in a pseudo-terminal of its own (typing_cases.py, typing_pty.py): a scripted typist at known
# speeds, accuracy exactly as injected, rollover, resume after a kill, damaged state, every size.
. "$(dirname "$0")/lib.sh"
sandbox
KW=$REPO/configs/home/.local/lib/fedokawaii/kawatype
DOC=$REPO/docs/learn/typing/curriculum.md

case_ "the options: help, the table, a wrong one, no terminal, a file that is not there or holds nothing"
rc 0 kawa-typing --help
has "$(kawa-typing --help)" "kawa-typing FILE"
rc 2 kawa-typing --nonsense
rc 2 kawa-typing --seed
out=$(kawa-typing 2>&1 </dev/null); eq "$?" 1; has "$out" "terminal"
out=$(TERM=foot tty_run 80 kawa-typing "$TMP/nothing" 2>&1); has "$out" "No such file"
printf '\n\n  \n' >"$TMP/empty"; out=$(TERM=foot tty_run 80 kawa-typing "$TMP/empty" 2>&1); has "$out" "nothing in it to type"
out=$(TERM=linux tty_run 80 kawa-typing 2>&1); has "$out" "foot"

case_ "the course: as many lessons as its document says, stage by stage"
table=$(kawa-typing --course)
total=$(grep -oE '\*\*[0-9]+\*\*' "$DOC" | tr -d '*' | head -n1)
eq "$(wc -l <<<"$table")" "$total" "the lessons against curriculum.md's total"
while IFS=$'\t' read -r name count; do
  eq "$(grep -cE "^ *[0-9]+  $name {2,}[a-z]" <<<"$table")" "$count" "stage $name: curriculum.md says $count"
done < <(sed -n '/^## The stages/,/^## A key/p' "$DOC" | sed -En 's/^\| [0-9]+ \| ([^|]+) \|.*\| ([0-9]+) \| [^|]+ \| [^|]+ \|$/\1\t\2/p')

case_ "the course: a lesson's goal is never under its minimum; a meet has none; every id once"
python3 -IB - "$REPO/configs/home/.local/lib/fedokawaii" <<'PY' >"$TMP/course.out" 2>&1
import random, sys
sys.path.insert(0, sys.argv[1])
from kawatype import course
ids = [l.id for l in course.LESSONS]
assert len(ids) == len(set(ids)), 'a lesson id twice'
for l in course.LESSONS:
    assert l.low <= l.goal, l.id
    assert (l.kind == 'meet') == (l.goal == 0), l.id
    for s in range(6):
        t = course.text_for(l, random.Random(s))
        assert len(t) >= 8, l.id
        assert t.isascii(), l.id
        if l.stage < 8:          # (nothing before it is met)
            assert set(t) <= set(l.known) | {' '}, (l.id, set(t) - set(l.known))
        if l.kind in ('drill', 'words', 'mix') and any(not c.isalpha() for c in l.keys):
            assert set(t) & {c for c in l.keys if not c.isalpha()}, ('its mark is missing', l.id)
print('fine')
PY
eq "$(cat "$TMP/course.out")" "fine"

case_ "the inks: as the palette has them (tools/wada-palette.py), nothing written by hand"
python3 -IB - "$REPO" <<'PY' >"$TMP/inks.out" 2>&1
import importlib.util, sys
repo = sys.argv[1]
spec = importlib.util.spec_from_file_location('w', repo + '/tools/wada-palette.py')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
P = m.palette()[0]
for line in open(repo + '/configs/home/.local/lib/fedokawaii/kawatype/inks.txt'):
    if line.startswith('#'): continue
    t, d, l = line.split()
    if t == 'paper_ink':
        assert (d, l) == (P['dark']['lo'], P['light']['strong']), t
    else:
        assert (d, l) == (P['dark'][t], P['light'][t]), t
print('fine')
PY
eq "$(cat "$TMP/inks.out")" "fine"

case_ "the art as its tool makes it: inks, Sumi UI's letters, the hands (tools/build-typing-art.py)"
mkdir -p "$TMP/art"
if python3 -IB "$REPO/tools/build-typing-art.py" --out "$TMP/art" 2>/dev/null; then
  for f in inks.txt glyphs.txt hands.txt; do cmp -s "$TMP/art/$f" "$KW/$f" && _ok || _no "$f differs: run tools/build-typing-art.py"; done
else skip "no Pillow here"; fi

case_ "the terminal's colours it names are the ones screen.sh names"
grep -q 'ACCENT, ON_ACCENT, EDGE, EDGE2, ACCENT_TEXT, MUTED, FAINT, STRONG, SELECT, ON_SELECT = 16, 17, 18, 19, 20, 21, 22, 23, 24, 25' "$KW/app.py" && _ok || _no "app.py's numbers moved"
for pair in ACCENT_TEXT:20 ACCENT:16 MUTED:21 FAINT:22 STRONG:23 STITCH:19; do
  has "$(cat "$REPO/configs/home/.config/fedokawaii/screen.sh")" "INK_${pair%:*}=\$'\\e[38;5;${pair#*:}m'"
done

case_ "no kanji, no \"…\", no capitals in what it says (docs/design-system.md §2, §13)"
lacks "$(/usr/bin/grep -nP '[\x{3040}-\x{30ff}\x{4e00}-\x{9fff}…]' "$KW"/*.py)" ":" "kanji or an ellipsis in the code"

# the program itself: each line of typing_cases.py's a check here
while IFS= read -r line; do
  case $line in
    ok\ *) case_ "${line#ok }"; _ok ;;
    FAIL\ *) case_ "${line#FAIL }"; _no "${line#FAIL }" ;;
    [0-9]*\ failed) ;;
    *) case_ "typing_cases.py"; _no "$line" ;;
  esac
done < <(python3 -IB "$C/typing_cases.py" 2>&1)

done_
