#!/usr/bin/env bash
# tests/content/test_lessons.sh — the daily lessons' format (lib/lessons.py): a day is one lesson of each
# part, 25 to 30 minutes; a lesson one idea, one exercise, one check; anything else is refused, with its
# place; the steps of an answer really make its check pass; the record is dated, and only that.
. "$(dirname "$0")/lib.sh"
sandbox
L=$TMP/lessons; mkdir -p "$L"
lessons() { python3 -B -I "$REPO/lib/lessons.py" "$@"; }

one_ask() {   # one_ask ID MINUTES
  cat >"$L/$1.md" <<ASK_LESSON_END
---
id: $1
title: the panel
part: 1
minutes: $2
---
## idea
The panel is one key away.

## exercise
Open it, close it.

## check
\`\`\`check
ask: Which key opens the panel?
answer: Super+U
proof: grep -q panel config.h
\`\`\`
ASK_LESSON_END
}
one_run() {   # one_run ID MINUTES
  cat >"$L/$1.md" <<RUN_LESSON_END
---
id: $1
title: one line on the screen
part: 2
minutes: $2
needs: [panel]
---
## idea
A program is a file of steps. Here is one:

\`\`\`python
# not a heading: a fence's lines never are
print("hello")
\`\`\`

## exercise
Write it in ~/dojo/hello.

## check
\`\`\`check
run: python3 hello.py | tr a-z A-Z; echo; exit 3
in: hello
expect: HELLO
expect:
exit: 3
\`\`\`

## answer
It is one line:

\`\`\`file hello.py
print("hello")
\`\`\`
\`\`\`do
chmod +x hello.py
\`\`\`
RUN_LESSON_END
}
fresh() {
  rm -f "$L"/*; one_ask panel 10; one_run first-print 15
  printf '# the order\n1\tpanel\tfirst-print\n' >"$L/days.tsv"
}
refused() {   # refused WORDS — the folder as it stands is refused, in those words
  local out; out=$(lessons "$L" 2>&1) && _no "accepted: $out" || has "$out" "$1"
}
swap() { python3 -B -I -c 'import sys
p, a, b = sys.argv[1:]; t = open(p).read(); assert a in t, a; open(p, "w").write(t.replace(a, b))' "$@"; }

case_ "a day of one ask and one run is read, and counted"
fresh; eq "$(lessons "$L")" "1 days, 2 lessons"

case_ "every part of a lesson comes through as written"
fresh
out=$(python3 -B -c 'import json, sys; sys.path.insert(0, sys.argv[1] + "/lib"); import lessons
c = lessons.load(sys.argv[2]); r = c["lessons"]["first-print"]; a = c["lessons"]["panel"]
print(json.dumps([c["days"], r["title"], r["minutes"], r["needs"], r["check"], [s.get("file") or s["do"] for s in r["steps"]],
  "not a heading" in r["idea"], r["answer"].startswith("It is one line"), a["check"], a["steps"]]))' "$REPO" "$L")
eq "$out" '[[[1, "panel", "first-print"]], "one line on the screen", 15, ["panel"], {"kind": "run", "run": "python3 hello.py | tr a-z A-Z; echo; exit 3", "in": "hello", "expect": "HELLO\n", "exit": 3}, ["hello.py", "chmod +x hello.py"], true, true, {"kind": "ask", "ask": "Which key opens the panel?", "answer": "Super+U", "proof": "grep -q panel config.h"}, []]'

case_ "an answer's steps make its check pass, and the check fails before them"
fresh
out=$(python3 -B -c 'import os, subprocess, sys; sys.path.insert(0, sys.argv[1] + "/lib"); import lessons
r = lessons.load(sys.argv[2])["lessons"]["first-print"]; d = sys.argv[3]; os.makedirs(d); c = r["check"]
def check():
    p = subprocess.run(["bash", "-c", c["run"]], cwd=d, capture_output=True, text=True)
    return p.returncode == c["exit"] and p.stdout.rstrip("\n") == c["expect"].rstrip("\n")
before = check()
for s in r["steps"]:
    if "file" in s:
        open(os.path.join(d, s["file"]), "w").write(s["text"])
    else:
        subprocess.run(["bash", "-c", s["do"]], cwd=d, check=True)
print(before, check())' "$REPO" "$L" "$TMP/dojo/hello")
eq "$out" "False True"

case_ "a lesson that is not one idea, one exercise, one check is refused"
fresh; swap "$L/panel.md" "## exercise" "## exercises"; refused "panel.md:10"
fresh; swap "$L/panel.md" "## idea" "## exercise"; refused "the next heading can only be ## idea"
fresh; swap "$L/panel.md" "Open it, close it." "### more"; refused "panel.md:"
fresh; swap "$L/panel.md" "---
## idea" "---
stray
## idea"; refused "words before ## idea"
fresh; python3 -B -I -c 'import sys; open(sys.argv[1], "a").write("\n```check\nask: b\nanswer: c\nproof: d\n```\n")' "$L/panel.md"; refused "one fenced check block"
fresh; swap "$L/panel.md" "The panel is one key away." "$(printf 'word %.0s' {1..201})"; refused "201 words"
fresh; swap "$L/panel.md" "Open it, close it." ""; refused "## exercise is empty"
fresh; python3 -B -I -c 'import sys; open(sys.argv[1], "a").write("```python\nopen\n")' "$L/panel.md"; refused "a fence that does not end"

case_ "the front matter is held: id, title, part, minutes, needs"
fresh; swap "$L/panel.md" "id: panel" "id: Panel"; refused "a bad id"
fresh; swap "$L/panel.md" "title: the panel" "title: $(printf 'x%.0s' {1..47})"; refused "a title over 46"
fresh; swap "$L/panel.md" "part: 1" "part: 3"; refused "part is 1 or 2"
fresh; swap "$L/panel.md" "minutes: 10" "minutes: 4"; refused "minutes are 5 to 25"
fresh; swap "$L/panel.md" "minutes: 10" "minutes: ten"; refused "minutes are 5 to 25"
fresh; swap "$L/panel.md" "minutes: 10" "minutes: 10
level: 3"; refused "not a front matter line"
fresh; swap "$L/panel.md" "---
id:" "id:"; refused "no front matter"
fresh; swap "$L/panel.md" "id: panel" "id: other"; refused "the file's name is the id"
fresh; swap "$L/panel.md" "the panel" "the panel…"; refused "an ellipsis"

case_ "a check is one kind, whole"
fresh; swap "$L/panel.md" "proof: grep -q panel config.h" "in: x"; refused "an ask check with in"
fresh; swap "$L/panel.md" "proof: grep -q panel config.h
" ""; refused "says ask, answer and proof"
fresh; swap "$L/panel.md" "ask: Which" "tell: Which"; refused "not a line of a check"
fresh; swap "$L/panel.md" "answer: Super+U" "answer: Super+U
answer: Super+V"; refused "answer twice"
fresh; swap "$L/first-print.md" "in: hello
" ""; refused "says run, in"
fresh; swap "$L/first-print.md" "in: hello" "in: ../hello"; refused "says run, in"
fresh; swap "$L/first-print.md" "expect: HELLO
expect:
" ""; refused "says run, in"
fresh; swap "$L/first-print.md" "exit: 3" "exit: no"; refused "exit is a number"
fresh; python3 -B -I -c 'import sys; p = sys.argv[1]; t = open(p).read(); open(p, "w").write(t[:t.index("## answer")])' "$L/first-print.md"; refused "needs its ## answer"
fresh; printf '\n## answer\nNo.\n' >>"$L/panel.md"; refused "no ## answer"

case_ "an answer stays inside its folder, and has a step"
fresh; swap "$L/first-print.md" "file hello.py" "file ../hello.py"; refused "inside the folder"
fresh; swap "$L/first-print.md" "file hello.py" "file /tmp/hello.py"; refused "inside the folder"
fresh; swap "$L/first-print.md" "file hello.py" "python"; refused "inside the folder"
fresh; python3 -B -I -c 'import sys; p = sys.argv[1]; t = open(p).read(); open(p, "w").write(t[:t.index("It is one line")] + "Words.\n")' "$L/first-print.md"; refused "has no step"

case_ "the days are held: their order, parts, length, every lesson once, nothing before it is taught"
fresh; printf '2\tpanel\tfirst-print\n' >"$L/days.tsv"; refused "day 2 where day 1 comes"
fresh; printf '1\tfirst-print\tpanel\n' >"$L/days.tsv"; refused "in part 1's place"
fresh; printf '1\tpanel\n' >"$L/days.tsv"; refused "not DAY"
fresh; printf '1\tpanel\tnothing\n' >"$L/days.tsv"; refused "no lesson nothing"
fresh; one_ask more 10; refused "more is in no day"
fresh; printf '1\tpanel\tfirst-print\n2\tpanel\tfirst-print\n' >"$L/days.tsv"; refused "is in two days"
fresh; swap "$L/first-print.md" "minutes: 15" "minutes: 21"; refused "31 minutes"
fresh; swap "$L/first-print.md" "minutes: 15" "minutes: 14"; refused "24 minutes"
fresh; swap "$L/first-print.md" "needs: [panel]" "needs: [later]"; one_ask later 10
printf '1\tpanel\tfirst-print\n2\tlater\tfirst-print\n' >"$L/days.tsv"; refused "needs later"
fresh; rm "$L/days.tsv"; refused "days.tsv"
rc 1 lessons "$TMP/no-such-folder"

case_ "the record: dated lines, the first date kept, what cannot be read passed over, an old id uncounted"
out=$(python3 -B -c 'import sys; sys.path.insert(0, sys.argv[1] + "/lib"); import lessons
p = sys.argv[2] + "/state/days"; lessons.add_record(p, "a", "2026-11-08"); lessons.add_record(p, "b", "2026-11-09")
open(p, "a").write("rubbish\n2026-11-09\tBAD ID\nnot-a-date\tc\n2026-11-01\ta\n\xff\n")
d = lessons.read_record(p); print(sorted(d.items()), lessons.history(d), lessons.read_record(p + ".none"))' "$REPO" "$TMP")
eq "$out" "[('a', '2026-11-01'), ('b', '2026-11-09')] [('2026-11-01', ['a']), ('2026-11-09', ['b'])] {}"

case_ "today's pair: the first unfinished; one finished today stays shown and the next waits; a missed day costs nothing"
out=$(python3 -B -c 'import sys; sys.path.insert(0, sys.argv[1] + "/lib"); import lessons
c = {"days": [(1, "a", "b"), (2, "c", "d"), (3, "e", "f")], "lessons": {}}
T = "2026-11-20"; Y = "2026-11-10"
n = lambda d: d[0] if d else None
for done in ({}, {"a": T}, {"a": Y, "b": Y}, {"a": Y, "b": T}, {"a": Y, "b": Y, "c": T, "d": T},
             {"a": Y, "b": Y, "c": Y, "d": Y, "e": Y, "f": Y}, {"a": T, "b": T, "c": T, "d": T, "e": T, "f": T}, {"z": T}):
    s = lessons.place(c, done, T); print(n(s[0]), n(s[1]), s[2], end="; ")' "$REPO")
eq "$out" "1 2 0; 1 2 0; 2 3 1; 1 2 1; 2 3 2; None None 3; 3 None 3; 1 2 0; "

done_
