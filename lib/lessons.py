"""lib/lessons.py — the daily lessons: their format, its parser, and where a day stands.

A day is one lesson of Part 1 (the system) and one of Part 2 (programming), 25 to 30 minutes
together. A lesson is one idea, one exercise, one check. A record of dated lessons is all that is
kept: no score, no streak, a day missed costs nothing, today's pair simply waits.

The folder (docs/lessons, flat):

    days.tsv     the order: DAY<TAB>PART-1-ID<TAB>PART-2-ID, days 1, 2, 3 … with no gap; # a comment.
                 Every lesson is in one day. An id stays once it is out: the record keeps it.
    ID.md        a lesson:

        ---
        id: first-print                the file's name; a-z 0-9 -
        title: one line on the screen  46 columns at most (the pane's heading)
        part: 2                        1 or 2
        minutes: 12                    5 to 25
        needs: [other-id]              optional: lessons of an earlier day, or Part 1 of this one
        ---
        ## idea                        at most 200 words of prose (code not counted)
        ## exercise                    at most 120
        ## check                       a single fenced block, check, of one kind:
        ## answer                      only with a run check, and needed there

Both kinds of check say what is true when the lesson is learnt, one key a line:

    run: python3 hello.py              in ~/dojo/FOLDER, by the owner or by a test
    in: FOLDER
    expect: hello                      its output, a line each, whole (expect: alone, an empty line)
    exit: 0                            optional: the exit status, 0 when not said

    ask: Which key opens the panel?    a question put to him
    answer: Super+U
    proof: grep -q …                   run from the repo's root by the tests only, never on his PC's
                                       desktop: what keeps the answer true when the system changes

The answer of a run check holds the steps that make it pass, in order, among prose: a fence
`file NAME` writes NAME in the folder, a fence `do` runs its commands there. Replaying Part 2's in
the days' order from an empty ~/dojo must pass every check, and each must fail before its own
steps: a tool is rebuilt across days, from zero, by hand.

The record: ~/.local/state/fedokawaii/days, a line YYYY-MM-DD<TAB>ID for a lesson done, only ever
added to. A line it cannot read is passed over, and an id no longer taught stays, uncounted.

Run alone, `python3 lib/lessons.py [FOLDER]` holds a folder to all this: says the first fault, exit 1.
"""
import os
import re
import select
import signal
import subprocess
import sys
import time

ID = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*")
DATE = re.compile(r"\d{4}-\d\d-\d\d")
FOLDER = re.compile(r"[a-z0-9][a-z0-9-]*")
FILENAME = re.compile(r"[A-Za-z0-9_][A-Za-z0-9_.-]*(?:/[A-Za-z0-9_][A-Za-z0-9_.-]*)*")
SECTIONS = ("idea", "exercise", "check", "answer")
WORDS = {"idea": 200, "exercise": 120}
TITLE = 46
LESSON_MINUTES = (5, 25)
DAY_MINUTES = (25, 30)
RUN_SECONDS = 10    # a run check at most: what never ends is stopped, and said
RUN_BYTES = 65536   # what it prints, kept at most: past it, it is stopped


class Fault(Exception):
    """what is wrong, with its place: file:line: why"""


def parse_front(lines, name):
    if not lines or lines[0] != "---":
        raise Fault(f"{name}:1: no front matter")
    front = {}
    for i, row in enumerate(lines[1:], 2):
        if row == "---":
            break
        key, colon, value = row.partition(": ")
        if not colon or key not in ("id", "title", "part", "minutes", "needs") or key in front:
            raise Fault(f"{name}:{i}: not a front matter line, or one said twice: {row}")
        front[key] = value.strip()
    else:
        raise Fault(f"{name}:1: the front matter does not end")
    for key in ("id", "title", "part", "minutes"):
        if not front.get(key):
            raise Fault(f"{name}: no {key}")
    if not ID.fullmatch(front["id"]):
        raise Fault(f"{name}: a bad id: {front['id']}")
    if len(front["title"]) > TITLE:
        raise Fault(f"{name}: a title over {TITLE} columns: {front['title']}")
    if front["part"] not in ("1", "2"):
        raise Fault(f"{name}: part is 1 or 2: {front['part']}")
    if not front["minutes"].isdecimal() or not LESSON_MINUTES[0] <= int(front["minutes"]) <= LESSON_MINUTES[1]:
        raise Fault(f"{name}: minutes are {LESSON_MINUTES[0]} to {LESSON_MINUTES[1]}: {front['minutes']}")
    needs = front.get("needs", "[]")
    if not (needs.startswith("[") and needs.endswith("]")):
        raise Fault(f"{name}: needs is a [list]: {needs}")
    needs = [n.strip() for n in needs[1:-1].split(",") if n.strip()]
    if not all(ID.fullmatch(n) for n in needs):
        raise Fault(f"{name}: a bad id in needs: {needs}")
    return {"id": front["id"], "title": front["title"], "part": int(front["part"]),
            "minutes": int(front["minutes"]), "needs": needs}, len(front) + 2


def split_sections(lines, first, name):
    """the sections, in their order, each a list of (line number, text); a fence's lines are never
    a heading"""
    sections, here, fence = {}, None, 0
    for i, row in enumerate(lines[first:], first + 1):
        if fence:
            if row == "```":
                fence = 0
        elif row.startswith("```"):
            fence = i
        elif row.startswith("#"):
            m = re.fullmatch(r"## (\w+)", row)
            want = SECTIONS[len(sections)] if len(sections) < len(SECTIONS) else None
            if not m or m[1] != want:
                raise Fault(f"{name}:{i}: {row}: the next heading can only be ## {want}")
            here = sections[m[1]] = []
            continue
        if here is None:
            if row.strip():
                raise Fault(f"{name}:{i}: words before ## idea")
            continue
        here.append((i, row))
    if fence:
        raise Fault(f"{name}:{fence}: a fence that does not end")
    for want in SECTIONS[:3]:
        if want not in sections:
            raise Fault(f"{name}: no ## {want}")
    return sections


def fences(section):
    """(line number, info, body) of each fence, then the prose between them"""
    found, prose, fence = [], [], None
    for i, row in section:
        if fence is not None:
            if row == "```":
                found.append((fence[0], fence[1], "\n".join(fence[2])))
                fence = None
            else:
                fence[2].append(row)
        elif row.startswith("```"):
            fence = (i, row[3:].strip(), [])
        else:
            prose.append(row)
    return found, prose


def parse_check(section, name):
    found, prose = fences(section)
    at = section[0][0] if section else 0
    if len(found) != 1 or found[0][1] != "check" or any(row.strip() for row in prose):
        raise Fault(f"{name}:{at}: ## check is one fenced check block and nothing else")
    at, _, body = found[0]
    check = {}
    for i, row in enumerate(body.split("\n"), at + 1):
        key, colon, value = row.partition(":")
        if not colon or key not in ("run", "in", "expect", "exit", "ask", "answer", "proof"):
            raise Fault(f"{name}:{i}: not a line of a check: {row}")
        value = value[1:] if value.startswith(" ") else value
        if key == "expect":
            check.setdefault("expect", []).append(value)
        elif key in check:
            raise Fault(f"{name}:{i}: {key} twice: one check, one of each")
        else:
            check[key] = value
    if "run" in check:
        extra = {"ask", "answer", "proof"} & check.keys()
        if extra:
            raise Fault(f"{name}:{at}: a run check with {sorted(extra)[0]}")
        if "expect" not in check or not check["run"].strip() or not FOLDER.fullmatch(check.get("in", "")):
            raise Fault(f"{name}:{at}: a run check says run, in (a folder of ~/dojo) and expect")
        if not re.fullmatch(r"\d{1,3}", check.get("exit", "0")):
            raise Fault(f"{name}:{at}: exit is a number: {check['exit']}")
        return {"kind": "run", "run": check["run"], "in": check["in"], "expect": "\n".join(check["expect"]),
                "exit": int(check.get("exit", "0"))}
    if "ask" in check:
        extra = {"in", "expect", "exit"} & check.keys()
        if extra:
            raise Fault(f"{name}:{at}: an ask check with {sorted(extra)[0]}")
        if not all(check.get(key, "").strip() for key in ("ask", "answer", "proof")):
            raise Fault(f"{name}:{at}: an ask check says ask, answer and proof")
        return {"kind": "ask", "ask": check["ask"], "answer": check["answer"], "proof": check["proof"]}
    raise Fault(f"{name}:{at}: a check is a run or an ask")


def parse_steps(section, name):
    found, _ = fences(section)
    steps = []
    for at, info, body in found:
        word, _, arg = info.partition(" ")
        if word == "do" and not arg:
            steps.append({"do": body})
        elif word == "file" and FILENAME.fullmatch(arg) and ".." not in arg:
            steps.append({"file": arg, "text": body + "\n"})
        else:
            raise Fault(f"{name}:{at}: in ## answer a fence is do, or file NAME inside the folder: {info}")
    if not steps:
        raise Fault(f"{name}: ## answer has no step: a do or a file fence")
    return steps


def text_of(section):
    return "\n".join(row for _, row in section).strip("\n")


def parse(text, name="lesson"):
    """a lesson's text as a dict: id title part minutes needs idea exercise check steps"""
    if "…" in text:
        raise Fault(f"{name}: an ellipsis: never cut, cut at a word or fit")
    lines = text.split("\n")
    lesson, first = parse_front(lines, name)
    sections = split_sections(lines, first, name)
    for key, most in WORDS.items():
        found, prose = fences(sections[key])
        words = len(" ".join(prose).split())
        if not words:
            raise Fault(f"{name}: ## {key} is empty")
        if words > most:
            raise Fault(f"{name}: ## {key} is {words} words, {most} at most: one idea, tiny steps")
    lesson["idea"], lesson["exercise"] = text_of(sections["idea"]), text_of(sections["exercise"])
    lesson["check"] = parse_check(sections["check"], name)
    if lesson["check"]["kind"] == "run":
        if "answer" not in sections:
            raise Fault(f"{name}: a run check needs its ## answer")
        lesson["steps"] = parse_steps(sections["answer"], name)
        lesson["answer"] = text_of(sections["answer"])
    else:
        if "answer" in sections:
            raise Fault(f"{name}: an ask check holds its answer: no ## answer")
        lesson["steps"], lesson["answer"] = [], ""
    return lesson


def read_days(path):
    """days.tsv as [(day, part 1 id, part 2 id)]"""
    days = []
    with open(path, encoding="utf-8") as f:
        for i, row in enumerate(f.read().split("\n"), 1):
            if not row or row.startswith("#"):
                continue
            c = row.split("\t")
            if len(c) != 3 or not all(ID.fullmatch(x) for x in c[1:]):
                raise Fault(f"{path}:{i}: not DAY, PART-1-ID, PART-2-ID: {row}")
            if c[0] != str(len(days) + 1):
                raise Fault(f"{path}:{i}: day {c[0]} where day {len(days) + 1} comes")
            days.append((len(days) + 1, c[1], c[2]))
    return days


def load(folder):
    """the course: {"days": [(day, id, id)], "lessons": {id: lesson}}, or a Fault: every lesson
    readable, each in one day, every day the right parts and length, nothing needed before it is taught"""
    lessons = {}
    for entry in sorted(os.listdir(folder)):
        if not entry.endswith(".md"):
            continue
        path = os.path.join(folder, entry)
        with open(path, encoding="utf-8") as f:
            lesson = parse(f.read(), path)
        if lesson["id"] != entry[:-3]:
            raise Fault(f"{path}: its id is {lesson['id']}: the file's name is the id")
        lessons[lesson["id"]] = lesson
    days = read_days(os.path.join(folder, "days.tsv"))
    taught = set()
    for day, one, two in days:
        for lid, part in ((one, 1), (two, 2)):
            if lid not in lessons:
                raise Fault(f"day {day}: no lesson {lid}")
            if lid in taught:
                raise Fault(f"day {day}: {lid} is in two days")
            if lessons[lid]["part"] != part:
                raise Fault(f"day {day}: {lid} is of part {lessons[lid]['part']}, in part {part}'s place")
            for need in lessons[lid]["needs"]:
                if need not in taught:
                    raise Fault(f"day {day}: {lid} needs {need}, not taught before it")
            taught.add(lid)
        minutes = lessons[one]["minutes"] + lessons[two]["minutes"]
        if not DAY_MINUTES[0] <= minutes <= DAY_MINUTES[1]:
            raise Fault(f"day {day}: {minutes} minutes, a day is {DAY_MINUTES[0]} to {DAY_MINUTES[1]}")
    lost = sorted(lessons.keys() - taught)
    if lost:
        raise Fault(f"{lost[0]} is in no day")
    return {"days": days, "lessons": lessons}


def read_record(path):
    """{id: the date it was first done}; a line it cannot read is passed over"""
    done = {}
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for row in f:
                c = row.rstrip("\n").split("\t")
                if len(c) == 2 and DATE.fullmatch(c[0]) and ID.fullmatch(c[1]):
                    done[c[1]] = min(c[0], done.get(c[1], c[0]))
    except OSError:
        pass
    return done


def add_record(path, lid, date):
    """(one short append: two windows cannot mix their lines)"""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "a", encoding="utf-8") as f:
        f.write(f"{date}\t{lid}\n")


def place(course, done, today):
    """where a day stands: (the day to show, the day after it, days finished). The day to show is the
    last finished today, else the first unfinished, None when all are finished; a day is finished
    on the later date of its two lessons, and one day a date is what is offered: the next waits"""
    finished, first_open, last_today = 0, None, None
    for day in course["days"]:
        if day[1] in done and day[2] in done:
            finished += 1
            if max(done[day[1]], done[day[2]]) == today:
                last_today = day
        elif first_open is None:
            first_open = day
    if last_today:
        return last_today, first_open, finished
    if first_open is None:
        return None, None, finished
    after = course["days"][first_open[0]:first_open[0] + 1]
    return first_open, after[0] if after else None, finished


def same_answer(said, answer):
    """an ask's answer, whatever its case, spaces or quotes: Super+U is super + u"""
    plain = lambda s: re.sub(r"[\s`'\"]+", "", s).casefold().rstrip(".")
    return bool(plain(said)) and plain(said) == plain(answer)


def run_check(check, dojo):
    """a run check on what is in dojo/FOLDER: {passed, out, err, status}. Its output must be expect,
    whole, and its status exit; status None: stopped, "no folder": nothing to run in"""
    folder = os.path.join(dojo, check["in"])
    if not os.path.isdir(folder):
        return {"passed": False, "out": "", "err": "", "status": "no folder"}
    p = subprocess.Popen(["bash", "-c", check["run"]], cwd=folder, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                         stderr=subprocess.PIPE, start_new_session=True)
    got = {p.stdout: b"", p.stderr: b""}
    end, stopped = time.monotonic() + RUN_SECONDS, False
    while any(not f.closed for f in got):
        ready, _, _ = select.select([f for f in got if not f.closed], [], [], max(0, end - time.monotonic()))
        for f in ready:
            data = os.read(f.fileno(), 4096)
            got[f] += data
            if not data:
                f.close()
        if not ready or sum(map(len, got.values())) > RUN_BYTES:
            stopped = True
            break
    try:            # (what shut its output may still run)
        p.wait(0 if stopped else max(0, end - time.monotonic()))
    except subprocess.TimeoutExpired:
        stopped = True
    if stopped:     # (its whole group: what it started goes with it)
        os.killpg(p.pid, signal.SIGKILL)
    status = p.wait()
    out, err = (got[f].decode("utf-8", "replace") for f in (p.stdout, p.stderr))
    for f in got:
        f.close()
    passed = not stopped and status == check["exit"] and out.rstrip("\n") == check["expect"].rstrip("\n")
    return {"passed": passed, "out": out, "err": err, "status": None if stopped else status}


def history(done):
    """the record for reading: [(date, [ids])], oldest first"""
    dates = {}
    for lid, date in done.items():
        dates.setdefault(date, []).append(lid)
    return [(date, sorted(dates[date])) for date in sorted(dates)]


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    try:
        course = load(sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "docs", "lessons"))
    except (Fault, OSError) as e:
        print(e, file=sys.stderr)
        sys.exit(1)
    print(f"{len(course['days'])} days, {len(course['lessons'])} lessons")
