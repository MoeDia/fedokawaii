#!/usr/bin/python3 -I
"""tools/share-sound-proof.sh's ear: the level of each tone in what the share microphone gave a
recorder. python3 -I tones.py DESKTOP.wav TWO.wav. Exit: 0 as it should be, 1 not."""
import math
import struct
import sys
import wave


def db(path, f):
    w = wave.open(path)
    n, ch, width = w.getnframes(), w.getnchannels(), w.getsampwidth()
    raw = w.readframes(n)
    w.close()
    if width == 4:
        x = [v / 2147483648 for v in struct.unpack("<%di" % (len(raw) // 4), raw)[::ch]]
    else:
        x = [v / 32768 for v in struct.unpack("<%dh" % (len(raw) // 2), raw)[::ch]]
    x = x[len(x) // 4:]
    k, a, b = 2 * math.cos(2 * math.pi * f / 48000), 0.0, 0.0
    for v in x:
        a, b = v + k * a - b, a
    return 10 * math.log10(max((a * a + b * b - k * a * b) / (len(x) ** 2) * 4, 1e-20))


got = {p: {f: round(db(p, f), 1) for f in (1000, 2000, 3000)} for p in sys.argv[1:]}
print("── mic")
for p, v in got.items():
    print("  ", p.rsplit("/", 1)[1], v)
d, t = got[sys.argv[1]], got[sys.argv[2]]
ok = all(d[f] > -50 for f in (1000, 2000, 3000)) and t[2000] > -50 and t[3000] > -50 and t[1000] < -60
print("   ✔ the desktop's sound and your microphone; then one program's and your microphone" if ok else "   ✘ wrong")
sys.exit(0 if ok else 1)
