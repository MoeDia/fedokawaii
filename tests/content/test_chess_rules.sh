#!/usr/bin/env bash
# tests/content/test_chess_rules.sh — kawa-chess's rules (board.py) held to the numbers everyone uses (perft) and,
# when Stockfish is here, to Stockfish itself; every rule a game can end on; SAN, FEN, PGN both ways; exchanges.
. "$(dirname "$0")/lib.sh"
sandbox
LIB=$REPO/configs/home/.local/lib/fedokawaii/kawa-chess
run() { python3 -I -B - "$LIB"; }

case_ "perft: the six positions of the chess programming wiki, to the node"
eq "$(run <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import board as B
T = [(B.START, [20, 400, 8902, 197281]),
     ("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1", [48, 2039, 97862]),
     ("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1", [14, 191, 2812, 43238]),
     ("r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1", [6, 264, 9467]),
     ("r2q1rk1/pP1p2pp/Q4n2/bbp1p3/Np6/1B3NBn/pPPP1PPP/R3K2R b KQ - 0 1", [6, 264, 9467]),
     ("rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8", [44, 1486, 62379]),
     ("r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10", [46, 2079, 89890])]
bad = [(f, d + 1, B.perft(B.Position(f), d + 1), n) for f, ns in T for d, n in enumerate(ns) if B.perft(B.Position(f), d + 1) != n]
print(bad or "all right")
PY
)" "all right"

case_ "FEN: what is not a position is refused; round trips"
eq "$(run <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import board as B
bad = ["", "garbage", "8/8/8/8/8/8/8/8 w - - 0 1", "9/8/8/8/8/8/8/K6k w - - 0 1", "ppp/8/8/8/8/8/8/K6k w - - 0 1",
       "K6k/8/8/8/8/8/8/8 x - - 0 1", "P6k/8/8/8/8/8/8/K7 w - - 0 1", "4k3/8/8/8/8/8/8/4R1K1 w - - 0 1",
       "KK5k/8/8/8/8/8/8/8 w - - 0 1", "8/8/8/8/8/8/8/K6k w ZZ - 0 1", "8/8/8/8/8/8/8/K6k w - z9 0 1", "8/8/8/8/8/8/8/K6k w - - x 1", "8/8/8/8/8/8/8/K6k w - - 0 -3"]
wrong = []
for f in bad:
    try:
        B.Position(f)
        wrong.append(f)
    except ValueError:
        pass
good = [B.START, "r3k2r/8/8/8/8/8/8/R3K2R b KQkq - 5 9", "4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 2"]
wrong += [f for f in good if B.Position(f).fen() != f]
# an en passant square no pawn crossed, castling rights with nothing to castle: not believed
if B.Position("4k3/8/8/4P3/8/8/8/4K3 w - d6 0 2").ep != -1:
    wrong.append("ep")
if B.Position("4k3/8/8/8/8/8/8/4K3 w KQkq - 0 1").castle != 0:
    wrong.append("castle")
print(wrong or "all right")
PY
)" "all right"

case_ "the ends of a game: mate, stalemate, three times, fifty moves, nothing left to mate with"
eq "$(run <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import board as B
out = []
g = B.Game()
for s in "f3 e5 g4 Qh4#".split():
    g.play(g.pos.parse_san(s))
out.append((g.result, g.why))
out.append(((g2 := B.Game("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")).result, g2.why))
g3 = B.Game("7k/8/8/8/8/8/8/K5Q1 w - - 0 1")
for s in "Qg2 Kh7 Qg1 Kh8 Qg2 Kh7 Qg1 Kh8".split():
    if not g3.over():
        g3.play(g3.pos.parse_san(s))
out.append((g3.result, g3.why))
out.append(((g4 := B.Game("7k/8/8/8/8/8/8/K5Q1 w - - 99 80")).result, g4.why))
g4.play(g4.pos.parse_san("Qg2"))
out.append((g4.result, g4.why))
for f in ("7k/8/8/8/8/8/8/K7 w - - 0 1", "7k/8/8/8/8/8/8/KB6 w - - 0 1", "7k/8/8/8/8/8/8/KN6 w - - 0 1", "6bk/8/8/8/8/8/8/KB6 w - - 0 1"):
    out.append(B.Game(f).why)
out.append(B.Game("7k/8/8/8/8/8/8/KBB5 w - - 0 1").why)   # (two bishops can mate)
out.append(B.Game("5b1k/8/8/8/8/8/8/KB6 w - - 0 1").why)  # (bishops of two colours can)
print(out)
PY
)" "[('0-1', 'checkmate'), ('1/2-1/2', 'stalemate'), ('1/2-1/2', 'threefold repetition'), ('*', ''), ('1/2-1/2', 'the fifty-move rule'), 'insufficient material', 'insufficient material', 'insufficient material', 'insufficient material', '', '']"

case_ "what a move can be typed as: lower case, no x, from-to, castling with zeros, the promotion's forms"
eq "$(run <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import board as B
p = B.Position("r3k2r/1P6/8/3p4/4P3/5N2/8/R3K2R w KQkq - 0 1")
names = {t: (p.parse_san(t) and B.uci(p.parse_san(t))) for t in ("Nd4", "nd4", "exd5", "ed5", "ed", "e4d5", "O-O", "0-0", "oo", "o-o-o", "bxa8=Q", "bxa8q", "b7a8q", "bxa8=N+", "Ng5!", "Nd4?!", "Qd1", "e9")}
print(names)
q = B.Position("r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 0 1")
print(B.uci(q.parse_san("bc3")) if q.parse_san("bc3") else None, [B.uci(m) for m in B.matching(q, "Bb")[0]], B.uci(q.parse_san("Bb5")))
PY
)" "{'Nd4': 'f3d4', 'nd4': 'f3d4', 'exd5': 'e4d5', 'ed5': 'e4d5', 'ed': 'e4d5', 'e4d5': 'e4d5', 'O-O': 'e1g1', '0-0': 'e1g1', 'oo': 'e1g1', 'o-o-o': 'e1c1', 'bxa8=Q': 'b7a8q', 'bxa8q': 'b7a8q', 'b7a8q': 'b7a8q', 'bxa8=N+': 'b7a8n', 'Ng5!': 'f3g5', 'Nd4?!': 'f3d4', 'Qd1': None, 'e9': None}
None ['f1b5'] f1b5"

case_ "SAN: disambiguation by file, rank, both; check and mate marks; PGN out and back, with a set position"
eq "$(run <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import board as B
p = B.Position("3k4/8/8/R6R/8/R7/8/4K3 w - - 0 1")
print(p.san(B.mv(B.sq_of("h5"), B.sq_of("c5"))), p.san(B.mv(B.sq_of("a5"), B.sq_of("a4"))), p.san(B.mv(B.sq_of("a3"), B.sq_of("a4"))))
q = B.Position("1N1k4/8/8/8/1N3N2/8/8/4K3 w - - 0 1")
print(q.san(B.mv(B.sq_of("b4"), B.sq_of("d5"))))
g = B.Game("4k3/P7/8/8/8/8/8/4K3 w - - 0 1")
g.play(g.pos.parse_san("a8=Q+"))
tags, h = B.read_pgn(g.pgn({"White": 'a "quoted" name'}))
print(g.sans, h.pos.fen() == g.pos.fen(), tags["White"])
t, r = B.read_pgn('[Event "x"]\n\n1. e4 {a comment} (1. d4 d5 (1... Nf6)) e5! $1 2. Nf3 ; a line comment\nNc6 1-0')
print([B.uci(m) for m in r.moves], r.result, r.why)
for bad in ("1. e4 e5 2. Ke3 Ke6 3. Qd8", "nothing here at all", "1. e4 (unclosed"):
    try:
        B.read_pgn(bad)
        print("read", bad)
    except ValueError:
        print("refused")
PY
)" "Rhc5 R5a4 R3a4
Nbd5
['a8=Q+'] True a quoted name
['e2e4', 'e7e5', 'g1f3', 'b8c6'] 1-0 as recorded
refused
refused
refused"

case_ "exchanges: free, guarded, outnumbered, x-rays behind, the king who cannot take into a guard"
eq "$(run <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import board as B
S = B.sq_of
print(B.Position("4k3/8/8/3p4/8/2N5/8/4K3 w - - 0 1").see(S("d5"), 0),            # free pawn
      B.Position("4k3/8/2p5/3p4/8/2N5/8/4K3 w - - 0 1").see(S("d5"), 0),          # guarded: would lose a knight
      B.Position("4k3/8/5n2/3p4/8/2N1N3/8/4K3 w - - 0 1").see(S("d5"), 0),        # 2 attackers, 1 guard
      B.Position("3rk3/8/8/3p4/8/8/3R4/3RK3 w - - 0 1").see(S("d5"), 0),          # rooks: x-ray
      B.Position("4k3/8/8/8/8/5q2/4K3/5r2 w - - 0 1").see(S("f3"), 0),            # the king may not take a guarded queen
      )
print(sorted(B.sq_name(s) for s in B.Position("4k3/8/8/3n4/8/8/8/R2QK3 b - - 0 1").hanging(0)),
      sorted(B.sq_name(s) for s in B.Position("4k3/8/8/3n4/1B6/8/8/R2QK3 b - - 0 1").hanging(0)),
      sorted(B.sq_name(s) for s in B.Position("4k3/8/8/3n4/8/8/8/3QK3 b - - 0 1").hanging(1)))
PY
)" "1 0 1 1 0
[] ['b4'] ['d5']"

STOCKFISH=${KAWA_TEST_STOCKFISH:-$(command -v stockfish 2>/dev/null)}
if [[ -n $STOCKFISH ]]; then
  case_ "random walks: our legal moves are Stockfish's, in every position of 30 games"
  eq "$(python3 -I -B - "$LIB" "$STOCKFISH" <<'PY'
import random, re, subprocess, sys
sys.path.insert(0, sys.argv[1])
import board as B
sf = subprocess.Popen([sys.argv[2]], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1)
def cmd(s):
    sf.stdin.write(s + "\n"); sf.stdin.flush()
cmd("uci")
while sf.stdout.readline().strip() != "uciok":
    pass
def moves(fen):
    cmd(f"position fen {fen}"); cmd("go perft 1")
    out = []
    while True:
        line = sf.stdout.readline().strip()
        if line.startswith("Nodes searched"):
            sf.stdout.readline()
            return sorted(out)
        m = re.fullmatch(r"([a-h][1-8][a-h][1-8][nbrq]?): \d+", line)
        if m:
            out.append(m[1])
rng = random.Random(11)
bad = 0
for _ in range(30):
    g = B.Game()
    while not g.over() and len(g.moves) < 200:
        ms = g.pos.legal()
        if sorted(B.uci(m) for m in ms) != moves(g.pos.fen()):
            bad += 1
            print("differs at", g.pos.fen())
            break
        g.play(rng.choice(ms))
cmd("quit")
print(bad)
PY
)" "0"
else skip "no Stockfish here: the positions of random games not compared"; fi
done_
