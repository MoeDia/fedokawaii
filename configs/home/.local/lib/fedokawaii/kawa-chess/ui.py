"""The panel's grammar in characters (docs/design-system.md §7), and where board and panel go.

Spans: a string (the terminal's own ink, `text`) or (string, ink) or (string, ink, ground).
Lines are lists of spans; a Row carries what a click or Enter on it means.
"""
import re

from term import ACCENT, ACCENT_TEXT, EDGE2, FAINT, MUTED, ON_SELECT, SELECT, STRONG

PIECE_MIN_ROWS = 18        # 320 px + the frame: the smallest board
_ICON = re.compile(r"^ICON_([A-Z0-9_]+)=\$'((?:\\x[0-9a-f]{2})+)'", re.M)
ICONS = {}


def load_icons(path):
    """The desktop's icon names → their characters (icons.sh is written by tools/build-icons.py)."""
    with open(path, encoding="utf-8") as f:
        text = f.read()
    for name, esc in _ICON.findall(text):
        ICONS[name] = bytes(int(h, 16) for h in esc.split("\\x")[1:]).decode("utf-8")


def icon(name):
    return ICONS.get(name, " ")


def wrap(text, width):
    """Words on lines of at most width; a word longer than a line is cut at the line, nothing added."""
    out = []
    for para in text.split("\n"):
        cur = ""
        for word in para.split():
            while len(word) > width > 0:
                if cur:
                    out.append(cur)
                    cur = ""
                out.append(word[:width])
                word = word[width:]
            if not cur:
                cur = word
            elif len(cur) + 1 + len(word) <= width:
                cur += " " + word
            else:
                out.append(cur)
                cur = word
        out.append(cur)
    return out


def heading(ic, name, w, right=None):
    """Its icon at column 0, its name from column 3, a space, the rule to the last column; a value
    (muted) may stand at the rule's end."""
    name = _cut(name, max(0, w - 3))
    used = 3 + len(name)
    spans = [(icon(ic), ACCENT_TEXT), "  ", (name, STRONG)]
    room = w - used
    if right and room >= len(right) + 4:
        rule = room - len(right) - 2
        spans += [" ", ("─" * rule, EDGE2), " ", (right, MUTED)]
    elif room >= 2:
        spans += [" ", ("─" * (room - 1), EDGE2)]
    return spans


class Row:
    """A row of a list: its icon at column 1, name from column 4, value right-aligned; a cursor's
    lacquer from the cursor's column to one beyond the content. act: what choosing it does."""
    __slots__ = ("ic", "name", "value", "act", "ink", "value_ink", "tag")

    def __init__(self, ic, name, value="", act=None, ink=None, value_ink=MUTED, tag=None):
        self.ic, self.name, self.value, self.act = ic, name, value, act
        self.ink, self.value_ink, self.tag = ink, value_ink, tag

    def spans(self, w, selected=False):
        v = "" if self.value is None or self.value == "" else str(self.value)
        room = w - 4 - (len(v) + 2 if v else 0)
        name = self.name
        if len(name) > room:
            name = _cut(name, room)
        pad = w - 4 - len(name) - len(v)
        if selected:
            # (the cursor's column before and one beyond: the panel draws those two cells)
            return [(" " + (icon(self.ic) if self.ic else " ") + "  " + name + " " * pad + v, ON_SELECT, SELECT)]
        out = [" ", (icon(self.ic) if self.ic else " ", self.icon_ink()), "  ", (name, self.ink)]
        if v:
            out += [" " * pad, (v, self.value_ink)]
        return out

    def icon_ink(self):
        return self.ink if self.ink in (FAINT, ACCENT, ACCENT_TEXT) else MUTED


def _cut(s, n):
    """At a word's end if one fits, else at the line: nothing added (§2)."""
    if n <= 0:
        return ""
    if len(s) <= n:
        return s
    cut = s[:n]
    sp = cut.rfind(" ")
    return cut[:sp] if sp > n // 2 else cut


class Face:
    """Two panel lines with a picture beside them: 40 × 40 px, five cells by two rows, on the content's first column;
    the words of each line start one cell after it. The line after a Face is its second row (Face.BELOW)."""
    __slots__ = ("name", "top", "bottom")
    BELOW = object()
    COLS = 6

    def __init__(self, name, top, bottom):
        self.name, self.top, self.bottom = name, top, bottom


def keys_line(*pairs):
    """A screen's own keys on its last line: the key in text, what it does muted, its state strong."""
    out = []
    for i, p in enumerate(pairs):
        if i:
            out.append("   ")
        out += [p[0], "  ", (p[1], MUTED)]
        if len(p) > 2:
            out += ["  ", (p[2], STRONG)]
    return out


def meter(fraction, cells=20):
    """Ten or twenty segments, a cell each (Sumi Icons' read and read-off, §7): done solid, to do hollow."""
    done = round(max(0.0, min(1.0, fraction)) * cells)
    return [(icon("READ") * done, ACCENT_TEXT), (icon("READ_OFF") * (cells - done), EDGE2)]


def span_len(spans):
    n = 0
    for s in spans:
        n += len(s if isinstance(s, str) else s[0])
    return n


class Layout:
    """Where the board and the panel go in a window of cols × rows. A board is 8 squares of 40, 80 or
    120 px with a pixel's frame round them: the largest that leaves the panel its room; the panel
    beside it or, in a tall narrow window, under it. Too small for the smallest board: `small`."""
    MIN_W, MIN_H = 60, 20
    __slots__ = ("scale", "col", "row", "pc", "pr", "pw", "ph", "side", "small", "cols", "rows")

    def __init__(self, cols, rows, cw, ch):
        self.cols, self.rows = cols, rows
        self.small = False
        self.side = True
        self.scale = 1
        self.col = 0                     # the picture's first cell (it holds its own margin)
        self.row = 0
        self.pc = self.pr = self.pw = self.ph = 0
        if cols < self.MIN_W or rows < self.MIN_H:
            self.small = True
            return
        for scale in (3, 2, 1):
            px = 8 * 40 * scale + 16
            bc, br = -(-px // cw), -(-px // ch)
            # beside it: the panel from the second cell after the picture to one cell before the edge
            w = cols - bc - 3
            if br <= rows and w >= 30:
                self.scale, self.side = scale, True
                self.pc, self.pr, self.pw, self.ph = bc + 2, 0, w, rows
                return
            # under it: as wide as the board, on what is left of the height
            if bc + 1 <= cols and rows - br >= 10:
                self.scale, self.side = scale, False
                self.col = (cols - bc) // 2
                self.pc, self.pr, self.pw, self.ph = self.col + 2, br, bc - 4, rows - br
                return
        # the smallest board and whatever room is left beside it
        bc, br = -(-336 // cw), -(-336 // ch)
        w = cols - bc - 3
        if br <= rows and w >= 15:
            self.scale, self.side = 1, True
            self.pc, self.pr, self.pw, self.ph = bc + 2, 0, w, rows
        elif bc <= cols and rows - br >= 2:
            self.scale, self.side = 1, False
            self.col = (cols - bc) // 2
            self.pc, self.pr, self.pw, self.ph = self.col + 2, br, bc - 4, rows - br
        else:
            self.small = True
