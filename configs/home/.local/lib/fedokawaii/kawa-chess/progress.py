"""Where you are: the day, what of it is done, the two ratings, what comes back when; kept in one file."""
import datetime
import time

from puzzles import REPEAT_DAYS, glicko2


def today_ordinal():
    return datetime.date.today().toordinal()


class Progress:
    DEFAULT_GAME = {"r": 450.0, "rd": 200.0, "vol": 0.06}
    DEFAULT_PUZZLE = {"r": 650.0, "rd": 250.0, "vol": 0.06}

    def __init__(self, store):
        self.store = store
        d = store.load("progress.json", {})
        self.day = _int(d.get("day"), 1, 1, 366)
        self.items = _dict(d.get("items"))              # "day/key" → when it was done
        self.lessons = _dict(d.get("lessons"))          # lesson id → page reached, or "done"
        self.game = _rating(d.get("game"), self.DEFAULT_GAME)
        self.puzzle = _rating(d.get("puzzle"), self.DEFAULT_PUZZLE)
        self.seen = set(x for x in _list(d.get("seen")) if isinstance(x, str))
        self.due = _dict(d.get("due"))                  # puzzle id → {at, step, own item?}
        self.played = _dict(d.get("played"))            # game number as a string → its record
        self.history = _list(d.get("history"))          # [ordinal, game r, puzzle r], a line a day
        self.streak = _int(d.get("streak"), 0, 0, 100000)
        self.last_active = _int(d.get("last_active"), 0, 0, 10**7)
        self.puzzle_left = _dict(d.get("puzzle_left"))  # day → seconds of the sitting not used yet
        self.free_games = _int(d.get("free_games"), 0, 0, 10**7)
        self.takeaways = _list(d.get("takeaways"))
        self.started = _int(d.get("started"), 0, 0, 10**7) or today_ordinal()
        self.solved_by_theme = _dict(d.get("themes"))   # theme → [solved, tried]
        self.first_try = _int(d.get("first_try"), 0, 0, 10**9)
        self.tries = _int(d.get("tries"), 0, 0, 10**9)
        self.stamped = _int(d.get("stamped"), 0, 0, 366)   # (the last day whose seal has come down)

    def save(self):
        return self.store.save("progress.json", {
            "day": self.day, "items": self.items, "lessons": self.lessons, "game": self.game, "puzzle": self.puzzle,
            "seen": sorted(self.seen), "due": self.due, "played": self.played, "history": self.history[-800:],
            "streak": self.streak, "last_active": self.last_active, "puzzle_left": self.puzzle_left,
            "free_games": self.free_games, "takeaways": self.takeaways[-800:], "started": self.started,
            "themes": self.solved_by_theme, "first_try": self.first_try, "tries": self.tries, "stamped": self.stamped})

    # ── days ─────────────────────────────────────────────────────────────────────────────────
    def active(self):
        """Something was done today: the streak grows by a day, or starts again after a gap."""
        t = today_ordinal()
        if self.last_active == t:
            return
        self.streak = self.streak + 1 if self.last_active == t - 1 else 1
        self.last_active = t
        if not self.history or self.history[-1][0] != t:
            self.history.append([t, round(self.game["r"]), round(self.puzzle["r"])])

    def is_done(self, day, key):
        return f"{day}/{key}" in self.items

    def mark_done(self, day, key):
        self.active()
        self.items[f"{day}/{key}"] = time.strftime("%Y-%m-%d")
        if self.history and self.history[-1][0] == today_ordinal():
            self.history[-1] = [today_ordinal(), round(self.game["r"]), round(self.puzzle["r"])]
        self.save()

    # ── games ────────────────────────────────────────────────────────────────────────────────
    def game_result(self, score, elo):
        g = self.game
        g["r"], g["rd"], g["vol"] = glicko2(g["r"], g["rd"], g["vol"], elo, 60.0, score)

    # ── puzzles ──────────────────────────────────────────────────────────────────────────────
    def puzzle_result(self, item, ok):
        self.active()
        pid = item[0]
        p = self.puzzle
        p["r"], p["rd"], p["vol"] = glicko2(p["r"], p["rd"], p["vol"], item[3], 75.0, 1.0 if ok else 0.0)
        self.seen.add(pid)
        self.tries += 1
        self.first_try += 1 if ok else 0
        for theme in item[4].split():
            t = self.solved_by_theme.setdefault(theme, [0, 0])
            t[0] += 1 if ok else 0
            t[1] += 1
        now = today_ordinal()
        d = self.due.get(pid)
        if ok:
            if d is not None:
                d["step"] = d.get("step", 0) + 1
                if d["step"] >= len(REPEAT_DAYS):
                    del self.due[pid]
                else:
                    d["at"] = now + REPEAT_DAYS[d["step"]]
        else:
            self.due[pid] = {"at": now + REPEAT_DAYS[0], "step": 0, **({"item": list(item)} if pid.startswith("own") else {})}

    def due_puzzle(self):
        """An item whose day has come, or None."""
        now = today_ordinal()
        for pid, d in self.due.items():
            if d.get("at", 0) <= now:
                if "item" in d:
                    return tuple(d["item"])
                it = self.bank_item(pid)
                if it is not None:
                    return it
        return None

    bank_item = staticmethod(lambda pid: None)   # (the app points it at the bank)

    def forget_due(self, pid):
        self.due.pop(pid, None)

    def own_puzzle(self, gid, n, fen, line, rating):
        """Your own miss as a puzzle: the position before your move, the better line. Comes tomorrow."""
        pid = f"own{gid}-{n}"
        self.due[pid] = {"at": today_ordinal() + 1, "step": 0, "item": [pid, fen, line, rating, "own"]}


def _int(v, default, lo, hi):
    return v if isinstance(v, int) and not isinstance(v, bool) and lo <= v <= hi else default


def _dict(v):
    return v if isinstance(v, dict) else {}


def _list(v):
    return v if isinstance(v, list) else []


def _rating(v, default):
    d = dict(default)
    if isinstance(v, dict):
        for k in d:
            if isinstance(v.get(k), (int, float)) and not isinstance(v.get(k), bool):
                d[k] = float(v[k])
    return d
