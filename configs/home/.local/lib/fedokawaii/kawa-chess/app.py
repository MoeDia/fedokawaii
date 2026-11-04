"""kawa-chess: the loop. One thread, nothing polled: keys, the engine's lines and timers wake it."""
import os
import re
import selectors
import signal
import sys
import time
import traceback

from art import Art, BoardView, MARGIN
from engine import Engine
from store import Store
from term import MUTED, ON_SELECT, SELECT, Term, Wakeups
from ui import Face, Layout, load_icons, wrap

HOME = os.path.expanduser("~")
DATA = os.path.join(os.environ.get("XDG_DATA_HOME") or os.path.join(HOME, ".local/share"), "fedokawaii/chess")
CONFIG = os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.join(HOME, ".config"), "fedokawaii")
STATE = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.join(HOME, ".local/state"), "fedokawaii/chess")
SLIDE_MS = 200


def current_mood():
    """dark or light, as the desktop's theme says (colors.sh); foot's own report keeps it after that."""
    try:
        with open(os.path.join(CONFIG, "current/colors.sh"), encoding="utf-8") as f:
            m = re.search(r"^THEME=(\w+)", f.read(), re.M)
        return m[1] if m and m[1] in ("dark", "light") else "dark"
    except OSError:
        return "dark"


def ease_out(t):
    return 1 - (1 - t) ** 3


class Screen:
    """What fills the window: says what the board shows, what the panel says, what keys do."""
    app = None

    def board(self):
        """(squares, marks, arrows, flipped) or None to leave the board as it stands."""
        return None

    def panel(self, w, h):
        """A list of lines of spans (or Rows), at most h long."""
        return []

    def key(self, name):
        pass

    def text(self, chars):
        pass

    def paste(self, text):
        pass

    def click(self, sq):
        pass

    def click_row(self, index):
        pass

    def tick(self, now):
        """Something timed; returns when it next wants waking (monotonic seconds), or None."""
        return None

    def focus(self, on):
        pass

    def leave(self):
        pass


class Slide:
    """Men in motion: [(piece, from-square, to-square)] sliding together in whole art pixels."""

    def __init__(self, view, parts, ms, done):
        self.view, self.done_cb = view, done
        self.parts = [(p, view.origin(a), view.origin(b)) for p, a, b in parts]
        self.t0 = time.monotonic()
        self.ms = ms / 1000
        self.ground = None
        self.last = [a for _, a, _ in self.parts]
        self.placed = None

    def positions(self, now):
        t = min(1.0, (now - self.t0) / self.ms)
        e = ease_out(t)
        s = self.view.s
        out = []
        for _p, a, b in self.parts:
            x = a[0] + round((b[0] - a[0]) * e / s) * s
            y = a[1] + round((b[1] - a[1]) * e / s) * s
            out.append((x, y))
        return out, t >= 1.0


class Burst:
    """A capture: a few sparks leave the square, 150 ms, drawn over the board and gone: no state of their own."""
    MS = 0.15
    DIRS = ((-1.0, -0.8), (1.0, -0.9), (-0.7, 0.6), (0.8, 0.7), (0.1, -1.0), (-1.0, 0.1), (1.0, 0.15), (-0.2, 1.0))

    def __init__(self, view, sq, inks):
        self.view, self.inks = view, inks
        self.x, self.y = view.origin(sq)
        self.t0 = time.monotonic()
        self.step = -1
        self.ground = None
        self.done_cb = lambda: None

    def frames(self, now, palette):
        """The picture of this moment, once per art-pixel step; None when nothing new; "end" when over."""
        t = (now - self.t0) / self.MS
        if t >= 1:
            return "end"
        step = int(t * 14)
        if step == self.step:
            return None
        self.step = step
        v, s, S = self.view, self.view.s, self.view.S
        part = v.cv.crop(self.x, self.y, S, S)
        reach = ease_out(t) * (S // 2 - 2 * s)
        for i, (dx, dy) in enumerate(self.DIRS):
            size = (2 if t < 0.6 else 1) * s
            px = S // 2 + int(dx * reach) // s * s
            py = S // 2 + int(dy * reach) // s * s
            part.fill(px, py, size, size, self.inks[i % len(self.inks)])
        return self.x, self.y, part.sixel(palette)


class App:
    def __init__(self):
        self.term = Term()
        self.art = Art(DATA)
        self.store = Store(STATE)
        self.engine = Engine()
        self.mood = current_mood()
        self.layout = None
        self.view = None
        self.stack = []
        self.anim = None
        self.dirty = True
        self.fresh = True            # (the whole window to draw)
        self.quit = False
        self.focused = True
        self.rows_at = {}            # panel row on the screen → index in the screen's panel lines
        self.pic_key = None          # the picture shown in the board's place, if any
        self.face_at = None          # the face in the panel: (name, row, column, mood)
        self.face_rows = set()
        self.pic_mood = None

    # ── the screens ──────────────────────────────────────────────────────────────────────────
    @property
    def screen(self):
        return self.stack[-1] if self.stack else None

    def push(self, screen):
        screen.app = self
        self.stack.append(screen)
        self.touch()

    def pop(self):
        s = self.stack.pop()
        s.leave()
        if not self.stack:
            self.quit = True
        else:
            shown = getattr(self.stack[-1], "on_show", None)
            if shown:
                shown()
        self.touch()

    def replace(self, screen):
        s = self.stack.pop()
        s.leave()
        screen.app = self
        self.stack.append(screen)
        self.touch()

    def touch(self):
        self.dirty = True

    def trace(self, *words):
        """For the tests' scripted player: what is on the board, in words (KAWA_CHESS_TRACE=FILE)."""
        path = os.environ.get("KAWA_CHESS_TRACE")
        if path:
            with open(path, "a", encoding="utf-8") as f:
                f.write("\t".join(str(w) for w in words) + "\n")

    # ── drawing ──────────────────────────────────────────────────────────────────────────────
    def relayout(self):
        t = self.term
        self.layout = Layout(t.cols, t.rows, t.cw, t.ch)
        flipped = self.view.flipped if self.view else False
        self.pic_key = None
        self.face_at = None
        self.face_rows = set()
        if self.layout.small:
            self.view = None
        else:
            self.view = BoardView(self.art, self.layout.scale, self.mood, t.cw, t.ch, flipped)
        self.finish_anim()
        self.fresh = True
        self.touch()

    def palette(self):
        return self.art.pal[self.mood]

    def render(self):
        t = self.term
        self.dirty = False
        if self.fresh:
            t.clear()
            self.fresh = False
            if self.view:
                self.view.redraw_all()
        lay = self.layout
        if lay.small:
            self._too_small()
            t.flush()
            return
        s = self.screen
        if s is None:
            return
        if self.anim is None:
            pic = s.picture(self.view) if hasattr(s, "picture") else None
            if pic is not None:
                key, canvas = pic
                if key != self.pic_key:
                    self.pic_key = key
                    t.picture(lay.row, lay.col, canvas.sixel(self.palette()))
            else:
                if self.pic_key is not None:
                    self.pic_key = None
                    self.view.redraw_all()
                b = s.board()
                if b is not None:
                    squares, marks, arrows, flipped = b
                    self.view.turn_over(flipped)
                    self.view.coords = not getattr(s, "plain", False)
                    self.view.set(squares, marks, arrows)
                self._send_board()
        self._draw_panel(s)
        t.flush()

    def _send_board(self):
        for x, y, six in self.view.pictures(self.palette()):
            self.term.picture(self.layout.row + y // self.term.ch, self.layout.col + x // self.term.cw, six)

    def _draw_panel(self, s):
        lay, t = self.layout, self.term
        lines = s.panel(lay.pw, lay.ph)
        self.rows_at = {}
        cur = getattr(s, "cursor", None)
        # (rows that held a picture and hold none now: their words were never drawn over it)
        rows_now = {lay.pr + i for i, ln in enumerate(lines[:lay.ph]) if isinstance(ln, Face) or ln is Face.BELOW}
        for row in self.face_rows - rows_now:
            t.forget(row, lay.pc - 1)
            t.forget(row, lay.pc + Face.COLS - 1)
        self.face_rows = rows_now
        if not rows_now:
            self.face_at = None
        for i in range(lay.ph):
            row = lay.pr + i
            if i < len(lines):
                ln = lines[i]
                if isinstance(ln, Face):
                    self._draw_face(ln, row)
                    continue
                if ln is Face.BELOW:
                    continue
                if hasattr(ln, "spans"):
                    self.rows_at[row] = i
                    sel = cur == i
                    # (the cursor's column before the content, and one beyond it: the lacquer's)
                    spans = ln.spans(lay.pw, sel)
                    if sel:
                        spans = [(" ", ON_SELECT, SELECT), *spans, (" ", ON_SELECT, SELECT)]
                    else:
                        spans = [" ", *spans, " "]
                    t.text(row, lay.pc - 1, spans, lay.pw + 2)
                    continue
                t.text(row, lay.pc - 1, [" ", *ln], lay.pw + 2)
            else:
                t.text(row, lay.pc - 1, [], lay.pw + 2)

    def _draw_face(self, face, row):
        """A picture and the words beside it; the picture sent only when it or its place changes."""
        t, lay = self.term, self.layout
        col = lay.pc - 1
        at = (face.name, row, col, self.mood)
        if at != self.face_at:
            self.face_at = at
            for r in (row, row + 1):
                t.forget(r, col)
                t.text(r, col, [], lay.pw + 2)
                t.forget(r, col)
                t.forget(r, lay.pc + Face.COLS - 1)
            cv = self.art.face(face.name)
            if cv is not None:
                t.picture(row, lay.pc, cv.sixel(self.palette()))
        w = lay.pw - Face.COLS + 1
        t.text(row, lay.pc + Face.COLS - 1, face.top, w)
        t.text(row + 1, lay.pc + Face.COLS - 1, face.bottom, w)

    def _too_small(self):
        t = self.term
        msg = wrap(f"this window is {t.cols} by {t.rows}: chess needs {Layout.MIN_W} by {Layout.MIN_H}", max(1, t.cols - 2))
        for i, line in enumerate(msg[:t.rows]):
            t.text(i, 1, [(line, MUTED)])
        for i in range(len(msg), t.rows):
            t.text(i, 0, [])

    # ── a man moving ─────────────────────────────────────────────────────────────────────────
    def slide(self, parts, hide, done, ms=SLIDE_MS):
        """parts: [(piece, from, to)] moved over the board as the screen shows it now, without what
        is on the squares `hide`. done: called when they arrive (or at once, if a key comes)."""
        self.finish_anim()
        if self.view is None:
            done()
            return
        b = self.screen.board()
        if b is not None:
            squares, marks, arrows, flipped = b
            self.view.turn_over(flipped)
            self.view.set(squares, marks, arrows, hide=hide)
        self._send_board()
        an = Slide(self.view, parts, ms, done)
        an.ground = self.view.under()
        self.anim = an
        self.term.flush()

    def burst(self, sq):
        """Sparks from a square where something was just taken."""
        if self.view is None:
            return
        i = self.art.index
        self.finish_anim()
        self._send_board()
        self.anim = Burst(self.view, sq, (i["flame"], i["accent_hi"], i["gold"]))

    def finish_anim(self):
        an = self.anim
        if an is not None:
            self.anim = None
            if self.view:
                self.view.hide = set()
                if isinstance(an, Burst):
                    x, y, data = self.view.cut(self.palette(), an.x, an.y, self.view.S, self.view.S)
                    self.term.picture(self.layout.row + y // self.term.ch, self.layout.col + x // self.term.cw, data)
                    self.term.flush()
            an.done_cb()
            self.touch()

    def _anim_frame(self, now):
        an = self.anim
        if isinstance(an, Burst):
            f = an.frames(now, self.palette())
            if f == "end":
                self.finish_anim()
            elif f is not None:
                self.term.picture(self.layout.row + f[1] // self.term.ch, self.layout.col + f[0] // self.term.cw, f[2])
                self.term.flush()
            return
        places, finished = an.positions(now)
        if finished:
            self.finish_anim()
            return
        if places != an.placed:
            six = self._moving_frame(an, places)
            for x, y, data in six:
                self.term.picture(self.layout.row + y // self.term.ch, self.layout.col + x // self.term.cw, data)
            an.placed = places
            an.last = places
            self.term.flush()

    def _moving_frame(self, an, places):
        """One picture: the box round all the men's old and new places (a castling's king and rook)."""
        v = self.view
        S = v.S
        xs = [p[0] for p in places] + [p[0] for p in an.last]
        ys = [p[1] for p in places] + [p[1] for p in an.last]
        x0, y0, x1, y1 = min(xs), min(ys), max(xs) + S, max(ys) + S
        cw, ch = v.cw, v.ch
        fx0, fy0 = x0 // cw * cw, y0 // ch * ch
        fx1, fy1 = min(v.size, -(-x1 // cw) * cw), min(v.size, -(-y1 // ch) * ch)
        part = an.ground.crop(fx0, fy0, fx1 - fx0, fy1 - fy0)
        for (piece, _a, _b), (x, y) in zip(an.parts, places, strict=True):
            part.stamp(v.art.man(piece, v.s), x - fx0, y - fy0)
        return [(fx0, fy0, part.sixel(self.palette()))]

    # ── events ───────────────────────────────────────────────────────────────────────────────
    def on_event(self, ev):
        s = self.screen
        kind = ev[0]
        if kind == "eof":
            self.quit = True
        elif kind == "mood":
            if ev[1] != self.mood:
                self.mood = ev[1]
                self.pic_key = None
                self.face_at = None
                if self.view:
                    self.view.redraw_all()
                self.touch()
        elif kind == "focus":
            self.focused = ev[1]
            if s:
                s.focus(ev[1])
            self.touch()
        elif s is None or self.layout is None or self.layout.small:
            if kind == "key" and ev[1] in ("esc", "ctrl-c", "ctrl-d"):
                self.quit = True
        elif kind == "key":
            self.finish_anim()
            if ev[1] == "ctrl-c":
                self.quit = True
                return
            s.key(ev[1])
            self.touch()
        elif kind == "text":
            self.finish_anim()
            s.text(ev[1])
            self.touch()
        elif kind == "paste":
            s.paste(ev[1])
            self.touch()
        elif kind == "mouse":
            self._mouse(s, ev)

    def _mouse(self, s, ev):
        _, what, btn, x, y = ev
        t, lay = self.term, self.layout
        # (foot's pixels count from the first cell's corner, from 1)
        px, py = max(0, x - 1), max(0, y - 1)
        if what == "wheel":
            if hasattr(s, "wheel"):
                s.wheel(-1 if btn == 0 else 1)
                self.touch()
            return
        if what == "down" and btn == 0:
            self.finish_anim()
            sq = self.view.at(px - lay.col * t.cw, py - lay.row * t.ch)
            if sq is not None:
                s.click(sq)
                self.touch()
                return
            row, col = py // t.ch, px // t.cw
            i = self.rows_at.get(row)
            if i is not None and lay.pc - 1 <= col <= lay.pc + lay.pw:
                s.click_row(i)
                self.touch()
        elif what == "move" and hasattr(s, "hover"):
            row, col = py // t.ch, px // t.cw
            i = self.rows_at.get(row)
            if i is not None and lay.pc - 1 <= col <= lay.pc + lay.pw:
                s.hover(i)
                self.touch()

    def run(self):
        term = self.term
        wake = Wakeups()
        sel = selectors.DefaultSelector()
        sel.register(term.fd_in, selectors.EVENT_READ, "term")
        sel.register(wake.r, selectors.EVENT_READ, "wake")
        engine_fd, engine_gen = None, 0
        term.enter()
        self.relayout()
        try:
            while not self.quit and self.stack and not term.gone:
                if (self.engine.fileno(), self.engine.generation) != (engine_fd, engine_gen):
                    if engine_fd is not None:
                        sel.unregister(engine_fd)
                    engine_fd, engine_gen = self.engine.fileno(), self.engine.generation
                    if engine_fd is not None:
                        sel.register(engine_fd, selectors.EVENT_READ, "engine")
                now = time.monotonic()
                wait = 5.0
                due = None
                if self.anim is None and self.screen:
                    due = self.screen.tick(now)
                if self.dirty:
                    self.render()
                if self.anim is not None:
                    wait = 0.006
                elif due is not None:
                    wait = max(0.0, min(wait, due - now))
                if not self.engine.idle():
                    wait = min(wait, 1.0)
                if term.buf:
                    wait = min(wait, 0.3)
                for key, _ in sel.select(wait):
                    what = key.data
                    if what == "term":
                        for ev in term.read():
                            self.on_event(ev)
                    elif what == "wake":
                        for sig in wake.take():
                            if sig in (signal.SIGTERM, signal.SIGHUP):
                                self.quit = True
                            elif sig == signal.SIGWINCH or sig == signal.SIGCONT:
                                if term.measure() or sig == signal.SIGCONT:
                                    self.relayout()
                    elif what == "engine":
                        self.engine.on_input()
                now = time.monotonic()
                self.engine.tick(now)
                if term.buf:
                    for ev in term.stale():
                        self.on_event(ev)
                if self.anim is not None:
                    self._anim_frame(now)
        finally:
            for s in reversed(self.stack):
                try:
                    s.leave()
                except Exception:
                    self.store.note_crash(traceback.format_exc())
            self.stack.clear()
            self.engine.stop_process()
            term.leave()


def check():
    """--check: what kawa-chess needs, looked at: its files, Stockfish, a legal move from it."""
    bad = []
    for f in ("inks.txt", "pieces.txt"):
        if not os.path.isfile(os.path.join(DATA, f)):
            bad.append(f"no {f} in {DATA}")
    import shutil
    if not shutil.which("stockfish"):
        bad.append("no stockfish on PATH")
    for line in bad:
        print(f"kawa-chess: {line}", file=sys.stderr)
    return 1 if bad else 0


def main(argv):
    if "--check" in argv:
        return check()
    if "--window" in argv:
        return in_window(argv)
    if "-h" in argv or "--help" in argv:
        print(sys.modules["__main__"].__doc__)
        return 0
    if not (os.isatty(0) and os.isatty(1)):
        print("kawa-chess: run it in a terminal (or with --window)", file=sys.stderr)
        return 2
    load_icons(os.path.join(CONFIG, "icons.sh"))
    app = App()
    from home import Home
    app.push(Home())
    try:
        app.run()
    except Exception:
        app.store.note_crash(traceback.format_exc())
        raise
    return 0


def in_window(_argv):
    """A foot window sized to the board at its middle size and the panel beside it."""
    os.execvp("kawa-term", ["kawa-term", "--app", "kawa-chess", "chess", os.path.abspath(sys.argv[0])])


__all__ = ["App", "Screen", "MARGIN", "DATA"]
