"""The first screen: today's plan, with the lessons, puzzles, your games and your progress as tabs (§7)."""
import datetime
import os
import random
import re
import time

import board as B
from app import DATA, Screen
from canvas import Canvas
from course import Course
from lesson import Lesson, Library
from play import Game
from progress import Progress, today_ordinal
from puzzles import SESSION, Bank, Session
from review import Review
from term import ACCENT, ACCENT_TEXT, FAINT, MUTED, STRONG
from ui import Row, heading, icon, wrap

TABS = (("today", "KNIGHT"), ("lessons", "BOOK"), ("puzzles", "STORM"), ("games", "SHEET"), ("progress", "USAGE"))


class Home(Screen):
    def __init__(self):
        self.tab = 0
        self.cursor = None
        self.index = 0
        self.top = 0
        self.ready = False
        self.message = ""

    # ── the first frame: everything read, a game left open taken up again ─────────────────────
    def prepare(self):
        app = self.app
        self.pr = app.progress = Progress(app.store)
        app.bank = Bank(os.path.join(DATA, "puzzles.tsv"))
        self.pr.bank_item = self._bank_item
        self.lib = app.library = Library(os.path.join(DATA, "lessons.txt"))
        self.course = app.course = Course(self.lib, app.bank)
        self.ready = True
        saved = app.store.load("current.json", {})
        if saved.get("spec") and saved.get("moves") is not None:
            self._resume(saved)

    def _bank_item(self, pid):
        self.app.bank.load()
        return self.app.bank.by_id.get(pid)

    def _resume(self, saved):
        spec = saved["spec"]
        try:
            self.app.push(Game(_clean_spec(spec), saved, self._game_over))
        except (ValueError, KeyError, TypeError, IndexError):
            self.app.store.delete("current.json")    # (what is in it is no game: gone, not a crash)
            self.message = "the game you left could not be read"

    def tick(self, now):
        if not self.ready:
            self.prepare()
            self.app.touch()
        return None

    # ── the day ───────────────────────────────────────────────────────────────────────────────
    def day_items(self):
        return self.course.items(self.pr.day)

    def next_open(self, items):
        for i, it in enumerate(items):
            if not self.pr.is_done(self.pr.day, it.key):
                return i
        return None

    def rows(self):
        """The rows of the tab shown."""
        if not self.ready:
            return []
        return getattr(self, "_rows_" + TABS[self.tab][0])()

    def _rows_today(self):
        pr = self.pr
        items = self.day_items()
        out = []
        for it in items:
            done = pr.is_done(pr.day, it.key)
            out.append(Row(it.icon, it.label, "done" if done else it.value(pr), act=("item", it), ink=FAINT if done else None))
        if self.next_open(items) is None and pr.day < 365:
            out.append(Row("CHEVRON_RIGHT", f"go on to day {pr.day + 1}", "tomorrow's", act=("next",)))
        return out

    def _rows_lessons(self):
        out = []
        for i, lid in enumerate(self.lib.index):
            m = self.lib.by_id[lid]
            state = self.pr.lessons.get(lid)
            done = state == "done"
            out.append(Row("CHECK" if done else "BOOK", m["title"], "done" if done else f"{i + 1}", act=("lesson", lid), ink=FAINT if done else None))
        return out

    def _rows_puzzles(self):
        pr = self.pr
        out = [Row("STORM", "ten minutes, mixed", act=("puzzles", None))]
        for key, name in self.course.theme_names():
            s = pr.solved_by_theme.get(key)
            v = f"{s[0]}/{s[1]}" if s else ""
            out.append(Row("STORM", name, v, act=("puzzles", key)))
        return out

    def _rows_games(self):
        out = [Row("KNIGHT", "a free game", act=("free",))]
        played = self.pr.played
        for no in sorted(played, key=lambda k: -played[k].get("t", 0))[:400]:
            rec = played[no]
            word = {"win": "won", "loss": "lost", "draw": "drawn"}.get(rec.get("score"), "")
            ac = rec.get("accuracy")
            out.append(Row("SHEET", f"game {no}", f"{word}  {ac:.0f} %" if ac is not None else word, act=("replay", no)))
        return out

    def _rows_progress(self):
        return []

    # ── the board ─────────────────────────────────────────────────────────────────────────────
    def board(self):
        if not self.ready:
            return B.Position().b, {}, [], False
        fen = B.START
        flipped = False
        rows = self.rows()
        if self.index < len(rows):
            act = rows[self.index].act or ()
            if act and act[0] == "item":
                it = act[1]
                if it.kind == "game":
                    spec = self.course.game_spec(it.ref, self.pr)
                    g = B.Game(spec["fen"])
                    for u in spec.get("line") or ():
                        g.play(B.from_uci(u))
                    fen = g.pos.fen()
                    flipped = spec["colour"] == B.BLACK
            elif act and act[0] == "lesson":
                fen = self._first_fen(act[1]) or fen
            elif act and act[0] == "replay":
                text = self.app.store.read_text(f"games/{act[1]}.pgn")
                if text:
                    try:
                        _, g = B.read_pgn(text)
                        fen = g.pos.fen()
                    except ValueError:
                        pass
        try:
            return B.Position(fen).b, {}, [], flipped
        except ValueError:
            return B.Position().b, {}, [], False

    def _first_fen(self, lid):
        try:
            _, pages = self.lib.read(lid)
        except (OSError, ValueError):
            return None
        for p in pages:
            if p.fen:
                return p.fen
        return None

    # ── the panel ─────────────────────────────────────────────────────────────────────────────
    def _tabs(self, w):
        """Three lines: the tabs, the line under the one shown, a row of paper (§7 Tabs)."""
        line, under = [], []
        cur = 0
        for i, (name, ic) in enumerate(TABS):
            if i:
                line.append("   ")
                under.append("   ")
                cur += 3
            if i == self.tab:
                line += [(icon(ic), ACCENT_TEXT), "  ", (name, STRONG)]
                under += ["   ", ("▔" * len(name), ACCENT)]
                cur += 3 + len(name)
            else:
                line.append((icon(ic), MUTED))
                line.append(" ")
                under.append("  ")
                cur += 2
        if cur > w:                      # (narrow: the shown tab's icon and name alone)
            name, ic = TABS[self.tab]
            line = [(icon(ic), ACCENT_TEXT), "  ", (name[:max(0, w - 3)], STRONG)]
            under = ["   ", ("▔" * min(len(name), max(0, w - 3)), ACCENT)]
        return [line, under, ""]

    def panel(self, w, h):
        if not self.ready:
            return []
        rows = self.rows()
        self.index = max(0, min(self.index, max(0, len(rows) - 1)))
        out = self._tabs(w)
        name = TABS[self.tab][0]
        out += getattr(self, "_head_" + name)(w)
        first = len(out)
        foot = self._foot(w, rows)
        room = max(1, h - first - len(foot) - (1 if foot else 0))
        if rows:
            if self.index < self.top:
                self.top = self.index
            if self.index >= self.top + room:
                self.top = self.index - room + 1
            self.top = max(0, min(self.top, max(0, len(rows) - room)))
            shown = rows[self.top:self.top + room]
            out += shown
            self.cursor = first + self.index - self.top
        else:
            self.cursor = None
        if foot:
            out += [""] * max(1, h - len(out) - len(foot))
            out += foot
        return out[:h]

    def _head_today(self, w):
        pr = self.pr
        wk = self.course.week(pr.day)
        out = [heading("KNIGHT", f"day {pr.day} of 365", w, right=f"week {wk.no}"), ""]
        out += [[(s, None)] for s in wrap(wk.title, w)]
        out.append("")
        return out

    def _head_lessons(self, w):
        done = sum(1 for lid in self.lib.index if self.pr.lessons.get(lid) == "done")
        return [heading("BOOK", "lessons", w, right=f"{done} of {len(self.lib.index)}"), ""]

    def _head_puzzles(self, w):
        return [heading("STORM", "puzzles", w, right=f"{self.pr.puzzle['r']:.0f}"), ""]

    def _head_games(self, w):
        n = len(self.pr.played)
        return [heading("SHEET", "your games", w, right=f"{n} of 730"), ""]

    def _head_progress(self, w):
        pr = self.pr
        wins = sum(1 for r in pr.played.values() if r.get("score") == "win")
        draws = sum(1 for r in pr.played.values() if r.get("score") == "draw")
        losses = sum(1 for r in pr.played.values() if r.get("score") == "loss")
        out = [heading("USAGE", "progress", w, right=f"day {pr.day}"), ""]
        out += [Row("KNIGHT", "your level", f"{pr.game['r']:.0f}"),
                Row("STORM", "puzzle rating", f"{pr.puzzle['r']:.0f}"),
                Row("CHECK", "days in a row", pr.streak),
                Row("SHEET", "games", f"{wins} {draws} {losses}"),
                Row("BOOK", "lessons", sum(1 for v in pr.lessons.values() if v == "done")),
                ""]
        m = self.course.milestone(pr.day, pr)
        if m:
            out += [[(s, MUTED)] for s in wrap(m, w)]
        return out

    def _foot(self, w, rows):
        """What the row under the cursor is: its goal, its opponent (the pane of §7)."""
        if self.message:
            return [[(s, MUTED)] for s in wrap(self.message, w)]
        if not rows or self.index >= len(rows):
            return []
        act = rows[self.index].act or ()
        if act and act[0] == "item":
            lines = act[1].details(self.pr)
            out = []
            for ln in lines:
                out += [[(s, MUTED)] for s in wrap(ln, w)]
            return out
        return []

    # ── keys ──────────────────────────────────────────────────────────────────────────────────
    def key(self, name):
        if not self.ready:
            if name in ("esc",):
                self.app.pop()
            return
        self.message = ""
        rows = self.rows()
        if name == "esc":
            self.app.pop()
        elif name == "tab" or name == "right":
            self._tab(1)
        elif name == "shift-tab" or name == "left":
            self._tab(-1)
        elif name == "up":
            self.index = max(0, self.index - 1)
        elif name == "down":
            self.index = min(max(0, len(rows) - 1), self.index + 1)
        elif name == "pageup":
            self.index = max(0, self.index - 10)
        elif name == "pagedown":
            self.index = min(max(0, len(rows) - 1), self.index + 10)
        elif name == "home":
            self.index = 0
        elif name == "end":
            self.index = max(0, len(rows) - 1)
        elif name == "enter" and rows and self.index < len(rows):
            self._act(rows[self.index].act)

    def _tab(self, d):
        self.tab = (self.tab + d) % len(TABS)
        self.index = 0
        self.top = 0
        if TABS[self.tab][0] == "today":
            n = self.next_open(self.day_items())
            self.index = n if n is not None else 0

    def on_show(self):
        n = self.next_open(self.day_items())
        if TABS[self.tab][0] == "today":
            self.index = n if n is not None else 0

    def click_row(self, i):
        lines = self.panel(self.app.layout.pw, self.app.layout.ph)
        if i < len(lines) and hasattr(lines[i], "act") and lines[i].act:
            rows = self.rows()
            if lines[i] in rows:
                self.index = rows.index(lines[i])
            self._act(lines[i].act)

    def hover(self, i):
        lines = self.panel(self.app.layout.pw, self.app.layout.ph)
        if i < len(lines) and hasattr(lines[i], "act") and lines[i].act:
            rows = self.rows()
            if lines[i] in rows:
                self.index = rows.index(lines[i])

    def wheel(self, d):
        rows = self.rows()
        self.index = max(0, min(max(0, len(rows) - 1), self.index + d))

    # ── doing what a row says ─────────────────────────────────────────────────────────────────
    def _act(self, act):
        if not act:
            return
        kind = act[0]
        if kind == "item":
            self._item(act[1])
        elif kind == "next":
            self.pr.day = min(365, self.pr.day + 1)
            self.pr.save()
            self.on_show()
        elif kind == "lesson":
            self.app.push(Lesson(act[1], self.lib, self.pr))
        elif kind == "puzzles":
            name = act[1] or "mixed"
            self.app.push(Session(f"puzzles · {name}", act[1]))
        elif kind == "free":
            self._free_game()
        elif kind == "replay":
            self._replay(act[1])

    def _item(self, it):
        pr, day = self.pr, self.pr.day
        if it.kind == "lesson":
            def done():
                pr.mark_done(day, it.key)
                self.on_show()
            self.app.push(Lesson(it.ref, self.lib, pr, done))
        elif it.kind == "game":
            if pr.is_done(day, it.key):
                self.message = "this game is played"
                return
            spec = self.course.game_spec(it.ref, pr)
            self.app.push(Game(spec, None, self._game_over))
        elif it.kind == "review":
            self._review_game(str(it.ref), day, it.key)
        elif it.kind == "puzzles":
            if pr.is_done(day, it.key):
                self.message = "today's puzzles are solved"
                return
            left = pr.puzzle_left.get(str(day), SESSION)

            def finished(s):
                pr.puzzle_left[str(day)] = 0
                pr.mark_done(day, it.key)
                self.on_show()

            ses = Session(it.label, it.ref, left=left, done=finished)
            ses.on_leave = lambda s=None: self._keep_left(day, ses)
            self.app.push(ses)
        elif it.kind == "exam":
            self._exam(it)
        elif it.kind == "report":
            self.app.push(Report(self.course, pr, self.course.week(day), lambda: (pr.mark_done(day, it.key), self.on_show())))

    def _exam(self, it):
        pr, day = self.pr, self.pr.day
        wk = self.course.week(day)
        ex = wk.exam

        def finished(s):
            if s.solved >= 16:
                pr.mark_done(day, it.key)
                self.message = f"passed: {s.solved} of {s.tried}"
            else:
                self.message = f"{s.solved} of {s.tried}: sixteen to pass. look at what you missed, try again another time."
            self.on_show()

        ses = Session(it.label, None, left=1e9, done=finished, count_limit=20, themes=ex["themes"], fixed_rating=ex["rating"], no_due=True)
        self.app.push(ses)

    def _keep_left(self, day, ses):
        self.pr.puzzle_left[str(day)] = ses.left
        self.pr.save()

    def _game_over(self, game):
        """A game ended: its PGN and record kept, the level moved; the review comes next."""
        pr, course = self.pr, self.course
        spec = game.spec
        o = game.outcome
        no = spec.get("no")
        label = str(no) if no else f"free{pr.free_games + 1}"
        if not no:
            pr.free_games += 1
        date = time.strftime("%Y.%m.%d")
        me = "you"
        opp = f"{spec.get('opponent', 'Stockfish')} ({spec['elo']})"
        tags = {"Event": spec.get("title", "game"), "Date": date, "Round": no or "-",
                "White": me if game.me == B.WHITE else opp, "Black": opp if game.me == B.WHITE else me,
                "TimeControl": "-" if not spec.get("clock") else f"{spec['clock'][0] * 60}+{spec['clock'][1]}",
                "Termination": o["why"]}
        self.app.store.write_text(f"games/{label}.pgn", game.g.pgn(tags))
        score = "draw" if o["draw"] else "win" if o["won"] else "loss"
        counted = len(game.g.moves) >= 2
        if counted:
            pr.game_result(0.5 if o["draw"] else 1.0 if o["won"] else 0.0, spec["elo"])
        pr.played[label] = {"score": score, "elo": spec["elo"], "t": time.time(), "why": o["why"], "goal": spec.get("goal", ""),
                            "check": spec.get("check"), "me": game.me, "times": game.times, "hints": game.hints_used, "accuracy": None}
        pr.active()
        if no:
            pr.mark_done(pr.day, f"game{no}")
        else:
            pr.save()

    def _review_game(self, label, day=None, key=None):
        pr = self.pr
        rec = pr.played.get(label)
        text = self.app.store.read_text(f"games/{label}.pgn")
        if not rec or not text:
            self.message = "play this game first"
            return
        try:
            tags, g = B.read_pgn(text)
        except ValueError:
            self.message = "this game's record cannot be read"
            return

        def finished(summary):
            rec["accuracy"] = summary.get("accuracy")
            rec["classes"] = summary.get("classes")
            rec["takeaway"] = summary.get("takeaway", "")
            if summary.get("takeaway"):
                pr.takeaways.append([label, summary["takeaway"]])
            for i, m in enumerate(summary.get("moments", ())):
                if m.get("unique") and m.get("best"):
                    pr.own_puzzle(label, i, m["fen"], m["best"], int(pr.puzzle["r"]))
            if day is not None:
                pr.mark_done(day, key)
            else:
                pr.save()
            self.on_show()

        self.app.push(Review(label, tags, g, rec.get("me", 0), f"review of game {label}", spec=rec, done=finished, saved=None))

    def _replay(self, label):
        self._review_game(label)

    def _free_game(self):
        self.app.push(FreeSetup(self))


class FreeSetup(Screen):
    """A free game: the level and the colour, nothing else; not counted in the course."""

    LEVELS = (250, 400, 600, 800, 1000, 1200, 1320, 1400, 1500, 1600, 1700, 1800, 1900, 2000, 2200, 2500, 3190)

    def __init__(self, home):
        self.home = home
        lv = home.pr.game["r"]
        self.level = min(range(len(self.LEVELS)), key=lambda i: abs(self.LEVELS[i] - lv))
        self.colour = 0
        self.cursor = None
        self.i = 0

    def board(self):
        return B.Position().b, {}, [], self.colour == 1

    def panel(self, w, h):
        rows = [Row("USER", "colour", "white" if self.colour == 0 else "black" if self.colour == 1 else "either", tag="colour"),
                Row("ONI", "level", self.LEVELS[self.level], tag="level"),
                Row("CHEVRON_RIGHT", "begin", tag="begin")]
        self._rows = rows
        out = [heading("KNIGHT", "a free game", w), ""] + rows
        self.cursor = 2 + self.i
        return out

    def key(self, name):
        if name == "esc":
            self.app.pop()
        elif name == "up":
            self.i = max(0, self.i - 1)
        elif name == "down":
            self.i = min(2, self.i + 1)
        elif name in ("left", "right"):
            d = 1 if name == "right" else -1
            if self.i == 0:
                self.colour = (self.colour + d) % 3
            elif self.i == 1:
                self.level = max(0, min(len(self.LEVELS) - 1, self.level + d))
        elif name == "enter":
            if self.i == 0:
                self.colour = (self.colour + 1) % 3
            elif self.i == 1:
                self.level = (self.level + 1) % len(self.LEVELS)
            else:
                self._begin()

    def click_row(self, i):
        self.i = max(0, min(2, i - 2))
        self.key("enter")

    def _begin(self):
        c = self.colour if self.colour < 2 else random.randrange(2)
        spec = {"title": "a free game", "goal": "", "fen": B.START, "line": [], "colour": c, "elo": self.LEVELS[self.level], "clock": (10, 0),
                "hints": 3, "threats": False, "opponent": "Stockfish", "no": None}
        self.app.replace(Game(spec, None, self.home._game_over))


class Report(Screen):
    """The week's report: the numbers, what you wrote down, whether you are on the way."""

    def __init__(self, course, pr, week, done):
        self.course, self.pr, self.week, self.done_cb = course, pr, week, done
        self.cursor = None

    def board(self):
        return B.Position().b, {}, [], False

    def panel(self, w, h):
        pr = self.pr
        first = (self.week.no - 1) * 14 + 1
        recs = [pr.played.get(str(n)) for n in range(first, first + 14)]
        recs = [r for r in recs if r]
        wins = sum(1 for r in recs if r.get("score") == "win")
        draws = sum(1 for r in recs if r.get("score") == "draw")
        losses = sum(1 for r in recs if r.get("score") == "loss")
        acc = [r["accuracy"] for r in recs if r.get("accuracy") is not None]
        out = [heading("USAGE", f"week {self.week.no}", w), ""]
        out += [Row("SHEET", "games", f"{wins} {draws} {losses}"),
                Row("USAGE", "accuracy", f"{sum(acc) / len(acc):.0f} %" if acc else ""),
                Row("KNIGHT", "your level", f"{pr.game['r']:.0f}"),
                Row("STORM", "puzzle rating", f"{pr.puzzle['r']:.0f}"), ""]
        m = self.course.milestone(pr.day, pr)
        if m:
            out += [[(s, None)] for s in wrap(m, w)] + [""]
        notes = [t for lb, t in pr.takeaways if lb.isdigit() and first <= int(lb) < first + 14]
        if notes:
            out.append(heading("NOTE", "what you wrote down", w))
            out.append("")
            for t in notes[-max(0, h - len(out)):]:
                for s in wrap(t, w)[:2]:
                    out.append([(s, MUTED)])
        return out[:h]

    def key(self, name):
        if name in ("enter", "esc"):
            self.app.pop()
            if name == "enter":
                self.done_cb()


def _clean_spec(spec):
    """A spec read back from a file: checked for what a Game needs."""
    if not isinstance(spec, dict) or not isinstance(spec.get("fen"), str) or spec.get("colour") not in (0, 1) or not isinstance(spec.get("elo"), int):
        raise ValueError("no game")
    clock = spec.get("clock")
    if clock is not None and not (isinstance(clock, (list, tuple)) and len(clock) == 2):
        spec["clock"] = None
    spec.setdefault("title", "a game")
    return spec


__all__ = ["Home", "Canvas", "datetime", "re", "today_ordinal"]
