# crop a kit shot to its floating window (the part that differs from the flat ground), tolerant of glass
import sys
from PIL import Image
src, dst = sys.argv[1:3]
im = Image.open(src).convert('RGB')
W, H = im.size
px = im.load()
g = px[5, H-5]
def differs(a):
    return sum(abs(x-y) for x, y in zip(a, g)) > 6
xs = [x for x in range(0, W, 2) if any(differs(px[x, y]) for y in range(40, H, 5))]
ys = [y for y in range(40, H, 2) if any(differs(px[x, y]) for x in range(0, W, 5))]
if xs and ys:
    box = (max(xs[0]-6, 0), max(ys[0]-6, 0), min(xs[-1]+8, W), min(ys[-1]+8, H))
    im.crop(box).save(dst); print(box)
else:
    im.save(dst); print('whole')
