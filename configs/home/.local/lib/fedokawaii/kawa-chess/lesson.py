"""A lesson: a few pages, each words and a position; moves played out on the board, moves you must find,
puzzles of the lesson's theme at its end. The place is kept: a lesson left is a lesson resumed.

lessons.txt: `=== slug` starts a lesson; head lines `key: value`, a blank line, then pages split by a
line `---`. In a page:
  @fen FEN            the board                    @flip          the board from Black's side
  @mark e4 d5         squares marked               @arrow e2e4    an arrow
  @play Nf3 Nc6       moves played out, one by one
  @try Nf3 | words    the move you must find (others: the words; several right ones: Nf3 Bc4 | …)
  @find e4 a1 h8      squares to find, typed or clicked
  @drill THEME N [±R] N puzzles of a theme now (R: around your rating, shifted)
Anything else is words; a blank line starts a new paragraph.
"""
import re
import time

import board as B
from app import Screen
from play import MoveInput, board_marks, moved_parts
from puzzles import Session
from term import ACCENT_TEXT, FAINT, MUTED, STRONG
from ui import heading, icon, wrap


class Page:
    __slots__ = ("fen", "flip", "marks", "arrows", "plays", "tries", "words", "drill", "fail", "find")

    def __init__(self):
        self.fen = self.flip = None
        self.marks, self.arrows, self.plays, self.words = [], [], [], []
        self.tries = None
        self.fail = ""
        self.drill = None
        self.find = None


def parse(text):
    """(head, pages) of a lesson file. ValueError on what cannot be meant."""
    head = {}
    lines = text.split("\n")
    i = 0
    while i < len(lines) and lines[i].strip():
        k, sep, v = lines[i].partition(":")
        if not sep:
            raise ValueError(f"not a head line: {lines[i]!r}")
        head[k.strip()] = v.strip()
        i += 1
    pages, page = [], Page()
    para = []

    def flush():
        if para:
            page.words.append(" ".join(para))
            para.clear()

    for line in lines[i:]:
        s = line.strip()
        if s == "---":
            flush()
            pages.append(page)
            page = Page()
        elif s.startswith("@"):
            word, _, rest = s[1:].partition(" ")
            rest = rest.strip()
            if word == "fen":
                page.fen = rest
            elif word == "flip":
                page.flip = True
            elif word == "mark":
                page.marks = rest.split()
            elif word == "arrow":
                page.arrows = rest.split()
            elif word == "play":
                page.plays = rest.split()
            elif word == "try":
                good, _, fail = rest.partition("|")
                page.tries = good.split()
                page.fail = fail.strip()
            elif word == "find":
                page.find = rest.split()
            elif word == "any":
                pass                 # (for the checker: a @try that teaches a move, not a good one)
            elif word == "drill":
                parts = rest.split()
                page.drill = (parts[0], int(parts[1]), int(parts[2]) if len(parts) > 2 else 0)
            else:
                raise ValueError(f"unknown @{word}")
        elif not s:
            flush()
        else:
            para.append(s)
    flush()
    if page.words or page.fen or page.plays or page.tries or page.drill or page.find:
        pages.append(page)
    return head, pages


class Library:
    """The lessons in their order, from one file; a lesson's pages parsed when first opened."""

    def __init__(self, path):
        self.index = []
        self.by_id = {}
        self.texts = {}
        try:
            with open(path, encoding="utf-8", errors="replace") as f:
                text = f.read()
        except OSError:
            return
        for block in re.split(r"(?m)^=== ", text)[1:]:
            lid, _, body = block.partition("\n")
            lid = lid.strip()
            if not lid or lid in self.by_id:
                continue
            self.texts[lid] = body
            meta = {"id": lid, "title": lid.replace("-", " "), "minutes": "", "source": ""}
            for line in body.split("\n"):
                if not line.strip():
                    break
                k, _, v = line.partition(":")
                if k in ("title", "minutes", "source"):
                    meta[k] = v.strip()
            self.by_id[lid] = meta
            self.index.append(lid)

    def read(self, lid):
        return parse(self.texts[lid])


class Lesson(Screen):
    def __init__(self, lid, library, progress, done=None, number=None):
        self.lid, self.lib, self.pr = lid, library, progress
        self.done_cb = done
        self.number = number
        self.meta = library.by_id.get(lid, {"title": lid, "minutes": "", "source": ""})
        try:
            _, self.pages = library.read(lid)
        except (OSError, ValueError) as e:
            self.pages = _broken(str(e))
        self.at = 0
        seen = progress.lessons.get(lid)
        if isinstance(seen, int) and 0 <= seen < len(self.pages):
            self.at = seen
        self.pos = B.Position()
        self.last = None
        self.flipped = False
        self.hand = MoveInput()
        self.waiting = None        # the moves left to play out on this page
        self.next_play = None
        self.tried = 0
        self.note = ""
        self.solved = False
        self.scroll = 0
        self.cursor = None
        self.entered = False
        self.find = None           # the squares still to find on this page
        self.found = []
        self.typed = ""

    def tick(self, now):
        if not self.entered:
            self.entered = True
            self._enter(self.at)
            self.app.touch()
        if self.next_play is not None:
            if now >= self.next_play:
                self.next_play = None
                self._play_next()
                return None
            return self.next_play
        return None

    def _page(self):
        return self.pages[self.at]

    def _enter(self, i):
        self.at = i
        self.scroll = 0
        self.note = ""
        self.tried = 0
        self.solved = False
        pg = self._page()
        self.pr.lessons[self.lid] = i
        self.pr.save()
        if pg.fen:
            try:
                self.pos = B.Position(pg.fen)
            except ValueError:
                self.pos = B.Position()
            self.last = None
        if pg.flip is not None:
            self.flipped = bool(pg.flip)
        self.waiting = list(pg.plays)
        self.next_play = time.monotonic() + 0.6 if self.waiting else None
        self.hand.clear()
        self.hand.pos = None
        self.find = list(pg.find) if pg.find else None
        self.found = []
        self.typed = ""
        if pg.tries and not self.waiting:
            self.hand.reset(self.pos)
        if pg.drill and not self.waiting:
            self._drill(pg)

    def _drill(self, pg):
        theme, n, shift = pg.drill

        def back(_s):
            self.solved = True

        self.solved = True
        self.app.push(Session(f"{theme} · {n} to solve", theme, left=1e9, done=back, count_limit=n, rating_shift=shift))

    def _play_next(self):
        if not self.waiting:
            return
        san = self.waiting.pop(0)
        m = self.pos.parse_san(san)
        if m is None:
            self.waiting = []
            return
        pos = self.pos
        parts = moved_parts(pos, m)

        def arrived():
            pos.push(m)
            self.last = m
            if self.waiting:
                self.next_play = time.monotonic() + 0.9
            elif self._page().tries:
                self.hand.reset(pos)
            elif self._page().drill:
                self._drill(self._page())
            self.app.touch()

        self.app.slide(parts, {p[1] for p in parts}, arrived, ms=260)

    def board(self):
        pg = self._page()
        marks = board_marks(self.pos, self.last)
        for s in pg.marks:
            try:
                marks.setdefault(B.sq_of(s), set()).add("dot" if not self.pos.b[B.sq_of(s)] else "take")
            except (ValueError, IndexError):
                pass
        if self.hand.pos is not None:
            for s, ms in self.hand.marks().items():
                marks.setdefault(s, set()).update(ms)
        for s in self.found:
            marks.setdefault(B.sq_of(s), set()).add("good")
        arrows = []
        if not self.waiting:
            for a in pg.arrows:
                try:
                    m = B.from_uci(a)
                    arrows.append((m & 63, m >> 6 & 63, "asagi"))
                except ValueError:
                    pass
        return self.pos.b, marks, arrows, self.flipped

    def panel(self, w, h):
        pg = self._page()
        right = f"{self.at + 1} of {len(self.pages)}"
        out = [heading("BOOK", self.meta["title"], w, right=right), ""]
        body = []
        for para in pg.words:
            for line in wrap(para, w):
                body.append([line])
            body.append("")
        if self.hand.pos is not None:
            line = [(icon("CHEVRON_RIGHT"), ACCENT_TEXT), "  "]
            if self.hand.promo:
                line.append(("q r b n", MUTED))
            elif self.hand.bad:
                line += [(icon("CROSS"), ACCENT_TEXT), " ", self.hand.bad]
            elif self.hand.typed:
                line.append((self.hand.typed, STRONG))
            else:
                line.append(("your move", FAINT))
            body.append(line)
        if self.find:
            body += [[(icon("SEARCH"), ACCENT_TEXT), "  ", (self.find[0], STRONG), "  ", (self.typed, None)], ""]
        if self.note:
            body.append("")
            body += [[(s, MUTED)] for s in wrap(self.note, w)]
        room = h - 2
        self.scroll = max(0, min(self.scroll, max(0, len(body) - room)))
        out += body[self.scroll:self.scroll + room]
        return out

    def _advance(self):
        if self.at + 1 < len(self.pages):
            self._enter(self.at + 1)
            return
        self.pr.lessons[self.lid] = "done"
        self.pr.save()
        cb, self.done_cb = self.done_cb, None
        self.app.pop()
        if cb:
            cb()

    def key(self, name):
        if self.find:
            if name == "backspace":
                self.typed = self.typed[:-1]
                return
            if name == "esc":
                self.app.pop()
            return
        if name == "up":
            self.scroll = max(0, self.scroll - 1)
            return
        if name == "down":
            self.scroll += 1
            return
        if self.hand.pos is not None:
            hand = self.hand
            if name == "esc":
                if hand.holds():
                    hand.letgo()
                else:
                    self.app.pop()
                return
            if name == "enter":
                m = hand.enter()
                if m is not None:
                    self._tried(m)
            elif name == "backspace":
                hand.backspace()
            elif name in ("left", "right"):
                hand.arrow(name, self.flipped, B.sq_of("e4"))
            return
        if name == "esc":
            self.app.pop()
        elif name in ("enter", "right", "space"):
            if self.waiting or self.next_play:
                self._hurry()
            else:
                self._advance()
        elif name == "left" and self.at > 0:
            self._enter(self.at - 1)

    def _hurry(self):
        """Enter while moves play out: they all land at once."""
        for san in self.waiting or ():
            m = self.pos.parse_san(san)
            if m is None:
                break
            self.pos.push(m)
            self.last = m
        self.waiting = []
        self.next_play = None
        pg = self._page()
        if pg.tries:
            self.hand.reset(self.pos)
        elif pg.drill:
            self._drill(pg)

    def _found(self, name):
        if name == self.find[0]:
            self.found.append(self.find.pop(0))
            self.note = ""
            if not self.find:
                self.find = None
        else:
            self.note = f"that is {name}."
        self.typed = ""

    def text(self, chars):
        if self.find:
            for ch in chars.lower():
                if not self.find:
                    return
                if not self.typed and ch in "abcdefgh":
                    self.typed = ch
                elif self.typed and ch in "12345678":
                    self._found(self.typed + ch)
            return
        if " " in chars and self.hand.pos is None:
            self.key("enter")
            return
        if self.hand.pos is not None:
            m = self.hand.text(chars)
            if m is not None:
                self._tried(m)

    def click(self, sq):
        if self.find:
            self._found(B.sq_name(sq))
            return
        if self.hand.pos is not None:
            m = self.hand.touch(sq)
            if m is not None:
                self._tried(m)

    def wheel(self, d):
        self.scroll = max(0, self.scroll + d)

    def _tried(self, m):
        pg = self._page()
        pos = self.pos
        good = [pos.parse_san(s) for s in pg.tries]
        if m in good:
            self.hand.clear()
            self.hand.pos = None
            parts = moved_parts(pos, m)

            def arrived():
                pos.push(m)
                self.last = m
                self.note = ""
                self.app.touch()

            self.app.slide(parts, {p[1] for p in parts}, arrived)
            return
        self.tried += 1
        self.hand.clear()
        if self.tried >= 3 and good and good[0] is not None:
            self.note = f"it is {pos.san(good[0])}."
        else:
            self.note = pg.fail or "not that one."

    def leave(self):
        pass


def _broken(why):
    p = Page()
    p.words = [f"this lesson cannot be read: {why}"]
    return [p]


