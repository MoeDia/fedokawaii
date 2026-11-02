#!/usr/bin/env bash
# tests/menus/test_panel.sh — kawa-panel, quick settings (the dial), the sound panel and the
# brightness slider on screen. Its window needs a screen,
# so what is tested is everything but the drawing (which the real one is measured for in
# docs/build: placement 8 px under the bar and from the edge, the 8 × 20 grid of
# docs/design-system.md §3, the dial of §4): the layout (the dial: twelve hours on a circle, the
# two arcs of twenty beads inside them, the four corners and the middle — every place evenly
# spaced and symmetric to the pixel —, the frame's box and the shadow that makes the window),
# the hours' pictures and words for each state, the keys (the arrows walk the dial, Tab goes
# round) and the mouse, what each choice runs, the meters (the arcs' beads, the sound panel's
# and the slider's segments: the level a click, a drag or the wheel means, one level at a
# time), opening and closing (its key,
# Esc, a click outside — and the click on the bar's cat that made that click outside), the bar's
# cat lit while open, the theme's colours, the pid file and its key, and the one light (§5): the
# pointer moves the cursor in every panel and menu (look(): what each item is drawn with — the
# pointer adds nothing of its own — and only the items that changed redrawn). Then the two
# other panels (--sound, --brightness): their layouts, what each choice runs, one panel at a
# time, each its own marker and poke on every way in and out, the pointer's enter and leave,
# and every open starting afresh (no cursor, nothing hot, no drag remembered). The menus' own
# grid (a heading's air, rows, keys, the calendar's days), their whole-cell width and the
# chosen one's dot. The module is loaded with a stand-in for gi (it is imported only to draw).
. "$(dirname "$0")/../lib/harness.sh"
command -v python3 >/dev/null || { echo "test_panel: skipped — needs python3"; exit 0; }
sandbox
config .config/fedokawaii

P=$TMP/panel; mkdir -p "$P/gi/repository"
cat >"$P/gi/__init__.py" <<'EOF'
def require_version(*a): pass
EOF
cat >"$P/gi/repository/__init__.py" <<'EOF'
class _Any:
    def __init__(self, *a, **k): pass
    def __call__(self, *a, **k): return _Any()
    def __getattr__(self, n): return _Any()
Gtk = Gdk = Gio = GLib = GLibUnix = GtkLayerShell = Pango = PangoCairo = _Any()
EOF
# py CODE — CODE run with kp (the module) and a fresh panel `p` on a stand-in ui `u`
# (u.calls: what it was asked; u.t: the clock), its output printed
py() {
  python3 -I - "$REPO/bin/kawa-panel" "$P" "$1" <<'EOF'
import importlib.machinery, importlib.util, json, sys
sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[2])
loader = importlib.machinery.SourceFileLoader("kawa_panel", sys.argv[1])
spec = importlib.util.spec_from_loader("kawa_panel", loader)
kp = importlib.util.module_from_spec(spec); loader.exec_module(kp)
import os                                      # (the pictures' ink table: the repository's, as installed)
kp.CRESTS = os.path.join(os.path.dirname(os.path.dirname(sys.argv[1])), "configs/home/.local/share/fedokawaii/crests")
class UI:
    def __init__(self): self.calls, self.t, self.pending, self.drawn, self.at, self.cid = [], 100.0, [], [], None, None; self.pushed = []; self.timers = []; self.ticks = []
    def clicked(self): return self.at
    def click(self): return self.cid             # the bar's last press, fresh (its id), or None
    def push(self, name, line): self.pushed.append((name, line))
    def now(self): return self.t
    def redraw(self, *items): self.calls.append("redraw"); self.drawn.append([i.key for i in items] or "all")
    def show(self): self.calls.append("show")
    def hide(self): self.calls.append("hide")
    def light(self, mode, on): self.calls.append(f"light {mode} {'on' if on else 'off'}")
    def run(self, argv, done): self.calls.append("run " + " ".join(argv)); self.pending.append(done)
    def launch(self, argv): self.calls.append("launch " + " ".join(argv))
    def later(self, ms, fn): self.calls.append(f"later {ms}"); self.timers.append(fn)
    def frames(self, fn): self.calls.append("frames"); self.ticks.append(fn)
    def answer(self, out="", rc=0):            # the oldest run comes back
        self.pending.pop(0)(rc, out)
STATE = ("theme\tdark\nbrightness\t70%\nnight\ton\nvrr\tin games\nwallpaper\tmishima-mist\nsound\t62%\n"
         "nettype\twifi\nnetwork\tHome Net 5G\nbluetooth\ton\ndevices\tnone\ndrives\tKINGSTON 58G\n"
         "backup\t3 days ago\ndnd\toff\n")
u = UI(); p = kp.Panel(u)
# (the owner's machine: an MSI board's ALC1220 behind the Ryzen's HD audio controller, an RX
# 9060 XT's HDMI to an LG ULTRAGEAR — kawa-quick --state sound's lines as it prints them)
RYZEN = "Ryzen HD Audio Controller"
SOUND = ("sound\t62%\nmuted\toff\nmic\ton\n"
         f"output\t62\t1\t{RYZEN} Analog Stereo\tLine Out\tALC1220 Analog\t{RYZEN}\tAnalog Stereo\talsa\n"
         "output\t73\t0\tNavi 48 HDMI/DP Audio Controller Digital Stereo (HDMI)\tHDMI / DisplayPort\tLG ULTRAGEAR\t"
         "Navi 48 HDMI/DP Audio Controller\tDigital Stereo (HDMI)\talsa\n"
         f"input\t67\t1\t{RYZEN} Analog Stereo\tRear Microphone\tALC1220 Analog\t{RYZEN}\tAnalog Stereo\talsa\n"
         f"input\t90\t0\t{RYZEN} Analog Stereo\tFront Microphone\tALC1220 Analog\t{RYZEN}\tAnalog Stereo\talsa\n")
def fresh(state=STATE):
    global u, p
    u = UI(); p = kp.Panel(u); p.refresh(); u.answer(state); u.calls.clear()
def opened(mode, state):                       # the panel open in mode, its state read
    fresh(); p.request(mode); u.answer(state); u.calls.clear(); u.drawn.clear()
def bead(key, j):                              # the centre pixel of an arc's bead j (0: the lowest)
    return kp.bead_at(p.item(key), j)
exec(sys.argv[3])
EOF
}

# ── the layout ─────────────────────────────────────────────────────────────────────────
case_ "the items, in order: the twelve hours (the theme at twelve, then clockwise — bluetooth and devices with an adapter), the two arcs (brightness, sound), the four corners"
eq "$(py 'fresh(); print(" ".join(i.key for i in p.items))')" \
  "theme night vrr saver dnd network bluetooth devices drives backup record ocr brightness sound screenshot wallpaper screenoff power"
eq "$(py 'fresh(STATE.replace("bluetooth\ton\n","").replace("devices\tnone\n","")); print(" ".join(i.key for i in p.items))')" \
  "theme night vrr saver dnd network drives backup record ocr brightness sound screenshot wallpaper screenoff power"
eq "$(py 'fresh(); print("".join(i.kind[0] for i in p.items))')" "hhhhhhhhhhhhaacccc" "twelve hours, two arcs, four corners"
eq "$(py 'print(" ".join(kp.HOURS)); print(" ".join(f"{k}:{ic}" for k, ic, n in kp.CORNERS))')" \
  "$(printf '%s\n' "theme night vrr saver dnd network bluetooth devices drives backup record ocr" "screenshot:camera wallpaper:picture screenoff:screen_off power:power")" \
  "the hours from twelve o'clock, clockwise; the corners from the top left, row by row, each its picture"
case_ "the captures: record (on while one runs: a click stops it) and read text, each closing the panel for its own picker"
eq "$(py 'fresh(); t = p.item("record"); print(t.icon, t.value, t.lit, p.item("ocr").icon, p.item("ocr").name)')" "tile_record off False tile_read read text"
eq "$(py 'fresh(STATE + "record\ton\n"); t = p.item("record"); print(t.value, t.lit)')" "recording True"
eq "$(py 'fresh(); p.request(); p.activate("record"); p.activate("ocr"); print([c for c in u.calls if c.startswith("launch")], p.visible)')" "['launch kawa-quick --do record', 'launch kawa-quick --do ocr'] False"
case_ "the size: 338 × 338 — the dial's square (304: 38 cells, the grid's one stated exception) in 16 px of pad and the 1 px hairline; no heading, no rule, no day line: the bar's"
eq "$(py 'fresh(); print(*p.size)')" "338 338"
eq "$(py 'print(kp.DIAL, kp.DIAL // kp.CELL, kp.DIAL + 2 * (kp.PAD + kp.BORDER), kp.BORDER, kp.HAIR, kp.PAD)')" "304 38 338 1 1 16" "304 of dial, 2 × 16 of pad, 2 × 1 of hairline"
eq "$(py 'fresh(); print(p.head, p.heads, p.rules, p.nones, p.marks, p.view)')" "(17, 17) [] [] [] [] None" "the content starts 17 px from every edge; nothing is drawn but the items and the middle"
eq "$(py 'print(kp.INNER, kp.INNER + 2 * (kp.PAD + kp.BORDER))')" "376 410" "the sound panel and the launcher keep their 376 of content: 410 across"
case_ "the window is the frame's box and its shadow — a column at its right, two rows under it (339 × 340) — and never trimmed to its ink"
eq "$(py 'fresh(); print(*p.win, p.ox, p.dy, kp.SHADOW_R, kp.SHADOW_B)')" "339 340 0 0 1 2"
eq "$(py 'fresh(); print(p.win == (p.size[0] + kp.SHADOW_R, p.size[1] + kp.SHADOW_B), p.rules); opened("sound", SOUND); print(p.win == (p.size[0] + 1, p.size[1] + 2), p.rules); opened("brightness", "brightness\t70%\n"); print(p.win == (p.size[0] + 1, p.size[1] + 2), p.rules, p.dy)')" "$(printf '%s\n' "True []" "True []" "True [] 0")" "every panel the same: the box + 1 column, + 2 rows — no trimming (dy 0), nothing drawn between the groups"
case_ "it opens under no heading — the square is the dial's: the mood's face at its middle, at rest, says whose it is (one picture, the theme's own, drawn in one place)"
eq "$(py 'fresh(); print(p.heads, p.rules)')" "[] []"
eq "$(py 'print(kp.FACE.endswith("/.config/fedokawaii/current/face-big.png"), hasattr(kp, "FACE_X"))')" "True False" "the face (open: the panel is) as the theme has it, the bar's 18 × 18 three times as large"
eq "$(grep -c 'face_pic()' "$REPO/bin/kawa-panel")" 2 "defined once, used once: the dial's middle at rest"
case_ "notices are as wide as the sound panel: one column under the bar's right end (mako's 410 — the dial is narrower, it is no measure)"
has "$(cat "$REPO/configs/home/.config/mako/config")" "width=$(py 'opened("sound", SOUND); print(p.size[0])')"
case_ "the dial's hours (§4): twelve places of 36 × 36 on a circle, the theme's centred 128 px above the dial's middle (169, 169), the others clockwise; a place's 28 px picture centred in it (4 px of lacquer round it, to the pixel)"
eq "$(py 'fresh(); print(" ".join(f"{i.key}:{i.x},{i.y}" for i in p.items if i.kind == "hour"))')" \
  "theme:151,23 night:215,40 vrr:262,87 saver:279,151 dnd:262,215 network:215,262 bluetooth:151,279 devices:87,262 drives:40,215 backup:23,151 record:40,87 ocr:87,40"
eq "$(py 'fresh(); print({(i.w, i.h) for i in p.items if i.kind == "hour"}, [i.order for i in p.items if i.kind == "hour"])')" "{(36, 36)} [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]"
eq "$(py 'print(kp.HOUR, kp.DIAL_R, kp.CREST_PIC, (kp.HOUR - kp.CREST_PIC) % 2 == 0)')" "36 128 28 True" "the place 36, its picture 28: 4 px of lacquer all round"
eq "$(py 'fresh(); print(" ".join(f"{i.key}:{i.centre():g},{kp.mid_y(i):g}" for i in p.items if i.kind in ("hour", "corner")))')" \
  "theme:169,41 night:233,58 vrr:280,105 saver:297,169 dnd:280,233 network:233,280 bluetooth:169,297 devices:105,280 drives:58,233 backup:41,169 record:58,105 ocr:105,58 screenshot:31,31 wallpaper:307,31 screenoff:31,307 power:307,307" \
  "their middles, where the arrows measure from (centre(), mid_y()); the arcs' are below"
case_ "the hours are spaced evenly: 360 / n degrees apart, clockwise from twelve (30 with twelve, 36 with ten — no adapter), each 128 px from the middle, to the pixel's rounding"
eq "$(py 'out = []
for st in (STATE, STATE.replace("bluetooth\ton\n", "").replace("devices\tnone\n", "")):
    fresh(st); hs = [i for i in p.items if i.kind == "hour"]; n = len(hs)
    r = [kp.math.hypot(i.centre() - 169, kp.mid_y(i) - 169) for i in hs]
    a = [(kp.math.degrees(kp.math.atan2(i.centre() - 169, 169 - kp.mid_y(i))) - 360 * k / n + 180) % 360 - 180 for k, i in enumerate(hs)]
    out.append((n, max(abs(x - kp.DIAL_R) for x in r) < 0.5, max(abs(x) for x in a) < 0.5))
print(out)')" "[(12, True, True), (10, True, True)]"
case_ "no adapter: ten hours (no bluetooth, no devices), the theme still at twelve — the arcs and the corners where they were, the square as big"
eq "$(py 'fresh(STATE.replace("bluetooth\ton\n","").replace("devices\tnone\n","")); print(" ".join(f"{i.key}:{i.x},{i.y}" for i in p.items if i.kind == "hour"), p.size)')" \
  "theme:151,23 night:226,47 vrr:273,111 saver:273,191 dnd:226,255 network:151,279 drives:76,255 backup:29,191 record:29,111 ocr:76,47 (338, 338)"
eq "$(py 'def rest(): return [(i.key, i.x, i.y, i.w, i.h) for i in p.items if i.kind != "hour"]
fresh(); a = rest(); fresh(STATE.replace("bluetooth\ton\n","").replace("devices\tnone\n","")); print(a == rest(), len(a))')" "True 6"
case_ "the dial is symmetric to the pixel: every hour's box mirrored across the vertical through the middle (x → 338 − x − w) is its partner's, and across the horizontal (y → 338 − y − h) too — with twelve and with ten; the arcs, the corners and the middle likewise"
eq "$(py 'out = []
for st in (STATE, STATE.replace("bluetooth\ton\n", "").replace("devices\tnone\n", "")):
    fresh(st); hs = [i for i in p.items if i.kind == "hour"]; at = {(i.x, i.y): i.key for i in hs}
    out.append(" ".join(f"{i.key}:{at.get((338 - i.x - i.w, i.y))}" for i in hs))
    out.append(" ".join(f"{i.key}:{at.get((i.x, 338 - i.y - i.h))}" for i in hs))
print("\n".join(out))')" "$(printf '%s\n' \
  "theme:theme night:ocr vrr:record saver:backup dnd:drives network:devices bluetooth:bluetooth devices:network drives:dnd backup:saver record:vrr ocr:night" \
  "theme:bluetooth night:network vrr:dnd saver:saver dnd:vrr network:night bluetooth:theme devices:ocr drives:record backup:backup record:drives ocr:devices" \
  "theme:theme night:ocr vrr:record saver:backup dnd:drives network:network drives:dnd backup:saver record:vrr ocr:night" \
  "theme:network night:dnd vrr:saver saver:vrr dnd:night network:theme drives:ocr backup:record record:backup ocr:drives")" \
  "left↔right then top↔bottom, twelve then ten: theme↔bluetooth on the axis, night↔ocr, vrr↔record, night↔network …"
eq "$(py 'fresh(); a = {i.key: i for i in p.items}; c = p.centre; box = lambda i: (i.x, i.y, i.w, i.h)
lr = lambda i: (338 - i.x - i.w, i.y, i.w, i.h); tb = lambda i: (i.x, 338 - i.y - i.h, i.w, i.h)
print(lr(a["brightness"]) == box(a["sound"]), tb(a["brightness"]) == box(a["brightness"]), tb(a["sound"]) == box(a["sound"]),
      lr(a["screenshot"]) == box(a["wallpaper"]), tb(a["screenshot"]) == box(a["screenoff"]), lr(a["screenoff"]) == box(a["power"]), tb(a["wallpaper"]) == box(a["power"]),
      lr(c) == box(c) == tb(c))')" "True True True True True True True True" "the arcs mirror each other and each is its own top-bottom mirror; the corners' places mirror in pairs; the middle is its own"
eq "$(py 'bad = []
for d in range(0, 361, 3):
    x, y = kp.on_circle(169, 169, kp.DIAL_R, d); xr, yr = kp.on_circle(169, 169, kp.DIAL_R, 360 - d); xb, yb = kp.on_circle(169, 169, kp.DIAL_R, 180 - d)
    if (x + xr, y - yr, x - xb, y + yb) != (338, 0, 0, 338): bad.append(d)
print(bad, *[kp.on_circle(169, 169, kp.DIAL_R, d) for d in (0, 90, 180, 270)])')" "[] (169, 41) (297, 169) (169, 297) (41, 169)" "on_circle, every 3 degrees: the same pixel both sides of the upright and of the horizontal (each half rounded once, the other its mirror)"
case_ "the two arcs (§4): brightness up the left, sound up the right — a box 75 × 196 each, round its twenty beads and the cursor's band; its middle (the circle's crown) 88 px from the dial's, level with it"
eq "$(py 'fresh(); print(" ".join(f"{i.key}:{i.x},{i.y},{i.w},{i.h}:{i.side}:{i.centre()}:{kp.mid_y(i)}" for i in p.items if i.kind == "arc"))')" \
  "brightness:71,71,75,196:-1:81:169 sound:192,71,75,196:1:257:169"
eq "$(py 'print(kp.BEAD_R, kp.BEAD, kp.BEAD_FROM, kp.BEAD_RUN, kp.BAND, kp.SEGS)')" "88 6 22 136 10 20" "a circle of 88; beads 6 px round, twenty, the first 22° up from six o'clock, the last 136° further; the band 10 px"
case_ "an arc's beads: twenty on the circle, the lowest (0) to the highest (19) — brightness (136, 251) · (81, 174) · (136, 87), sound (202, 251) · (257, 174) · (202, 87) for beads 0, 9 and 19 — the arcs mirror images to the pixel, no two touching, all inside their box"
eq "$(py 'fresh(); print([bead("brightness", j) for j in (0, 9, 19)], [bead("sound", j) for j in (0, 9, 19)])')" \
  "[(136, 251), (81, 174), (136, 87)] [(202, 251), (257, 174), (202, 87)]"
eq "$(py 'fresh(); print(all(bead("brightness", j)[0] + bead("sound", j)[0] == 338 and bead("brightness", j)[1] == bead("sound", j)[1] for j in range(20)))')" True "x + x = 338 and the same y, for every bead"
eq "$(py 'fresh(); print([min(kp.math.hypot(bead(k, j + 1)[0] - bead(k, j)[0], bead(k, j + 1)[1] - bead(k, j)[1]) for j in range(19)) for k in ("brightness", "sound")])')" "[10.0, 10.0]" "10 px apart at least: 4 px of air between two 6 px beads"
eq "$(py 'fresh(); out = []
for k in ("brightness", "sound"):
    a = p.item(k); xs = [bead(k, j)[0] for j in range(20)]; ys = [bead(k, j)[1] for j in range(20)]
    out.append(a.x <= min(xs) - kp.BEAD // 2 and max(xs) + kp.BEAD // 2 <= a.x + a.w and a.y <= min(ys) - kp.BEAD // 2 and max(ys) + kp.BEAD // 2 <= a.y + a.h)
print(out)')" "[True, True]" "every bead inside its arc's box (what a redraw of it covers)"
eq "$(py 'fresh(); bad = []; step = kp.BEAD_RUN / (kp.SEGS - 1)
for k in ("brightness", "sound"):
    a = p.item(k)
    for y in range(a.y - 20, a.y + a.h + 20):
        for x in range(a.x - 20, a.x + a.w + 20):
            ang, r = kp.arc_polar(a, x, y)
            if ang is not None and abs(r - kp.BEAD_R) <= kp.BAND / 2 and kp.BEAD_FROM - step / 2 <= ang <= kp.BEAD_FROM + kp.BEAD_RUN + step / 2 and not kp.Item.inside(a, x, y):
                bad.append((k, x, y))
print(bad[:3])')" "[]" "…and the cursor's lacquer band (BAND px along the circle) too: no pixel of it outside the box, none left stale"
case_ "the four corners (screenshot, wallpaper, screen off, power): places of 36 × 36 flush with the content's corners, 4 px into the pad — mirror images —, each picture's ink centred in its place (pic_ink: crests/ink.txt; its odd pixel of air right and below); their names and states are the middle's"
eq "$(py 'fresh(); print(" ".join(f"{i.key}:{i.x},{i.y},{i.w}x{i.h}:{i.icon}:{i.name}" for i in p.items if i.kind == "corner"))')" \
  "screenshot:13,13,36x36:camera:screenshot wallpaper:289,13,36x36:picture:wallpaper screenoff:13,289,36x36:screen_off:screen off power:289,289,36x36:power:power"
eq "$(py 'fresh(); out = []
for i in [i for i in p.items if i.kind == "corner"]:
    ix, iy, iw, ih = kp.pic_ink(i.icon); x0, y0 = i.pic[0] + ix, i.pic[1] + iy; x1, y1 = x0 + iw - 1, y0 + ih - 1
    out.append((x0 - 17 if i.x < 169 else 320 - x1, y0 - 17 if i.y < 169 else 320 - y1, (x0 - i.x) - (i.x + i.w - 1 - x1), (y0 - i.y) - (i.y + i.h - 1 - y1)))
print(out)')" "[(2, 4, 0, 0), (2, 4, 0, 0), (2, 4, 0, 0), (3, 3, 0, -1)]" "the framed pictures' ink 2 from the sides and 4 from top or foot, the round power sign's 3 and 3; every ink centred in its place (power's odd row below)"
eq "$(py 'fresh(); print([(p.item(k).tip, p.item(k).value) for k in ("screenshot", "wallpaper", "screenoff", "power")])')" "[('', ''), ('', 'mishima-mist'), ('', ''), ('', '')]" "no words under a corner and no tooltip beside the pointer (one light): the middle says it — the wallpaper's name its second row"
case_ "the dial's middle (the echo): a place of its own, 156 × 156 round the middle, inside the beads' circle less the band — no item (no cursor, nothing to choose): the face at rest, the item the cursor is on, larger, with its name and state"
eq "$(py 'fresh(); c = p.centre; print(c.key, c.kind, c.x, c.y, c.w, c.h, c in p.items, c.x + c.w // 2, c.y + c.h // 2)')" "centre centre 91 91 156 156 False 169 169"
eq "$(py 'fresh(); c = p.centre; print(c.x + c.w + c.x == 338, c.y + c.h + c.y == 338, c.w == c.h == 2 * (kp.BEAD_R - kp.BAND), c.x == 169 - kp.BEAD_R + kp.BAND)')" "True True True True" "symmetric round the middle: its box mirrored is itself"
eq "$(py 'fresh(); print(sorted({p.at(x, y) is None for x in range(99, 240) for y in range(99, 240) if kp.math.hypot(x + .5 - 169, y + .5 - 169) < 70}))')" "[True]" "nothing is chosen in the middle (70 px round it, the arcs' hit reach starting at 76)"
case_ "one pixel, one item: no two items' places overlap — a click means one thing (twelve and ten hours) — and every place lies inside the frame's pad (13–325: the corners' lacquer 4 px past the content)"
eq "$(py 'out = []
for st in (STATE, STATE.replace("bluetooth\ton\n", "").replace("devices\tnone\n", "")):
    fresh(st); multi = [(x, y) for x in range(338) for y in range(338) if sum(i.inside(x, y) for i in p.items) > 1]
    out.append((len(multi), min(i.x for i in p.items), min(i.y for i in p.items), max(i.x + i.w for i in p.items), max(i.y + i.h for i in p.items)))
print(out)')" "[(0, 13, 13, 325, 325), (0, 13, 13, 325, 325)]"
case_ "an arc's pointer (arc_level): on a bead the level of that bead — 5 % each, the first 5, the last 100 —, a bead's spacing below the first 0 (above the last 100); held (a drag) anywhere on its side, past an end that end; across the dial, held, the nearer end (0 below the middle, 100 above); off its circle, not held: none"
eq "$(py 'fresh(); print([[kp.arc_level(p.item(k), *bead(k, j)) for j in range(20)] == [5 * (j + 1) for j in range(20)] and all(p.item(k).inside(*bead(k, j)) for j in range(20)) for k in ("brightness", "sound")])')" "[True, True]" "a click on bead j is 5 · (j + 1) % — on both arcs"
eq "$(py 'fresh(); print([(kp.arc_level(p.item(k), *kp.bead_at(p.item(k), -0.75)), kp.arc_level(p.item(k), *kp.bead_at(p.item(k), 19.75))) for k in ("brightness", "sound")])')" "[(0, 100), (0, 100)]" "three quarters of a bead's spacing below the first: 0; above the last: 100"
eq "$(py 'fresh(); b, s = p.item("brightness"), p.item("sound"); print([kp.arc_level(a, x, y, True) for a, x, y in ((b, 150, 330), (b, 150, 5), (s, 190, 330), (s, 190, 5), (b, 300, 300), (b, 300, 20), (s, 20, 300), (s, 20, 20))])')" \
  "[0, 100, 0, 100, 0, 100, 0, 100]" "held: past the foot 0, past the crown 100; across the dial the nearer end"
eq "$(py 'fresh(); b, s = p.item("brightness"), p.item("sound"); print([kp.arc_level(b, *bead("sound", 9)), kp.arc_level(s, *bead("brightness", 9)), kp.arc_level(b, 169, 169), kp.arc_level(s, 169, 120), kp.arc_level(b, 5, 5), kp.arc_level(s, 400, 300)])')" \
  "[None, None, None, None, None, None]" "not held, off its circle: the other arc's beads, the middle, the air between, the frame, outside — none"
eq "$(py 'fresh(); s, b = p.item("sound"), p.item("brightness"); print([s.inside(257 + d, 169) for d in (-14, -10, 0, 10, 14)], [b.inside(81 + d, 169) for d in (-14, -10, 0, 10, 14)], s.inside(81, 169), b.inside(257, 169))')" \
  "[False, True, True, True, False] [False, True, True, True, False] False False" "the pointer is on an arc within 12 px (HOUR / 3) of its circle, not on the other side"
eq "$(py 'fresh(); print([[a.inside(*kp.bead_at(a, j)) for j in (-1.3, -0.8, 19.8, 20.3)] for a in (p.item("brightness"), p.item("sound"))])')" "[[False, True, True, False], [False, True, True, False]]" "…and within a bead's spacing beyond either end of its run, no further"
eq "$(py 'fresh(); print(p.at(73, 73), p.at(*bead("sound", 9)).key)')" "None sound" "an arc's box is for redrawing only: a point in it, off its circle, is no click"
eq "$(py 'fresh(); s = p.item("sound"); x, y = bead("sound", 12); print(p.meter_at(s, x, y=y), p.meter_at(s, 20, held=True, y=330), p.meter_at(s, 20, y=330), kp.arc_level(s, x, y))')" "65 0 None 65" "Panel.meter_at(an arc, x, y=…) is arc_level: the same levels, held or not"
case_ "the grid's own constants (the sound panel's, the slider's and the menus': the dial stands outside it)"
eq "$(py 'print(kp.HEAD_H, kp.SECTION, kp.KEY_H, kp.METER_GAP, kp.GAP, hasattr(kp, "GROUP"))')" "28 20 20 0 8 False" "a heading 28, 20 of air above one that is not first, keys 20, rows touching (the sheet's groups gone with it)"

# ── the hours' pictures and words ───────────────────────────────────────────────────────
t() { py "fresh($1); i = p.item('$2'); print(i.icon, i.name, '|', i.value, '|', 'lit' if i.lit else 'quiet')"; }
case_ "each hour: its own picture (a tile_ name: the file of its mask), its name, how it stands; lit while it is on"
eq "$(t '' theme)" "tile_moon theme | dark | lit"
eq "$(t 'STATE.replace("theme\tdark","theme\tlight")' theme)" "tile_sun theme | light | lit" "light: the rising sun"
eq "$(t '' night)" "tile_lantern night light | on | lit"
eq "$(t 'STATE.replace("night\ton","night\toff")' night)" "tile_lantern night light | off | quiet"
eq "$(t 'STATE.replace("night\ton","night\t3500K")' night)" "tile_lantern night light | 3500K | lit" "on: its warmth"
eq "$(t 'STATE + "saver\t15 min\n"' saver)" "tile_saver screensaver | 15 min | lit"
eq "$(t 'STATE + "saver\toff\n"' saver)" "tile_saver screensaver | off | quiet"
eq "$(t '' vrr)" "tile_wave freesync | in games | lit"
eq "$(t 'STATE.replace("vrr\tin games","vrr\toff")' vrr)" "tile_wave freesync | off | quiet"
case_ "FreeSync's hour: the setting and the card's own state this moment (vrrnow), lit only while on"
eq "$(t 'STATE + "vrrnow\toff\n"' vrr)" "tile_wave freesync | games · off | quiet"
eq "$(t 'STATE + "vrrnow\ton\n"' vrr)" "tile_wave freesync | games · on | lit"
eq "$(t 'STATE.replace("vrr\tin games","vrr\talways") + "vrrnow\ton\n"' vrr)" "tile_wave freesync | always · on | lit"
eq "$(t 'STATE + "vrrnow\tnone\n"' vrr)" "tile_wave freesync | not offered | quiet"
eq "$(t 'STATE.replace("vrr\tin games","vrr\toff") + "vrrnow\toff\n"' vrr)" "tile_wave freesync | off | quiet"
case_ "the network hour's picture follows the kind of link: wired, Wi-Fi, none"
eq "$(t '' network)" "tile_wifi network | Home Net 5G | lit"
eq "$(t 'STATE.replace("nettype\twifi","nettype\tethernet").replace("Home Net 5G","wired")' network)" "tile_ethernet network | wired | lit"
eq "$(t 'STATE.replace("nettype\twifi","nettype\toffline").replace("Home Net 5G","offline")' network)" "tile_offline network | offline | quiet"
case_ "bluetooth, devices, drives, backup, do not disturb: each its own picture; the quiet bell once do not disturb is on"
eq "$(t '' bluetooth)" "tile_bluetooth bluetooth | on | lit"
eq "$(t '' devices)" "tile_devices devices | none | quiet"
eq "$(t 'STATE.replace("devices\tnone","devices\tWH-1000XM5")' devices)" "tile_devices devices | WH-1000XM5 | lit"
eq "$(t '' drives)" "tile_drive drives | KINGSTON 58G | lit"
eq "$(t 'STATE.replace("KINGSTON 58G","none")' drives)" "tile_drive drives | none | quiet"
eq "$(t '' backup)" "tile_backup backup | 3 days ago | lit"
eq "$(t 'STATE.replace("3 days ago","never")' backup)" "tile_backup backup | never | quiet"
eq "$(t '' dnd)" "tile_bell dnd | off | quiet"
eq "$(t 'STATE.replace("dnd\toff","dnd\ton")' dnd)" "tile_bell_off dnd | on | lit"
case_ "tiles_of: (key, picture, name, value, on) — five fields; every picture a crest of its own and no two alike (sixteen drawings over every state)"
eq "$(py 'S = [STATE.replace("theme\tdark", "theme\tlight"), STATE, STATE.replace("nettype\twifi", "nettype\tethernet"), STATE.replace("nettype\twifi", "nettype\toffline"), STATE.replace("dnd\toff", "dnd\ton")]
rows = [t for st in S for t in kp.tiles_of(kp.parse_state(st))]
pics = sorted({t[1] for t in rows})
print({len(t) for t in rows}, len(pics))
print(" ".join(pics))')" \
  "$(printf '%s\n' "{5} 16" "tile_backup tile_bell tile_bell_off tile_bluetooth tile_devices tile_drive tile_ethernet tile_lantern tile_moon tile_offline tile_read tile_record tile_saver tile_sun tile_wave tile_wifi")"
case_ "the pictures (art/crests.txt → tools/build-icons.py): one drawing and one 28 × 28 mask for each picture an hour can wear (its icon less tile_: sixteen over every state) and each corner's (camera, picture, screen-off, power) — twenty — and the record hour's second frame (record-2, its reels turned), nothing else"
want="backup bell bell-off bluetooth camera devices drive ethernet lantern moon offline picture power read record saver screen-off sun wave wifi"
eq "$(grep '^@' "$REPO/art/crests.txt" | cut -c2- | sort | tr '\n' ' ' | sed 's/ $//')" "$(tr ' ' '\n' <<<"$want record-2" | sort | tr '\n' ' ' | sed 's/ $//')" "drawn: one each, and the reels' second frame"
eq "$(cd "$REPO/configs/home/.local/share/fedokawaii/crests" && ls -- *.png | sed 's/\.png$//' | sort | tr '\n' ' ' | sed 's/ $//')" "$(tr ' ' '\n' <<<"$want record-2" | sort | tr '\n' ' ' | sed 's/ $//')" "built: one mask each, no stale one"
eq "$(py 'S = [STATE.replace("theme\tdark", "theme\tlight"), STATE, STATE.replace("nettype\twifi", "nettype\tethernet"), STATE.replace("nettype\twifi", "nettype\toffline"), STATE.replace("dnd\toff", "dnd\ton")]
names = {t[1].removeprefix("tile_").replace("_", "-") for st in S for t in kp.tiles_of(kp.parse_state(st))} | {c[1].replace("_", "-") for c in kp.CORNERS}
print(" ".join(sorted(names)))')" "$want" "every picture an item can wear is one of them, and each is worn: a corner's icon becomes its file's name the same way (screen_off → screen-off)"
eq "$(python3 -I -c 'import struct, sys
for f in sys.argv[1:]:
    b = open(f, "rb").read(26)
    print(b[:8] == b"\x89PNG\r\n\x1a\n", struct.unpack(">II", b[16:24]), b[24:26])' "$REPO"/configs/home/.local/share/fedokawaii/crests/*.png | sort -u)" "True (28, 28) b'\x08\x04'" "every one a PNG 28 × 28, 8-bit grey and alpha (a mask)"
eq "$(py 'print(kp.CREST_PIC, kp.CRESTS.endswith("/.local/share/fedokawaii/crests"))')" "28 True"
case_ "the wallpaper's name: the middle's second row under its corner, cut to the middle's width"
eq "$(py 'fresh(); print(p.item("wallpaper").value)')" mishima-mist
eq "$(py 'fresh(STATE.replace("mishima-mist", "a wallpaper with a name much too long for the middle")); v = p.item("wallpaper").value; print(repr(v), kp.px_of(v) <= kp.ECHO_W)')" "'a wallpaper with a' True"
case_ "no day or weather line: the bar's own, right above the panel"
eq "$(py 'fresh(); print(hasattr(kp, "date_line"), [i.key for i in p.items if i.key in ("date", "day", "weather")])')" "False []" "no day or weather line: the bar shows them, right above"
case_ "the icons by name, from icons.sh (none hard-coded): the headings', the meters' and the keys' own, all there"
eq "$(py 'i = kp.icons(); need = ["sliders", "speaker", "speaker_off", "headphones", "mic", "mic_off", "torii_small", "picture", "camera", "power"] + [f"bri_{n}" for n in range(5)] + [f"vol_{n}" for n in range(5)] + ["vol_mute"]; print(len(i) > 40, sorted(k for k in need if k not in i))')" "True []"

# ── opening and closing ───────────────────────────────────────────────────────────────
case_ "its key opens it: it shows, the bar's cat lights, the state is read"
eq "$(py 'fresh(); p.request(); print(", ".join(u.calls))')" "show, light quick on, run kawa-quick --state"
case_ "its key again closes it, the cat dark again"
eq "$(py 'fresh(); p.request(); u.calls.clear(); u.t += 0.6; p.request(); print(", ".join(u.calls), p.visible)')" "hide, light quick off False"
case_ "its key pressed fast (every 30 ms; dwl repeats no held key that opens it): every press counts — open after an odd number, closed after an even one"
eq "$(py 'fresh(); out = []
for i in range(7): p.request(); out.append(p.visible); u.t += 0.03
print(out)')" "[True, False, True, False, True, False, True]"
lacks "$(cat "$REPO/bin/kawa-panel")" "REPEAT"
case_ "a click is never a held key: clicks 120 ms apart each open or close it"
eq "$(py 'fresh(); out = []
for i in range(6): u.cid = f"c{i}"; p.request(); out.append(p.visible); u.t += 0.12
print(out)')" "[True, False, True, False, True, False]"
case_ "another menu's key or the launcher (close): closed as chosen — its key then opens it at once"
eq "$(py 'fresh(); p.request(); u.calls.clear(); p.close("chosen"); u.t += 0.1; p.request(); print(p.visible)')" True
has "$(cat "$REPO/bin/kawa-panel")" 'elif f == ["close"]:'
case_ "its signals through GLibUnix.signal_add (GLib.unix_signal_add is deprecated: a warning in kawa-panel.log at every start)"
lacks "$(cat "$REPO/bin/kawa-panel")" "GLib.unix_signal_add"; has "$(cat "$REPO/bin/kawa-panel")" 'gi.require_version("GLibUnix", "2.0")'
eq "$(grep -c 'GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, ' "$REPO/bin/kawa-panel")" 1
case_ "the bar's cat: lit by a marker of its own (a dropdown's is kawa-drop.open), poked with SIGRTMIN+15"
eq "$(py 'import os; print(os.path.basename(kp.MARK))')" kawa-panel.open
eq "$(py 'print(kp.POKE["quick"], kp.poke_sigs("quick"), kp.poke_sigs("menu kawa-quick"))')" "15 [15] [12]" "the cat's alone: the mode tile (+12) is lit by its own dropdown, do not disturb's"
case_ "the meters: no number beside the slider (the bar shows both levels) — words only when there is no level"
lacks "$(cat "$REPO/bin/kawa-panel")" 'it.key != "sound"'
has "$(python3 -I "$REPO/bin/kawa-panel" --help)" "volume's number are the bar's, right above it" "its help says so: the bar's, right above"
has "$(python3 -I "$REPO/bin/kawa-panel" --help)" "twenty beads each" "…and what the dial's meters are"
case_ "Esc closes it"
eq "$(py 'fresh(); p.request(); u.calls.clear(); p.key("Escape"); print(", ".join(u.calls))')" "hide, light quick off"
case_ "a click outside closes it; when that click was on its own button, the request it makes is that close"
eq "$(py 'fresh(); u.cid = "c1"; p.request(); u.cid = "c2"; p.close("lost"); u.t += 0.01; p.request(); print(p.visible, p.lost)')" "False None"
eq "$(py 'fresh(); u.cid = "c1"; p.request(); u.cid = "c2"; p.close("lost"); p.request(); u.t += 0.1; u.cid = "c3"; p.request(); print(p.visible)')" True \
  "the next click opens it, however soon (no time window)"
eq "$(py 'fresh(); u.cid = "c1"; p.request(); p.close("lost"); u.t += 0.1; u.cid = "c4"; p.request(); print(p.visible)')" True \
  "closed by a click elsewhere (not on the bar: no new press): its button opens it at once"
eq "$(py 'fresh(); p.request(); p.close("lost"); u.t += 0.1; p.request(); print(p.visible)')" True "… and its key"
eq "$(py 'fresh(); u.cid = "c1"; p.request(); u.cid = "c2"; p.close("lost"); p.request("sound"); print(p.mode, p.visible)')" "sound True" \
  "the click outside was on another panel's button: that one opens"
eq "$(py 'fresh(); p.request(); p.close("chosen"); u.t += 0.1; p.request(); print(p.visible)')" True "closed otherwise: its key opens it at once"
case_ "a fast clicker: 40 clicks on a button, in every order the compositor can give them (the click outside reaching the panel before or after the click's own request, or none: not open yet) — open after an odd count, closed after an even one; lit exactly while on screen"
for what in quick sound menu launcher; do
  eq "$(py 'import random
WHAT = "'"$what"'"
random.seed(7); bad = []
for run in range(25):
    fresh(); lit = set()
    u.light = lambda w, on: lit.add(w) if on else lit.discard(w)
    replies = []
    for i in range(40):
        u.cid = f"r{run}c{i}"; u.t += random.choice((0.03, 0.08, 0.12, 0.2))
        if p.visible and random.random() < 0.6:
            p.close("lost")                       # (dwl took the keyboard: the press on the bar)
        if WHAT == "menu":
            p.request("menu kawa-calendar", kp.Menu(["a", "b"], drop=True), lambda rc, t: replies.append(rc))
        elif WHAT == "launcher":                  # (the torii, Super+Space: kawa-menu --launcher, "toggle launcher")
            p.request("launcher", kp.Launcher([], {}), None)
        else:
            p.request(WHAT)
        on = {p.what} if p.visible else set()
        if lit != on: bad.append((run, i, sorted(lit), p.visible))
    if p.visible != (40 % 2 == 1): bad.append((run, "end", p.visible))
print(bad or "ok")')" ok "$what"
done
case_ "the launcher (the torii, Super+Space): in the middle of the screen, its own marker and poke; its key again closes it; pressed fast, every press counts"
eq "$(py 'fresh(); p.request("launcher", kp.Launcher([], {}), None); print(p.visible, p.what, p.mode, p.place, ", ".join(u.calls[:2]))')" \
  "True launcher menu ('centre', 0, None) show, light launcher on"
eq "$(py 'fresh(); out = []
for i in range(7): p.request("launcher", kp.Launcher([], {}), None); out.append(p.visible); u.t += 0.03
print(out)')" "[True, False, True, False, True, False, True]"
eq "$(py 'import os; print(os.path.basename(kp.MARKS["launcher"]), kp.POKE["launcher"])')" "kawa-launcher.open 20" "lit by its marker, the torii's module poked with SIGRTMIN+20"
eq "$(py 'fresh(); p.request("launcher", kp.Launcher([], {}), None); print(p.heads, p.size, p.win, p.rules)')" "[('torii_small', 'launcher', 17, 17)] (410, 302) (411, 304) []" "its heading the small torii; always ten rows tall: 17 + 28 + the line typed on (20) + 20 + 200 + 17 = 302"
eq "$(py 'fresh(); u.cid = "c1"; p.request("launcher", kp.Launcher([], {}), None); u.cid = "c2"; p.close("lost"); u.t += 0.01; p.request("launcher", kp.Launcher([], {}), None); print(p.visible)')" False \
  "the torii clicked while it is open: that click closed it — its own call does not reopen it"
eq "$(py 'fresh(); u.cid = "c1"; p.request("launcher", kp.Launcher([], {}), None); u.cid = "c2"; p.close("lost"); p.request("launcher", kp.Launcher([], {}), None); u.t += 0.1; u.cid = "c3"; p.request("launcher", kp.Launcher([], {}), None); print(p.visible)')" True \
  "the next click opens it, however soon"
eq "$(py 'fresh(); p.request(); p.request("launcher", kp.Launcher([], {}), None); print(p.what, "light quick off" in u.calls)')" "launcher True" "over quick settings: they close, it opens"
eq "$(py 'fresh(); p.request("launcher", kp.Launcher([], {}), None); r = []; p.request("menu kawa-calendar", kp.Menu(["a"], drop=True), lambda rc, t: r.append(rc)); print(p.what, "light launcher off" in u.calls, r)')" \
  "menu kawa-calendar True []" "a dropdown asked for while it is open: the dropdown in its place, the torii dark"
case_ "a menu opens keyboard-first: the cursor on its first choice (or --select's); the pointer moves that one cursor, it stays where the pointer left it"
eq "$(py 'fresh(); p.request("menu x", kp.Menu(["a", "b", "c"]), lambda rc, t: 0); print(p.focus)')" 0
eq "$(py 'fresh(); p.request("menu x", kp.Menu(["a", "b", "c"], select=2), lambda rc, t: 0); print(p.focus)')" 2
eq "$(py 'fresh(); p.request("menu x", kp.Menu(["a", "b", "c"]), lambda rc, t: 0); it = p.item("2"); p.enter(it.x + 2, it.y + 2); a = p.focus; p.leave(); print(a, p.focus, p.hot)')" "2 2 None"
eq "$(py 'fresh(); r = []; p.request("menu x", kp.Menu(["a", "b"]), lambda rc, t: r.append(t)); p.key("Return"); print(r)')" "['a']" "Enter at once takes the first"
case_ "--stay (the calendar's months): a key answers and the menu stays; the next page in place (no close, no new window); a click meanwhile is done on it; nothing asked: closed after a second"
eq "$(py 'fresh(); r = []; M = lambda: kp.Menu(["cell\t1", "key\t<\tprevious", "key\t>\tnext"], drop=True, index=True, stay=True, select=2)
p.request("menu kawa-calendar", M(), lambda rc, t: r.append(t)); u.calls.clear()
p.activate("2"); p.activate("2"); print(r, p.visible, p.queued)
p.request("menu kawa-calendar", M(), lambda rc, t: r.append(t)); print(r, p.visible, p.focus, "show" in u.calls, "hide" in u.calls)
p.request("menu kawa-calendar", M(), lambda rc, t: r.append(t)); p.activate("1"); u.timers[-1](); print(p.visible)')" "$(printf '%s\n' "['2'] True ['2']" "['2', '2'] True 2 False False" False)"
eq "$(py 'fresh(); r = []; p.request("menu kawa-calendar", kp.Menu(["a", "key\t<\tprevious"], index=True, stay=True), lambda rc, t: r.append(t)); p.activate("0"); print(r, p.visible)')" "['0'] False" "a choice (not a key): chosen and closed"
eq "$(py 'fresh(); n = []; u.cid = "c1"; p.request("menu kawa-calendar", kp.Menu(["a"], drop=True), lambda rc, t: n.append(("1st", rc)))
u.cid = "c2"; p.request("menu kawa-calendar", kp.Menu(["a"], drop=True), lambda rc, t: n.append(("2nd", rc))); print(n, p.visible)')" \
  "[('2nd', 1), ('1st', 1)] False" "a menu's button again: both callers dismissed at once, the menu gone"
eq "$(py 'fresh(); n = []; p.request("menu kawa-calendar", kp.Menu(["a"], drop=True), lambda rc, t: n.append(rc))
p.request("menu kawa-weather", kp.Menu(["b"], drop=True), lambda rc, t: n.append(rc)); print(n, p.what, p.visible)')" \
  "[1] menu kawa-weather True" "another script's menu takes its place"
case_ "a meter dragged: every step pushed to the bar's module at once (volume, brightness), before its level is sent"
eq "$(py 'opened("quick", STATE); u.pushed.clear(); p.set_level("sound", 40); p.set_level("sound", 45); p.set_level("brightness", 30); print(u.pushed)')" \
  "[('volume', 'volume 40 0'), ('volume', 'volume 45 0'), ('brightness', '30')]"
case_ "the push itself: a line into each live module's link (kawa-bar.NAME.PID → its fifo), none waiting"
R4=$TMP/push; mkdir -p "$R4"; mkfifo "$R4/kawa-bar.wake.$$"; ln -s "kawa-bar.wake.$$" "$R4/kawa-bar.volume.$$"; exec 6<>"$R4/kawa-bar.wake.$$"
ln -s "kawa-bar.wake.999999999" "$R4/kawa-bar.volume.999999999"
XDG_RUNTIME_DIR=$R4 py 'kp.bar_push("volume", "volume 33 0"); kp.bar_push("brightness", "50")'
read -r -t 1 -u 6 l; eq "$l" "volume 33 0"; read -r -t 0.2 -u 6 l && _no "another line: $l" || _ok
exec 6<&-
case_ "closing what is closed does nothing"
eq "$(py 'fresh(); p.close("lost"); print(u.calls, p.lost)')" "[] None"

# ── doing ─────────────────────────────────────────────────────────────────────────────
case_ "a switch (theme, night light, freesync, bluetooth, dnd, the screensaver): done in place, the panel open, the state read after"
for k in theme night vrr bluetooth dnd saver; do
  eq "$(py "fresh(); p.request(); u.answer(STATE); u.calls.clear(); p.activate('$k'); u.answer(); print(', '.join(u.calls), p.visible)")" \
    "run kawa-quick --do $k, run kawa-quick --state True" "$k"
done
case_ "the others: the panel closes, then their own menu or window"
for k in network devices drives backup record ocr wallpaper screenshot screenoff power; do
  eq "$(py "fresh(); p.request(); u.calls.clear(); p.activate('$k'); print(', '.join(u.calls))")" \
    "hide, light quick off, launch kawa-quick --do $k" "$k"
done
case_ "Enter on the sound meter: the sound panel (outputs, inputs) in its place; on brightness: nothing more"
eq "$(py 'fresh(); p.request(); u.calls.clear(); p.focus = "sound"; p.key("Return"); print(", ".join(u.calls)); print(p.mode, p.visible, p.focus)')" \
  "$(printf '%s\n' "hide, light quick off, show, light sound on, run kawa-quick --state sound" "sound True None")"
eq "$(py 'fresh(); p.request(); u.calls.clear(); p.focus = "brightness"; p.key("Return"); print(u.calls)')" "[]"
case_ "Enter, Space and the keypad's Enter do what a click on the item does: a switch in place, an opener closes the panel and goes"
for key in Return space KP_Enter; do
  eq "$(py "fresh(); p.request(); u.answer(STATE); u.calls.clear(); p.focus = 'night'; p.key('$key'); u.answer(); print(', '.join(u.calls), p.visible)")" \
    "run kawa-quick --do night, run kawa-quick --state True" "$key on a switch"
  eq "$(py "fresh(); p.request(); u.calls.clear(); p.focus = 'power'; p.key('$key'); print(', '.join(u.calls), p.visible)")" \
    "hide, light quick off, launch kawa-quick --do power False" "$key on an opener"
done

# ── the keys ──────────────────────────────────────────────────────────────────────────
nav() { py "fresh(); p.focus = '$1'; [p.key(k) for k in '$2'.split()]; print(p.focus)"; }
case_ "arrows (and h j k l) walk the dial: to the nearest item that way — its middle within a cone either side of the arrow (no farther aside than twice as far ahead), the nearer and the less aside the better — so they go round the hours as the eye does; nothing that way: the cursor stays"
eq "$(nav theme 'Right')" night "from twelve o'clock to one"; eq "$(nav theme 'l')" night "(l is Right)"; eq "$(nav night 'Left')" theme
eq "$(nav theme 'Right Right Right')" wallpaper "out to the top right corner; the end of the walk stays"
eq "$(nav theme 'Left')" ocr "round the top the other way: eleven o'clock"; eq "$(nav theme 'h h h')" screenshot "…out to the top left corner"
eq "$(nav theme 'Up')" theme "nothing above twelve o'clock"; eq "$(nav theme 'Down')" bluetooth "straight down through the middle to six o'clock"; eq "$(nav bluetooth 'k')" theme
eq "$(nav bluetooth 'Right')" network "from six o'clock to five"; eq "$(nav bluetooth 'Left')" devices; eq "$(nav network 'Right')" power "…and out to the corner"
eq "$(nav vrr 'j j j j')" power "down the right edge: three o'clock, four, the corner; the end stays"
eq "$(nav saver 'Left')" sound "inward from three o'clock: the sound arc"; eq "$(nav sound 'Left')" brightness "across to the brightness arc"; eq "$(nav brightness 'Left')" backup "out to nine o'clock"
eq "$(nav saver 'Left Left Left')" backup "straight across the dial in three keys"; eq "$(nav brightness 'Right')" sound; eq "$(nav sound 'Right')" saver "…and back"
eq "$(nav screenshot 'Right')" ocr; eq "$(nav screenshot 'Down')" record; eq "$(nav wallpaper 'Left')" night; eq "$(nav wallpaper 'Down')" vrr
eq "$(nav screenoff 'Right')" devices; eq "$(nav screenoff 'Up')" drives; eq "$(nav power 'Left')" network; eq "$(nav power 'Up')" dnd "the corners lead back in"
eq "$(nav screenshot 'Up Left')" screenshot; eq "$(nav power 'Down Right')" power "nothing beyond a corner: the cursor stays"
eq "$(py 'fresh(STATE.replace("bluetooth\ton\n","").replace("devices\tnone\n","")); p.focus = "theme"; p.key("Down"); a = p.focus; p.key("Up"); print(a, p.focus)')" "network theme" "ten hours: straight down from the theme is the network, six o'clock"
eq "$(py 'out = []
for st in (STATE, STATE.replace("bluetooth\ton\n", "").replace("devices\tnone\n", "")):
    fresh(st); seen, todo = {p.items[0].key}, [p.items[0]]
    while todo:
        a = todo.pop()
        for d in ("Up", "Right", "Down", "Left"):
            b = kp.toward(p.items, a, d)
            if b is not None and b.key not in seen: seen.add(b.key); todo.append(b)
    out.append((len(seen), len(p.items)))
print(out)')" "[(18, 18), (16, 16)]" "every item can be reached with the arrows from the first, with twelve hours or ten"
case_ "toward(), the rule itself: ahead of the cursor's item along the arrow, no farther aside than twice as far ahead (an item beside or behind is never the one); the lowest ahead + 2 · aside; a tie: the lower hour"
eq "$(py 'I = lambda k, x, y, o: kp.Item(k, "hour", x, y, 0, 0, 0, order=o)
cur = I("cur", 0, 0, 0); near = I("near", 10, 20, 1); far = I("far", 60, 0, 2); wide = I("wide", 10, 21, 3); back = I("back", -5, 0, 4); beside = I("beside", 0, 30, 5)
print(kp.toward([cur, near, far, wide, back, beside], cur, "Right").key, kp.toward([cur, far, wide, back, beside], cur, "Right").key, kp.toward([cur, wide, back, beside], cur, "Right"),
      kp.toward([cur, near, far, wide, back, beside], cur, "Left").key, kp.toward([cur, near, far, wide, back, beside], cur, "Down").key, kp.toward([cur, near, far, wide, back, beside], cur, "Up"))')" \
  "near far None back beside None" "50 beats 60 (20 aside is the cone's edge), 21 aside is outside it, the one behind is Left, the one beside is Down, nothing is Up"
eq "$(py 'I = lambda k, x, y, o: kp.Item(k, "hour", x, y, 0, 0, 0, order=o)
cur = I("cur", 0, 0, 0); a = I("a", 20, 0, 9); b = I("b", 20, 0, 5)
print(kp.toward([cur, a, b], cur, "Right").key, kp.toward([cur, b, a], cur, "Right").key, kp.toward([cur, a, b], cur, "l").key)')" "b b b" "equal scores: the lower hour, whichever comes first in the list; l is Right"
case_ "Tab and Shift+Tab: every item in turn, round — in the items' order: the hours, the two arcs, the corners"
eq "$(nav power 'Tab')" theme "round: the last to the first"; eq "$(nav theme 'ISO_Left_Tab')" power "…and back"
eq "$(nav theme 'Tab Tab Tab')" saver; eq "$(nav ocr 'Tab')" brightness "the hours, then the arcs"; eq "$(nav sound 'Tab')" screenshot "then the corners"; eq "$(nav brightness 'ISO_Left_Tab')" ocr
eq "$(py 'fresh(); p.focus = "theme"; seen = [p.focus]
for _ in range(len(p.items)): p.key("Tab"); seen.append(p.focus)
print(seen == [i.key for i in p.items] + ["theme"], len(set(seen)))')" "True 18" "all eighteen once, in the items' order, then round to the first"
case_ "↑ ↓ (k j) on an arc: its level by 5 to the next multiple of 5, at once and then set (the beads rise: up is more); ← → leave it for the next item, as from any"
eq "$(py 'fresh(); p.focus = "sound"; p.key("Up"); print(p.focus, p.state["sound"], u.calls[-1])')" "sound 65% run kawa-quick --do volume 65"
eq "$(py 'fresh(); p.focus = "sound"; p.key("k"); print(p.state["sound"], u.calls[-1])')" "65% run kawa-quick --do volume 65" "(k is Up)"
eq "$(py 'fresh(); p.focus = "brightness"; p.key("j"); print(p.focus, p.state["brightness"], u.calls[-1])')" "brightness 65% run kawa-quick --do brightness 65" "(j is Down)"
eq "$(py 'fresh(); p.focus = "sound"; p.key("Down"); print(p.state["sound"], u.calls[-1])')" "60% run kawa-quick --do volume 60" "62 down: 60, the next multiple of 5"
eq "$(py 'fresh(); p.focus = "brightness"; [p.key("Up") for _ in range(9)]; print(p.state["brightness"])')" 100% "no more than 100"
eq "$(py 'fresh(); p.focus = "sound"; [p.key("Down") for _ in range(20)]; print(p.state["sound"])')" 0% "no less than 0"
eq "$(py 'fresh(); p.focus = "sound"; p.key("Right"); print(p.focus, p.state["sound"], [c for c in u.calls if c.startswith("run")])')" "saver 62% []" "← → move on: the level is not touched"
case_ "a meter without a level (no DDC/CI, no output): ↑ ↓ have nothing to change — they move on, as on any item"
eq "$(py 'fresh(STATE.replace("70%","no DDC/CI")); p.focus = "brightness"; p.key("Up"); print(p.state["brightness"], p.focus, [c for c in u.calls if c.startswith("run")])')" "no DDC/CI record []" "up from the left arc: the hour above it, nothing sent"
eq "$(py 'fresh(STATE.replace("70%","no DDC/CI")); p.focus = "brightness"; p.key("Down"); print(p.focus, [c for c in u.calls if c.startswith("run")])')" "drives []"

# ── the mouse ─────────────────────────────────────────────────────────────────────────
# (quick settings, the dial: night's place x 215–250, y 40–75, middle (233, 58); the theme's middle
# (169, 41), vrr's (280, 105), saver's (297, 169), network's (233, 280); brightness's beads up the
# left from (136, 251) — bead 9 at (81, 174) —, sound's up the right from (202, 251) — bead 9 at
# (257, 174) —; the wallpaper's corner x 289–324, y 13–48; the air between (169, 120), the
# dial's middle (169, 169) and the frame (5, 5) hold nothing)
case_ "one light: the pointer over an item moves the cursor there (it is hot and the cursor at once), and the cursor stays where the pointer left it"
eq "$(py 'opened("quick", STATE); p.hover(233, 58); print(p.hot, p.focus)')" "night night"
eq "$(py 'opened("quick", STATE); p.hover(233, 58); p.hover(169, 120); print(p.hot, p.focus)')" "None night" "over a gap: nothing hot, the cursor where the pointer left it"
eq "$(py 'opened("quick", STATE); p.hover(233, 58); p.hover(169, 169); print(p.hot, p.focus)')" "None night" "over the dial's middle (it is no item): the same"
eq "$(py 'opened("quick", STATE); p.hover(233, 58); p.hover(5, 5); print(p.hot, p.focus)')" "None night" "over the frame: the same"
eq "$(py 'opened("quick", STATE); p.hover(233, 58); p.leave(); print(p.hot, p.focus)')" "None night" "the pointer gone: the cursor stays"
eq "$(py 'opened("quick", STATE); p.focus = "theme"; p.hover(233, 58); print(p.hot, p.focus)')" "night night" "a cursor the keys showed: the pointer takes it"
eq "$(py 'fresh(); p.hover(233, 58); print(p.hot, p.focus)')" "night None" "a panel not open shows no cursor"
case_ "a click does what is under the pointer, there and then"
eq "$(py 'opened("quick", STATE); p.hover(233, 58); p.press(233, 58); print(p.hot, p.focus)')" "night night"
eq "$(py 'fresh(); p.press(*bead("sound", 9)); print(p.focus)')" None "a click on a meter, with no cursor shown: none is shown for it"
eq "$(py 'fresh(); p.focus = "theme"; p.press(*bead("sound", 9)); print(p.focus)')" sound "… but a cursor the keys showed follows the click"
eq "$(py 'fresh(); p.request(); u.calls.clear(); p.press(300, 25); print(", ".join(u.calls))')" "redraw, hide, light quick off, launch kawa-quick --do wallpaper"
case_ "the keys move the cursor from where the pointer left it"
eq "$(py 'opened("quick", STATE); p.hover(280, 105); p.key("Left"); print(p.hot, p.focus)')" "vrr night"
eq "$(py 'opened("quick", STATE); p.hover(233, 280); p.key("Right"); print(p.hot, p.focus)')" "network power"
case_ "the pointer leaving the panel: nothing hot, only that item redrawn; the cursor stays"
eq "$(py 'opened("quick", STATE); p.hover(233, 58); u.drawn.clear(); p.leave(); print(p.hot, p.focus, u.drawn)')" "None night [['night']]"
eq "$(py 'fresh(); u.drawn.clear(); p.leave(); print(u.drawn)')" "[]" "nothing was hot: nothing redrawn"
has "$(cat "$REPO/bin/kawa-panel")" 'win.connect("leave-notify-event", on_leave)'
has "$(cat "$REPO/bin/kawa-panel")" 'Gdk.EventMask.LEAVE_NOTIFY_MASK'
case_ "opened again: nothing hot until the pointer says where it is (a new window); a state read keeps it while it is there"
eq "$(py 'fresh(); p.request(); p.hover(233, 58); p.close("chosen"); p.request(); print(p.hot)')" None
eq "$(py 'fresh(); p.hover(233, 58); p.refresh(); u.answer(STATE); print(p.hot)')" night
eq "$(py 'fresh(); p.hover(297, 169); a = p.hot; p.refresh(); u.answer(STATE.replace("bluetooth\ton\n","").replace("devices\tnone\n","")); print(a, p.hot)')" "saver None" "the hours reflowed to ten: where the saver was is now the air between two of them"
case_ "a drag: the meter follows, the hot one does not move off it (nor the cursor)"
eq "$(py 'opened("quick", STATE); b = bead("brightness", 9); p.hover(*b); p.press(*b); p.hover(233, 58, dragging=True); print(p.hot, p.focus)')" "brightness brightness"
eq "$(py 'fresh(); p.press(5, 5); print(u.calls)')" "[]" "on the frame: nothing"
case_ "a click on an arc's beads: the level of the bead under it (lit through it: 5 % each, the first 5); a bead's spacing below the first: 0; off its circle: nothing set; a drag follows"
eq "$(py 'fresh(); print([ (p.press(*bead("brightness", j)), p.state["brightness"])[1] for j in (0, 1, 9, 10, 19) ])')" "['5%', '10%', '50%', '55%', '100%']" "bead j is 5 · (j + 1) %: the first 5, the tenth 50, the eleventh 55, the twentieth 100"
eq "$(py 'fresh(); p.press(*kp.bead_at(p.item("brightness"), -0.75)); print(p.state["brightness"])')" 0% "below the first bead: 0"
eq "$(py 'fresh(); p.press(169, 120); p.press(73, 73); print(p.state["brightness"], [c for c in u.calls if c.startswith("run")])')" "70% []" "off the circle (the air between, a corner of the arc's box): nothing set"
eq "$(py 'fresh(); p.press(*bead("sound", 0)); p.hover(200, 20, dragging=True); print(p.state["sound"])')" 100% "a drag on round to the crown: 100"
eq "$(py 'fresh(); p.press(*bead("sound", 0)); p.release(); p.hover(200, 20, dragging=True); print(p.state["sound"])')" 5% "let go: no more"

case_ "the segments and the level, one rule both ways (the sound panel's and the brightness slider's; the dial's arcs have arc_level): a click lights through the segment under the pointer (to its top), the air before the first is 0"
eq "$(py '
bad = []
for o in range(-20, 200):
    v = kp.level_at(o)
    want = 0 if o < 0 else min(20, o // 8 + 1)       # the segments lit through the one under it
    if kp.lit_of(v) != (want, 0): bad.append((o, v, kp.lit_of(v)))
print(bad)')" "[]" "every pixel from 20 before the run to 40 after it: the segments lit are those through the pointer's"
eq "$(py 'v = [kp.level_at(o) for o in range(-20, 200)]; print(all(a <= b for a, b in zip(v, v[1:])), max(b - a for a, b in zip(v, v[1:])), v[0], v[-1], kp.level_at(-1), kp.level_at(0), kp.level_at(7), kp.level_at(8), kp.level_at(159), kp.level_at(160), kp.level_at(500))')" \
  "True 5 0 100 0 5 5 10 100 100 100" "never back; 5 % at each cell (8 px); the ends 0 and 100 exactly"
eq "$(py 'print([kp.lit_of(v) for v in (0, 1, 4, 5, 42, 99, 100, 150)], kp.lit_of(None), kp.lit_of(-3))')" \
  "[(0, 0), (0, 2), (0, 8), (1, 0), (8, 4), (19, 8), (20, 0), (20, 0)] (0, 0) (0, 0)" "5 % a segment, then two rows a percent into the next one (42 % = 8 whole and 4 rows)"
eq "$(py 'print(len({kp.lit_of(v) for v in range(101)}))')" 101 "every level its own pixels: no two alike"
eq "$(py 'print([kp.seg_ink(i) for i in (0, 15, 16, 17, 18, 19)])')" "['asagi', 'asagi', 'flame', 'flame', 'accent', 'accent']" "it reddens as it rises: the 17th–18th flame, the 19th–20th accent"
eq "$(py 'print(kp.SEGS, kp.SEG_W, kp.SEG_H, kp.CELL, kp.SPAN, kp.SPAN == kp.SEGS * kp.CELL)')" "20 6 10 8 160 True" "twenty segments 6 × 10, one a cell"
eq "$(py 'opened("brightness", "brightness\t70%\n"); m = p.items[0]; x0 = p.slider_x(m); print(x0, [p.meter_at(m, x0 + o) for o in (-9, -8, -1, 0, 7, 8, 159, 167, 168)], p.meter_at(m, x0 - 300, held=True), p.meter_at(m, x0 + 900, held=True))')" \
  "137 [None, 0, 0, 5, 5, 10, 100, 100, None] 0 100" "the brightness slider's: the pointer counts from a cell before the run to a cell after it; dragged, anywhere (an end held)"
eq "$(py 'opened("sound", SOUND); m = p.item("sound"); x0 = p.slider_x(m); print(x0, [p.meter_at(m, x0 + o) for o in (-9, -8, -1, 0, 7, 8, 159, 167, 168)], p.meter_at(m, x0 - 300, held=True), p.meter_at(m, x0 + 900, held=True))')" \
  "235 [None, 0, 0, 5, 5, 10, 100, 100, None] 0 100" "the sound panel's: the same rule, its run at the content's right"
eq "$(py 'opened("sound", SOUND); m = p.item("sound"); print(p.slider_x(m) + (kp.SEGS - 1) * kp.CELL + kp.SEG_W == m.x + m.w); m.trail = 20; print(p.slider_x(m))')" "$(printf '%s\n' True 215)" "the last segment's ink on the content's edge; before a value's room, further left"
eq "$(py 'print([callable(getattr(kp, n, None)) for n in ("lit_of", "seg_ink", "level_at", "snap")], hasattr(kp, "SEGS"))')" "[True, True, True, True] True" "the segments are the whole of the slider: what they light, in which ink, what a pointer on them means"
eq "$(py 'print([kp.snap(v, d) for v, d in ((62, 5), (62, -5), (60, 5), (60, -5), (0, -5), (98, 5), (100, 5))])')" \
  "[65, 60, 65, 55, 0, 100, 100]" "keys and the wheel: to the next multiple of 5"

case_ "a drag: every motion sets the level under the pointer at once, only that meter redrawn, one set at a time, the last one sent"
eq "$(py '
fresh(); p.press(*bead("brightness", 5)); u.drawn.clear()
shown = []
for j in range(6, 20):
    p.hover(*bead("brightness", j), dragging=True); shown.append(p.state["brightness"] == f"{5 * (j + 1)}%")
print(all(shown), all(d == ["brightness"] for d in u.drawn), sum(c.startswith("run kawa-quick --do brightness") for c in u.calls))
u.answer(); print(u.calls[-1]); p.release(); u.answer(); print(u.calls[-1])')" \
  "$(printf '%s\n' 'True True 1' 'run kawa-quick --do brightness 100' 'run kawa-quick --state')"
eq "$(py 'fresh(); x, y = bead("brightness", 5); p.press(x, y); n = len(u.calls); p.hover(x, y + 1, dragging=True); p.hover(x + 1, y, dragging=True); print(len(u.calls) - n)')" 0 "the same level again (the same bead): nothing redrawn, nothing sent"
eq "$(py 'fresh(); p.press(*bead("brightness", 9)); p.hover(150, 330, dragging=True); a = p.state["brightness"]; p.hover(150, 5, dragging=True); print(a, p.state["brightness"])')" "0% 100%" "dragged past either end: that end"
eq "$(py 'fresh(); p.press(*bead("brightness", 9)); p.hover(300, 300, dragging=True); a = p.state["brightness"]; p.hover(300, 20, dragging=True); print(a, p.state["brightness"])')" "0% 100%" "dragged across the dial, to the other side: the nearer end — 0 below the middle, 100 above"

case_ "no snapping back: a state read that comes back mid-drag, or was started before the last change, leaves the meter as set"
eq "$(py '
fresh(); p.refresh()                                  # (a read already under way: the open)
p.press(*bead("brightness", 12)); v = p.state["brightness"]
u.pending.pop(0)(0, STATE)                            # (that read comes back with the old 70 %)
print(v, p.state["brightness"])')" "65% 65%"
eq "$(py '
fresh(); p.press(*bead("brightness", 12)); p.release(); p.refresh()
u.answer()                                            # (the level set: confirmed)
u.answer(STATE)                                       # (the read started before that: 70 %)
print(p.state["brightness"])')" 65% "a read started while it was being set: ignored"
eq "$(py '
fresh(); p.press(*bead("brightness", 12)); p.release(); u.answer()
u.answer(STATE.replace("70%", "65%").replace("night\ton", "night\toff"))
print(p.state["brightness"], p.state["night"], p.held("brightness"))')" "65% off False" "a read after it: taken, and the meter free again"
eq "$(py '
fresh(); p.refresh(); p.press(*bead("brightness", 12)); p.release(); p.refresh(); u.answer(STATE); u.answer(); u.answer(STATE); u.answer(STATE)
print(p.state["brightness"], p.held("brightness"))')" "70% False" "reads that started while it was set are ignored, but only those: the meter is not held for good"
eq "$(py '
fresh(); p.press(*bead("brightness", 12)); p.release(); u.answer(); u.answer(STATE)
print(p.state["brightness"])')" 70% "… so a level the machine did not take shows as it is"

case_ "the wheel and a touchpad: a step per notch; a touchpad's small scrolls summed, not a step each (on the night light's warmth)"
eq "$(py 'fresh(); W = lambda: sum(c == "run kawa-quick --do warmer" for c in u.calls); p.scroll_by(233, 58, -1.0); a = W(); [p.scroll_by(233, 58, -0.25) for _ in range(3)]; b = W(); p.scroll_by(233, 58, -0.25); print(a, b, W())')" "1 1 2"
eq "$(py 'fresh(); p.scroll_by(233, 58, 0.5); p.scroll_by(169, 41, 0.5); p.scroll_by(233, 58, 0.5); print([c for c in u.calls if c.startswith("run")])')" "[]" "half a step on one item does not add to the other's"
eq "$(py 'fresh(); p.scroll_by(233, 58, -1.0); p.scroll_by(233, 58, 1.0); print([c for c in u.calls if c.startswith("run")])')" "['run kawa-quick --do warmer', 'run kawa-quick --do cooler']" "up warmer, down cooler"
case_ "...and on the dial's meters: a smooth scroll (a touchpad, GTK's wheel on Wayland) over the beads steps the level, the small parts summed"
eq "$(py 'fresh(); p.scroll_by(*bead("brightness", 9), -1.0); print(p.state["brightness"])')" "75%" "a whole notch up: 70 → 75"
eq "$(py 'fresh(); [p.scroll_by(*bead("sound", 3), 0.25) for _ in range(3)]; a = p.state["sound"]; p.scroll_by(*bead("sound", 3), 0.25); print(a, p.state["sound"])')" "62% 60%" "three quarters: nothing yet; the fourth: a step down (to the next multiple of 5)"
case_ "the arcs' hit zones are mirror images: a point on one side and its mirror across the middle (x ↔ 338 − x) hit the two arcs alike"
eq "$(py 'fresh(); b, s_ = p.item("brightness"), p.item("sound")
pts = [(x + .5, y + .5) for y in range(60, 280) for x in range(169, 300)]
print(all(s_.inside(x, y) == b.inside(338 - x, y) for x, y in pts), sum(s_.inside(x, y) for x, y in pts) > 0)')" "True True"

case_ "moving between items redraws only those that changed: the one left and the one entered (the cursor and the hot one together)"
eq "$(py 'opened("quick", STATE); p.hover(233, 58); print(sorted({tuple(d) for d in u.drawn}))')" "[('night',)]" "the first: only it"
eq "$(py 'opened("quick", STATE); p.hover(233, 58); u.drawn.clear(); p.hover(280, 105); print(sorted({tuple(d) for d in u.drawn}))')" "[('night', 'vrr')]"
eq "$(py 'opened("quick", STATE); p.hover(233, 58); u.drawn.clear(); p.hover(234, 59); p.hover(240, 70); print(u.drawn)')" "[]" "within the same item: nothing"
eq "$(py 'opened("quick", STATE); p.hover(233, 58); u.drawn.clear(); p.hover(169, 41); print(sorted({tuple(d) for d in u.drawn}))')" "[('night', 'theme')]" "onto the next hour: both"
eq "$(py 'opened("quick", STATE); p.hover(233, 58); u.drawn.clear(); p.hover(*bead("sound", 9)); print(sorted({tuple(d) for d in u.drawn}))')" "[('night', 'sound')]" "onto an arc: both, never the whole dial"
eq "$(py 'opened("quick", STATE); p.hover(*bead("sound", 3)); u.drawn.clear(); p.hover(*bead("sound", 14)); print(u.drawn)')" "[]" "along the same arc: nothing (one item)"
eq "$(py 'opened("quick", STATE); p.hover(233, 58); u.drawn.clear(); p.hover(5, 5); print(u.drawn, p.focus)')" "[['night']] night" "onto the frame: the one left, the cursor stays"
eq "$(py 'fresh(); p.focus = "theme"; u.drawn.clear(); p.key("Right"); print(u.drawn)')" "[['theme', 'night']]" "the keys: the cursor's two"
has "$(cat "$REPO/bin/kawa-panel")" 'for it in items + ((panel.centre,) if panel.centre is not None else ()):' "…each redraw covers the dial's middle too (it shows the cursor's item: a stale echo otherwise)"

case_ "how each item is drawn (look): the cursor fills the item's place with the lacquer (select), its inks text_on_select; at rest the place is bare — an hour's picture accent when it is on, muted when off, a corner's and an arc's muted (their name and state are the dial's middle's, drawn there). The pointer adds nothing of its own: it moves the cursor"
lk() { py "fresh(); i = p.item('$1'); l = kp.look(i, $2, $3); print(l['fill'], l['frame'], l['glyph'], l['label'], l['value'], l['on_fill'])"; }
eq "$(lk night False False)" "None None accent text muted False" "an hour that is on"
eq "$(lk devices False False)" "None None muted text muted False" "an hour that is off"
eq "$(lk wallpaper False False)" "None None muted text muted False" "a corner at rest: nothing behind it, its picture muted"
eq "$(lk power False False)" "None None muted text muted False"
eq "$(lk sound False False)" "None None muted text muted False" "an arc at rest: nothing behind its beads"
eq "$(lk brightness False False)" "None None muted text muted False"
for k in night devices wallpaper power sound brightness; do
  eq "$(lk $k False True)" "$(lk $k False False)" "$k under the pointer: drawn as at rest (it has the cursor then)"
  eq "$(lk $k True False)" "select None text_on_select text_on_select text_on_select True" "$k the cursor: filled with the lacquer"
  eq "$(lk $k True True)" "select None text_on_select text_on_select text_on_select True" "$k the cursor and under the pointer: the same"
done
eq "$(py 'fresh(); print(sorted({kp.look(i, False, True) == kp.look(i, False, False) for i in p.items}))')" "[True]" \
  "no item is drawn differently under the pointer: no tint, no frame, no vermilion of its own"
case_ "draw() takes every colour from look(): the cursor (the pointer moves it), nothing else decides"
src=$(sed -n '/    def draw(widget, cr):/,/^    def on_key/p' "$REPO/bin/kawa-panel")
has "$src" 'lk = look(it, it.key == panel.focus, it.key == panel.hot)'
lacks "$src" '"accent" if'; lacks "$src" 'text_on_select" if on else "text'
case_ "no GTK widget with a hover look: the window holds one drawing area, painted whole; no transitions"
has "$(cat "$REPO/bin/kawa-panel")" '* { transition: none; animation: none; }'
eq "$(grep -oE 'Gtk\.(Button|EventBox|ToggleButton|Scale|Switch|Label|Box|Grid|ListBox|MenuItem|Image)\b' "$REPO/bin/kawa-panel" | sort -u)" "" "no widgets but the window and its drawing area"
has "$src" 'cr.set_operator(cairo.OPERATOR_SOURCE)'; has "$src" 'cr.set_source_rgba(*pal["ground"], see[0])'
has "$src" 'cr.paint()' "the ground painted whole, every pixel (whatever a theme gives the window underneath)"
case_ "the drawing's pixel rules (§4), read from its code — the window needs a screen: the frame's hairline with its four corner pixels left out, the shadow (two rows under it, the first from a pixel in, the second a pixel further right, and a column at its right), the cursor one cell beyond the content either side"
d=$(sed -n '/    def frame(cr, x, y, w, h, name, t=1, cut=False):/,/^    def on_key/p' "$REPO/bin/kawa-panel")
has "$d" 'c = t if cut else 0'
has "$d" 'box(cr, x + c, y, w - 2 * c, t, name)'; has "$d" 'box(cr, x + c, y + h - t, w - 2 * c, t, name)'
has "$d" 'box(cr, x, y + t, t, h - 2 * t, name)'; has "$d" 'box(cr, x + w - t, y + t, t, h - 2 * t, name)'
has "$d" 'frame(cr, 0, 0, W, H, "hair", cut=True)'
has "$d" 'box(cr, HAIR, H, W - HAIR, 1, "shadow1")'; has "$d" 'box(cr, 2 * HAIR, H + 1, W - HAIR, 1, "shadow2")'; has "$d" 'box(cr, W, 2 * HAIR, 1, H - 2 * HAIR, "shadow2")'
has "$d" 'cr.translate(panel.ox, 0)' "the frame's own place in the window"
has "$d" 'box(cr, it.x - CELL, it.y, it.w + 2 * CELL, it.h, lk["fill"])' "the cursor: a cell beyond the content either side"
case_ "a heading's pixels: its icon (accent_text) in the icon column, its name (strong) from cell 3, the rule — 1 px edge2, solid, on the row's row 10 — to the content's edge (8 px before a value, muted, at its end)"
has "$d" 'glyph(cr, x, ty, ic.get(icon, icon), "accent_text")'
has "$d" 'w = text(cr, x + HEAD_X, ty, name, "strong")'
has "$d" 'box(cr, sx, y + 10, right - sx, 1, "edge2")'
has "$d" 'right -= text(cr, right, ty, value, "muted", right=True) + GAP'
case_ "a meter's pixels (the sound panel's and the brightness slider's): twenty segments of 6 × 10 a cell apart — lit in the level's ink (asagi, flame, accent), the next one partly from the bottom, unlit edge; hollow (an outline) while muted; on the cursor's lacquer lit text_on_select, unlit select_lo"
has "$d" 'full, part = lit_of(pct)'
has "$d" 'lit_ink, off_ink = ("text_on_select", "select_lo") if on else (seg_ink(i), "edge")'
has "$d" 'rows = SEG_H if i < full else part if i == full else 0'
has "$d" 'frame(cr, x, top, SEG_W, rows, lit_ink)'
has "$d" 'segments(cr, it, Panel.slider_x(it), it.y + (ROW - SEG_H) // 2, pct, on)' "centred in its row"
case_ "an arc's pixels (§4): twenty beads, BEAD px round with their corner pixels left out, on the circle — whole beads lit to the level (5 % each) from the bottom in its ink (asagi, the 17th–18th flame, the 19th–20th accent: it reddens as it rises), unlit edge2; hollow (an outline) while muted; under the cursor on a lacquer band BAND px wide along the circle, lit text_on_select, unlit select_lo"
has "$d" 'lit = panel.shown.setdefault(it.key, lit_beads(it.value))' "the beads as they stand on screen (glide() moves them to the level)"
eq "$(py 'print([kp.lit_beads(v) for v in ("0%", "4%", "5%", "62%", "99%", "100%", "no DDC/CI", "")])')" "[0, 0, 1, 12, 19, 20, 0, 0]" "5 % a bead, whole beads; no level: none"
case_ "a meter changing on the dial: its beads light (or go out) one after another on the frame clock — a bead on the first frame BEAD_MS (12) or more after the last: at 144 Hz every second frame, at 60 Hz every frame (§11) — each step that arc alone redrawn; never at an open, never while closed"
eq "$(py 'opened("quick", STATE); print(p.shown, p.gliding, u.ticks)')" "{} False []" "an open: nothing glides (the beads drawn at their levels)"
eq "$(py 'opened("quick", STATE); p.shown = {"brightness": 14, "sound": 12}; u.calls.clear(); p.set_level("brightness", 85)
tick = u.ticks[0]; steps = []; go = True; n = 0
while go:
    u.drawn.clear(); go = tick(100 + n / 144); steps.append((n, p.shown["brightness"], [d for d in u.drawn])); n += 1
print([s for s in steps if s[2]], p.gliding, u.calls.count("frames"))')" \
  "[(0, 15, [['brightness']]), (2, 16, [['brightness']]), (4, 17, [['brightness']])] False 1" "144 Hz, 70 → 85: a bead on frames 0, 2, 4 (13.9 ms apart), only that arc drawn, then it stops asking"
eq "$(py 'opened("quick", STATE); p.shown = {"brightness": 14, "sound": 12}; p.set_level("sound", 50); tick = u.ticks[0]; n = 0; frames = []
while True:
    before = p.shown["sound"]; go = tick(100 + n / 60)
    if p.shown["sound"] != before: frames.append(n)
    n += 1
    if not go: break
print(p.shown["sound"], frames)')" "10 [0, 1]" "60 Hz, 62 → 50: two beads go out, one a frame (16.7 ms ≥ 12)"
eq "$(py 'fresh(); p.shown = {"brightness": 14}; p.set_level("brightness", 100); print(p.gliding, u.ticks)')" "False []" "closed: no glide (it stands where it is until the next open)"
has "$d" 'bx, by = bead_at(it, j)'
has "$d" 'x, y = bx - BEAD // 2, by - BEAD // 2' "the bead's box round its centre pixel"
has "$d" 'ink = ("text_on_select" if on else seg_ink(j)) if j < lit else ("select_lo" if on else "edge2")'
has "$d" 'if j < lit and it.muted:'
has "$d" 'box(cr, x + 1, y, BEAD - 2, BEAD, ink)'; has "$d" 'box(cr, x, y + 1, BEAD, BEAD - 2, ink)' "(its corner pixels left out)"
has "$d" 'abs(r - BEAD_R) <= BAND / 2'; has "$d" 'box(cr, x, y, w, 1, "select")' "the band: the pixels within BAND / 2 of the circle, a run a row"
has "$d" 'beads(cr, it, on)' "drawn by its beads, nothing else"
case_ "the chosen dot and a calendar's today, in pixels: a lit row with no value gets a 6 px vermilion dot at its right edge (text_on_select on the cursor), its corners left out; today a 1 px accent frame, its corners cut"
has "$d" 'if it.lit and not it.value:'
has "$d" 'dot(cr, it.x + it.w - DOT, it.y + (ROW - DOT) // 2, "text_on_select" if on else "accent")'
has "$d" 'box(cr, x + 1, y, DOT - 2, DOT, name)'; has "$d" 'box(cr, x, y + 1, DOT, DOT - 2, name)'
has "$d" 'frame(cr, x, y, w, h, "accent_text", cut=True)'
case_ "an hour's and a corner's pixels (§4): its 28 px picture (a mask: its own drawing) on the middle of its 36 × 36 place, in the state's ink — accent when on, muted when off, a corner's muted; under the cursor the place in the lacquer, its four corner pixels left out"
has "$d" 'box(cr, it.x + 1, it.y, it.w - 2, it.h, lk["fill"])'; has "$d" 'box(cr, it.x, it.y + 1, it.w, it.h - 2, lk["fill"])'
has "$d" 'mask = crest_pic(turned(it.icon))' "(its frame: the record hour's reels turned while it records)"
case_ "no two functions of the panel share a name in one scope (a later one shadows the earlier: the frame's hairline vanished once, r27-19k-7)"
eq "$(python3 -I -c 'import ast, collections, sys
t = ast.parse(open(sys.argv[1]).read())
bad = []
for scope in [t] + [n for n in ast.walk(t) if isinstance(n, (ast.FunctionDef, ast.ClassDef))]:
    c = collections.Counter(n.name for n in scope.body if isinstance(n, ast.FunctionDef))
    bad += [getattr(scope, "name", "module") + "." + k for k, v in c.items() if v > 1]
print(bad)' "$REPO/bin/kawa-panel")" "[]"
case_ "the record hour while it records: its reels turn (§5 busy: a picture that moves) — REEL_MS (167: 6 a second, §13) a frame, only that hour redrawn; it stops when the recording does or the panel goes"
eq "$(py 'R = STATE + "record\ton\n"; fresh(R); p.request("quick"); u.answer(R); print(p.reeling, len(u.timers), kp.REEL_MS)
f = u.timers.pop(0); u.drawn.clear(); f(); print(p.turn, u.drawn, len(u.timers))
f = u.timers.pop(0); f(); print(p.turn)')" "$(printf '%s\n' 'True 1 167' "1 [['record']] 1" '0')" "an open while recording: the reels turn, frame by frame (one timer at a time)"
eq "$(py 'opened("quick", STATE); print(p.reeling, [c for c in u.calls if c.startswith("later")])')" "False []" "not recording: nothing turns, no timer"
eq "$(py 'R = STATE + "record\ton\n"; fresh(R); p.request("quick"); u.answer(R); u.timers.pop(0)(); print(p.turn); p.refresh(); u.answer(STATE); u.drawn.clear(); u.timers.pop(0)(); print(p.turn, p.reeling, u.drawn)')" "$(printf '%s\n' 1 "0 False [['record']]")" "the recording stopped while the dial shows: the reels back at their first frame, that hour drawn again"
eq "$(py 'R = STATE + "record\ton\n"; fresh(R); p.request("quick"); u.answer(R); reel = u.timers[0]; p.close("chosen"); n = len(u.timers); reel(); print(p.reeling, p.turn, len(u.timers) - n)')" "False 0 0" "the panel gone: the reels stop at their first frame, no timer more"
has "$d" 'cr.mask_surface(mask, *it.pic)' "the picture at its place's own spot (an hour: its square centred in the place; a corner: by its ink)"
eq "$(py 'fresh(); print(all(i.pic == (i.x + (i.w - kp.CREST_PIC) // 2, i.y + (i.h - kp.CREST_PIC) // 2) for i in p.items if i.kind == "hour"))')" True "an hour's 28 px square on the middle of its place (both between pixels)"
has "$d" 'name = icon.removeprefix("tile_").replace("_", "-")'
case_ "the dial's middle's pixels (§4): at rest the mood's face drawn for it, 56 × 56 at 1 px, centred; under the cursor the item's picture twice as large (accent on, text off) over its name (strong) and its state (strong on, muted off; a corner's: its tip, the wallpaper's name), a row each, every part centred on the middle by its ink; an arc: its level in display size (Sumi UI twice as large), its name and its state"
has "$d" 'cr.set_source_surface(pic_, cx - pic_.get_width() // 2, cy - pic_.get_height() // 2)' "at rest the face drawn for the middle, at 1 px, centred (no scaling, no outline)"
eq "$(python3 -I -c 'import sys
from PIL import Image
for m in ("dark", "light"):
    im = Image.open(f"{sys.argv[1]}/configs/home/.config/fedokawaii/themes/{m}/face-big.png").convert("RGBA"); w, h = im.size
    px = im.load(); a = [[px[x, y][3] > 0 for x in range(w)] for y in range(h)]
    print(m, w, h, all(px[x, y] == px[w - 1 - x, y] for y in range(h) for x in range(w)), len({px[x, y] for y in range(h) for x in range(w) if px[x, y][3]}))' "$REPO")" \
  "$(printf '%s\n' 'dark 56 56 True 4' 'light 56 56 True 4')" "the middle's faces: 56 × 56, mirror images to the pixel, four inks each (tools/build-themes.py FACE_BIG)"
case_ "the middle's block is centred on the middle in every state, as itself (echo_parts: the picture or the level, then the rows that have words — its ink's top and foot equally far from the middle, the odd row above)"
eq "$(py '
def block(it):
    t = kp.echo_parts(it)
    foot = max(top + (kp.ECHO * kp.pic_ink(w)[3] if k == "pic" else 20 if k == "num" else kp.CAPS) for k, w, _, top in t)
    return t[0][3], foot, [(k, w) for k, w, _, _ in t]
S = {"hour on": STATE, "hour off": STATE}
out = []
for st, key in ((STATE, "theme"), (STATE, "dnd"), (STATE, "screenshot"), (STATE, "wallpaper"), (STATE, "brightness"),
                (STATE + "muted\ton\n", "sound"), (STATE.replace("70%", "no DDC/CI"), "brightness")):
    fresh(st); top, foot, parts = block(p.item(key))
    out.append(f"{key}:{top},{foot}:{-top - foot}")
print(" ".join(out))')" \
  "theme:-47,47:0 dnd:-45,45:0 screenshot:-33,33:0 wallpaper:-43,43:0 brightness:-23,23:0 sound:-33,33:0 brightness:-15,15:0" \
  "by the picture's ink (twice its rows), 16 px, then the rows' capitals: the moon 48 + 16 + 30, the bell 44 + …, the camera with its name alone 40 + 16 + 10, a level 20 + 16 + 10, muted sound 20 + 16 + 30, no level 30 — each balanced on the middle"
eq "$(py 'fresh(); print([(k, w, i) for k, w, i, _ in kp.echo_parts(p.item("theme"))], [(k, w) for k, w, _, _ in kp.echo_parts(p.item("brightness"))], [(k, w, i) for k, w, i, _ in kp.echo_parts(p.item("screenoff"))])')" \
  "[('pic', 'tile_moon', 'accent'), ('words', 'theme', 'strong'), ('words', 'dark', 'strong')] [('num', '70'), ('words', 'brightness')] [('pic', 'screen_off', 'text'), ('words', 'screen off', 'strong')]" \
  "an hour: its picture (accent on), name, state; a meter: its level in display size, its name; a corner: its picture, its name"
eq "$(py 'fresh(); t = kp.echo_parts(p.item("theme")); print(t[1][3] - (t[0][3] + kp.ECHO * kp.pic_ink("tile_moon")[3]), t[2][3] - t[1][3], kp.ECHO_GAP)')" "16 20 16" "the picture's ink to the name's capitals 16 px (two cells); the rows 20 apart"
case_ "a click on the middle does what it shows (the sound's level: the sound panel, as Enter on it); at rest, nothing"
eq "$(py 'opened("quick", STATE); p.key("Tab"); p.focus = "sound"; p.press(169, 169); print(p.mode, p.visible)')" "sound True" "the sound panel opens in its place"
eq "$(py 'opened("quick", STATE); p.focus = "dnd"; p.press(169, 169); print([c for c in u.calls if c.startswith("run")])')" "['run kawa-quick --do dnd']" "an hour shown: switched"
eq "$(py 'opened("quick", STATE); p.press(169, 169); print([c for c in u.calls if c.startswith("run") or c.startswith("launch")], p.focus)')" "[] None" "the face: nothing to do"
eq "$(py 'print(kp.ECHO, kp.ECHO_W, kp.ECHO * kp.CREST_PIC, kp.ECHO_W // kp.CELL)')" "2 128 56 16" "the picture 56 px, the words 128 (16 cells) at most"
case_ "an hour's state fits the middle: each at most ECHO_W px, cut at a word, never with an ellipsis"
eq "$(py 'S = [STATE.replace("theme\tdark", "theme\tlight"), STATE, STATE.replace("nettype\twifi", "nettype\tethernet"), STATE.replace("nettype\twifi", "nettype\toffline"), STATE.replace("dnd\toff", "dnd\ton")]
print(max(kp.px_of(t[3]) for st in S for t in kp.tiles_of(kp.parse_state(st))) <= kp.ECHO_W)')" True
eq "$(py 'long = "a drive with a name much too long to sit between the two arcs"
v = [t[3] for t in kp.tiles_of(kp.parse_state(STATE.replace("KINGSTON 58G", long))) if t[0] == "drives"][0]
print(repr(v), kp.px_of(v) <= kp.ECHO_W, "…" in v)')" "'a drive with a' True False" "a name too long: what fits of it, at a word"
case_ "an hour turned on while quick settings shows: its picture stamped (§11) — in accent_hi for STAMP_MS, then its ink; never at an open, never turned off"
eq "$(py 'fresh(); p.request(); u.answer(STATE); s0 = dict(p.states["quick"]); print(p.stamps)
u.t = 200.0; p.refresh(); u.answer(STATE.replace("dnd\toff", "dnd\ton")); print(sorted(p.stamps), p.stamping("dnd"))
u.t = 200.0 + kp.STAMP_MS / 1000 + 0.001; print(p.stamping("dnd"))
u.t = 300.0; p.refresh(); u.answer(STATE); print(sorted(p.stamps))')" \
  "$(printf '%s\n' '{}' "['dnd'] True" 'False' "['dnd']")"
eq "$(py 'fresh(); p.request(); u.answer(STATE); u.t = 200.0; p.refresh(); u.answer(STATE.replace("dnd\toff", "dnd\ton")); u.drawn.clear(); print("later 60" in u.calls); u.timers[-1](); print(u.drawn)')" \
  "$(printf '%s\n' True "[['dnd']]")" "STAMP_MS later that hour alone is drawn again, at its own ink"
has "$d" 'col(cr, "accent_hi" if not on and panel.stamping(it.key) else lk["glyph"])' "the stamp's ink: the picture, the moment it is turned on (never on the cursor's lacquer)"
case_ "the ground as see-through as the terminal's (kawa-glass's file): on as it is made, its alpha as saved, opaque without one"
G=$HOME/.local/state/fedokawaii/foot-glass.ini; rm -f "$G"
eq "$(py 'print(kp.glass())')" 0.92 "no file yet: on (as kawa-glass ensure makes it)"
mkdir -p "${G%/*}"; printf '%s\n' '# kawa-glass' '[colors-dark]' 'alpha=1' '[colors-light]' 'alpha=1' >"$G"
eq "$(py 'print(kp.glass())')" 1.0 "off: opaque"
printf '%s\n' '[colors-dark]' 'alpha=0.92' '[colors-light]' 'alpha=0.92' >"$G"; eq "$(py 'print(kp.glass())')" 0.92 "on"
printf '%s\n' '[colors-dark]' >"$G"; eq "$(py 'print(kp.glass())')" 1.0 "a file without an alpha: opaque (as kawa-glass reads it)"
printf 'alpha=7\n' >"$G"; eq "$(py 'print(kp.glass())')" 1.0 "never more than opaque"
printf 'alpha=x\n' >"$G"; eq "$(py 'print(kp.glass())')" 0.92 "unreadable: as made"
rm -f "$G"
eq "$(grep -c 'see\[0\] = glass()' "$REPO/bin/kawa-panel")" 1 "read again as each window is made (a switch seen at the next open)"
case_ "a meter set fast: one wpctl at a time, the last level asked the one that stays"
eq "$(py 'fresh(); [p.step("sound", 5) for _ in range(4)]; print(sum(c.startswith("run kawa-quick --do volume") for c in u.calls)); u.answer(); print(u.calls[-1]); u.answer(); print(u.calls[-1])')" \
  "$(printf '%s\n' 1 'run kawa-quick --do volume 80' 'run kawa-quick --state')"
case_ "a level being set is shown as asked when the state comes back meanwhile"
eq "$(py 'fresh(); p.step("sound", 5); p.refresh(); u.pending.pop(1)(0, STATE); print(p.state["sound"])')" 65%
case_ "the wheel over a meter: ±5"
eq "$(py 'fresh(); p.wheel(*bead("brightness", 9), True); p.wheel(*bead("sound", 9), False); print(p.state["brightness"], p.state["sound"])')" "75% 60%" "(62 % down: 60, the next multiple of 5)"
eq "$(py 'fresh(); p.wheel(169, 41, True); print(u.calls)')" "[]" "over an hour that has no wheel: nothing"
eq "$(py 'fresh(); p.wheel(233, 58, True); p.wheel(233, 58, False); print(u.calls)')" "['run kawa-quick --do warmer', 'run kawa-quick --do cooler']" "… but the night light's: warmer, cooler"
eq "$(py 'fresh(); p.wheel(169, 120, True); p.wheel(169, 169, False); print(p.state["brightness"], p.state["sound"], u.calls)')" "70% 62% []" "over the air between, or the dial's middle: nothing"

# ── the state ─────────────────────────────────────────────────────────────────────────
case_ "one reading at a time: asked again meanwhile, read once more after"
eq "$(py 'fresh(); p.refresh(); p.refresh(); p.refresh(); print(sum(c == "run kawa-quick --state" for c in u.calls)); u.answer(STATE); print(sum(c == "run kawa-quick --state" for c in u.calls))')" "$(printf '1\n2')"
case_ "kawa-quick failing: the last state stays"
eq "$(py 'fresh(); p.refresh(); u.answer("", 1); print(p.state["night"])')" on
case_ "the colours: the theme's panel.conf, every name the drawing uses (surface: the level display's solid ground; accent_hi: an hour's picture the moment it is stamped)"
for m in dark light; do
  eq "$(py "c = kp.colours('$REPO/configs/home/.config/fedokawaii/themes/$m/panel.conf'); print(sorted(c) == sorted(['ground','surface','key','edge','edge2','faint','muted','text','strong','accent','accent_text','accent_hi','select','text_on_select','select_lo','asagi','flame','hair','shadow1','shadow2']), all(0 <= v <= 1 for t in c.values() for v in t), sorted(k for k, t in c.items() if len(t) == 4), sorted({len(t) for t in c.values()}))")" "True True ['hair', 'shadow1', 'shadow2'] [3, 4]" "$m: the frame's hairline and its two shadows carry an alpha, the rest are plain"
done
case_ "a theme switch while it runs: kawa-theme's rename of the link over current is seen, and the new link's colours read (light after dark)"
# (watch_theme with a stand-in Gio: the folder's events as GIO gives them for a rename —
# the new link moved onto "current"; on a real screen: the panel opened after kawa-theme light
# draws the light ground — the theme's panel.conf)
mkdir -p "$HOME/.config/fedokawaii/themes"
for m in dark light; do ln -sfn "$REPO/configs/home/.config/fedokawaii/themes/$m" "$HOME/.config/fedokawaii/themes/$m"; done
ln -sfn themes/dark "$HOME/.config/fedokawaii/current"
eq "$(py '
import os
class F:
    def __init__(self, p): self.p = p
    def get_path(self): return self.p
    def get_basename(self): return os.path.basename(self.p)
class Mon:
    def connect(self, sig, fn): self.fn = fn
class Gio:
    class FileMonitorFlags: WATCH_MOVES = 1
    class File:
        @staticmethod
        def new_for_path(d):
            class D:
                def monitor_directory(self, flags, c): Gio.mon = Mon(); return Gio.mon
            return D()
seen = []
def changed(): seen.append("%02x%02x%02x" % tuple(round(v * 255) for v in kp.colours(os.path.join(kp.CURRENT, "panel.conf"))["ground"]))
kp.watch_theme(Gio, changed)
d = os.path.dirname(kp.CURRENT)
changed()
os.symlink("themes/light", d + "/current.new"); os.rename(d + "/current.new", kp.CURRENT)
Gio.mon.fn(Gio.mon, F(d + "/current.new"), F(kp.CURRENT), 0)     # (the rename)
Gio.mon.fn(Gio.mon, F(d + "/state.sh"), None, 0)                    # (something else there: nothing)
print(" ".join(seen))')" "$(for m in dark light; do sed -n 's/^ground=//p' "$REPO/configs/home/.config/fedokawaii/themes/$m/panel.conf"; done | paste -sd ' ')"
used=$(grep -oE '"(ground|key|edge|edge2|faint|muted|text|strong|accent|accent_text|select|text_on_select|select_lo|asagi|[a-z_0-9]+)"' "$REPO/bin/kawa-panel" | sort -u | tr -d '"' | tr '\n' ' ')
for n in ground key edge edge2 faint muted text strong accent accent_text select text_on_select select_lo asagi flame hair shadow1 shadow2; do has " $used" " $n " "$n is drawn with"; done

# ── every open afresh: nothing remembered ──────────────────────────────────────────────
case_ "a meter dragged, closed, opened again: no cursor, nothing hot, no drag — nothing highlighted"
eq "$(py 'fresh(); p.request(); b = bead("brightness", 9); p.hover(*b); p.press(*b); p.hover(*bead("brightness", 5), dragging=True); p.close("chosen"); p.request(); print(p.focus, p.hot, p.dragging, p.pointer)')" "None None None None"
eq "$(py 'fresh(); p.request(); p.focus = "brightness"; p.press(*bead("brightness", 9)); p.close("lost"); u.t += 1; p.request(); print(p.focus, p.hot, p.dragging)')" "None None None" "… also a cursor the keys had shown, and closed by a click outside"
eq "$(py 'fresh(); p.request(); p.press(*bead("brightness", 9)); p.close("chosen"); p.request(); i = p.item("brightness"); print(sorted({x for x in kp.look(i, i.key == p.focus, i.key == p.hot).values() if x}))')" \
  "['muted', 'text']" "the brightness arc drawn as at rest: no vermilion lacquer, its picture not lit"
eq "$(py 'fresh(); p.request(); p.press(*bead("brightness", 9)); p.close("chosen"); p.request(); n = len(u.calls); p.hover(233, 58, dragging=True); print([c for c in u.calls[n:] if "--do" in c], p.hot)')" "[] night" \
  "a motion with the button held after reopening: no drag carried over"
case_ "no cursor until a key asks: the first arrow, Tab or Enter puts it on the first item (the theme) and does nothing else"
for k in Down Up Left Right h j k l Tab ISO_Left_Tab Return KP_Enter space; do
  eq "$(py "fresh(); p.request(); u.calls.clear(); p.key('$k'); print(p.focus, p.state['brightness'], [c for c in u.calls if c.startswith('run')])")" "theme 70% []" "$k"
done
eq "$(py 'fresh(); p.request(); p.key("Down"); p.key("Down"); print(p.focus)')" bluetooth "then the keys go on from there (down the dial to six o'clock)"
eq "$(py 'fresh(); p.request(); p.key("Escape"); print(p.visible)')" False "Esc closes it, cursor or not"
eq "$(py 'fresh(); p.request(); p.key("F5"); print(p.focus)')" None "another key: nothing"
case_ "every open: the cursor gone, even when the keys showed it"
eq "$(py 'fresh(); p.request(); p.key("Down"); p.key("Down"); p.close("chosen"); p.request(); print(p.focus)')" None

# ── the pointer: in, out, over a panel that changes ────────────────────────────────────
case_ "the pointer coming in (enter-notify): what is under it hot at once — and the cursor there — before any motion, only that item redrawn"
eq "$(py 'fresh(); p.request(); u.drawn.clear(); p.enter(233, 58); print(p.hot, p.focus, sorted({tuple(d) for d in u.drawn}))')" "night night [('night',)]"
eq "$(py 'fresh(); p.request(); p.enter(5, 5); print(p.hot, p.focus)')" "None None" "on the frame: nothing"
eq "$(py 'fresh(); p.request(); p.press(*bead("brightness", 9)); p.enter(233, 58); print(p.hot)')" brightness "during a drag the hot one stays"
case_ "it opens under the pointer: the item there is hot as the window says the pointer is in"
eq "$(py 'fresh(); p.request(); p.enter(300, 25); print(p.hot, p.focus)')" "wallpaper wallpaper"
case_ "the pointer leaving: only a real leave clears it — not one into a child's window, not a grab's crossing"
eq "$(py 'print([kp.real_leave(m, d) for m, d in (("normal", "nonlinear"), ("normal", "ancestor"), ("ungrab", "nonlinear"), ("normal", "inferior"), ("grab", "nonlinear"), ("gtk-grab", "ancestor"), ("state-changed", "nonlinear"))])')" \
  "[True, True, True, False, False, False, False]"
has "$(cat "$REPO/bin/kawa-panel")" 'if real_leave(ev.mode.value_nick, ev.detail.value_nick):'
has "$(cat "$REPO/bin/kawa-panel")" 'win.connect("enter-notify-event", on_enter)'
has "$(cat "$REPO/bin/kawa-panel")" 'Gdk.EventMask.ENTER_NOTIFY_MASK'
case_ "a click acts on the item under the pointer — hot at once, even with no motion or enter before it"
eq "$(py 'fresh(); p.request(); u.calls.clear(); p.press(233, 58); print(p.hot, u.calls[-2:])')" "night ['redraw', 'run kawa-quick --do night']"
eq "$(py 'fresh(); p.request(); p.hover(233, 58); u.calls.clear(); p.press(280, 105); print(p.hot, u.calls[-1])')" "vrr run kawa-quick --do vrr" "a stale hot one does not matter: the click's place does"
case_ "let go: the hot one is what is under the pointer then (a drag may end anywhere)"
eq "$(py 'fresh(); p.request(); p.press(*bead("brightness", 9)); p.hover(233, 58, dragging=True); p.release(233, 58); print(p.hot, p.dragging)')" "night None"
eq "$(py 'fresh(); p.request(); p.press(*bead("brightness", 9)); p.release(400, 400); print(p.hot)')" None "let go outside: nothing"
case_ "the panel changing under a still pointer (a state read): the hot one is what is under it now"
eq "$(py 'fresh(); p.request(); p.enter(169, 297); a = p.hot; u.answer(STATE.replace("bluetooth\ton\n","").replace("devices\tnone\n","")); print(a, p.hot)')" "bluetooth network" "twelve hours to ten: what stands at six o'clock is the network now"
eq "$(py 'opened("sound", SOUND); p.enter(200, 171); print(p.hot); p.refresh(); u.answer(SOUND.replace("input\t90", "output\t91\t0\tUSB DAC\t\t\t\t\t\ninput\t90")); print(p.hot)')" \
  "$(printf '%s\n' out:73 out:73)" "a device added below: the same row still under it"
eq "$(py 'opened("sound", SOUND); p.enter(200, 151); print(p.hot); p.refresh(); u.answer("\n".join(l for l in SOUND.split("\n") if not l.startswith("output\t62"))); print(p.hot)')" \
  "$(printf '%s\n' out:62 out:73)" "the row under it gone: the one that took its place"
case_ "one light in every panel and menu: the pointer moves the cursor in the sound panel, in a menu and in the launcher, as in quick settings"
eq "$(py 'opened("sound", SOUND); p.enter(200, 171); print(p.hot, p.focus)')" "out:73 out:73" "the sound panel"
eq "$(py 'fresh(); p.request("menu x", kp.Menu(["a", "b", "c"]), lambda rc, t: 0); it = p.item("2"); p.enter(it.x + 2, it.y + 2); print(p.hot, p.focus)')" "2 2" "a menu"
eq "$(py 'fresh(); p.request("launcher", kp.Launcher([], {}), None); print(p.hot, p.focus)')" "None None" "the launcher, no entries: nothing to take"
eq "$(py 'fresh(); p.enter(233, 58); print(p.hot, p.focus)')" "night None" "a panel not on screen: no cursor to move"
case_ "the pointer works whether or not the panel has the keyboard: motion, enter and clicks never ask for it"
lacks "$(sed -n '/^class Panel/,/^def mark/p' "$REPO/bin/kawa-panel")" 'has_focus'
case_ "the keyboard: the panel's own while open (exclusive: dwl treats it as a menu — a click outside takes it, closing it)"
has "$(cat "$REPO/bin/kawa-panel")" 'GtkLayerShell.set_keyboard_mode(win, GtkLayerShell.KeyboardMode.EXCLUSIVE)'
case_ "only the window on screen closes it: the one just replaced losing the keyboard a moment later does not"
has "$(cat "$REPO/bin/kawa-panel")" 'win.connect("focus-out-event", lambda w, ev: (w is view["win"] and panel.close("lost")) or False)'
has "$(cat "$REPO/bin/kawa-panel")" 'win.connect("unmap-event", lambda w, ev: (w is view["win"] and panel.close("lost")) or False)'

# ── the sound panel (--sound) ──────────────────────────────────────────────────────────
case_ "the sound panel: sound (the speaker — the volume, mute, mixer), output (headphones) and input (the microphone) — a row each, the default lit — mute microphone"
eq "$(py 'opened("sound", SOUND); print(" ".join(i.key for i in p.items)); print(p.heads)')" \
  "$(printf '%s\n' "sound mute mixer out:62 out:73 in:67 in:90 mic mictest" "[('speaker', 'sound', 17, 17), ('headphones', 'output', 17, 113), ('mic', 'input', 17, 201)]")"
eq "$(py 'opened("sound", SOUND); print(" ".join(f"{i.key}:{i.kind}:{i.x},{i.y},{i.w},{i.h}" for i in p.items), p.size, p.win)')" \
  "sound:meter:17,45,376,20 mute:key:17,73,184,20 mixer:key:209,73,184,20 out:62:row:17,141,376,20 out:73:row:17,161,376,20 in:67:row:17,229,376,20 in:90:row:17,249,376,20 mic:key:17,277,184,20 mictest:key:209,277,184,20 (410, 314) (411, 316)" \
  "quick settings' width and grid: 17 px from the edges, a heading and 8 px of air above its first row, 20 px of air above a heading that is not first, rows touching, keys one row high 8 px apart"
eq "$(py 'opened("sound", SOUND); print(" | ".join(f"{i.icon} {i.name} {i.lit}" for i in p.items if i.kind == "row"))')" \
  "speaker line out · analog True | speaker LG ULTRAGEAR · HDMI False | mic rear mic True | mic front mic False" "an output the speaker, an input the microphone; the default lit (no boxes ticked)"
eq "$(py 'opened("sound", SOUND); print([i.lit and not i.value for i in p.items if i.kind == "row"])')" "[True, False, True, False]" "the lit rows have no value: each draws the chosen dot"
eq "$(py 'opened("sound", SOUND); print(p.item("mute").icon, p.item("mute").name, "|", p.item("mixer").icon, p.item("mixer").name, "|", p.item("mic").icon, p.item("mic").name)')" \
  "speaker_off mute | sliders mixer | mic_off mute microphone" "as kawa-audio said them: each what it will do"
eq "$(py 'opened("sound", SOUND.replace("muted\toff", "muted\ton").replace("mic\ton", "mic\tmuted")); print(p.item("mute").icon, p.item("mute").name, p.item("sound").muted, p.item("sound").value, "|", p.item("mic").icon, p.item("mic").name)')" \
  "speaker unmute True 62% | mic unmute microphone" "muted: unmute (the level kept, its segments hollow), the microphone too"
eq "$(py 'opened("sound", "sound\tno output\nmuted\toff\nmic\tnone\n"); print(" ".join(i.key for i in p.items), p.nones, p.size)')" \
  "sound mute mixer [(17, 141), (17, 209)] (410, 246)" "no devices: each list says none; no input, no microphone to mute"
case_ "the microphone's foot: ONE row of two half-width keys side by side, exactly as mute and mixer above — mute microphone at the left edge, test mic a gap after it, the same y — and nothing else under 入 (no level, no third key)"
eq "$(py 'opened("sound", SOUND); m, t = p.item("mic"), p.item("mictest"); x0, half = kp.BORDER + kp.PAD, (kp.INNER - kp.GAP) // 2
print(m.y == t.y, m.row == t.row, m.x == x0, m.w == half, t.x == x0 + half + kp.GAP, t.w == kp.INNER - half - kp.GAP, m.h == t.h == kp.KEY_H, (m.x, m.w, t.x, t.w))')" \
  "True True True True True True True (17, 184, 209, 184)"
eq "$(py 'opened("sound", SOUND); mu, mx, m, t = (p.item(k) for k in ("mute", "mixer", "mic", "mictest")); print((m.x, m.w, t.x, t.w) == (mu.x, mu.w, mx.x, mx.w), p.items[-1].key, p.items[-2].key)')" \
  "True mictest mic" "the very columns of mute · mixer; the last row of the panel"
eq "$(py 'opened("sound", SOUND); m = p.item("mic"); print(p.size[1] - (m.y + m.h))')" 17 "16 px of pad and the hairline under the keys: the panel ends there"
eq "$(py 'opened("sound", SOUND.replace("mic\ton\n", "mic\tmuted\n")); m, t = p.item("mic"), p.item("mictest"); print(m.icon, m.name, m.w, "|", t.icon, t.name, t.w)')" \
  "mic unmute microphone 184 | mic test mic 184" "muted: unmute microphone — the longest name the foot has"
eq "$(py 'print(kp.px_of("unmute microphone") + kp.GLYPH_COL + kp.GAP <= (kp.INNER - kp.GAP) // 2 - 2 * kp.CELL)')" True "…its icon, gap and name with a cell of air either side, never cut"
eq "$(py 'opened("sound", SOUND.replace("mic\ton\n", "mic\ton\ncleanmic\ton\nlevel\t50%\n")); print(" ".join(i.key for i in p.items[-3:]), p.size)')" \
  "in:90 mic mictest (410, 314)" "a stray cleanmic or level line (a kawa-quick from before) draws nothing: the foot is the same two keys"
case_ "mute microphone: a click switches it (kawa-quick --do micmute), the panel stays and reads back; test mic runs on its own, the panel stays"
eq "$(py 'opened("sound", SOUND); m = p.item("mic"); p.press(m.x + 5, m.y + 5); print(u.calls[-1]); u.answer(); print(u.calls[-1], p.visible)')" \
  "$(printf '%s\n' 'run kawa-quick --do micmute' 'run kawa-quick --state sound True')"
eq "$(py 'opened("sound", SOUND); t = p.item("mictest"); p.press(t.x + 5, t.y + 5); print(u.calls[-1], p.visible)')" "launch kawa-quick --do mictest True"
eq "$(py 'opened("sound", SOUND); p.focus = "mictest"; p.key("Return"); print(u.calls[-1], p.visible)')" "launch kawa-quick --do mictest True"
case_ "the sound meter's icon is the bar's: no wave at 0, one to 25 %, two to 50, three to 75, four above; crossed out muted"
eq "$(py 'print(*[kp.vol_icon(v, False) for v in (0, 1, 25, 26, 50, 51, 75, 76, 100, 130)], kp.vol_icon(40, True), kp.vol_icon(None, False))')" \
  "vol_0 vol_1 vol_1 vol_2 vol_2 vol_3 vol_3 vol_4 vol_4 vol_4 vol_mute vol_0"
eq "$(py 'i = kp.icons(); print(all(f"vol_{n}" in i for n in (0, 1, 2, 3, 4, "mute")), all(k in i for k in ("speaker", "speaker_off", "sliders", "mic", "mic_off")))')" "True True"
case_ "parse_sound: the levels, the devices in order, each by its short name; odd lines skipped"
eq "$(py 's = kp.parse_sound("sound\t40%\nmuted\ton\nmic\tnone\noutput\t5\t1\tA Analog Stereo\t\t\t\t\t\ninput\tx\t0\tbad\t\t\t\t\t\noutput\t6\t0\tB\n"); print(s["sound"], s["muted"], s["mic"], s["outputs"], s["inputs"])')" \
  "40% on none [('5', True, 'analog')] []"
case_ "a device's short name: the port in use, else a nick that is a name, else a card that is a product; an output adds its form"
dn() { py "print(kp.device_name($1))"; }
eq "$(dn '"output", "Ryzen HD Audio Controller Analog Stereo", "Line Out", "ALC1220 Analog", "Ryzen HD Audio Controller", "Analog Stereo", "alsa"')" "line out · analog" "the owner's speakers"
eq "$(dn '"output", "Ryzen HD Audio Controller Analog Stereo", "Headphones", "ALC1220 Analog", "Ryzen HD Audio Controller", "Analog Stereo", "alsa"')" "headphones · analog" "headphones in the front jack"
eq "$(dn '"output", "Navi 48 HDMI/DP Audio Controller Digital Stereo (HDMI)", "HDMI / DisplayPort", "LG ULTRAGEAR", "Navi 48 HDMI/DP Audio Controller", "Digital Stereo (HDMI)", "alsa"')" "LG ULTRAGEAR · HDMI" "the monitor's own name, as it is"
eq "$(dn '"output", "Navi 48 HDMI/DP Audio Controller Digital Stereo (HDMI 2)", "HDMI / DisplayPort", "HDMI 1", "Navi 48 HDMI/DP Audio Controller", "Digital Stereo (HDMI 2)", "alsa"')" "HDMI 2" "no monitor name: the form alone"
eq "$(dn '"input", "Ryzen HD Audio Controller Analog Stereo", "Rear Microphone", "ALC1220 Analog", "Ryzen HD Audio Controller", "Analog Stereo", "alsa"')" "rear mic"
eq "$(dn '"input", "Ryzen HD Audio Controller Analog Stereo", "Front Microphone", "ALC1220 Analog", "Ryzen HD Audio Controller", "Analog Stereo", "alsa"')" "front mic"
eq "$(dn '"output", "Ryzen HD Audio Controller Digital Stereo (IEC958)", "Digital Output (S/PDIF)", "ALC1220 Digital", "Ryzen HD Audio Controller", "Digital Stereo (IEC958)", "alsa"')" "S/PDIF"
eq "$(dn '"output", "Ryzen HD Audio Controller Analog Surround 5.1", "Line Out", "ALC1220 Analog", "Ryzen HD Audio Controller", "Analog Surround 5.1", "alsa"')" "line out · analog 5.1"
eq "$(dn '"input", "Yeti Stereo Microphone Analog Stereo", "Analog Input", "Yeti Stereo Microphone", "Yeti Stereo Microphone", "Analog Stereo", "alsa"')" "Yeti Stereo Microphone" "a USB microphone: its product's name"
eq "$(dn '"output", "WH-1000XM4", "", "WH-1000XM4", "WH-1000XM4", "", "bluez5"')" "WH-1000XM4 · bluetooth"
eq "$(dn '"output", "Starship/Matisse HD Audio Controller Analog Stereo", "", "", "", "", ""')" "analog" "nothing but the description: its form"
eq "$(dn '"output", "Echo-Cancel Sink", "", "", "", "", ""')" "Echo-Cancel Sink" "no form either: the description as it is"
case_ "two alike: told apart by their cards, else by number"
eq "$(py 'H = ("HDMI / DisplayPort", "HDMI 0"); print(kp.device_names([("output", "Navi 48 HDMI/DP Audio Controller Digital Stereo (HDMI)", *H, "Navi 48 HDMI/DP Audio Controller", "Digital Stereo (HDMI)", "alsa"), ("output", "Radeon High Definition Audio Controller Digital Stereo (HDMI)", *H, "Radeon High Definition Audio Controller", "Digital Stereo (HDMI)", "alsa"), ("output", "X", "", "", "", "", ""), ("output", "X", "", "", "", "", "")]))')" \
  "['HDMI · Navi 48', 'HDMI · Radeon', 'X', 'X 2']"
case_ "every short name fits its row whole (the row's 322 px — 46 columns of Sumi UI's 7 px —, from its name's cell to the chosen dot's two cells of air and the dot) — no …"
eq "$(py 's = kp.parse_sound(SOUND); print(max(kp.px_of(n) for _, _, n in s["outputs"] + s["inputs"]) <= kp.INNER - kp.NAME_X - 2 * kp.CELL - kp.DOT == 322)')" True
case_ "a row's look: the one in use (lit) in strong ink, the others quiet; the pointer adds nothing (it moves the cursor), the cursor fills the row"
eq "$(py 'opened("sound", SOUND); a, b = p.item("out:62"), p.item("out:73"); print(*[" ".join(str(v) for v in kp.look(i, f, h).values()) for i, f, h in ((a, False, False), (b, False, False), (b, False, True), (b, True, False))], sep=" | ")')" \
  "None None strong strong muted False text | None None muted text muted False text | None None muted text muted False text | select None text_on_select text_on_select text_on_select True text_on_select"
case_ "another output picked (a click or Enter): the default (kawa-quick --do output ID: wpctl set-default), the panel stays and reads again"
eq "$(py 'opened("sound", SOUND); p.press(200, 171); print(u.calls[-1]); u.answer(); print(u.calls[-1], p.visible)')" \
  "$(printf '%s\n' 'run kawa-quick --do output 73' 'run kawa-quick --state sound True')"
eq "$(py 'opened("sound", SOUND); p.press(200, 259); print(u.calls[-1])')" "run kawa-quick --do input 90" "an input"
eq "$(py 'opened("sound", SOUND); p.focus = "out:73"; p.key("Return"); print(u.calls[-1])')" "run kawa-quick --do output 73" "Enter"
eq "$(py 'opened("sound", SOUND); p.press(200, 151); p.press(200, 239); print([c for c in u.calls if c.startswith("run")])')" "[]" "the one in use: nothing to change"
case_ "mute and mute microphone: switched over, the panel stays; mixer: the panel closes, wiremix opens (kawa-quick --do mixer)"
eq "$(py 'opened("sound", SOUND); p.press(60, 83); print(u.calls[-1]); u.answer(); print(u.calls[-1], p.visible)')" \
  "$(printf '%s\n' 'run kawa-quick --do mute' 'run kawa-quick --state sound True')"
eq "$(py 'opened("sound", SOUND); p.press(100, 287); print(u.calls[-1], p.visible)')" "run kawa-quick --do micmute True"
eq "$(py 'opened("sound", SOUND); p.press(300, 287); print(u.calls[-1], p.visible)')" "launch kawa-quick --do mictest True" "test mic: the right half"
eq "$(py 'opened("sound", SOUND); p.press(300, 83); print(", ".join(u.calls[-3:]), p.visible)')" "hide, light sound off, launch kawa-quick --do mixer False"
case_ "the volume: dragged, clicked, the wheel, ← →, as quick settings' (kawa-quick --do volume N), one at a time"
eq "$(py 'opened("sound", SOUND); p.press(235 + 76, 55); print(p.state["sound"], u.calls[-1])')" "50% run kawa-quick --do volume 50"
eq "$(py 'opened("sound", SOUND); p.press(235 + 4, 55); p.hover(420, 55, dragging=True); p.hover(235 + 120, 55, dragging=True); print(sum(c.startswith("run kawa-quick --do volume") for c in u.calls)); u.answer(); print(u.calls[-1])')" \
  "$(printf '%s\n' 1 'run kawa-quick --do volume 80')"
eq "$(py 'opened("sound", SOUND); p.wheel(200, 55, True); print(p.state["sound"])')" 65%
eq "$(py 'opened("sound", SOUND); p.key("Down"); p.key("Right"); print(p.focus, p.state["sound"])')" "sound 65%"
case_ "muted: a level set unmutes (kawa-quick --do volume does) — even the same level; the segments solid again at once (hollow while muted)"
eq "$(py 'opened("sound", SOUND.replace("muted\toff", "muted\ton").replace("sound\t62%", "sound\t65%")); print(p.item("sound").muted); p.press(235 + 100, 55); print(p.state["sound"], p.state["muted"], p.item("sound").muted, u.calls[-1])')" \
  "$(printf '%s\n' True '65% off False run kawa-quick --do volume 65')"
case_ "no snapping back: a read of the sound panel started before a change leaves the volume (and its unmute) as set"
eq "$(py 'opened("sound", SOUND.replace("muted\toff", "muted\ton")); p.press(335, 55); p.release(); p.refresh(); u.answer(); u.answer(SOUND.replace("muted\toff", "muted\ton")); print(p.state["sound"], p.state["muted"])')" "65% off"
case_ "a level set in one panel is every panel's: quick settings shows it too, and its older read does not undo it"
eq "$(py 'opened("sound", SOUND); p.refresh("quick"); p.press(335, 55); print(p.states["quick"]["sound"]); u.answer(STATE); print(p.states["quick"]["sound"])')" \
  "$(printf '%s\n' 65% 65%)"
eq "$(py 'opened("brightness", "brightness\t70%\n"); p.key("Right"); print(p.states["quick"]["brightness"], p.state["brightness"])')" "75% 75%"
case_ "the arrows: up and down through the rows (two keys in one), left and right along the keys"
eq "$(py 'opened("sound", SOUND); p.focus = "sound"; [p.key(k) for k in ("Down", "Right", "Down", "Down", "Down", "Down", "Down")]; print(p.focus)')" mic
eq "$(py 'opened("sound", SOUND); p.focus = "mic"; p.key("Up"); p.key("Up"); print(p.focus)')" in:67

# ── the brightness slider (--brightness) ───────────────────────────────────────────────
case_ "the brightness slider: the meter alone, the size of what it holds — its icon on the content's left edge, its last segment on the right"
eq "$(py 'opened("brightness", "brightness\t70%\n"); i = p.items[0]; print([(i.key, i.kind, i.icon, i.name, i.x, i.y, i.w, i.h)], p.size, p.win, p.slider_x(i), p.slider_x(i) + (kp.SEGS - 1) * kp.CELL + kp.SEG_W == i.x + i.w)')" \
  "[('brightness', 'meter', 'bri_3', 'brightness', 17, 17, 278, 20)] (312, 54) (313, 56) 137 True"
eq "$(py 'opened("sound", SOUND); print(p.slider_x(p.item("sound")))')" 235 "the sound panel's segments, their last on the content's edge too"
eq "$(py 'print([kp.bri_icon(v) for v in (None, 0, 19, 20, 70, 99, 100)])')" "['bri_0', 'bri_0', 'bri_0', 'bri_1', 'bri_3', 'bri_4', 'bri_4']" "the icon follows the level, a fifth each (the bar's own)"
case_ "its keys: ← → (h l) change it from the first press (it is all there is) — no cursor drawn for that; a click, a drag, the wheel"
eq "$(py 'opened("brightness", "brightness\t70%\n"); p.key("Right"); p.key("h"); print(p.focus, p.state["brightness"], [c for c in u.calls if c.startswith("run")][0])')" \
  "None 70% run kawa-quick --do brightness 75"
eq "$(py 'opened("brightness", "brightness\t70%\n"); p.press(137 + 76, 27); print(p.state["brightness"])')" 50%
eq "$(py 'opened("brightness", "brightness\t70%\n"); p.wheel(200, 27, False); print(p.state["brightness"])')" 65%
eq "$(py 'opened("brightness", "brightness\tno DDC/CI\n"); p.key("Right"); print(p.state["brightness"], u.calls)')" "no DDC/CI []" "no DDC/CI: the words, the keys do nothing"
eq "$(py 'opened("brightness", "brightness\t70%\n"); p.key("Tab"); print(p.focus)')" brightness "Tab shows the cursor on it"

# ── one panel at a time, each its own key, marker and poke ─────────────────────────────
case_ "each mode reads its own state (kawa-quick --state, --state sound, --state brightness)"
for m in sound brightness; do
  eq "$(py "fresh(); p.request('$m'); print(u.calls[-1])")" "run kawa-quick --state $m" "$m"
done
case_ "--sound, --brightness: open, and the same again closes it"
for m in sound brightness; do
  eq "$(py "fresh(); p.request('$m'); print(', '.join(u.calls), p.visible, p.mode); u.calls.clear(); u.t += 0.6; p.request('$m'); print(', '.join(u.calls), p.visible)")" \
    "$(printf '%s\n' "show, light $m on, run kawa-quick --state $m True $m" "hide, light $m off False")" "$m"
done
case_ "opening one closes the one open: never two (quick settings, sound, brightness, in any order)"
eq "$(py 'fresh(); p.request(); u.calls.clear(); p.request("sound"); print(", ".join(u.calls), p.mode, p.visible)')" \
  "hide, light quick off, show, light sound on, run kawa-quick --state sound sound True"
eq "$(py 'fresh(); p.request("sound"); u.calls.clear(); p.request("brightness"); print(", ".join(u.calls))')" \
  "hide, light sound off, show, light brightness on, run kawa-quick --state brightness"
eq "$(py 'fresh(); p.request("brightness"); u.calls.clear(); p.request(); print(", ".join(u.calls))')" \
  "hide, light brightness off, show, light quick on, run kawa-quick --state"
eq "$(py '
fresh(); lit = set()
u.light = lambda m, on: lit.add(m) if on else lit.discard(m)
for m in ("quick", "sound", "brightness", "sound", "quick", "brightness", "brightness", "quick"):
    u.t += 1; p.request(m); print(sorted(lit), end=" ")')" \
  "['quick'] ['sound'] ['brightness'] ['sound'] ['quick'] ['brightness'] [] ['quick'] " "one lit at most, the one open"
case_ "a click on another module while one is open: that click closed it (outside) — the other opens all the same"
eq "$(py 'fresh(); u.cid = "c1"; p.request("sound"); u.cid = "c2"; p.close("lost"); u.t += 0.1; p.request("brightness"); print(p.mode, p.visible)')" "brightness True"
eq "$(py 'fresh(); u.cid = "c1"; p.request("sound"); u.cid = "c2"; p.close("lost"); u.t += 0.1; p.request("sound"); print(p.visible)')" False "its own module's click: closed it stays"
eq "$(py 'fresh(); p.request("sound"); u.t += 0.1; p.request("brightness"); u.t += 0.1; p.request("sound"); print(p.mode, p.visible)')" "sound True" "another's key switches to it, then its own key back"
case_ "every way out takes its marker away: its key, Esc, a click outside, another menu or the launcher (close), a choice, another panel"
for m in quick sound brightness; do
  for how in 'p.request(M)' 'p.key("Escape")' 'p.close("lost")' 'p.close("chosen")' 'p.request(OTHER)'; do
    eq "$(py "M = '$m'; OTHER = 'sound' if M != 'sound' else 'quick'; fresh(); p.request(M); u.t += 1; u.calls.clear(); $how; print('light ' + M + ' off' in u.calls)")" True "$m: $how"
  done
done
eq "$(py 'fresh(); p.request("sound"); u.answer(SOUND); u.calls.clear(); p.press(300, 83); print("light sound off" in u.calls)')" True "sound: mixer"
eq "$(py 'fresh(); p.request(); u.calls.clear(); p.activate("power"); print("light quick off" in u.calls)')" True "quick: an opener"
case_ "… even when taking the window away fails"
eq "$(py '
fresh(); p.request("sound"); u.calls.clear()
def bad(): raise RuntimeError("gone")
u.hide = bad
try: p.close("chosen")
except RuntimeError: pass
print(u.calls, p.visible)')" "['light sound off'] False"
case_ "the markers: each mode's file, holding the panel's pid while open, gone when closed; one left by a panel gone, cleared as it starts"
eq "$(py 'import os; print(*[os.path.basename(kp.MARKS[m]) for m in kp.MODES])')" \
  "kawa-panel.open kawa-panel-sound.open kawa-panel-brightness.open"
eq "$(py 'print(kp.POKE)')" "{'quick': 15, 'sound': 16, 'brightness': 14, 'launcher': 20}" "the cat +15 · a new +16 for the sound · the brightness module's own +14 · the torii's +20 for the launcher"
R=$TMP/rt; mkdir -p "$R"
eq "$(XDG_RUNTIME_DIR=$R py '
import os
kp.mark("sound", True); print(sorted(os.listdir(kp.RUN)), open(kp.MARKS["sound"]).read().strip() == str(os.getpid()))
kp.mark("sound", False); kp.mark("sound", False); print(sorted(os.listdir(kp.RUN)))')" \
  "$(printf '%s\n' "['kawa-panel-sound.open'] True" "[]")" "written whole (a rename), then gone; twice gone is no error"
: >"$R/kawa-panel.open"; echo 1 >"$R/kawa-panel-brightness.open"; ln -sf /nonexistent "$R/kawa-panel-sound.open"
eq "$(XDG_RUNTIME_DIR=$R py 'print(kp.stale_marks()); import os; print(sorted(os.listdir(kp.RUN)))')" \
  "$(printf '%s\n' "['quick', 'sound', 'brightness']" "[]")" "a dangling link too"
has "$(sed -n '/    finally:/,/return 0/p' "$REPO/bin/kawa-panel")" 'panel.close("ended")' "ended (SIGTERM, SIGHUP, Ctrl+C): the open one's marker goes"
has "$(cat "$REPO/bin/kawa-panel")" 'for mode in stale_marks():' "killed or crashed: its next start clears it (and the bar's lit() checks the pid meanwhile)"
case_ "the panel never hides alive with a marker: closing always destroys its window and takes the marker"
has "$(sed -n '/        def hide(self):/,/destroy/p' "$REPO/bin/kawa-panel")" 'GLib.idle_add(w.destroy)'
eq "$(grep -n 'ui.hide()' "$REPO/bin/kawa-panel" | wc -l)" 1 "only close() takes the window away"
eq "$(py 'fresh(); p.request(); p.close("chosen"); print(p.visible, u.calls[-2:])')" "False ['hide', 'light quick off']"
case_ "opened by its key: every panel's right hairline 8 px from the right edge (a margin of 7 and the shadow's column past it; the bar's modules sit within a panel's width of its end); 8 px under the bar"
for m in quick sound brightness; do
  eq "$(py "fresh(); p.request('$m'); print(p.place)")" "('right', 7, None)" "$m"
done
eq "$(py 'print(kp.menu_place(True, None, 300), kp.menu_place(False, None, 300), kp.EDGE, kp.SHADOW_R)')" "('right', 7, None) ('centre', 0, None) 8 1" "a menu dropped from the bar by a key: as quick settings; any other in the middle"
case_ "--middle (the calendar, the timer): dropped from the bar's middle, the date's — a click or a key alike, on the clicked output; the top alone anchored (centred on it)"
eq "$(py 'print(kp.menu_place(True, None, 410, True), kp.menu_place(True, (880, 0, 1920), 410, True), kp.menu_place(True, (2900, 1920, 2560), 410, True))')" \
  "('middle', 0, None) ('middle', 0, 0) ('middle', 0, 1920)" "by a key: dwl's output; by a click: that one"
eq "$(py 'print(kp.menu_place(False, None, 410, True))')" "('centre', 0, None)" "--middle without --drop: the middle of the screen, as any menu"
f=$(sed -n '/side, margin, out_x = panel.place/,/area.set_size_request/p' "$REPO/bin/kawa-panel")
has "$f" 'if side == "middle":'; has "$f" 'GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.TOP, True)'
has "$f" 'if side in ("left", "middle") and out_x is not None:' "(the clicked output)"
lacks "$(cat "$REPO/bin/kawa-panel")" "MARGIN" "no place of its own per panel"
has "$(cat "$REPO/bin/kawa-panel")" 'GtkLayerShell.set_margin(win, edge, margin)'
case_ "a menu from the bar's middle has a column of air before its frame, as wide as the shadow's: the window is (1 + box + 1, box + 2), so dwl, centring it, centres the frame to the pixel; any other place has none"
eq "$(py 'fresh(); u.at = (880, 0, 1920); p.request("menu kawa-calendar", kp.Menu(["a", "b"], drop=True, middle=True), lambda rc, t: 0); print(p.place, p.ox, p.size, p.win, p.win == (p.ox + p.size[0] + kp.SHADOW_R, p.size[1] + kp.SHADOW_B))')" \
  "('middle', 0, 0) 1 (194, 74) (196, 76) True"
eq "$(py 'fresh(); p.request("menu kawa-calendar", kp.Menu(["a", "b"], drop=True, middle=True), lambda rc, t: 0); print(p.place, p.ox, p.win)')" "('middle', 0, None) 1 (196, 76)" "by a key: dwl's output"
eq "$(py 'fresh(); p.request("menu kawa-drives", kp.Menu(["a", "b"], drop=True), lambda rc, t: 0); print(p.place, p.ox, p.win); p.request("menu kawa-power", kp.Menu(["a", "b"]), lambda rc, t: 0); print(p.place, p.ox, p.win)')" \
  "$(printf '%s\n' "('right', 7, None) 0 (195, 76)" "('centre', 0, None) 0 (195, 76)")" "a dropdown from the right, a menu in the middle of the screen: the box and the shadow, no air before"
eq "$(py 'fresh(); p.request("menu kawa-calendar", kp.Menu(["a", "b"], drop=True, middle=True), lambda rc, t: 0); p.close("chosen"); p.request("sound"); print(p.ox, p.win == (p.size[0] + 1, p.size[1] + 2))')" "0 True" "the next panel opens without it"
case_ "opened by a click on the bar: centred under the pointer, on that output, kept 8 px inside its edges"
eq "$(py 'print(kp.hang(1563, 0, 1920, 410), kp.hang(1616, 0, 1920, 312), kp.hang(1900, 0, 1920, 338), kp.hang(30, 0, 1920, 338), kp.hang(960, 0, 1920, 338))')" "1358 1460 1574 8 791" \
  "the volume (the sound panel, 410 wide), the brightness (its slider, 312), the cat (quick settings, 338: held at the right edge, 1920 − 338 − 8), the far left (8), the middle (960 − 169)"
eq "$(py 'print(kp.hang(1920 + 1563, 1920, 2560, 410), kp.hang(1920 + 2550, 1920, 2560, 410), kp.hang(1925, 1920, 2560, 410))')" "1358 2142 8" \
  "on a second output (its own x and width): the margin is the output's own"
eq "$(py 'print(kp.hang(100, 0, 300, 410))')" 8 "an output narrower than the panel: from its left edge"
case_ "dwl's record (X Y OUTPUT OUTPUT_X OUTPUT_WIDTH): taken only while fresh (under 1 s old), and only whole"
eq "$(py 'print(kp.bar_click("1563 15 DP-1 0 1920\n", 0.2), kp.bar_click("1563.7 15 DP-1 1920 2560", 0.0), kp.bar_click("1563 15 DP-1 0 1920", 1.5), kp.bar_click("1563 15 DP-1 0", 0.1), kp.bar_click("x 15 DP-1 0 1920", 0.1), kp.bar_click("", 0.1))')" \
  "(1563, 0, 1920) (1563, 1920, 2560) None None None None"
eq "$(py 'fresh(); u.at = (1563, 0, 1920); p.request("sound"); print(p.place); u.at = None; u.t += 1; p.request("sound"); u.t += 1; p.request("sound"); print(p.place)')" \
  "$(printf '%s\n' "('left', 1358, 0)" "('right', 7, None)")" "each open asks anew: a click's place does not stay for the key's"
eq "$(py 'fresh(); u.at = (1900, 0, 1920); p.request(); print(p.place)')" "('left', 1574, 0)" "the cat: under it, held 8 px from the right edge (1920 − 338 − 8)"
eq "$(XDG_RUNTIME_DIR=$TMP py 'import os; print(os.path.basename(kp.POINTER), kp.FRESH, kp.EDGE)')" "dwl-pointer 1.0 8"
case_ "a state read for another panel than the open one: kept, the open one's layout untouched"
eq "$(py 'opened("sound", SOUND); n = len(p.items); p.refresh("quick"); u.answer(STATE); print(len(p.items) == n, p.mode, p.states["quick"]["night"])')" "True sound on"

# ── asking the running panel ───────────────────────────────────────────────────────────
case_ "--open, --sound and --brightness with a panel running: a request line into its fifo each, whole, in order"
R=$TMP/ask; mkdir -p "$R"; mkfifo "$R/kawa-panel.in"; exec 6<>"$R/kawa-panel.in"
python3 -I -c 'import time; time.sleep(30)' kawa-panel & pp=$! # (a process whose command line says kawa-panel)
for _ in {1..20}; do grep -qa kawa-panel "/proc/$pp/cmdline" 2>/dev/null && break; sleep 0.05; done
echo "$pp" >"$R/kawa-panel.pid"
for m in --open --sound --brightness; do rc 0 env XDG_RUNTIME_DIR="$R" PYTHONPATH="$P" python3 "$REPO/bin/kawa-panel" "$m"; done
got=""; for _ in 1 2 3; do read -r -t 2 -u 6 l && got+="$l|"; done
eq "$got" "toggle quick|toggle sound|toggle brightness|"
kill "$pp" 2>/dev/null; wait "$pp" 2>/dev/null; exec 6<&-
case_ "kawa-quick asks it with bash alone (the bar's cat, volume and brightness; Super+X, Super+A): 200 requests from 20 at once — every one arrives, whole"
mkfifo "$R/in2"; mv "$R/in2" "$R/kawa-panel.in"; exec 6<>"$R/kawa-panel.in"
python3 -I -c 'import time; time.sleep(60)' kawa-panel & pp=$!
for _ in {1..20}; do grep -qa kawa-panel "/proc/$pp/cmdline" 2>/dev/null && break; sleep 0.05; done
echo "$pp" >"$R/kawa-panel.pid"
cat <&6 >"$TMP/reqs" & cp=$!
pids=(); for _ in {1..20}; do (for j in {1..10}; do if ((j % 3)); then XDG_RUNTIME_DIR=$R kawa-quick; else XDG_RUNTIME_DIR=$R kawa-quick sound; fi; done) & pids+=($!); done
wait "${pids[@]}"; sleep 0.3; kill "$cp" 2>/dev/null; wait "$cp" 2>/dev/null
eq "$(sort "$TMP/reqs" | uniq -c | awk '{print $1, $2, $3}' | tr '\n' '|')" "140 toggle quick|60 toggle sound|"
kill "$pp" 2>/dev/null; wait "$pp" 2>/dev/null; exec 6<&-
has "$(cat "$REPO/bin/kawa-quick")" 'sound)      toggle sound ;;'
has "$(cat "$REPO/src/dwl/config.h")" 'SHCMD("kawa-quick sound")'
case_ "a menu's options: --drop, --middle, --index, --stay, --password are flags; --title, --width, --lines, --select, --prompt take a value (a number for the three counts); anything else is wrong use"
eq "$(py 'a = kp.menu_args(["--drop", "--middle", "--index", "--select", "3", "--title", "t"]); print(a["drop"], a["middle"], a["index"], a["select"], a["title"], a["stay"], a["password"])')" "True True True 3 t False False"
eq "$(py 'print(kp.menu_args([])["middle"], kp.menu_args(["--drop"])["middle"], kp.menu_args(["--middle", "--title"]), kp.menu_args(["--select", "x"]), kp.menu_args(["--bogus"]))')" "False False None None None"
case_ "a menu's request: the caller, its options, its rows (kawa-menu's file) — a wrong one is no menu"
eq "$(py 'w, m = kp.menu_request("kawa-calendar\n3\n--drop\n--title\npick one\npart\t暦\tOct\nrow\tx\ta\n")
print(w, m.drop, repr(m.title), [l[1] for l in m.lines])')" "kawa-calendar True 'pick one' ['part', 'row']"
eq "$(py 'w, m = kp.menu_request("kawa-calendar\n2\n--drop\n--middle\ncell\t1\n"); print(m.drop, m.middle)')" "True True" "--middle read"
eq "$(py 'w, m = kp.menu_request("kawa-drives\n1\n--drop\nrow\tx\ta\n"); print(m.drop, m.middle)')" "True False" "(none: not dropped from the middle)"
eq "$(py 'print([kp.menu_request(t) for t in ("", "x\n", "x\nz\n", "x\n2\n--title\n", "x\n1\n--bogus\n")])')" "[None, None, None, None, None]"
eq "$(py 'w, m = kp.menu_request("kawa-power\n0\n"); print(w, m.lines, m.drop)')" "kawa-power [] False" "no rows: an empty menu"
case_ "a dropdown lights its button: kawa-drop.open (the panel's pid, the script that asked), its module poked — and dark again as it goes"
eq "$(py 'print(kp.poke_sigs("menu kawa-calendar"), kp.poke_sigs("menu kawa-timer"), kp.poke_sigs("menu kawa-power"), kp.poke_sigs("sound"), kp.poke_sigs("menu kawa-quick"), kp.DROP_POKE["kawa-quick"])')" \
  "[19] [] None [16] [12] 12" "do not disturb's dropdown (kawa-quick dnd) pokes the mode tile: SIGRTMIN+12"
case_ "the bar told from the panel itself, no process started: SIGRTMIN+N to waybar (only once it catches it), every long-running module woken"
R3=$TMP/poke; mkdir -p "$R3"; mkfifo "$R3/kawa-bar.wake.$$"; exec 6<>"$R3/kawa-bar.wake.$$"
python3 -I -c 'import ctypes, signal, sys, time
ctypes.CDLL(None).prctl(15, b"waybar")
for n in (12, 15):
    signal.signal(signal.SIGRTMIN + n, lambda s, f: open(sys.argv[1], "a").write(f"{s - signal.SIGRTMIN}\n"))
open(sys.argv[1] + ".up", "w").close(); time.sleep(20)' "$TMP/wb.log" & wb=$!
for _ in {1..100}; do [[ -e $TMP/wb.log.up ]] && break; sleep 0.05; done
XDG_RUNTIME_DIR=$R3 py 'kp.poke("quick"); kp.poke("sound"); kp.poke("menu kawa-quick")'
# (a wait, not a pause: done the moment both have arrived — 5 s at most, for a loaded machine)
for _ in {1..100}; do [[ $(wc -l <"$TMP/wb.log" 2>/dev/null) -ge 2 ]] && break; sleep 0.05; done
eq "$(sort "$TMP/wb.log" | tr '\n' ' ')" "12 15 " "quick settings: +15 alone; do not disturb's dropdown: +12; the sound's +16 not caught: not sent (it would end waybar)"
kill -0 "$wb" 2>/dev/null && _ok || _no "waybar ended by a signal it does not catch"
n=0; while read -r -t 0.2 -u 6 _; do ((n++)); done; eq "$n" 3 "the wake fifo: a line each"
kill "$wb" 2>/dev/null; wait "$wb" 2>/dev/null; exec 6<&-
R2=$TMP/drop; mkdir -p "$R2"
eq "$(XDG_RUNTIME_DIR=$R2 py 'import os
kp.mark("menu kawa-weather", True); print(open(kp.DROP).read().split()[1], open(kp.DROP).read().split()[0] == str(os.getpid()))
kp.mark("menu kawa-weather", False); print(os.path.exists(kp.DROP))
kp.mark("menu kawa-quick", True); print(open(kp.DROP).read().split()[1]); kp.mark("menu kawa-quick", False)')" "$(printf 'kawa-weather True\nFalse\nkawa-quick')" "(the mode tile reads \"kawa-drop.open kawa-quick\")"
eq "$(py 'fresh(); p.request("menu kawa-calendar", kp.Menu(["a"], drop=True), lambda *a: 0); p.close("lost"); print([c for c in u.calls if c.startswith("light")])')" \
  "['light menu kawa-calendar on', 'light menu kawa-calendar off']"
eq "$(py 'fresh(); p.request("menu kawa-power", kp.Menu(["a"]), lambda *a: 0); p.close("lost"); print([c for c in u.calls if c.startswith("light")])')" "[]" \
  "a menu not dropped from the bar: no button to light"

# ── a menu's size ─────────────────────────────────────────────────────────────────────
case_ "a menu sizes to its content, in whole cells: the value 16 px after the widest detail, rows ending flush at the content's edge (the weather's week)"
eq "$(py 'i = kp.icons(); m = kp.Menu(["part\t" + i["cloud"] + "\tSharjah", "row\t☼\tMon 19\tscorching\t31°", "row\t☁\tTue 20\tmild\t24°"])
print(m.inner(), kp.columns([l[2] for l in m.lines if l[1] == "row"], kp.px_of))')" "192 (90, 190)" "the names 42 px: details at 32 + 42 + 16 = 90; scorching (63) ends at 153, + 16 + the widest value (21): 190; whole cells: 192 wide"
eq "$(py 'print(kp.Menu(["row\tx\tlock", "row\tx\tshut down"]).inner())')" 160 "a short menu: 160 px at least (20 cells)"
eq "$(py 'print(kp.Menu(["key\tx\tprevious", "key\tx\tnext", "key\tx\ttoday"]).inner())')" "$(( ( (3 * (16 + 12 + 8 + 56) + 2 * 8 + 7) / 8) * 8 ))" "keys sharing a row: each as wide as the widest (2 cells of air, the icon 12, a gap, the name), 8 apart — 292 px, whole cells: 296"
eq "$(py 'print(kp.px_of("a—b…"), kp.px_of("写真"))')" "28 28" "the signs Sumi UI draws into one column count 7, a wide letter (a kana, a CJK sign) 14"
case_ "a menu's width, line by line (whole cells): a heading needs 3 cells in, its name, 8 px and 4 cells of rule — and, with a value, 8 px and the value; the calendar's grid 7 days of 40 and 6 gaps of 8"
eq "$(py 'n = "abcdefghijklmnopqrst"; print(kp.Menu(["part\tI\t" + n]).inner(), kp.Menu(["part\tI\t" + n + "\tup 03h 07m"]).inner())')" "208 288" "24 + 140 + 8 + 32 = 204; with a value 8 + 70 more = 282"
eq "$(py 'print(kp.Menu(["cell\t1"]).inner(), kp.Menu(["cell\t1"] * 42).inner(), 7 * kp.CELL_W + 6 * kp.GAP, kp.CELL_W)')" "328 328 328 40"
case_ "a menu's width is always whole cells (8 px) and its rows end flush at the content's edge, the keys' last one with them"
eq "$(py 'print(all(kp.Menu(["row\tx\t" + "a" * n]).inner() % kp.CELL == 0 for n in range(1, 60)), kp.Menu(["row\tx\ta"]).inner())')" "True 160" "every width a multiple of 8, 160 at least"
eq "$(py 'lay = kp.layout_menu(kp.Menu(["part\tI\tone", "row\tx\tsome words here", "on\tx\tb", "key\t<\tprev", "key\t>\tnext"]))
print(lay.size, [(it.kind, it.x, it.w, it.x + it.w == lay.size[0] - (kp.PAD + kp.BORDER)) for it in lay.items])')" \
  "(194, 130) [('row', 17, 160, True), ('row', 17, 160, True), ('key', 17, 76, False), ('key', 101, 76, True)]" "rows the content's width, flush right; two keys share it (76 each, 8 apart), the last flush too"
case_ "the chosen one's dot: a lit row (an on line) with no value reserves its room — two cells of air and the 6 px dot — in the menu's width; a row with a value draws no dot and reserves nothing"
eq "$(py 'n = "abcdefghijklmnopqrst"; print(kp.Menu(["row\tx\t" + n]).inner(), kp.Menu(["on\tx\t" + n]).inner(), kp.DOT + 2 * kp.CELL)')" "176 200 22" "the name from cell 4: 32 + 140 = 172 → 176; with the dot 172 + 22 = 194 → 200"
eq "$(py 'n = "abcdefghijklmnopqrst"; print(kp.Menu(["row\tx\t" + n + "\tdetail"]).inner(), kp.Menu(["on\tx\t" + n + "\tdetail"]).inner())')" "232 256" "with a detail: its column 32 + 140 + 16 = 188, + 42 = 230 → 232; with the dot 252 → 256"
eq "$(py 'n = "abcdefghijklmnopqrst"; print(kp.Menu(["row\tx\t" + n + "\tdetail\tvalue"]).inner(), kp.Menu(["on\tx\t" + n + "\tdetail\tvalue"]).inner())')" "288 288" "a value takes the dot's place: nothing more reserved"
eq "$(py 'print([(it.key, it.lit, it.lit and not it.value) for it in kp.layout_menu(kp.Menu(["row\tx\ta", "on\tx\tb", "on\tx\tc\td\te"])).items])')" "[('0', False, False), ('1', True, True), ('2', True, False)]" "which rows draw the dot: lit and without a value"
case_ "a menu's grid (§3): a heading is its row and 8 px of air, a row of air above one that is not first; rows 20 px, touching; keys one row high, 8 px under what is above them and 8 apart sharing a row; a row only read (info) is never an item"
eq "$(py 'lay = kp.layout_menu(kp.Menu(["part\tI\tone\tvalue", "row\tx\ta", "on\tx\tb", "part\tI\ttwo", "info\tx\tc\td", "key\t<\tprev", "key\t>\tnext", "key\t=\ttoday", "row\tx\tz"]))
print(lay.size, lay.heads); print([(it.key, it.kind, it.x, it.y, it.w, it.h) for it in lay.items]); print(lay.marks, lay.rules, lay.view)')" \
  "$(printf '%s\n' "(266, 226) [('I', 'one', 17, 17, 'value'), ('I', 'two', 17, 105)]" "[('1', 'row', 17, 45, 232, 20), ('2', 'row', 17, 65, 232, 20), ('5', 'key', 17, 161, 72, 20), ('6', 'key', 97, 161, 72, 20), ('7', 'key', 177, 161, 72, 20), ('8', 'row', 17, 189, 232, 20)]" "[('info', 17, 133, 232, 'x', 'c', 'd', '')] [] None")" \
  "232 wide (the keys', whole cells) + 34; the second heading 20 under row b's foot (85), its first row 28 under it; the keys 8 under the info row; no rule between parts"
case_ "the calendar's days: 40 × 20, 8 apart, seven a row from the content's edge, a row under the weekdays for each week; today stamped (its state); its three keys the whole width (104 each) 8 under the last week"
eq "$(py 'm = kp.Menu(["part\tI\tOct 2026"] + ["cell\t%s\thead" % w for w in "Mo Tu We Th Fr Sa Su".split()] + ["cell\t%d\t%s" % (d, "today" if d == 16 else "") for d in range(1, 36)] + ["cell\t%d\tdim" % d for d in range(1, 8)] + ["key\t<\tprevious", "key\t>\tnext", "key\t=\ttoday"])
lay = kp.layout_menu(m); cells = [mk for mk in lay.marks if mk[0] == "cell"]
print(lay.size, len(cells), [(c[1], c[2]) for c in cells[:8]], sorted({c[2] for c in cells}))
print([c[3:5] for c in cells][:1], [c[1:7] for c in cells if c[6] == "today"], [(it.x, it.y, it.w, it.h) for it in lay.items])')" \
  "$(printf '%s\n' "(362, 230) 49 [(17, 45), (65, 45), (113, 45), (161, 45), (209, 45), (257, 45), (305, 45), (17, 65)] [45, 65, 85, 105, 125, 145, 165]" "[(40, 20)] [(65, 105, 40, 20, '16', 'today')] [(17, 193, 104, 20), (129, 193, 104, 20), (241, 193, 104, 20)]")"
case_ "--lines N: N lines of choices whole, their headings above them not counted"
eq "$(py 'print(kp.layout_menu(kp.Menu(["part\t共\tshare", "row\tx\ta", "row\tx\tb", "row\tx\tc"], lines_shown=3)).view)')" None "a heading and three rows, three asked: all of it, no scrolling"
eq "$(py 'm = kp.Menu(["part\t起\tone"] + ["row\t\tk\td"] * 5 + ["part\t写\ttwo"] + ["row\t\tk\td"] * 5, lines_shown=6)
lay = kp.layout_menu(m); top, vh, full = lay.view; it = lay.items[5]
print(top + vh == it.y + it.h, full > vh)')" "True True" "the view ends under the sixth row (the second heading inside it)"
case_ "a menu with a line to type in: a space is typed too (\"750 KB\"), Enter on what no row has gives it"
eq "$(py 'fresh(); got = []
p.open_menu(kp.Menu(["row\tx\t300 KB", "row\tx\t5 MB"], prompt="under "), lambda rc, out: got.append((rc, out)))
for n, c in [("7", "7"), ("5", "5"), ("0", "0"), ("space", " "), ("K", "K"), ("B", "B"), ("Return", "")]:
    p.key(n, c)
print(got)')" "[(0, '750 KB')]"

case_ "--fuzzy (Super+/): a word finds by its letters in order too — whole beats letters, a word's start beats inside; a run strewn over the whole text finds nothing; the rows the best first, each under its part, the parts by their best row (a tie: as listed); without it, words as they are"
eq "$(py 't = "super+w  wallpaper picker (in it, r: change every 4 h)"
print(kp.found("wpa", t) > 0, kp.found("wall", t) > kp.found("wpa", t), kp.found("wall", t) > kp.found("all", t), kp.found("sgg", "super+shift+w  dark / light theme (also in quick settings)"), kp.found("zzz", t))')" \
  "True True True 0 0"
eq "$(py 'L = ["part\tI\tlaunch", "info\t\tSuper+Return\tterminal (foot)", "info\t\tSuper+W\twallpaper picker", "part\tY\tyazi\tmoving", "info\t\tW\twatch a film together (Syncplay)", "info\t\tj / k\tnext / previous file"]
for q, fz in [("wpa", True), ("watch", True), ("w", True), ("wpa", False), ("zzz", True)]:
    m = kp.Menu(L, prompt="", fuzzy=fz); m.query = q
    lines = kp.ranked(m, m.lines) if fz else None
    print(q, [f[1] for _, k, f in lines] if lines is not None else [h[1] for h in kp.layout_menu(m).heads])')" \
  "$(printf '%s\n' "wpa ['launch', 'Super+W', 'yazi', 'W']" "watch ['yazi', 'W']" "w ['yazi', 'W', 'launch', 'Super+W']" "wpa []" "zzz []")" \
  "w: the yazi row's key is w itself (the text's start) — its part goes first; wpa without --fuzzy finds nothing"
eq "$(py 'print(kp.menu_args(["--prompt", "", "--fuzzy"])["fuzzy"], kp.menu_args(["--prompt", ""])["fuzzy"])')" "True False"

case_ "a list only to read (Super+/'s rows, longer than its 24 lines): Down / Up a row, Page Down / Up a page, End / Home its ends; j, k and Space are the field's letters"
eq "$(py 'fresh(); L = ["part\tI\tlaunch"] + ["info\t\tSuper+%d\trow %d" % (i, i) for i in range(60)]
p.request("menu kawa-help", kp.Menu(L, prompt="", fuzzy=True, lines_shown=24), lambda rc, t: 0)
top, vh, full = p.view; R = kp.ROW; s = []
for k in ("Down", "Down", "Up", "Page_Down", "Page_Up", "End", "Down", "Home", "Up"):
    p.key(k); s.append(p.scroll)
p.key("j", "j"); p.key("space", " "); p.key("k", "k")
print(s == [R, 2 * R, R, R + (vh // R - 1) * R, R, full - vh, full - vh, 0, 0], p.state.query == "j k", p.scroll)')" "True True 0"

case_ "a menu's title: words alone a quiet note; MARK<tab>words a failure (a wrong password asked again: §5's failed state) — the mark in the icon column, so the width counts the words alone"
eq "$(py 'print(kp.title_parts("pick one"), kp.title_parts("X\tr.pdf · wrong password"))')" "('', 'pick one') ('X', 'r.pdf · wrong password')"
eq "$(py 'w = "a long name of a locked file, a report.pdf · wrong password"
print(kp.Menu([], prompt="P  ", title=w).inner() == kp.Menu([], prompt="P  ", title="X\t" + w).inner())')" True "(the mark takes no width: it stands in the icon column)"
case_ "a field alone (a password asked): the window ends a pad under it, as above the title — no row of air kept for rows that never come (bug 10's window: 37 px under the field, 22 above the title)"
eq "$(py 'L = kp.layout_menu(kp.Menu([], prompt="P  ", password=True, title="r.pdf · password"))
print(L.size[1] - 2 * (kp.BORDER + kp.PAD) - (kp.ROW + kp.GAP) - kp.KEY_H)')" 0 "(the frame, the pads, the title's row and its air, the field: nothing else)"
eq "$(py 'L = kp.layout_menu(kp.Menu(["row\tx\ta"], prompt="P  ", title="t"))
print(L.size[1] - 2 * (kp.BORDER + kp.PAD) - (kp.ROW + kp.GAP) - kp.KEY_H - kp.SECTION - kp.ROW)')" 0 "(with rows: the row of air between the field and them stays)"
case_ "a password asked with --stay (a locked PDF, an archive — bug 10): Enter answers and the window stays; the caller's next page (\"wrong password\") in its place, the field empty, no new window; keys while it waits are not taken; done closes it at once"
eq "$(py 'fresh(); got = []
M = lambda t: kp.Menu([], prompt="P  ", password=True, stay=True, title=t)
p.request("menu kawa-file", M("r.pdf · password"), lambda rc, out: got.append(out)); u.calls.clear()
for c in "nope": p.key(c, c)
p.key("Return", ""); p.key("x", "x"); p.key("Return", "")
print(got, p.visible, p.holding)
p.request("menu kawa-file", M("r.pdf · wrong password"), lambda rc, out: got.append(out))
print(p.visible, p.holding, repr(p.state.query), p.state.title, "show" in u.calls, "hide" in u.calls)
for c in "pw": p.key(c, c)
p.key("Return", ""); p.done("menu kawa-file"); print(got, p.visible, "hide" in u.calls)')" \
  "$(printf '%s\n' "['nope'] True True" "True False '' r.pdf · wrong password False False" "['nope', 'pw'] False True")"
eq "$(py 'fresh(); got = []
p.request("menu kawa-file", kp.Menu([], prompt="P  ", password=True, stay=True), lambda rc, out: got.append(out))
for c in "pw": p.key(c, c)
p.key("Return", ""); u.timers[-1](); print(got, p.visible)')" "['pw'] False" "its caller silent: closed after the second"
eq "$(py 'fresh(); p.request("menu kawa-file", kp.Menu([], prompt="P  ", password=True, stay=True), lambda rc, out: 0)
p.done("menu kawa-other"); a = p.visible; p.done("menu kawa-file"); b = p.visible
for c in "pw": p.key(c, c)
p.done("menu kawa-file"); print(a, b, p.visible)')" "True True True" "done: only its own caller's, only a held window (one still being typed in stays)"
eq "$(py 'fresh(); got = []
p.request("menu kawa-file", kp.Menu([], prompt="P  ", password=True), lambda rc, out: got.append(out))
for c in "pw": p.key(c, c)
p.key("Return", ""); print(got, p.visible)')" "['pw'] False" "(without --stay: answered and closed, as before)"

# ── use ───────────────────────────────────────────────────────────────────────────────
case_ "--help: what it is; anything else: exit 2"
out=$(python3 -I "$REPO/bin/kawa-panel" --help); has "$out" "quick settings"; has "$out" "kawa-panel.in"; has "$out" "toggle MODE"
has "$out" "--sound"; has "$out" "--brightness"
rc 2 python3 -I "$REPO/bin/kawa-panel" --bogus; rc 2 python3 -I "$REPO/bin/kawa-panel" --open extra
rc 2 python3 -I "$REPO/bin/kawa-panel" --sound --brightness; rc 2 python3 -I "$REPO/bin/kawa-panel" sound
# ── where it comes from ───────────────────────────────────────────────────────────────
case_ "the session starts it (autostart, kept running), its colours come with each theme, the bar's cat asks for it"
has "$(cat "$REPO/configs/home/.config/dwl/autostart.sh")" 'keep kawa-panel'
for m in dark light; do [[ -s $REPO/configs/home/.config/fedokawaii/themes/$m/panel.conf ]] && _ok || _no "no $m panel.conf"; done
has "$(cat "$REPO/configs/home/.config/waybar/config.jsonc")" '"on-click": "kawa-quick"'
# ── the level display (kawa-osd's: design-system §9) ─────────────────────────────────
case_ "the level display: one row on the grid — 258 × 54 (16 of pad, the hairline), its content 28 cells: the icon's column, the meter from cell 3, a gap, four letters right-aligned; 72 px above the screen's foot, gone 1.2 s after the last key"
eq "$(py 'print(kp.LEVEL_W, kp.LEVEL_H, kp.LEVEL_CONTENT, kp.LEVEL_CONTENT // kp.CELL, kp.LEVEL_SEG_X, kp.LEVEL_BOTTOM, kp.LEVEL_MS)')" "258 54 224 28 24 72 1200"
eq "$(py 'print(kp.LEVEL_SEG_X + kp.SPAN + kp.GAP + 4 * kp.COL <= kp.LEVEL_CONTENT, kp.LEVEL_SEG_X == kp.GLYPH_COL + kp.GAP)')" "True True" "the meter, a gap and \"100%\" fit; the meter a gap after the icon's column"
case_ "…asked through the fifo (level ICON PCT [off]: anything else ignored), a window of its own — the overlay layer, its own namespace (dwl's one-menu rule leaves it alone), no keyboard, no input region —, the panel's segments and frame, a marker while it shows"
P_=$(cat "$REPO/bin/kawa-panel")
has "$P_" 'elif len(f) in (3, 4) and f[0] == "level" and f[2].isdigit() and f[3:] in ([], ["off"]):'
has "$P_" 'GtkLayerShell.set_namespace(win, "kawa-level")'
has "$P_" 'GtkLayerShell.set_keyboard_mode(win, GtkLayerShell.KeyboardMode.NONE)'
has "$P_" 'w.input_shape_combine_region(cairo.Region())'
has "$P_" 'segments(cr, _Muted(lvl["off"]), x0 + LEVEL_SEG_X'
has "$P_" 'frame(cr, 0, 0, W, H, "hair", cut=True)'
has "$P_" 'LEVEL_MARK = os.path.join(RUN, "kawa-level.shown")'

done_
