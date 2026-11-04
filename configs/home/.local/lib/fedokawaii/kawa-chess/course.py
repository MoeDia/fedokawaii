"""The year: 52 weeks, 365 days, 730 games. A day is what lies open, in order: its lesson (if it has one),
a game, its review, ten minutes of puzzles, a game, its review; the week's last day adds a report.
The weeks themselves are in syllabus.py; docs/learn/chess/curriculum.md is written from them.
"""
import datetime
import random

import board as B
import syllabus as SY

GAMES_A_DAY = 2


class Item:
    __slots__ = ("key", "kind", "ref", "label", "icon", "course")

    def __init__(self, course, key, kind, ref, label, ic):
        self.course, self.key, self.kind, self.ref, self.label, self.icon = course, key, kind, ref, label, ic

    def value(self, pr):
        if self.kind == "puzzles":
            left = pr.puzzle_left.get(str(pr.day))
            if left is not None:
                return f"{int(left + 0.999) // 60}:{int(left + 0.999) % 60:02d} left"
            return "10 min"
        if self.kind == "lesson":
            m = self.course.lib.by_id.get(self.ref)
            return f"{m['minutes']} min" if m and m.get("minutes") else ""
        return ""

    def details(self, pr, face=False):
        """Words for the pane under the list; face: who you meet is drawn there already."""
        if self.kind == "game":
            spec = self.course.game_spec(self.ref, pr)
            side = "white" if spec["colour"] == B.WHITE else "black"
            tc = f"{spec['clock'][0]}+{spec['clock'][1]}" if spec.get("clock") else "no clock"
            against = "" if face else f" against {spec['opponent']}, level {spec['elo']}"
            return [spec["goal"], f"you play {side}{against}, {tc}."]
        if self.kind == "review":
            return ["three moments: you find the move, then you see why."]
        if self.kind == "vision":
            return ["the squares named one after another, the board without its letters: find as many as you can."]
        if self.kind == "puzzles":
            return ["what you missed comes back first"]
        if self.kind == "exam":
            return ["twenty puzzles from these four weeks: sixteen to pass, as the Steps Method's 80 %. again another day if not."]
        if self.kind == "report":
            return ["what this week did, and where you stand"]
        return []


class Week:
    __slots__ = ("no", "title", "aim", "band", "lessons", "themes", "games", "milestone", "exam")

    def __init__(self, no, data):
        self.no = no
        self.title = data["title"]
        self.aim = data.get("aim", "")
        self.band = data["band"]
        self.lessons = data.get("lessons", [])
        self.themes = data.get("themes", [None])
        self.games = data["games"]
        self.milestone = data.get("milestone")
        self.exam = data.get("exam")


class Course:
    def __init__(self, library, bank=None):
        self.lib = library
        self.bank_ref = bank
        self.bank_starts = {}
        self.weeks = [Week(i + 1, d) for i, d in enumerate(SY.WEEKS)]

    def week(self, day):
        return self.weeks[min(len(self.weeks) - 1, (max(1, day) - 1) // 7)]

    def items(self, day):
        day = max(1, min(365, day))
        wk = self.week(day)
        dow = (day - 1) % 7 if day < 365 else 7
        out = []
        lesson = _lesson_of_day(wk, dow)
        if lesson and lesson in self.lib.by_id:
            out.append(Item(self, f"lesson-{lesson}", "lesson", lesson, self.lib.by_id[lesson]["title"], "BOOK"))
        no = (day - 1) * GAMES_A_DAY + 1
        theme = wk.themes[dow % len(wk.themes)] if wk.themes else None
        if wk.exam and dow == 6:
            out.append(Item(self, f"exam{wk.no}", "exam", wk.no, "the exam of these four weeks", "CHECK"))
        out.append(Item(self, f"game{no}", "game", no, f"game {no}", "KNIGHT"))
        out.append(Item(self, f"review{no}", "review", no, f"review of game {no}", "SEARCH"))
        word = self.theme_word(theme) or "mixed"
        if theme == "@vision":     # (the first days: not one piece is known yet, the squares are)
            out.append(Item(self, f"vision{day}", "vision", None, "the squares: two minutes", "SEARCH"))
        else:
            out.append(Item(self, f"puzzles{day}", "puzzles", theme, f"puzzles: {word}", "STORM"))
        out.append(Item(self, f"game{no + 1}", "game", no + 1, f"game {no + 1}", "KNIGHT"))
        out.append(Item(self, f"review{no + 1}", "review", no + 1, f"review of game {no + 1}", "SEARCH"))
        if dow == 6:
            out.append(Item(self, f"report{wk.no}", "report", wk.no, f"the report of week {wk.no}", "USAGE"))
        return out

    def game_spec(self, no, pr):
        """Game number no as it will be played, today: the level follows your own, within the week's;
        the colours take turns, day by day. A light game comes from a set position, a line, or the bank."""
        day = (no + 1) // 2
        wk = self.week(day)
        g = wk.games[(no - 1) % 14]
        lo, hi = wk.band
        elo = g.get("elo", int(max(lo, min(hi, pr.game["r"] + g.get("off", 50)))))
        colour = g.get("you")
        colour = (day - 1 + (no - 1) % 2) % 2 if colour is None else colour
        fen, line = SY.start_of(g, colour)
        goal = g["goal"]
        if "pos" in g:
            colour = SY.POS[g["pos"]][1]
        if "bank" in g:
            # (once for a game: the row under the cursor asks at every frame, and the search goes through the whole bank)
            if no not in self.bank_starts:
                self.bank_starts[no] = self._bank_start(g["bank"], no, pr)
            fen, colour, line = self.bank_starts[no]
        light = g.get("light")
        clock = g.get("clock", (5, 5) if light and wk.no > 4 else wk_clock(wk.no))
        return {"title": f"game {no} of 730", "goal": goal, "fen": fen, "line": line, "colour": colour, "elo": elo,
                "clock": clock, "hints": g.get("hints", wk_hints(wk.no)), "threats": g.get("threats", wk.no <= 8),
                "opponent": SY.opponent(elo), "no": no, "check": g.get("check"), "gate": bool(g.get("gate")), "card": wk.no <= 12}

    def _bank_start(self, theme, no, pr):
        """A position with this theme's tactic in it: the same one for the same game, near your level."""
        bank = self.bank()
        bank.load()
        rng = random.Random(no)
        want = int(pr.puzzle["r"]) - 100
        tag = f" {theme} "
        pool = [it for it in bank.items if tag in f" {it[4]} " and abs(it[3] - want) <= 200] or \
               [it for it in bank.items if tag in f" {it[4]} "] or bank.items
        if not pool:
            return B.START, 0, []
        item = rng.choice(pool)
        # (a puzzle's first move is the opponent's: it is on the board when the game begins, and the tactic is yours to find)
        try:
            pos = B.Position(item[1])
            first = B.from_uci(item[2].split()[0])
            if first not in pos.legal():
                raise ValueError("first move illegal")
        except (ValueError, IndexError):
            return B.START, 0, []
        return pos.fen(), 1 - pos.turn, [B.uci(first)]

    def bank(self):
        return self.bank_ref

    def theme_names(self):
        return SY.THEME_NAMES

    def theme_word(self, key):
        return dict(SY.THEME_NAMES).get(key) if key else None

    def milestone(self, day, pr):
        """The next milestone, plainly: where you should be by then, where you are."""
        for wk in self.weeks[self.week(day).no - 1:]:
            if wk.milestone:
                m = wk.milestone
                return (f"by week {wk.no}: level {m['level']}, puzzles {m['puzzle']}. "
                        f"now {pr.game['r']:.0f} and {pr.puzzle['r']:.0f}.")
        return ""

    def forecast(self, pr):
        """Where the line of your own last month points: an honest date, or nothing while there is too little."""
        h = [x for x in pr.history if isinstance(x, list) and len(x) == 3][-28:]
        if len(h) < 14:
            return ""
        n = len(h)
        xs = [x[0] for x in h]
        ys = [x[1] for x in h]
        mx, my = sum(xs) / n, sum(ys) / n
        den = sum((x - mx) ** 2 for x in xs)
        slope = sum((x - mx) * (y - my) for x, y in zip(xs, ys, strict=True)) / den if den else 0
        if slope <= 0.05:
            return "your level has not risen this month. the plan holds; look at your reviews."
        days = (1800 - ys[-1]) / slope
        if days <= 0:
            return "you are past the line."
        when = datetime.date.fromordinal(int(xs[-1] + days))
        return f"at this month's pace: 1800 around {when.strftime('%b %Y').lower()}."


def wk_clock(no):
    """No clock while the rules are learnt; then a long one to think on (Heisman wants 30+5 or slower; two
    games must fit an hour), shortening to the 10 minutes of chess.com's rapid by the last months."""
    if no <= 4:
        return None
    if no <= 16:
        return (20, 10)
    if no <= 36:
        return (15, 10)
    if no <= 44:
        return (10, 5)
    return (10, 0)


def wk_hints(no):
    return 5 if no <= 2 else 3 if no <= 8 else 1 if no <= 16 else 0


def _lesson_of_day(wk, dow):
    """A week's lessons fall on its first days, one a day."""
    return wk.lessons[dow] if dow < len(wk.lessons) else None
