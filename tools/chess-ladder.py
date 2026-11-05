#!/usr/bin/env python3
"""tools/chess-ladder.py — how far apart kawa-chess's opponent levels really are: two levels play each other
with the settings the app uses, colours by turns, first moves varied; the score gives the Elo gap. UCI_Elo is an
engine scale (Stockfish's docs: 120+1 s, anchored to CCRL) and below its floor of 1320 the levels are our own, so this
is the only measure there is. The result: docs/learn/chess/ladder.md.

  python3 -I -B tools/chess-ladder.py LEVEL_A LEVEL_B GAMES [SEED]   prints: A B A's score games gap (B's lead)
"""
import math
import pathlib
import random
import subprocess
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "configs/home/.local/lib/fedokawaii/kawa-chess"))
import board as B  # noqa: E402
import engine as E  # noqa: E402


class Sync:
    """One Stockfish, driven in turn: enough for a match, nothing shared with the app's loop but its requests."""

    def __init__(self, path):
        self.p = subprocess.Popen([path], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1)
        self.set = {}
        self.cmd("uci")
        self.until("uciok")

    def cmd(self, s):
        self.p.stdin.write(s + "\n")
        self.p.stdin.flush()

    def until(self, word):
        while True:
            line = self.p.stdout.readline()
            if line.startswith(word):
                return line

    def search(self, s):
        for k, v in {"MultiPV": s.multipv, **s.options}.items():
            if self.set.get(k) != v:
                self.cmd(f"setoption name {k} value {v}")
                self.set[k] = v
        self.cmd(f"position fen {s.fen}" + (" moves " + " ".join(s.moves) if s.moves else ""))
        self.cmd("go " + s.go)
        while True:
            line = self.p.stdout.readline().strip()
            if line.startswith("info ") and " pv " in line:
                E.Engine._info(s, line)
            elif line.startswith("bestmove"):
                parts = line.split()
                s.best = parts[1] if len(parts) > 1 and parts[1] != "(none)" else None
                return s

    def close(self):
        self.p.kill()


def reply(engine, game, elo, rng):
    moves = [B.uci(m) for m in game.moves]
    legal = [B.uci(m) for m in game.pos.legal()]
    if isinstance(elo, tuple):            # (a trial: temperature, wild, depth)
        temp, wild, depth = elo
        if rng.random() < wild:
            return rng.choice(legal)
        s = E.Search(game.start, moves, f"depth {depth}", None, multipv=60, options={"UCI_LimitStrength": "false", "Skill Level": 20})
        engine.search(s)
        lines = [ln for ln in s.ranked() if ln.pv]
        clamp = [max(-1000, min(1000, ln.score())) for ln in lines]
        top = max(clamp)
        w = [math.exp((v - top) / temp) for v in clamp]
        u = rng.choices([ln.pv[0] for ln in lines], weights=w)[0] if lines else rng.choice(legal)
        return u if u in legal else rng.choice(legal)
    s = E.play_request(game.start, moves, elo, None)
    engine.search(s)
    if elo < 1320:
        u = E.choose_weak(s, legal, elo, rng)
    else:
        u = s.best
    return u if u in legal else rng.choice(legal)


def _level(text):
    """1320, or a trial T400:W0.1:D1 (temperature, chance of any move, search depth)."""
    if text.startswith("T"):
        t, w, d = text[1:].split(":")
        return float(t), float(w[1:]), int(d[1:])
    return int(text)


def main(argv):
    a, b, n = _level(argv[1]), _level(argv[2]), int(argv[3])
    rng = random.Random(int(argv[4]) if len(argv) > 4 else hash((argv[1], argv[2])) & 0xffff)
    path = __import__("shutil").which("stockfish") or "stockfish"
    ea, eb = Sync(path), Sync(path)
    score = 0.0
    played = 0
    for i in range(n):
        g = B.Game()
        for _ in range(2):              # (two random plies a side: no two games alike)
            for _ in range(2):
                g.play(rng.choice(g.pos.legal()))
        a_white = i % 2 == 0
        while not g.over() and len(g.moves) < 400:
            white = g.pos.turn == B.WHITE
            mine = white == a_white
            u = reply(ea if mine else eb, g, a if mine else b, rng)
            g.play(B.from_uci(u))
        if g.result == "*" or g.result == "1/2-1/2":
            score += 0.5
        elif (g.result == "1-0") == a_white:
            score += 1
        played += 1
    ea.close()
    eb.close()
    s = max(0.5 / played, min(1 - 0.5 / played, score / played))
    print(argv[1], argv[2], score, played, round(400 * math.log10((1 - s) / s)))     # (the gap: how much stronger b is than a)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
