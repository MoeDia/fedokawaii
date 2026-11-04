"""A game: the board under your hand, Stockfish across it, the clocks, and what a move can be typed as.

Moves: typed in algebraic (Nf3, exd5, O-O — lower case and no x are fine), the arrows and Enter, or
the mouse. A man picked up shows where he can go. Esc: first what you were doing, then the menu.
"""
import random
import time

import board as B
from app import Screen
from engine import analysis_request, choose_weak, play_request
from term import ACCENT_TEXT, FAINT, MUTED, STRONG
from ui import Face, Row, heading, icon, wrap

ALLOWED = set("abcdefghABCDEFGHxXNRQKnrqkO0o-=+#12345678")


def fmt_clock(sec):
    if sec is None:
        return ""
    sec = max(0, int(sec + 0.999))
    return f"{sec // 60}:{sec % 60:02d}"


class MoveInput:
    """Every way a move gets made, for a position and the side to move's hand."""

    def __init__(self):
        self.pos = None
        self.names = {}
        self.moves = []
        self.clear()

    def clear(self):
        self.typed = ""
        self.bad = ""              # what was typed last that no move could become
        self.picked = None         # the square of the man picked up
        self.cursor = None         # the keyboard's place on the board
        self.promo = None          # the promotions waiting for a choice of man

    def reset(self, pos):
        self.pos = pos
        self.moves = pos.legal()
        self.names = pos.names()
        self.clear()

    def holds(self):
        """Is anything in hand (that Esc would let go of first)?"""
        return bool(self.typed or self.bad or self.picked is not None or self.promo or self.cursor is not None)

    def letgo(self):
        self.clear()

    def text(self, chars):
        """Keys typed: returns the move when one is decided (a promotion's letter, for one)."""
        for ch in chars:
            if self.promo:
                kind = {"q": B.QUEEN, "r": B.ROOK, "b": B.BISHOP, "n": B.KNIGHT}.get(ch.lower())
                if kind:
                    for m in self.promo:
                        if m >> 12 == kind:
                            self.clear()
                            return m
                continue
            if ch not in ALLOWED:
                continue
            self.cursor = None
            self.picked = None
            found, _ = B.matching(self.pos, self.typed + ch, self.names)
            if found:
                self.typed += ch
                self.bad = ""
            else:
                self.bad = self.typed + ch
        return None

    def backspace(self):
        if self.bad:
            self.bad = ""
        elif self.typed:
            self.typed = self.typed[:-1]

    def enter(self):
        """Enter: what is typed or under the cursor. Returns a move, or None (a choice still open)."""
        if self.promo:
            for m in self.promo:
                if m >> 12 == B.QUEEN:
                    self.clear()
                    return m
            return None
        if self.typed:
            found, exact = B.matching(self.pos, self.typed, self.names)
            if exact is not None:
                self.clear()
                return exact
            cands = list(found)
            if len(cands) == 1:
                self.clear()
                return cands[0]
            if cands and all(m >> 12 for m in cands) and len({m & 4095 for m in cands}) == 1:
                self.promo = cands      # (a pawn's last step typed without its man: which one?)
                self.typed = ""
            return None
        if self.cursor is not None:
            return self.touch(self.cursor)
        return None

    def touch(self, sq):
        """A square chosen (click, or Enter on the cursor): pick up, put down, or change your mind."""
        self.typed, self.bad = "", ""
        pos = self.pos
        if self.picked is not None:
            options = [m for m in self.moves if m & 63 == self.picked and m >> 6 & 63 == sq]
            if options:
                if len(options) > 1:
                    self.promo = options
                    return None
                self.picked = None
                self.cursor = None
                return options[0]
            if sq == self.picked:
                self.picked = None
                return None
        p = pos.b[sq]
        if p and p >> 3 & 1 == pos.turn and any(m & 63 == sq for m in self.moves):
            self.picked = sq
        else:
            self.picked = None
        return None

    def arrow(self, name, flipped, start):
        """The cursor moved a square as the board is seen; it starts at `start`."""
        if self.cursor is None:
            self.cursor = self.picked if self.picked is not None else start
        else:
            f, r = self.cursor % 8, self.cursor // 8
            dx, dy = {"left": (-1, 0), "right": (1, 0), "up": (0, 1), "down": (0, -1)}[name]
            if flipped:
                dx, dy = -dx, -dy
            f, r = min(7, max(0, f + dx)), min(7, max(0, r + dy))
            self.cursor = f + 8 * r
        self.typed, self.bad = "", ""

    def marks(self):
        """What the hand shows on the board: the man up, where he can go; what typing still allows."""
        out = {}
        add = lambda s, m: out.setdefault(s, set()).add(m)  # noqa: E731
        pos = self.pos
        if self.cursor is not None:
            add(self.cursor, "cur")
        if pos is None:
            return out
        src = None
        if self.picked is not None:
            src = [m for m in self.moves if m & 63 == self.picked]
            add(self.picked, "sel")
        elif self.typed:
            src = list(B.matching(pos, self.typed, self.names)[0])
            for m in src:
                add(m & 63, "sel")
        elif self.promo:
            src = self.promo
            add(self.promo[0] & 63, "sel")
        for m in src or ():
            t = m >> 6 & 63
            add(t, "take" if pos.is_capture(m) else "dot")
        return out


def moves_rows(g, w, room, mark):
    """A game's moves in two columns, the move `mark` in the strong ink and in view; a narrow panel gives each its line."""
    p = B.Position(g.start)
    first_black = p.turn == B.BLACK
    full = p.full
    rows = []
    at = 0                         # (the row of the marked move)
    if w >= 22:
        i = 0
        while i < len(g.sans):
            a = "..." if first_black and i == 0 else g.sans[i]
            k = 0 if first_black and i == 0 else 1
            b = g.sans[i + k] if i + k < len(g.sans) else ""
            if mark in (i, i + k):
                at = len(rows)
            ink_a = STRONG if i == mark and k else None
            ink_b = STRONG if i + k == mark else None
            rows.append([" ", (f"{full}.".ljust(5), MUTED), (a.ljust(9), ink_a), (b, ink_b)])
            i += 1 + k
            full += 1
    else:
        black = first_black
        for j, san in enumerate(g.sans):
            num = "" if black else f"{full}."
            if j == mark:
                at = len(rows)
            rows.append([" ", (num.ljust(4), MUTED), (san, STRONG if j == mark else None)])
            if black:
                full += 1
            black = not black
    if room <= 0:
        return []
    top = max(0, min(at - room + 1, len(rows) - room)) if at >= room else 0
    if at == len(rows) - 1:
        top = max(0, len(rows) - room)
    return rows[top:top + room]


def hand_line(hand, idle=""):
    """The input line: the chevron, then what is typed, or why it is no move, or what is asked."""
    line = [(icon("CHEVRON_RIGHT"), ACCENT_TEXT), "  "]
    if hand.promo:
        line.append(("queen, rook, bishop or knight: q r b n", MUTED))
    elif hand.bad:
        line += [(icon("CROSS"), ACCENT_TEXT), "  ", hand.bad, "  ", ("no such move", MUTED)]
    elif hand.typed:
        line.append((hand.typed, STRONG))
    elif idle:
        line.append((idle, FAINT))
    return line


def board_marks(pos, last, hanging=(), extra=None):
    """The marks of the game itself: the last move's squares, a king in check, men in danger."""
    out = {}
    if last is not None:
        out.setdefault(last & 63, set()).add("last")
        out.setdefault(last >> 6 & 63, set()).add("last")
    if pos.in_check():
        out.setdefault(pos.kings[pos.turn], set()).add("check")
    for s in hanging:
        out.setdefault(s, set()).add("warn")
    for s, ms in (extra or {}).items():
        out.setdefault(s, set()).update(ms)
    return out


def moved_parts(pos, m):
    """(piece, from, to) of everything a move shifts, on the position before it (a castling's rook too)."""
    f, t = m & 63, m >> 6 & 63
    p = pos.b[f]
    parts = [(p, f, t)]
    if p & 7 == B.KING and abs(f - t) == 2:
        rf, rt = (f + 3, f + 1) if t > f else (f - 4, f - 1)
        parts.append((pos.b[rf], rf, rt))
    return parts


class Game(Screen):
    """spec: title, goal, fen, line (moves already on the board, UCI), colour, elo, clock ((minutes,
    increment) or None), hints, threats, opponent, no (the game's number in the course, or None)."""

    def __init__(self, spec, saved=None, done=None):
        self.spec = spec
        self.done_cb = done
        self.me = spec["colour"]
        self.g = B.Game(spec["fen"])
        for u in spec.get("line") or ():
            m = B.from_uci(u)
            if m not in self.g.pos.legal():
                raise ValueError(f"not a move here: {u}")
            self.g.play(m)
        self.n_line = len(self.g.moves)
        self.hand = MoveInput()
        self.flipped = self.me == B.BLACK
        self.clock = None
        if spec.get("clock"):
            self.clock = [spec["clock"][0] * 60.0, spec["clock"][0] * 60.0]
        self.times = []
        self.hints_used = 0
        self.hint = None             # (move, stage): the lantern, then the arrow
        self.hint_wait = False
        self.note = ""               # one line under the input
        self.menu = None
        self.cursor = None
        self.reply = None            # (when, uci) the engine's move, waiting for its moment
        self.asked = False
        self.t_mark = time.monotonic()
        self.paused = False
        self.ended = False
        self.draw_wait = False
        self.show_threats = bool(spec.get("threats"))
        self.rng = random.Random()
        self.thinking_since = None
        self.shown = None
        self.landing = None          # (a move on its way: its squares lit from its first frame)
        self.begun = False
        self.burst_on = None         # (the square of a capture just made: its sparks fly at the next frame)
        self.fallen = None           # (the beaten king's square, how far he has fallen)
        self.fall_at = 0
        if saved:
            self._restore(saved)
        self.hand.reset(self.g.pos)
        self.t_mark = time.monotonic()

    # ── keeping it ───────────────────────────────────────────────────────────────────────────
    def _restore(self, saved):
        for u in saved["moves"][self.n_line:]:
            m = B.from_uci(u)
            if m not in self.g.pos.legal() or self.g.over():
                raise ValueError(f"not a move here: {u}")
            self.g.play(m)
        self.clock = saved.get("clock", self.clock)
        self.times = saved.get("times", [])
        self.hints_used = saved.get("hints_used", 0)

    def save(self):
        self.app.store.save("current.json", {
            "spec": self.spec, "moves": [B.uci(m) for m in self.g.moves], "clock": self.clock,
            "times": self.times, "hints_used": self.hints_used})

    # ── time ─────────────────────────────────────────────────────────────────────────────────
    def _charge(self, now):
        """The clock of the side to move runs from the last mark to now (not while paused)."""
        dt = now - self.t_mark
        self.t_mark = now
        if self.clock is not None and not self.paused and not self.g.over():
            self.clock[self.g.pos.turn] -= dt
        return dt

    def focus(self, on):
        now = time.monotonic()
        self._charge(now)
        self.paused = not on
        self.t_mark = now

    # ── the board ────────────────────────────────────────────────────────────────────────────
    def board(self):
        pos = self.g.pos
        last = self.landing if self.landing is not None else self.g.moves[-1] if self.g.moves else None
        hanging = pos.hanging(self.me) if self.show_threats and not self.g.over() and self.landing is None else ()
        marks = board_marks(pos, last, hanging)
        for s, ms in self.hand.marks().items():
            marks.setdefault(s, set()).update(ms)
        arrows = []
        if self.hint:
            m, stage = self.hint
            marks.setdefault(m & 63, set()).add("hint")
            if stage > 1:
                arrows.append((m & 63, m >> 6 & 63, "asagi"))
        if self.ended and self.fallen is not None:
            marks.setdefault(self.fallen[0], set()).add(f"fall{self.fallen[1]}")
        return pos.b, marks, arrows, self.flipped

    # ── the panel ────────────────────────────────────────────────────────────────────────────
    def panel(self, w, h):
        spec = self.spec
        now = time.monotonic()
        top = [heading("KNIGHT", spec["title"], w), ""] if h > 8 else []
        goal = wrap(spec.get("goal") or "", w) if spec.get("goal") and h >= 24 else []
        if goal:
            top += [[(line, MUTED)] for line in goal] + [""]
        if spec.get("card") and h >= 28 and w >= 30:     # (the Steps Method's three questions, the first months)
            top += [[("material? mate? danger?", FAINT)], ""]
        opp_turn = self.g.pos.turn != self.me and not self.g.over()
        hg = f"HG_{int(now * 6) % 5}" if opp_turn and not self.paused else None
        me = self._side_row("you", self.me, None)
        foot = self._input_lines(w)
        lower = [me, ""] + foot
        opp = self._opponent(w, h, hg)
        room = h - len(top) - len(opp) - len(lower) - (1 if h > 12 else 0)
        middle = self.menu_lines(w, room) if self.menu else self._moves(w, room)
        lines = top + opp + middle
        lines += [""] * max(0, h - len(lines) - len(lower)) + lower
        return lines[:h]

    def menu_lines(self, w, room):
        return list(self.menu)

    def _opponent(self, w, h, hg):
        """Who sits across: the face and the words beside it, where there is room for them."""
        side = 1 - self.me
        name = self.spec.get("opponent", "stockfish")
        if w < 26 or h < 20:
            return [self._side_row(name, side, hg), ""]
        turn = self.g.pos.turn == side and not self.g.over()
        left = None
        if self.clock:
            left = self.clock[side] - (time.monotonic() - self.t_mark if turn and not self.paused else 0)
        clock = fmt_clock(left)
        room = w - Face.COLS + 1
        title = name + self._ahead(side)
        pad = room - len(title) - len(clock)
        low = f"level {self.spec['elo']}"
        top = [(title, STRONG if turn else None), " " * max(1, pad), (clock, ACCENT_TEXT if left is not None and left < 30 else STRONG if turn else MUTED)]
        bottom = [(low, MUTED)]
        if hg:
            bottom += [" " * max(1, room - len(low) - 2), (icon(hg), MUTED)]
        return [Face(name, top, bottom), Face.BELOW, ""]

    def _ahead(self, side):
        """How much material a side is ahead, in pawns: "+3", or nothing."""
        d = sum(B.VALUE[p & 7] * (1 if p >> 3 & 1 == side else -1) for p in self.g.pos.b if p and p & 7 != B.KING)
        return f"  +{d}" if d > 0 else ""

    def _side_row(self, name, side, hg):
        name += self._ahead(side)
        turn = self.g.pos.turn == side and not self.g.over()
        left = None
        if self.clock:
            left = self.clock[side]
            if turn and not self.paused:
                left -= time.monotonic() - self.t_mark
        clock = fmt_clock(left)
        ink = STRONG if turn else None
        vink = STRONG if turn else MUTED
        if left is not None and left < 30:
            vink = ACCENT_TEXT
        ic = hg or ("USER" if side == self.me else "ONI")
        return Row(ic, name, clock, ink=ink, value_ink=vink)

    def _moves(self, w, room):
        return moves_rows(self.g, w, room, len(self.g.sans) - 1)

    def _input_lines(self, w):
        if self.g.over():
            return [[(self.note or " ", MUTED)], [""]]
        line = hand_line(self.hand, "your move" if self.g.pos.turn == self.me else "")
        return [line, [(self.note, MUTED)] if self.note else ""]

    # ── keys ─────────────────────────────────────────────────────────────────────────────────
    def key(self, name):
        self.note = ""
        if self.menu:
            return self._menu_key(name)
        if self.g.over():
            if name in ("enter", "esc"):
                self._leave_game()
            return None
        if name == "esc":
            if self.hand.holds():
                self.hand.letgo()
            else:
                self._open_menu()
            return None
        if self.g.pos.turn != self.me:
            return None
        hand = self.hand
        if name == "enter":
            m = hand.enter()
            if m is not None:
                self.play_mine(m)
        elif name == "backspace":
            hand.backspace()
        elif name in ("left", "right", "up", "down"):
            hand.arrow(name, self.flipped, self._cursor_home())
        return None

    def _cursor_home(self):
        if self.g.moves:
            return self.g.moves[-1] >> 6 & 63
        return B.sq_of("e2" if self.me == B.WHITE else "e7")

    def text(self, chars):
        self.note = ""
        for ch in chars:
            if self.menu or self.g.over():
                return
            if ch == "?":
                self._ask_hint()
            elif self.g.pos.turn != self.me or self.app.anim is not None:
                return
            elif ch == "t" and not self.hand.typed:
                self.show_threats = not self.show_threats
            else:
                m = self.hand.text(ch)
                if m is not None:
                    self.play_mine(m)

    def click(self, sq):
        if self.menu or self.g.over() or self.g.pos.turn != self.me:
            return
        self.note = ""
        m = self.hand.touch(sq)
        if m is not None:
            self.play_mine(m)

    # ── the menu (Esc) ───────────────────────────────────────────────────────────────────────
    def _open_menu(self):
        rows = [Row("CHEVRON_RIGHT", "back to the board", act="back"),
                Row("RESTART", "turn the board round", act="flip")]
        if self.spec.get("hints"):
            left = max(0, self.spec["hints"] - self.hints_used)
            rows.append(Row("LANTERN", "a hint", f"{left} left", act="hint"))
        rows += [Row("EQUALS", "offer a draw", act="draw"),
                 Row("CROSS", "resign", act="resign"),
                 Row("DOOR", "leave, kept for later", act="leave")]
        self.menu = rows
        self.cursor = None
        self._menu_at(0)

    def _menu_at(self, i):
        self.menu_i = max(0, min(len(self.menu) - 1, i))
        self.cursor = self._menu_row(self.menu_i)

    def _menu_row(self, i):
        # (where the menu's rows land among the panel's lines)
        lines = self.panel(self.app.layout.pw, self.app.layout.ph)
        rows = [k for k, ln in enumerate(lines) if ln is self.menu[i]]
        return rows[0] if rows else None

    def _menu_key(self, name):
        if name == "esc":
            self.menu = None
            self.cursor = None
        elif name == "up":
            self._menu_at(self.menu_i - 1)
        elif name == "down":
            self._menu_at(self.menu_i + 1)
        elif name == "enter":
            self._menu_act(self.menu[self.menu_i].act)

    def click_row(self, i):
        if not self.menu:
            return
        lines = self.panel(self.app.layout.pw, self.app.layout.ph)
        if i < len(lines) and hasattr(lines[i], "act") and lines[i].act:
            self._menu_act(lines[i].act)

    def hover(self, i):
        if self.menu:
            lines = self.panel(self.app.layout.pw, self.app.layout.ph)
            if i < len(lines) and lines[i] in self.menu:
                self.menu_i = self.menu.index(lines[i])
                self.cursor = i

    def _menu_act(self, act):
        self.menu, self.cursor = None, None
        if act == "flip":
            self.flipped = not self.flipped
        elif act == "hint":
            self._ask_hint()
        elif act == "draw":
            self._offer_draw()
        elif act == "resign":
            self._charge(time.monotonic())
            self.finish("0-1" if self.me == B.WHITE else "1-0", "you resigned")
        elif act == "leave":
            self.save()
            self.app.pop()

    # ── a hint: the lantern on the man, then the arrow ───────────────────────────────────────
    def _ask_hint(self):
        if self.g.pos.turn != self.me or self.g.over():
            return
        if self.hint and self.hint[1] == 1:
            self.hint = (self.hint[0], 2)
            return
        if self.hint:
            return
        if self.hints_used >= int(self.spec.get("hints") or 0):
            self.note = "no hints in this game" if not self.spec.get("hints") else "no hints left"
            return
        self.hint_wait = True
        self.note = "looking"
        self.app.engine.ask(analysis_request(self.g.start, [B.uci(m) for m in self.g.moves], self._hint_found, nodes=60000, multipv=1, tag=len(self.g.moves)))

    def _hint_found(self, s):
        self.hint_wait = False
        self.note = ""
        if s.tag == len(self.g.moves) and s.best:
            self.hints_used += 1
            self.hint = (B.from_uci(s.best), 1)
        self.app.touch()

    def _offer_draw(self):
        if self.g.pos.turn != self.me:
            return
        self.note = "thinking about it"
        self.draw_wait = True
        self.app.engine.ask(analysis_request(self.g.start, [B.uci(m) for m in self.g.moves], self._draw_answer, nodes=60000, multipv=1, tag=len(self.g.moves)))

    def _draw_answer(self, s):
        self.draw_wait = False
        lines = s.ranked()
        close = lines and abs(lines[0].score()) < 40 and len(self.g.moves) >= 40
        if close and not self.g.over():
            self._charge(time.monotonic())
            self.finish("1/2-1/2", "a draw agreed")
        else:
            self.note = "the offer is declined"
        self.app.touch()

    # ── moves ────────────────────────────────────────────────────────────────────────────────
    def play_mine(self, m):
        dt = self._charge(time.monotonic())
        self.times.append(round(dt, 1))
        self._apply(m)

    def _apply(self, m):
        pos = self.g.pos
        parts = moved_parts(pos, m)
        self.hint = None
        self.app.engine.cancel_all()
        hide = {p[1] for p in parts}

        self.landing = m
        took = pos.is_capture(m)

        def arrived():
            self.landing = None
            self.g.play(m)
            if self.clock and self.spec["clock"][1]:
                self.clock[1 - self.g.pos.turn] += self.spec["clock"][1]
            self.hand.reset(self.g.pos)
            self.t_mark = time.monotonic()
            self.save()
            if self.g.over():
                self.finish(self.g.result, self.g.why)
            self.burst_on = m >> 6 & 63 if took else None
            self.app.touch()

        self.app.slide(parts, hide, arrived)

    def _engine_move(self):
        s = self.spec
        moves = [B.uci(m) for m in self.g.moves]
        self.asked = True
        self.thinking_since = time.monotonic()
        self.app.engine.ask(play_request(self.g.start, moves, s["elo"], self._engine_answer, tag=len(moves)))

    def _engine_answer(self, sr):
        self.asked = False
        if self.ended or sr.tag != len(self.g.moves):
            return
        legal = [B.uci(m) for m in self.g.pos.legal()]
        if not legal:
            return
        if self.spec["elo"] < 1320:
            u = choose_weak(sr, legal, self.spec["elo"], self.rng)
        else:
            u = sr.best
        if u not in legal:                 # (the engine cannot be reached or says nonsense: any move, never a stop)
            u = self.rng.choice(legal)
        wait = self.rng.uniform(0.3, 1.3) if self.spec["elo"] < 1600 else self.rng.uniform(0.5, 2.0)
        self.reply = (self.thinking_since + wait, u)
        self.app.touch()

    def tick(self, now):
        if self.burst_on is not None:
            sq, self.burst_on = self.burst_on, None
            self.app.burst(sq)
        if self.ended:
            # (the beaten king topples, in three frames)
            if self.fallen is not None and self.fallen[1] < 3 and now >= self.fall_at:
                self.fallen = (self.fallen[0], self.fallen[1] + 1)
                self.fall_at = now + 0.09
                self.app.touch()
            return self.fall_at if self.fallen is not None and self.fallen[1] < 3 else None
        g = self.g
        if not self.begun:
            self.begun = True
            self.save()               # (from its first moment it is a game that can be taken up again)
        if self.clock and not self.paused:
            turn = g.pos.turn
            left = self.clock[turn] - (now - self.t_mark)
            if left <= 0:
                self._charge(now)
                self._flag(turn)
                return None
        if g.pos.turn != self.me:
            if self.reply is None and not self.asked and not self.paused:
                self._engine_move()
            if self.reply is not None and now >= self.reply[0]:
                u = self.reply[1]
                self.reply = None
                self._charge(now)
                self._apply(B.from_uci(u))
                return None
        # (words again only when they would differ: the clock's seconds, the hourglass's frame)
        shown = (int(now * 6) % 5 if g.pos.turn != self.me else None,
                 int(self.clock[g.pos.turn] - (now - self.t_mark) + 0.999) if self.clock and not self.paused else None)
        if shown != self.shown:
            self.shown = shown
            self.app.touch()
        return now + (1 / 6 if g.pos.turn != self.me else 0.25 if self.clock else 5)

    def _flag(self, side):
        """Time is up: a loss, unless the other side has nothing to mate with (a draw, as on chess.com)."""
        q = self.g.pos.copy()
        for s, p in enumerate(q.b):
            if p and p >> 3 & 1 == side and p & 7 != B.KING:
                q.b[s] = 0
        if q.insufficient():
            self.finish("1/2-1/2", "time, nothing left to mate with")
        else:
            self.finish("0-1" if side == B.WHITE else "1-0", "on time")

    # ── the end ──────────────────────────────────────────────────────────────────────────────
    def finish(self, result, why):
        if self.ended:
            return
        self.ended = True
        self.app.engine.cancel_all()
        if not self.g.over():
            self.g.end(result, why)
        won = (result == "1-0") == (self.me == B.WHITE) and result != "1/2-1/2"
        word = "a draw" if result == "1/2-1/2" else "you won" if won else "you lost"
        self.note = f"{word}: {why}"
        self.hand.clear()
        self.outcome = {"result": result, "why": why, "won": won, "draw": result == "1/2-1/2"}
        if result != "1/2-1/2":
            loser = B.BLACK if result == "1-0" else B.WHITE
            self.fallen = (self.g.pos.kings[loser], 0)
            self.fall_at = time.monotonic() + 0.25
        # (the record first, the game in hand gone after it: nothing is lost between the two)
        if self.done_cb:
            self.done_cb(self)
        self.app.store.delete("current.json")
        self.app.touch()

    def _leave_game(self):
        self.app.pop()

    def leave(self):
        if not self.ended and self.begun:
            self._charge(time.monotonic())
            self.save()
