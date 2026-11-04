"""The rules of chess: positions, legal moves, SAN, FEN, PGN, draws, exchanges. No imports but re.

A square is 0–63 (a1 = 0, h1 = 7, a8 = 56), a piece kind | colour << 3 (white 1–6, black 9–14), a
move an int: from | to << 6 | promotion kind << 12. Checked against Stockfish's perft in
tests/content/test_chess_rules.sh.
"""
import re

WHITE, BLACK = 0, 1
PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING = 1, 2, 3, 4, 5, 6
LETTER = {PAWN: "", KNIGHT: "N", BISHOP: "B", ROOK: "R", QUEEN: "Q", KING: "K"}
FEN_LETTER = " pnbrqk"
VALUE = {PAWN: 1, KNIGHT: 3, BISHOP: 3, ROOK: 5, QUEEN: 9, KING: 100}
NAME = {PAWN: "pawn", KNIGHT: "knight", BISHOP: "bishop", ROOK: "rook", QUEEN: "queen", KING: "king"}
START = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
WK, WQ, BK, BQ = 1, 2, 4, 8


def _build():
    knight, king, rays = [], [], []
    pawn_att = ([], [])
    for s in range(64):
        f, r = s % 8, s // 8
        on = [(f + x, r + y) for x, y in ((1, 2), (2, 1), (2, -1), (1, -2), (-1, -2), (-2, -1), (-2, 1), (-1, 2))]
        knight.append(tuple(x + 8 * y for x, y in on if 0 <= x < 8 and 0 <= y < 8))
        on = [(f + x, r + y) for x in (-1, 0, 1) for y in (-1, 0, 1) if x or y]
        king.append(tuple(x + 8 * y for x, y in on if 0 <= x < 8 and 0 <= y < 8))
        here = []
        # (the rook's four rays first, then the bishop's: attacked() and the generator rely on it)
        for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0), (1, 1), (-1, 1), (1, -1), (-1, -1)):
            ray, x, y = [], f + dx, r + dy
            while 0 <= x < 8 and 0 <= y < 8:
                ray.append(x + 8 * y)
                x, y = x + dx, y + dy
            here.append(tuple(ray))
        rays.append(tuple(here))
        for c, dy in ((WHITE, 1), (BLACK, -1)):
            pawn_att[c].append(tuple(x + 8 * (r + dy) for x in (f - 1, f + 1) if 0 <= x < 8 and 0 <= r + dy < 8))
    return tuple(knight), tuple(king), tuple(rays), (tuple(pawn_att[0]), tuple(pawn_att[1]))


KN, KI, RAY, PAWN_ATT = _build()
CASTLE_KEEP = [15] * 64
for _s, _lost in ((0, WQ), (7, WK), (4, WK | WQ), (56, BQ), (63, BK), (60, BK | BQ)):
    CASTLE_KEEP[_s] = 15 ^ _lost


def sq_name(s):
    return "abcdefgh"[s % 8] + str(s // 8 + 1)


def sq_of(name):
    return "abcdefgh".index(name[0]) + 8 * (int(name[1]) - 1)


def mv(f, t, promo=0):
    return f | t << 6 | promo << 12


def uci(m):
    return sq_name(m & 63) + sq_name(m >> 6 & 63) + (FEN_LETTER[m >> 12] if m >> 12 else "")


def from_uci(text):
    """'e2e4' or 'e7e8q' → a move (not checked against any position); ValueError when malformed."""
    if not re.fullmatch(r"[a-h][1-8][a-h][1-8][nbrq]?", text):
        raise ValueError(f"not a move: {text!r}")
    return mv(sq_of(text[:2]), sq_of(text[2:4]), FEN_LETTER.index(text[4]) if len(text) == 5 else 0)


class Position:
    __slots__ = ("b", "turn", "castle", "ep", "half", "full", "kings", "stack")

    def __init__(self, fen=START):
        self.stack = []
        self._parse(fen)

    def _parse(self, fen):
        parts = fen.split()
        if len(parts) < 4 or len(parts) > 6:
            raise ValueError(f"FEN needs 4–6 fields: {fen!r}")
        rows = parts[0].split("/")
        if len(rows) != 8:
            raise ValueError(f"FEN needs 8 ranks: {fen!r}")
        b = [0] * 64
        for r, row in enumerate(rows):
            f = 0
            for ch in row:
                if ch.isdigit() and ch.isascii():
                    if not 1 <= int(ch) <= 8:
                        raise ValueError(f"bad FEN rank {row!r}")
                    f += int(ch)
                else:
                    kind = FEN_LETTER.find(ch.lower())
                    if kind < 1 or f > 7:
                        raise ValueError(f"bad FEN rank {row!r}")
                    b[f + 8 * (7 - r)] = kind | (BLACK << 3 if ch.islower() else 0)
                    f += 1
            if f != 8:
                raise ValueError(f"bad FEN rank {row!r}")
        if parts[1] not in ("w", "b"):
            raise ValueError(f"bad FEN side {parts[1]!r}")
        self.b = b
        self.turn = WHITE if parts[1] == "w" else BLACK
        wk = [i for i, p in enumerate(b) if p == KING]
        bk = [i for i, p in enumerate(b) if p == KING | BLACK << 3]
        if len(wk) != 1 or len(bk) != 1:
            raise ValueError("a position has one king a side")
        if any(p & 7 == PAWN and i // 8 in (0, 7) for i, p in enumerate(b)):
            raise ValueError("a pawn on the first or last rank")
        self.kings = [wk[0], bk[0]]
        if parts[2] != "-" and not re.fullmatch(r"K?Q?k?q?", parts[2]):
            raise ValueError(f"bad FEN castling {parts[2]!r}")
        c = 0
        for ch, bit, ks, rs, side in (("K", WK, 4, 7, 0), ("Q", WQ, 4, 0, 0), ("k", BK, 60, 63, 8), ("q", BQ, 60, 56, 8)):
            if ch in parts[2] and b[ks] == KING | side and b[rs] == ROOK | side:
                c |= bit
        self.castle = c
        self.ep = -1
        if parts[3] != "-":
            if not re.fullmatch(r"[a-h][36]", parts[3]):
                raise ValueError(f"bad FEN en passant {parts[3]!r}")
            e = sq_of(parts[3])
            # (only a square a pawn has really just crossed: an empty one, the pawn past it)
            mover, past, back = (PAWN | 8, e - 8, e + 8) if self.turn == WHITE else (PAWN, e + 8, e - 8)
            if e // 8 == (5 if self.turn == WHITE else 2) and not b[e] and not b[back] and b[past] == mover:
                self.ep = e
        try:
            self.half = int(parts[4]) if len(parts) > 4 else 0
            self.full = int(parts[5]) if len(parts) > 5 else 1
        except ValueError:
            raise ValueError(f"bad FEN counters: {fen!r}") from None
        if self.half < 0 or self.full < 1:
            raise ValueError(f"bad FEN counters: {fen!r}")
        if self.attacked(self.kings[1 - self.turn], self.turn):
            raise ValueError("the side not to move is in check")

    def copy(self):
        p = Position.__new__(Position)
        p.b, p.turn, p.castle, p.ep, p.half, p.full = self.b[:], self.turn, self.castle, self.ep, self.half, self.full
        p.kings, p.stack = self.kings[:], []
        return p

    def fen(self):
        rows = []
        for r in range(7, -1, -1):
            row, gap = "", 0
            for f in range(8):
                p = self.b[f + 8 * r]
                if p:
                    row += (str(gap) if gap else "") + (FEN_LETTER[p & 7] if p & 8 else FEN_LETTER[p & 7].upper())
                    gap = 0
                else:
                    gap += 1
            rows.append(row + (str(gap) if gap else ""))
        c = "".join(ch for ch, bit in (("K", WK), ("Q", WQ), ("k", BK), ("q", BQ)) if self.castle & bit) or "-"
        ep = sq_name(self.ep) if self.ep >= 0 else "-"
        return f"{'/'.join(rows)} {'wb'[self.turn]} {c} {ep} {self.half} {self.full}"

    def key(self):
        """What makes two positions the same one for repetition: placement, side, castling, and
        the en passant square only when the capture is really there (FIDE 9.2)."""
        ep = self.ep if self.ep >= 0 and any(m >> 6 & 63 == self.ep and self.b[m & 63] & 7 == PAWN for m in self.legal()) else -1
        return (tuple(self.b), self.turn, self.castle, ep)

    def attacked(self, s, by):
        b, p = self.b, by << 3
        k = p | KNIGHT
        for t in KN[s]:
            if b[t] == k:
                return True
        k = p | KING
        for t in KI[s]:
            if b[t] == k:
                return True
        k = p | PAWN
        for t in PAWN_ATT[1 - by][s]:      # (a pawn of `by` attacks s from where the other side's pawn on s would attack)
            if b[t] == k:
                return True
        rays = RAY[s]
        r, q, bi = p | ROOK, p | QUEEN, p | BISHOP
        for i in range(4):
            for t in rays[i]:
                x = b[t]
                if x:
                    if x == r or x == q:
                        return True
                    break
        for i in range(4, 8):
            for t in rays[i]:
                x = b[t]
                if x:
                    if x == bi or x == q:
                        return True
                    break
        return False

    def attackers(self, s, by, b=None):
        """The squares of `by`'s pieces that attack s (on the board b: exchanges try without some)."""
        b = b or self.b
        p, out = by << 3, []
        k = p | KNIGHT
        out += [t for t in KN[s] if b[t] == k]
        k = p | KING
        out += [t for t in KI[s] if b[t] == k]
        k = p | PAWN
        out += [t for t in PAWN_ATT[1 - by][s] if b[t] == k]
        for i, ray in enumerate(RAY[s]):
            slider = p | (ROOK if i < 4 else BISHOP)
            q = p | QUEEN
            for t in ray:
                x = b[t]
                if x:
                    if x == slider or x == q:
                        out.append(t)
                    break
        return out

    def in_check(self, side=None):
        side = self.turn if side is None else side
        return self.attacked(self.kings[side], 1 - side)

    def pseudo(self):
        b, me = self.b, self.turn
        my = me << 3
        out = []
        add = out.append
        for f in range(64):
            p = b[f]
            if not p or p & 8 != my:
                continue
            kind = p & 7
            if kind == PAWN:
                r = f // 8
                step = 8 if me == WHITE else -8
                t = f + step
                last = r == (6 if me == WHITE else 1)
                if not b[t]:
                    if last:
                        for pr in (QUEEN, ROOK, BISHOP, KNIGHT):
                            add(f | t << 6 | pr << 12)
                    else:
                        add(f | t << 6)
                        if r == (1 if me == WHITE else 6) and not b[t + step]:
                            add(f | (t + step) << 6)
                for t in PAWN_ATT[me][f]:
                    x = b[t]
                    if (x and x & 8 != my) or t == self.ep:
                        if last:
                            for pr in (QUEEN, ROOK, BISHOP, KNIGHT):
                                add(f | t << 6 | pr << 12)
                        else:
                            add(f | t << 6)
            elif kind == KNIGHT or kind == KING:
                for t in (KN if kind == KNIGHT else KI)[f]:
                    x = b[t]
                    if not x or x & 8 != my:
                        add(f | t << 6)
            else:
                rays = RAY[f]
                for i in (range(4, 8) if kind == BISHOP else range(4) if kind == ROOK else range(8)):
                    for t in rays[i]:
                        x = b[t]
                        if x:
                            if x & 8 != my:
                                add(f | t << 6)
                            break
                        add(f | t << 6)
        # castling: the rights, the empty squares, and no square the king crosses attacked
        c, foe = self.castle, 1 - me
        if me == WHITE:
            if c & WK and not b[5] and not b[6] and not (self.attacked(4, foe) or self.attacked(5, foe) or self.attacked(6, foe)):
                add(4 | 6 << 6)
            if c & WQ and not b[3] and not b[2] and not b[1] and not (self.attacked(4, foe) or self.attacked(3, foe) or self.attacked(2, foe)):
                add(4 | 2 << 6)
        else:
            if c & BK and not b[61] and not b[62] and not (self.attacked(60, foe) or self.attacked(61, foe) or self.attacked(62, foe)):
                add(60 | 62 << 6)
            if c & BQ and not b[59] and not b[58] and not b[57] and not (self.attacked(60, foe) or self.attacked(59, foe) or self.attacked(58, foe)):
                add(60 | 58 << 6)
        return out

    def push(self, m):
        b = self.b
        f, t, promo = m & 63, m >> 6 & 63, m >> 12
        p, cap = b[f], b[t]
        me = self.turn
        self.stack.append((m, cap, self.castle, self.ep, self.half))
        kind = p & 7
        b[f] = 0
        b[t] = promo | me << 3 if promo else p
        if kind == PAWN:
            self.half = 0
            if t == self.ep:
                b[t + (-8 if me == WHITE else 8)] = 0
            self.ep = (f + t) // 2 if abs(f - t) == 16 else -1
        else:
            self.half = 0 if cap else self.half + 1
            self.ep = -1
            if kind == KING:
                self.kings[me] = t
                if t - f == 2:
                    b[f + 1], b[f + 3] = b[f + 3], 0
                elif f - t == 2:
                    b[f - 1], b[f - 4] = b[f - 4], 0
        self.castle &= CASTLE_KEEP[f] & CASTLE_KEEP[t]
        if me == BLACK:
            self.full += 1
        self.turn = 1 - me

    def pop(self):
        m, cap, self.castle, ep, self.half = self.stack.pop()
        self.ep = ep
        b = self.b
        f, t, promo = m & 63, m >> 6 & 63, m >> 12
        me = 1 - self.turn
        self.turn = me
        if me == BLACK:
            self.full -= 1
        p = PAWN | me << 3 if promo else b[t]
        b[f], b[t] = p, cap
        kind = p & 7
        if kind == PAWN and t == ep and not cap:
            b[t + (-8 if me == WHITE else 8)] = PAWN | (1 - me) << 3
        elif kind == KING:
            self.kings[me] = f
            if t - f == 2:
                b[f + 3], b[f + 1] = b[f + 1], 0
            elif f - t == 2:
                b[f - 4], b[f - 1] = b[f - 1], 0
        return m

    def legal(self):
        out = []
        me = self.turn
        foe = 1 - me
        for m in self.pseudo():
            self.push(m)
            if not self.attacked(self.kings[me], foe):
                out.append(m)
            self.pop()
        return out

    def has_legal(self):
        me = self.turn
        foe = 1 - me
        for m in self.pseudo():
            self.push(m)
            ok = not self.attacked(self.kings[me], foe)
            self.pop()
            if ok:
                return True
        return False

    def is_capture(self, m):
        return bool(self.b[m >> 6 & 63]) or (m >> 6 & 63 == self.ep and self.b[m & 63] & 7 == PAWN)

    def san(self, m, moves=None):
        """A legal move in Standard Algebraic Notation, with + or # (moves: the legal ones, if known)."""
        f, t, promo = m & 63, m >> 6 & 63, m >> 12
        kind = self.b[f] & 7
        if kind == KING and abs(f - t) == 2:
            s = "O-O" if t > f else "O-O-O"
        else:
            s = LETTER[kind]
            if kind == PAWN:
                if f % 8 != t % 8:
                    s = "abcdefgh"[f % 8]
            else:
                others = [o & 63 for o in (self.legal() if moves is None else moves)
                          if o >> 6 & 63 == t and o & 63 != f and self.b[o & 63] & 7 == kind]
                if others:
                    if all(o % 8 != f % 8 for o in others):
                        s += "abcdefgh"[f % 8]
                    elif all(o // 8 != f // 8 for o in others):
                        s += str(f // 8 + 1)
                    else:
                        s += sq_name(f)
            if self.is_capture(m):
                s += "x"
            s += sq_name(t)
            if promo:
                s += "=" + LETTER[promo]
        self.push(m)
        if self.in_check():
            s += "+" if self.has_legal() else "#"
        self.pop()
        return s

    def parse_san(self, text):
        """The legal move that text names, or None: SAN (checks, marks and 'x' optional), UCI, 0-0."""
        names = self.names()
        t = _plain(text)
        return names.get(t) or (names.get("B" + t[1:]) if t[:1] == "b" else None)

    def names(self):
        """Every way of typing each legal move → the move; a spelling two moves share is left out."""
        moves = self.legal()
        out, shared = {}, set()
        for m in moves:
            for name in self.spellings(m, moves):
                if name in out and out[name] != m:
                    shared.add(name)
                out[name] = m
        for name in shared:
            del out[name]
        return out

    def spellings(self, m, moves=None):
        """The typed forms of a legal move, all in _plain form: full SAN without marks, without x
        (exd5, ed5), the from-to (e2e4), the promotion with or without '='."""
        full = _plain(self.san(m, moves))
        out = {full, _plain(uci(m)), full.replace("x", "")}
        if self.b[m & 63] & 7 == PAWN and m & 63 & 7 != (m >> 6 & 63) & 7:
            out.add(full[0] + "abcdefgh"[(m >> 6 & 63) % 8])    # ed: the pawn takes towards a file
        return out

    def stage_material(self):
        """(minors and majors, pawns) of each side, for insufficient material and the phase."""
        count = [[0] * 7, [0] * 7]
        for p in self.b:
            if p:
                count[p >> 3 & 1][p & 7] += 1
        return count

    def insufficient(self):
        """Neither side can mate by any legal play (FIDE 5.2.2's plain cases): K v K, K+minor v K,
        K+B v K+B with both bishops on one colour of square."""
        minors, bishops = [], []
        for s, p in enumerate(self.b):
            k = p & 7
            if k in (PAWN, ROOK, QUEEN):
                return False
            if k in (KNIGHT, BISHOP):
                minors.append(k)
                if k == BISHOP:
                    bishops.append((s % 8 + s // 8) % 2)
        if len(minors) <= 1:
            return True
        return len(minors) == len(bishops) and len(set(bishops)) == 1

    def see(self, s, by):
        """What `by` wins, in pawns, by the best exchange on s — 0 if it would rather not start one
        (static exchange: each side takes with its cheapest, may stop at any point; pins ignored)."""
        target = self.b[s]
        if not target:
            return 0
        b = self.b[:]
        gains, side = [VALUE[target & 7]], by
        while True:
            att = self.attackers(s, side, b)
            if not att:
                break
            frm = min(att, key=lambda t: VALUE[b[t] & 7])
            kind = b[frm] & 7
            if kind == KING and self.attackers(s, 1 - side, _without(b, frm)):
                break                      # (the king cannot take into a guard)
            gains.append(VALUE[kind] - gains[-1])
            b[frm] = 0
            side = 1 - side
        for i in range(len(gains) - 2, 0, -1):
            gains[i - 1] = -max(-gains[i - 1], gains[i])
        return gains[0] if len(gains) > 1 and gains[0] > 0 else 0

    def hanging(self, side):
        """The squares of side's pieces the other side wins something by taking now (a piece pinned
        to its king takes nothing)."""
        out = []
        foe = 1 - side
        for s, p in enumerate(self.b):
            if p and p >> 3 & 1 == side and p & 7 != KING and self.see(s, foe) > 0:
                q = self.copy()
                q.turn, q.ep = foe, -1
                for a in q.attackers(s, foe):
                    q.push(a | s << 6)
                    free = not q.attacked(q.kings[foe], side)
                    q.pop()
                    if free:
                        out.append(s)
                        break
        return out


def _without(b, s):
    c = b[:]
    c[s] = 0
    return c


def _plain(text):
    """A typed move in one form: no marks, castling in letters, pieces in capitals where a lower
    case letter can only be a piece (n r q k — b stays the file, B the bishop)."""
    t = text.strip().rstrip("+#!?").replace("0", "O").replace("=", "")
    low = t.lower().replace("-", "")
    if low in ("o", "oo", "ooo"):
        return {"o": "O", "oo": "O-O", "ooo": "O-O-O"}[low]
    if t[:1] in ("n", "r", "q", "k"):
        t = t[0].upper() + t[1:]
    m = re.fullmatch(r"([a-h][18]|[a-h]x[a-h][18]|[a-h][1-8]x?[a-h][18])([nbrqNBRQ])", t)
    if m:
        t = m[1] + m[2].upper()
    return t


def matching(pos, typed, names=None):
    """The legal moves a part-typed move may still become, as {move: True} in generation order, and
    whether what is typed is by itself a whole name of one of them."""
    names = pos.names() if names is None else names
    t = _plain(typed) if typed else ""
    # (typed as it is, too: "a1b" on the way to a1b3 is not a promotion to a bishop)
    tries = (t, typed.strip()) if typed else (t,)
    found = {m: True for name, m in names.items() if name.startswith(tries)}
    if not found and t[:1] == "b":        # (no pawn on the b-file does that: the bishop was meant)
        t = "B" + t[1:]
        found = {m: True for name, m in names.items() if name.startswith(t)}
    return found, names.get(t)


class Game:
    """A game from a start position: its moves, its SANs, how it stands. Draws as chess.com plays
    them, automatically: threefold, the 50-move rule, insufficient material, stalemate."""

    def __init__(self, fen=START):
        self.start = fen
        self.pos = Position(fen)
        self.moves = []
        self.sans = []
        self.keys = {self.pos.key(): 1}
        self.keylog = [self.pos.key()]
        self.result = "*"
        self.why = ""
        self.check_end()

    def play(self, m):
        self.sans.append(self.pos.san(m))
        self.pos.push(m)
        self.moves.append(m)
        k = self.pos.key()
        self.keys[k] = self.keys.get(k, 0) + 1
        self.keylog.append(k)
        self.check_end()

    def undo(self):
        if not self.moves:
            return
        self.pos.pop()
        self.moves.pop()
        self.sans.pop()
        k = self.keylog.pop()
        self.keys[k] -= 1
        if not self.keys[k]:
            del self.keys[k]
        self.result, self.why = "*", ""
        self.check_end()

    def check_end(self):
        p = self.pos
        if not p.has_legal():
            if p.in_check():
                self.result, self.why = ("0-1" if p.turn == WHITE else "1-0"), "checkmate"
            else:
                self.result, self.why = "1/2-1/2", "stalemate"
        elif p.insufficient():
            self.result, self.why = "1/2-1/2", "insufficient material"
        elif p.half >= 100:
            self.result, self.why = "1/2-1/2", "the fifty-move rule"
        elif self.keys[self.keylog[-1]] >= 3:
            self.result, self.why = "1/2-1/2", "threefold repetition"

    def end(self, result, why):
        self.result, self.why = result, why

    def over(self):
        return self.result != "*"

    def replay(self, upto):
        """The position after `upto` of the game's moves."""
        p = Position(self.start)
        for m in self.moves[:upto]:
            p.push(m)
        p.stack.clear()
        return p

    def movetext(self):
        p = Position(self.start)
        out = []
        for i, s in enumerate(self.sans):
            if p.turn == WHITE:
                out.append(f"{p.full}. {s}")
            elif i == 0:
                out.append(f"{p.full}... {s}")
            else:
                out.append(s)
            p.push(self.moves[i])
        out.append(self.result)
        return " ".join(out)

    def pgn(self, tags=None):
        tags = dict(tags or {})
        head = {"Event": "kawa-chess", "Site": "-", "Date": "????.??.??", "Round": "-",
                "White": "?", "Black": "?", "Result": self.result}
        head.update(tags)
        head["Result"] = self.result
        if self.start != START:
            head["SetUp"] = "1"
            head["FEN"] = self.start
        lines = [f'[{k} "{str(v).replace(chr(92), "").replace(chr(34), "")}"]' for k, v in head.items()]
        return "\n".join(lines) + "\n\n" + _wrap(self.movetext()) + "\n"


def _wrap(text, width=80):
    lines, cur = [], ""
    for word in text.split():
        if len(cur) + 1 + len(word) > width and cur:
            lines.append(cur)
            cur = word
        else:
            cur = f"{cur} {word}" if cur else word
    if cur:
        lines.append(cur)
    return "\n".join(lines)


_TAG = re.compile(r'^\s*\[(\w+)\s+"((?:[^"\\]|\\.)*)"\]\s*$', re.M)
_NOISE = re.compile(r"\{[^}]*\}|;[^\n]*|\$\d+")


def read_pgn(text):
    """One PGN game → (tags, Game). ValueError on a move that is not legal or a text with no game."""
    tags = dict(_TAG.findall(text))
    body = _TAG.sub("", text)
    body = _NOISE.sub(" ", body)
    while "(" in body:                  # (variations, nested ones from the inside out)
        new = re.sub(r"\([^()]*\)", " ", body)
        if new == body:
            raise ValueError("unbalanced variation")
        body = new
    g = Game(tags.get("FEN", START))
    result = None
    for tok in body.split():
        tok = re.sub(r"^\d+\.+", "", tok)
        if not tok or tok == "." or tok == "...":
            continue
        if tok in ("1-0", "0-1", "1/2-1/2", "*"):
            result = tok
            break
        if g.over():
            raise ValueError(f"a move after the game's end: {tok!r}")
        m = g.pos.parse_san(tok)
        if m is None:
            raise ValueError(f"not a legal move: {tok!r} at {g.pos.fen()}")
        g.play(m)
    if result is None and not g.moves:
        raise ValueError("no game in this text")
    if result and result != "*" and not g.over():
        g.end(result, tags.get("Termination", "as recorded"))
    return tags, g


def perft(p, depth):
    if depth == 0:
        return 1
    moves = p.legal()
    if depth == 1:
        return len(moves)
    n = 0
    for m in moves:
        p.push(m)
        n += perft(p, depth - 1)
        p.pop()
    return n
