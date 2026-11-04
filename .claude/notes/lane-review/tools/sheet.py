#!/usr/bin/env python3
# lane-review: a contact sheet of named frames: sheet.py OUT.png SCALE COLS FRAME…
import sys
from PIL import Image, ImageDraw
out, scale, cols = sys.argv[1], float(sys.argv[2]), int(sys.argv[3])
files = sys.argv[4:]
ims = [Image.open(f).convert("RGB") for f in files]
w, h = ims[0].size
tw, th = int(w*scale), int(h*scale)
rows = (len(ims)+cols-1)//cols
sheet = Image.new("RGB", (cols*(tw+4), rows*(th+18)), (40,40,40))
d = ImageDraw.Draw(sheet)
for i,(f,im) in enumerate(zip(files,ims)):
    x,y = (i%cols)*(tw+4), (i//cols)*(th+18)
    sheet.paste(im.resize((tw,th), Image.NEAREST if scale>=1 else Image.BILINEAR), (x,y+14))
    d.text((x+2,y+1), f.split('/')[-1], fill=(255,255,255))
sheet.save(out)
print(sheet.size)
