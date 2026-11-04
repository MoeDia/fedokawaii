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
    if right and room >= len(right) + 5:      # (a column in from the content's last: over the rows' values, §7)
        rule = room - len(right) - 3
        spans += [" ", ("─" * rule, EDGE2), " ", (right, MUTED), " "]
    elif room >= 2:
        spans += [" ", ("─" * (room - 1), EDGE2)]
    return spans


class Row:
    """A row of a list: its icon at column 1, name from column 4, value right-aligned a column in from the content's
    last: two columns from the end of the cursor's tint, as the icon from its start (§7). The tint from the cursor's
    column to one beyond the content. act: what choosing it does."""
    __slots__ = ("ic", "name", "value", "act", "ink", "value_ink", "tag", "mark")

    def __init__(self, ic, name, value="", act=None, ink=None, value_ink=MUTED, tag=None, mark=None):
        self.ic, self.name, self.value, self.act = ic, name, value, act
        self.ink, self.value_ink, self.tag = ink, value_ink, tag
        self.mark = mark          # (two characters in the icon's two cells: chess's own ?? and ?!, say)

    def spans(self, w, selected=False):
        v = "" if self.value is None or self.value == "" else str(self.value)
        room = w - 4 - (len(v) + 3 if v else 0)
        name = self.name
        if len(name) > room:
            name = _cut(name, room)
        pad = w - 4 - len(name) - (len(v) + 1 if v else 0)
        if selected:
            # (the name and its picture text_on_select, every other ink its own, §7; the cursor's column before and one
            # beyond: the panel draws those two cells, the edge in the first)
            pic = [(self.mark.ljust(2), ACCENT_TEXT, SELECT), (" ", ON_SELECT, SELECT)] if self.mark else [((icon(self.ic) if self.ic else " ") + "  ", ON_SELECT, SELECT)]
            return [(" ", ON_SELECT, SELECT), *pic, (name + " " * pad, ON_SELECT, SELECT), *([(v, self.value_ink, SELECT), (" ", ON_SELECT, SELECT)] if v else [])]
        if self.mark:
            out = [" ", (self.mark.ljust(2), ACCENT_TEXT), " ", (name, self.ink)]
        else:
            out = [" ", (icon(self.ic) if self.ic else " ", self.icon_ink()), "  ", (name, self.ink)]
        if v:
            out += [" " * pad, (v, self.value_ink)]
        return out

    def icon_ink(self):
        return self.ink if self.ink in (FAINT, ACCENT, ACCENT_TEXT) else MUTED


def _cut(s, n):
    """What fits, at a word's end: nothing added, no word in half (§2); a first word too long for the room: nothing."""
    if n <= 0:
        return ""
    if len(s) <= n:
        return s
    if s[n] == " ":
        return s[:n]
    sp = s.rfind(" ", 0, n)
    return s[:sp].rstrip() if sp > 0 else ""


class Face:
    """Panel lines with a picture beside them, on the content's first column: 40 × 40 px, five cells by two rows; large
    (a tall panel, the large board's): 80 × 80, ten cells by four. The words start one cell after it, their two lines in
    the middle of its rows. The lines after a Face are its other rows (Face.BELOW): Face.lines gives them all."""
    __slots__ = ("name", "top", "bottom", "large")
    BELOW = object()
    COLS = 6
    LARGE_COLS = 11

    def __init__(self, name, top, bottom, large=False):
        self.name, self.top, self.bottom, self.large = name, top, bottom, large

    @property
    def cols(self):
        return self.LARGE_COLS if self.large else self.COLS

    @property
    def lines(self):
        return [self] + [self.BELOW] * (3 if self.large else 1)


def tile(key):
    """A key on a text screen (§7 Keys): whole cells of Sumi Icons Term, U+FF001, then U+FF000 + each letter's ASCII
    code, then U+FF002: its frame, its lip and its letters one ink, no fill."""
    return ("\U000ff001" + "".join(chr(0xff000 + ord(c)) for c in key) + "\U000ff002", MUTED)


def keys_line(w, *pairs):
    """A screen's own keys on its last line (§7): the key a tile, what it does muted, its state strong, two cells
    between them; as many of them, the first ones, as the panel has room for."""
    out, used = [], 0
    for p in pairs:
        need = len(p[0]) + 3 + len(p[1]) + (2 + len(p[2]) if len(p) > 2 else 0) + (2 if out else 0)
        if used + need > w:
            break
        if out:
            out.append("  ")
        out += [tile(p[0]), " ", (p[1], MUTED)]
        if len(p) > 2:
            out += ["  ", (p[2], STRONG)]
        used += need
    return out


def footed(lines, h, keys):
    """A panel's lines and, on its last line, its keys; what does not fit gives way to them."""
    if not keys:
        return lines[:h]
    lines = lines[:max(0, h - 2)]
    return lines + [""] * (h - 1 - len(lines)) + [keys]


def meter(fraction, cells=20):
    """Ten or twenty segments, a cell each (Sumi Icons' read and read-off, §7): done solid, to do hollow."""
    done = round(max(0.0, min(1.0, fraction)) * cells)
    return [(icon("READ") * done, ACCENT_TEXT), (icon("READ_OFF") * (cells - done), EDGE2)]


def window(lines, top, room):
    """What fits of lines from `top`: a scrolling pane; when there is more below, its last line says so. Returns
    (the lines to show, the top as it could be kept)."""
    top = max(0, min(top, max(0, len(lines) - room)))
    shown = lines[top:top + room]
    if top + room < len(lines) and room > 0:
        shown = shown[:-1] + [[("↓", MUTED)]]
    return shown, top


def span_len(spans):
    n = 0
    for s in spans:
        n += len(s if isinstance(s, str) else s[0])
    return n


class Layout:
    """Where the board and the panel go in a window of cols × rows. A board is 8 squares of 40, 80 or
    120 px with a pixel's frame round them: the largest that leaves the panel its room; the panel
    beside it or, in a tall narrow window, under it. In a window larger than they need the two stay
    together, one block in its middle, the panel as tall as the board and no wider than a line reads.
    Too small for the smallest board: `small`."""
    MIN_W, MIN_H = 60, 20
    PANEL_MAX = 60
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
                pw = min(w, self.PANEL_MAX)
                self.col = (cols - bc - 3 - pw) // 2
                if scale > 1:
                    self.row = (rows - br) // 2
                    self.pc, self.pr, self.pw, self.ph = self.col + bc + 2, self.row, pw, br
                else:                  # (the smallest board: every row is the panel's, and the board in the middle of them if there are many)
                    self.row = (rows - br) // 2 if rows - br >= 6 else 0
                    self.pc, self.pr, self.pw, self.ph = self.col + bc + 2, 0, pw, rows
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
