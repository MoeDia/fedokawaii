#!/usr/bin/env python3
"""tools/learn-pieces.py — the Learn book cut into lessons: docs/fedokawaii-learn.md, by the order
docs/learn/syllabus.txt writes, into docs/learn/pieces/NNN-ID.md (front matter: id, title, part,
chapter, minutes, needs, optional) and docs/learn/index.tsv, what kawa-learn reads at its start.

    python3 tools/learn-pieces.py           writes them
    python3 tools/learn-pieces.py --check   writes nothing: fails unless they are what it would
                                            write (tests/content/test_learn.sh)
    python3 tools/learn-pieces.py --refs    lists what a lesson's text calls "chapter N" where
                                            that chapter comes later in the order: to read, not a rule

It stops, saying why, on: a section of the book in no lesson or in two, an exercise or a solution
that belongs nowhere, a chapter's sections out of order, an ID twice, a lesson that needs one that
comes later (the order is then no order: nothing can be a cycle). What is in the book for one of
the two forms only: <!-- book --> … <!-- /book --> (not in the lessons), <!-- lesson … --> (the
lessons only; a comment to the PDF).
Exit 0 · 1 what it stopped on (said) · 2 misuse."""
import os
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
BOOK = REPO / "docs/fedokawaii-learn.md"
LEARN = REPO / "docs/learn"
STAR_MINUTES = {1: 1, 2: 5, 3: 30, 4: 120}      # the book's own table ("How to read this book"); ★★★★: an evening
EXERCISE = re.compile(r"^\*\*(\d+\.\d+) (★+)")
CHAPTER = re.compile(r"^# (\d+|[A-D])\. (.*)$")
PART = re.compile(r"^# Part ([IVX]+) — (.*)$")
# what keeps its capital when a heading's first letter goes lower case (docs/design-system.md §2: words
# are lower case, proper names keep theirs)
PROPER = {"Python", "Rust", "NumPy", "PyTorch", "GitHub", "Claude", "Fedora", "Vec", "String", "HashMap",
          "BTreeMap", "HashSet", "VecDeque", "Option", "Result", "True", "False", "PyPI", "PyO3"}


def die(msg):
    print(f"learn-pieces: {msg}", file=sys.stderr)
    sys.exit(1)


def lower_first(s):
    word = re.match(r"[^\s:,;.]*", s)[0]
    return s if word in PROPER or word[1:2].isupper() else s[:1].lower() + s[1:]


# a table's row that differs between the two forms (a comment inside a table would break it in the PDF):
# its start → what the lessons have instead, or nothing
LESSON_ROWS = {
    "| Appendices |": None,
    "| learning | lessons |": "| learning | lessons | what you are reading: the book, in pieces | every day |",
}


def for_lessons(text):
    """the book as the lessons read it: its book-only stretches gone, its lesson-only ones open"""
    text = re.sub(r"<!-- book -->\n.*?<!-- /book -->\n?", "", text, flags=re.S)
    text = re.sub(r"<!-- lesson\n(.*?)\n-->", r"\1", text, flags=re.S)
    out = []
    for line in text.split("\n"):
        for start, instead in LESSON_ROWS.items():
            if line.startswith(start):
                line = instead
                break
        if line is not None:
            out.append(line)
    return "\n".join(out)


class Section:
    """one stretch of the book, and whether a lesson has taken it"""

    def __init__(self, key, title):
        self.key, self.title, self.lines, self.taken = key, title, [], None

    def text(self):
        return "\n".join(self.lines).strip("\n")


def read_book():
    """the book → its sections by key ("how", "PI", "25.0", "25.3", "25.x", "25.y", "66.0/2"), the
    solutions by exercise, each chapter's "You need" (the numbers named) and the rest of that line"""
    src = BOOK.read_text(encoding="utf-8")
    body = re.match(r"^---\n.*?\n---\n(.*)$", src, re.S)[1]
    sections, solutions, solved, needs = {}, {}, {}, {}
    fence = False
    cur = chap = None
    in_ex = in_sol = False
    ex_star = 0

    def start(key, title=""):
        nonlocal cur
        if key in sections:
            die(f"the book has {key} twice")
        cur = sections[key] = Section(key, title)

    for line in for_lessons(body).split("\n"):
        if line.startswith("```"):
            fence = not fence
        if not fence:
            m, p = CHAPTER.match(line), PART.match(line)
            if p:
                start("P" + p[1], p[2])
                chap, in_ex, in_sol = None, False, False
                continue
            if m and m[1] in "BCD":
                chap, in_sol, in_ex, cur, solved = None, True, False, None, {}
                continue
            if m:
                chap, in_ex, in_sol = m[1], False, False
                start(f"{chap}.0" if chap != "A" else "A", m[2])
                continue
            if line == "# How to read this book":
                start("how", "how this works")
                continue
            if line.startswith("# "):
                die(f"a heading of the book this script does not know: {line}")
            if in_sol:
                if line.startswith("## "):
                    solved = {}
                    continue
                e = EXERCISE.match(line)
                if e:
                    if e[1] in solutions:
                        die(f"exercise {e[1]} has two solutions")
                    solved = solutions[e[1]] = {"lines": []}
                    continue
                if solved:
                    solved["lines"].append(line)
                continue
            s = re.match(r"^## (\d+)\.(\d+) (.*)$", line)
            if s and chap:
                if s[1] != chap:
                    die(f"section {s[1]}.{s[2]} sits in chapter {chap}")
                start(f"{chap}.{s[2]}", s[3])
                cur.lines.append(f"## {s[1]}.{s[2]} {lower_first(s[3])}")
                continue
            if line.startswith("### ") and line != "### Exercises":
                line = "### " + lower_first(line[4:])
            if line == "### Exercises" and chap:
                in_ex, ex_star = True, 0
                start(f"{chap}.x")
                sections[f"{chap}.y"] = Section(f"{chap}.y", "")
                continue
            if line.strip() == "<!-- cut -->" and cur:
                base = cur.key.split("/")[0]
                if "/" not in cur.key:
                    sections.pop(cur.key)
                    first = sections[base + "/1"] = Section(base + "/1", cur.title)
                    first.lines = cur.lines
                n = int(cur.key.split("/")[1]) + 1 if "/" in cur.key else 2
                start(f"{base}/{n}", cur.title)
                continue
            e = EXERCISE.match(line)
            if in_ex and e:
                if not e[1].startswith(chap + "."):
                    die(f"exercise {e[1]} sits in chapter {chap}")
                ex_star = len(e[2])
                cur = sections[f"{chap}.{'x' if ex_star <= 2 else 'y'}"]
                cur.exercises = getattr(cur, "exercises", []) + [(e[1], ex_star)]
            if chap and line.startswith("> **You need:**"):
                first, _, rest = line[len("> **You need:**"):].strip().partition(". ")
                nums = []
                for frag in re.findall(r"chapters?\s+((?:\d+(?:–\d+)?(?:,\s*|\s+and\s+)?)+)", first):
                    for a in re.findall(r"\d+(?:–\d+)?", frag):
                        nums.append(a.split("–")[-1])
                needs[chap] = nums
                if rest:
                    cur.lines.append("> " + rest)
                elif cur.lines and cur.lines[-1].strip() == ">":
                    cur.lines.pop()         # (the box's empty line before it: nothing of it stays)
                continue
        if in_sol and fence and solved:
            solved["lines"].append(line)
        elif cur:
            cur.lines.append(line)
    if fence:
        die("the book ends inside a code block")
    return sections, solutions, needs


def with_solutions(sec, solutions, used):
    """an exercise section's text, each exercise followed by its solution in a comment pair (kawa-learn
    shows them on its key; none shown, the page is what the book's exercises are)"""
    out, cur = [], None

    def close():
        nonlocal cur
        if cur:
            sol = "\n".join(solutions[cur]["lines"]).strip("\n")
            while out and not out[-1].strip():
                out.pop()
            out.extend(["", f"<!-- solution {cur} -->", sol, "<!-- /solution -->", ""])
            used.add(cur)
        cur = None

    for line in sec.lines:
        e = EXERCISE.match(line)
        if e:
            close()
            cur = e[1] if e[1] in solutions else None
        out.append(line)
    close()
    return "\n".join(out).strip("\n")


def words_minutes(text):
    """reading at 150 words a minute (a lesson is tried as it is read); a line of code 8 s: typed or read, tried"""
    words = code = 0
    fence = False
    for line in text.split("\n"):
        if line.startswith("```"):
            fence = not fence
        elif fence:
            code += 1
        else:
            words += len(line.split())
    return words / 150 + code * 8 / 60


def read_syllabus():
    parts, chapters, lessons = [], {}, []
    part = chap = None
    n = 0
    for raw in (LEARN / "syllabus.txt").read_text(encoding="utf-8").split("\n"):
        n += 1
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        f = [x.strip() for x in line.split("|")]
        head = f[0].split()
        if head[0] == "part":
            part = {"id": head[1], "name": f[1], "icon": f[2]}
            parts.append(part)
        elif head[0] == "chapter":
            chap = {"n": head[1], "id": head[2], "name": f[1], "icon": f[2], "part": part["id"], "needs": None}
            if len(f) > 3:
                if f[3].split()[0] != "needs":
                    die(f"syllabus, line {n}: {f[3]}")
                chap["needs"] = f[3].split()[1:]
            chapters[chap["n"]] = chap
        elif head == ["x"] or head == ["y"]:
            optional = head[0] == "y"
            lessons.append({"id": f"{chap['id']}-{'projects' if optional else 'practice'}",
                            "title": "projects" if optional else "practice", "what": head, "chapter": chap["n"],
                            "part": part["id"], "minutes": None, "optional": optional})
        elif len(f) >= 3:
            over = next((x[1:] for x in f[3:] if x.startswith("~")), None)
            lessons.append({"id": f[0], "title": f[1], "what": f[2].split(), "chapter": chap["n"], "part": part["id"],
                            "minutes": int(over) if over else None, "optional": "?" in f[3:]})
        else:
            die(f"syllabus, line {n}: {raw}")
    return parts, chapters, lessons


def key_of(what, chap):
    if what == "how" or what == "A" or re.match(r"^P[IVX]+$", what) or "." in what:
        return what
    return f"{chap}.{what}"


def compose():
    """→ the lessons with their text, the parts and the chapters; every rule checked on the way"""
    sections, solutions, book_needs = read_book()
    parts, chapters, lessons = read_syllabus()
    seen, used = set(), set()
    for le in lessons:
        if le["id"] in seen or not re.match(r"^[a-z0-9][a-z0-9-]*$", le["id"]):
            die(f"lesson ID {le['id']}: twice, or not plain")
        seen.add(le["id"])
        texts, minutes, titles, last = [], 0.0, [], -1
        for what in le["what"]:
            key = key_of(what, le["chapter"])
            sec = sections.get(key)
            if sec is None:
                die(f"{le['id']}: the book has no section {key}")
            if sec.taken:
                die(f"{le['id']}: section {key} is in {sec.taken} already")
            sec.taken = le["id"]
            if key.startswith(le["chapter"] + ".") and what.split("/")[0].isdigit():
                at = int(what.split("/")[0])
                if at < last:
                    die(f"{le['id']}: its sections out of the book's order")
                last = at
            if what in ("x", "y"):
                text = with_solutions(sec, solutions, used)
                minutes += sum(STAR_MINUTES[s] for _, s in getattr(sec, "exercises", []))
                if len(le["what"]) > 1 and text:          # (beside what it practises: its heading)
                    text = "### exercises\n\n" + text
            else:
                text = sec.text()
                minutes += words_minutes(text)
                if sec.title and what.isdigit() and what != "0":
                    titles.append(f"{le['chapter']}.{what} {lower_first(sec.title)}")
            texts.append(text)
        le["text"] = "\n\n".join(t for t in texts if t)
        if not le["text"]:
            die(f"{le['id']}: nothing in it (a chapter with no such exercises: take its line out)")
        le["sections"] = titles
        le["minutes"] = le["minutes"] or max(1, round(minutes))
    for key, sec in sections.items():
        if not sec.taken and sec.text():
            die(f"section {key} of the book is in no lesson: add it to docs/learn/syllabus.txt")
    for num in solutions:
        if num not in used:
            die(f"the solution of {num} belongs to no exercise of a lesson")
    # needs: within a chapter the required lesson before it, a chapter's first what the book's "You
    # need" or the syllabus names (the last required lesson of each); projects their chapter's practice
    last_of, prev = {}, {}
    order = {le["id"]: i for i, le in enumerate(lessons)}
    for le in lessons:
        ch = le["chapter"]
        if le["optional"]:
            le["needs"] = [prev[ch]] if ch in prev else []
            continue
        if ch in prev:
            le["needs"] = [prev[ch]]
        else:
            named = chapters[ch]["needs"]
            named = book_needs.get(ch, []) if named is None else named
            le["needs"] = []
            for c in named:
                if c not in last_of:
                    die(f"{le['id']}: chapter {ch} needs chapter {c}, which comes later in the syllabus (or has no lesson)")
                if last_of[c] not in le["needs"]:
                    le["needs"].append(last_of[c])
        prev[ch] = last_of[ch] = le["id"]
    for le in lessons:
        for need in le["needs"]:
            if order[need] >= order[le["id"]]:
                die(f"{le['id']} needs {need}, which comes after it")
    return parts, chapters, lessons


def front(le):
    needs = ", ".join(le["needs"])
    return (f"---\nid: {le['id']}\ntitle: {le['title']}\npart: {le['part']}\nchapter: {le['chapter']}\n"
            f"minutes: {le['minutes']}\nneeds: [{needs}]\noptional: {'yes' if le['optional'] else 'no'}\n---\n\n")


def outputs():
    """{path relative to docs/learn: what it holds}"""
    parts, chapters, lessons = compose()
    out, index, i, n = {}, [], 0, 0
    for p in parts:
        index.append(f"P\t{p['id']}\t{p['name']}\t{p['icon']}")
    for c in chapters.values():
        index.append(f"C\t{c['n']}\t{c['part']}\t{c['name']}\t{c['icon']}")
    for le in lessons:
        i += 1
        name = f"{i:03d}-{le['id']}.md"
        out[f"pieces/{name}"] = front(le) + le["text"] + "\n"
        n += 0 if le["optional"] else 1
        place = 0 if le["optional"] else n
        index.append("\t".join(("L", le["id"], name, str(place), le["part"], le["chapter"], le["title"],
                                str(le["minutes"]), " ".join(le["needs"]), "|".join(le["sections"]))))
    out["index.tsv"] = "\n".join(index) + "\n"
    return out


def refs():
    parts, chapters, lessons = compose()
    pos = {}
    for i, le in enumerate(lessons):
        pos.setdefault(le["chapter"], i)
    for i, le in enumerate(lessons):
        for m in re.finditer(r"[Cc]hapters? (\d+)", le["text"]):
            if m[1] in pos and pos[m[1]] > i:
                print(f"{le['id']}: chapter {m[1]} comes later — {le['text'][max(0, m.start() - 50):m.end() + 30]!r}")


def main():
    arg = sys.argv[1] if len(sys.argv) > 1 else ""
    if arg in ("-h", "--help"):
        print(__doc__)
        return 0
    if arg == "--refs":
        refs()
        return 0
    if arg not in ("", "--check"):
        print(__doc__, file=sys.stderr)
        return 2
    want = outputs()
    have = {}
    pieces = LEARN / "pieces"
    if pieces.is_dir():
        for f in pieces.iterdir():
            have[f"pieces/{f.name}"] = f.read_text(encoding="utf-8")
    if (LEARN / "index.tsv").exists():
        have["index.tsv"] = (LEARN / "index.tsv").read_text(encoding="utf-8")
    if arg == "--check":
        diff = sorted(k for k in want.keys() | have.keys() if want.get(k) != have.get(k))
        if diff:
            die(f"{len(diff)} file(s) not as the book and the syllabus make them, the first: {diff[0]} — run tools/learn-pieces.py")
        return 0
    pieces.mkdir(parents=True, exist_ok=True)
    for k in have.keys() - want.keys():
        os.unlink(LEARN / k)
    for k, v in want.items():
        if have.get(k) != v:
            (LEARN / k).write_text(v, encoding="utf-8")
    lessons = [k for k in want if k.startswith("pieces/")]
    print(f"{len(lessons)} lessons → docs/learn/pieces, docs/learn/index.tsv")
    return 0


if __name__ == "__main__":
    sys.exit(main())
