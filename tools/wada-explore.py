#!/usr/bin/env python3
# tools/wada-explore.py — the Wada colours (colors.json from github.com/mattdesl/dictionary-of-colour-combinations)
# against our palette: nearest Wada colour per token (ΔE2000), the darkest and lightest swatches, the
# vermilions and the combinations that pair one with a near-black.   python3 -I tools/wada-explore.py colors.json
import json, math, sys
d = json.load(open(sys.argv[1]))
def hex2lab(h):
    h = h.lstrip('#'); r, g, b = (int(h[i:i+2], 16) / 255 for i in (0, 2, 4))
    f = lambda c: ((c + 0.055) / 1.055) ** 2.4 if c > 0.04045 else c / 12.92
    r, g, b = f(r), f(g), f(b)
    x = (r*0.4124 + g*0.3576 + b*0.1805) / 0.95047; y = r*0.2126 + g*0.7152 + b*0.0722; z = (r*0.0193 + g*0.1192 + b*0.9505) / 1.08883
    t = lambda v: v ** (1/3) if v > 0.008856 else 7.787 * v + 16/116
    return (116*t(y) - 16, 500*(t(x) - t(y)), 200*(t(y) - t(z)))
def de2000(l1, l2):
    L1,a1,b1 = l1; L2,a2,b2 = l2
    C1=math.hypot(a1,b1); C2=math.hypot(a2,b2); Cb=(C1+C2)/2
    G=0.5*(1-math.sqrt(Cb**7/(Cb**7+25**7))); a1p=(1+G)*a1; a2p=(1+G)*a2
    C1p=math.hypot(a1p,b1); C2p=math.hypot(a2p,b2)
    h1p=math.degrees(math.atan2(b1,a1p))%360; h2p=math.degrees(math.atan2(b2,a2p))%360
    dLp=L2-L1; dCp=C2p-C1p
    dhp=0 if C1p*C2p==0 else (h2p-h1p if abs(h2p-h1p)<=180 else (h2p-h1p-360 if h2p-h1p>180 else h2p-h1p+360))
    dHp=2*math.sqrt(C1p*C2p)*math.sin(math.radians(dhp/2))
    Lbp=(L1+L2)/2; Cbp=(C1p+C2p)/2
    hbp=h1p+h2p if C1p*C2p==0 else ((h1p+h2p)/2 if abs(h1p-h2p)<=180 else ((h1p+h2p+360)/2 if h1p+h2p<360 else (h1p+h2p-360)/2))
    T=1-0.17*math.cos(math.radians(hbp-30))+0.24*math.cos(math.radians(2*hbp))+0.32*math.cos(math.radians(3*hbp+6))-0.20*math.cos(math.radians(4*hbp-63))
    dth=30*math.exp(-((hbp-275)/25)**2); RC=2*math.sqrt(Cbp**7/(Cbp**7+25**7))
    SL=1+0.015*(Lbp-50)**2/math.sqrt(20+(Lbp-50)**2); SC=1+0.045*Cbp; SH=1+0.015*Cbp*T; RT=-math.sin(math.radians(2*dth))*RC
    return math.sqrt((dLp/SL)**2+(dCp/SC)**2+(dHp/SH)**2+RT*(dCp/SC)*(dHp/SH))
W = [(c['name'], c['hex'], hex2lab(c['hex']), c['combinations']) for c in d]
def nearest(h):
    l = hex2lab(h); return min(((de2000(l, w[2]), w[0], w[1]) for w in W))
ours = {'dark': dict(ground='0f0e0c', surface='161411', edge2='3d372f', faint='5f584c', muted='877f6f', text='cfc3a6', strong='ece3cc', accent='d0583a', asagi='7fb8b0', green='8e9a5b', yellow='d29f45', blue='5f7fa0', purple='9079a9'),
        'light': dict(ground='e9e1cb', surface='dcd2b8', edge2='b1a688', faint='9b927e', muted='5f594d', text='2b2721', accent='c0462a', asagi='2f6e67')}
for m, toks in ours.items():
    print(f"== {m}: our token → nearest Wada (ΔE2000)")
    for k, h in toks.items():
        de, n, wh = nearest('#'+h); print(f"  {k:8} #{h} → {n:28} {wh}  ΔE {de:5.1f}")
print("== darkest 12 Wada colours (L*)")
for n, h, l, _ in sorted(W, key=lambda w: w[2][0])[:12]: print(f"  L {l[0]:5.1f}  {h}  {n}")
print("== lightest 10")
for n, h, l, _ in sorted(W, key=lambda w: -w[2][0])[:10]: print(f"  L {l[0]:5.1f}  {h}  {n}")
ver = [w for w in W if 15 <= (math.degrees(math.atan2(w[2][2], w[2][1])) % 360) <= 45 and math.hypot(w[2][1], w[2][2]) > 45 and 40 < w[2][0] < 65]
print("== vermilions (hue 15–45°, chroma > 45, L 40–65):", ", ".join(f"{n} {h}" for n, h, _, _ in ver))
combos = {}
for n, h, l, cs in W:
    for k in cs: combos.setdefault(k, []).append((n, h))
vnames = {n for n, *_ in ver}
print("== combinations with a vermilion and a near-black (L < 25):")
dark = {w[0] for w in W if w[2][0] < 25}
for k, cs in sorted(combos.items()):
    names = {n for n, _ in cs}
    if names & vnames and names & dark: print(f"  #{k}: " + " · ".join(f"{n} {h}" for n, h in cs))
