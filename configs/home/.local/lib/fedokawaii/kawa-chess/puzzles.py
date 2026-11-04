"""Puzzles: Lichess's (CC0) by theme and rating, your rating moved by Glicko-2 as Lichess's is, what you
miss comes back on a widening schedule (Woodpecker's repetition, your own blunders too); ten minutes a day.
"""
import math
import os
import random
import time

import board as B
from app import Screen
from play import MoveInput, board_marks, moved_parts
from term import ACCENT_TEXT, MUTED, STRONG
from ui import Row, heading, icon, meter, wrap

SESSION = 600.0                    # ten minutes
REPEAT_DAYS = (1, 3, 7, 21)        # after a miss: again on these days


class Bank:
    """The shipped set: id, FEN, moves, rating, themes, tab-separated, read when first asked for."""

    def __init__(self, path):
        self.path = path
        self.items = None
        self.bad = 0

    def load(self):
        if self.items is not None:
            return
        self.items = []
        self.by_id = {}
        try:
            with open(self.path, encoding="utf-8", errors="replace") as f:
                for line in f:
                    if line.startswith("#"):
                        continue
                    p = line.rstrip("\n").split("\t")
                    # (a line that is damaged is simply not a puzzle: nothing is asked of it yet)
                    if len(p) < 5 or not p[3].isdigit() or " " not in p[1] or len(p[2]) < 4:
                        self.bad += 1
                        continue
                    item = (p[0], p[1], p[2], int(p[3]), p[4])
                    self.items.append(item)
                    self.by_id[p[0]] = item
        except OSError:
            self.bad += 1

    def pick(self, theme, rating, seen, rng, spread=150):
        """A puzzle of that theme, near the rating, not seen yet; the band widens until one turns up."""
        self.load()
        if not self.items:
            return None
        tag = f" {theme} " if theme else None
        lo, hi = rating - spread, rating + spread // 2
        for _ in range(6):
            pool = [it for it in self.items if lo <= it[3] <= hi and it[0] not in seen and (tag is None or tag in f" {it[4]} ")]
            if pool:
                return rng.choice(pool)
            lo -= spread
            hi += spread
        pool = [it for it in self.items if it[0] not in seen]
        return rng.choice(pool) if pool else rng.choice(self.items)


def glicko2(r, rd, vol, opp_r, opp_rd, score, tau=0.75):
    """One rating period of one game, as in Glickman's example (Lichess's own constants are close)."""
    q = math.log(10) / 400
    mu, phi = (r - 1500) * q, rd * q
    mu_j, phi_j = (opp_r - 1500) * q, opp_rd * q
    g = 1 / math.sqrt(1 + 3 * phi_j * phi_j / math.pi ** 2)
    E = 1 / (1 + math.exp(-g * (mu - mu_j)))
    v = 1 / (g * g * E * (1 - E))
    delta = v * g * (score - E)
    a = math.log(vol * vol)

    def f(x):
        ex = math.exp(x)
        return ex * (delta * delta - phi * phi - v - ex) / (2 * (phi * phi + v + ex) ** 2) - (x - a) / (tau * tau)

    A, B_ = a, 0.0
    if delta * delta > phi * phi + v:
        B_ = math.log(delta * delta - phi * phi - v)
    else:
        k = 1
        while f(a - k * tau) < 0:
            k += 1
        B_ = a - k * tau
    fa, fb = f(A), f(B_)
    for _ in range(50):
        if abs(B_ - A) < 1e-6:
            break
        C = A + (A - B_) * fa / (fb - fa)
        fc = f(C)
        if fc * fb < 0:
            A, fa = B_, fb
        else:
            fa /= 2
        B_, fb = C, fc
    new_vol = math.exp(A / 2)
    star = math.sqrt(phi * phi + new_vol * new_vol)
    new_phi = 1 / math.sqrt(1 / (star * star) + 1 / v)
    new_mu = mu + new_phi * new_phi * g * (score - E)
    return new_mu / q + 1500, max(45.0, min(350.0, new_phi / q)), new_vol


class Session(Screen):
    """A sitting of puzzles; theme: Lichess's theme key or None. done(): the time is used up."""

    def __init__(self, title, theme, left=SESSION, done=None, count_limit=None, rating_shift=0, themes=None, fixed_rating=None, no_due=False):
        self.title, self.theme = title, theme
        self.themes, self.fixed_rating, self.no_due = themes, fixed_rating, no_due
        self.left = left
        self.done_cb = done
        self.count_limit = count_limit
        self.shift = rating_shift
        self.hand = MoveInput()
        self.rng = random.Random()
        self.pos = None
        self.flipped = False
        self.item = None
        self.line = []
        self.at = 0
        self.first = True
        self.failed_now = False
        self.solved = 0
        self.tried = 0
        self.note = ""
        self.finished = False
        self.t_mark = time.monotonic()
        self.reply_at = None
        self.last = None
        self.shown = None
        self.paused = False
        self.showing = False       # (the solution played out, a key goes on)
        self.cursor = None
        self.d0 = None

    def bank(self):
        return self.app.bank

    def _state(self):
        return self.app.progress

    def start(self):
        self.d0 = self._state().puzzle["r"]
        self.next_puzzle()

    def tick(self, now):
        if self.item is None and not self.finished:
            self.start()
            self.app.touch()
        if self.finished:
            return None
        if self.reply_at is not None and now >= self.reply_at:
            self.reply_at = None
            self._reply()
            return None
        if self.count_limit is not None:
            return self.reply_at
        if not self.paused:
            dt = now - self.t_mark
            self.t_mark = now
            self.left -= dt
            if self.left <= 0 and not self.finished:
                self.left = 0
                if self.reply_at is None:
                    self._finish()
                return None
        sec = int(self.left + 0.999)
        if sec != self.shown:
            self.shown = sec
            self.app.touch()
        return now + 0.25

    def focus(self, on):
        self.t_mark = time.monotonic()
        self.paused = not on

    def next_puzzle(self):
        pr = self._state()
        if self.count_limit is not None and self.tried >= self.count_limit:
            self._finish()
            return
        item = None if self.no_due else pr.due_puzzle()
        if item is None:
            self.bank().load()
            theme = self.rng.choice(self.themes) if self.themes else self.theme
            rating = self.fixed_rating if self.fixed_rating is not None else int(pr.puzzle["r"]) + self.shift
            item = self.bank().pick(theme, rating, pr.seen, self.rng)
        if item is None:
            self.note = "no puzzles"
            self._finish()
            return
        self.item = item
        self.failed_now = False
        self.first = True
        self.showing = False
        try:
            self.pos = B.Position(item[1])
            self.line = [B.from_uci(u) for u in item[2].split()]
            if self.line[0] not in self.pos.legal():
                raise ValueError("first move illegal")
        except (ValueError, IndexError):
            pr.forget_due(item[0])         # (a damaged puzzle: not this one)
            self.bank().items = [it for it in self.bank().items if it[0] != item[0]]
            self.next_puzzle()
            return
        # Lichess: the position is before the opponent's move; he moves first, you answer
        self.at = 0
        self.last = None
        self.flipped = (self.pos.turn == B.WHITE)   # (the side to answer is the other)
        self.reply_at = time.monotonic() + 0.55
        self.hand.reset(self.pos)
        self.hand.pos = None
        self.note = ""
        self.app.trace("puzzle", item[0], item[1], item[2], item[3])

    def _reply(self):
        """The line's next move by the other side."""
        if self.at >= len(self.line):
            self._solved()
            return
        m = self.line[self.at]
        pos = self.pos
        parts = moved_parts(pos, m)

        def arrived():
            pos.push(m)
            self.last = m
            self.at += 1
            if self.at >= len(self.line):
                if self.showing:
                    self.app.touch()
                else:
                    self._solved()
                return
            if self.showing:
                self.reply_at = time.monotonic() + 0.7
                self.mine_next = True
            else:
                self.hand.reset(pos)
            self.app.touch()

        self.app.slide(parts, {p[1] for p in parts}, arrived)

    def _tried(self, m):
        want = self.line[self.at]
        if m == want or self._mates(m, want):
            self.note = ""
            self.hand.pos = None
            pos = self.pos
            parts = moved_parts(pos, m)

            def arrived():
                pos.push(m)
                self.last = m
                self.at += 1
                if self.at >= len(self.line):
                    self._solved()
                else:
                    self.reply_at = time.monotonic() + 0.4
                self.app.touch()

            self.app.slide(parts, {p[1] for p in parts}, arrived, ms=140)
            return
        if not self.failed_now:
            self.failed_now = True
            self._score(False)
        self.note = "not that. again, or Esc for the answer."
        self.hand.clear()

    def _mates(self, m, want):
        """Another move that mates at once ends the puzzle as well as the written one does."""
        q = self.pos.copy()
        q.push(m)
        return self.at == len(self.line) - 1 and q.in_check() and not q.has_legal()

    def _score(self, ok):
        pr = self._state()
        pr.puzzle_result(self.item, ok)

    def _solved(self):
        if not self.failed_now:
            self._score(True)
            self.solved += 1
        self.tried += 1
        self.note = ""
        pr = self._state()
        pr.save()
        if self.left <= 0:
            self._finish()
            return
        self.reply_at = None
        self.next_puzzle()
        self.app.touch()

    def _give_up(self):
        """Esc on a puzzle: it is shown, move by move; counts as missed."""
        if not self.failed_now:
            self.failed_now = True
            self._score(False)
        self.showing = True
        self.hand.pos = None
        self.note = "the answer. enter goes on."
        self.reply_at = time.monotonic() + 0.2
        self.app.touch()

    def _finish(self):
        self.finished = True
        self.reply_at = None
        self.hand.pos = None
        pr = self._state()
        pr.save()
        if self.done_cb:
            self.done_cb(self)
        self.app.touch()

    def board(self):
        if self.pos is None:
            return B.Position().b, {}, [], False
        marks = board_marks(self.pos, self.last)
        if self.hand.pos is not None:
            for s, ms in self.hand.marks().items():
                marks.setdefault(s, set()).update(ms)
        return self.pos.b, marks, [], self.flipped

    def panel(self, w, h):
        pr = self._state()
        sec = max(0, int(min(self.left, 1e6) + 0.999))
        if self.count_limit is not None:
            out = [heading("STORM", self.title, w, right=f"{min(self.tried + 1, self.count_limit)} of {self.count_limit}"), ""]
        else:
            out = [heading("STORM", self.title, w, right=f"{sec // 60}:{sec % 60:02d}"), ""]
            out.append(meter(self.left / SESSION, min(20, w)))
            out.append("")
        out.append(Row("USAGE", "your rating", f"{pr.puzzle['r']:.0f}"))
        if self.d0 is not None:
            out.append(Row("CHECK", "solved", f"{self.solved} of {self.tried}"))
        out.append("")
        if self.finished:
            d = pr.puzzle["r"] - (self.d0 or pr.puzzle["r"])
            out += [[(f"done: {d:+.0f} today", STRONG)], "", [("enter goes back", MUTED)]]
            return out
        if self.item is not None:
            side = "black" if self.flipped else "white"
            out += [[(f"{side} to move", MUTED)], ""]
            if self.hand.pos is not None or self.note:
                line = [(icon("CHEVRON_RIGHT"), ACCENT_TEXT), "  "]
                if self.hand.promo:
                    line.append(("q r b n", MUTED))
                elif self.hand.bad:
                    line += [(icon("CROSS"), ACCENT_TEXT), " ", self.hand.bad]
                elif self.hand.typed:
                    line.append((self.hand.typed, STRONG))
                out.append(line)
            if self.note:
                out += [[(s, MUTED)] for s in wrap(self.note, w)]
        return out

    def leave(self):
        keep = getattr(self, "on_leave", None)
        if keep and not self.finished:
            keep()

    def key(self, name):
        if self.finished:
            if name in ("enter", "esc"):
                self.app.pop()
            return
        if self.showing:
            if name in ("enter", "esc", "right"):
                self.tried += 1
                self.reply_at = None
                if self.left <= 0:
                    self._finish()
                else:
                    self.next_puzzle()
            return
        hand = self.hand
        if hand.pos is None:
            if name == "esc":
                self.app.pop()
            return
        if name == "esc":
            if hand.holds():
                hand.letgo()
            else:
                self._give_up()
        elif name == "enter":
            m = hand.enter()
            if m is not None:
                self._tried(m)
        elif name == "backspace":
            hand.backspace()
        elif name in ("left", "right", "up", "down"):
            hand.arrow(name, self.flipped, self.last >> 6 & 63 if self.last is not None else self.pos.kings[self.pos.turn])

    def text(self, chars):
        if self.finished or self.showing or self.hand.pos is None:
            return
        m = self.hand.text(chars)
        if m is not None:
            self._tried(m)

    def click(self, sq):
        if self.finished or self.showing or self.hand.pos is None:
            return
        m = self.hand.touch(sq)
        if m is not None:
            self._tried(m)


__all__ = ["Bank", "Session", "glicko2", "SESSION", "REPEAT_DAYS", "os"]
