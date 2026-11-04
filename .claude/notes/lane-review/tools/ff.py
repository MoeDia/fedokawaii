#!/usr/bin/env python3
# frames of a recording, with times; list changed frames' bounding box of change
import sys,subprocess,glob,os
import numpy as np
from PIL import Image
mk,outdir=sys.argv[1:3]
os.makedirs(outdir,exist_ok=True)
for f in glob.glob(outdir+"/*.png"): os.remove(f)
subprocess.run(["ffmpeg","-v","error","-i",mk,"-fps_mode","passthrough",outdir+"/%05d.png"],check=True)
pts=subprocess.run(["ffprobe","-v","error","-select_streams","v","-show_entries","frame=pts_time","-of","csv=p=0",mk],capture_output=True,text=True).stdout.split()
pts=[float(x.strip(",")) for x in pts if x.strip()]
files=sorted(glob.glob(outdir+"/*.png"))
prev=None
for i,f in enumerate(files):
    a=np.asarray(Image.open(f).convert("RGB")).astype(int)
    if prev is not None:
        d=(a!=prev).any(axis=2)
        ys,xs=np.nonzero(d)
        box=(int(xs.min()),int(ys.min()),int(xs.max()),int(ys.max())) if len(xs) else None
    else: box=None
    print(i+1,f"{pts[i]:.4f}",box)
    prev=a
