#!/usr/bin/env python3
import sys
import numpy as np
from PIL import Image
L="/dev/shm/lane-review/lockhome/.local/share/fedokawaii"
for mood in ("dark",):
    kv={}
    for line in open(f"{L}/{mood}/lock-scene.txt"):
        w=line.split("#")[0].split()
        if w: kv[w[0]]=w[1:]
    gx,gy,gw,gh,gn=map(int,kv["gate"])
    frames=np.asarray(Image.open(f"{L}/{mood}/lock-gate.png").convert("RGB"))
    def fr(f): return frames[:gh,f*gw:(f+1)*gw]
    print(mood,"gate",gx,gy,gw,gh,gn)
    import glob,os
    for p in sorted(glob.glob(f"/dev/shm/lane-review/g1/w2/*.png"),key=os.path.getmtime):
        a=np.asarray(Image.open(p).convert("RGB"))
        s=a[3*gy:3*(gy+gh):3,3*gx:3*(gx+gw):3]
        best=[(float((s==fr(f)).all(axis=2).mean()),f) for f in range(gn)]
        v,f=max(best)
        print(f"  {os.path.basename(p):22s} best frame {f} {v:.1%}  mean {a.mean():.1f}")
