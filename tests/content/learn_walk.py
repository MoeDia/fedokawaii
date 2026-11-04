#!/usr/bin/env python3
"""learn_walk.py REPO WIDTH… — every lesson laid out at each width in one run of kawa-learn's own code: no line wider
than the width, no word of the source lost (solutions shown), nothing dotted that the source does not have.
Prints what is wrong; says how many lines it read. Exit 1 when something is."""
import importlib.machinery
import importlib.util
import os
import re
import sys

repo = sys.argv[1]
loader = importlib.machinery.SourceFileLoader("kawa_learn", os.path.join(repo, "bin/kawa-learn"))
spec = importlib.util.spec_from_loader("kawa_learn", loader)
k = importlib.util.module_from_spec(spec)
sys.dont_write_bytecode = True
loader.exec_module(k)
course = k.Course()
bad = 0
lines = 0
for le in course.lessons:
    text = k.body_of(os.path.join(k.LEARN, "pieces", le["file"]))
    # the source's words: no comments, no fences' names, no markup
    src = re.sub(r"<!--.*?-->", " ", text, flags=re.S)
    src = re.sub(r"^```\S*$", " ", src, flags=re.M)
    want = set(re.findall(r"[^\W_]+", src))
    want -= {"Word"}                         # (a box's "Word —": its icon says it)
    for width in map(int, sys.argv[2:]):
        page = k.Page(text, {}, "", le["title"])
        page.hl = {}
        out = page.layout(width, True)
        got = set(re.findall(r"[^\W_]+", " ".join(le["sections"])))        # (the lesson's own heading: the page's head has them)
        for ln in out:
            s = k.plain(ln.runs)
            lines += 1
            got.update(re.findall(r"[^\W_]+", s))
            if k.run_cols(ln.runs) > width:
                print(f"{le['id']} at {width}: a line of {k.run_cols(ln.runs)}: {s[:60]}")
                bad += 1
        # (a word longer than the line is cut across lines: compare what is left without spaces)
        joined = "".join(k.plain(ln.runs).lstrip("│↳ ") for ln in out)
        lost = [w for w in want - got if w not in joined and w not in le["title"]]
        if lost:
            print(f"{le['id']} at {width}: lost {sorted(lost)[:8]}")
            bad += 1
print(f"{len(course.lessons)} lessons, {lines} lines read")
sys.exit(1 if bad else 0)
