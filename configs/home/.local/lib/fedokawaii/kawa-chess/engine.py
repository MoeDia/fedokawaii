"""Stockfish over UCI, in a process of its own, never blocking the screen; and how it plays weakly.

One search at a time. A search that is not answered in its time is stopped; an engine that dies or
hangs is started again and the search asked once more, so nothing above ever sees it go.
"""
import math
import os
import random
import signal
import subprocess
import time

ENGINE = "stockfish"
GRACE = 3.0                 # seconds past a search's budget before it is stopped, then again before a kill


def win_chance(cp):
    return 0.5 + 0.5 * (2 / (1 + math.exp(-0.00368208 * cp)) - 1)


class Search:
    """What a search was asked and what came back: root moves best first with their scores."""
    __slots__ = ("fen", "moves", "go", "multipv", "budget", "done", "lines", "best", "options", "tag", "asked_at", "stopping", "tries", "cancelled")

    def __init__(self, fen, moves, go, done, multipv=1, budget=5.0, options=None, tag=None):
        self.fen, self.moves, self.go, self.done = fen, list(moves), go, done
        self.multipv, self.budget, self.options, self.tag = multipv, budget, options or {}, tag
        self.lines = {}             # multipv index → Line
        self.best = None
        self.asked_at = None
        self.stopping = False
        self.tries = 0
        self.cancelled = False

    def ranked(self):
        return [self.lines[k] for k in sorted(self.lines)]


class Line:
    """A principal variation as the engine last gave it, from the side to move's point of view."""
    __slots__ = ("cp", "mate", "wdl", "pv", "depth", "nodes")

    def __init__(self):
        self.cp, self.mate, self.wdl, self.pv, self.depth, self.nodes = 0, None, None, [], 0, 0

    def score(self):
        """Centipawns; a mate as far beyond any material as it is near."""
        if self.mate is not None:
            return (30000 - 100 * abs(self.mate)) * (1 if self.mate > 0 else -1)
        return self.cp

    def expected(self):
        """Expected points for the side to move, 0–1: Lichess's win chance, fitted on real games by human
        players (lichess.org/page/accuracy) — Stockfish's own WDL model is fitted to engines."""
        return win_chance(self.score())


class Engine:
    def __init__(self):
        self.proc = None
        self.fd = None
        self.buf = b""
        self.ready = False
        self.queue = []
        self.current = None
        self.set = {}               # the options as last sent
        self.failed = None          # why it cannot run at all (no program)
        self.last_used = time.monotonic()
        self.restarts = []          # when it was last started again after dying

    # ── the process ──────────────────────────────────────────────────────────────────────────
    def start(self):
        if self.proc:
            return True
        try:
            self.proc = subprocess.Popen([ENGINE], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                         stderr=subprocess.DEVNULL, bufsize=0, start_new_session=True,
                                         preexec_fn=lambda: os.nice(5))
        except OSError as e:
            self.failed = f"{ENGINE}: {e.strerror or e}"
            return False
        self.fd = self.proc.stdout.fileno()
        os.set_blocking(self.fd, False)
        self.buf = b""
        self.ready = False
        self.set = {}
        self.failed = None
        self.send("uci")
        return True

    def stop_process(self):
        """Gone, at once: Stockfish holds its net in memory, and nothing here needs it now."""
        p, self.proc, self.fd, self.ready = self.proc, None, None, False
        if p is None:
            return
        try:
            p.stdin.close()
        except OSError:
            pass
        try:
            os.killpg(p.pid, signal.SIGKILL)
        except OSError:
            pass
        try:
            p.stdout.close()
        except OSError:
            pass
        try:
            p.wait(timeout=1)
        except subprocess.TimeoutExpired:
            pass

    def send(self, text):
        if not self.proc:
            return
        try:
            self.proc.stdin.write(text.encode() + b"\n")
        except OSError:
            self._lost()

    def fileno(self):
        return self.fd

    def idle(self):
        return self.current is None and not self.queue

    def _lost(self):
        """The engine is gone (killed, crashed): start it again; what was being searched is asked again."""
        cur = self.current
        self.stop_process()
        self.current = None
        now = time.monotonic()
        self.restarts = [t for t in self.restarts if now - t < 20] + [now]
        if len(self.restarts) > 5:     # (it dies as it starts: nothing to wait for)
            self.failed = f"{ENGINE} keeps dying"
            waiting = ([cur] if cur is not None and not cur.cancelled else []) + self.queue
            self.queue = []
            for s in waiting:
                s.best = None
                s.done(s)
            return
        if cur is not None and not cur.cancelled:
            cur.tries += 1
            cur.lines, cur.best, cur.stopping = {}, None, False
            if cur.tries > 3:
                cur.best = None
                cur.done(cur)
            else:
                self.queue.insert(0, cur)
        if self.queue:
            self.start()

    # ── asking ───────────────────────────────────────────────────────────────────────────────
    def ask(self, search):
        self.last_used = time.monotonic()
        self.queue.append(search)
        if not self.start():
            self.queue.remove(search)
            search.best = None
            search.done(search)
            return
        self._next()

    def cancel_all(self):
        """Nothing that was asked is wanted any more."""
        self.queue = []
        if self.current is not None:
            self.current.cancelled = True
            if not self.current.stopping:
                self.current.stopping = True
                self.send("stop")

    def _next(self):
        if not self.ready or self.current is not None or not self.queue or not self.proc:
            return
        s = self.current = self.queue.pop(0)
        want = {"MultiPV": s.multipv, **s.options}
        for k, v in want.items():
            if self.set.get(k) != v:
                self.send(f"setoption name {k} value {v}")
                self.set[k] = v
        tail = " moves " + " ".join(s.moves) if s.moves else ""
        self.send(f"position fen {s.fen}{tail}")
        self.send("go " + s.go)
        s.asked_at = time.monotonic()
        s.lines, s.best, s.stopping = {}, None, False

    def on_input(self):
        """The engine has written: whole lines are read and acted on."""
        if not self.proc:
            return
        try:
            data = os.read(self.fd, 65536)
        except BlockingIOError:
            return
        except OSError:
            data = b""
        if not data:
            self._lost()
            return
        self.buf += data
        lines = self.buf.split(b"\n")
        self.buf = lines.pop()
        for raw in lines:
            self._line(raw.decode("ascii", "replace").strip())

    def tick(self, now):
        """Called now and then: a search past its budget is stopped; one that will not stop, killed."""
        s = self.current
        if s is not None and s.asked_at is not None:
            over = now - s.asked_at - s.budget
            if over > GRACE * 2:
                self._lost()
            elif over > GRACE and not s.stopping:
                s.stopping = True
                self.send("stop")
        elif self.proc and self.current is None and not self.queue and not self.ready and now - self.last_used > 10:
            self._lost()               # (never said uciok)

    def _line(self, line):
        if line == "uciok":
            self.send("setoption name Threads value 1")
            self.send("isready")
            return
        if line == "readyok":
            self.ready = True
            self._next()
            return
        s = self.current
        if s is None:
            return
        if line.startswith("info ") and " pv " in line:
            self._info(s, line)
        elif line.startswith("info ") and " score " in line and " multipv " not in line and not s.lines:
            self._info(s, line)        # (mate at the root, or no moves: no pv is sent)
        elif line.startswith("bestmove"):
            parts = line.split()
            s.best = parts[1] if len(parts) > 1 and parts[1] != "(none)" else None
            self.current = None
            self.last_used = time.monotonic()
            if not s.cancelled:
                s.done(s)
            self._next()

    @staticmethod
    def _info(s, line):
        t = line.split()
        n = len(t)
        i, pv_i = 1, 1
        cp, mate, wdl, pv, depth, nodes = 0, None, None, [], 0, 0
        while i < n:
            k = t[i]
            if k == "multipv":
                pv_i = int(t[i + 1])
                i += 2
            elif k == "depth":
                depth = int(t[i + 1])
                i += 2
            elif k == "nodes":
                nodes = int(t[i + 1])
                i += 2
            elif k == "score":
                if t[i + 1] == "cp":
                    cp = int(t[i + 2])
                else:
                    mate = int(t[i + 2])
                i += 3
                if i < n and t[i] in ("lowerbound", "upperbound"):
                    return                 # (a bound, not a score: the next line has it)
            elif k == "wdl":
                wdl = (int(t[i + 1]), int(t[i + 2]), int(t[i + 3]))
                i += 4
            elif k == "pv":
                pv = t[i + 1:]
                break
            else:
                i += 2
        ln = s.lines.get(pv_i) or Line()
        ln.cp, ln.mate, ln.wdl, ln.depth, ln.nodes = cp, mate, wdl, depth, nodes
        if pv or not ln.pv:
            ln.pv = pv
        s.lines[pv_i] = ln


# ── playing weakly ───────────────────────────────────────────────────────────────────────────
# Below Stockfish's own floor (UCI_Elo 1320) a move is drawn from a depth-1 search's root moves by how
# good they are: the lower the level, the flatter the draw and the more often any legal move at all, so
# a weak opponent hangs pieces and misses mates, as a beginner does. From 1320 up: Stockfish's own limit
# (Skill Level through UCI_Elo: src/search.h). The levels are one scale measured by tools/chess-ladder.py,
# engine against engine, anchored at Stockfish's 1320 (docs/learn/chess/ladder.md): an engine pool's
# numbers, not chess.com's (Stockfish's own FAQ: no human scale can be claimed).
_WEAK = (              # level, temperature in cp, chance of any legal move (measured: 200 games a pair)
    (290, 1e5, 1.00),
    (317, 1500.0, 0.30),
    (350, 800.0, 0.20),
    (400, 500.0, 0.15),
    (445, 350.0, 0.10),
    (515, 250.0, 0.07),
    (615, 180.0, 0.05),
    (760, 130.0, 0.03),
    (930, 90.0, 0.02),
    (1140, 60.0, 0.01),
    (1320, 40.0, 0.00),
)


def weakness(elo):
    """(temperature, chance of any legal move) at a level below 1320, between the table's rows."""
    rows = _WEAK
    if elo <= rows[0][0]:
        return rows[0][1:]
    for (e0, t0, b0), (e1, t1, b1) in zip(rows, rows[1:]):
        if elo <= e1:
            a = (elo - e0) / (e1 - e0)
            return t0 * (t1 / t0) ** a, b0 + (b1 - b0) * a
    return rows[-1][1:]


def choose_weak(search, legal_uci, elo, rng=random):
    """A move at level elo from a shallow multi-line search (the moves in UCI)."""
    temp, wild = weakness(elo)
    if rng.random() < wild:
        return rng.choice(legal_uci)
    lines = [ln for ln in search.ranked() if ln.pv]
    if not lines:
        return rng.choice(legal_uci)
    # (a mate counts as a thousand: the weakest levels miss even that, sometimes)
    clamp = [max(-1000, min(1000, ln.score())) for ln in lines]
    top = max(clamp)
    weights = [math.exp((v - top) / temp) for v in clamp]
    r = rng.random() * sum(weights)
    for ln, w in zip(lines, weights):
        r -= w
        if r <= 0:
            return ln.pv[0]
    return lines[0].pv[0]


def play_request(fen, moves, elo, done, tag=None):
    """The Search that gets the engine's reply at a level. Weak: every root move at a small depth (the
    choice is made by choose_weak afterwards). From 1320: its own UCI_Elo over a node budget (never the
    clock's mercy: the same strength whatever else this machine is doing)."""
    if elo < 1320:
        return Search(fen, moves, "depth 1", done, multipv=60, budget=3.0, tag=tag,
                      options={"UCI_LimitStrength": "false", "Skill Level": 20})
    nodes = 30000 if elo < 2200 else 200000 if elo < 2600 else 1000000
    return Search(fen, moves, f"nodes {nodes}", done, budget=6.0, tag=tag,
                  options={"UCI_LimitStrength": "true", "UCI_Elo": min(elo, 3190)})


def analysis_request(fen, moves, done, nodes=120000, multipv=2, tag=None):
    """An honest look at a position: the full strength, a number of nodes (the same whatever the load)."""
    return Search(fen, moves, f"nodes {nodes}", done, multipv=multipv, budget=20.0, tag=tag,
                  options={"UCI_LimitStrength": "false", "Skill Level": 20})
