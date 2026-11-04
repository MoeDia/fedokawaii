#!/usr/bin/env python3
"""tools/check-chess-lessons.py — every lesson held to the board: each FEN valid, each move legal where it is
played, each lesson of the syllabus written and in the syllabus's order, each @try a good move by Stockfish's
own judgement, each @find a square. Prints what is wrong; exit 1 if anything is.

  python3 -I -B tools/check-chess-lessons.py [--engine PATH] [--nodes N] [LESSONS.txt]
"""
import pathlib
import re
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = pathlib.Path(__file__).resolve().parent.parent
LIB = ROOT / "configs/home/.local/lib/fedokawaii/kawa-chess"
sys.path.insert(0, str(LIB))
import board as B  # noqa: E402
import engine as E  # noqa: E402
import syllabus as SY  # noqa: E402

LESSON = re.compile(r"(?m)^=== (\S+)\n")


class SF:
    def __init__(self, path):
        self.p = subprocess.Popen([path], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1)
        self.cmd("uci")
        self.until("uciok")
        self.cmd("setoption name Threads value 2")
        self.cmd("setoption name Hash value 128")

    def cmd(self, s):
        self.p.stdin.write(s + "\n")
        self.p.stdin.flush()

    def until(self, w):
        while not self.p.stdout.readline().startswith(w):
            pass

    def score(self, fen, moves, nodes):
        """Best score of the side to move, in centipawns, after moves."""
        self.cmd(f"position fen {fen}" + (" moves " + " ".join(moves) if moves else ""))
        self.cmd(f"go nodes {nodes}")
        cp = 0
        while True:
            t = self.p.stdout.readline().split()
            if t and t[0] == "bestmove":
                return cp, t[1] if len(t) > 1 else None
            if "score" in t and "lowerbound" not in t and "upperbound" not in t:
                i = t.index("score")
                cp = int(t[i + 2]) if t[i + 1] == "cp" else (30000 - 100 * abs(int(t[i + 2]))) * (1 if int(t[i + 2]) > 0 else -1)


def parse_pages(body):
    head, _, rest = body.partition("\n\n")
    return head, rest.split("\n---\n")


def main(argv):
    engine = None
    nodes = 300000
    args = argv[1:]
    if "--engine" in args:
        i = args.index("--engine")
        engine = SF(args[i + 1])
        del args[i:i + 2]
    if "--nodes" in args:
        i = args.index("--nodes")
        nodes = int(args[i + 1])
        del args[i:i + 2]
    path = pathlib.Path(args[0]) if args else ROOT / "configs/home/.local/share/fedokawaii/chess/lessons.txt"
    text = path.read_text(encoding="utf-8")
    parts = LESSON.split(text)
    names = parts[1::2]
    bodies = parts[2::2]
    bad = []
    wanted = [s for w in SY.WEEKS for s in w.get("lessons", [])]
    for s in wanted:
        if s not in names:
            bad.append(f"syllabus: no lesson {s}")
    for s in names:
        if s not in wanted:
            bad.append(f"lesson {s}: not in the syllabus")
    if [n for n in names if n in wanted] != [w for w in wanted if w in names]:
        bad.append("lessons.txt is not in the syllabus's order")
    if len(names) != len(set(names)):
        bad.append("a lesson twice")
    themes = {k for k, _ in SY.THEME_NAMES} | {"equality"}
    for name, body in zip(names, bodies, strict=True):
        head, pages = parse_pages(body)
        if not re.search(r"(?m)^title: \S", head):
            bad.append(f"{name}: no title")
        if not re.search(r"(?m)^source: \S", head):
            bad.append(f"{name}: no source")
        if not re.search(r"(?m)^minutes: \d", head):
            bad.append(f"{name}: no minutes")
        pos = None
        words = 0
        for pn, page in enumerate(pages, 1):
            where = f"{name} p{pn}"
            fenline = re.search(r"(?m)^@fen (.+)$", page)
            if fenline:
                try:
                    pos = B.Position(fenline[1].strip())
                except ValueError as e:
                    bad.append(f"{where}: {e}")
                    pos = None
            ops = [ln.split()[0] for ln in page.split("\n") if ln.startswith(("@play", "@try"))]
            if ops.count("@play") > 1 or ops.count("@try") > 1 or ops == ["@try", "@play"]:
                bad.append(f"{where}: a page plays its moves first, then asks: one of each, in that order")
            for line in page.split("\n"):
                s = line.strip()
                if not s:
                    continue
                if not s.startswith("@"):
                    words += len(s.split())
                    if re.search(r"\.\.\.|…", s) and not re.search(r"\.\.\.[A-Za-z]", s):
                        bad.append(f"{where}: an ellipsis in the words: {s[:50]}")
                    if not re.search(r"[a-z]", s):
                        bad.append(f"{where}: odd words: {s[:40]}")
                    continue
                word, _, rest = s[1:].partition(" ")
                if word in ("fen", "flip", "any"):
                    continue
                if word == "mark":
                    for sq in rest.split():
                        if not re.fullmatch(r"[a-h][1-8]", sq):
                            bad.append(f"{where}: mark {sq}")
                elif word == "arrow":
                    for a in rest.split():
                        try:
                            B.from_uci(a)
                        except ValueError:
                            bad.append(f"{where}: arrow {a}")
                elif word == "find":
                    for sq in rest.split():
                        if not re.fullmatch(r"[a-h][1-8]", sq):
                            bad.append(f"{where}: find {sq}")
                elif word == "play":
                    for san in rest.split():
                        if pos is None:
                            bad.append(f"{where}: @play with no position")
                            break
                        m = pos.parse_san(san)
                        if m is None:
                            bad.append(f"{where}: @play {san}: not legal in {pos.fen()}")
                            break
                        pos.push(m)
                elif word == "try":
                    good, _, fail = rest.partition("|")
                    good = good.split()
                    if pos is None or not good:
                        bad.append(f"{where}: @try with no position or no move")
                        continue
                    if not fail.strip():
                        bad.append(f"{where}: @try with no words for a wrong move")
                    ms = []
                    for san in good:
                        m = pos.parse_san(san)
                        if m is None:
                            bad.append(f"{where}: @try {san}: not legal in {pos.fen()}")
                        else:
                            ms.append(m)
                    if engine and ms:
                        best, bm = engine.score(pos.fen(), [], nodes)
                        for san, m in zip(good, ms, strict=False):
                            if B.uci(m) == bm:
                                continue
                            after, _ = engine.score(pos.fen(), [B.uci(m)], nodes)
                            loss = E.win_chance(best) - E.win_chance(-after)
                            if loss > 0.10 and not page_allows_any(page):
                                bad.append(f"{where}: @try {san} loses {loss:.2f} (best {bm}) in {pos.fen()}")
                    if ms:
                        pos.push(ms[0])
                elif word == "drill":
                    p = rest.split()
                    if p[0] not in themes:
                        bad.append(f"{where}: drill theme {p[0]}")
                else:
                    bad.append(f"{where}: unknown @{word}")
        if words > 260:
            bad.append(f"{name}: {words} words is too long for a short lesson")
    for line in bad:
        print(line)
    print(f"{len(names)} lessons of {len(wanted)}: {len(bad)} wrong", file=sys.stderr)
    return 1 if bad else 0


def page_allows_any(page):
    """A @try teaching only how a piece moves says so: `# any` on its page."""
    return "@any" in page


if __name__ == "__main__":
    sys.exit(main(sys.argv))
