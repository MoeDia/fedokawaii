import sys, subprocess
import numpy as np
from PIL import Image
nut, png = sys.argv[1:3]
raw = png + ".raw"
subprocess.run(["ffmpeg","-v","error","-y","-i",nut,"-fps_mode","passthrough","-vf","crop=1920:1:0:1050,format=rgb24","-f","rawvideo",raw],check=True)
a = np.fromfile(raw, np.uint8).reshape(-1,1920,3)
ch = [i for i in range(1,len(a)) if (a[i]!=a[i-1]).any()]
print("frames", len(a), "moving", len(ch), "first", ch[:1], "last", ch[-1:])
s, e = max(ch[0]-3,0), min(ch[-1]+4,len(a))
b = a[s:e]
Image.fromarray(np.repeat(b, 6, axis=0)).save(png)
ACC=np.array([0xeb,0x53,0x24])
for i,row in enumerate(b):
    xs=np.flatnonzero(np.abs(row.astype(int)-ACC).sum(axis=1)<8)
    runs=[]
    for x in xs:
        if runs and x==runs[-1][1]+1: runs[-1][1]=int(x)
        else: runs.append([int(x),int(x)])
    print(i+s, [(p,q-p+1) for p,q in runs][:8])
