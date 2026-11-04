"""app.py — kawa-typing's screens: the three tabs (course, practice, progress), a lesson, its result. Text is
foot's own cells in the palette's numbers, so it follows a theme switch by itself; the keyboard and the hands
are pictures (canvas.py) repainted as the theme changes. docs/design-system.md §7 is the grammar of all of it.
"""
import math
import os
import re
import signal
import sys
import time
import traceback

from . import art, canvas, course, keys, metrics, store, term
from .term import Flags, Focus, Key, Mood, Mouse, Pasted, Resize

# the palette's numbers (screen.sh): foot holds them for both moods
ACCENT, ON_ACCENT, EDGE, EDGE2, ACCENT_TEXT, MUTED, FAINT, STRONG, SELECT, ON_SELECT = 16, 17, 18, 19, 20, 21, 22, 23, 24, 25
OFF = '\x1b[0m'
DAY_MINUTES = 20
SEAL_ON, SEAL_OFF = '●', '○'
TABS = ('course', 'practice', 'progress')
TAB_ICONS = {'course': 'MORTARBOARD', 'practice': 'BRUSH', 'progress': 'USAGE'}
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
    """cells of a line (an icon is drawn across two, but takes one: it overflows into the space after it)"""
    return len(plain(s))


def meter(app, done, total):
    """a quantity in a row (§7): ten segments, done solid, to do hollow; complete: muted; nothing yet: nothing"""
    if not done:
        return ''
    on, off = app.icon('READ'), app.icon('READ_OFF')
    n = max(1, done * 10 // total) if done < total else 10
    return fg(MUTED if done >= total else ACCENT_TEXT) + on * n + fg(EDGE2) + off * (10 - n) + OFF


def fit_power(tests):
    """the power law of practice through (day, wpm): the day it reaches 100, or None. Two weeks of data at least"""
    pts = [(r['d'], r['w']) for r in tests if r['w'] > 0]
    if len(pts) < 8 or pts[-1][0] - pts[0][0] < 14 * 86400:
        return None
    t0 = pts[0][0]
    xs = [math.log((t - t0) / 86400 + 1) for t, _ in pts]
    ys = [math.log(w) for _, w in pts]
    n = len(xs)
    mx, my = sum(xs) / n, sum(ys) / n
    den = sum((x - mx) ** 2 for x in xs)
    if not den:
        return None
    b = sum((x - mx) * (y - my) for x, y in zip(xs, ys, strict=True)) / den
    if b <= 0.01:
        return None
    a = my - b * mx
    days = math.exp((math.log(100) - a) / b) - 1
    return None if days > 3650 else t0 + days * 86400


def plan(app):
    """what comes next: a run left under way; the first minute; the day's warm-up; a lesson; the day's test"""
    st = app.store
    d = st.load_resume()
    if d.get('run') and d['run'].get('pos') if isinstance(d.get('run'), dict) else False:
        return 'resume', str(d.get('title') or 'go on'), d
    if st.progress['baseline'] is None:
        return 'baseline', 'one minute, the way you type now', None
    day = st.day()
    if not day['warm'] and sum(v[0] for v in st.keys['keys'].values()) >= 300:
        return 'warmup', 'warm up, your weakest keys', None
    if st.minutes_today() >= DAY_MINUTES and not day['test']:
        return 'test', 'the day\'s test, one minute', None
    have = st.progress['lessons']
    for i, les in enumerate(course.LESSONS):
        got = have.get(les.id)
        if not got or (les.goal and got['seals'] < 1):
            return 'lesson', les.title, i
    return 'practice', 'your weakest keys', None


def start(app, what):
    """the screen plan() named"""
    kind, _, arg = what
    if kind == 'resume':
        return resumed(app, arg) or Home(app)
    if kind == 'lesson':
        return LessonScreen(app, arg)
    if kind == 'baseline':
        return LessonScreen.free(app, 'baseline')
    if kind == 'warmup':
        return LessonScreen.free(app, 'warmup')
    if kind == 'test':
        return LessonScreen.free(app, 'test', 60, day_test=True)
    return LessonScreen.free(app, 'weak')


def resumed(app, d):
    """the run a kill, a reboot or Esc left; None if what was kept cannot be used"""
    try:
        run = metrics.Run.restored(d['run'])
        i = d.get('index')
        if isinstance(i, int) and 0 <= i < len(course.LESSONS) and course.LESSONS[i].id == d.get('lesson'):
            return LessonScreen(app, i, resume=run)
        title = str(d.get('title') or 'go on')
        lesson = course.Lesson(str(d.get('lesson')), 8, str(d.get('kind')), title, '', '', 0, 0, run.flow, len(run.text), run.limit, None)
        return LessonScreen(app, None, lesson=lesson, resume=run)
    except (KeyError, TypeError, ValueError, AttributeError, IndexError):
        app.store.clear_resume()
        return None


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
        elif isinstance(ev, Flags):
            self.releases = bool(ev.value & 2)

    def quit(self):
        self.alive = False


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
        if len(name) > w - 4:        # (never an ellipsis: cut at a word, or the name's end goes)
            name = name[:max(w - 3, 0)].rsplit(' ', 1)[0][:max(w - 4, 0)]
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
    __slots__ = ('icon', 'name', 'value', 'act', 'tell')

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
        self.kb = self.hands = None
        self.scale = 1
        self.pic_col = 0
        self.tab_spans = []
        self.plan = plan(app)
        self.drum_at = time.monotonic() + 2.5     # (the hands drum their fingers, now and then: alive, even at rest)
        self.drum_i = -1

    def wait(self):
        if self.pic and self.hands and self.app.focused:
            return max(self.drum_at - time.monotonic(), 0.005)
        return None

    def tick(self, now):
        """a finger lifted at a time, little to index, on both hands, every few seconds"""
        if not (self.pic and self.hands) or now < self.drum_at or not self.app.focused:
            return
        self.drum_i += 1
        order = ((0, 9), (1, 8), (2, 7), (3, 6))
        if self.drum_i >= len(order):
            self.hands.pose = {}
            self.drum_i = -1
            self.drum_at = now + 3.5
        else:
            self.hands.pose = {f: (0, 2) for f in order[self.drum_i]}
            self.drum_at = now + 0.07
        self.hands.paint(self.pic, self.scale, 0, art.KEY_H * self.scale)
        self.t.write(self.pic.send(self.pic_col + 1, self.first + 3 + 1, art.PALETTE[self.app.dark]))

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
        return sum(1 for les in course.LESSONS if (stage is None or les.stage == stage) and les.id in have and (have[les.id]['seals'] >= 1 or not les.goal))

    def course_rows(self):
        a = self.app
        out = []
        kind, title, arg = self.plan
        total = len(course.LESSONS)
        value = f'{arg + 1} of {total}' if kind == 'lesson' else ''
        tell = ('next', course.LESSONS[arg]) if kind == 'lesson' else ('plan', kind)
        out.append(Row(a.icon('CHEVRON_RIGHT'), title, fg(MUTED) + value + OFF, lambda: a.go(start(a, self.plan)), tell))
        counts = course.stage_counts()
        for s, name in enumerate(course.STAGE_NAMES):
            done = self.lessons_done(s)
            out.append(Row(a.icon(STAGE_ICONS[s]), name, meter(a, done, counts[s]), lambda s=s: self.open_stage(s), ('stage', s)))
        return out

    def stage_rows(self):
        have = self.app.store.progress['lessons']
        out = []
        icons = {'check': 'HOURGLASS', 'passage': 'BOOK', 'pacer': 'LANTERN', 'code': 'CODE', 'sentences': 'NOTE', 'patterns': 'SPIRAL'}
        for i, les in enumerate(course.LESSONS):
            if les.stage == self.stage:
                d = have.get(les.id)
                if not les.goal:
                    v = fg(ACCENT_TEXT) + '✓' + OFF if d else ''
                else:
                    v = seals_text(d['seals']) if d else fg(EDGE2) + SEAL_OFF * 5 + OFF
                out.append(Row(self.app.icon(icons.get(les.kind, 'KEYBOARD')), les.title, v, lambda i=i: self.app.go(LessonScreen(self.app, i)), ('lesson', les)))
        return out

    def practice_rows(self):
        a = self.app

        def go(*args):
            return lambda: a.go(LessonScreen.free(a, *args))
        out = [Row(a.icon('KEYBOARD'), 'your weakest keys', act=go('weak'), tell=('words', 'the letters you are slowest and least sure on.')),
               Row(a.icon('NOTE'), 'plain words', act=go('words'), tell=('words', 'the 200 commonest words, drawn at random.')),
               Row(a.icon('BOOK'), 'a passage', act=go('passage'), tell=('words', 'Okakura, Hearn or Nitobe, as printed.'))]
        for lang in ('bash', 'git', 'python', 'rust', 'c'):
            out.append(Row(a.icon('CODE'), lang, act=go('code', lang), tell=('words', 'real code. a line\'s indent is the editor\'s work.')))
        for secs in (15, 30, 60):
            out.append(Row(a.icon('HOURGLASS'), f'test, {secs} seconds', act=go('test', secs), tell=('words', 'plain words. it starts with your first key.')))
        return out

    def open_stage(self, s):
        self.stage = s
        self.cursor = self.top = 0
        have = self.app.store.progress['lessons']
        for i, les in enumerate(x for x in course.LESSONS if x.stage == s):
            if les.id not in have:
                self.cursor = i
                break
        self.t.write('\x1b[2J')
        self.layout()
        self.draw()

    # ── its place on the screen ──────────────────────────────────────────────
    def layout(self):
        self.build()
        cols, rows, cw, ch = self.app.size
        self.x0 = 2
        self.W = max(cols - 4, 1)
        self.first = 4                          # (a row of air, the tabs, their line, a row of air)
        self.visible = max(rows - self.first - 1, 1)
        self.pane = self.tab != 'progress' and cols >= 92
        self.list_w = min(47, self.W) if self.pane else self.W
        self.pane_x = self.x0 + self.list_w + 2
        self.pane_w = cols - self.pane_x - 2
        self.pic = None
        if self.tab == 'progress':
            self.progress_layout()
        elif self.pane and self.tab == 'course':
            # the keyboard and the hands at rest, as large as the pane has room for
            for k in (2, 1):
                need_rows = math.ceil((art.KEY_H + art.HANDS_H) * k / ch)
                if art.KEY_W * k <= self.pane_w * cw and self.first + 3 + need_rows < rows:
                    self.scale = k
                    self.pic = canvas.Picture(art.KEY_W * k, (art.KEY_H + art.HANDS_H) * k, (cw, ch))
                    self.kb = art.Keyboard(self.app.dark)
                    self.hands = art.Hands(self.app.dark)
                    self.kb.paint(self.pic, k)
                    self.hands.paint(self.pic, k, 0, art.KEY_H * k)
                    break

    # ── drawing ──────────────────────────────────────────────────────────────
    def draw_tabs(self):
        x = self.x0
        s = ''
        self.tab_spans = []
        under = None
        for name in TABS:
            icon = self.app.icon(TAB_ICONS[name])
            if name == self.tab:
                s += fg(ACCENT_TEXT) + icon + OFF + '  ' + fg(STRONG) + name + OFF + '   '
                under = (x + 3, len(name))
                w = 3 + len(name)
            else:
                s += fg(MUTED) + icon + OFF + '    '
                w = 2
            self.tab_spans.append((x, x + w, name))
            x += w + 3
        self.at(1, self.x0, s)
        if under:
            self.at(2, under[0], fg(ACCENT) + '▔' * under[1] + OFF)

    def draw_row(self, i):
        row = self.first + i - self.top
        if not 0 <= i - self.top < self.visible or i >= len(self.rows):
            return
        r = self.rows[i]
        w = self.list_w
        value, vw = r.value, width(r.value)
        room = max(w - 4 - (vw + 2 if vw else 0), 0)
        name = r.name
        if len(name) > room:           # (never an ellipsis: cut at a word, or the name's end goes)
            name = name[:room + 1].rsplit(' ', 1)[0] if ' ' in name[:room + 1] else name[:room]
            name = name[:room]
        pad = ' ' * max(w - 4 - len(name) - vw, 0)
        if i == self.cursor:
            s = bg(SELECT) + fg(ON_SELECT) + '  ' + r.icon + '  ' + name + pad + plain(value) + ' ' + OFF
        else:
            s = '  ' + fg(MUTED) + r.icon + OFF + '  ' + name + pad + value + OFF + ' '
        self.at(row, self.x0 - 1, s)

    def draw_list(self):
        if self.cursor < self.top:
            self.top = self.cursor
        if self.cursor >= self.top + self.visible:
            self.top = self.cursor - self.visible + 1
        for i in range(self.top, min(self.top + self.visible, len(self.rows))):
            self.draw_row(i)

    def today_words(self):
        st = self.app.store
        m = st.minutes_today()
        if m >= DAY_MINUTES:
            return fg(STRONG) + 'enough for today' + OFF
        return fg(MUTED) + f'{int(m)} of {DAY_MINUTES} min' + OFF

    def draw_pane(self):
        if not self.pane:
            return
        x, w = self.pane_x, self.pane_w
        rows = self.app.size[1]
        for r in range(1, rows):
            self.at(r, x, '\x1b[K')
        tell = self.rows[self.cursor].tell if self.rows else None
        st = self.app.store
        lit = {}
        lines = []
        self.heading(1, self.app.icon('LANTERN'), 'today', x, w, self.today_words())
        kind = tell[0] if tell else ''
        if kind in ('next', 'lesson'):
            les = tell[1]
            if les.goal:
                lines.append(fg(MUTED) + 'goal ' + OFF + f'{les.goal} wpm' + fg(MUTED) + ', 97 % or more' + OFF)
            else:
                lines.append(fg(MUTED) + 'no score: only the fingers' + OFF)
            d = st.progress['lessons'].get(les.id)
            if d and les.goal and d['best']:
                lines.append(fg(MUTED) + 'best ' + OFF + f'{d["best"]:.0f} wpm')
            for c in les.keys or '':
                for name, f in keys.needs(c):
                    lit[name] = f
        elif kind == 'stage':
            s = tell[1]
            lines.append(fg(MUTED) + f'{self.lessons_done(s)} of {course.stage_counts()[s]} lessons' + OFF)
            for les in course.LESSONS:
                if les.stage == s:
                    for c in les.keys or '':
                        for name, f in keys.needs(c):
                            lit.setdefault(name, f)
        elif kind == 'plan':
            lines += {'baseline': ['first, how fast you are today, however you', 'type: touch typing will pass it one day.'],
                      'resume': ['it goes on where it stopped.'],
                      'warmup': ['a minute on what you own, before anything new.'],
                      'test': ['the same test every day: the line you will', 'watch rise.'],
                      'practice': ['the course is done. this is what keeps it.']}.get(tell[1], [])
        elif kind == 'words':
            lines.append(tell[1])
        y = self.first
        for line in lines[:2]:
            self.at(y, x, line)
            y += 1
        if self.pic:
            self.kb.dark, self.hands.dark = self.app.dark, self.app.dark
            changed = set(lit) | set(self.kb.lit)
            self.kb.lit = lit
            for name in changed:
                self.kb.paint_key(self.pic, name, self.scale)
            cols_pic = math.ceil(self.pic.w / self.app.size[2])
            self.pic_col = x + (w - cols_pic) // 2
            self.pic.touch_all()
            self.t.write(self.pic.send(self.pic_col + 1, self.first + 3 + 1, art.PALETTE[self.app.dark]))

    def draw(self):
        self.t.write('\x1b[?25l')
        self.draw_tabs()
        if self.tab == 'progress':
            self.draw_progress()
        else:
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
        old, self.cursor = self.cursor, to
        if self.cursor < self.top or self.cursor >= self.top + self.visible:
            self.draw_list()
        else:
            self.draw_row(old)
            self.draw_row(to)
        self.draw_pane()

    def switch(self, tab):
        self.tab, self.stage, self.cursor, self.top = tab, None, 0, 0
        self.plan = plan(self.app)
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
        if ev.mods & (term.SUPER | term.ALT) or (ctrl and n != 'tab'):
            return
        if n in ('tab', 'right', 'left'):
            back = n == 'left' or (n == 'tab' and ev.mods & term.SHIFT)
            self.switch(TABS[(TABS.index(self.tab) + (-1 if back else 1)) % len(TABS)])
        elif n in ('down', 'j'):
            self.move(self.cursor + 1)
        elif n in ('up', 'k'):
            self.move(self.cursor - 1)
        elif n == 'pagedown':
            self.move(self.cursor + self.visible)
        elif n == 'pageup':
            self.move(self.cursor - self.visible)
        elif n == 'home':
            self.move(0)
        elif n == 'end':
            self.move(len(self.rows) - 1)
        elif n == 'enter':
            if ev.kind == 'press' and self.rows and self.rows[self.cursor].act:
                self.rows[self.cursor].act()
        elif n in ('escape', 'q') and ev.kind == 'press':
            if self.stage is not None:
                self.stage = None
                self.cursor = self.top = 0
                self.t.write('\x1b[2J')
                self.layout()
                self.draw()
            else:
                self.app.quit()

    def mouse(self, ev):
        col, row = ev.col - 1, ev.row - 1
        if ev.kind == 'wheel':
            self.move(self.cursor + ev.button)
            return
        if row == 1 and ev.kind == 'press':
            for a, b, name in self.tab_spans:
                if a <= col < b and name != self.tab:
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

    # ── the progress tab ─────────────────────────────────────────────────────
    def progress_layout(self):
        cols, rows, cw, ch = self.app.size
        self.chart = self.cal = self.heat = None
        self.col2 = self.x0 + 47 + 2
        wide = cols >= 92
        w2 = (cols - self.col2 - 2) * cw if wide else self.W * cw
        self.chart_rows = 8
        if w2 >= 200 and rows >= 20:
            self.chart = canvas.Picture((w2 // cw) * cw, self.chart_rows * ch, (cw, ch))
        if w2 >= 270 and rows >= 28 or (wide and rows >= 24):
            self.cal = canvas.Picture(min(270, w2 // cw * cw), 4 * ch, (cw, ch))
        if rows >= 22 and (self.W * cw >= art.KEY_W):
            self.heat = canvas.Picture(art.KEY_W, art.KEY_H, (cw, ch))

    def draw_progress(self):
        a = self.app
        st = a.store
        h = st.history()
        x = self.x0
        cols, rows, cw, ch = a.size
        tests = [r for r in h if r.get('k') in ('test', 'check')]
        best = max((r['w'] for r in tests), default=None)
        last = tests[-1] if tests else None
        base = st.progress['baseline']
        total = sum(r.get('s', 0) for r in h)
        facts = [('lessons', f'{self.lessons_done()} of {len(course.LESSONS)}'),
                 ('in all', f'{int(total // 3600)} h {int(total % 3600 // 60)} min'),
                 ('days', str(len({time.strftime("%Y-%m-%d", time.localtime(r["d"])) for r in h}))),
                 ('last test', f'{last["w"]:.0f} wpm, {last["a"]:.1f} %' if last else 'none yet'),
                 ('best test', f'{best:.0f} wpm' if best is not None else 'none yet')]
        rolls = [r['o'] for r in h[-40:] if 'o' in r]
        if rolls:
            facts.append(('rollover', f'{sum(rolls) / len(rolls):.0f} %'))
        if base:
            passed = best is not None and best > base
            facts.append(('your old way', f'{base:.0f} wpm' + (', passed' if passed else '')))
        when = fit_power(tests)
        if when:
            facts.append(('100 wpm', 'around ' + time.strftime('%B %Y', time.localtime(when)).lower()))
        row = self.first
        pad = max(len(k) for k, _ in facts)
        for k, v in facts:
            if row < rows - 1:
                self.at(row, x + 3, fg(MUTED) + k.ljust(pad + 2) + OFF + v)
            row += 1
        pal = art.PALETTE[a.dark]
        wide = cols >= 92
        left_row = row + 1
        if self.heat and left_row + math.ceil(art.KEY_H / ch) < rows:
            kb = art.Keyboard(a.dark)
            weak = course.weakness(st.keys['keys'])
            for c, w in weak.items():
                if c in keys.CHARS:
                    kb.heat[keys.CHARS[c][0]] = art.INK['accent'] if w > 1.5 else art.INK['flame'] if w > 1.15 else art.INK['asagi']
            kb.paint(self.heat, 1)
            self.t.write(self.heat.send(x + 1, left_row + 1, pal))
            left_row += math.ceil(art.KEY_H / ch) + 1
        col = self.col2 if wide else x
        y = 1 if wide else left_row
        if self.chart and y + 2 + self.chart_rows < rows:
            w = cols - col - 2 if wide else self.W
            self.heading(y, a.icon('USAGE'), 'speed', col, w)
            self.paint_chart(tests, base)
            self.t.write(self.chart.send(col + 1, y + 3, pal))
            y += self.chart_rows + 3
        if self.cal and y + 2 + 4 < rows and wide:
            self.heading(y, a.icon('CALENDAR'), 'days', col, cols - col - 2)
            self.paint_calendar(h)
            self.t.write(self.cal.send(col + 1, y + 3, pal))

    def paint_chart(self, tests, base):
        p = self.chart
        p.clear()
        ink = art.INK
        wpms = [r['w'] for r in tests][-200:]
        top = max([110] + wpms) * 1.05
        H, W = p.h - 3, p.w - 24

        def y(v):
            return H - int(v / top * H) + 1
        for m in MILESTONES:                  # (the milestones: a row of dots each, their figure at the left)
            if m <= top:
                art.paint_word(p, 0, y(m) - 7, str(m), ink['faint'], 1)
                for xx in range(24, p.w, 6):
                    p.fill(xx, y(m), 1, 1, ink['edge2'])
        if base:
            for xx in range(24, p.w, 3):
                p.fill(xx, y(base), 1, 1, ink['muted'])
        if wpms:
            step = W / max(len(wpms) - 1, 1)
            prev = None
            for i, v in enumerate(wpms):
                xx, yy = 24 + int(i * step), y(v)
                if prev:
                    dx, dy = xx - prev[0], yy - prev[1]
                    n = max(abs(dx), abs(dy), 1)
                    for t in range(n + 1):
                        p.fill(prev[0] + dx * t // n, prev[1] + dy * t // n, 2, 2, ink['asagi'])
                prev = (xx, yy)
            p.fill(prev[0] - 2, prev[1] - 2, 5, 5, ink['accent'])

    def paint_calendar(self, history):
        """the last 26 weeks, a seal for every day practised (the handbook's "calendar full of green squares")"""
        p = self.cal
        p.clear()
        ink = art.INK
        days = {time.strftime('%Y-%m-%d', time.localtime(r['d'])) for r in history}
        now = time.time()
        today = time.localtime(now)
        back = today.tm_wday + 25 * 7
        for i in range(back + 1):
            t = now - (back - i) * 86400
            lt = time.localtime(t)
            col, row = i // 7, lt.tm_wday
            on = time.strftime('%Y-%m-%d', lt) in days
            x, y = col * 10, row * 10 + 2
            p.fill(x + 1, y, 6, 8, ink['accent'] if on else ink['edge'])
            p.fill(x, y + 1, 8, 6, ink['accent'] if on else ink['edge'])


# ── a lesson ─────────────────────────────────────────────────────────────────
class LessonScreen(Screen):
    wants_mouse = False

    def __init__(self, app, index=None, *, lesson=None, text=None, resume=None, day_test=False):
        super().__init__(app)
        self.day_test = day_test
        self.index = index
        self.lesson = lesson if lesson is not None else course.LESSONS[index]
        les = self.lesson
        st = app.store
        if resume is not None:
            self.run = resume
        else:
            body = text if text is not None else course.text_for(les, app.rng(), st.keys['keys'])
            self.run = metrics.Run(body, les.flow, les.limit)
        self.held = {}             # keys down now → when
        self.prev_key = None
        self.notice = ''
        self.notice_until = 0.0
        self.wrong_until = 0.0
        self.thumb = 5             # (the space bar's, this time: the other hand's than the last letter)
        self.saved_at = 0.0
        self.finished = False
        self.pacer_cell = None
        self.watched = self.lesson.kind in ('sentences', 'passage') and not self.lesson.limit
        self.eye_next = 0.0        # (when the eye opens next: at random, every 40–60 s of a text)
        self.eye_open = 0.0        # (when it opened; 0: it is shut)
        self.dimmed = False        # (it was not answered: the text waits)
        self.paused_shown = False
        self.drawn_line = -1
        self.spans = []
        self.kb = self.hands = self.pic = None
        self.caret_on = True
        self.blink_at = 0.0
        self.last_key = 0.0
        self.save_resume()

    @classmethod
    def free(cls, app, what, arg=None, day_test=False):
        """from the practice tab: no lesson's seals, measured all the same"""
        rng = app.rng()
        st = app.store
        limit = None
        kind = what
        known = 'abcdefghijklmnopqrstuvwxyz'
        title = {'weak': 'your weakest keys', 'words': 'plain words', 'passage': 'a passage', 'warmup': 'warm up, your weakest keys'}.get(what, what)
        if what == 'weak':
            text = ' '.join(course.pick_words(known, rng, '', 60, course.weakness(st.keys['keys'])))
        elif what == 'warmup':
            done = [les for les in course.LESSONS if les.id in st.progress['lessons']]
            known = ''.join(c for c in (done[-1].known if done else known) if c.isalpha() and c.islower()) or known
            text = ' '.join(course.pick_words(known, rng, '', 45, course.weakness(st.keys['keys'])))
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
        return cls(app, None, lesson=lesson, text=text, day_test=day_test)

    # ── its place on the screen ──────────────────────────────────────────────
    def layout(self):
        cols, rows, cw, ch = self.app.size
        self.rows_n = rows
        x0, W = 2, max(cols - 4, 1)
        self.x0, self.W = x0, W
        top = 3                                 # (air, the heading, air)
        px_w = W * cw
        # the largest whole multiple the window has room for, with the hands; then one without them
        self.scale, self.show_hands = 0, False
        for s, hands in ((3, True), (2, True), (1, True), (1, False)):
            t = min(s, 2)
            need = top + math.ceil(60 * t / ch) + 1 + math.ceil((art.KEY_H + (art.HANDS_H if hands else 0)) * s / ch)
            if art.KEY_W * s <= px_w and need <= rows:
                self.scale, self.show_hands = s, hands
                break
        t = min(self.scale, 2) or 1
        self.letters = art.Letters(t)
        # (the text and the keyboard one column, one left edge; with no keyboard, up to 76 letters)
        self.tw_px = art.KEY_W * self.scale if self.scale else min(px_w, 76 * 7 * t)
        self.chars = max(self.tw_px // self.letters.w, 1)
        lines = 3
        if not self.scale:
            lines = max(min((rows - top - 1) * ch // self.letters.h, 3), 1)
        self.lines_n = lines
        text_rows = math.ceil(lines * self.letters.h / ch)
        pic_rows = 0
        if self.scale:
            pic_rows = math.ceil((art.KEY_H + (art.HANDS_H if self.show_hands else 0)) * self.scale / ch)
        free = max(rows - top - text_rows - 1 - pic_rows - 1, 0)
        y = top + free // 3
        self.text_y = y
        self.text_x = x0 + (W - math.ceil(self.tw_px / cw)) // 2
        self.notice_y = y + text_rows
        self.notice_w = W - (self.text_x - x0) - 3
        self.tp = canvas.Picture(max(self.tw_px, self.letters.w), lines * self.letters.h, (cw, ch))
        self.spans = wrap(self.run.text, self.chars)
        self.drawn_line = -1
        self.pic = None
        self.hand_state = None
        if self.scale:
            s = self.scale
            pw, ph = art.KEY_W * s, (art.KEY_H + (art.HANDS_H if self.show_hands else 0)) * s
            self.pic = canvas.Picture(pw, ph, (cw, ch))
            self.pic_x = x0 + (W - math.ceil(pw / cw)) // 2
            self.pic_y = self.notice_y + 1
            self.kb = art.Keyboard(self.app.dark)
            self.hands = art.Hands(self.app.dark) if self.show_hands else None
            self.kb.paint(self.pic, s)
            self.apply_keys(send=False)

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
    def paint_letter(self, i, place=None):
        """the character at position i as it stands now: typed faint, a wrong one on vermilion, the next one
        under the caret (the terminal's own: a vermilion block, Sumi Term's §1)"""
        place = place or self.place_of(i)
        if not place:
            return
        r = self.run
        c = r.text[i]
        shown = '↵' if c == '\n' else c
        ink = art.INK
        if i == r.pos and self.caret_on and self.app.focused:
            cell = self.letters.cell(shown if c != ' ' else ' ', ink['text_on_accent'], ink['accent'])
        elif i < r.pos:
            got = r.got.get(i)
            if got is None or got == c:
                cell = self.letters.cell(shown, ink['faint'])
            else:
                cell = self.letters.cell('·' if c == ' ' else shown, ink['text_on_select'], ink['select'])
        elif i == self.pacer_cell:
            cell = self.letters.cell(shown, ink['text'], ink['edge2'])
        elif c == '\n':
            cell = self.letters.cell(shown, ink['faint'])
        else:
            cell = self.letters.cell(shown, ink['text'])
        self.tp.spans(place[0], place[1], cell)

    def place_of(self, pos):
        """where position pos lies on the text's picture"""
        line = self.line_of(pos)
        k = line - self.drawn_line
        if not 0 <= k < self.lines_n:
            return None
        return (pos - self.spans[line][0]) * self.letters.w, k * self.letters.h

    def draw_text(self, force=False):
        r = self.run
        line = self.line_of(min(r.pos, len(r.text) - 1))
        if line != self.drawn_line or force:
            self.drawn_line = line
            self.tp.clear()
            for k in range(self.lines_n):
                if line + k < len(self.spans):
                    a, b = self.spans[line + k]
                    for i in range(a, b):
                        self.paint_letter(i, ((i - a) * self.letters.w, k * self.letters.h))

    def send_text(self):
        self.t.write(self.tp.send(self.text_x + 1, self.text_y + 1, art.PALETTE[self.app.dark]))

    def caret(self):
        """every frame of a lesson ends here: the letters that changed go out"""
        self.send_text()

    # ── the keyboard and the hands ───────────────────────────────────────────
    def wanted(self):
        """the keys the next character takes: [(key, finger)]"""
        r = self.run
        if r.done:
            return []
        if self.eye_open:
            return [('tab', 0)]
        anchor = self.anchor()
        if anchor and anchor not in self.held:
            return [(anchor, keys.PLACE[anchor][3])]
        return keys.needs(r.text[r.pos], self.thumb)

    def anchor(self):
        """the key this lesson has held down, once the terminal tells releases"""
        return self.lesson.extra if self.lesson.kind == 'anchor' and self.app.releases else None

    def apply_keys(self, send=True):
        """the keyboard's lights and the hands' pose, as the next key and the held ones want them"""
        if not self.pic:
            return
        kb, hands = self.kb, self.hands
        quiet = self.app.store.progress['quiet']
        want = [] if quiet else self.wanted()
        lit = dict(want)
        # (the legends a shifted key would show: what is held, or what the next key will take)
        shift = any(k in self.held or k in lit for k in ('lshift', 'rshift'))
        changed = set(lit) ^ set(kb.lit) | {k for k in lit if kb.lit.get(k) != lit[k]}
        new_down = {k for k in self.held if k in keys.PLACE}
        changed |= new_down ^ kb.down
        new_wrong = kb.wrong
        if shift != kb.shift:
            kb.shift = shift
            changed |= {name for name, p in keys.PLACE.items() if p[4] != p[5]}
        kb.lit, kb.down = lit, new_down
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
                    pose[f] = ((kx - hx) // 2, (hy - ky) // 3 + 3)
                else:
                    pose[f] = (0, 3)
            pressed = {keys.PLACE[k][3] if k != 'space' else self.thumb for k in new_down if k in keys.PLACE}
            wrong_f = {keys.PLACE[k][3] for k in kb.wrong if k in keys.PLACE}
            state = (pose, lit_f, pressed, wrong_f)
            if state != self.hand_state:
                self.hand_state = state
                hands.pose, hands.lit, hands.pressed, hands.wrong = pose, lit_f, pressed, wrong_f
                hands.paint(self.pic, self.scale, 0, art.KEY_H * self.scale)
        if send:
            self.t.write(self.pic.send(self.pic_x + 1, self.pic_y + 1, art.PALETTE[self.app.dark]))

    # ── drawing ──────────────────────────────────────────────────────────────
    def stats(self, now=None):
        r = self.run
        if r.correct + r.wrong == 0:
            return ''
        wpm, acc = r.net(now), r.accuracy()
        s = fg(MUTED) + f'{wpm:.0f} wpm  {acc:.0f} %' + OFF
        if self.paused_shown:
            s = fg(STRONG) + 'paused' + OFF + '  ' + s
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
        self.at(self.notice_y, self.x0, '\x1b[0m' + ' ' * self.W)
        if self.notice:
            self.at(self.notice_y, self.text_x, fg(ACCENT_TEXT) + self.app.icon('CROSS') + OFF + '  ' + self.notice[:max(self.notice_w, 0)])

    def say(self, words, now, secs=2.0):
        if words != self.notice:
            self.notice = words
            self.draw_notice()
        self.notice_until = now + secs

    def draw(self):
        self.t.write('\x1b[?25l')
        self.draw_heading()
        self.draw_notice()
        if self.pic:
            self.pic.touch_all()
            self.t.write(self.pic.send(self.pic_x + 1, self.pic_y + 1, art.PALETTE[self.app.dark]))
        self.drawn_line = -1
        self.draw_text()
        self.tp.touch_all()
        self.send_text()

    def remood(self):
        self.t.write('\x1b[2J')
        self.layout()
        self.draw()

    # ── time ─────────────────────────────────────────────────────────────────
    def wait(self):
        if self.notice or self.wrong_until or self.lesson.kind == 'pacer' and self.run.first is not None:
            return 0.08
        if self.run.limit and self.run.first is not None:
            return 0.25
        return 0.25 if self.app.focused else None     # (the caret's blink)

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
            if r.expired(now):
                self.finish(now)
                return
        if self.app.focused and now - self.last_key > 0.6 and now >= self.blink_at and not self.dimmed:
            self.blink_at = now + 0.5
            self.caret_on = not self.caret_on
            if not r.done:
                self.paint_letter(r.pos)
                self.caret()
        if self.lesson.kind == 'pacer' and r.first is not None:
            self.draw_pacer(now)
        if r.first is not None and not r.done:
            stopped = r.hold or now - r.last > metrics.PAUSE
            if stopped != self.paused_shown:
                self.paused_shown = stopped
                self.draw_heading(now)
        if self.watched:
            self.tick_eye(now)

    def tick_eye(self, now):
        """Yechiam 2003's signal: open at random; answered by its key within 2 s, or the text waits, dimmed"""
        if not self.eye_next:
            if self.run.first is not None:
                self.eye_next = now + self.eye_gap()
            return
        if not self.eye_open and now >= self.eye_next and not self.paused_shown and self.notice_y < self.rows_n:
            self.eye_open = now
            self.draw_eye()
            self.apply_keys()
        elif self.eye_open and not self.dimmed and now - self.eye_open > 2:
            self.dimmed = True
            self.run.pause()
            self.dim(True)

    def eye_gap(self):
        return self.app.args.get('eye') or self.app.rng().uniform(40, 60)

    def draw_eye(self):
        """on the row between the text and the keyboard, where looking down at the keys misses it"""
        cols, rows, cw, ch = self.app.size
        pic = canvas.Picture(40, ch, (cw, ch))
        if self.eye_open:
            art.paint_eye(pic, 0, max((ch - 16) // 2, 0), 2, self.app.dark)
            self.t.write(pic.send(self.text_x + 1, self.notice_y + 1, art.PALETTE[self.app.dark]))
            self.at(self.notice_y, self.text_x + 6, fg(STRONG) + 'tab' + OFF)
        else:
            self.t.write(f'\x1b[{self.notice_y + 1};{self.text_x + 1}H\x1b[10X')

    def dim(self, on):
        """the text goes faint until the eye is answered"""
        self.tp.clear()
        if not on:
            self.drawn_line = -1
            self.draw_text()
        else:
            k_line = self.drawn_line
            for k in range(self.lines_n):
                if k_line + k < len(self.spans):
                    a, b = self.spans[k_line + k]
                    for i in range(a, b):
                        c = self.run.text[i]
                        self.tp.spans((i - a) * self.letters.w, k * self.letters.h,
                                      self.letters.cell('↵' if c == '\n' else c, art.INK['edge2']))
        self.send_text()

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
        if old is not None:
            self.paint_letter(old)
        self.paint_letter(at)
        self.caret()

    def focus(self, on):
        if not on:
            self.run.pause()
            self.held.clear()
            if self.kb:
                self.kb.wrong = set()
            self.apply_keys()
            self.save_resume()
        if not self.run.done:
            self.caret_on = True
            self.paint_letter(self.run.pos)
        self.caret()

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
            elif ev.mods & term.CTRL and name == 'k' and ev.kind == 'press':
                p = self.app.store.progress
                p['quiet'] = not p['quiet']
                self.apply_keys()
                self.caret()
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
            if self.eye_open:
                self.eye_open = 0.0
                self.eye_next = now + self.eye_gap()
                self.draw_eye()
                if self.dimmed:
                    self.dimmed = False
                    self.dim(False)
                self.apply_keys()
                self.caret()
            return
        if self.dimmed:
            return
        anchor = self.anchor()
        if anchor:
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
        if r.expired(now):       # (past the clock: the test is over, this key is not part of it)
            self.finish(now)
            return
        rolled = bool(self.prev_key) and self.prev_key in self.held
        before = r.pos
        self.last_key = now
        self.caret_on = True
        ok = r.press(ch, now, rolled)
        self.prev_key = name
        self.held[name] = now
        want_shift = next((k for k, _ in keys.needs(ch) if k in ('lshift', 'rshift')), None)
        if ok and want_shift and want_shift not in self.held and any(s in self.held for s in ('lshift', 'rshift')):
            r.shift_slips += 1
            self.say(f'the {"right" if want_shift == "rshift" else "left"} shift for that one', now)
        if ok:
            f = keys.PLACE[name][3] if name in keys.PLACE else None
            if f is not None and f != 5:
                self.thumb = 5 if f < 5 else 4
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
        if not r.done:
            self.paint_letter(before)
            self.paint_letter(r.pos)
        if self.pic:
            self.apply_keys()
        self.caret()
        if now - self.saved_at > 2.0 or (r.pos and r.text[r.pos - 1] == ' '):
            self.t.flush()           # (the key's frame first: the disk never holds it up)
            self.save_resume(now)

    def erase(self):
        r = self.run
        at = r.pos
        if r.backspace():
            self.draw_text()
            if at < len(r.text):
                self.paint_letter(at)
            self.paint_letter(r.pos)
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
        les = self.lesson
        wpm, raw, acc = r.net(now), r.raw(now), r.accuracy()
        secs = r.minutes(now) * 60
        st.learn(r.samples)
        st.add_time(secs)
        seals = seals_for(wpm, acc, les.low, les.goal) if les.goal else 1
        best = 0
        if self.index is not None:
            d = st.progress['lessons'].setdefault(les.id, {'seals': 0, 'best': 0.0, 'tries': 0})
            d['tries'] += 1
            best = d['best']
            d['seals'] = max(d['seals'], seals if les.goal else 0)
            d['best'] = max(d['best'], wpm)
        day = st.day()
        if les.kind == 'baseline':
            st.progress['baseline'] = round(wpm, 1)
        elif les.kind == 'warmup':
            day['warm'] = True
        elif self.day_test:
            day['test'] = True
        cons = r.consistency()
        roll = r.rollover()
        rec = {'d': int(time.time()), 'l': les.id, 'k': les.kind, 'w': round(wpm, 2), 'r': round(raw, 2), 'a': round(acc, 2), 's': round(secs, 2)}
        if cons is not None:
            rec['c'] = round(cons, 1)
        if roll is not None:
            rec['o'] = round(roll, 1)
        st.append_history(rec)
        st.clear_resume()
        st.save()
        if les.kind == 'meet' and self.index is not None:   # (no score: on to its drill, without a stop)
            self.app.go(start(self.app, plan(self.app)))
            return
        self.app.go(Result(self.app, self, wpm, raw, acc, secs, cons, roll, seals, best))


# ── a result ─────────────────────────────────────────────────────────────────
class Result(Screen):
    """the seals stamped one after another (§11), the speed in display size, the facts, the keyboard with what
    slipped on it; Enter goes on, r again"""

    def __init__(self, app, lesson_screen, wpm, raw, acc, secs, cons, roll, seals, best):
        super().__init__(app)
        self.ls = lesson_screen
        self.les = lesson_screen.lesson
        self.index = lesson_screen.index
        self.wpm, self.raw, self.acc, self.secs, self.cons, self.roll = wpm, raw, acc, secs, cons, roll
        self.seals = seals
        self.best = best
        self.passed = not self.les.goal or seals > 0
        self.top_pic = self.kb_pic = None
        self.began = None
        self.stamped = 0

    def layout(self):
        cols, rows, cw, ch = self.app.size
        self.x0, self.W = 2, max(cols - 4, 1)
        self.top_pic = canvas.Picture(min(self.W * cw // cw * cw, 8 * 40), 6 * ch, (cw, ch)) if rows >= 14 and self.W * cw >= 192 else None
        self.kb_pic = None
        if self.W * cw >= art.KEY_W and rows >= 26 or (cols >= 92 and rows >= 18):
            self.kb_pic = canvas.Picture(art.KEY_W, art.KEY_H, (cw, ch))

    def seal_state(self, i):
        if i >= min(self.seals, 5) or i >= self.stamped:
            return 'off'
        return 'gold' if self.seals >= 6 else 'on'

    def paint_top(self):
        p = self.top_pic
        if not p:
            return
        ink = art.INK
        if self.les.goal:
            for i in range(5):
                art.paint_seal(p, i * 40 + 2, 2, 32, self.app.dark, self.seal_state(i))
        y = 44 if self.les.goal else 4
        word = f'{self.wpm:.0f}'
        art.paint_word(p, 0, y, word, ink['strong'], 3)
        art.paint_word(p, (len(word) * 7 + 2) * 3, y + 20, 'wpm', ink['muted'], 1)

    def facts(self):
        les, r = self.les, self.ls.run
        out = [('accuracy', f'{self.acc:.1f} %' + (', 97 at least' if les.goal else ''))]
        if les.goal:
            out.append(('goal', f'{les.goal} wpm'))
        out.append(('time', clock(self.secs)))
        if self.cons is not None:
            out.append(('consistency', f'{self.cons:.0f} %'))
        if self.roll is not None and (les.stage >= 8):
            out.append(('rollover', f'{self.roll:.0f} %'))
        if r.shift_slips:
            out.append(('wrong shift', str(r.shift_slips)))
        return out

    def verdict(self):
        """one line: what to do about it"""
        les, r = self.les, self.ls.run
        slips = sorted(r.slips.items(), key=lambda kv: -kv[1])
        words = ''
        if slips:
            named = [('space' if c == ' ' else 'enter' if c == '\n' else c) for c, _ in slips[:3]]
            words = 'slipped on ' + ', '.join(named)
        if self.les.kind == 'baseline':
            return 'that is your old way. touch typing will pass it.'
        if not self.passed:
            if self.acc < 97:
                return 'slower, then: 97 % opens the next one.' + (' ' + words + '.' if words else '')
            return f'held your accuracy; {max(les.low - self.wpm, 1):.0f} wpm more opens the next one.'
        return words + '.' if words else ''

    def draw(self):
        a = self.app
        les = self.les
        cols, rows, cw, ch = a.size
        self.t.write('\x1b[?25l')
        place = ''
        if self.index is not None:
            place = fg(MUTED) + f'{self.index + 1} of {len(course.LESSONS)}' + OFF
        self.heading(1, a.icon('CHECK' if self.passed else 'CROSS'), les.title, self.x0, self.W, place)
        pal = art.PALETTE[a.dark]
        row = 3
        if self.top_pic:
            self.paint_top()
            self.top_pic.touch_all()
            self.t.write(self.top_pic.send(self.x0 + 1, row + 1, pal))
            row += 5 if les.goal else 4
        else:
            self.at(row, self.x0, seals_text(self.seals) + '  ' + f'{self.wpm:.0f} wpm' if les.goal else f'{self.wpm:.0f} wpm')
            row += 2
        facts = self.facts()
        pad = max(len(k) for k, _ in facts)
        for k, v in facts:
            if row < rows - 2:
                self.at(row, self.x0 + 3, fg(MUTED) + k.ljust(pad + 2) + OFF + v)
                row += 1
        words = self.verdict()
        if words and row + 1 < rows - 2:
            row += 1
            self.at(row, self.x0, words[:self.W])
            row += 1
        if self.kb_pic:
            kb = art.Keyboard(a.dark)
            for c, _ in self.ls.run.slips.items():
                n = keys.needs(c)
                if n:
                    kb.wrong.add(n[0][0])
            kb.paint(self.kb_pic, 1)
            wide = cols >= 92
            kx = cols - 2 - math.ceil(art.KEY_W / cw) if wide else self.x0
            ky = 3 if wide else row + 1
            if ky + math.ceil(art.KEY_H / ch) < rows - 1:
                self.t.write(self.kb_pic.send(kx + 1, ky + 1, pal))
        if rows >= 8:
            go = 'next' if self.passed else 'again'
            again = '    r  ' + fg(MUTED) + 'again' + OFF if self.index is not None and self.passed else ''
            self.at(rows - 2, self.x0, 'enter  ' + fg(MUTED) + go + OFF + again)
        self.began = None

    def wait(self):
        return 0.03 if self.top_pic and self.stamped < min(self.seals, 5) else None

    def tick(self, now):
        if not self.top_pic or self.stamped >= min(self.seals, 5):
            return
        if self.began is None:
            self.began = now + 0.08
            return
        # (each stamp: down for 60 ms, lit and a pixel larger; then as it stays. 140 ms apart)
        i = self.stamped
        at = now - self.began - i * 0.14
        if at >= 0:
            p = self.top_pic
            down = at < 0.06
            state = 'down' if down else ('gold' if self.seals >= 6 else 'on')
            art.paint_seal(p, i * 40 + 2, 2, 32, self.app.dark, state)
            if not down:
                self.stamped += 1
            self.t.write(p.send(self.x0 + 1, 4, art.PALETTE[self.app.dark]))

    def key(self, ev):
        if ev.kind != 'press':
            return
        n = ev.name
        if ev.mods & term.CTRL and n == 'c':
            self.app.quit()
        elif n == 'enter':
            self.next()
        elif n == 'r' and not ev.mods & (term.CTRL | term.ALT | term.SUPER):
            self.again()
        elif n in ('escape', 'q'):
            self.app.go(Home(self.app, 'course' if self.index is not None else 'practice'))

    def next(self):
        if not self.passed:
            self.again()
        elif self.index is None and self.les.kind not in ('baseline', 'warmup', 'test'):
            self.app.go(Home(self.app, 'practice'))
        else:
            self.app.go(start(self.app, plan(self.app)))

    def again(self):
        if self.index is None:
            self.app.go(Home(self.app, 'practice'))
        else:
            self.app.go(LessonScreen(self.app, self.index))


def status_lines():
    st = store.Store()
    have = st.progress['lessons']
    done = sum(1 for les in course.LESSONS if les.id in have and (have[les.id]['seals'] >= 1 or not les.goal))
    out = [f'lesson {done + 1} of {len(course.LESSONS)}' if done < len(course.LESSONS) else 'the course is done']
    tests = [r for r in st.history() if r.get('k') in ('test', 'check')]
    if tests:
        out.append(f'last test {tests[-1]["w"]:.0f} wpm, {tests[-1]["a"]:.0f} %')
    return out


HELP = """kawa-typing — touch typing, finger by finger, to 100 words a minute and past it: a terminal program, the keyboard
and the hands drawn in the terminal itself (Super+U, learning → typing).

    kawa-typing            the course: it goes on where you stopped
    kawa-typing FILE       types a file of your own (code, notes, anything)
    kawa-typing --course   the lessons, as a table

In a lesson: Esc leaves it (it is kept), Ctrl+K quiets the next key's light, Backspace corrects (from the sentences on).
On the tabs: Tab or the arrows change tab, Enter goes, Esc goes back or closes.
Everything it keeps: ~/.local/state/fedokawaii/typing. The method and its sources: docs/learn/typing/."""


def main(argv):
    args = {}
    path = None
    it = iter(argv)
    for a in it:
        if a in ('-h', '--help'):
            print(HELP)
            return 0
        if a == '--status':       # (for Super+U's pane: where you are, in a line or two)
            for line in status_lines():
                print(line)
            return 0
        if a == '--course':
            for i, les in enumerate(course.LESSONS):
                print(f'{i + 1:3}  {course.STAGE_NAMES[les.stage]:16} {les.kind:10} {les.low:3} {les.goal:3}  {les.title}')
            return 0
        if a == '--seed' or a == '--eye':     # (for its tests: the words drawn; the eye's first opening, in seconds)
            try:
                args[a[2:]] = int(next(it))
            except (StopIteration, ValueError):
                print(f'kawa-typing: {a} N', file=sys.stderr)
                return 2
        elif a == '--lesson':
            try:
                args['lesson'] = course.BY_ID[next(it)]
            except (StopIteration, KeyError):
                print('kawa-typing: --lesson ID (kawa-typing --course lists them, ids in course.py)', file=sys.stderr)
                return 2
        elif a.startswith('-'):
            print(f'kawa-typing: no option {a}', file=sys.stderr)
            return 2
        else:
            path = a
    if not sys.stdin.isatty() or not sys.stdout.isatty():
        print('kawa-typing: a terminal program: run it in one', file=sys.stderr)
        return 1
    if not os.environ.get('TERM', '').startswith('foot'):
        print('kawa-typing: it draws in the desktop\'s terminal (foot): the keyboard and the words are pictures', file=sys.stderr)
        return 1
    tty = term.Term()
    app = App(tty, args)

    def leave(*_):     # (the window closed, or asked to end: what is kept is kept)
        app.alive = False
        tty.poke()
    signal.signal(signal.SIGTERM, leave)
    signal.signal(signal.SIGHUP, leave)
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
        time.sleep(2)      # (long enough to be read, in a window of its own)
        return 1
    rc = 0
    try:
        if path:
            first = LessonScreen.free(app, os.path.basename(path), text)
        elif 'lesson' in args:
            first = LessonScreen(app, args['lesson'])
        else:
            first = Home(app)
        app.run(first)
        app.store.save()
    except EOFError:
        app.store.save()
    except Exception:   # (the terminal goes back as it was, whatever happened; what happened goes to a file)
        tty.stop()
        try:
            with open(os.path.join(app.store.dir, 'crash.log'), 'a') as f:
                f.write(time.strftime('%F %T\n') + traceback.format_exc() + '\n')
        except OSError:
            pass
        print('kawa-typing: it broke: the details are in ' + os.path.join(app.store.dir, 'crash.log'), file=sys.stderr)
        rc = 1
    finally:
        tty.stop()
    return rc
