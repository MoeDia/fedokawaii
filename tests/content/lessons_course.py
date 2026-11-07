"""tests/content/lessons_course.py FOLDER SYLLABUS REPO — holds every lesson in FOLDER to its day.

Prints one line a finding, "ok ..." or "FAIL ...". The order is the SYLLABUS's (DAY, PART-1-ID,
PART-2-ID; "-" for Part 1 once it is done); a lesson not written yet is "pending" (said, not a failure). Held: every lesson reads and
sits in its syllabus day and part; what it needs is taught before it (or in Part 1 of its day); a day
with both lessons is 25 to 30 minutes; Part 2's runs replayed in day order from an empty dojo each fail
before their own steps and pass after; every ask's proof passes from REPO's root, and its answer is
accepted as itself; a standard-2 lesson's example (sb04) runs and prints its ```output exactly: its
```python fences joined run by python3, its ```bash fences by bash, in an empty folder; a Part 1 example of
```keys (a key pressed, what appears) is held by the lesson's ask proof instead, a Part 2 one always runs.
"""
import os
import re
import subprocess
import sys
import tempfile

folder, syllabus, repo = sys.argv[1:4]
sys.path.insert(0, os.path.join(repo, "lib"))
import lessons as L  # noqa: E402

days = []
for row in open(syllabus, encoding="utf-8").read().split("\n"):
    if row and not row.startswith("#"):
        c = row.split("\t")
        days.append((int(c[0]), c[1], c[2]))

course = {}
for entry in sorted(os.listdir(folder)):
    if entry.endswith(".md"):
        path = os.path.join(folder, entry)
        try:
            course[entry[:-3]] = L.parse(open(path, encoding="utf-8").read(), path)
        except L.Fault as e:
            print(f"FAIL unreadable: {e}")
syllabus_ids = {i for _, a, b in days for i in (a, b)}
for lid in sorted(course.keys() - syllabus_ids):
    print(f"FAIL {lid} is in no syllabus day")

RUNS = {"python": ["python3", "-I", "-B", "-"], "bash": ["bash", "-s"]}


def example(path, lid, part):
    """runs a standard-2 lesson's example: (ok, why)"""
    text = open(path, encoding="utf-8").read()
    section = re.search(r"^## example\n(.*?)(?=^## )", text, re.M | re.S)
    found = re.findall(r"^```(\S*)[^\n]*\n(.*?)^```$", section[1], re.M | re.S) if section else []
    code = [(info, body) for info, body in found if info in RUNS]
    want = "".join(body for info, body in found if info == "output")
    kinds = {info for info, _ in code}
    if not code:
        return (part == 1 and any(info == "keys" for info, _ in found), "no ```python or ```bash to run")
    if len(kinds) > 1:
        return False, "one language an example"
    with tempfile.TemporaryDirectory(prefix="example-") as where:
        try:
            p = subprocess.run(RUNS[kinds.pop()], input="".join(b for _, b in code), cwd=where,
                               capture_output=True, text=True, timeout=10)
        except subprocess.TimeoutExpired:
            return False, "ran over 10 s"
    if p.stdout != want or p.returncode:
        return False, f"printed {p.stdout[-120:]!r} (exit {p.returncode}), its output says {want[-120:]!r}"
    return True, ""


taught, dojo = set(), tempfile.mkdtemp(prefix="dojo-")
pending = []
for day, one, two in days:
    for lid, part in ((one, 1), (two, 2)):
        if lid == "-":  # Part 1 done: the day is Part 2 alone
            continue
        r = course.get(lid)
        if not r:
            pending.append(lid)
            continue
        if r["part"] != part:
            print(f"FAIL day {day}: {lid} is part {r['part']}, in part {part}'s place")
        for need in r["needs"]:
            if need not in taught and not (part == 2 and need == one):
                print(f"FAIL day {day}: {lid} needs {need}, not taught before it")
        taught.add(lid)
        if r["standard"] == 2:
            good, why = example(os.path.join(folder, lid + ".md"), lid, part)
            print(f"{'ok' if good else 'FAIL'} day {day} {lid}: example prints its output" + (f": {why}" if why else ""))
        c = r["check"]
        if c["kind"] == "ask":
            if not L.same_answer(c["answer"], c["answer"]):
                print(f"FAIL day {day}: {lid}: its answer is not accepted as itself")
            p = subprocess.run(["bash", "-c", c["proof"]], cwd=repo, stdin=subprocess.DEVNULL,
                               capture_output=True, text=True)
            print(f"{'ok' if p.returncode == 0 else 'FAIL'} day {day} {lid}: ask proof exit {p.returncode}"
                  + ("" if p.returncode == 0 else f" {p.stderr.strip()[-200:]}"))
            continue
        os.makedirs(os.path.join(dojo, c["in"]), exist_ok=True)
        before = L.run_check(c, dojo)["passed"]
        for s in r["steps"]:
            if "file" in s:
                target = os.path.join(dojo, c["in"], s["file"])
                os.makedirs(os.path.dirname(target), exist_ok=True)
                open(target, "w", encoding="utf-8").write(s["text"])
            else:
                subprocess.run(["bash", "-c", s["do"]], cwd=os.path.join(dojo, c["in"]),
                               stdin=subprocess.DEVNULL, capture_output=True)
        after = L.run_check(c, dojo)
        good = not before and after["passed"]
        why = "" if good else f" before={before} after={after['passed']} out={after['out'][-120:]!r} err={after['err'][-120:]!r}"
        print(f"{'ok' if good else 'FAIL'} day {day} {lid}: run fails before, passes after{why}")
    if one in course and two in course:
        m = course[one]["minutes"] + course[two]["minutes"]
        if not L.DAY_MINUTES[0] <= m <= L.DAY_MINUTES[1]:
            print(f"FAIL day {day}: {m} minutes, a day is {L.DAY_MINUTES[0]} to {L.DAY_MINUTES[1]}")
        else:
            print(f"ok day {day}: paired {one} + {two}, {m} minutes")
print(f"pending {len(pending)}: {' '.join(pending)}")
