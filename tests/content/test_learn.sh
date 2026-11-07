#!/usr/bin/env bash
# tests/content/test_learn.sh — the lessons (Super+U → learning → lessons): the book cut by
# tools/learn-pieces.py, nothing lost and nothing in an impossible order (until the book goes); the old Guide
# PDF gone; kawa-learn in a terminal of its own (learn_pty.py reads back what it draws), on three days of
# fixtures/lessons: the pair, its checks, every key and window size, the record kept across a kill and a
# bad file, the reader never falling over.
. "$(dirname "$0")/lib.sh"
sandbox
export KAWA_LEARN=$REPO/docs/learn PATH=$REPO/bin:$PATH
FIX=$C/fixtures/lessons
ST=$XDG_STATE_HOME/fedokawaii
stub bat 'cat'
pty() { python3 -B -I "$C/learn_pty.py" "$@"; }
screens() { sed -n '/^--- screen/,$p'; }

# ── the cut ───────────────────────────────────────────────────────────────────────────────
case_ "the pieces are what the book and the syllabus make, byte for byte"
out=$(python3 -B -I "$REPO/tools/learn-pieces.py" --check 2>&1) && _ok || _no "$out"
case_ "at least 120 lessons; every id once; each with its front matter; a name that fits the pane's heading"
n=$(find "$KAWA_LEARN/pieces" -name '[0-9][0-9][0-9]-*.md' | wc -l); ((n >= 120)) && _ok || _no "$n lessons"
eq "$(cut -f2 "$KAWA_LEARN/index.tsv" | sort | uniq -d | grep -c .)" 0 "an id twice"
awk -F'\t' '$1=="L"{print $3}' "$KAWA_LEARN/index.tsv" >"$TMP/files"
eq "$(wc -l <"$TMP/files")" "$n" "the index's lessons are the files"
for f in $(sed -n '1p;40p;$p' "$TMP/files"); do
  head -n 9 "$KAWA_LEARN/pieces/$f" | grep -qE '^needs: \[' && head -n 9 "$KAWA_LEARN/pieces/$f" | grep -qE '^minutes: [0-9]+$' && _ok || _no "$f: its front matter"
done
awk -F'\t' '$1=="L" && length($7) > 46 {print $7}' "$KAWA_LEARN/index.tsv" >"$TMP/long"; eq "$(cat "$TMP/long")" "" "a name longer than the pane's heading holds"
case_ "the order is an order: what a lesson needs comes before it, nothing in a cycle, every need a lesson"
out=$(awk -F'\t' '$1=="L"{ n=split($9, a, " "); for (i=1;i<=n;i++) if (!(a[i] in seen)) print $2" needs "a[i]; seen[$2]=1 }' "$KAWA_LEARN/index.tsv"); eq "$out" "" "$out"
case_ "the numbers count only what is required: 1 to N with no gap, projects outside them"
eq "$(awk -F'\t' '$1=="L" && $4>0{ if ($4 != ++k) print "gap at "$2 }' "$KAWA_LEARN/index.tsv")" ""
eq "$(awk -F'\t' '$1=="L" && $4==0 && $7=="projects"{c++} END{print (c>30)}' "$KAWA_LEARN/index.tsv")" 1 "projects are not counted"
case_ "the book whole: every section, exercise and solution in exactly one lesson"
python3 -B -I - "$REPO/docs/fedokawaii-learn.md" "$KAWA_LEARN/pieces" >"$TMP/whole" <<'PY'
import collections, glob, os, re, sys
book = open(sys.argv[1], encoding="utf-8").read()
fence = False; secs = []; exs = []; sols = []; in_sol = False
for l in book.split("\n"):
    if l.startswith("```"): fence = not fence
    if fence: continue
    if re.match(r"# [BCD]\. ", l): in_sol = True
    if re.match(r"# A\. ", l): in_sol = False
    m = re.match(r"## (\d+\.\d+) ", l)
    if m: secs.append(m[1])
    m = re.match(r"\*\*(\d+\.\d+) ★", l)
    if m: (sols if in_sol else exs).append(m[1])
got_secs = collections.Counter(); got_ex = collections.Counter(); got_sol = collections.Counter()
for f in glob.glob(sys.argv[2] + "/*.md"):
    fence = False
    for l in open(f, encoding="utf-8").read().split("\n"):
        if l.startswith("```"): fence = not fence
        if fence: continue
        m = re.match(r"## (\d+\.\d+) ", l)
        if m: got_secs[m[1]] += 1
        m = re.match(r"\*\*(\d+\.\d+) ★", l)
        if m: got_ex[m[1]] += 1
        m = re.match(r"<!-- solution (\S+) -->", l)
        if m: got_sol[m[1]] += 1
for name, want, got in (("section", secs, got_secs), ("exercise", exs, got_ex), ("solution", sols, got_sol)):
    for w in want:
        if got[w] != 1: print(name, w, "in", got[w], "lessons")
print(len(secs), "sections", len(exs), "exercises", len(sols), "solutions")
PY
eq "$(grep -vE '^[0-9]+ sections' "$TMP/whole" | head -5)" "" "$(head -3 "$TMP/whole")"
has "$(cat "$TMP/whole")" "exercises"
case_ "the cut stops, saying why: a section in no lesson, in two, a need that comes later, a section out of order"
cut_copy() { rm -rf "$TMP/c"; mkdir -p "$TMP/c/tools" "$TMP/c/docs"; cp "$REPO/tools/learn-pieces.py" "$TMP/c/tools/"; cp "$REPO/docs/fedokawaii-learn.md" "$TMP/c/docs/"; cp -r "$REPO/docs/learn" "$TMP/c/docs/"; }
cut_copy; sed -i '/^what-pieces /d' "$TMP/c/docs/learn/syllabus.txt"; out=$(python3 -B -I "$TMP/c/tools/learn-pieces.py" 2>&1); eq "$?" 1; has "$out" "in no lesson"
cut_copy; sed -i 's/^the-plan | twenty-six weeks | 66.0\/1$/&\nsecond | twice | 66.0\/1/' "$TMP/c/docs/learn/syllabus.txt"; out=$(python3 -B -I "$TMP/c/tools/learn-pieces.py" 2>&1); eq "$?" 1; has "$out" "is in the-plan already"
cut_copy; sed -i 's/^chapter 12 yazi | yazi: the files | folder | needs 4$/chapter 12 yazi | yazi: the files | folder | needs 14/' "$TMP/c/docs/learn/syllabus.txt"; out=$(python3 -B -I "$TMP/c/tools/learn-pieces.py" 2>&1); eq "$?" 1; has "$out" "comes later"
cut_copy; sed -i 's/^py-if | True, False, if | 0 1 2$/py-if | True, False, if | 2 1 0/' "$TMP/c/docs/learn/syllabus.txt"; out=$(python3 -B -I "$TMP/c/tools/learn-pieces.py" 2>&1); eq "$?" 1; has "$out" "out of the book's order"
cut_copy; sed -i 's/^## 25.7 Common mistakes$/## 25.99 New\n\nnew words\n\n&/' "$TMP/c/docs/fedokawaii-learn.md"; out=$(python3 -B -I "$TMP/c/tools/learn-pieces.py" 2>&1); eq "$?" 1; has "$out" "section 25.99 of the book is in no lesson"
cut_copy; echo stray >"$TMP/c/docs/learn/pieces/stray.md"; rc 1 python3 -B -I "$TMP/c/tools/learn-pieces.py" --check
case_ "what is for one form only: a lesson's words stay out of the PDF's source as comments, the book's out of the lessons"
has "$(cat "$KAWA_LEARN/pieces/001-how-to-read.md")" "These lessons are the Learn book cut into pieces"
lacks "$(cat "$KAWA_LEARN/pieces/001-how-to-read.md")" "at the back"
python3 -B -I -c 'import re,sys
b=open(sys.argv[1],encoding="utf-8").read()
assert "<!-- lesson\nThese lessons are the Learn book" in b and "<!-- book -->\n\nThis book is the practical one" in b' "$REPO/docs/fedokawaii-learn.md" && _ok || _no "the book's markers"
case_ "the book's own words: no \"You need\" in a lesson (the list says what a lesson needs), no appendix to turn to"
eq "$(grep -l 'You need:' "$KAWA_LEARN"/pieces/*.md | wc -l)" 0
eq "$(grep -lE '^# ' "$KAWA_LEARN"/pieces/*.md | wc -l)" "$(python3 -B -I - "$KAWA_LEARN/pieces" <<'PY'
import glob, sys
n = 0
for f in glob.glob(sys.argv[1] + "/*.md"):
    fence = False
    for l in open(f, encoding="utf-8").read().split("\n"):
        if l.startswith("```"):
            fence = not fence
        elif not fence and l.startswith("# "):
            print("a book heading in", f, l, file=sys.stderr); n += 1
print(len([f for f in glob.glob(sys.argv[1] + "/*.md") if any(l.startswith("# ") for l in open(f, encoding="utf-8").read().split("\n"))]))
PY
)" "(only code's comments start a line with #)"

# ── the old Guide ─────────────────────────────────────────────────────────────────────────
case_ "the Guide PDF and every reference to it are gone (the handbook's source stays, the technical reference)"
[[ ! -e "$REPO/docs/Fedokawaii-Guide"".pdf" ]] && _ok || _no "the PDF is there"
[[ -s $REPO/docs/fedokawaii-guide.md ]] && _ok || _no "its source went too"
out=$(grep -rIl --exclude-dir=.git --exclude-dir=.claude --exclude=CLAUDE.md 'Guide\.pdf' "$REPO" 2>/dev/null); eq "$out" "" "still named in: $out"
out=$(grep -rIlE --exclude=test_learn.sh --exclude=test_menu.sh --exclude-dir=.git --exclude-dir=.claude 'fedokawaii guide\b' "$REPO/bin" "$REPO/system" "$REPO/configs" "$REPO/tests" "$REPO/README.md" 2>/dev/null); eq "$out" "" "the command still named in: $out"

# ── the daily lessons, in their window ────────────────────────────────────────────────────
export KAWA_TOOLKIT=$REPO KAWA_LEARN=$FIX
today=$(date +%F); DOJO=$HOME/dojo
rec() { printf '%s\t%s\n' "$1" "$2" >>"$ST/days"; }
clean() { rm -rf "$ST" "$DOJO"; mkdir -p "$ST"; }

case_ "every lesson laid out at 120, 88, 60, 40, 20 and 9 columns: nothing wider than the window, no word lost"
out=$(python3 -B -I "$C/learn_walk.py" "$REPO" "$FIX" 120 88 60 40 20 9 2>&1) && _ok || _no "$(tail -n 6 <<<"$out")"

case_ "the day: today's pair, a mark on the first to do, what comes next told, how far; no ellipsis"
clean; s=$(pty 118x40 '!dump' | screens)
has "$s" "day 1"; has "$s" "1 of 3"; has "$s" "the panel"; has "$s" "a program that says hello"; has "$s" "10 min"
has "$s" "next"; has "$s" "the keys"; has "$s" "a name for a value"; has "$s" "day 2"
has "$s" "takes"; has "$s" "you answer"; has "$s" "0 of 3"; lacks "$s" "…"; lacks "$s" "Traceback"
case_ "§7, by the columns: a row's name from 9, the time at the block's end, the pane beside it"
l=$(grep -F 'a program that says hello' <<<"$s" | head -n 1); [[ $l =~ ^(.*)a\ program ]] && eq "${#BASH_REMATCH[1]}" 11 "two of margin, its name at 9: [$l]" || _no "[$l]"
[[ $l =~ 15\ min ]] && _ok || _no "no time on the row: [$l]"
case_ "too narrow for a pane: the pair alone, the same rows; and every size down to a single cell draws, and closes"
s=$(pty 60x20 '!dump' | screens); has "$s" "the panel"; has "$s" "days"; lacks "$s" "takes"
for z in 1x1 2x2 5x3 10x4 20x5 30x6 46x8 99x10 100x12 240x70; do
  o=$(pty "$z" j '\t' '\r' j s '\r' '\x1b' 2>&1); rc=$?
  eq "$rc" 0 "$z: exit $rc: ${o: -300}"
done

case_ "a lesson: its idea, a table, the exercise, the check; the answer only on s; the end says what Enter does"
clean; s=$(pty 118x40 '\r' '!wait 0.5' '!dump' | screens)
has "$s" "the panel"; has "$s" "one key"; has "$s" "exercise"; has "$s" "Which key opens the panel?"; has "$s" "day 1"
has "$s" "answer it"; lacks "$s" "closes it Super"
out=$(pty 118x40 '\r' '!wait 0.5' s '!dump' | screens); has "$out" "answer"; has "$out" "Super+U"
case_ "an ask: a wrong answer is not stamped, and said; the right one, in any case or spacing, is"
clean; s=$(pty 118x40 '\r' '!wait 0.5' '\r' 'x' 'y' '\r' '!wait 0.2' '!dump' | screens); has "$s" "not yet"; has "$s" "xy"
[[ ! -s $ST/days ]] && _ok || _no "a wrong answer stamped: $(cat "$ST/days")"
pty 118x40 '\r' '!wait 0.5' '\r' 's' 'u' 'p' 'e' 'r' ' ' '+' ' ' 'u' '\r' '!wait 0.2' >/dev/null
eq "$(cat "$ST/days")" "$today"$'\t'"the-panel"
case_ "Esc while answering: back to the page, nothing kept, nothing typed taken for a key"
clean; pty 118x40 '\r' '!wait 0.5' '\r' 'q' '\x1b' '!wait 0.2' >/dev/null; rc=$?; eq "$rc" 0; [[ ! -s $ST/days ]] && _ok || _no "stamped"
case_ "a run check: nothing there, said; the wrong output, shown; the right one stamps; Enter goes on to the other of the pair"
clean; rec "$today" the-panel
s=$(pty 118x40 '\r' '!wait 0.5' 'G' '\r' '!wait 0.5' '!dump' | screens); has "$s" "not yet"; has "$s" "is not there yet"; lacks "$(cat "$ST/days")" first-print
mkdir -p "$DOJO/hello"; echo 'print("nope")' >"$DOJO/hello/hello.py"
s=$(pty 118x40 '\r' '!wait 0.5' 'G' '\r' '!wait 0.5' '!dump' | screens); has "$s" "nope"; lacks "$(cat "$ST/days")" first-print
echo 'import sys; sys.exit(4)' >"$DOJO/hello/hello.py"
s=$(pty 118x40 '\r' '!wait 0.5' 'G' '\r' '!wait 0.5' '!dump' | screens); has "$s" "status 4"
echo 'print("hello")' >"$DOJO/hello/hello.py"
s=$(pty 118x40 '\r' '!wait 0.5' 'G' '\r' '!wait 0.5' '!dump' | screens); has "$s" "the day"; lacks "$s" "not yet"
has "$(cat "$ST/days")" first-print; eq "$(cut -f1 "$ST/days" | sort -u)" "$today"
s=$(pty 118x40 '!dump' | screens); has "$s" "day 1"; has "$s" "the keys"
case_ "the pair walked: its first done, Enter opens the other; the second done, Enter is the day"
clean; rec "$today" first-print
s=$(pty 118x40 '\r' '!wait 0.5' 'G' '\r' 'S' 'u' 'p' 'e' 'r' '+' 'U' '\r' '!wait 0.2' '!dump' | screens); has "$s" "the day"
clean; s=$(pty 118x40 '\r' '!wait 0.5' 'G' '\r' 'S' 'u' 'p' 'e' 'r' '+' 'U' '\r' '!wait 0.2' '!dump' | screens); has "$s" "next: a program that says hello"
case_ "one day a date: a day done on an earlier date gives the next; done today, it stays and the next waits"
clean; rec 2026-01-01 the-panel; rec 2026-01-01 first-print
s=$(pty 118x40 '!dump' | screens); has "$s" "the keys"; has "$s" "2 of 3"
s=$(pty 118x40 h '!dump' | screens); has "$s" "the panel"; has "$s" "1 of 3" "← a day before"
s=$(pty 118x40 l '!dump' | screens); has "$s" "2 of 3" "→ past today: stays"; lacks "$s" "3 of 3"
clean; rec "$today" the-panel; rec "$today" first-print
s=$(pty 118x40 '!dump' | screens); has "$s" "1 of 3"; has "$s" "the keys"; has "$s" "stamped"
s=$(pty 118x40 l '!dump' | screens); lacks "$s" "2 of 3" "the next waits for its date"
case_ "the place Super+U's row reads, and the words of --place"
clean; rec 2026-01-01 the-panel; rec 2026-01-01 first-print; kawa-learn --place >"$TMP/words"
has "$(cat "$TMP/words")" "day 2 of 3 · next: the keys"
eq "$(cat "$ST/learn.place")" $'2\t3\tthe keys\t10\t50'
case_ "every day done: nothing next, every key still works"
clean; for i in the-panel first-print the-keys names keeping-it-well-and-why-a-long-name-wraps loops; do rec 2026-01-01 "$i"; done
s=$(pty 118x40 '!dump' j '\r' '\x1b' '!dump' | screens); has "$s" "3 of 3"; has "$s" "3 of 3"; lacks "$s" "next"
eq "$(kawa-learn --place)" "day 3 of 3"
case_ "a lesson by name; none by a wrong name; a record that cannot be read: its bad lines passed over"
clean; s=$(pty 118x40 --arg names '!wait 0.5' '!dump' | screens); has "$s" "a name for a value"
rc 2 kawa-learn nonsense </dev/null
clean; printf 'rubbish\n2026-01-01\tthe-panel\nx\ty\tz\n' >"$ST/days"; s=$(pty 118x40 '!dump' | screens); has "$s" "day 1"
has "$(cat "$ST/days")" "rubbish" "the file is only added to"
case_ "where you stopped: closed mid-lesson it opens there; opened from the other, it starts at its top"
clean; pty 118x20 '\r' '!wait 0.5' G q q >/dev/null; [[ $(cut -f1 "$ST/learn.at") == the-panel ]] && _ok || _no "not kept: $(cat "$ST/learn.at" 2>/dev/null)"
n=$(cut -f2 "$ST/learn.at"); ((n > 0)) && _ok || _no "the block: $n"
case_ "a window resized under a lesson: nothing over the edge"
clean; pty 118x40 '\r' '!wait 0.5' =40x12 '!wait 0.1' =9x5 '!wait 0.1' =118x40 >/dev/null; eq "$?" 0
case_ "the mouse on the day: a row clicked opens it; in a lesson nothing is taken from the terminal"
clean; s=$(pty 118x40 '\x1b[<0;20;5M' '!wait 0.5' '!dump' | screens); has "$s" "A program is a file"
case_ "the theme switches under it: foot's word that it did, nothing falls"
clean; pty 118x40 '\x1b[?997;2n' '\r' '!wait 0.5' '\x1b[?997;1n' >/dev/null; eq "$?" 0
case_ "a folder for the state that cannot be written: the page goes on, the stamp lasts the window"
clean; chmod 500 "$ST"; o=$(pty 118x40 '\r' '!wait 0.5' '\r' 'S' 'u' 'p' 'e' 'r' '+' 'U' '\r' '!wait 0.2' 2>&1); rc=$?; chmod 700 "$ST"; eq "$rc" 0 "${o: -200}"

case_ "as plain text: no escape, today's by itself, one by name, never its answer; a wrong name said"
clean; out=$(kawa-learn --text 2>&1); has "$out" "the panel — day 1 of 3"; lacks "$out" $'\e'; has "$out" "Which key opens"
lacks "$out" "the panel, on its first section  Super+U\$"
out=$(kawa-learn --text names --cols 60); has "$out" "a name for a value — day 2 of 3"; lacks "$out" 'print(name)'
eq "$(awk '{ if (length($0) > 60) print }' <<<"$out" | wc -l)" 0 "wider than asked"
out=$(kawa-learn --text nonsense 2>&1); eq "$?" 1; has "$out" "no lesson nonsense"
out=$(TERM=linux kawa-learn --text the-panel --cols 40); lacks "$out" "—"; lacks "$out" "│"

case_ "the lessons missing: said, with what puts them back; none yet: said; no terminal: said"
out=$(KAWA_LEARN=$TMP/none kawa-learn 2>&1); eq "$?" 1; has "$out" "fedokawaii repair"
out=$(KAWA_LEARN=$REPO/docs/lessons kawa-learn --place 2>&1); rc=$?; [[ $rc == 0 || $out == *"no lessons in"* ]] && _ok || _no "$out"
out=$(kawa-learn </dev/null 2>&1); eq "$?" 2; has "$out" "needs a terminal"
out=$(KAWA_TOOLKIT=$TMP/none kawa-learn --place 2>&1); eq "$?" 1; has "$out" "lessons.py cannot be read"
case_ "the checks' own rules: an answer whatever its case, spaces, quotes; a run stopped at its limit, its group gone, what it printed kept"
python3 -B -c '
import os, sys, tempfile, time
sys.path.insert(0, sys.argv[1] + "/lib")
import lessons as l
assert l.same_answer(" super + u.", "Super+U") and l.same_answer("`Super+U`", "Super+U") and not l.same_answer("", "x") and not l.same_answer("Super+I", "Super+U")
d = tempfile.mkdtemp(); os.mkdir(d + "/f"); l.RUN_SECONDS = 1
c = {"in": "f", "expect": "a\nb", "exit": 3}
got = l.run_check({**c, "run": "printf \"a\\nb\\n\"; echo oops >&2; exit 3"}, d); assert got["passed"] and got["err"] == "oops\n", got
got = l.run_check({**c, "run": "printf a; exit 3"}, d); assert not got["passed"] and got["status"] == 3, got
t = time.monotonic(); got = l.run_check({**c, "run": "echo a; sleep 60 & wait"}, d); assert got["status"] is None and got["out"] == "a\n" and time.monotonic() - t < 3, got
t = time.monotonic(); got = l.run_check({**c, "run": "exec >&- 2>&-; sleep 60"}, d); assert got["status"] is None and time.monotonic() - t < 3, got
got = l.run_check({**c, "run": "yes"}, d); assert got["status"] is None and not got["passed"]
assert l.run_check({**c, "in": "g", "run": "true"}, d)["status"] == "no folder"
' "$REPO" && _ok || _no "the checks"
case_ "the design's page: the stamp's inks are the mood's own"
has "$(cat "$REPO/bin/kawa-learn")" '"accent_hi" if hot else "accent" if done else "edge2"'
case_ "the cover: the book's first page, full bleed, the picture alone, and no words of the old cover's; the other pages untouched in number; the pane's small one its shape"
pdf=$REPO/docs/Fedokawaii-Learn.pdf
eq "$(identify -format '%wx%h' "$REPO/docs/learn/cover.jpg")" "1654x2340"; eq "$(identify -format '%wx%h' "$REPO/docs/learn/cover-thumb.png")" "336x475"
eq "$(pdftotext -f 1 -l 1 "$pdf" - | tr -d '[:space:]')" "" "page 1 has no words of its own"
eq "$(pdfimages -f 1 -l 1 -list "$pdf" | awk 'NR>2{print $4"x"$5}')" "1654x2340" "page 1 is that picture"
eq "$(pdfinfo "$pdf" | awk '/^Title/{$1="";print}' | sed 's/^ *//')" "Fedokawaii — learn"
[[ $(pdfinfo -f 1 -l 2 "$pdf" | awk '/^Page +[12] size/{print $4 "x" $6}' | sort -u | wc -l) == 1 ]] && _ok || _no "the cover's page is not the book's size"
grep -q "docs/learn/cover.jpg" "$REPO/docs/build/handbook.py" && _ok || _no "a rebuild of the book would lose the cover"
grep -q "FEDOKAWAII_COVER\|cover.*ink-ridges-night\|ink-ridges-night.*cover" "$REPO/docs/build/handbook.py" "$REPO/docs/build/README.md" && _no "the old cover is still named" || _ok
case_ "ten seconds of anything: keys, the mouse, sizes from one cell to the whole screen — no Traceback"
out=$(pty 118x40 '!fuzz' 10 "$RANDOM" 2>&1); r=$?; ((r == 0)) && _ok || _no "exit $r: ${out: -600}"

done_
