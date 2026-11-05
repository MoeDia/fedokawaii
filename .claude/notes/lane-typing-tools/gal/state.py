# a demo state: three weeks of practice, for the shots
import json, os, random, sys, time
d = sys.argv[1]
os.makedirs(d, exist_ok=True)
sys.path.insert(0, sys.argv[2])
from kawatype import course
rng = random.Random(5)
lessons = {}
for i, l in enumerate(course.LESSONS[:58]):
    lessons[l.id] = {'seals': 0 if not l.goal else rng.choice((1, 3, 4, 5, 5, 6)), 'best': rng.uniform(14, 38), 'tries': rng.randint(1, 3)}
json.dump({'lessons': lessons, 'baseline': 38.0, 'quiet': False, 'day': {'date': time.strftime('%Y-%m-%d'), 'seconds': 760.0, 'warm': True, 'test': False}}, open(d + '/progress.json', 'w'))
now = time.time()
with open(d + '/history.jsonl', 'w') as f:
    for k in range(60):
        t = now - (60 - k) * 86400 * 0.45
        w = 12 + k * 0.62 + rng.uniform(-2, 2)
        f.write(json.dumps({'d': int(t), 'l': 'free.test', 'k': 'test', 'w': round(w, 2), 'r': round(w + 2, 2), 'a': round(rng.uniform(95, 99.8), 2), 's': 60.0, 'c': 70.0, 'o': round(k * 0.3, 1)}) + '\n')
keys = {}
for c in 'abcdefghijklmnopqrstuvwxyz,. ;':
    ms = rng.uniform(150, 260) * (1.8 if c in 'zqxpb' else 1.25 if c in 'yuvk' else 1)
    keys[c] = [rng.randint(100, 900), rng.randint(1, 40) if c in 'zqp' else rng.randint(0, 8), ms, ms * 0.8]
json.dump({'keys': keys, 'pairs': {}}, open(d + '/keys.json', 'w'))
