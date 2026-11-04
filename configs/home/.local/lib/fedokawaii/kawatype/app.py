"""app.py — kawa-typing's screens: the three tabs (course, practice, progress), a lesson, its result. Text is
foot's own cells in the palette's numbers, so it follows a theme switch by itself; the keyboard and the hands
are pictures (canvas.py) repainted as the theme changes. docs/design-system.md §7 is the grammar of all of it.
"""
import math
import os
import re
import sys
import time

from . import art, canvas, course, keys, metrics, store, term
from .term import Focus, Key, Mood, Mouse, Pasted, Resize

# the palette's numbers (screen.sh): foot holds them for both moods
ACCENT, ON_ACCENT, EDGE, EDGE2, ACCENT_TEXT, MUTED, FAINT, STRONG, SELECT, ON_SELECT = 16, 17, 18, 19, 20, 21, 22, 23, 24, 25
PAPERS = (26, 27, 28, 29)
PAPER_INK = 30
OFF = '\x1b[0m'
DAY_MINUTES = 20
SEAL_ON, SEAL_OFF = '●', '○'
TABS = ('course', 'practice', 'progress')
TAB_ICONS = {'course': 'MORTARBOARD', 'practice': 'KEYCAP', 'progress': 'USAGE'}
STAGE_ICONS = ('KEYBOARD', 'KEYBOARD', 'KEYBOARD', 'NOTE', 'PEN', 'CALC', 'EQUALS', 'CODE', 'LANTERN')
MILESTONES = (50, 75, 90, 100, 120)


def fg(n):
    return f'\x1b[38;5;{n}m'


def bg(n):
    return f'\x1b[48;5;{n}m'


def load_icons():
    path = os.path.join(os.environ.get('XDG_CONFIG_HOME') or os.path.expanduser('~/.config'), 'fedokawaii', 'icons.sh')
    out = {}
    try:
        with open(path, encoding='utf-8', errors='replace') as f:
            for m in re.finditer(r"^ICON_([A-Z_0-9]+)=\$'((?:\\x[0-9a-f]{2})+)'", f.read(), re.M):
                out[m[1]] = bytes.fromhex(m[2].replace('\\x', '')).decode()
    except OSError:
        pass
    return out


def clock(seconds):
    return f'{int(seconds) // 60}:{int(seconds) % 60:02d}'


def seals_text(n):
    gold = n >= 6
    n = min(n, 5)
    return (fg(ACCENT_TEXT if not gold else STRONG) + SEAL_ON * n + fg(EDGE2) + SEAL_OFF * (5 - n) + OFF)


def seals_for(wpm, acc, low, goal):
    """the table of docs/learn/typing/curriculum.md: 0 not passed, 1–5, 6 the gold seal"""
    if acc < 97 or wpm < low:
        return 0
    if wpm >= goal * 1.5 and acc >= 100:
        return 6
    if wpm >= goal:
        return 5 if acc >= 99 else 4
    span = goal - low
    return 3 if wpm >= low + span * 2 / 3 else 2 if wpm >= low + span / 3 else 1


def plain(s):
    return re.sub(r'\x1b\[[0-9;:<=>?]*[A-Za-z]', '', s)


def width(s):
    """cells of a line: our icons are two wide"""
    return sum(2 if 0xf0000 <= ord(c) <= 0xfffff else 1 for c in plain(s))


def wrap(text, w):
    """the text's lines at w columns, at words: [(start, end)], '\\n' ending its line; a word too long is cut"""
    lines = []
    i, n = 0, len(text)
    w = max(w, 4)
    while i < n:
        end = min(i + w, n)
        nl = text.find('\n', i, end + 1)
        if nl >= 0:
            lines.append((i, nl + 1))
            i = nl + 1
            continue
        if end >= n:
            lines.append((i, n))
            break
        sp = text.rfind(' ', i, end + 1)
        if sp > i:
            lines.append((i, sp + 1))
            i = sp + 1
        else:
            lines.append((i, end))
            i = end
    return lines or [(0, 0)]


class App:
    def __init__(self, tty, args):
        self.t = tty
        self.args = args
        self.store = store.Store()
        self.icons = load_icons()
        self.dark = self._read_mood()
        self.releases = False            # (the terminal tells releases: rollover, anchors)
        self.focused = True
        self.screen = None
        self.size = (80, 24, 8, 20)
        self.seed = args.get('seed')
        self.attempt = 0
        self.alive = True

    def icon(self, name):
        return self.icons.get(name, '·')

    @staticmethod
    def _read_mood():
        path = os.path.join(os.environ.get('XDG_CONFIG_HOME') or os.path.expanduser('~/.config'), 'fedokawaii', 'current', 'colors.sh')
        try:
            with open(path) as f:
                return 'THEME=light' not in f.read(200)
        except OSError:
            return True

    def rng(self):
        self.attempt += 1
        return course.fresh(None if self.seed is None else self.seed + self.attempt)

    # ── the loop ─────────────────────────────────────────────────────────────
    def run(self, first):
        self.t.start()
        self.size = self.t.size()
        self.go(first)
        while self.alive:
            timeout = self.screen.wait()
            for ev in self.t.read(timeout):
                self.event(ev)
                if not self.alive:
                    break
            self.screen.tick(time.monotonic())
            self.t.flush()

    def go(self, screen):
        self.screen = screen
        self.t.write('\x1b[0m\x1b[2J')
        self.t.mouse_on(screen.wants_mouse)
        screen.layout()
        screen.draw()
        self.t.flush()

    def event(self, ev):
        if isinstance(ev, Resize):
            self.size = self.t.size()
            self.t.write('\x1b[0m\x1b[2J')
            self.screen.layout()
            self.screen.draw()
        elif isinstance(ev, Mood):
            if ev.dark != self.dark:
                self.dark = ev.dark
                self.screen.remood()
        elif isinstance(ev, Focus):
            self.focused = ev.on
            self.screen.focus(ev.on)
        elif isinstance(ev, Key):
            if ev.kind == 'release':
                self.releases = True
            self.screen.key(ev)
        elif isinstance(ev, Mouse):
            self.screen.mouse(ev)
        elif isinstance(ev, Pasted):
            self.screen.pasted()

    def quit(self):
        self.alive = False
        self.store.save()


class Screen:
    wants_mouse = False

    def __init__(self, app):
        self.app = app
        self.t = app.t

    def wait(self):
        return None

    def tick(self, now):
        pass

    def layout(self):
        pass

    def draw(self):
        pass

    def remood(self):
        self.t.write('\x1b[2J')
        self.layout()
        self.draw()

    def focus(self, on):
        pass

    def key(self, ev):
        pass

    def mouse(self, ev):
        pass

    def pasted(self):
        pass

    # the grammar's parts ------------------------------------------------------
    def at(self, row, col, s=''):
        """row and col from 0"""
        self.t.write(f'\x1b[{row + 1};{col + 1}H{s}')

    def heading(self, row, icon, name, x0, w, tail='', done=None):
        """a heading (§7): the icon, two columns, the name, the rule to the last column; done: how much of
        the rule is burnt, 0–1 (a lesson's progress); tail: words at the rule's right end"""
        s = fg(ACCENT_TEXT) + icon + OFF + '  ' + fg(STRONG) + name + OFF + ' '
        used = width(s)
        room = w - used
        tail_w = width(tail)
        if tail and room >= tail_w + 8:
            room -= tail_w + 1
        else:
            tail = ''
        room = max(room, 0)
        burnt = 0 if done is None else round(room * max(min(done, 1), 0))
        s += fg(ACCENT_TEXT) + '─' * burnt + fg(EDGE2) + '─' * (room - burnt) + OFF
        if tail:
            s += ' ' + tail + OFF
        self.at(row, x0, s)


# ── the tabs ─────────────────────────────────────────────────────────────────
class Row:
    __slots__ = ('icon', 'name', 'value', 'act', 'tell', 'plainvalue')

    def __init__(self, icon, name, value='', act=None, tell=None):
        self.icon, self.name, self.value, self.act, self.tell = icon, name, value, act, tell


class Home(Screen):
    wants_mouse = True

    def __init__(self, app, tab='course', stage=None):
        super().__init__(app)
        self.tab = tab
        self.stage = stage         # a stage opened: its lessons
        self.cursor = 0
        self.top = 0
        self.rows = []
        self.pic = None
        self.kb = None
        self.pic_at = (0, 0)
        self.history = app.store.history()

    # ── what each tab lists ──────────────────────────────────────────────────
    def build(self):
        if self.tab == 'course':
            self.rows = self.stage_rows() if self.stage is not None else self.course_rows()
        elif self.tab == 'practice':
            self.rows = self.practice_rows()
        else:
            self.rows = []
        self.cursor = min(self.cursor, max(len(self.rows) - 1, 0))

    def lessons_done(self, stage=None):
        have = self.app.store.progress['lessons']
        return sum(1 for l in course.LESSONS if (stage is None or l.stage == stage) and l.id in have and (have[l.id]['seals'] >= 1 or not l.goal))

    def next_lesson(self):
        have = self.app.store.progress['lessons']
        for i, l in enumerate(course.LESSONS):
            d = have.get(l.id)
            if not d or (l.goal and d['seals'] < 1):
                return i
        return None

    def course_rows(self):
        out = []
        n = self.next_lesson()
        total = len(course.LESSONS)
        if n is not None:
            l = course.LESSONS[n]
            out.append(Row(self.app.icon('CHEVRON_RIGHT'), l.title, f'{n + 1} of {total}', lambda: self.start_lesson(n), ('next', l)))
        counts = course.stage_counts()
        for s, name in enumerate(course.STAGE_NAMES):
            done = self.lessons_done(s)
            value = fg(MUTED) + (f'{done} of {counts[s]}' if done < counts[s] else '') + OFF if done < counts[s] else fg(ACCENT_TEXT) + '✓' + OFF
            if not done:
                value = fg(FAINT) + str(counts[s]) + OFF
            out.append(Row(self.app.icon(STAGE_ICONS[s]), name, value, lambda s=s: self.open_stage(s), ('stage', s)))
        return out

    def stage_rows(self):
        have = self.app.store.progress['lessons']
        out = []
        for i, l in enumerate(course.LESSONS):
            if l.stage == self.stage:
                d = have.get(l.id)
                if not l.goal:
                    v = fg(ACCENT_TEXT) + '✓' + OFF if d else ''
                else:
                    v = seals_text(d['seals']) if d else fg(EDGE2) + SEAL_OFF * 5 + OFF
                out.append(Row(self.app.icon({'meet': 'KEYCAP', 'check': 'HOURGLASS', 'passage': 'BOOK', 'code': 'CODE'}.get(l.kind, 'KEYBOARD')), l.title, v,
                               lambda i=i: self.start_lesson(i), ('lesson', l)))
        return out

    def practice_rows(self):
        a = self.app
        out = [Row(a.icon('KEYBOARD'), 'your weakest keys', act=lambda: self.start_free('weak'), tell=('free', 'the letters you are slowest and least sure on, in words.')),
               Row(a.icon('NOTE'), 'plain words', act=lambda: self.start_free('words'), tell=('free', 'the 200 commonest words, drawn at random.')),
               Row(a.icon('BOOK'), 'a passage', act=lambda: self.start_free('passage'), tell=('free', 'Okakura, Hearn or Nitobe, as printed.'))]
        for lang in ('bash', 'git', 'python', 'rust', 'c'):
            out.append(Row(a.icon('CODE'), lang, act=lambda lang=lang: self.start_free('code', lang), tell=('free', f'real {lang}. a line\'s indent is the editor\'s work.')))
        for secs in (15, 30, 60):
            out.append(Row(a.icon('HOURGLASS'), f'test, {secs} seconds', act=lambda secs=secs: self.start_free('test', secs),
                           tell=('free', 'plain words, flowing, measured as Monkeytype measures.')))
        return out

    def open_stage(self, s):
        self.stage = s
        self.cursor = 0
        self.top = 0
        have = self.app.store.progress['lessons']
        for i, l in enumerate(x for x in course.LESSONS if x.stage == s):
            if l.id not in have:
                self.cursor = i
                break
        self.layout()
        self.t.write('\x1b[2J')
        self.draw()

    def start_lesson(self, i):
        self.app.go(LessonScreen(self.app, i))

    def start_free(self, what, arg=None):
        self.app.go(LessonScreen.free(self.app, what, arg))

    # ── its place on the screen ──────────────────────────────────────────────
    def layout(self):
        self.build()
        cols, rows, cw, ch = self.app.size
        self.x0 = 2
        self.W = max(cols - 4, 1)
        self.first = 4                          # (a row of air, the tabs, their line, a row of air)
        self.visible = max(rows - self.first - 1, 1)
        self.pane = self.tab == 'course' and cols >= 92
        self.list_w = min(47, self.W) if self.pane else self.W
        self.pic = None
        pane_x = self.x0 + self.list_w + 2
        pane_w = cols - pane_x - 2
        self.pane_x, self.pane_w = pane_x, pane_w
        if self.tab == 'course' and self.pane and pane_w * cw >= art.KEY_W and rows >= self.first + 8:
            self.pic = canvas.Picture(art.KEY_W, art.KEY_H, (cw, ch))
            self.kb = art.Keyboard(self.app.dark)
            self.pic_at = (self.first + 5, pane_x)
        if self.tab == 'progress':
            self.progress_layout()

    # ── drawing ──────────────────────────────────────────────────────────────
    def draw_tabs(self):
        x = self.x0
        s = ''
        under = None
        for name in TABS:
            icon = self.app.icon(TAB_ICONS[name])
            if name == self.tab:
                s += fg(ACCENT_TEXT) + icon + OFF + '  ' + fg(STRONG) + name + OFF + '   '
                under = (x + 4, len(name))
                x += 4 + len(name) + 3
            else:
                s += fg(MUTED) + icon + OFF + '   '
                x += 2 + 3
        self.tab_spans = []
        self.at(1, self.x0, s)
        if under:
            self.at(2, under[0], fg(ACCENT) + '▔' * under[1] + OFF)
        xx = self.x0
        for name in TABS:
            w = 4 + len(name) if name == self.tab else 2
            self.tab_spans.append((xx, xx + w, name))
            xx += w + 3

    def draw_row(self, i):
        row = self.first + i - self.top
        if not 0 <= i - self.top < self.visible or i >= len(self.rows):
            return
        r = self.rows[i]
        on = i == self.cursor
        w = self.list_w
        name = r.name
        value = r.value
        vw = width(value)
        room = w - 4 - (vw + 2 if vw else 0)
        if len(name) > room:           # (never "…": cut at a word)
            cut = name[:max(room, 0) + 1].rsplit(' ', 1)[0] if ' ' in name[:max(room, 0) + 1] else name[:max(room, 0)]
            name = cut[:max(room, 0)]
        pad = w - 4 - len(name) - vw
        icon = r.icon
        if on:
            s = bg(SELECT) + fg(ON_SELECT) + '  ' + icon + '  ' + name + ' ' * max(pad, 0) + plain(value) + ' ' + OFF
            self.at(row, self.x0 - 1, s)
        else:
            s = '  ' + fg(MUTED) + icon + OFF + '  ' + name + ' ' * max(pad, 0) + value + OFF + ' '
            self.at(row, self.x0 - 1, s)

    def draw_list(self):
        if self.cursor < self.top:
            self.top = self.cursor
        if self.cursor >= self.top + self.visible:
            self.top = self.cursor - self.visible + 1
        for i in range(self.top, min(self.top + self.visible, len(self.rows))):
            self.draw_row(i)

    def draw_pane(self):
        if not self.pane:
            return
        rows = self.app.size[1]
        for r in range(1, rows - 1):
            self.at(r, self.pane_x, '\x1b[K')
        x = self.pane_x
        w = self.pane_w
        tell = self.rows[self.cursor].tell if self.rows else None
        store_ = self.app.store
        minutes = store_.minutes_today()
        today = f'{int(minutes)} of {DAY_MINUTES} min' if minutes < DAY_MINUTES else 'enough for today'
        lit = {}
        if tell and tell[0] in ('next', 'lesson'):
            l = tell[1]
            self.heading(1, self.app.icon('KEYCAP'), 'today', x, w, fg(MUTED) + today + OFF)
            self.at(self.first, x, l.title)
            line = ''
            if l.goal:
                line = fg(MUTED) + f'goal {l.goal} wpm, 97 % or more' + OFF
            elif l.kind == 'meet':
                line = fg(MUTED) + 'no score: just the fingers' + OFF
            self.at(self.first + 1, x, line)
            d = store_.progress['lessons'].get(l.id)
            if d and l.goal:
                self.at(self.first + 2, x, fg(MUTED) + f'best {d["best"]:.0f} wpm' + OFF)
            for c in l.keys or '':
                for name, f in keys.needs(c):
                    lit[name] = f
        elif tell and tell[0] == 'stage':
            s = tell[1]
            self.heading(1, self.app.icon('KEYCAP'), 'today', x, w, fg(MUTED) + today + OFF)
            done = self.lessons_done(s)
            n = course.stage_counts()[s]
            self.at(self.first, x, course.STAGE_NAMES[s])
            self.at(self.first + 1, x, fg(MUTED) + f'{done} of {n} lessons' + OFF)
            for l in course.LESSONS:
                if l.stage == s:
                    for c in l.keys or '':
                        for name, f in keys.needs(c):
                            lit.setdefault(name, f)
        if self.pic and self.kb:
            self.kb.dark = self.app.dark
            self.kb.lit = lit
            self.pic.clear()
            self.kb.paint(self.pic, 1)
            self.pic.touch_all()
            self.t.write(self.pic.send(self.pic_at[1] + 1, self.pic_at[0] + 1, art.PALETTE[self.app.dark]))

    def draw(self):
        self.t.write('\x1b[?25l')
        self.draw_tabs()
        if self.tab == 'progress':
            self.draw_progress()
            return
        self.draw_list()
        self.draw_pane()
        if self.app.store.failed:
            self.at(self.app.size[1] - 1, self.x0, fg(ACCENT_TEXT) + self.app.icon('CROSS') + OFF + '  the disk would not take your progress')

    def move(self, to):
        if not self.rows:
            return
        to = max(0, min(to, len(self.rows) - 1))
        if to == self.cursor:
            return
        old = self.cursor
        self.cursor = to
        if self.cursor < self.top or self.cursor >= self.top + self.visible:
            self.draw_list()
        else:
            self.draw_row(old)
            self.draw_row(to)
        self.draw_pane()

    def switch(self, tab):
        self.tab, self.stage, self.cursor, self.top = tab, None, 0, 0
        self.t.write('\x1b[2J')
        self.layout()
        self.draw()

    # ── input ────────────────────────────────────────────────────────────────
    def key(self, ev):
        if ev.kind == 'release':
            return
        n = ev.name
        ctrl = ev.mods & term.CTRL
        if ctrl and n == 'c':
            self.app.quit()
            return
        if ev.mods & (term.SUPER | term.ALT) or (ctrl and n not in ('tab',)):
            return
        if n == 'tab' or n == 'right' or n == 'left':
            back = n == 'left' or (n == 'tab' and ev.mods & term.SHIFT)
            i = TABS.index(self.tab) + (-1 if back else 1)
            self.switch(TABS[i % len(TABS)])
        elif n in ('down', 'j'):
            self.move(self.cursor + 1)
        elif n in ('up', 'k'):
            self.move(self.cursor - 1)
        elif n in ('pagedown',):
            self.move(self.cursor + self.visible)
        elif n in ('pageup',):
            self.move(self.cursor - self.visible)
        elif n == 'home':
            self.move(0)
        elif n == 'end':
            self.move(len(self.rows) - 1)
        elif n == 'enter':
            if self.rows and self.rows[self.cursor].act:
                self.rows[self.cursor].act()
        elif n == 'escape' or n == 'q':
            if self.stage is not None:
                self.stage = None
                self.cursor = 0
                self.top = 0
                self.t.write('\x1b[2J')
                self.layout()
                self.draw()
            elif n == 'escape' or n == 'q':
                self.app.quit()

    def mouse(self, ev):
        col, row = ev.col - 1, ev.row - 1
        if ev.kind == 'wheel':
            self.move(self.cursor + ev.button)
            return
        if row == 1 and ev.kind == 'press':
            for a, b, name in getattr(self, 'tab_spans', ()):
                if a <= col < b:
                    if name != self.tab:
                        self.switch(name)
                    return
        i = row - self.first + self.top
        inside = self.first <= row < self.first + self.visible and 0 <= i < len(self.rows) and col < self.x0 + self.list_w + 1
        if ev.kind == 'move' and inside:
            self.move(i)
        elif ev.kind == 'press' and inside and ev.button == 0:
            self.move(i)
            if self.rows[i].act:
                self.rows[i].act()

    def remood(self):
        self.t.write('\x1b[2J')
        self.layout()
        self.draw()

    # ── the progress tab ─────────────────────────────────────────────────────
    def progress_layout(self):
        cols, rows, cw, ch = self.app.size
        self.chart = None
        self.kb_pic = None
        self.cal = None
        w = (cols - 4) * cw
        self.chart_rows = 8
        if rows >= 18:
            self.chart = canvas.Picture(min(w, 900) // cw * cw, self.chart_rows * ch, (cw, ch))
        room = rows - 4 - (self.chart_rows + 2 if self.chart else 0) - 7
        if room >= 5 and w >= 300:
            self.kb_pic = canvas.Picture(art.KEY_W, art.KEY_H, (cw, ch))

    def draw_progress(self):
        st = self.app.store
        h = self.history
        x, W = self.x0, self.W
        tests = [r for r in h if r.get('k') in ('test', 'check', 'baseline')]
        row = 4
        cols, rows, cw, ch = self.app.size
        best = max((r['w'] for r in tests), default=None)
        last = tests[-1] if tests else None
        base = st.progress['baseline']
        days = len({time.strftime('%Y-%m-%d', time.localtime(r['d'])) for r in h})
        total = sum(r.get('s', 0) for r in h)
        done = self.lessons_done()
        facts = [('lessons', f'{done} of {len(course.LESSONS)}'),
                 ('today', f'{int(st.minutes_today())} of {DAY_MINUTES} min'),
                 ('days', str(days)),
                 ('in all', f'{int(total // 3600)} h {int(total % 3600 // 60)} min'),
                 ('last test', f'{last["w"]:.0f} wpm, {last["a"]:.1f} %' if last else 'none yet'),
                 ('best test', f'{best:.0f} wpm' if best is not None else 'none yet'),
                 ('your old way', f'{base:.0f} wpm' if base else 'not measured')]
        if base and best is not None and tests:
            passed = any(r['w'] > base and r.get('k') != 'baseline' for r in tests)
            facts[-1] = ('your old way', f'{base:.0f} wpm' + (': passed' if passed else ''))
        pad = max(len(k) for k, _ in facts)
        for k, v in facts[:max(rows - 5, 0)]:
            self.at(row, x + 3, fg(MUTED) + k.ljust(pad + 2) + OFF + v)
            row += 1
        row += 1
        if self.chart and row + self.chart_rows < rows:
            self.paint_chart(tests, base)
            self.t.write(self.chart.send(x + 1, row + 1, art.PALETTE[self.app.dark]))
            row += self.chart_rows + 1
        if self.kb_pic and row + 5 < rows:
            kb = art.Keyboard(self.app.dark)
            weak = course.weakness(st.keys['keys'])
            for name, c in ((keys.CHARS[c][0], w) for c, w in weak.items() if c in keys.CHARS):
                if c > 1.35:
                    kb.heat[name] = art.INK['accent']
                elif c > 1.1:
                    kb.heat[name] = art.INK['flame']
                else:
                    kb.heat[name] = art.INK['asagi']
            kb.paint(self.kb_pic, 1)
            self.t.write(self.kb_pic.send(x + 1, row + 1, art.PALETTE[self.app.dark]))

    def paint_chart(self, tests, base):
        p = self.chart
        p.clear()
        ink = art.INK
        wpms = [r['w'] for r in tests][-200:]
        top = max([110] + wpms) * 1.05
        H, Wd = p.h - 2, p.w - 2

        def y(v):
            return H - int(v / top * H)
        # the guide lines: the milestones, a row of dots each
        for m in MILESTONES:
            if m <= top:
                for xx in range(0, Wd, 6):
                    p.fill(xx, y(m), 1, 1, ink['edge2'])
        if base:
            for xx in range(0, Wd, 3):
                p.fill(xx, y(base), 1, 1, ink['muted'])
        if wpms:
            step = Wd / max(len(wpms) - 1, 1)
            prev = None
            for i, v in enumerate(wpms):
                xx, yy = int(i * step), y(v)
                if prev:
                    x0, y0 = prev
                    dx, dy = xx - x0, yy - y0
                    n = max(abs(dx), abs(dy), 1)
                    for t in range(n + 1):
                        p.fill(x0 + dx * t // n, y0 + dy * t // n, 2, 2, ink['asagi'])
                prev = (xx, yy)
            p.fill(prev[0] - 2, prev[1] - 2, 5, 5, ink['accent'])


# ── a lesson ─────────────────────────────────────────────────────────────────
class LessonScreen(Screen):
    wants_mouse = False

    def __init__(self, app, index=None, *, lesson=None, text=None, resume=None, seed_next=True):
        super().__init__(app)
        self.index = index
        self.lesson = lesson if lesson is not None else course.LESSONS[index]
        l = self.lesson
        st = app.store
        if resume is not None:
            self.run = resume
        else:
            body = text if text is not None else course.text_for(l, app.rng(), st.keys['keys'])
            self.run = metrics.Run(body, l.flow, l.limit)
        self.held = {}             # keys down now → when
        self.prev_key = None
        self.notice = ''
        self.notice_until = 0.0
        self.wrong_until = 0.0
        self.thumb = 5
        self.last_finger = 3
        self.saved_at = 0.0
        self.finished = False
        self.saved_text = False
        self.pacer_cell = None
        self.eye_next = 0.0
        self.eye = None
        self.dimmed = False
        self.drawn_line = -1
        self.spans = []
        self.kb = self.hands = self.pic = None
        self.lit_now = {}
        self.save_resume()

    @classmethod
    def free(cls, app, what, arg=None):
        """from the practice tab: no lesson's seals, measured all the same"""
        rng = app.rng()
        st = app.store
        limit = None
        kind = what
        known = 'abcdefghijklmnopqrstuvwxyz'
        title = {'weak': 'your weakest keys', 'words': 'plain words', 'passage': 'a passage'}.get(what, what)
        if what == 'weak':
            text = ' '.join(course.pick_words(known, rng, '', 60, course.weakness(st.keys['keys'])))
        elif what == 'words':
            top = course.words()[:200]
            text = course.fill(top, 300, rng)
        elif what == 'passage':
            text = course.passages()[rng.randrange(len(course.passages()))]
        elif what == 'code':
            blocks = course.code_blocks()[arg]
            start = rng.randrange(len(blocks))
            text = '\n'.join(blocks[(start + i) % len(blocks)] for i in range(3))
            title = arg
        elif what == 'test':
            limit = arg
            top = course.words()[:300]
            text = course.fill(top, arg * 30 + 100, rng)
            title = f'test, {arg} seconds'
        elif what == 'baseline':
            limit = 60
            top = course.words()[:200]
            text = course.fill(top, 1500, rng)
            title = 'one minute, the way you type now'
        else:          # a file of your own
            text = arg
            title = what
        lesson = course.Lesson(f'free.{what}', 8, kind, title, '', '', 0, 0, True, len(text), limit, None)
        return cls(app, None, lesson=lesson, text=text)

    # ── its place on the screen ──────────────────────────────────────────────
    def layout(self):
        cols, rows, cw, ch = self.app.size
        self.cols, self.rows_n = cols, rows
        x0, W = 2, max(cols - 4, 1)
        self.x0, self.W = x0, W
        self.scale = 0
        self.show_hands = False
        top = 3                                 # (air, the heading, air)
        for s in (3, 2, 1):
            kw = math.ceil(art.KEY_W * s / cw)
            kh = math.ceil(art.KEY_H * s / ch)
            hh = math.ceil((art.HANDS_H + 4) * s / ch)
            if kw <= W and top + 5 + 1 + kh + hh + 1 <= rows:
                self.scale, self.show_hands = s, True
                break
        if not self.scale and rows >= top + 3 + 1 + math.ceil(art.KEY_H / ch) + 1 and art.KEY_W <= W * cw:
            self.scale = 1
        self.tw = min(W, 72)
        lines = 3
        spaced = 2
        if self.scale:
            s = self.scale
            kw = math.ceil(art.KEY_W * s / cw)
            kh = math.ceil(art.KEY_H * s / ch)
            hh = math.ceil((art.HANDS_H + 4) * s / ch) if self.show_hands else 0
            self.tw = min(W, max(kw, 60), 96)
            if top + 5 + 1 + kh + hh + 1 > rows:
                spaced = 1
            block = (lines - 1) * spaced + 1 + 1 + kh + hh
        else:
            kh = hh = 0
            room = rows - top - 1
            lines = max(min(room, 3), 1)
            spaced = 1
            block = lines
        self.lines_n, self.spaced = lines, spaced
        free = max(rows - top - 1 - block, 0)
        y = top + free // 3
        self.text_y = y
        self.notice_y = y + (lines - 1) * spaced + 1
        self.text_x = x0 + (W - self.tw) // 2
        self.spans = wrap(self.run.text, self.tw)
        self.drawn_line = -1
        self.pic = None
        if self.scale:
            s = self.scale
            pw = art.KEY_W * s
            ph = (art.KEY_H + (art.HANDS_H + 4 if self.show_hands else 0)) * s
            self.pic = canvas.Picture(pw, ph, (cw, ch))
            kw = math.ceil(pw / cw)
            self.pic_x = x0 + (W - kw) // 2
            self.pic_y = self.notice_y + 1
            self.kb = art.Keyboard(self.app.dark)
            self.hands = art.Hands(self.app.dark) if self.show_hands else None
            self.lit_now = {}
            self.apply_keys()

    def line_of(self, pos):
        lo, hi = 0, len(self.spans) - 1
        while lo < hi:
            mid = (lo + hi) // 2
            if pos >= self.spans[mid][1]:
                lo = mid + 1
            else:
                hi = mid
        return lo

    # ── the words ────────────────────────────────────────────────────────────
    def cell(self, i):
        """the character at position i, as it stands now"""
        r = self.run
        c = r.text[i]
        shown = '↵' if c == '\n' else c
        if i < r.pos:
            got = r.got.get(i)
            if got is None or got == c:
                return fg(FAINT) + shown
            return bg(ACCENT) + fg(ON_ACCENT) + ('·' if got == ' ' or c == ' ' else shown)
        if c == '\n':
            return fg(FAINT) + shown
        return shown

    def draw_line(self, row, a, b):
        s = []
        for i in range(a, b):
            s.append(OFF + self.cell(i))
        self.at(row, self.text_x, '\x1b[0m' + ' ' * self.tw)
        self.at(row, self.text_x, ''.join(s) + OFF)

    def draw_text(self, force=False):
        r = self.run
        pos = min(r.pos, len(r.text) - 1)
        line = self.line_of(pos)
        if line != self.drawn_line or force:
            self.drawn_line = line
            for k in range(self.lines_n):
                row = self.text_y + k * self.spaced
                if row >= self.rows_n:
                    break
                if line + k < len(self.spans):
                    self.draw_line(row, *self.spans[line + k])
                else:
                    self.at(row, self.text_x, '\x1b[0m' + ' ' * self.tw)
        self.caret()

    def place_of(self, pos):
        line = self.line_of(pos)
        k = line - self.drawn_line
        if not 0 <= k < self.lines_n:
            return None
        return self.text_y + k * self.spaced, self.text_x + pos - self.spans[line][0]

    def redraw_cell(self, i):
        p = self.place_of(i)
        if p:
            self.at(p[0], p[1], self.cell(i) + OFF)

    def caret(self):
        p = self.place_of(min(self.run.pos, len(self.run.text) - 1))
        if p:
            self.t.write(f'\x1b[{p[0] + 1};{p[1] + 1}H\x1b[?25h')

    # ── the keyboard and the hands ───────────────────────────────────────────
    def wanted(self):
        """the keys the next character takes: [(key, finger)]"""
        r = self.run
        if r.done:
            return []
        c = r.text[r.pos]
        return keys.needs(c, self.thumb)

    def apply_keys(self):
        """the keyboard's lights and the hands' pose, as the next key and the held ones want them"""
        if not self.pic:
            return
        kb, hands = self.kb, self.hands
        quiet = self.app.store.progress['quiet']
        want = [] if quiet else self.wanted()
        lit = dict(want)
        shift = any(k in self.held for k in ('lshift', 'rshift'))
        if want and len(want) == 2:
            shift = True                         # (the legends a shifted key would show)
        changed = set(lit) ^ set(kb.lit) | {k for k in lit if kb.lit.get(k) != lit[k]}
        new_down = {k for k in self.held if k in keys.PLACE}
        changed |= new_down ^ kb.down
        new_wrong = kb.wrong
        if shift != kb.shift:
            kb.shift = shift
            changed |= {name for name, p in keys.PLACE.items() if p[4] != p[5]}
        kb.lit, kb.down = lit, new_down
        first = not any(any(r) for r in self.pic.rows[:self.scale])
        if first:
            kb.paint(self.pic, self.scale)
        else:
            for name in changed | new_wrong:
                kb.paint_key(self.pic, name, self.scale)
        if hands:
            pose = {}
            lit_f = set()
            for name, f in want:
                lit_f.add(f)
                home = keys.HOME.get(f)
                if home and name != home:
                    hx, hy = keys.centre(home)
                    kx, ky = keys.centre(name)
                    across = (kx - hx) // 2
                    up = (hy - ky) // 3 + 3
                    pose[f] = (across, up)
                else:
                    pose[f] = (0, 3)
            pressed = {keys.PLACE[k][3] if k != 'space' else self.thumb for k in new_down if k in keys.PLACE}
            wrong_f = {keys.PLACE[k][3] for k in kb.wrong if k in keys.PLACE}
            state = (dict(pose), set(lit_f), set(pressed), set(wrong_f))
            if state != getattr(self, 'hand_state', None) or first:
                self.hand_state = state
                hands.pose, hands.lit, hands.pressed, hands.wrong = pose, lit_f, pressed, wrong_f
                hands.paint(self.pic, self.scale, 0, (art.KEY_H + 4) * self.scale)
        self.t.write(self.pic.send(self.pic_x + 1, self.pic_y + 1, art.PALETTE[self.app.dark]))

    # ── drawing ──────────────────────────────────────────────────────────────
    def stats(self, now=None):
        r = self.run
        if r.correct + r.wrong == 0 or not (self.lesson.goal or self.lesson.limit or self.lesson.kind):
            return ''
        wpm, acc = r.net(now), r.accuracy()
        s = fg(MUTED) + f'{wpm:.0f} wpm  {acc:.0f} %' + OFF
        if r.limit:
            left = max(r.limit - r.active(now), 0)
            s = fg(STRONG) + clock(math.ceil(left)) + OFF + '  ' + s
        return s

    def draw_heading(self, now=None):
        r = self.run
        if r.limit:
            done = r.active(now) / r.limit
        else:
            done = r.pos / max(len(r.text), 1)
        self.at(1, 0, '\x1b[K')
        self.heading(1, self.app.icon('KEYBOARD'), self.lesson.title, self.x0, self.W, self.stats(now), done)

    def draw_notice(self):
        if self.notice_y >= self.rows_n:
            return
        self.at(self.notice_y, self.text_x, '\x1b[0m' + ' ' * self.tw)
        if self.notice:
            self.at(self.notice_y, self.text_x, fg(ACCENT_TEXT) + self.app.icon('CROSS') + OFF + '  ' + self.notice[:max(self.tw - 3, 0)])

    def say(self, words, now, secs=2.0):
        if words != self.notice:
            self.notice = words
            self.draw_notice()
        self.notice_until = now + secs

    def draw(self):
        self.draw_heading()
        self.draw_notice()
        if self.pic:
            self.pic.touch_all()
            first = not any(any(r) for r in self.pic.rows[:self.scale])
            if first:
                self.apply_keys()
            else:
                self.t.write(self.pic.send(self.pic_x + 1, self.pic_y + 1, art.PALETTE[self.app.dark]))
        self.drawn_line = -1
        self.draw_text()

    def remood(self):
        self.t.write('\x1b[2J')
        self.layout()
        self.draw()

    # ── time ─────────────────────────────────────────────────────────────────
    def wait(self):
        if self.run.limit and self.run.first is not None:
            return 0.25
        if self.notice or self.wrong_until:
            return 0.1
        if self.lesson.kind == 'pacer' and self.run.first is not None:
            return 0.08
        return None

    def tick(self, now):
        if self.finished:
            return
        if self.notice and now >= self.notice_until:
            self.notice = ''
            self.draw_notice()
            self.caret()
        if self.wrong_until and now >= self.wrong_until:
            self.wrong_until = 0.0
            if self.kb and self.kb.wrong:
                wrong, self.kb.wrong = self.kb.wrong, set()
                for name in wrong:
                    self.held.pop(name, None) if not self.app.releases else None
                self.apply_after(wrong)
        r = self.run
        if r.limit and r.first is not None:
            self.draw_heading(now)
            self.caret()
            if r.expired(now):
                self.finish(now)
                return
        if self.lesson.kind == 'pacer' and r.first is not None:
            self.draw_pacer(now)

    def apply_after(self, names):
        if self.pic:
            for name in names:
                if name in keys.PLACE:
                    self.kb.paint_key(self.pic, name, self.scale)
            self.apply_keys()
            self.caret()

    def draw_pacer(self, now):
        goal = self.lesson.goal or 40
        at = min(int(goal * 5 / 60 * self.run.active(now)), len(self.run.text) - 1)
        if at == self.pacer_cell:
            return
        old, self.pacer_cell = self.pacer_cell, at
        if old is not None and self.place_of(old):
            self.redraw_cell(old)
        p = self.place_of(at)
        if p and at >= self.run.pos:
            c = self.run.text[at]
            self.at(p[0], p[1], bg(EDGE2) + ('↵' if c == '\n' else c) + OFF)
        self.caret()

    def focus(self, on):
        if not on:
            self.run.pause()
            self.held.clear()
            if self.kb:
                self.kb.wrong = set()
            self.apply_keys()
            self.caret()
            self.save_resume()

    # ── input ────────────────────────────────────────────────────────────────
    def key(self, ev):
        now = ev.t
        name = ev.name
        if ev.kind == 'release':
            self.held.pop(name, None)
            self.app.releases = True
            self.run.releases = True
            if self.kb and name in self.kb.wrong:
                self.kb.wrong.discard(name)
                self.apply_after({name})
            elif self.pic:
                self.apply_keys()
                self.caret()
            return
        if ev.mods & (term.CTRL | term.ALT | term.SUPER) and name not in ('lctrl', 'rctrl', 'lalt', 'ralt', 'lsuper', 'rsuper'):
            if ev.mods & term.CTRL and name == 'c':
                self.leave()
                self.app.quit()
            return
        if name == 'escape':
            self.leave()
            self.app.go(Home(self.app))
            return
        if ev.kind == 'repeat':
            if name == 'backspace' and self.run.flow:
                self.erase()
            return
        if name in ('lshift', 'rshift', 'lctrl', 'rctrl', 'lalt', 'ralt', 'lsuper', 'rsuper', 'caps'):
            self.held[name] = now
            if self.pic:
                self.apply_keys()
                self.caret()
            return
        if name in ('up', 'down', 'left', 'right', 'home', 'end', 'pageup', 'pagedown', 'insert', 'delete', 'other'):
            return
        if name == 'backspace':
            self.erase()
            return
        if name == 'tab':
            return
        anchor = self.lesson.extra if self.lesson.kind == 'anchor' else None
        if anchor and self.app.releases:
            if name == anchor:
                self.held[name] = now
                self.apply_keys()
                self.caret()
                return
            if anchor not in self.held:
                self.say(f'hold {anchor} down with the other hand', now)
                self.caret()
                return
        ch = '\n' if name == 'enter' else ev.text
        if not ch:
            return
        if len(ch) > 1:
            ch = ch[0]
        if ev.mods & term.CAPS:
            self.say('caps lock is on', now)
            self.caret()
            return
        if not ch.isascii():
            self.say('the keyboard is not in english', now)
            self.caret()
            return
        self.typed(ch, name, now, ev)

    def typed(self, ch, name, now, ev):
        r = self.run
        rolled = bool(self.prev_key) and self.prev_key in self.held
        before = r.pos
        ok = r.press(ch, now, rolled)
        self.prev_key = name
        self.held[name] = now
        need = keys.needs(ch)
        if ok and len(need) == 2:
            want_shift = need[1][0]
            if want_shift not in self.held and any(s in self.held for s in ('lshift', 'rshift')):
                r.shift_slips += 1
                hand = 'right' if want_shift == 'rshift' else 'left'
                self.say(f'the {hand} shift for that one', now)
        if ok:
            f = keys.PLACE[name][3] if name in keys.PLACE else None
            if f is not None and f != 5:
                self.last_finger = f
                self.thumb = 5 if f < 5 else 4
        if r.flow:
            self.redraw_cell(before)
        elif ok:
            self.redraw_cell(before)
        if ok is False and self.kb is not None and name in keys.PLACE:
            self.kb.wrong = self.kb.wrong | {name}
            self.wrong_until = now + 0.18
        if not self.app.releases:
            self.held.pop(name, None)
        if not self.run.limit:
            self.draw_heading(now)
        elif not ok:
            self.draw_heading(now)
        if r.flow and not r.done and r.pos < len(r.text) and r.text[r.pos - 1:r.pos] == '\n':
            r.skip_indent()
        if r.done or (r.limit and r.expired(now)):
            self.finish(now)
            return
        self.draw_text()
        if self.pic:
            self.apply_keys()
        self.caret()
        if now - self.saved_at > 2.0 or (r.pos and r.text[r.pos - 1] == ' '):
            self.save_resume(now)

    def erase(self):
        r = self.run
        if r.backspace():
            self.draw_text()
            self.redraw_cell(r.pos)
            if self.pic:
                self.apply_keys()
            self.caret()

    def pasted(self):
        now = time.monotonic()
        self.say('pasted text is not typed', now)
        self.caret()

    # ── kept, finished, left ─────────────────────────────────────────────────
    def save_resume(self, now=None):
        self.saved_at = now if now is not None else time.monotonic()
        self.app.store.save_resume({'lesson': self.lesson.id, 'index': self.index, 'title': self.lesson.title,
                                    'kind': self.lesson.kind, 'run': self.run.snapshot()})

    def leave(self):
        """Esc: the run is kept, to go on from later"""
        if self.run.pos:
            self.save_resume()
        else:
            self.app.store.clear_resume()

    def finish(self, now):
        self.finished = True
        st = self.app.store
        r = self.run
        l = self.lesson
        wpm, raw, acc = r.net(now), r.raw(now), r.accuracy()
        secs = r.minutes(now) * 60
        st.learn(r.samples)
        st.add_time(secs)
        seals = seals_for(wpm, acc, l.low, l.goal) if l.goal else 1
        best = 0
        if self.index is not None:
            d = st.progress['lessons'].setdefault(l.id, {'seals': 0, 'best': 0.0, 'tries': 0})
            d['tries'] += 1
            best = d['best']
            d['seals'] = max(d['seals'], seals if l.goal else 0)
            d['best'] = max(d['best'], wpm)
        if l.kind == 'baseline':
            st.progress['baseline'] = round(wpm, 1)
        cons = r.consistency()
        roll = r.rollover()
        rec = {'d': int(time.time()), 'l': l.id, 'k': 'test' if l.kind == 'test' else l.kind, 'w': round(wpm, 2), 'r': round(raw, 2), 'a': round(acc, 2),
               's': round(secs, 2)}
        if cons is not None:
            rec['c'] = round(cons, 1)
        if roll is not None:
            rec['o'] = round(roll, 1)
        st.append_history(rec)
        st.clear_resume()
        st.save()
        self.app.go(Result(self.app, self, wpm, raw, acc, secs, cons, roll, seals, best))


# ── a result ─────────────────────────────────────────────────────────────────
class Result(Screen):
    def __init__(self, app, lesson_screen, wpm, raw, acc, secs, cons, roll, seals, best):
        super().__init__(app)
        self.ls = lesson_screen
        self.l = lesson_screen.lesson
        self.index = lesson_screen.index
        self.wpm, self.raw, self.acc, self.secs, self.cons, self.roll = wpm, raw, acc, secs, cons, roll
        self.seals = seals
        self.best = best
        self.pic = None

    def layout(self):
        cols, rows, cw, ch = self.app.size
        self.x0, self.W = 2, max(cols - 4, 1)
        self.pic = None
        need = 13 + 5
        if rows >= need and self.W * cw >= art.KEY_W:
            self.pic = canvas.Picture(art.KEY_W, art.KEY_H, (cw, ch))

    def draw(self):
        a = self.app
        l, r = self.l, self.ls.run
        self.t.write('\x1b[?25l')
        passed = not l.goal or self.seals > 0
        place = ''
        if self.index is not None:
            place = fg(MUTED) + f'{self.index + 1} of {len(course.LESSONS)}' + OFF
        self.heading(1, a.icon('CHECK' if passed else 'CROSS'), l.title, self.x0, self.W, place)
        row = 3
        if l.goal:
            self.at(row, self.x0 + 3, seals_text(self.seals).replace(SEAL_ON, SEAL_ON + ' ').replace(SEAL_OFF, SEAL_OFF + ' '))
            row += 2
        facts = [('speed', f'{self.wpm:.0f} wpm' + (f', goal {l.goal}' if l.goal else '')),
                 ('accuracy', f'{self.acc:.1f} %' + (', at least 97' if l.goal else '')),
                 ('time', clock(self.secs))]
        if self.cons is not None:
            facts.append(('consistency', f'{self.cons:.0f} %'))
        if self.roll is not None and l.stage >= 8:
            facts.append(('rollover', f'{self.roll:.0f} %'))
        if r.shift_slips:
            facts.append(('wrong shift', str(r.shift_slips)))
        pad = max(len(k) for k, _ in facts)
        for k, v in facts:
            if row < a.size[1] - 1:
                self.at(row, self.x0 + 3, fg(MUTED) + k.ljust(pad + 2) + OFF + v)
            row += 1
        row += 1
        slips = sorted(r.slips.items(), key=lambda kv: -kv[1])[:6]
        if self.pic and row + 6 < a.size[1]:
            kb = art.Keyboard(a.dark)
            for c, _ in slips:
                n = keys.needs(c)
                if n:
                    kb.heat[n[0][0]] = art.INK['accent']
            kb.paint(self.pic, 1)
            self.t.write(self.pic.send(self.x0 + 1, row + 1, art.PALETTE[a.dark]))
            row += 6
        foot = a.size[1] - 2
        if foot > row - 1:
            self.at(foot, self.x0, 'enter  ' + fg(MUTED) + 'next' + OFF + '    r  ' + fg(MUTED) + 'again' + OFF)

    def key(self, ev):
        if ev.kind != 'press':
            return
        n = ev.name
        if ev.mods & term.CTRL and n == 'c':
            self.app.quit()
        elif n == 'enter':
            self.next()
        elif n == 'r':
            self.again()
        elif n in ('escape', 'q'):
            self.app.go(Home(self.app))

    def next(self):
        if self.index is None:
            self.app.go(Home(self.app, 'practice'))
            return
        passed = not self.l.goal or self.seals > 0
        if not passed:
            self.again()
            return
        if self.index + 1 < len(course.LESSONS):
            self.app.go(LessonScreen(self.app, self.index + 1))
        else:
            self.app.go(Home(self.app))

    def again(self):
        if self.index is None:
            self.app.go(Home(self.app, 'practice'))
            return
        self.app.go(LessonScreen(self.app, self.index))


def first_screen(app):
    """a run left under way goes on from where it stood; or the first minute; or the tabs"""
    st = app.store
    d = st.load_resume()
    if d:
        try:
            run = metrics.Run.restored(d['run'])
            i = d.get('index')
            if isinstance(i, int) and 0 <= i < len(course.LESSONS) and course.LESSONS[i].id == d.get('lesson'):
                return LessonScreen(app, i, resume=run)
            lesson = course.Lesson(str(d.get('lesson')), 8, str(d.get('kind')), str(d.get('title')), '', '', 0, 0, run.flow, len(run.text), run.limit, None)
            return LessonScreen(app, None, lesson=lesson, resume=run)
        except (KeyError, TypeError, ValueError, AttributeError):
            st.clear_resume()
    if st.progress['baseline'] is None and not st.progress['lessons']:
        return LessonScreen.free(app, 'baseline')
    return Home(app)


def main(argv):
    args = {}
    path = None
    it = iter(argv)
    for a in it:
        if a in ('-h', '--help'):
            print(__doc__)
            return 0
        if a == '--course':
            for i, l in enumerate(course.LESSONS):
                print(f'{i + 1:3}  {course.STAGE_NAMES[l.stage]:16} {l.kind:10} {l.low:3} {l.goal:3}  {l.title}')
            return 0
        if a == '--seed':
            try:
                args['seed'] = int(next(it))
            except (StopIteration, ValueError):
                print('kawa-typing: --seed N', file=sys.stderr)
                return 2
        elif a.startswith('-'):
            print(f'kawa-typing: no option {a}', file=sys.stderr)
            return 2
        else:
            path = a
    if not sys.stdin.isatty() or not sys.stdout.isatty():
        print('kawa-typing: a terminal program: run it in one', file=sys.stderr)
        return 1
    tty = term.Term()
    app = App(tty, args)
    text = None
    if path:
        try:
            with open(path, encoding='utf-8', errors='replace') as f:
                text = f.read(20000)
        except OSError as e:
            print(f'kawa-typing: {path}: {e.strerror}', file=sys.stderr)
            return 1
        text = ''.join(c for c in text.replace('\r\n', '\n').replace('\t', '    ') if c == '\n' or (c.isascii() and c.isprintable())).strip()
        if not text:
            print(f'kawa-typing: {path}: nothing in it to type', file=sys.stderr)
            return 1
    if not app.store.first_only():
        print('kawa-typing: it is open in another window', file=sys.stderr)
        return 1
    try:
        first = LessonScreen.free(app, os.path.basename(path), text) if path else first_screen(app)
        app.run(first)
    except EOFError:
        pass
    finally:
        tty.stop()
    return 0
