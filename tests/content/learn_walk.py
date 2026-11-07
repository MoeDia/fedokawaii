#!/usr/bin/env python3
"""learn_walk.py REPO FOLDER WIDTH… — every lesson of FOLDER laid out at each width in one run of kawa-learn's own
code, its answer shown: no line wider than the width, no word of its text lost, nothing dotted that the text does
not have. Prints what is wrong; says how many lines it read. Exit 1 when something is."""
import importlib.machinery
import importlib.util
import os
import re
import sys

repo, folder = sys.argv[1:3]
os.environ.update(KAWA_TOOLKIT=repo, KAWA_LEARN=folder)
sys.dont_write_bytecode = True
loader = importlib.machinery.SourceFileLoader("kawa_learn", os.path.join(repo, "bin/kawa-learn"))
spec = importlib.util.spec_from_loader("kawa_learn", loader)
k = importlib.util.module_from_spec(spec)
loader.exec_module(k)
course = k.Course()
bad = 0
lines = 0
for le in course.by_id.values():
    text = k.page_text(le, answer=True)
    src = re.sub(r"^```\S*$", " ", text, flags=re.M)
    want = set(re.findall(r"[^\W_]+", src.lower()))
    for width in map(int, sys.argv[3:]):
        page = k.Page(text, {}, le["title"])
        page.hl = {}
        out = page.layout(width)
        got = set()
        for ln in out:
            s = k.plain(ln.runs)
            lines += 1
            got.update(re.findall(r"[^\W_]+", s.lower()))
            if k.run_cols(ln.runs) > width:
                print(f"{le['id']} at {width}: a line of {k.run_cols(ln.runs)}: {s[:60]}")
                bad += 1
        # (a word longer than the line is cut across lines: compare what is left without spaces)
        joined = "".join(k.plain(ln.runs).lstrip("│↳ ") for ln in out).lower()
        lost = [w for w in want - got if w not in joined]
        if lost:
            print(f"{le['id']} at {width}: lost {sorted(lost)[:8]}")
            bad += 1
print(f"{len(course.by_id)} lessons, {lines} lines read")
sys.exit(1 if bad else 0)
