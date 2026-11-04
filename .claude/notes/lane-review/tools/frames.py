#!/usr/bin/env python3
# lane-review: a recording's frames → times, and per frame where the rail stands and the vermilion focus hairlines
import sys, subprocess, glob, os, re, json
import numpy as np
from PIL import Image
mk, outdir = sys.argv[1:3]
os.makedirs(outdir, exist_ok=True)
for f in glob.glob(outdir + "/*.png"): os.remove(f)
subprocess.run(["ffmpeg","-v","error","-i",mk,"-fps_mode","passthrough",outdir+"/%05d.png"],check=True)
pts = subprocess.run(["ffprobe","-v","error","-select_streams","v","-show_entries","frame=pts_time","-of","csv=p=0",mk],capture_output=True,text=True).stdout.split()
pts = [float(x.strip(",")) for x in pts if x.strip()]
files = sorted(glob.glob(outdir+"/*.png"))
print(len(files), "frames", len(pts), "times")
ACC=np.array([0xeb,0x53,0x24])
prev=None
rows=[]
t0=None
for i,f in enumerate(files):
    a=np.asarray(Image.open(f).convert("RGB")).astype(int)
    # a row low on the screen, under the bar, to see what crosses (y=1060 and y=600)
    r=a[1050]
    m=(np.abs(r-ACC).sum(axis=1)<8)
    # runs of vermilion on that row
    xs=np.flatnonzero(m)
    runs=[]
    if len(xs):
        s=xs[0];p=xs[0]
        for x in xs[1:]:
            if x!=p+1: runs.append((int(s),int(p-s+1))); s=x
            p=x
        runs.append((int(s),int(p-s+1)))
    changed = prev is None or (a!=prev).any()
    prev=a
    t=pts[i] if i<len(pts) else None
    rows.append((i+1,t,runs,bool(changed)))
for n,t,runs,ch in rows:
    print(n, f"{t:.4f}" if t is not None else "-", runs[:6], "" if ch else "same")
