#!/usr/bin/env bash
# tests/content/test_learn.sh — the lessons (Super+U → learning → lessons): the book cut by
# tools/learn-pieces.py, nothing lost and nothing in an impossible order; the old Guide PDF gone; kawa-learn
# in a terminal of its own (learn_pty.py reads back what it draws): every lesson, key and window size,
# what is stamped kept across a kill and a bad file, the reader never falling over.
. "$(dirname "$0")/lib.sh"
sandbox
export KAWA_LEARN=$REPO/docs/learn PATH=$REPO/bin:$PATH
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
case_ "a table's columns: the short ones whole, only the long sentences wrap"
s=$(kawa-learn --text how-to-read --cols 88); has "$s" "Space (in the list)"; has "$s" "I — From zero"
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

# ── every lesson, every width ─────────────────────────────────────────────────────────────
case_ "every lesson laid out at 120, 88, 60, 40, 20 and 9 columns: nothing wider than the window, no word lost"
out=$(python3 -B -I "$C/learn_walk.py" "$REPO" 120 88 60 40 20 9 2>&1) && _ok || _no "$(tail -n 6 <<<"$out")"
case_ "as plain text: a lesson without a single escape, its place said; the next by itself; one by name; none by a wrong name"
out=$(kawa-learn --text 2>&1); has "$out" "how this works — lesson 1 of"; lacks "$out" $'\e'
out=$(kawa-learn --text py-arithmetic --cols 60); has "$out" "numbers and arithmetic — lesson"
eq "$(awk '{ if (length($0) > 60) print }' <<<"$out" | wc -l)" 0 "wider than asked"
out=$(kawa-learn --text nonsense 2>&1); eq "$?" 1; has "$out" "no lesson nonsense"
rc 2 kawa-learn --text a b; rc 2 kawa-learn --text --cols x
case_ "a text console: its signs in plain letters; on its terminal, in less, then a key: Enter stamps and goes on, q stops"
out=$(TERM=linux kawa-learn --text py-numbers-practice --cols 70); lacks "$out" "★"; lacks "$out" "—"; has "$out" "25.1 * Seconds"
rm -f "$ST/learn"; stub less 'cat >/dev/null'
out=$(python3 -I "$REPO/tests/lib/pty_run.py" --cols 80 --rows 24 --send 0.8 '\n' --send 1.6 'q\n' --timeout 6 -- kawa-learn --text 2>&1); has "$out" "how this works: enter stamps it"; has "$out" "twenty-six weeks: enter stamps it"
grep -q '^how-to-read' "$ST/learn" && _ok || _no "Enter did not stamp: $(cat "$ST/learn" 2>/dev/null)"; grep -q '^the-plan' "$ST/learn" && _no "q stamped" || _ok
rm -f "$ST/learn" "$(command -v less)"

# ── the window ────────────────────────────────────────────────────────────────────────────
case_ "the list: the first run, on the next lesson, the part's tabs, the place, nothing stamped"
out=$(pty 118x40 '!dump'); s=$(screens <<<"$out")
has "$s" "from zero"; has "$s" "0 of "; has "$s" "start here"; has "$s" "how this works"; has "$s" "lesson"; has "$s" "takes"
lacks "$s" "…"; lacks "$s" "Traceback"
case_ "§7, by the columns: a heading at column 0 of the content, its name from 3, a row's number from 4, its name from 9, the time at the list's end"
out=$(pty 118x40 '!dump' | screens); l=$(grep -E 'start here' <<<"$out"); r=$(grep -E 'twenty-six weeks' <<<"$out")
eq "${l%%start here*}" "$(printf '  %s  ' "${l:2:1}")" "the heading's name, 3 columns in from the icon: [$l]"
[[ $r =~ ^(\ +)2\ \ twenty-six ]] && eq "${#BASH_REMATCH[1]}" 8 "the number's last column: [$r]" || _no "the row: [$r]"
[[ $r =~ ([0-9]+\ min) ]] && _ok || _no "no time on the row: [$r]"
w=$(awk '{ i = index($0, "   lesson"); if (i) print i }' <<<"$out" | head -n 1); [[ -n $w ]] && _ok || _no "the pane's facts"
case_ "too narrow for a pane: the list alone, the same rows; and every size down to a single cell draws, and closes"
s=$(pty 60x20 '!dump' | screens); has "$s" "how this works"; lacks "$s" "takes"
for z in 1x1 2x2 5x3 10x4 20x5 30x6 46x8 99x10 100x12 240x70; do
  o=$(pty "$z" j '\t' j '\r' j '\r' '\x1b' '/' a '\x1b' 2>&1); rc=$?
  eq "$rc" 0 "$z: exit $rc: ${o: -300}"
done
case_ "a lesson: its heading, its place, the words; at the end the empty ring and the key; the stamp written; once more the next"
rm -f "$ST/learn" "$ST/learn.at"
out=$(pty 100x30 '\r' '!dump' G '!dump' '\r' '!dump' '\r' '!dump'); s=$(screens <<<"$out")
has "$s" "how this works"; has "$s" "1 of "; has "$s" "These lessons are the Learn book"
has "$s" "enter  stamp it"; has "$s" "enter  next: twenty-six weeks"; has "$s" "twenty-six weeks"
grep -q "^how-to-read"$'\t'"$(date +%F)$" "$ST/learn" && _ok || _no "not stamped: $(cat "$ST/learn" 2>/dev/null)"
has "$out" "--- sixels" "the seal is drawn"
[[ $(grep -oE '^--- sixels [0-9]+' <<<"$out" | grep -oE '[0-9]+') -ge 2 ]] && _ok || _no "no ring, no seal: $(grep -- '--- sixels' <<<"$out")"
case_ "the place Super+U's row reads: as far as the stamps go, the next, the time left"
IFS=$'\t' read -r d t nx m lf <"$ST/learn.place"; eq "$d" 1; ((t > 100)) && _ok || _no "total $t"; eq "$nx" "twenty-six weeks"; [[ $m =~ ^[0-9]+$ && $lf =~ ^[0-9]+$ ]] && _ok || _no "minutes [$m] [$lf]"
has "$(kawa-learn --place)" "1 of $t · next: twenty-six weeks"
case_ "Enter walks a whole lesson: a page at a time, the stamp at its end, never a stamp before it"
rm -f "$ST/learn" "$ST/learn.at"
pty 80x15 '\r' '\r' '\r' >/dev/null; [[ ! -s $ST/learn ]] && _ok || _no "stamped before its end: $(cat "$ST/learn")"
case_ "Space in the list stamps and takes off; the seal moves on; a stamp from another window is not lost"
rm -f "$ST/learn"; printf 'the-plan\t2026-11-02\n' >"$ST/learn"
s=$(pty 118x30 ' ' '!dump' | screens); grep -q '^how-to-read' "$ST/learn" && grep -q '^the-plan' "$ST/learn" && _ok || _no "$(cat "$ST/learn")"
pty 118x30 k k k ' ' >/dev/null
case_ "the solutions: an exercise lesson's key says so; none hidden behind it where there are none"
s=$(pty 100x30 --arg py-numbers-practice '!dump' s '!dump' | screens); has "$s" "s  solutions"; has "$s" "solution"; has "$s" "on"
s=$(pty 100x30 --arg how-to-read '!dump' | screens); lacks "$s" "s  solutions"
case_ "← and → walk the lessons, projects too; ↑ and ↓ a line; PgDn a page; g and G the ends; Esc the list again, on that lesson"
s=$(pty 100x30 --arg what-pieces '\x1b[C' '!dump' | screens); has "$s" "open it: five commands"
s=$(pty 100x30 --arg what-pieces '\x1b[D' '!dump' | screens); has "$s" "the words, all of them"
s=$(pty 118x30 --arg open-it '\x1b' '!dump' | screens); has "$s" "open it: five commands"; has "$s" "takes"
case_ "where you stopped: closed mid-lesson (a key, a kill, the window gone), it opens there; a lesson opened from another starts at its top"
rm -f "$ST/learn.at"
pty 100x20 --arg py-arithmetic G k k k '\x1b' >/dev/null; grep -q '^py-arithmetic'$'\t' "$ST/learn.at" && _ok || _no "$(cat "$ST/learn.at" 2>/dev/null)"
b=$(cut -f2 "$ST/learn.at"); ((b > 3)) && _ok || _no "block $b"
s=$(pty 100x20 --arg py-arithmetic '!dump' | screens); lacks "$s" "Python is a calculator first" "it opened at the top again"
rm -f "$ST/learn.at"; pty 100x20 --arg py-arithmetic G '!term' >/dev/null; grep -q '^py-arithmetic' "$ST/learn.at" && _ok || _no "SIGTERM: nothing kept"
rm -f "$ST/learn.at"; pty 100x20 --arg py-arithmetic G '!hup' >/dev/null; grep -q '^py-arithmetic' "$ST/learn.at" && _ok || _no "the window gone: nothing kept"
case_ "a window resized under a lesson: the same words at the top, nothing over the edge"
rm -f "$ST/learn.at"
out=$(pty 100x24 --arg py-arithmetic j j j j j j j j j j '!dump' =60x20 '!dump' =200x50 '!dump' 2>&1); eq "$?" 0 "$out"; lacks "$out" "past the edge"
case_ "/ finds in every lesson's words, the best first; Esc ends it, Enter opens it; what finds nothing says nothing wrong"
s=$(pty 118x30 / zoxide '!dump' | screens); has "$s" "moving and reading"; has "$s" "zoxide"
s=$(pty 118x30 / qqqqzzz '!dump' '\r' '!dump' '\x1b' '!dump' | screens); has "$s" "from zero"; lacks "$s" "Traceback"
s=$(pty 118x30 / py '\x7f' '\x7f' '!dump' | screens); has "$s" "find in the lessons"
case_ "the mouse in the list: the pointer's row lit, one click opens it, the wheel moves; a tab clicked; in a lesson nothing is taken from the terminal's selection"
s=$(pty 118x30 '\x1b[<35;20;7M' '!dump' '\x1b[<0;20;7M' '!dump' | screens); has "$s" "lesson"
out=$(pty 118x30 '\x1b[<64;20;7M' '\x1b[<65;20;7M' '\x1b[<0;18;2M' '\x1b[<0;18;2m' '!dump' | screens); has "$out" "the desktop"
grep -c '1000;1003;1006l' "$REPO/bin/kawa-learn" >/dev/null && _ok || _no "a page must take the mouse off"
s=$(pty 118x30 '\x1b[<0;100;8M' '\x1b[<0;100;8m' '!dump' | screens); has "$s" "takes" "a click on the pane opened a lesson"
case_ "b: the whole book, on its own"
stub setsid
pty 118x30 b >/dev/null; called "^setsid -f zathura $KAWA_LEARN/../Fedokawaii-Learn.pdf$|^setsid -f zathura .*Fedokawaii-Learn.pdf$"
case_ "a state that cannot be read: its bad lines passed over, the good ones kept; a stamp for a lesson gone stays for the day it is back"
mkdir -p "$ST"; printf 'how-to-read\t2026-11-01\ngarbage line\n\xff\xfe\nthe-plan\tnot-a-date\nold-lesson\t2026-01-01\n' >"$ST/learn"; printf 'not a place' >"$ST/learn.at"
s=$(pty 118x30 '!dump' | screens); has "$s" "1 of " "the good line counted"; has "$s" "twenty-six weeks"
pty 118x30 k k ' ' >/dev/null; grep -q '^old-lesson' "$ST/learn" && _ok || _no "the stamp of a lesson gone was lost"
case_ "a state folder that cannot be written: the page goes on, what cannot be kept is not kept"
rm -rf "$ST"; : >"$XDG_STATE_HOME/x"; (XDG_STATE_HOME=$XDG_STATE_HOME/x pty 100x20 '\r' G '\r' '!dump' >"$TMP/o" 2>&1); eq "$?" 0 "$(tail -n 5 "$TMP/o")"; mkdir -p "$ST"
case_ "the lessons missing: said, with what puts them back; no terminal: said"
out=$(KAWA_LEARN=$TMP/nowhere kawa-learn 2>&1); eq "$?" 1; has "$out" "fedokawaii repair puts them back"
out=$(kawa-learn </dev/null 2>&1 | cat); has "$out" "needs a terminal"
rc 2 kawa-learn nonsense extra
case_ "every lesson stamped: no next, no seal in the list, every key still works; the place says so"
awk -F'\t' '$1=="L"{print $2"\t2026-11-01"}' "$KAWA_LEARN/index.tsv" >"$ST/learn"
s=$(pty 118x30 '!dump' '\r' G '\r' '!dump' | screens); lacks "$s" "Traceback"; has "$(kawa-learn --place)" "of"; lacks "$(kawa-learn --place)" "next"
out=$(kawa-learn --text); has "$out" "every lesson is stamped"
rm -f "$ST/learn"
case_ "a lesson's file gone: the window says so in its place, nothing falls over"
rm -rf "$TMP/l"; cp -r "$KAWA_LEARN" "$TMP/l"; rm -f "$TMP/l"/pieces/001-*; s=$(KAWA_LEARN=$TMP/l pty 100x20 '\r' '!dump' | screens); has "$s" "cannot be read"
case_ "the theme switches under it: foot's word that it did, the seal drawn again"
out=$(pty 118x30 --arg how-to-read G '\r' '\x1b[?997;2n' '!dump' 2>&1); eq "$?" 0 "$out"
case_ "words: lower case in the headings, proper names kept; the code's own \"...\" stays, nothing is dotted by the window"
has "$(cat "$KAWA_LEARN"/pieces/*-py-two-ways.md)" "## 25.1 two ways to run Python"
has "$(grep -h '^## ' "$KAWA_LEARN"/pieces/*-py-numbers-mistakes.md)" "common mistakes"
has "$(awk -F'\t' '$2=="rs-vec"' "$KAWA_LEARN/index.tsv")" "Vec: a growing list"
grep -v '^#' "$REPO/bin/kawa-learn" | grep -q '…\|\.\.\.' && _no "a dotted word in the program" || _ok
case_ "every lesson opens in the window: n from the first to the last, a kill-free walk through all of them, in order"
n=$(awk -F'\t' '$1=="L"{c++} END{print c}' "$KAWA_LEARN/index.tsv"); last=$(awk -F'\t' '$1=="L"{t=$7} END{print t}' "$KAWA_LEARN/index.tsv")
s=$(pty 118x40 --arg how-to-read '!walk' n "$n" '!dump' 2>&1 | screens); has "$s" "$last"; lacks "$s" "cannot be read"
case_ "the stamp's inks are the mood's own: the ring edge2, the thump accent_hi, the seal accent; a wrong or missing theme draws no wrong colour"
percent() { python3 -I -c 'import sys; h=sys.argv[1]; print(";".join(str(round(int(h[i:i+2],16)*100/255)) for i in (0,2,4)))' "$1"; }
mkdir -p "$XDG_CONFIG_HOME/fedokawaii/current"; printf 'accent=eb5324\naccent_hi=f47b58\nedge2=3c2f22\n' >"$XDG_CONFIG_HOME/fedokawaii/current/panel.conf"
rm -f "$ST/learn"; out=$(pty 100x20 --arg how-to-read G '\r' '!wait' 0.2 '!dump' 2>&1); i=$(grep -- '--- sixels' <<<"$out")
has "$i" "$(percent 3c2f22)" "the ring: $i"; has "$i" "$(percent f47b58)" "the thump: $i"; has "$i" "$(percent eb5324)" "the seal: $i"
rm -f "$ST/learn"; rm -rf "$XDG_CONFIG_HOME/fedokawaii/current"
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
