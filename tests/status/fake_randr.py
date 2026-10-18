#!/usr/bin/env python3
# fake wlr-randr: prints the heads in $FAKE_RANDR (a JSON list) exactly as wlr-randr 0.4/0.5
# prints them — each mode's refresh is (float)mHz / 1000 printed with %f, a mode with no
# refresh has no ", … Hz" — and applies "--output NAME --mode WxH[@R[Hz]]" with wlr-randr's
# own matching: round(strtod(R) * 1000) must equal a mode's mHz exactly, else "unknown mode"
# and exit 1. Applied modes are written back; every set or failure is logged to $FAKE_RANDR.log.
# (From the display review's kit, review12/B.) $FAKE_RANDR_FAIL=1: no compositor to talk to.
import json
import os
import re
import struct
import sys

if os.environ.get("FAKE_RANDR_FAIL"):
    print("failed to connect to display", file=sys.stderr)
    sys.exit(1)
fx = os.environ["FAKE_RANDR"]
heads = json.load(open(fx))
log = open(fx + ".log", "a")


def f32(x):
    return struct.unpack("f", struct.pack("f", x))[0]


def show():
    for h in heads:
        print(f'{h["name"]} "{h.get("desc", "")}"')
        print(f'  Make: {h.get("make", "")}')
        print(f'  Model: {h.get("model", "")}')
        print(f'  Serial: {h.get("serial", "")}')
        print(f'  Enabled: {"yes" if h.get("enabled", True) else "no"}')
        if h["modes"]:
            print("  Modes:")
        for i, (w, ht, mhz) in enumerate(h["modes"]):
            s = f"    {w}x{ht} px"
            if mhz > 0:
                s += ", %f Hz" % f32(f32(mhz) / 1000)
            tags = []
            if i == h.get("preferred"):
                tags.append("preferred")
            if i == h.get("current"):
                tags.append("current")
            if tags:
                s += " (" + ", ".join(tags) + ")"
            print(s)
        if not h.get("enabled", True):
            continue
        print(f'  Position: {h.get("x", 0)},0')
        print(f'  Transform: {h.get("transform", "normal")}')
        print(f'  Scale: {h.get("scale", 1.0):f}')
        print("  Adaptive Sync: disabled")


def parse_mode(v):
    m = re.match(r"^(\d+)x(\d+)(?:\s*(?:px)?\s*[,@]\s*([0-9.eE+-]+)(Hz)?)?$", v)
    if not m:
        return None
    r = 0
    if m[3]:
        r = int(round(float(m[3]) * 1000))
    return int(m[1]), int(m[2]), r


args = sys.argv[1:]
if not args:
    show()
    sys.exit(0)
cur = None
i = 0
while i < len(args):
    a = args[i]
    if a == "--output":
        cur = next((h for h in heads if h["name"] == args[i + 1]), None)
        if cur is None:
            print(f"unknown output {args[i + 1]}", file=sys.stderr)
            sys.exit(1)
        i += 2
    elif a == "--mode":
        p = parse_mode(args[i + 1])
        if p is None:
            print(f"invalid mode: {args[i + 1]}", file=sys.stderr)
            log.write(f"FAIL {cur['name']} {args[i + 1]}\n")
            sys.exit(1)
        w, ht, r = p
        idx = next((j for j, (mw, mh, mr) in enumerate(cur["modes"])
                    if mw == w and mh == ht and (r == 0 or mr == r)), None)
        if idx is None:
            print(f"unknown mode: {args[i + 1]}", file=sys.stderr)
            log.write(f"FAIL {cur['name']} {args[i + 1]}\n")
            sys.exit(1)
        cur["current"] = idx
        log.write(f"SET {cur['name']} {w}x{ht}@{cur['modes'][idx][2]}\n")
        i += 2
    else:
        i += 1
json.dump(heads, open(fx, "w"))
