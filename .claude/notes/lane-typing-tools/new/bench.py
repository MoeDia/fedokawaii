import os, sys, time, tempfile
os.environ['XDG_STATE_HOME'] = tempfile.mkdtemp(dir='/dev/shm')
os.environ['XDG_CONFIG_HOME'] = os.path.expanduser('~/.config')
sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[1])
from kawatype import app as A, course, term, art
class T:
    def __init__(self): self.n = 0
    def write(self, b): self.n += len(b)
    def flush(self): pass
    def mouse_on(self, on): pass
    def start(self): pass
    def size(self): return (79, 38, 8, 20)
t = T()
a = A.App(t, {'seed': 3})
a.size = (79, 38, 8, 20)
s = A.LessonScreen(a, course.BY_ID['speed.30.passage.1'])
t0 = time.perf_counter(); s.layout(); s.draw(); print('first frame ms', round((time.perf_counter()-t0)*1000,1), 'bytes', t.n)
times, feeds = [], []
r = s.run
base = time.monotonic()
for i, c in enumerate(r.text[:200]):
    now = base + i * 0.1
    ev = term.Key('press', 'space' if c == ' ' else c.lower(), c, 0, now)
    s.key(ev)
    t0 = time.perf_counter()
    s.tick(now)
    dt = time.perf_counter() - t0
    (feeds if s.feed else times).append(dt * 1000)
    while s.feed:
        t.n = 0
        t0 = time.perf_counter()
        s.stale = True
        s.render(now)
        feeds.append((time.perf_counter() - t0) * 1000)
        time.sleep(0.016)
    s.key(term.Key('release', 'space' if c == ' ' else c.lower(), '', 0, now + 0.03))
times.sort(); feeds.sort()
print('key frame ms p50', round(times[len(times)//2],2), 'p95', round(times[int(len(times)*.95)],2), 'max', round(times[-1],2))
print('feed frame ms p50', round(feeds[len(feeds)//2],2), 'max', round(feeds[-1],2), 'n', len(feeds))
