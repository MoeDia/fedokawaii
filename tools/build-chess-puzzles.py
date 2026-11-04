#!/usr/bin/env python3
"""tools/build-chess-puzzles.py — the puzzles kawa-chess ships: a subset of Lichess's puzzle database (CC0,
https://database.lichess.org/#puzzles), by theme and rating band, the well-rated and often-played ones,
every line checked against the rules. Deterministic: the same dump gives the same file.

  curl -LO https://database.lichess.org/lichess_db_puzzle.csv.zst
  zstd -dc lichess_db_puzzle.csv.zst | python3 -I -B tools/build-chess-puzzles.py SHA256 > \
      configs/home/.local/share/fedokawaii/chess/puzzles.tsv

Out: a head of comments, then id, FEN, moves, rating, themes (only those the course names), tab-separated.
"""
import heapq
import hashlib
import pathlib
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "configs/home/.local/lib/fedokawaii/kawa-chess"))
import board as B  # noqa: E402

THEMES = """hangingPiece mateIn1 mateIn2 mateIn3 mateIn4 backRankMate fork pin skewer discoveredAttack doubleCheck
discoveredCheck deflection attraction capturingDefender clearance interference intermezzo xRayAttack trappedPiece
sacrifice quietMove defensiveMove advancedPawn promotion underPromotion enPassant attackingF2F7 kingsideAttack
queensideAttack exposedKing smotheredMate arabianMate anastasiaMate bodenMate dovetailMate hookMate doubleBishopMate
pawnEndgame rookEndgame bishopEndgame knightEndgame queenEndgame queenRookEndgame zugzwang opening middlegame
endgame equality""".split()
KEEP = set(THEMES)
BAND = 200
FLOOR, ROOF = 400, 2600


def cap(theme, band):
    if theme in ("opening", "middlegame", "endgame"):
        return 180
    return 90 if band < 1000 else 60


def main(argv):
    sha = argv[1] if len(argv) > 1 else "?"
    heaps = {}
    general = {}
    for line in sys.stdin:
        p = line.rstrip("\n").split(",")
        if p[0] == "PuzzleId" or len(p) < 8:
            continue
        rating, rd, pop, plays = int(p[3]), int(p[4]), int(p[5]), int(p[6])
        if rd > 80 or pop < 85 or plays < 200 or not FLOOR <= rating < ROOF:
            continue
        band = rating // BAND * BAND
        h = int.from_bytes(hashlib.blake2b(p[0].encode(), digest_size=6).digest(), "big")
        themes = [t for t in p[7].split() if t in KEEP]
        row = (p[0], p[1], p[2], rating, " ".join(themes))
        for t in themes:
            q = heaps.setdefault((t, band), [])
            n = cap(t, band)
            if len(q) < n:
                heapq.heappush(q, (-h, row))
            elif -q[0][0] > h:
                heapq.heapreplace(q, (-h, row))
        q = general.setdefault(band, [])
        if len(q) < 400:
            heapq.heappush(q, (-h, row))
        elif -q[0][0] > h:
            heapq.heapreplace(q, (-h, row))
    chosen = {}
    for q in list(heaps.values()) + list(general.values()):
        for _, row in q:
            chosen[row[0]] = row
    out = [f"# Lichess puzzle database (CC0): https://database.lichess.org/#puzzles — a subset, dump sha256 {sha}",
           "# tools/build-chess-puzzles.py writes this: id, FEN, moves (the opponent's first), rating, themes"]
    bad = 0
    for pid in sorted(chosen):
        row = chosen[pid]
        try:
            pos = B.Position(row[1])
            for u in row[2].split():
                m = B.from_uci(u)
                if m not in pos.legal():
                    raise ValueError(u)
                pos.push(m)
        except ValueError:
            bad += 1
            continue
        out.append("\t".join(str(x) for x in row))
    sys.stdout.write("\n".join(out) + "\n")
    print(f"{len(out) - 2} puzzles, {bad} refused", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
