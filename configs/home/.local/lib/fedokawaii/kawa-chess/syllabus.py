"""The fifty-two weeks: what each is for, its lessons, its puzzles, and its fourteen games. Data only.

A game: goal (one sentence, what this game is for), start (a line of moves from LINES, or a position
from POS, or odds "q"/"r"/"n": the opponent starts without it), you (0 white, 1 black; none: by turns),
off (the level against your own), elo (a fixed level, for technique), check (how the review measures
the goal: review.py GOALS), clock, hints, threats. docs/learn/chess/curriculum.md is written from this.
"""
import board as B

# the opening lines of the repertoire: moves already on the board when the game begins
LINES = {
    "italian": "e4 e5 Nf3 Nc6 Bc4 Bc5",
    "two-knights": "e4 e5 Nf3 Nc6 Bc4 Nf6",
    "scotch-gambit": "e4 e5 Nf3 Nc6 d4 exd4",
    "alapin": "e4 c5 c3",
    "caro-advance": "e4 c6 d4 d5 e5",
    "french-advance": "e4 e6 d4 d5 e5",
    "scandinavian": "e4 d5 exd5 Qxd5 Nc3",
    "pirc": "e4 d6 d4 Nf6 Nc3",
    "e5-italian": "e4 e5 Nf3 Nc6 Bc4 Nf6",
    "e5-scotch": "e4 e5 Nf3 Nc6 d4 exd4 Nxd4 Nf6",
    "e5-ruy": "e4 e5 Nf3 Nc6 Bb5 a6",
    "qgd": "d4 d5 c4 e6 Nc3 Nf6",
    "london-black": "d4 d5 Nf3 Nf6 Bf4 e6",
    "english-black": "c4 e5 Nc3 Nf6",
}
# positions: you are the side named, moving as the FEN says
POS = {
    "rook-v-pawns": ("4k3/ppp5/8/8/8/8/8/R3K3 w - - 0 1", 0),
    "bishop-v-pawns": ("4k3/ppp5/8/8/8/8/8/2B1K3 w - - 0 1", 0),
    "knight-v-pawns": ("4k3/ppp5/8/8/8/8/8/1N2K3 w - - 0 1", 0),
    "queen-v-pawns": ("4k3/pppppppp/8/8/8/8/8/3QK3 w - - 0 1", 0),
    "pawn-war": ("4k3/pppppppp/8/8/8/8/PPPPPPPP/4K3 w - - 0 1", 0),
    "two-rooks": ("8/8/8/4k3/8/8/8/R3K2R w - - 0 1", 0),
    "kq-k": ("8/8/8/4k3/8/8/8/3QK3 w - - 0 1", 0),
    "kr-k": ("8/8/8/4k3/8/8/8/R3K3 w - - 0 1", 0),
    "kq-k-corner": ("7k/8/8/8/8/8/Q7/K7 w - - 0 1", 0),
    "kr-k-far": ("8/8/3k4/8/8/8/8/K6R w - - 0 1", 0),
    "kp-k-ahead": ("8/8/8/4k3/8/4K3/4P3/8 b - - 0 1", 0),
    "kp-k-opposition": ("4k3/8/4K3/4P3/8/8/8/8 w - - 0 1", 0),
    "kp-k-hold": ("8/8/8/4k3/8/4P3/4K3/8 b - - 0 1", 1),
    "two-pawns": ("8/8/4k3/8/3PP3/4K3/8/8 w - - 0 1", 0),
    "lucena": ("1K1k4/1P6/8/8/8/8/r7/2R5 w - - 0 1", 0),
    "philidor": ("4k3/7R/r7/3KP3/8/8/8/8 b - - 0 1", 1),
    "q-v-pawn": ("K7/8/8/8/8/8/3pk3/7Q w - - 0 1", 0),
    "rook-behind": ("r7/8/8/P3k3/8/5P2/5K2/R7 w - - 0 1", 0),
    "active-rook": ("8/5pk1/6p1/7p/P6P/6P1/r4PK1/1R6 w - - 0 1", 0),
    "bishop-good": ("2b5/4k3/p3p1p1/1p1pP3/1P1P4/P2BK1P1/8/8 w - - 0 1", 0),
    "knight-outpost": ("r4rk1/pp3ppp/2p5/3pP3/3n4/8/PP3PPP/R1BR2K1 b - - 0 1", 1),
    "bishop-v-knight": ("8/4kp2/4p1p1/3nP3/5P2/2B3P1/5K2/8 w - - 0 1", 0),
    "outside-passer": ("8/5pk1/6p1/8/P5P1/5K2/8/8 w - - 0 1", 0),
    "iqp-white": ("r1bq1rk1/pp2bppp/2n1pn2/8/3P4/2N2N2/PP2BPPP/R1BQ1RK1 w - - 0 1", 0),
    "iqp-black": ("r1bq1rk1/pp2bppp/2n1pn2/8/3P4/2N2N2/PP2BPPP/R1BQ1RK1 b - - 0 1", 1),
    "greek-gift": ("r1bq1rk1/pppn1ppp/4p3/3pP3/1b1P4/2NB1N2/PPP2PPP/R1BQK2R w KQ - 0 8", 0),
    "open-file": ("1r4k1/pp3ppp/2p5/8/8/2P5/PP3PPP/3R2K1 w - - 0 1", 0),
    "worse-rook": ("8/5pk1/4p1p1/3p3p/3P1P1P/r3P1P1/5K2/1R6 b - - 0 1", 1),
    "down-exchange": ("r5k1/5ppp/8/3p4/3n4/5P2/5KPP/1R6 w - - 0 1", 0),
    "up-a-piece": ("2r3k1/5ppp/8/8/3N4/4P3/5PPP/3R2K1 w - - 0 1", 0),
    "up-a-pawn": ("3r2k1/5ppp/8/8/8/4PP2/5KPP/2R5 w - - 0 1", 0),
    "up-a-queen": ("8/5pkp/6p1/8/8/8/Q4PPP/6K1 w - - 0 1", 0),
}
ODDS = {"q": "d", "r": "a", "n": "b"}


def start_of(g, colour):
    """(start FEN, the moves already played, UCI) for a game of the syllabus, as `colour` plays it."""
    if "pos" in g:
        return POS[g["pos"]][0], []
    if "bank" in g:
        return bank_position(g, colour)
    if "odds" in g:
        # the opponent's man taken off the start position
        rows = B.START.split()[0].split("/")
        kind = g["odds"]
        back = rows[0] if colour == B.WHITE else rows[7]
        i = {"q": 3, "r": 0, "n": 1}[kind]
        filled = back[:i] + "1" + back[i + 1:]
        if colour == B.WHITE:
            rows[0] = _compact(filled)
        else:
            rows[7] = _compact(filled)
        fen = "/".join(rows) + (" w KQk - 0 1" if colour == B.WHITE and kind == "r" else " w Qkq - 0 1" if kind == "r" else " w KQkq - 0 1")
        return fen, []
    if "line" in g:
        pos = B.Position()
        out = []
        for san in LINES[g["line"]].split():
            m = pos.parse_san(san)
            out.append(B.uci(m))
            pos.push(m)
        return B.START, out
    return B.START, []


def bank_position(g, _colour):
    """A placeholder until a game's number chooses from the bank (course.py game_spec)."""
    return B.START, []


def _compact(row):
    """Digits side by side added up, as a FEN writes them."""
    out, gap = "", 0
    for ch in row:
        if ch.isdigit():
            gap += int(ch)
        else:
            out += (str(gap) if gap else "") + ch
            gap = 0
    return out + (str(gap) if gap else "")


# the ladder: who sits across the board at each level — from a harmless tree spirit to the oni's king
LADDER = ((400, "kodama"), (600, "tanuki"), (800, "kappa"), (1000, "karakasa"), (1200, "kitsune"), (1400, "tengu"),
          (1600, "yuki-onna"), (1800, "oni"), (2000, "hannya"), (9999, "shuten-doji"))


def opponent(elo):
    for limit, name in LADDER:
        if elo < limit:
            return name
    return LADDER[-1][1]


THEME_NAMES = (
    ("hangingPiece", "a piece for free"), ("mateIn1", "mate in one"), ("mateIn2", "mate in two"), ("mateIn3", "mate in three"),
    ("backRankMate", "the back rank"), ("fork", "forks"), ("pin", "pins"), ("skewer", "skewers"),
    ("discoveredAttack", "discovered attacks"), ("discoveredCheck", "discovered checks"), ("doubleCheck", "double checks"),
    ("capturingDefender", "removing the guard"), ("deflection", "deflection"), ("attraction", "attraction"),
    ("clearance", "clearance"), ("interference", "interference"), ("intermezzo", "the move in between"),
    ("xRayAttack", "x-rays"), ("trappedPiece", "trapped pieces"), ("sacrifice", "sacrifices"), ("quietMove", "quiet moves"),
    ("defensiveMove", "only moves"), ("advancedPawn", "advanced pawns"), ("promotion", "promotion"),
    ("attackingF2F7", "f2 and f7"), ("kingsideAttack", "attacking the king"), ("exposedKing", "the bare king"),
    ("smotheredMate", "smothered mate"), ("arabianMate", "the Arabian mate"), ("anastasiaMate", "Anastasia's mate"),
    ("bodenMate", "Boden's mate"), ("dovetailMate", "the dovetail"), ("hookMate", "the hook"),
    ("doubleBishopMate", "two bishops"), ("pawnEndgame", "pawn endings"), ("rookEndgame", "rook endings"),
    ("bishopEndgame", "bishop endings"), ("knightEndgame", "knight endings"), ("queenEndgame", "queen endings"),
    ("queenRookEndgame", "queen and rook endings"), ("zugzwang", "zugzwang"), ("opening", "in the opening"),
    ("middlegame", "in the middlegame"), ("endgame", "in the ending"),
)


def G(n, goal, **kw):
    return [dict(goal=goal, **kw) for _ in range(n)]


def pair(deep, light):
    """A day's two games: first the deep one (a whole game, a long clock), then the light one (a set
    position, an opening line, a tactic to play out: a short clock). One deep, one light keeps the two
    games inside the hour; Heisman: slow games teach thinking, 5|5 is fine for safety [D20][D22]."""
    return [g for two in zip(deep, light, strict=True) for g in two]


def B7(theme, n=7, goal=None):
    """Light games from the puzzle bank: a position with a tactic of this theme in it, to find and play out."""
    return G(n, goal or "a tactic is waiting here. find it, then win the game from there.", bank=theme, light=True, check="win")


def L7(n, goal, **kw):
    return G(n, goal, light=True, **kw)


SAFE = "before each move: what does it leave unguarded, what does their last move attack?"
CARD = "the three questions, every move: can I win material, can I mate, is a piece of mine in danger?"
WEEKS = [
    # ── the first month: the men, the rules, what they are worth, mate (Steps 1, Silman part one) ──
    dict(title="the men and how they move", band=(250, 300), themes=["hangingPiece"],
         lessons=["the-board", "the-rook", "the-bishop", "the-queen", "the-king", "the-knight", "the-pawn"],
         games=G(2, "a rook against three pawns: take them all before one reaches the far side.", pos="rook-v-pawns", hints=5, elo=250)
         + G(2, "a bishop against three pawns: take what stands on your colour, hold the rest back.", pos="bishop-v-pawns", hints=5, elo=250)
         + G(2, "the queen against eight pawns: she wins if you never let one through.", pos="queen-v-pawns", hints=5, elo=250)
         + G(2, "pawns against pawns: the first to reach the far side has a queen.", pos="pawn-war", hints=5, elo=250)
         + G(2, "a knight against three pawns: learn his jump, catch them from far away.", pos="knight-v-pawns", hints=5, elo=250)
         + G(2, "pawns against pawns again: now look before you push: can it be taken?", pos="pawn-war", hints=5, elo=250)
         + G(2, "your first whole game: they have no queen. take whatever you safely can.", odds="q", hints=5, elo=250)),
    dict(title="check, mate and the rules", band=(250, 350), themes=["mateIn1", "hangingPiece"],
         lessons=["check", "checkmate", "stalemate", "castling", "en-passant", "promotion", "notation-and-draws"],
         games=G(4, "two rooks against a lone king: mate him; they walk him to the edge rank by rank.", pos="two-rooks", elo=1320, check="mate:30")
         + G(4, "they have no queen: win, and castle on the way.", odds="q", check="castle:15")
         + G(4, "they have no rook: win. every capture you can make safely, make.", odds="r", check="win")
         + G(2, "a whole game, level: nothing to prove but legal moves and one mate.", check="finish")),
    dict(title="what the men are worth", band=(250, 400), themes=["hangingPiece", "mateIn1"],
         lessons=["what-they-are-worth", "free-pieces", "attack-and-defence", "counting", "good-and-bad-trades", "when-not-to-take", "the-simplest-plan"],
         games=G(4, "they have no knight: take every piece left unguarded, leave none of yours.", odds="n", check="free")
         + G(6, "a whole game: take every free piece. count before every capture.", check="free")
         + G(4, "a whole game: be the one who wins material, and when ahead trade down.", check="win")),
    dict(title="mate at once, and the lone king", band=(300, 450), themes=["mateIn1", "backRankMate"],
         lessons=["the-back-rank", "mate-in-one", "the-ladder", "king-and-queen", "king-and-rook", "do-not-stalemate"],
         milestone=dict(level=450, puzzle=750), exam=dict(themes=["mateIn1", "hangingPiece", "backRankMate"], rating=600),
         games=G(3, "king and queen against a lone king: mate in under twenty moves.", pos="kq-k", elo=1320, check="mate:20", gate=True)
         + G(3, "king and rook against a lone king: mate in under thirty moves.", pos="kr-k", elo=1320, check="mate:30", gate=True)
         + G(1, "the king and queen from the far corner: mate, no stalemate.", pos="kq-k-corner", elo=1320, check="mate:20")
         + G(1, "the king and rook from far away: mate, no stalemate.", pos="kr-k-far", elo=1320, check="mate:30")
         + G(4, "a whole game: if you get ahead, finish it: mate, not a draw.", check="win")
         + G(2, "a whole game at your stretch: their back rank, your back rank.", off=150, check="finish")),
    # ── safety and the first tactics (Heisman; Steps 2) ─────────────────────────────────────
    dict(title="is it safe?", band=(350, 550), themes=["hangingPiece", "mateIn1"], lessons=["is-it-safe", "the-blunder-check", "loose-pieces"],
         games=pair(G(4, "not one piece given away. " + SAFE, check="safe")
                    + G(3, "the marks on your pieces are off now: see them yourself.", threats=False, check="safe"),
                    B7("hangingPiece", 7, "someone left a piece hanging here: take it, keep it, win."))),
    dict(title="the opening: centre, men out, king home", band=(400, 600), themes=["opening", "hangingPiece"],
         lessons=["the-centre", "pieces-out", "king-home", "opening-sins"],
         games=pair(G(7, "knights and bishops out and castled by move ten; the queen stays home for now.", check="develop:10"),
                    L7(4, "you are White in the Italian: finish your development first, then think.", line="italian", you=0, check="castle:10")
                    + L7(3, "you are Black against the Italian: e5, knights out, castle.", line="e5-italian", you=1, check="castle:10"))),
    dict(title="the fork", band=(450, 650), themes=["fork", "fork", "hangingPiece"], lessons=["two-at-once", "the-knights-fork", "the-queens-fork", "the-pawns-fork"],
         games=pair(G(7, "win something with a fork, or make one possible. look at their knights too.", check="safe"), B7("fork"))),
    dict(title="the pin", band=(500, 700), themes=["pin", "pin", "fork"], lessons=["the-pin", "pinned-to-the-queen", "using-a-pin"],
         milestone=dict(level=650, puzzle=950), exam=dict(themes=["fork", "pin", "hangingPiece", "mateIn1"], rating=750),
         games=pair(G(5, "pin something and pile up on it; a pinned man is a guard that does not guard.", check="safe")
                    + G(2, "test games, a level above you: what you have, you use.", off=150, check="finish"),
                    B7("pin", 5) + L7(1, "White in the Two Knights: watch for Bg5 and ...Bg4.", line="two-knights", you=0, check="safe")
                    + L7(1, "Black against d4: d5, e6, Nf6: no piece pinned for free.", line="qgd", you=1, check="safe"))),
    dict(title="the skewer and the discovered attack", band=(550, 750), themes=["skewer", "discoveredAttack", "discoveredCheck", "pin"],
         lessons=["the-skewer", "discovered-attack", "discovered-check"],
         games=pair(G(7, "line up your long-range pieces on theirs; find what moves away with a threat.", check="safe"),
                    B7("skewer", 3) + B7("discoveredAttack", 4))),
    dict(title="mate in two", band=(600, 800), themes=["mateIn2", "mateIn2", "mateIn1", "backRankMate"],
         lessons=["how-to-find-mate-in-two", "the-scholars-mate", "the-early-queen", "smothered-mate"],
         games=pair(G(4, "they will try quick mates: stop them with a developing move, then punish the queen.", check="safe")
                    + G(3, "look for mate on every move you are ahead: finish, do not fiddle.", check="win"),
                    B7("mateIn2", 5, "mate in two is here. find it; if you miss it, win anyway.") + B7("smotheredMate", 2))),
    dict(title="kings and pawns", band=(650, 850), themes=["pawnEndgame", "advancedPawn", "promotion"],
         lessons=["key-squares", "the-opposition", "the-square", "pawn-races"],
         games=pair(G(7, "a whole game: when you are ahead, trade pieces, not pawns.", check="win"),
                    L7(2, "king and pawn: get your king in front, keep the opposition, make a queen.", pos="kp-k-ahead", elo=1320, check="win")
                    + L7(1, "the classic: king on the sixth in front of the pawn: win.", pos="kp-k-opposition", elo=1320, check="win")
                    + L7(2, "you are the lone king: hold it, step by step in front of the pawn.", pos="kp-k-hold", you=1, elo=1320, check="draw")
                    + L7(2, "two pawns are easy if they stay together: win.", pos="two-pawns", elo=1320, check="win"))),
    dict(title="the first exam", band=(700, 950), themes=[None, "fork", "pin", "mateIn2", "hangingPiece", "pawnEndgame", "skewer"],
         lessons=["your-opening-as-white", "your-opening-as-black"],
         milestone=dict(level=800, puzzle=1100), exam=dict(themes=["fork", "pin", "skewer", "mateIn2", "discoveredAttack"], rating=900),
         games=pair(G(5, "whole games at your level: everything counts now.", check="win")
                    + G(2, "test games, a level up: this is the first big exam.", off=150, check="finish"),
                    L7(2, "White in the Italian: play it without looking it up.", line="italian", you=0, check="develop:10")
                    + L7(2, "Black with e5: play it without looking it up.", line="e5-italian", you=1, check="develop:10")
                    + L7(1, "Black with d5: play it without looking it up.", line="qgd", you=1, check="develop:10")
                    + B7("fork", 1) + B7("pin", 1))),
    # ── thinking; tactics that take two ideas; attack (Heisman's Real Chess; Steps 3–4) ─────
    dict(title="real chess: how to choose a move", band=(750, 1000), themes=[None, "fork", "pin", "discoveredAttack"],
         lessons=["hope-chess", "candidate-moves", "checks-captures-threats"],
         games=pair(G(4, "use the clock: every move, two candidates and their best answers before you touch.", check="think:15")
                    + G(3, "every move, their answer first: what do they do if you play it?", threats=False, check="think:15"),
                    B7("discoveredAttack", 3) + B7("fork", 2) + B7("pin", 2))),
    dict(title="the guard removed, the overworked man", band=(800, 1050), themes=["capturingDefender", "deflection", "attraction", "fork"],
         lessons=["remove-the-guard", "the-overworked-man", "deflection-and-attraction"],
         games=pair(G(7, "ask of their every guard: can I take it, chase it, or give it two jobs?", check="safe"),
                    B7("capturingDefender", 3) + B7("deflection", 2) + B7("attraction", 2))),
    dict(title="mates with names", band=(850, 1100), themes=["smotheredMate", "arabianMate", "anastasiaMate", "bodenMate", "hookMate", "dovetailMate", "doubleBishopMate"],
         lessons=["arabian-and-anastasia", "boden-and-two-bishops", "dovetail-and-hook"],
         games=pair(G(7, "when their king has few squares, stop and count: is there a pattern you know?", check="win"),
                    B7("arabianMate", 2) + B7("anastasiaMate", 2) + B7("bodenMate", 1) + B7("dovetailMate", 1) + B7("hookMate", 1))),
    dict(title="attacking the castled king", band=(900, 1200), themes=["kingsideAttack", "attackingF2F7", "exposedKing", "sacrifice"],
         lessons=["open-lines-to-the-king", "the-greek-gift", "the-bare-king"], milestone=dict(level=950, puzzle=1250),
         exam=dict(themes=["discoveredAttack", "capturingDefender", "deflection", "mateIn2", "kingsideAttack"], rating=1050),
         games=pair(G(5, "bring three pieces near their king before you strike.", check="win")
                    + G(2, "test games, a level up: attack only what you have counted.", off=150, check="finish"),
                    L7(3, "this position has the gift in it: Bxh7+ if the knight and the queen can follow.", pos="greek-gift", elo=1320, check="win")
                    + B7("kingsideAttack", 4))),
    dict(title="a master's game, move by move", band=(950, 1250), themes=[None, "middlegame", "opening"],
         lessons=["morphys-opera-game", "a-king-hunt", "the-pin-that-won"],
         games=pair(G(7, "before each move, what would the master of this week's game do with your position?", check="develop:12"),
                    L7(3, "White in the Italian: the pieces where the master puts them.", line="italian", you=0, check="safe")
                    + L7(2, "Black with e5: the pieces where the master puts them.", line="e5-italian", you=1, check="safe")
                    + B7("middlegame", 2))),
    dict(title="the rooks", band=(1000, 1250), themes=["rookEndgame", "middlegame", "backRankMate"],
         lessons=["the-open-file", "the-seventh-rank", "doubling"],
         games=pair(G(7, "by move twenty your rooks are on open files or doubled, not at home.", check="safe"),
                    L7(3, "you hold the open file: bring the rook to the seventh and win.", pos="open-file", elo=1320, check="win")
                    + B7("rookEndgame", 4))),
    dict(title="knights and bishops", band=(1050, 1300), themes=["middlegame", "trappedPiece", "knightEndgame", "bishopEndgame"],
         lessons=["outposts", "good-and-bad-bishops", "the-two-bishops"],
         games=pair(G(7, "before trading a minor piece, name which one you would rather keep and why.", check="safe"),
                    L7(3, "your knight has a home on d4: use it against the bad bishop.", pos="knight-outpost", you=1, elo=1400, check="win")
                    + B7("trappedPiece", 2) + B7("bishopEndgame", 1) + B7("knightEndgame", 1))),
    dict(title="pawns: the skeleton of the game", band=(1100, 1350), themes=["advancedPawn", "promotion", "pawnEndgame", "middlegame"],
         lessons=["the-passed-pawn", "weak-pawns", "chains"], milestone=dict(level=1050, puzzle=1350),
         exam=dict(themes=["rookEndgame", "pawnEndgame", "trappedPiece", "advancedPawn", "attackingF2F7"], rating=1150),
         games=pair(G(5, "name their weakest pawn by move fifteen, and aim something at it.", check="safe")
                    + G(2, "test games, a level up.", off=150, check="finish"),
                    B7("advancedPawn", 4) + B7("promotion", 2) + B7("pawnEndgame", 1))),
    dict(title="queen against pawn, and the Lucena", band=(1150, 1400), themes=["rookEndgame", "queenEndgame", "pawnEndgame"],
         lessons=["queen-against-pawn", "the-lucena-position", "the-bridge"],
         games=pair(G(7, "whole games: in the ending, your king is a fighting piece.", check="safe"),
                    L7(3, "the Lucena: build the bridge and promote.", pos="lucena", elo=1800, check="win", gate=True)
                    + L7(2, "the queen against the far-advanced pawn: king close, then take it or mate.", pos="q-v-pawn", elo=1800, check="win")
                    + B7("rookEndgame", 2))),
    dict(title="the Philidor, and active rooks", band=(1200, 1450), themes=["rookEndgame", "defensiveMove", "pawnEndgame"],
         lessons=["the-philidor-position", "rooks-behind-pawns", "the-active-rook"],
         games=pair(G(7, "whole games: every rook ending you reach, you know now.", check="safe"),
                    L7(3, "the Philidor: stay on the third rank until the pawn advances, then check from behind.", pos="philidor", you=1, elo=1800, check="draw", gate=True)
                    + L7(2, "rook behind the passed pawn: push it home.", pos="rook-behind", elo=1500, check="win")
                    + L7(2, "rook ending, your rook active: do not defend passively.", pos="active-rook", elo=1500, check="draw+"))),
    dict(title="the clock and your habits", band=(1250, 1500), themes=[None, "defensiveMove", "quietMove", "intermezzo"],
         lessons=["a-budget-for-the-clock", "your-own-errors", "the-last-check"],
         games=pair(G(7, "a third of your clock for the opening's end: spend it where the game is decided.", check="clock"),
                    B7("defensiveMove", 3, "you are in trouble here: find the only move, then hold.") + B7("quietMove", 2) + B7("intermezzo", 2))),
    dict(title="the second exam", band=(1250, 1550), themes=[None, "fork", "pin", "rookEndgame", "kingsideAttack", "deflection", "pawnEndgame"], lessons=[],
         milestone=dict(level=1150, puzzle=1450), exam=dict(themes=["fork", "pin", "rookEndgame", "kingsideAttack", "deflection", "defensiveMove"], rating=1300),
         games=pair(G(5, "whole games at your level: all you know.", check="win")
                    + G(2, "test games, a level up: the second big exam.", off=150, check="finish"),
                    B7("endgame", 3) + B7("middlegame", 4))),
    # ── calculation; defence; planning (Steps 4–5, Yusupov, Silman parts 4–5) ───────────────
    dict(title="calculating", band=(1300, 1550), themes=["mateIn3", "sacrifice", "quietMove", "intermezzo"],
         lessons=["see-it-in-your-head", "forcing-lines", "count-to-quiet"],
         games=pair(G(7, "at each capture and check, go on until nothing more can be taken: then judge.", check="think:20"),
                    B7("mateIn3", 3) + B7("sacrifice", 4))),
    dict(title="defending", band=(1350, 1600), themes=["defensiveMove", "defensiveMove", "intermezzo", "exposedKing"],
         lessons=["their-threat-first", "the-counterattack", "the-move-in-between"],
         games=pair(G(7, "you are the one being attacked in half of these: find the only move, do not despair.", check="safe"),
                    L7(3, "you are a piece down: make it as hard as you can, look for tricks.", pos="down-exchange", elo=1320, check="draw+")
                    + B7("defensiveMove", 4))),
    dict(title="clearance, interference, x-ray", band=(1400, 1650), themes=["clearance", "interference", "xRayAttack", "discoveredAttack"],
         lessons=["clearing-the-way", "cutting-the-line", "through-a-man"],
         games=pair(G(7, "their pieces' lines: which one can you cut, which of yours can you open?", check="safe"),
                    B7("clearance", 3) + B7("interference", 2) + B7("xRayAttack", 2))),
    dict(title="storms: opposite castling", band=(1450, 1700), themes=["kingsideAttack", "exposedKing", "sacrifice", "mateIn3"],
         lessons=["the-pawn-storm", "opposite-castling", "the-h-file"], milestone=dict(level=1250, puzzle=1550),
         exam=dict(themes=["mateIn3", "sacrifice", "defensiveMove", "clearance", "kingsideAttack"], rating=1400),
         games=pair(G(5, "castle on the other wing when it is safe; in a race, every tempo counts.", check="safe")
                    + G(2, "test games, a level up.", off=150, check="finish"),
                    B7("kingsideAttack", 4) + B7("exposedKing", 3))),
    dict(title="weak squares", band=(1450, 1700), themes=["middlegame", "quietMove", "trappedPiece"],
         lessons=["holes", "the-colour-of-the-squares", "making-a-weakness"],
         games=pair(G(7, "by move fifteen, name one hole in their camp and bring a piece to it.", check="safe"),
                    B7("quietMove", 4) + B7("trappedPiece", 3))),
    dict(title="what to trade", band=(1500, 1750), themes=["middlegame", "endgame", "hangingPiece"],
         lessons=["good-pieces-and-bad-pieces", "trading-when-ahead", "the-trade-you-regret"],
         games=pair(G(7, "before every trade: who is better off in the position that is left?", check="safe"),
                    L7(3, "you are up a pawn and the rooks are on: trade them, win the ending.", pos="up-a-pawn", elo=1500, check="win")
                    + B7("endgame", 4))),
    dict(title="breaks and space", band=(1500, 1750), themes=["middlegame", "quietMove", "advancedPawn"],
         lessons=["pawn-breaks", "space", "the-closed-centre"],
         games=pair(G(7, "name the pawn move that opens the game for you, and prepare it.", check="safe"),
                    L7(4, "Black against d4: when does ...c5 or ...e5 free you?", line="qgd", you=1, check="safe")
                    + L7(3, "Black against the London: ...c5 and a calm game.", line="london-black", you=1, check="safe"))),
    dict(title="minor-piece endings", band=(1550, 1800), themes=["bishopEndgame", "knightEndgame", "pawnEndgame"],
         lessons=["good-bishop-bad-bishop-endings", "knight-against-bishop", "the-wrong-bishop"], milestone=dict(level=1350, puzzle=1650),
         exam=dict(themes=["bishopEndgame", "knightEndgame", "pawnEndgame", "quietMove", "trappedPiece"], rating=1500),
         games=pair(G(5, "whole games: choose your ending.", check="safe")
                    + G(2, "test games, a level up.", off=150, check="finish"),
                    L7(3, "your bishop is good, theirs is not: press.", pos="bishop-good", elo=1800, check="win")
                    + L7(2, "bishop against knight with pawns on both sides: use the long range.", pos="bishop-v-knight", elo=1800, check="draw+")
                    + B7("bishopEndgame", 2))),
    dict(title="rook endings, once more", band=(1550, 1800), themes=["rookEndgame", "rookEndgame", "defensiveMove"],
         lessons=["cutting-off-the-king", "rook-and-two-pawns"],
         games=pair(G(7, "whole games: if a rook ending comes, the rook stays active.", check="safe"),
                    L7(3, "the rook behind, from the third rank: draw this worse ending.", pos="worse-rook", you=1, elo=1800, check="draw+")
                    + B7("rookEndgame", 4))),
    dict(title="your openings, your plans", band=(1600, 1850), themes=["opening", "middlegame"],
         lessons=["the-italian-plan", "against-the-sicilian", "against-caro-and-french", "the-qgd-plan"],
         games=pair(G(7, "whole games: your own opening and the plan that belongs to it.", check="safe"),
                    L7(1, "the Italian: c3 and d4 at the right moment.", line="italian", you=0, check="safe")
                    + L7(1, "the Alapin: c3, d4, free play for your pieces.", line="alapin", you=0, check="safe")
                    + L7(1, "the Advance against the Caro-Kann.", line="caro-advance", you=0, check="safe")
                    + L7(1, "the Advance against the French.", line="french-advance", you=0, check="safe")
                    + L7(1, "e5 against the Scotch.", line="e5-scotch", you=1, check="safe")
                    + L7(1, "e5 against the Ruy Lopez.", line="e5-ruy", you=1, check="safe")
                    + L7(1, "the Queen's Gambit Declined.", line="qgd", you=1, check="safe"))),
    dict(title="imbalances: making a plan", band=(1600, 1850), themes=["middlegame", "quietMove", None],
         lessons=["what-is-different", "making-a-plan", "the-worst-piece"],
         games=pair(G(7, "by move fifteen, say the plan to yourself: what is different, whom does it favour?", check="think:20"),
                    B7("middlegame", 7))),
    dict(title="the third exam", band=(1600, 1900), themes=[None, "fork", "pin", "rookEndgame", "kingsideAttack", "quietMove", "defensiveMove"], lessons=[],
         milestone=dict(level=1450, puzzle=1750), exam=dict(themes=["rookEndgame", "kingsideAttack", "quietMove", "defensiveMove", "sacrifice", "bishopEndgame"], rating=1600),
         games=pair(G(5, "whole games at your level.", check="win")
                    + G(2, "test games, a level up: the third big exam.", off=150, check="finish"),
                    B7("endgame", 3) + B7("middlegame", 4))),
    # ── the last climb (Yusupov's method of tests; rapid as chess.com plays it) ─────────────
    dict(title="winning the won game", band=(1650, 1900), themes=["middlegame", "endgame", "defensiveMove"],
         lessons=["simplify", "no-counterplay", "one-good-move-at-a-time"],
         games=pair(G(7, "when ahead, take away their every check and threat first.", check="win"),
                    L7(3, "up a whole piece: no tricks allowed, trade down, win.", pos="up-a-piece", elo=1800, check="win")
                    + L7(2, "a queen up: mate in under thirty, safely.", pos="up-a-queen", elo=1800, check="win")
                    + B7("endgame", 2))),
    dict(title="saving lost positions", band=(1700, 1950), themes=["defensiveMove", "quietMove", "queenEndgame"],
         lessons=["a-swindle", "the-fortress", "perpetual-check"],
         games=pair(G(7, "when worse, make every move a problem; never resign early.", check="safe"),
                    B7("equality", 4, "you are losing here: there is one way back. find it.") + B7("defensiveMove", 3))),
    dict(title="traps in your own openings", band=(1700, 1950), themes=["opening", "attackingF2F7", "trappedPiece"],
         lessons=["traps-in-the-italian", "traps-after-e5", "traps-after-d5"],
         games=pair(G(7, "whole games: the first fifteen moves without a slip.", check="safe"),
                    L7(2, "the Two Knights: you are White: Ng5 or d4?", line="two-knights", you=0, check="safe")
                    + B7("opening", 3) + B7("attackingF2F7", 2))),
    dict(title="what do they want?", band=(1750, 2000), themes=["defensiveMove", "quietMove", "intermezzo"],
         lessons=["what-do-they-want", "prophylaxis", "the-piece-doing-nothing"], milestone=dict(level=1550, puzzle=1850),
         exam=dict(themes=["defensiveMove", "quietMove", "intermezzo", "equality", "opening"], rating=1700),
         games=pair(G(5, "each move, say their plan before yours; stop it if it costs nothing.", check="think:20")
                    + G(2, "test games, a level up.", off=150, check="finish"),
                    B7("quietMove", 4) + B7("intermezzo", 3))),
    dict(title="the initiative", band=(1750, 2000), themes=["kingsideAttack", "sacrifice", "clearance"],
         lessons=["tempo", "breaking-in-the-centre", "giving-to-attack"],
         games=pair(G(7, "keep them answering: a threat each move, while it lasts.", check="safe"),
                    B7("sacrifice", 4) + B7("clearance", 3))),
    dict(title="the isolated pawn, hanging pawns", band=(1800, 2050), themes=["middlegame", "advancedPawn", "quietMove"],
         lessons=["playing-with-the-isolani", "playing-against-the-isolani", "hanging-pawns"],
         games=pair(G(7, "whole games: name the structure by move twelve.", check="safe"),
                    L7(4, "with the isolani: d5 is your break, attack the king.", pos="iqp-white", elo=1600, check="safe")
                    + L7(3, "against it: blockade d4, trade pieces.", pos="iqp-black", you=1, elo=1600, check="safe"))),
    dict(title="king endings, deeper", band=(1800, 2050), themes=["pawnEndgame", "zugzwang", "endgame"],
         lessons=["triangulation", "the-outside-passed-pawn", "the-active-king"],
         games=pair(G(7, "whole games: go for the pawn ending when you have counted it.", check="safe"),
                    L7(3, "the outside passed pawn wins: decoy their king.", pos="outside-passer", elo=1800, check="win")
                    + B7("pawnEndgame", 2) + B7("zugzwang", 2))),
    dict(title="ten minutes", band=(1800, 2050), themes=[None, "fork", "pin", "mateIn2", "endgame"],
         lessons=["playing-on-ten-minutes", "simple-when-short"], milestone=dict(level=1650, puzzle=1950),
         exam=dict(themes=["pawnEndgame", "zugzwang", "sacrifice", "clearance", "mateIn3"], rating=1800),
         games=pair(G(5, "ten minutes, no increment: never under one minute before move thirty.", clock=(10, 0), check="clock")
                    + G(2, "test games, a level up.", clock=(10, 0), off=150, check="finish"),
                    B7("middlegame", 4) + B7("endgame", 3))),
    dict(title="the woodpecker", band=(1800, 2100), themes=[None], lessons=["the-woodpecker"],
         games=pair(G(7, "all the tactics you ever missed come back this week: see them in the game first.", clock=(10, 5), check="safe"),
                    B7("middlegame", 7))),
    dict(title="masters again", band=(1850, 2100), themes=["middlegame", "endgame", None],
         lessons=["capablanca-simple-chess", "rubinstein-rook-ending", "a-model-attack"],
         games=pair(G(7, "guess what the master would do, then check your guess with your own calculation.", clock=(10, 5), check="think:20"),
                    B7("endgame", 4) + B7("middlegame", 3))),
    dict(title="queens and rooks together", band=(1850, 2100), themes=["queenEndgame", "queenRookEndgame", "exposedKing"],
         lessons=["queen-endings", "heavy-pieces"],
         games=pair(G(7, "with the heavy pieces on: king safety first; a check is not always a threat.", clock=(10, 5), check="safe"),
                    B7("queenEndgame", 4) + B7("queenRookEndgame", 3))),
    dict(title="who you will meet", band=(1900, 2150), themes=[None, "opening", "attackingF2F7"], lessons=["gambits-at-1500", "the-online-opponent"],
         milestone=dict(level=1750, puzzle=2000), exam=dict(themes=["queenEndgame", "opening", "attackingF2F7", "sacrifice", "defensiveMove"], rating=1900),
         games=pair(G(5, "the sharp lines people play online: stay calm, take the free pawn when you have counted.", clock=(10, 5), check="safe")
                    + G(2, "test games, a level up.", clock=(10, 5), off=150, check="finish"),
                    B7("opening", 4) + B7("attackingF2F7", 3))),
    dict(title="the last climb: rapid as it is", band=(1900, 2200), themes=[None], lessons=["when-you-lose", "a-review-of-your-own"],
         games=pair(G(7, "rapid: ten minutes, chess.com's own. your own review after each.", clock=(10, 0), check="win"),
                    B7("middlegame", 7))),
    dict(title="the last climb: stronger", band=(1950, 2250), themes=[None], lessons=[],
         games=pair(G(7, "rapid against someone a little better: you will lose some. learn why.", clock=(10, 0), off=100, check="finish"),
                    B7("endgame", 7))),
    dict(title="the last climb: all of it", band=(2000, 2300), themes=[None], lessons=["what-to-do-next"],
         games=pair(G(7, "rapid, your full repertoire, every habit.", clock=(10, 0), off=100, check="finish"),
                    B7("middlegame", 7))),
    dict(title="the last exam", band=(2000, 2350), themes=[None], lessons=[],
         milestone=dict(level=1800, puzzle=2100), exam=dict(themes=[None], rating=2000),
         games=pair(G(7, "the last exam: then play on chess.com, ten minutes: see what the year made of you.", clock=(10, 0), off=150, check="finish"),
                    B7("endgame", 3) + B7("middlegame", 4))),
]
assert len(WEEKS) == 52
assert all(len(w["games"]) == 14 for w in WEEKS)
