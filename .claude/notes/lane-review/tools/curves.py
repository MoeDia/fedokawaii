#!/usr/bin/env python3
# lane-review: dwl's motion curves (src/dwl/dwl.patch, spring()) frame by frame at 144 Hz
import math
def spring(p,w,z):
    if p<=0: return 1.0
    if p>=1: return 0.0
    k = 1.0-(p-0.9)*10.0 if p>0.9 else 1.0
    if z>=1: return k*(1+w*p)*math.exp(-w*p)
    d=w*math.sqrt(1-z*z)
    return k*math.exp(-z*w*p)*(math.cos(d*p)+z*w/d*math.sin(d*p))
F=1000/144
def run(name,dist,ms,w,z):
    n=int(ms/F)+1
    xs=[round(dist*spring(i*F/ms,w,z)) for i in range(n+1)]
    ds=[xs[i+1]-xs[i] for i in range(n)]
    print(name,"dist",dist,"ms",ms,"frames",n)
    print(" pos",xs)
    print(" d  ",ds)
    # acceleration jumps
    dd=[ds[i+1]-ds[i] for i in range(n-1)]
    print(" max|d|",max(abs(x) for x in ds)," max jerk at end (last 8 d):",ds[-8:])
    print(" min pos",min(xs))
run("open 120px",120,450,7.5,0.72)
run("tag strip 1935px (wave 0)",1935,402,8.0,0.84)
run("tag strip 1935px rail",1935,450,8.0,0.84)
run("slide 600px",600,300,8.0,1.0)
run("slide 60px",60,300,8.0,1.0)
