"""After a game: every position looked at by the engine at full strength, your moves scored as
chess.com's Game Review scores them, the three moments that mattered replayed — you find the move first,
then you are shown it and why — and one thing to remember, written by you.
"""
import math

import board as B
from app import Screen
from engine import analysis_request
from play import MoveInput, board_marks, moved_parts
from term import ACCENT_TEXT, FAINT, MUTED, STRONG
from ui import Row, heading, icon, meter, wrap

# Expected-points loss → a word, the steps of chess.com's own classification
CLASSES = ((0.20, "blunder"), (0.10, "mistake"), (0.05, "inaccuracy"), (0.02, "good"), (0.0, "excellent"))
NODES = 150000


def classify(loss):
    for limit, word in CLASSES:
        if loss > limit:
            return word
    return "best"


def accuracy(win_drops):
    """Lichess's accuracy from the win-percentage drops of your moves (lichess.org/page/accuracy)."""
    if not win_drops:
        return 100.0
    vals = [min(100.0, max(0.0, 103.1668 * math.exp(-0.04354 * d) - 3.1669)) for d in win_drops]
    return sum(vals) / len(vals)


class Analysis:
    """Walks a game's positions one at a time through the engine; results: one Entry a position."""

    def __init__(self, app, start, moves, done=None):
        self.app, self.start, self.moves = app, start, [B.uci(m) for m in moves]
        self.entries = [None] * (len(moves) + 1)
        self.done_cb = done
        self.i = 0
        self.cancelled = False
        self.final = None

    def fraction(self):
        return self.i / max(1, len(self.entries))

    def go(self):
        while self.i < len(self.entries):
            pos = B.Position(self.start)
            for u in self.moves[:self.i]:
                pos.push(B.from_uci(u))
            if pos.has_legal():
                self.app.engine.ask(analysis_request(self.start, self.moves[:self.i], self._got, nodes=NODES, multipv=2, tag=self.i))
                return
            # (no moves: mate or stalemate, nothing to ask)
            self.entries[self.i] = {"ep": 0.0 if pos.in_check() else 0.5, "cp": -30000 if pos.in_check() else 0, "mate": 0 if pos.in_check() else None, "best": None, "pv": [], "second": None}
            self.i += 1
        if self.done_cb and not self.cancelled:
            cb, self.done_cb = self.done_cb, None
            cb()

    def _got(self, s):
        if self.cancelled:
            return
        ranked = s.ranked()
        if ranked:
            top = ranked[0]
            self.entries[s.tag] = {"ep": top.expected(), "cp": top.score(), "mate": top.mate, "best": s.best, "pv": top.pv[:10],
                                   "second": ranked[1].expected() if len(ranked) > 1 else None}
        else:
            self.entries[s.tag] = {"ep": 0.5, "cp": 0, "mate": None, "best": s.best, "pv": [], "second": None}
        self.i = s.tag + 1
        self.go()
        self.app.touch()


def scored_moves(entries, moves, me, start_fen, skip=0):
    """Each of `me`'s moves (past the `skip` already on the board): ply, loss in expected points, its
    class, the win% drop."""
    pos = B.Position(start_fen)
    out = []
    for i, m in enumerate(moves):
        side = pos.turn
        if side == me and i >= skip and entries[i] and entries[i + 1]:
            before = entries[i]["ep"]
            after = 1.0 - entries[i + 1]["ep"]
            loss = max(0.0, before - after)
            best = entries[i]["best"]
            free = False
            if best and loss > 0.05 and best != B.uci(m):
                b = B.from_uci(best)
                target = pos.b[b >> 6 & 63]
                free = bool(target) and pos.see(b >> 6 & 63, side) >= B.VALUE[target & 7]
            out.append({"ply": i, "loss": loss, "class": classify(loss), "drop": loss * 100, "before": before, "after": after, "best": best, "uci": B.uci(m), "free": free})
        pos.push(m)
    return out


def _material(pos, side):
    return sum(B.VALUE[p & 7] for p in pos.b if p and p >> 3 & 1 == side and p & 7 != B.KING)


def _line_after(fen, line):
    """SANs and the position at the end of a line of UCI moves (stops at an illegal one)."""
    pos = B.Position(fen)
    sans = []
    for u in line:
        try:
            m = B.from_uci(u)
        except ValueError:
            break
        if m not in pos.legal():
            break
        sans.append(pos.san(m))
        pos.push(m)
    return sans, pos


def _fork_targets(pos, sq, side):
    """What a man on sq attacks that is worth at least his own value, or stands unguarded."""
    p = pos.b[sq]
    q = pos.copy()
    q.turn = side
    hits = []
    v = B.VALUE[p & 7]
    for m in q.pseudo():
        if m & 63 == sq and q.b[m >> 6 & 63] and not m >> 12:
            t = q.b[m >> 6 & 63]
            if B.VALUE[t & 7] > v or not q.attackers(m >> 6 & 63, 1 - side):
                hits.append(m >> 6 & 63)
    return hits


def explain(entries, ply, fen_before, played_uci, me):
    """Plain words for a moment: what your move allowed, what was there instead."""
    e0, e1 = entries[ply], entries[ply + 1]
    best = e0["best"]
    out = []
    pos = B.Position(fen_before)
    mine = B.from_uci(played_uci)
    pos2 = pos.copy()
    pos2.push(mine)
    # what your move allowed
    if e1 and e1.get("pv"):
        sans, end = _line_after(pos2.fen(), e1["pv"][:5])
        if e1.get("mate") is not None and e1["mate"] > 0:
            out.append(f"it allows mate in {e1['mate']}: {' '.join(sans[:e1['mate'] * 2 - 1])}.")
        else:
            lost = _material(pos2, me) - _material(end, me) - (_material(pos2, 1 - me) - _material(end, 1 - me))
            if lost >= 1:
                out.append(f"it loses {_worth(lost)}: {' '.join(sans[:3])}.")
            elif sans:
                out.append(f"the answer is {sans[0]}.")
    # what was there
    if best and best != played_uci:
        m = B.from_uci(best)
        san = pos.san(m)
        if e0.get("mate") is not None and e0["mate"] > 0:
            out.append(f"{san} was mate in {e0['mate']}.")
        else:
            target = pos.b[m >> 6 & 63]
            q = pos.copy()
            q.push(m)
            fork = _fork_targets(q, m >> 6 & 63, me) if not m >> 12 else []
            if target and not pos.attackers(m >> 6 & 63, 1 - me):
                out.append(f"{san} takes a free {B.NAME[target & 7]}.")
            elif target and pos.see(m >> 6 & 63, me) > 0:
                out.append(f"{san} wins material on {B.sq_name(m >> 6 & 63)}.")
            elif len(fork) >= 2:
                names = " and ".join(B.NAME[q.b[s] & 7] for s in fork[:2])
                out.append(f"{san} forks the {names}.")
            elif q.in_check():
                out.append(f"{san} is a check that keeps the initiative.")
            else:
                out.append(f"{san} was the move.")
    return " ".join(out)


def _worth(n):
    return {1: "a pawn", 2: "two pawns", 3: "a piece", 4: "a piece and a pawn", 5: "a rook", 6: "a rook and a pawn", 9: "the queen"}.get(n, f"{n} points of material")


def goal_met(check, g, me, scored, times, outcome):
    """Was the game's goal reached (syllabus.py's `check`)? None when it asks nothing measurable."""
    if not check:
        return None
    word, _, arg = check.partition(":")
    n = int(arg) if arg.isdigit() else 0
    if word == "win":
        return outcome == "win"
    if word == "draw":
        return outcome == "draw"
    if word == "draw+":
        return outcome != "loss"
    if word == "finish":
        return g.why != "you resigned"
    if word == "safe":
        return not any(s["class"] == "blunder" for s in scored)
    if word == "free":
        return not any(s.get("free") for s in scored)
    if word == "mate":
        p = B.Position(g.start)
        mine = sum(1 for i in range(len(g.moves)) if (p.turn == me) == (i % 2 == 0))
        return outcome == "win" and g.why == "checkmate" and mine <= n
    if word in ("castle", "develop"):
        return _opening_goal(word, g, me, n)
    if word == "think":
        spent = times[5:] or times
        return bool(spent) and sum(spent) / len(spent) >= n
    if word == "clock":
        return g.why != "on time"
    return None


def _opening_goal(word, g, me, n):
    """Castled by your move n, or castled and all four minor men gone from home by it."""
    pos = B.Position(g.start)
    home = {B.WHITE: (1, 2, 5, 6), B.BLACK: (57, 58, 61, 62)}[me]
    kind_home = {s: (B.KNIGHT if s % 8 in (1, 6) else B.BISHOP) | me << 3 for s in home}
    castled = False
    mine = 0
    for m in g.moves:
        side = pos.turn
        if side == me:
            mine += 1
            if pos.b[m & 63] & 7 == B.KING and abs((m & 63) - (m >> 6 & 63)) == 2:
                castled = True
        pos.push(m)
        if side == me and mine == n:
            break
    if word == "castle":
        return castled
    return castled and not any(pos.b[s] == k for s, k in kind_home.items())


def pick_moments(scored, n=3):
    """The moves that cost the most, in the order they were played; nothing under an inaccuracy."""
    worst = sorted((s for s in scored if s["loss"] > 0.05), key=lambda s: -s["loss"])[:n]
    return sorted(worst, key=lambda s: s["ply"])


class Review(Screen):
    """done(summary): called when he leaves it, with what the game left: accuracy, classes, takeaway."""

    def __init__(self, game_no, tags, g, me, title, spec=None, done=None, saved=None):
        self.no, self.tags, self.g, self.me, self.title = game_no, tags, g, me, title
        self.spec = spec or {}
        self.done_cb = done
        self.phase = "reading"    # reading → moment → summary
        self.an = None
        self.scored = []
        self.moments = []
        self.mi = 0
        self.step = "find"        # find → shown
        self.tries = 0
        self.hand = MoveInput()
        self.line = []            # the better line, stepped through with ← →
        self.line_at = 0
        self.view_pos = None
        self.note = ""
        self.take = ""
        self.summary = saved
        self.flipped = me == B.BLACK
        self.cursor = None
        self.judged = ""
        if saved:
            self.phase = "summary"

    def tick(self, now):
        if self.an is None and self.phase == "reading":
            self.an = Analysis(self.app, self.g.start, self.g.moves, self._read)
            self.an.go()
            self.app.touch()
        return None

    def _read(self):
        self.scored = scored_moves(self.an.entries, self.g.moves, self.me, self.g.start, self.spec.get("skip", 0))
        self.moments = pick_moments(self.scored)
        self.app.engine.stop_process()
        self.mi = 0
        if self.moments:
            # (first your own judgement, then the engine's: what you have to recall, you keep)
            self.phase = "judge"
            self.judge_plies = [x["ply"] for x in self.scored]
            self.judge_i = len(self.judge_plies) - 1
        else:
            self._to_summary()
        self.app.touch()

    def _judged(self, ply):
        chosen = next((x for x in self.scored if x["ply"] == ply), None)
        saw = chosen is not None and chosen in self.moments
        worst = max(self.moments, key=lambda m: m["loss"])
        if chosen is worst:
            self.judged = "you saw it: that was the worst."
        elif saw:
            self.judged = "you saw that one. there is worse."
        else:
            self.judged = "that one held. the engine would take back others."
        self.phase = "moment"
        self._enter_moment()

    def _moment(self):
        return self.moments[self.mi]

    def _enter_moment(self):
        m = self._moment()
        self.step = "find"
        self.tries = 0
        self.note = ""
        self.pos = self.g.replay(m["ply"])
        self.hand.reset(self.pos)
        self.line = []
        self.line_at = 0
        self.flipped = self.me == B.BLACK

    def _shown(self, kind):
        """The answer on the board: the better move's line, stepped with the arrows."""
        m = self._moment()
        self.step = "shown"
        self.result_word = kind
        e0 = self.an.entries[m["ply"]]
        self.line = e0["pv"][:6]
        self.line_at = 0
        self.expl = explain(self.an.entries, m["ply"], self.pos.fen(), m["uci"], self.me)
        self.hand.clear()

    def _to_summary(self):
        self.phase = "summary"
        s = self.scored
        counts = {}
        for x in s:
            counts[x["class"]] = counts.get(x["class"], 0) + 1
        rec = self.spec
        met = goal_met(rec.get("check"), self.g, self.me, s, rec.get("times") or [], rec.get("score"))
        goal = {"text": rec.get("goal", ""), "ok": bool(met)} if met is not None else None
        self.summary = {"accuracy": round(accuracy([x["drop"] for x in s]), 1), "classes": counts, "goal": goal, "moments": [
            {"ply": m["ply"], "fen": self.g.replay(m["ply"]).fen(), "best": m["best"], "played": m["uci"], "loss": round(m["loss"], 3),
             "unique": self._unique(m)} for m in self.moments]}
        self.take = ""

    def _unique(self, m):
        e = self.an.entries[m["ply"]]
        return e["second"] is None or e["ep"] - e["second"] >= 0.10

    # ── the board ───────────────────────────────────────────────────────────────────────────
    def board(self):
        if self.phase == "judge":
            ply = self.judge_plies[self.judge_i]
            pos = self.g.replay(ply + 1)
            return pos.b, board_marks(pos, self.g.moves[ply]), [], self.flipped
        if self.phase == "moment":
            if self.step == "shown":
                pos = self.pos.copy()
                last = None
                for u in self.line[:self.line_at]:
                    last = B.from_uci(u)
                    pos.push(last)
                marks = board_marks(pos, last)
                arrows = []
                if self.line_at == 0:
                    m = self._moment()
                    arrows.append((B.from_uci(m["uci"]) & 63, B.from_uci(m["uci"]) >> 6 & 63, "accent"))
                    if m["best"]:
                        arrows.append((B.from_uci(m["best"]) & 63, B.from_uci(m["best"]) >> 6 & 63, "asagi"))
                elif self.line_at < len(self.line):
                    nxt = B.from_uci(self.line[self.line_at])
                    arrows.append((nxt & 63, nxt >> 6 & 63, "asagi"))
                return pos.b, marks, arrows, self.flipped
            marks = board_marks(self.pos, self.g.moves[self._moment()["ply"] - 1] if self._moment()["ply"] else None)
            for s, ms in self.hand.marks().items():
                marks.setdefault(s, set()).update(ms)
            return self.pos.b, marks, [], self.flipped
        pos = self.g.pos
        return pos.b, board_marks(pos, self.g.moves[-1] if self.g.moves else None), [], self.flipped

    # ── the panel ───────────────────────────────────────────────────────────────────────────
    def panel(self, w, h):
        out = [heading("SEARCH", self.title, w), ""]
        if self.phase == "reading":
            out += [[("reading the game", MUTED)], ""]
            frac = self.an.fraction() if self.an else 0.0
            out.append(meter(frac, min(20, w)))
            return out
        if self.phase == "judge":
            ply = self.judge_plies[self.judge_i]
            pos = self.g.replay(ply)
            san = pos.san(self.g.moves[ply])
            no = f"{pos.full}." if pos.turn == B.WHITE else f"{pos.full}..."
            out += [[(s, None)] for s in wrap("before the engine speaks: which of your moves would you take back?", w)]
            out += ["", [(no + " ", MUTED), (san, STRONG)], ""]
            out += [[(s, MUTED)] for s in wrap("left and right walk the game, enter chooses, esc skips.", w)]
            return out
        if self.phase == "moment":
            return out + self._moment_lines(w, h - 2)
        return out + self._summary_lines(w, h - 2)

    def _moment_lines(self, w, h):
        m = self._moment()
        pos = self.pos
        no = pos.full
        dots = "." if pos.turn == B.WHITE else "..."
        played = pos.san(B.from_uci(m["uci"]))
        lines = [[(f"moment {self.mi + 1} of {len(self.moments)}", MUTED)], ""]
        if self.judged and self.mi == 0:
            lines += [[(s, MUTED)] for s in wrap(self.judged, w)] + [""]
        lines += [[f"{no}{dots} you played ", (played, STRONG), f": a {m['class']}."]] if len(f"{no}{dots} you played {played}: a {m['class']}.") <= w else [[(s, None)] for s in wrap(f"{no}{dots} you played {played}: a {m['class']}.", w)]
        lines.append("")
        if self.step == "find":
            lines += [[(s, None)] for s in wrap("find a better move.", w)]
            lines.append("")
            lines.append(self._hand_line())
            if self.note:
                lines += [[(s, MUTED)] for s in wrap(self.note, w)]
            return lines
        word = {"found": "you found it.", "close": "close enough: that holds.", "gave": "the move:"}.get(self.result_word, "")
        best = pos.san(B.from_uci(m["best"])) if m["best"] else ""
        if self.result_word == "found":
            lines.append([(icon("CHECK"), ACCENT_TEXT), "  ", word])
        else:
            lines.append([word + " ", (best, STRONG)] if self.result_word != "close" else [word])
        lines.append("")
        lines += [[(s, None)] for s in wrap(self.expl, w)]
        lines.append("")
        sans, _ = _line_after(pos.fen(), self.line)
        shown = []
        for i, s in enumerate(sans):
            shown.append((s, STRONG if i == self.line_at - 1 else MUTED))
        text_line, cur = [], 0
        for s, ink in shown:
            if cur + len(s) + 1 > w:
                lines.append(text_line)
                text_line, cur = [], 0
            text_line += [(s, ink), " "]
            cur += len(s) + 1
        if text_line:
            lines.append(text_line)
        return lines

    def _hand_line(self):
        hand = self.hand
        line = [(icon("CHEVRON_RIGHT"), ACCENT_TEXT), "  "]
        if hand.promo:
            line += [("q r b n", MUTED)]
        elif hand.bad:
            line += [(icon("CROSS"), ACCENT_TEXT), " ", hand.bad]
        elif hand.typed:
            line += [(hand.typed, STRONG)]
        return line

    def _summary_lines(self, w, h):
        s = self.summary
        c = s.get("classes", {})
        lines = [Row("USAGE", "accuracy", f"{s.get('accuracy', 0):.0f} %"),
                 Row("CROSS", "blunders", c.get("blunder", 0)),
                 Row("CROSS", "mistakes", c.get("mistake", 0)),
                 Row("CROSS", "inaccuracies", c.get("inaccuracy", 0))]
        goal = s.get("goal")
        if goal:
            lines += ["", [(icon("CHECK" if goal["ok"] else "CROSS"), ACCENT_TEXT), "  ", *[(t, None) for t in wrap(goal["text"], w - 3)[:1]]]]
        lines += ["", [("one thing to remember:", MUTED)], ""]
        lines += [[(icon("CHEVRON_RIGHT"), ACCENT_TEXT), "  ", (self.take[-(w - 3):], STRONG)]]
        return lines

    # ── keys ────────────────────────────────────────────────────────────────────────────────
    def key(self, name):
        if self.phase == "reading":
            if name == "esc":
                self._leave()
            return
        if self.phase == "judge":
            if name in ("left", "up"):
                self.judge_i = max(0, self.judge_i - 1)
            elif name in ("right", "down"):
                self.judge_i = min(len(self.judge_plies) - 1, self.judge_i + 1)
            elif name == "enter":
                self._judged(self.judge_plies[self.judge_i])
            elif name == "esc":
                self.phase = "moment"
                self._enter_moment()
            return
        if self.phase == "moment":
            self._moment_key(name)
            return
        if name == "enter":
            self._leave()
        elif name == "esc":
            self.take = ""
            self._leave()
        elif name == "backspace":
            self.take = self.take[:-1]

    def _moment_key(self, name):
        if self.step == "find":
            if name == "esc":
                if self.hand.holds():
                    self.hand.letgo()
                else:
                    self._shown("gave")
            elif name == "enter":
                m = self.hand.enter()
                if m is not None:
                    self._tried(m)
            elif name == "backspace":
                self.hand.backspace()
            elif name in ("left", "right", "up", "down"):
                self.hand.arrow(name, self.flipped, self.pos.kings[self.me])
            return
        if name in ("right", "down") and self.line_at < len(self.line):
            self.line_at += 1
        elif name in ("left", "up") and self.line_at > 0:
            self.line_at -= 1
        elif name in ("enter", "esc"):
            self.mi += 1
            if self.mi < len(self.moments):
                self._enter_moment()
            else:
                self._to_summary()

    def text(self, chars):
        if self.phase == "summary":
            if len(self.take) < 200:
                self.take += "".join(c for c in chars if c.isprintable())
            return
        if self.phase == "moment" and self.step == "find":
            m = self.hand.text(chars)
            if m is not None:
                self._tried(m)

    def paste(self, text):
        if self.phase == "summary":
            self.text(" ".join(text.split()))

    def click(self, sq):
        if self.phase == "moment" and self.step == "find":
            m = self.hand.touch(sq)
            if m is not None:
                self._tried(m)

    def _tried(self, m):
        mo = self._moment()
        u = B.uci(m)
        self.tries += 1
        if u == mo["best"]:
            self._shown("found")
        elif u == mo["uci"]:
            self.note = "that is what you played. look again."
            self.hand.clear()
        elif self.tries >= 2:
            self._shown("gave")
        else:
            self.note = "not that one. look at what your opponent threatens, then at every check and capture."
            self.hand.clear()

    def _leave(self):
        if self.summary is None:
            self.summary = {"accuracy": None, "classes": {}, "moments": []}
        self.summary["takeaway"] = " ".join(self.take.split())
        cb, self.done_cb = self.done_cb, None
        self.app.pop()
        if cb:
            cb(self.summary)

    def leave(self):
        if self.an:
            self.an.cancelled = True
        self.app.engine.cancel_all()
        self.app.engine.stop_process()


__all__ = ["Review", "Analysis", "accuracy", "classify", "moved_parts", "FAINT"]
