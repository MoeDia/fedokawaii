#!/usr/bin/env python3
"""chess_year.py DIR [STEP] — the year as the app will hand it out, day by day. Every one of the 365 days read from the course
at three levels of yourself: its rows, every game's start, clock and goal, what each lesson and sitting of puzzles asks of the
files; then every STEP-th day (13; the first, the last and each exam's too) opened in the real program, row by row, each by
Enter onto the screen it promises. Prints what is wrong, one line each; the last line: days, rows, games, opened, findings."""
import inspect
import json
import pathlib
import re
import shutil
import sys
import time

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from chess_lib import LIB, REPO, crash_text, make_home, open_app, state  # noqa: E402

sys.path.insert(0, str(LIB))
import board as B  # noqa: E402
import course as C  # noqa: E402
import lesson as L  # noqa: E402
import progress as PR  # noqa: E402
import puzzles as P  # noqa: E402
import review as RV  # noqa: E402
import store as S  # noqa: E402

DATA = REPO / "configs/home/.local/share/fedokawaii/chess"


def known_checks():
    src = inspect.getsource(RV.goal_met)
    return set(re.findall(r'word == "([^"]+)"', src)) | {w for g in re.findall(r"word in \(([^)]*)\)", src) for w in re.findall(r'"([^"]+)"', g)}


def read_year(root, say):
    """The whole course, read without a screen. Returns (days, rows, games)."""
    store = S.Store(str(root / "state"))
    pr = PR.Progress(store)
    bank = P.Bank(str(DATA / "puzzles.tsv"))
    lib = L.Library(str(DATA / "lessons.txt"))
    course = C.Course(lib, bank)
    bank.load()
    if bank.bad:
        say(f"the bank has {bank.bad} damaged lines")
    known = known_checks()
    tags = {}
    for it in bank.items:
        for tag in it[4].split():
            tags[tag] = tags.get(tag, 0) + 1
    games, rows, lessons = [], 0, set()
    for day in range(1, 366):
        items = course.items(day)
        keys = [it.key for it in items]
        rows += len(items)
        if len(set(keys)) != len(keys):
            say(f"day {day}: a row twice: {keys}")
        if not any(it.kind == "game" for it in items):
            say(f"day {day}: no game")
        for i, it in enumerate(items):
            if not it.label.strip() or not it.icon:
                say(f"day {day}: a row with no name or picture: {it.key}")
            if it.kind == "review" and (i == 0 or items[i - 1].kind != "game" or items[i - 1].ref != it.ref):
                say(f"day {day}: {it.key} does not follow its game")
            if it.kind == "lesson":
                lessons.add(it.ref)
                try:
                    _, pages = lib.read(it.ref)
                except (OSError, ValueError) as e:
                    say(f"day {day}: lesson {it.ref}: {e}")
                    continue
                if not pages:
                    say(f"day {day}: lesson {it.ref} has no page")
            if it.kind == "puzzles" and it.ref and tags.get(it.ref, 0) < 50:
                say(f"day {day}: only {tags.get(it.ref, 0)} puzzles of {it.ref}")
            if it.kind == "exam":
                ex = course.week(day).exam
                mixed = None in ex["themes"]    # (the year's last: any theme)
                have = sum(1 for p in bank.items if (mixed or set(p[4].split()) & set(ex["themes"])) and abs(p[3] - ex["rating"]) <= 300)
                if have < 40:
                    say(f"day {day}: the exam can draw on only {have} puzzles near {ex['rating']}")
            for r in (450.0, 1100.0, 1950.0):
                pr.game["r"], pr.puzzle["r"] = r, r + 200
                course.bank_starts.clear()
                it.value(pr)
                words = it.details(pr) + it.details(pr, face=True)
                if it.kind not in ("lesson",) and not words:
                    say(f"day {day}: {it.key}: nothing to say on the row")
                if it.kind != "game":
                    continue
                spec = course.game_spec(it.ref, pr)
                try:
                    g = B.Game(spec["fen"])
                    for u in spec.get("line") or ():
                        m = B.from_uci(u)
                        if m not in g.pos.legal():
                            say(f"game {it.ref} at {r}: {u} is not legal in its line")
                            break
                        g.play(m)
                    if not g.pos.legal():
                        say(f"game {it.ref} at {r}: no legal move at its start: {spec['fen']}")
                except (ValueError, KeyError, IndexError) as e:
                    say(f"game {it.ref} at {r}: {e}: {spec['fen']}")
                if not spec["goal"].strip():
                    say(f"game {it.ref}: no goal")
                if not 100 <= spec["elo"] <= 3200 or not spec["opponent"]:
                    say(f"game {it.ref}: level {spec['elo']}, opponent {spec['opponent']}")
                cl = spec.get("clock")
                if cl is not None and not (len(cl) == 2 and cl[0] > 0 and cl[1] >= 0):
                    say(f"game {it.ref}: clock {cl}")
                if spec["hints"] < 0:
                    say(f"game {it.ref}: hints {spec['hints']}")
                chk = spec.get("check")
                if chk and chk.partition(":")[0] not in known:
                    say(f"game {it.ref}: a check goal_met does not know: {chk}")
                if spec.get("gate") and not chk:
                    say(f"game {it.ref}: a gate with nothing to measure")
                if spec["title"] != f"game {it.ref} of 730":
                    say(f"game {it.ref}: titled {spec['title']}")
            if it.kind == "game":
                games.append(it.ref)
    if games != list(range(1, 731)):
        say(f"the games are not 1 to 730 in order: {len(games)} of them")
    never = [x for x in lib.index if x not in lessons]
    if never:
        say(f"{len(never)} lessons no day hands out: {never[:8]}")
    return course, rows, len(games)


def fresh_state(home, day, no=None, done=()):
    st = state(home)
    shutil.rmtree(st, ignore_errors=True)
    (st / "games").mkdir(parents=True)
    record = {"day": day, "items": {f"{day}/{k}": "x" for k in done}, "played": {}, "last_active": PR.today_ordinal()}
    if no:
        (st / f"games/{no}.pgn").write_text('[Event "x"]\n[White "you"]\n[Black "opp"]\n[Result "0-1"]\n\n1. e4 e5 2. Qg4 Nf6 3. Qg5 Nxe4 4. d3 Nxg5 0-1\n')
        record["played"][str(no)] = {"score": "loss", "elo": 500, "t": 1, "me": 0, "times": [3, 3, 3, 3], "check": "safe", "goal": "x", "accuracy": None}
    (st / "progress.json").write_text(json.dumps(record))


def promised(it, course):
    """What the screen a row opens must say at once."""
    if it.kind == "lesson":
        return course.lib.by_id[it.ref]["title"]
    if it.kind == "game":
        return f"game {it.ref} of 730"
    if it.kind == "review":
        return f"review of game {it.ref}"
    if it.kind == "puzzles":
        return "to move"
    if it.kind == "vision":
        return "the squares"
    if it.kind == "exam":
        return "to move"
    return f"week {it.ref}"


def open_days(course, root, step, say):
    """Rows opened in the real program, each from a fresh start on its day."""
    home, env = make_home(root / "pty")
    exams = [i * 7 + 7 for i, w in enumerate(course.weeks) if w.exam]
    days = sorted({1, 2, 7, 8, 28, 29, 363, 364, 365} | set(range(1, 366, step)) | set(exams))
    opened = 0
    for day in days:
        for i, it in enumerate(course.items(day)):
            fresh_state(home, day, it.ref if it.kind == "review" else None)
            t = open_app(env)
            try:
                for _ in range(i):
                    t.send("\x1b[B")
                    t.pump(0.01)
                t.send("\r")
                if not t.wait(promised(it, course), 12):
                    say(f"day {day}, row {i} ({it.key}): no '{promised(it, course)}' after Enter: {t.screen()[-300:]!r}")
                opened += 1
                t.pump(0.05)
                if crash_text(home):
                    say(f"day {day}, row {i} ({it.key}): {crash_text(home)[-400:]}")
                if not t.alive():
                    say(f"day {day}, row {i} ({it.key}): the program ended")
            finally:
                t.close()
    # a day all done, then the row that goes on; the year's last day done, its last words
    last = course.items(364)
    fresh_state(home, 364, done=[it.key for it in last])
    t = open_app(env)
    if not t.find("go on to day 365"):
        say(f"day 364 done: no row goes on: {t.screen()[-300:]!r}")
    t.send("\x1b[H")
    for _ in range(len(last)):
        t.send("\x1b[B")
        t.pump(0.01)
    t.send("\r")
    if not t.wait("day 365 of 365", 8):
        say(f"the row that goes on: no day 365: {t.screen()[-300:]!r}")
    t.close()
    fresh_state(home, 365, done=[it.key for it in course.items(365)])
    t = open_app(env)
    if not t.wait("the year is done", 8):
        say(f"day 365 done: no last words: {t.screen()[-300:]!r}")
    if t.find("go on to day"):
        say("day 365 done: a row goes on to a day that does not exist")
    t.close()
    if crash_text(home):
        say(f"the year's end: {crash_text(home)[-400:]}")
    return opened


def main():
    root = pathlib.Path(sys.argv[1])
    step = int(sys.argv[2]) if len(sys.argv) > 2 else 13
    root.mkdir(parents=True, exist_ok=True)
    (root / "state").mkdir(exist_ok=True)
    found = []

    def say(s):
        found.append(s)
        print(s, flush=True)

    started = time.monotonic()
    course, rows, games = read_year(root, say)
    print(f"read: {rows} rows, {games} games, {time.monotonic() - started:.0f} s", flush=True)
    opened = open_days(course, root, step, say)
    print(f"365 days, {rows} rows, {games} games, {opened} opened, {len(found)} findings", flush=True)
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
