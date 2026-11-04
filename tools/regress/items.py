#!/usr/bin/env python3
"""tools/regress/items.py — the never-again list (tools/regress/README.md) held to the truth.

  items.py check [REPO]   every ledger item and every row of the master's trace has a row; every
                          row's check is there (the test file, and the case it names, word for
                          word); every check here has a row. Exit 1, each fault on a line.
                          (a copy without .claude/: the rows' checks alone)
  items.py count [REPO]   how many items: with a check, gone, a record, open, by hand.
  items.py of NAME        the items a headless check guards (tools/regress/NAME.sh): its run's line.
  items.py blame LOG      what the owner reported that a run's log broke: for each "✘ CASE — why"
                          line (tests/run.sh) and "✘ NAME …" line (tools/regress/run.sh), the items
                          whose row names that case or that check.

A row: | ITEM ITEM … | what must hold | CHECK · CHECK … |, where a CHECK is
  tests/AREA/test_x.sh "words of a case" · tools/PATH · gone T.. : why · record: why ·
  open T..: why · manual: the step
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SEP = " · "
KINDS = ("gone", "record", "open", "manual")
MANUAL_MOST = 5     # (plan T52: a written reason it cannot be automated, five at the most)

# Ledger lines that are records by their very name: a run's verdict, an apply, a push, an event,
# a master's review (what it found has its own -fix line, with its own row). README.md says so.
RECORD = re.compile(r"""^r27$ | ^r27-(suites?|push|apply|event|boot|tidy|shm|note|f45-job|away-proof)(\b|-) | ^r27-inbox$
                        | -master(-\d+|-efh(-\d+)?)?$ | -R\d+b?$ | -review\d*$ | -baseline$ | -digest$ | -research$
                        | -facts$ | -hunt$ | -weighed$ | -owner$""", re.X)


def rows(repo):
    """The list's rows: (line number, items, what must hold, checks)."""
    out = []
    with open(os.path.join(repo, "tools/regress/README.md"), encoding="utf8") as f:
        for n, line in enumerate(f, 1):
            if not line.startswith("| r2"):
                continue
            cells = [c.strip() for c in line.strip().strip("|").split(" | ")]
            if len(cells) != 3:
                out.append((n, [], "", [f"!row: {len(cells)} cells, not 3"]))
                continue
            out.append((n, cells[0].split(), cells[1], cells[2].split(SEP)))
    return out


def parse_check(check):
    """A check's (path, case words) — or (kind, the words after it)."""
    m = re.fullmatch(r'((?:tests|tools)/\S+?)(?: "(.+)")?', check)
    if m:
        return m.group(1), m.group(2)
    m = re.match(rf"({'|'.join(KINDS)})\b ?(T[\w-]+)? ?:? ?(.*)", check)
    if m:
        return m.group(1), (m.group(2) or "") + "\0" + m.group(3)
    return None, None


def ledger_items(repo):
    """Every id in the ledger: - rNN… lines, the r24 list's numbers, the r26 follow-ups by place."""
    want, seen_r24, fu = set(), [], 0
    section = ""
    path = os.path.join(repo, ".claude/notes/02-LEDGER.md")
    if not os.path.exists(path):
        return set()
    with open(path, encoding="utf8") as f:
        for line in f:
            if line.startswith("## "):
                section = line
            m = re.match(r"- (r2[567](?:-[-a-zA-Z0-9./]*[a-zA-Z0-9])?)", line)
            if m:
                want.add(m.group(1))
            elif section.startswith("## r24 ") and re.match(r"\d|Report", line):
                seen_r24 += re.findall(r"(?:^|· )(\d+) [^·]*?→", line)
            elif section.startswith("## r26 follow-ups") and line.startswith("- "):
                fu += 1
    want |= {f"r24-{n}" for n in seen_r24}
    want |= {f"r26-fu-{i}" for i in range(1, fu + 1)}
    return want


def trace_items(repo):
    """Every row of the master's trace: the owner's requests by id."""
    path = os.path.join(repo, ".claude/notes/master-trace.md")
    if not os.path.exists(path):
        return set()
    with open(path, encoding="utf8") as f:
        return {m.group(1) for m in (re.match(r"\| (r2[4-7]-[\w-]+) \|", ln) for ln in f) if m}


def wanted(repo):
    """Every item: a ledger number the trace splits (r24-8 → r24-8a, b, c) stands for its parts."""
    ledger, trace = ledger_items(repo), trace_items(repo)
    return {i for i in ledger if not any(t.startswith(i) and t[len(i):].isalpha() for t in trace)} | trace


def case_lines(path):
    with open(path, encoding="utf8", errors="replace") as f:
        return [ln for ln in f if re.match(r"\s*case_ ", ln)]


def plan_done(repo):
    """Tasks the plan marks done: their heading's own bracket says so."""
    done = set()
    path = os.path.join(repo, ".claude/plan.md")
    if not os.path.exists(path):
        return done
    with open(path, encoding="utf8") as f:
        for line in f:
            m = re.match(r"### (T[\w-]+) .*\[(done|DONE)\b", line)
            if m:
                done.add(m.group(1))
    return done


def check(repo):
    faults = []
    the_rows = rows(repo)
    listed, used = {}, set()
    manual = 0
    done = plan_done(repo)
    cases = {}
    for n, items, _, checks in the_rows:
        for i in items:
            if i in listed:
                faults.append(f"line {n}: {i} is on line {listed[i]} too")
            listed[i] = n
        if not checks or checks == [""]:
            faults.append(f"line {n}: no check")
        for c in checks:
            if c.startswith("!"):
                faults.append(f"line {n}: {c[1:]}")
                continue
            what, words = parse_check(c)
            if what is None:
                faults.append(f"line {n}: not a check: {c}")
            elif what in KINDS:
                task, why = words.split("\0")
                if not why:
                    faults.append(f"line {n}: {what} with no reason")
                if what == "manual":
                    manual += 1
                if what == "open" and task in done:
                    faults.append(f"line {n}: {task} is done now: name its check ({' '.join(items)})")
            else:
                used.add(what)
                p = os.path.join(repo, what)
                if not os.path.exists(p):
                    faults.append(f"line {n}: {what} is not there")
                elif words:
                    cases.setdefault(what, case_lines(p))
                    if not any(words in ln for ln in cases[what]):
                        faults.append(f'line {n}: {what} has no case with "{words}"')
    if manual > MANUAL_MOST:
        faults.append(f"{manual} rows done by hand, at most {MANUAL_MOST}")
    want = wanted(repo)
    for i in sorted(want - set(listed)):
        if not RECORD.search(i):
            faults.append(f"no row for {i}: add | {i} | what must hold | its check | to tools/regress/README.md")
    if want:      # (a toolkit's copy has neither the ledger nor the trace: its rows hold what it can)
        for i in sorted(set(listed) - want):
            faults.append(f"line {listed[i]}: {i} is in neither the ledger nor the trace")
    for d in ("tools/regress", "tests/regress"):
        for f in sorted(os.listdir(os.path.join(repo, d))):
            p = f"{d}/{f}"
            if p.endswith(".sh") and f not in ("run.sh", "lib.sh") and p not in used:
                faults.append(f"{p} is no row's check")
    return faults


def count(repo):
    tally = dict.fromkeys(("check", *KINDS), 0)
    want = wanted(repo)
    listed = set()
    for _, items, _, checks in rows(repo):
        listed |= set(items)
        kinds = {parse_check(c)[0] for c in checks}
        kind = next((k for k in ("open", "manual", "gone", "record") if k in kinds and len(kinds) == 1), "check")
        tally[kind] += len(items)
    records = sum(1 for i in want - listed if RECORD.search(i))
    return (f"{len(listed) + records} items: {tally['check']} with a check, {tally['gone']} gone, "
            f"{tally['record'] + records} records, {tally['open']} open in their tasks, {tally['manual']} by hand")


def of(repo, name):
    """The items whose row names the check tools/regress/NAME.sh."""
    hits = []
    for _, items, _, checks in rows(repo):
        if f"tools/regress/{name}.sh" in checks:
            hits += items
    return " ".join(hits)


def blame(repo, log):
    the_rows = rows(repo)
    said = set()
    with open(log, encoding="utf8", errors="replace") as f:
        for line in f:
            m = re.match(r"\s*✘ (.+?)(?: — |\s{2,}|$)", line)
            if not m:
                continue
            case = m.group(1).strip()
            hits = []
            for _, items, _, checks in the_rows:
                for c in checks:
                    what, words = parse_check(c)
                    if what in KINDS or what is None:
                        continue
                    if (words and words in case) or (not words and os.path.basename(what).removesuffix(".sh") == case.split()[0]):
                        hits += items
                        break
            if hits and case not in said:
                said.add(case)
                print(f"✘ {' '.join(hits)} — {case[:100]}")


def main(argv):
    if len(argv) < 2 or argv[1] not in ("check", "count", "blame", "of"):
        print(__doc__)
        return 2
    default = os.path.dirname(os.path.dirname(HERE))
    if argv[1] == "of":
        print(of(default, argv[2]) if len(argv) == 3 else "")
        return 0
    if argv[1] == "blame":
        if len(argv) != 3:
            print("usage: items.py blame LOG", file=sys.stderr)
            return 2
        blame(default, argv[2])
        return 0
    repo = argv[2] if len(argv) > 2 else default
    if argv[1] == "count":
        print(count(repo))
        return 0
    faults = check(repo)
    print("\n".join(faults) if faults else f"the list is whole — {count(repo)}")
    return 1 if faults else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
