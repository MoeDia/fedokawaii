#!/usr/bin/env bash
# tests/menus/test_panel.sh — kawa-panel, quick settings (a plain menu), the sound panel and the
# brightness slider on screen. Its window needs a screen, so what is tested is everything but
# the drawing (which the real one is measured for in docs/build: placement 8 px under the bar
# and from the edge, the 8 × 20 grid of docs/design-system.md §3): the layout (a heading, the
# two meters, then the rows in three groups — every place on the 20 px pitch, half a row of air
# between the groups, the frame's box and the shadow that makes the window), each row's picture,
# name and state for each state line (on: its picture vermilion and its state strong), the keys
# (the arrows walk the rows, ← → set a meter, Tab goes round) and the mouse, what each choice
# runs (a switch in place, an opener closes the panel and goes), the meters (quick settings',
# the sound panel's and the slider's segments: the level a click, a drag or the wheel means,
# one level at a time), opening and closing (its key, Esc, a click outside — and the click on
# the bar's cat that made that click outside), the bar's cat lit while open, the theme's
# colours, the pid file and its key, and the one light (§5): the pointer moves the cursor in
# every panel and menu (look(): what each item is drawn with — the pointer adds nothing of its
# own — and only the items that changed redrawn). Then the two other panels (--sound,
# --brightness): their layouts, what each choice runs, one panel at a time, each its own marker
# and poke on every way in and out, the pointer's enter and leave, and every open starting
# afresh (no cursor, nothing hot, no drag remembered). The menus' own grid (a heading's air,
# rows, keys, the calendar's days), their whole-cell width and the chosen one's dot. The module
# is loaded with a stand-in for gi (it is imported only to draw).
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
class UI:
    def __init__(self): self.calls, self.t, self.pending, self.drawn, self.at, self.cid = [], 100.0, [], [], None, None; self.pushed = []; self.timers = []
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
    def answer(self, out="", rc=0):            # the oldest run comes back
        self.pending.pop(0)(rc, out)
STATE = ("theme\tdark\nbrightness\t70%\nnight\ton\nvrr\tfull screen\nwallpaper\tmishima-mist\nsound\t62%\n"
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
def mid(key):                                  # the middle of an item's place
    it = p.item(key); return it.x + it.w // 2, it.y + it.h // 2
def seg(key, j):                               # a point on a meter's segment j (0: the first): the level there is 5 * (j + 1)
    it = p.item(key); return p.slider_x(it) + j * kp.CELL + kp.SEG_W // 2, it.y + it.h // 2
def air(key):                                  # a point in the air under an item: between two groups, or in the pad
    it = p.item(key); return it.x + it.w // 2, it.y + it.h + 1
exec(sys.argv[3])
EOF
}

# ── the layout ─────────────────────────────────────────────────────────────────────────
case_ "the items, in order: the two meters (brightness, sound), then the rows in three groups — in place (theme, night light, do not disturb, screensaver, freesync), connections (network, bluetooth and devices with an adapter, drives, backup), the screen (wallpaper, screenshot, record, read text, screen off, power)"
eq "$(py 'fresh(); print(" ".join(i.key for i in p.items))')" \
  "brightness sound theme night dnd saver vrr network bluetooth devices drives backup wallpaper screenshot record ocr screenoff power"
eq "$(py 'fresh(STATE.replace("bluetooth\ton\n","").replace("devices\tnone\n","")); print(" ".join(i.key for i in p.items))')" \
  "brightness sound theme night dnd saver vrr network drives backup wallpaper screenshot record ocr screenoff power" \
  "no adapter: neither bluetooth nor devices"
eq "$(py 'fresh(STATE.replace("bluetooth\ton\n","")); print(" ".join(i.key for i in p.items))')" \
  "brightness sound theme night dnd saver vrr network drives backup wallpaper screenshot record ocr screenoff power" \
  "no adapter, a stray devices line: it draws nothing"
eq "$(py 'fresh(STATE.replace("bluetooth\ton","bluetooth\toff")); print(" ".join(i.key for i in p.items))')" \
  "brightness sound theme night dnd saver vrr network bluetooth drives backup wallpaper screenshot record ocr screenoff power" \
  "an adapter that is off: bluetooth to switch it on, devices only while it is on (the devices line is there, it draws nothing)"
eq "$(py 'fresh(); print("".join(i.kind[0] for i in p.items))')" "mmrrrrrrrrrrrrrrrr" "two meters, sixteen rows"
eq "$(py 'fresh(STATE.replace("bluetooth\ton\n","").replace("devices\tnone\n","")); print("".join(i.kind[0] for i in p.items))')" "mmrrrrrrrrrrrrrr" "two meters, fourteen rows"
eq "$(py 'fresh(); print([i.row for i in p.items] == list(range(len(p.items))))')" True "a row a thing: the arrows walk the numbers"
case_ "quick_rows: the rows after the meters in three groups, each row (key, icon, name, value, on) — in place five, connections five (three without an adapter, four with it off), the screen six"
eq "$(py 'out = []
for st in (STATE, STATE.replace("bluetooth\ton","bluetooth\toff"), STATE.replace("bluetooth\ton\n","").replace("devices\tnone\n","")):
    g = kp.quick_rows(kp.parse_state(st)); out.append(([len(x) for x in g], {len(r) for x in g for r in x}))
print(out)')" "[([5, 5, 6], {5}), ([5, 4, 6], {5}), ([5, 3, 6], {5})]"
eq "$(py 'g = kp.quick_rows(kp.parse_state(STATE)); print([[r[0] for r in x] for x in g])')" \
  "[['theme', 'night', 'dnd', 'saver', 'vrr'], ['network', 'bluetooth', 'devices', 'drives', 'backup'], ['wallpaper', 'screenshot', 'record', 'ocr', 'screenoff', 'power']]"
eq "$(py 'fresh(""); print(len(p.items), p.item("theme").value, p.item("network").value, p.item("backup").value, repr(p.item("brightness").value))')" "16 dark offline not set up ''" \
  "a state with nothing in it (kawa-quick failed at the first read): the rows as they would be, no adapter"
eq "$(py 'u = UI(); p = kp.Panel(u); print(len(p.items), p.size, p.item("night").value, [p.item(k).on for k in ("night", "network", "drives")])')" "16 (410, 412) off [False, False, False]" \
  "before any read: the same rows, nothing on, drawn at once; the read redraws them"
eq "$(py 'fresh(); p.request(); u.drawn.clear(); u.answer(STATE); print(u.drawn, p.item("night").on)')" "['all'] True"
case_ "parse_state and percent: KEY<TAB>VALUE a line, a line without a tab skipped, a value keeps its own tabs, the last of a key stands; 70% is 70, anything else (no DDC/CI, muted, no output) is no level"
eq "$(py 'print(kp.parse_state("theme\tdark\nnoise\nwallpaper\ta b\tc\nnight\toff\nnight\ton\n\n"))')" "{'theme': 'dark', 'wallpaper': 'a b\tc', 'night': 'on'}"
eq "$(py 'print([kp.percent(v) for v in ("70%", "100%", "0%", "no DDC/CI", "muted", "no output", "", "7x%", "%")])')" "[70, 100, 0, None, None, None, None, None, None]"
case_ "the captures: record (on while one runs: a click stops it) and read text, each closing the panel for its own picker"
eq "$(py 'fresh(); t = p.item("record"); print(t.icon, "|", t.value, "|", t.on, "|", p.item("ocr").icon, p.item("ocr").name)')" "tile_record |  | False | tile_read read text"
eq "$(py 'fresh(STATE + "record\ton\n"); t = p.item("record"); print(t.value, t.on)')" "recording True"
eq "$(py 'fresh(); p.request(); p.activate("record"); p.activate("ocr"); print([c for c in u.calls if c.startswith("launch")], p.visible)')" "['launch kawa-quick --do record', 'launch kawa-quick --do ocr'] False"
case_ "the grid (docs/design-system.md §3): a heading — its row and 8 px of air (HEAD_H 28) — then every meter and row 376 wide from x 17, one row (20 px) high, on a 20 px pitch: half a row (QUICK_GAP, 10 px) of air between the groups, none inside one"
eq "$(py 'fresh(); print(" ".join(f"{i.key}:{i.x},{i.y},{i.w},{i.h}" for i in p.items))')" \
  "brightness:17,45,376,20 sound:17,65,376,20 theme:17,95,376,20 night:17,115,376,20 dnd:17,135,376,20 saver:17,155,376,20 vrr:17,175,376,20 network:17,205,376,20 bluetooth:17,225,376,20 devices:17,245,376,20 drives:17,265,376,20 backup:17,285,376,20 wallpaper:17,315,376,20 screenshot:17,335,376,20 record:17,355,376,20 ocr:17,375,376,20 screenoff:17,395,376,20 power:17,415,376,20"
eq "$(py 'fresh(); print({(i.x, i.w, i.h) for i in p.items}, p.items[0].y - p.heads[0][3], kp.HEAD_H)')" "{(17, 376, 20)} 28 28" "all alike but their y; the first meter a heading's row and its air under the heading"
eq "$(py 'fresh(); ys = [i.y for i in p.items]; print([b - a for a, b in zip(ys, ys[1:])])')" "[20, 30, 20, 20, 20, 20, 30, 20, 20, 20, 20, 30, 20, 20, 20, 20, 20]" "the pitch 20; 30 where a group ends (the meters and the three groups) — a row and QUICK_GAP"
eq "$(py 'out = []
for st in (STATE, STATE.replace("bluetooth\ton\n","").replace("devices\tnone\n","")):
    fresh(st); ys = [(i.key, i.y - j.y) for j, i in zip(p.items, p.items[1:])]
    out.append([k for k, d in ys if d == kp.ROW + kp.QUICK_GAP])
print(out)')" "[['theme', 'network', 'wallpaper'], ['theme', 'network', 'wallpaper']]" "a group starts after its gap: in place, connections, the screen — with the adapter or without"
case_ "one pixel, one item: no two places overlap — a click means one thing — and each lies inside the frame's pad (17 px from the sides and the foot), with and without the adapter"
eq "$(py 'out = []
for st in (STATE, STATE.replace("bluetooth\ton","bluetooth\toff"), STATE.replace("bluetooth\ton\n","").replace("devices\tnone\n","")):
    fresh(st); its = sorted(p.items, key=lambda i: i.y); w, h = p.size
    out.append((all(a.y + a.h <= b.y for a, b in zip(its, its[1:])), min(i.x for i in p.items), w - max(i.x + i.w for i in p.items), min(i.y for i in p.items) - p.heads[0][3] - kp.HEAD_H, h - max(i.y + i.h for i in p.items)))
print(out)')" "[(True, 17, 17, 0, 17), (True, 17, 17, 0, 17), (True, 17, 17, 0, 17)]"
case_ "the size: the sound panel's width — 376 of content (47 cells) in 16 px of pad and the 1 px hairline, 410 across — and as tall as its parts: the heading, two meters, the rows, three half rows of air between the groups — 452 with the bluetooth rows, 432 with the adapter off, 412 with none"
eq "$(py 'fresh(); print(*p.size)')" "410 452"
eq "$(py 'fresh(STATE.replace("bluetooth\ton","bluetooth\toff")); print(*p.size)')" "410 432"
eq "$(py 'fresh(STATE.replace("bluetooth\ton\n","").replace("devices\tnone\n","")); print(*p.size)')" "410 412"
eq "$(py 'print(kp.INNER, kp.INNER // kp.CELL, kp.INNER % kp.CELL, kp.INNER + 2 * (kp.PAD + kp.BORDER), kp.BORDER, kp.HAIR, kp.PAD)')" "376 47 0 410 1 1 16" "47 whole cells of content, 2 × 16 of pad, 2 × 1 of hairline"
eq "$(py 'out = []
for st in (STATE, STATE.replace("bluetooth\ton","bluetooth\toff"), STATE.replace("bluetooth\ton\n","").replace("devices\tnone\n","")):
    fresh(st); n = sum(i.kind == "row" for i in p.items)
    out.append(p.size == (kp.INNER + 2 * (kp.PAD + kp.BORDER), kp.BORDER + kp.PAD + kp.HEAD_H + 2 * kp.ROW + 3 * kp.QUICK_GAP + n * kp.ROW + kp.PAD + kp.BORDER))
print(out)')" "[True, True, True]" "the height is the sum of its parts and nothing else: the pad, the heading, two meters, three half rows of air, a row each, the pad"
eq "$(py 'fresh(); print(p.head, p.heads, p.rules, p.nones, p.marks, p.view)')" "(17, 17) [('sliders', 'quick settings', 17, 17)] [] [] [] None" "one heading at the content's corner, 17 px from every edge; nothing is drawn but it and the items"
eq "$(py 'out = []
fresh(); out.append(p.size[0])
opened("sound", SOUND); out.append(p.size[0])
fresh(); p.request("launcher", kp.Launcher([], {}), None); out.append(p.size[0])
print(out)')" "[410, 410, 410]" "quick settings, the sound panel and the launcher: one width"
case_ "the window is the frame's box and its shadow — a column at its right, two rows under it (411 × 454) — and never trimmed to its ink"
eq "$(py 'fresh(); print(*p.win, p.ox, p.dy, kp.SHADOW_R, kp.SHADOW_B)')" "411 454 0 0 1 2"
eq "$(py 'fresh(); print(p.win == (p.size[0] + kp.SHADOW_R, p.size[1] + kp.SHADOW_B), p.rules); opened("sound", SOUND); print(p.win == (p.size[0] + 1, p.size[1] + 2), p.rules); opened("brightness", "brightness\t70%\n"); print(p.win == (p.size[0] + 1, p.size[1] + 2), p.rules, p.dy)')" "$(printf '%s\n' "True []" "True []" "True [] 0")" "every panel the same: the box + 1 column, + 2 rows — no trimming (dy 0), nothing drawn between the groups"
case_ "an open panel follows its rows: a state read that takes the devices row away (bluetooth off) gives it the smaller box and window — the drawing resizes its window to match"
eq "$(py 'fresh(); p.request(); print(p.size, p.win); u.answer(STATE.replace("bluetooth\ton","bluetooth\toff")); print(p.size, p.win)')" \
  "$(printf '%s\n' "(410, 452) (411, 454)" "(410, 432) (411, 434)")"
case_ "notices are as wide as the panels: one column under the bar's right end (mako's 410, quick settings' and the sound panel's width)"
has "$(cat "$REPO/configs/home/.config/mako/config")" "width=$(py 'opened("sound", SOUND); print(p.size[0])')"
has "$(cat "$REPO/configs/home/.config/mako/config")" "width=$(py 'fresh(); print(p.size[0])')"
case_ "the meters (brightness, sound): a row's icon and name — the bar's icon for the level, the sound's crossed out while muted — and the segments of §4 at the content's right, their last on its edge; words alone when there is no level"
eq "$(py 'fresh(); print(" ".join(f"{i.key}:{i.icon}:{i.name}:{i.value}:{i.muted}:{p.slider_x(i)}" for i in p.items if i.kind == "meter"))')" \
  "brightness:bri_3:brightness:70%:False:235 sound:vol_3:sound:62%:False:235"
eq "$(py 'fresh(STATE + "muted\ton\n"); print(p.item("sound").icon, p.item("sound").muted, p.item("brightness").muted)')" "vol_mute True False" "muted: the speaker crossed out, its segments hollow; the brightness does not follow"
eq "$(py 'fresh(STATE.replace("70%", "no DDC/CI").replace("62%", "no output")); print(p.item("brightness").icon, p.item("brightness").value, "|", p.item("sound").icon, p.item("sound").value)')" "bri_0 no DDC/CI | vol_0 no output" "no level: the words, the icon at its lowest"
eq "$(py 'fresh(); print([p.slider_x(i) + (kp.SEGS - 1) * kp.CELL + kp.SEG_W == i.x + i.w for i in p.items if i.kind == "meter"])')" "[True, True]" "the last segment's ink on the content's edge"
case_ "the grid's own constants (quick settings', the sound panel's, the slider's and the menus')"
eq "$(py 'print(kp.HEAD_H, kp.SECTION, kp.KEY_H, kp.METER_GAP, kp.GAP, kp.QUICK_GAP, kp.QUICK_VALUE, hasattr(kp, "GROUP"))')" "28 20 20 0 8 10 192 False" "a heading 28, 20 of air above one that is not first, keys 20, rows touching, half a row (10) between quick settings' groups, a state's words at most 192 (24 cells)"

# ── the rows' pictures and words ────────────────────────────────────────────────────────
t() { py "fresh($1); i = p.item('$2'); print(i.icon, '|', i.name, '|', i.value, '|', 'lit' if i.on else 'quiet')"; }
case_ "each row: its own picture (a tile_ name, or a plain icon), its name, how it stands; lit — the picture vermilion, the state strong — while it is on; the theme is a mood, never on"
eq "$(t '' theme)" "tile_moon | theme | dark | quiet"
eq "$(t 'STATE.replace("theme\tdark","theme\tlight")' theme)" "tile_sun | theme | light | quiet" "light: the rising sun"
eq "$(t '' night)" "tile_lantern | night light | on | lit"
eq "$(t 'STATE.replace("night\ton","night\toff")' night)" "tile_lantern | night light | off | quiet"
eq "$(t 'STATE.replace("night\ton","night\t3500K")' night)" "tile_lantern | night light | 3500K | lit" "on: its warmth"
eq "$(t '' saver)" "tile_saver | screensaver | off | quiet" "(no saver line: off)"
eq "$(t 'STATE + "saver\t15 min\n"' saver)" "tile_saver | screensaver | 15 min | lit"
eq "$(t 'STATE + "saver\toff\n"' saver)" "tile_saver | screensaver | off | quiet"
eq "$(t '' vrr)" "tile_wave | freesync | full screen | lit"
eq "$(t 'STATE.replace("vrr\tfull screen","vrr\toff")' vrr)" "tile_wave | freesync | off | quiet"
case_ "FreeSync's row: the setting and the card's own state this moment (vrrnow), lit only while on"
eq "$(t 'STATE + "vrrnow\toff\n"' vrr)" "tile_wave | freesync | full screen · off | quiet"
eq "$(t 'STATE + "vrrnow\ton\n"' vrr)" "tile_wave | freesync | full screen · on | lit"
eq "$(t 'STATE.replace("vrr\tfull screen","vrr\talways") + "vrrnow\ton\n"' vrr)" "tile_wave | freesync | always · on | lit"
eq "$(t 'STATE + "vrrnow\tnone\n"' vrr)" "tile_wave | freesync | not offered | quiet"
eq "$(t 'STATE.replace("vrr\tfull screen","vrr\toff") + "vrrnow\toff\n"' vrr)" "tile_wave | freesync | off | quiet"
case_ "the network row's picture follows the kind of link: wired, Wi-Fi, none"
eq "$(t '' network)" "tile_wifi | network | Home Net 5G | lit"
eq "$(t 'STATE.replace("nettype\twifi","nettype\tethernet").replace("Home Net 5G","wired")' network)" "tile_ethernet | network | wired | lit"
eq "$(t 'STATE.replace("nettype\twifi","nettype\toffline").replace("Home Net 5G","offline")' network)" "tile_offline | network | offline | quiet"
case_ "bluetooth, devices, drives, backup, do not disturb: each its own picture; the quiet bell once do not disturb is on"
eq "$(t '' bluetooth)" "tile_bluetooth | bluetooth | on | lit"
eq "$(t 'STATE.replace("bluetooth\ton","bluetooth\toff")' bluetooth)" "tile_bluetooth | bluetooth | off | quiet"
eq "$(t '' devices)" "tile_devices | devices | none | quiet"
eq "$(t 'STATE.replace("devices\tnone","devices\tWH-1000XM5")' devices)" "tile_devices | devices | WH-1000XM5 | lit"
eq "$(t '' drives)" "tile_drive | drives | KINGSTON 58G | lit"
eq "$(t 'STATE.replace("KINGSTON 58G","none")' drives)" "tile_drive | drives | none | quiet"
eq "$(t '' backup)" "tile_backup | backup | 3 days ago | lit"
eq "$(t 'STATE.replace("3 days ago","never")' backup)" "tile_backup | backup | never | quiet"
eq "$(t 'STATE.replace("backup\t3 days ago\n","")' backup)" "tile_backup | backup | not set up | quiet" "(no backup line: not set up)"
eq "$(t '' dnd)" "tile_bell | do not disturb | off | quiet"
eq "$(t 'STATE.replace("dnd\toff","dnd\ton")' dnd)" "tile_bell_off | do not disturb | on | lit"
case_ "the screen's rows: wallpaper (its name), screenshot, record (recording, lit, while one runs), read text, screen off, power — none on but the recording"
eq "$(t '' wallpaper)" "picture | wallpaper | mishima-mist | quiet"
eq "$(t '' screenshot)" "camera | screenshot |  | quiet"
eq "$(t '' record)" "tile_record | record |  | quiet"
eq "$(t 'STATE + "record\ton\n"' record)" "tile_record | record | recording | lit"
eq "$(t '' ocr)" "tile_read | read text |  | quiet"
eq "$(t '' screenoff)" "screen_off | screen off |  | quiet"
eq "$(t '' power)" "power | power |  | quiet"
case_ "no day or weather line: the bar's own, right above the panel"
eq "$(py 'fresh(); print(hasattr(kp, "date_line"), [i.key for i in p.items if i.key in ("date", "day", "weather")])')" "False []" "no day or weather line: the bar shows them, right above"
case_ "every picture a row (or a meter) can wear is one of icons.sh's, and no two rows of one state wear the same — each its own picture"
eq "$(py 'S = [STATE.replace("theme\tdark", "theme\tlight"), STATE, STATE.replace("nettype\twifi", "nettype\tethernet"), STATE.replace("nettype\twifi", "nettype\toffline"),
     STATE.replace("dnd\toff", "dnd\ton") + "muted\ton\n", STATE.replace("70%", "no DDC/CI").replace("62%", "no output"), STATE.replace("bluetooth\ton\n", "")]
ic = kp.icons(); names = {i.icon for st in S for i in kp.layout_quick(kp.parse_state(st)).items}
print(len(names), sorted(n for n in names if n not in ic))')" "25 []" "(twenty rows' pictures and five meters': art/icons.txt → tools/build-icons.py)"
eq "$(py 'out = []
for st in (STATE, STATE.replace("bluetooth\ton\n", "")):
    fresh(st); icons = [i.icon for i in p.items]; out.append((len(icons), len(set(icons))))
print(out)')" "[(18, 18), (16, 16)]"
case_ "a state's words fit its row: at most QUICK_VALUE px (24 cells), cut at a word, never with an ellipsis; the longest name and the widest state side by side in the row's 376 px"
eq "$(py 'long = "a drive with a name much too long to sit beside its own row name"
fresh(STATE.replace("KINGSTON 58G", long)); v = p.item("drives").value
print(repr(v), kp.px_of(v) <= kp.QUICK_VALUE, "…" in v)')" "'a drive with a name much' True False" "a name too long: what fits of it, at a word"
eq "$(py 'long = "x" * 20 + " " + "y" * 20 + " " + "z" * 20; out = []
for key, line in (("network", "network\t"), ("devices", "devices\t"), ("drives", "drives\t"), ("wallpaper", "wallpaper\t"), ("backup", "backup\t")):
    fresh("".join(l + "\n" for l in STATE.splitlines() if not l.startswith(line)) + line + long + "\n"); v = p.item(key).value
    out.append((key, kp.px_of(v) <= kp.QUICK_VALUE, "…" in v, v == "x" * 20))
print(out)')" "[('network', True, False, True), ('devices', True, False, True), ('drives', True, False, True), ('wallpaper', True, False, True), ('backup', True, False, True)]" \
  "every state with a name in it, cut at the word before the one that does not fit"
eq "$(py 'fresh(STATE.replace("KINGSTON 58G", "w" * 40)); v = p.item("drives").value; print(len(v), kp.px_of(v) <= kp.QUICK_VALUE, "…" in v)')" "27 True False" "one word too long: it loses its last letters"
eq "$(py 'fresh(STATE.replace("KINGSTON 58G", "写真" * 10)); v = p.item("drives").value; print(kp.px_of(v) <= kp.QUICK_VALUE, kp.px_of(v), "…" in v)')" "True 182 False" "wide letters count two columns"
eq "$(py 'fresh(); names = [i.name for i in p.items if i.kind == "row"]; print(max(names, key=kp.px_of), kp.NAME_X + max(kp.px_of(n) for n in names) + 2 * kp.CELL + kp.QUICK_VALUE <= kp.INNER)')" "do not disturb True" "the name from cell 4, two cells of air, the widest state: inside the row, nothing overlaps"
eq "$(py 'fresh(); raw = {r[0]: r[3] for g in kp.quick_rows(kp.parse_state(STATE)) for r in g}; print(all(p.item(k).value == v for k, v in raw.items()))')" True "the usual states are shown whole, as the machine says them"
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
has "$(python3 -I "$REPO/bin/kawa-panel" --help)" "Quick settings is a plain menu" "its help says what it is"
has "$(python3 -I "$REPO/bin/kawa-panel" --help)" "brightness and sound" "…and names its meters"
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
case_ "Enter on a switch does the same, the cursor staying on its row; the row then shows what the machine says (do not disturb: on, its bell crossed)"
for k in theme night vrr bluetooth dnd saver; do
  eq "$(py "fresh(); p.request(); u.answer(STATE); u.calls.clear(); p.focus = '$k'; p.key('Return'); u.answer(); print(', '.join(u.calls), p.visible, p.focus)")" \
    "run kawa-quick --do $k, run kawa-quick --state True $k" "$k"
done
eq "$(py 'fresh(); p.request(); u.answer(STATE); p.focus = "dnd"; p.key("Return"); u.answer(); u.answer(STATE.replace("dnd\toff", "dnd\ton")); i = p.item("dnd"); print(i.icon, i.value, i.on, p.focus, p.visible)')" "tile_bell_off on True dnd True"
case_ "the others: the panel closes, then their own menu or window"
for k in network devices drives backup record ocr wallpaper screenshot screenoff power; do
  eq "$(py "fresh(); p.request(); u.calls.clear(); p.activate('$k'); print(', '.join(u.calls))")" \
    "hide, light quick off, launch kawa-quick --do $k" "$k"
done
case_ "Enter on one of them: the same — the panel closed, the cursor gone with it"
for k in network devices drives backup record ocr wallpaper screenshot screenoff power; do
  eq "$(py "fresh(); p.request(); u.calls.clear(); p.focus = '$k'; p.key('Return'); print(', '.join(u.calls), p.visible, p.focus)")" \
    "hide, light quick off, launch kawa-quick --do $k False None" "$k"
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
case_ "no row is dead and none does both: the switches and the openers divide the rows between them, whatever the state, and the meters are the two METERS"
eq "$(py 'dead = []
for st in (STATE, STATE.replace("bluetooth\ton","bluetooth\toff"), STATE.replace("bluetooth\ton\n","").replace("devices\tnone\n","")):
    fresh(st); dead += [i.key for i in p.items if i.kind == "row" and i.key not in kp.SWITCHES + kp.OPENERS]
fresh(); keys = [i.key for i in p.items if i.kind == "row"]
print(dead, sorted(set(kp.SWITCHES) & set(kp.OPENERS)), sorted(set(kp.SWITCHES + kp.OPENERS) - set(keys)), [i.key for i in p.items if i.kind == "meter"] == list(kp.METERS))')" \
  "[] [] [] True" "no row without something to do, none in both lists, nothing listed that no row has; the meters are METERS, in order"
case_ "what a row runs is something kawa-quick --do knows: a branch in its act() for each key the panel sends (the wheel's warmer and cooler, the meters' volume and brightness too)"
for k in $(py 'print(*kp.SWITCHES, *kp.OPENERS, *[k for pair in kp.WHEELED.values() for k in pair], "volume", "brightness")'); do
  grep -qE "^[[:space:]]+([a-z|]+\|)?$k(\|[a-z|]+)?\)" "$REPO/bin/kawa-quick" && _ok || _no "kawa-quick has no branch for --do $k"
done

# ── the keys ──────────────────────────────────────────────────────────────────────────
nav() { py "fresh(); p.focus = '$1'; [p.key(k) for k in '$2'.split()]; print(p.focus)"; }
case_ "arrows (and h j k l) walk the rows in their order: Down (j) to the next, Up (k) to the one before — the meters first, over the air between the groups — and the ends stay: nothing above the first, nothing under the last"
eq "$(nav brightness 'Down')" sound; eq "$(nav brightness 'j')" sound "(j is Down)"; eq "$(nav sound 'Up')" brightness; eq "$(nav sound 'k')" brightness "(k is Up)"
eq "$(nav sound 'Down')" theme "from the meters into the first group"; eq "$(nav theme 'Up')" sound "…and back"
eq "$(nav vrr 'Down')" network "over the air between the groups"; eq "$(nav network 'Up')" vrr; eq "$(nav backup 'Down')" wallpaper; eq "$(nav wallpaper 'Up')" backup
eq "$(nav bluetooth 'Down')" devices "devices is walked while bluetooth is on"; eq "$(nav devices 'Down')" drives
eq "$(nav brightness 'Up')" brightness "nothing above the first"; eq "$(nav power 'Down')" power "nothing under the last"
eq "$(py 'fresh(STATE.replace("bluetooth\ton\n","").replace("devices\tnone\n","")); p.focus = "network"; p.key("Down"); a = p.focus; p.key("Up"); print(a, p.focus)')" "drives network" "no adapter: drives follows the network"
eq "$(py 'fresh(); p.focus = "brightness"; seen = [p.focus]
for _ in range(len(p.items) - 1): p.key("Down"); seen.append(p.focus)
for _ in range(len(p.items) - 1): p.key("Up"); seen.append(p.focus)
keys = [i.key for i in p.items]; n = len(keys)
print(seen[:n] == keys, seen[n:] == keys[-2::-1], len(set(seen)))')" "True True 18" "every row reached by the arrows alone: down the whole list in order, and back up"
case_ "← → (h l) on a row: nothing — the cursor stays, nothing is done or sent, the panel stays open (a row has no other side)"
for k in night power wallpaper bluetooth; do
  eq "$(py "fresh(); p.request(); u.calls.clear(); p.focus = '$k'; [p.key(n) for n in ('Left', 'Right', 'h', 'l')]; print(p.focus, u.calls, p.visible)")" "$k [] True" "$k"
done
case_ "← → (h l) on a meter: its level by 5 to the next multiple of 5, at once and then set (kawa-quick --do volume / brightness N) — the cursor stays on it; ↑ ↓ leave it for the next row"
eq "$(py 'fresh(); p.focus = "sound"; p.key("Right"); print(p.focus, p.state["sound"], u.calls[-1])')" "sound 65% run kawa-quick --do volume 65"
eq "$(py 'fresh(); p.focus = "sound"; p.key("l"); print(p.state["sound"], u.calls[-1])')" "65% run kawa-quick --do volume 65" "(l is Right)"
eq "$(py 'fresh(); p.focus = "brightness"; p.key("h"); print(p.focus, p.state["brightness"], u.calls[-1])')" "brightness 65% run kawa-quick --do brightness 65" "(h is Left)"
eq "$(py 'fresh(); p.focus = "sound"; p.key("Left"); print(p.state["sound"], u.calls[-1])')" "60% run kawa-quick --do volume 60" "62 left: 60, the next multiple of 5"
eq "$(py 'fresh(); p.focus = "brightness"; [p.key("Right") for _ in range(9)]; print(p.state["brightness"])')" 100% "no more than 100"
eq "$(py 'fresh(); p.focus = "sound"; [p.key("Left") for _ in range(20)]; print(p.state["sound"])')" 0% "no less than 0"
eq "$(py 'fresh(); p.focus = "sound"; p.key("Down"); print(p.focus, p.state["sound"], [c for c in u.calls if c.startswith("run")])')" "theme 62% []" "↓ leaves it: the level is not touched"
eq "$(py 'fresh(); p.focus = "sound"; p.key("Up"); print(p.focus, p.state["sound"], [c for c in u.calls if c.startswith("run")])')" "brightness 62% []" "↑ too"
eq "$(py 'fresh(); p.focus = "sound"; p.step("sound", 5); p.key("Right"); print(p.state["sound"], sum(c.startswith("run kawa-quick --do volume") for c in u.calls)); u.answer(); print(u.calls[-1])')" \
  "$(printf '%s\n' '70% 1' 'run kawa-quick --do volume 70')" "keys pressed fast: one wpctl at a time, the last level asked the one that stays"
case_ "a meter without a level (no DDC/CI, no output): ← → have nothing to set — nothing is sent, the cursor stays; ↑ ↓ walk on as from any row"
eq "$(py 'fresh(STATE.replace("70%","no DDC/CI")); p.focus = "brightness"; p.key("Right"); p.key("Left"); print(p.state["brightness"], p.focus, [c for c in u.calls if c.startswith("run")])')" "no DDC/CI brightness []"
eq "$(py 'fresh(STATE.replace("70%","no DDC/CI")); p.focus = "brightness"; p.key("Down"); print(p.focus, [c for c in u.calls if c.startswith("run")])')" "sound []"
case_ "Tab and Shift+Tab: every item in turn, round — in the items' order: the meters, then the rows"
eq "$(nav power 'Tab')" brightness "round: the last to the first"; eq "$(nav brightness 'ISO_Left_Tab')" power "…and back"
eq "$(nav brightness 'Tab Tab Tab')" night "the meters, then the first group"; eq "$(nav sound 'Tab')" theme; eq "$(nav theme 'ISO_Left_Tab')" sound; eq "$(nav vrr 'Tab')" network "across the air between"
eq "$(py 'fresh(); p.focus = "brightness"; seen = [p.focus]
for _ in range(len(p.items)): p.key("Tab"); seen.append(p.focus)
print(seen == [i.key for i in p.items] + ["brightness"], len(set(seen)))')" "True 18" "all eighteen once, in the items' order, then round to the first"
eq "$(py 'fresh(); p.focus = "brightness"; seen = [p.focus]
for _ in range(len(p.items)): p.key("ISO_Left_Tab"); seen.append(p.focus)
print(seen == [i.key for i in p.items][:1] + [i.key for i in p.items][::-1], len(set(seen)))')" "True 18" "…and Shift+Tab the whole way back"
case_ "a state read that takes the focused row away (bluetooth turned off: no devices row): the cursor goes with it; one that leaves it there keeps it"
eq "$(py 'fresh(); p.request(); p.focus = "devices"; u.answer(STATE.replace("bluetooth\ton","bluetooth\toff")); print(p.focus, p.item("devices"))')" "None None"
eq "$(py 'fresh(); p.request(); p.focus = "drives"; u.answer(STATE.replace("bluetooth\ton","bluetooth\toff")); print(p.focus, p.item("drives").y)')" "drives 245" "(the rows below it move up: the cursor follows its row)"

# ── the mouse ─────────────────────────────────────────────────────────────────────────
# (quick settings, the default state: every row x 17–392, 20 px high — night's y 115–134, its middle
# (205, 125); the theme's middle (205, 105), vrr's (205, 185), bluetooth's (205, 235), wallpaper's
# (205, 325); brightness's segments from x 235 along y 45–64 — segment 9 at x 307–312 —, sound's
# along y 65–84; the air between the groups (y 85–94 under the meters), the heading (y 17–44)
# and the frame at (5, 5) hold nothing)
case_ "one light: the pointer over an item moves the cursor there (it is hot and the cursor at once), and the cursor stays where the pointer left it"
eq "$(py 'opened("quick", STATE); p.hover(*mid("night")); print(p.hot, p.focus)')" "night night"
eq "$(py 'opened("quick", STATE); p.hover(*mid("night")); p.hover(*air("sound")); print(p.hot, p.focus)')" "None night" "over the air between two groups: nothing hot, the cursor where the pointer left it"
eq "$(py 'opened("quick", STATE); p.hover(*mid("night")); p.hover(100, 25); print(p.hot, p.focus)')" "None night" "over the heading (it is no item): the same"
eq "$(py 'opened("quick", STATE); p.hover(*mid("night")); p.hover(5, 5); print(p.hot, p.focus)')" "None night" "over the frame: the same"
eq "$(py 'opened("quick", STATE); p.hover(*mid("night")); p.leave(); print(p.hot, p.focus)')" "None night" "the pointer gone: the cursor stays"
eq "$(py 'opened("quick", STATE); p.focus = "theme"; p.hover(*mid("night")); print(p.hot, p.focus)')" "night night" "a cursor the keys showed: the pointer takes it"
eq "$(py 'fresh(); p.hover(*mid("night")); print(p.hot, p.focus)')" "night None" "a panel not open shows no cursor"
case_ "a click does what is under the pointer, there and then"
eq "$(py 'opened("quick", STATE); p.hover(*mid("night")); p.press(*mid("night")); print(p.hot, p.focus)')" "night night"
eq "$(py 'fresh(); p.press(*seg("sound", 9)); print(p.focus)')" None "a click on a meter, with no cursor shown: none is shown for it"
eq "$(py 'fresh(); p.focus = "theme"; p.press(*seg("sound", 9)); print(p.focus)')" sound "… but a cursor the keys showed follows the click"
eq "$(py 'fresh(); p.request(); u.calls.clear(); p.press(*mid("wallpaper")); print(", ".join(u.calls))')" "redraw, hide, light quick off, launch kawa-quick --do wallpaper"
case_ "a click anywhere on a row's place — its icon, its name, its state, its first and last pixel — does what the row does; on the pad round the rows, the heading or the air between the groups: nothing"
eq "$(py 'fresh(); p.request(); u.calls.clear(); it = p.item("night"); [p.press(x, y) for x, y in ((it.x, it.y), (it.x + 10, it.y + 5), (it.x + 100, it.y + 9), (it.x + it.w - 1, it.y + it.h - 1))]; print(sum(c == "run kawa-quick --do night" for c in u.calls))')" 4
eq "$(py 'fresh(); p.request(); u.calls.clear(); [p.press(x, y) for x, y in ((5, 120), (400, 120), (100, 25), air("sound"), air("vrr"), air("power"))]; print([c for c in u.calls if c.startswith("run") or c.startswith("launch")], p.visible)')" "[] True"
case_ "a click on a row does what Enter does: a switch in place, an opener closes the panel and goes; on the sound meter's icon or name the sound panel, on the brightness one nothing"
eq "$(py 'fresh(); p.request(); u.answer(STATE); u.calls.clear(); p.press(*mid("dnd")); print(", ".join(u.calls), p.visible)')" "redraw, run kawa-quick --do dnd True"
eq "$(py 'fresh(); p.request(); u.calls.clear(); p.press(*mid("power")); print(", ".join(u.calls), p.visible)')" "redraw, hide, light quick off, launch kawa-quick --do power False"
eq "$(py 'fresh(); p.request(); u.calls.clear(); it = p.item("sound"); p.press(it.x + 40, it.y + 5); print(", ".join(u.calls)); print(p.mode, p.visible)')" \
  "$(printf '%s\n' "redraw, hide, light quick off, show, light sound on, run kawa-quick --state sound" "sound True")" "(as Enter on it)"
eq "$(py 'fresh(); p.request(); u.calls.clear(); it = p.item("brightness"); p.press(it.x + 40, it.y + 5); print([c for c in u.calls if c.startswith("run") or c.startswith("launch")], p.state["brightness"], p.visible)')" "[] 70% True" "(as Enter on it: nothing)"
case_ "the keys move the cursor from where the pointer left it"
eq "$(py 'opened("quick", STATE); p.hover(*mid("vrr")); p.key("Up"); print(p.hot, p.focus)')" "vrr saver"
eq "$(py 'opened("quick", STATE); p.hover(*mid("vrr")); p.key("Down"); print(p.hot, p.focus)')" "vrr network"
case_ "the pointer leaving the panel: nothing hot, only that item redrawn; the cursor stays"
eq "$(py 'opened("quick", STATE); p.hover(*mid("night")); u.drawn.clear(); p.leave(); print(p.hot, p.focus, u.drawn)')" "None night [['night']]"
eq "$(py 'fresh(); u.drawn.clear(); p.leave(); print(u.drawn)')" "[]" "nothing was hot: nothing redrawn"
has "$(cat "$REPO/bin/kawa-panel")" 'win.connect("leave-notify-event", on_leave)'
has "$(cat "$REPO/bin/kawa-panel")" 'Gdk.EventMask.LEAVE_NOTIFY_MASK'
case_ "opened again: nothing hot until the pointer says where it is (a new window); a state read keeps it while it is there"
eq "$(py 'fresh(); p.request(); p.hover(*mid("night")); p.close("chosen"); p.request(); print(p.hot)')" None
eq "$(py 'fresh(); p.hover(*mid("night")); p.refresh(); u.answer(STATE); print(p.hot)')" night
eq "$(py 'fresh(); p.hover(*mid("backup")); a = p.hot; p.refresh(); u.answer(STATE.replace("bluetooth\ton\n","").replace("devices\tnone\n","")); print(a, p.hot)')" "backup screenshot" "the rows reflowed (no adapter: two fewer): where backup was is now the screen's second row"
case_ "a drag: the meter follows, the hot one does not move off it (nor the cursor)"
eq "$(py 'opened("quick", STATE); b = seg("brightness", 9); p.hover(*b); p.press(*b); p.hover(*mid("night"), dragging=True); print(p.hot, p.focus)')" "brightness brightness"
eq "$(py 'fresh(); p.press(5, 5); print(u.calls)')" "[]" "on the frame: nothing"
case_ "a click on a meter's segments: the level through the segment under it (lit to its top: 5 % each, the first 5); a cell of air before the first: 0; off the segments (its icon, its name): not a level; a drag follows"
eq "$(py 'fresh(); print([ (p.press(*seg("brightness", j)), p.state["brightness"])[1] for j in (0, 1, 9, 10, 19) ])')" "['5%', '10%', '50%', '55%', '100%']" "segment j is 5 · (j + 1) %: the first 5, the tenth 50, the eleventh 55, the twentieth 100"
eq "$(py 'fresh(); x, y = seg("brightness", 0); p.press(x - 6, y); print(p.state["brightness"])')" 0% "a cell of air before the first segment: 0"
eq "$(py 'fresh(); it = p.item("brightness"); p.press(it.x + 40, it.y + 5); p.press(it.x + 100, it.y + 5); print(p.state["brightness"], [c for c in u.calls if c.startswith("run")])')" "70% []" "off the segments (its icon, its name): nothing set"
eq "$(py 'fresh(); p.press(*seg("sound", 0)); x, y = seg("sound", 9); p.hover(x, y, dragging=True); a = p.state["sound"]; p.hover(5, y + 200, dragging=True); b = p.state["sound"]; p.hover(900, y - 100, dragging=True); print(a, b, p.state["sound"])')" "50% 0% 100%" "a drag follows the pointer along the segments at any height; past either end: that end"
eq "$(py 'fresh(); p.press(*seg("sound", 0)); p.release(); p.hover(*seg("sound", 19), dragging=True); print(p.state["sound"])')" 5% "let go: no more"

case_ "the segments and the level, one rule both ways (quick settings', the sound panel's and the brightness slider's): a click lights through the segment under the pointer (to its top), the air before the first is 0"
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
eq "$(py 'fresh(); out = []
for k in ("brightness", "sound"):
    m = p.item(k); x0 = p.slider_x(m); out.append((x0, [p.meter_at(m, x0 + o) for o in (-9, -8, -1, 0, 7, 8, 159, 167, 168)], p.meter_at(m, x0 - 300, held=True), p.meter_at(m, x0 + 900, held=True)))
print(out[0] == out[1], *out[0])')" "True 235 [None, 0, 0, 5, 5, 10, 100, 100, None] 0 100" "quick settings' meters: the pointer counts from a cell before the run to a cell after it; dragged, anywhere (an end held)"
eq "$(py 'fresh(); print([[p.meter_at(p.item(k), seg(k, j)[0]) for j in range(20)] == [5 * (j + 1) for j in range(20)] for k in ("brightness", "sound")])')" "[True, True]" "a point on segment j is 5 · (j + 1) %, on both"
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
fresh(); p.press(*seg("brightness", 5)); u.drawn.clear()
shown = []
for j in range(6, 20):
    p.hover(*seg("brightness", j), dragging=True); shown.append(p.state["brightness"] == f"{5 * (j + 1)}%")
print(all(shown), all(d == ["brightness"] for d in u.drawn), sum(c.startswith("run kawa-quick --do brightness") for c in u.calls))
u.answer(); print(u.calls[-1]); p.release(); u.answer(); print(u.calls[-1])')" \
  "$(printf '%s\n' 'True True 1' 'run kawa-quick --do brightness 100' 'run kawa-quick --state')"
eq "$(py 'fresh(); x, y = seg("brightness", 5); p.press(x, y); n = len(u.calls); p.hover(x + 1, y + 1, dragging=True); p.hover(x - 1, y, dragging=True); print(len(u.calls) - n)')" 0 "the same level again (the same segment): nothing redrawn, nothing sent"
eq "$(py 'fresh(); p.press(*seg("brightness", 9)); p.hover(0, 55, dragging=True); a = p.state["brightness"]; p.hover(600, 55, dragging=True); print(a, p.state["brightness"])')" "0% 100%" "dragged past either end: that end"

case_ "no snapping back: a state read that comes back mid-drag, or was started before the last change, leaves the meter as set"
eq "$(py '
fresh(); p.refresh()                                  # (a read already under way: the open)
p.press(*seg("brightness", 12)); v = p.state["brightness"]
u.pending.pop(0)(0, STATE)                            # (that read comes back with the old 70 %)
print(v, p.state["brightness"])')" "65% 65%"
eq "$(py '
fresh(); p.press(*seg("brightness", 12)); p.release(); p.refresh()
u.answer()                                            # (the level set: confirmed)
u.answer(STATE)                                       # (the read started before that: 70 %)
print(p.state["brightness"])')" 65% "a read started while it was being set: ignored"
eq "$(py '
fresh(); p.press(*seg("brightness", 12)); p.release(); u.answer()
u.answer(STATE.replace("70%", "65%").replace("night\ton", "night\toff"))
print(p.state["brightness"], p.state["night"], p.held("brightness"))')" "65% off False" "a read after it: taken, and the meter free again"
eq "$(py '
fresh(); p.refresh(); p.press(*seg("brightness", 12)); p.release(); p.refresh(); u.answer(STATE); u.answer(); u.answer(STATE); u.answer(STATE)
print(p.state["brightness"], p.held("brightness"))')" "70% False" "reads that started while it was set are ignored, but only those: the meter is not held for good"
eq "$(py '
fresh(); p.press(*seg("brightness", 12)); p.release(); u.answer(); u.answer(STATE)
print(p.state["brightness"])')" 70% "… so a level the machine did not take shows as it is"

case_ "the wheel and a touchpad: a step per notch; a touchpad's small scrolls summed, not a step each (on the night light's warmth)"
eq "$(py 'fresh(); W = lambda: sum(c == "run kawa-quick --do warmer" for c in u.calls); n = mid("night"); p.scroll_by(*n, -1.0); a = W(); [p.scroll_by(*n, -0.25) for _ in range(3)]; b = W(); p.scroll_by(*n, -0.25); print(a, b, W())')" "1 1 2"
eq "$(py 'fresh(); p.scroll_by(*mid("night"), 0.5); p.scroll_by(*mid("theme"), 0.5); p.scroll_by(*mid("night"), 0.5); print([c for c in u.calls if c.startswith("run")])')" "[]" "half a step on one item does not add to the other's"
eq "$(py 'fresh(); p.scroll_by(*mid("night"), -1.0); p.scroll_by(*mid("night"), 1.0); print([c for c in u.calls if c.startswith("run")])')" "['run kawa-quick --do warmer', 'run kawa-quick --do cooler']" "up warmer, down cooler"
case_ "...and on the meters: a smooth scroll (a touchpad, GTK's wheel on Wayland) anywhere on the row steps the level, the small parts summed"
eq "$(py 'fresh(); p.scroll_by(*seg("brightness", 9), -1.0); print(p.state["brightness"])')" "75%" "a whole notch up: 70 → 75"
eq "$(py 'fresh(); p.scroll_by(*mid("brightness"), -1.0); p.scroll_by(40, 75, 1.0); print(p.state["brightness"], p.state["sound"])')" "75% 60%" "…also over the icon and the name, not only the segments"
eq "$(py 'fresh(); [p.scroll_by(*seg("sound", 3), 0.25) for _ in range(3)]; a = p.state["sound"]; p.scroll_by(*seg("sound", 3), 0.25); print(a, p.state["sound"])')" "62% 60%" "three quarters: nothing yet; the fourth: a step down (to the next multiple of 5)"

case_ "moving between items redraws only those that changed: the one left and the one entered (the cursor and the hot one together)"
eq "$(py 'opened("quick", STATE); p.hover(*mid("night")); print(sorted({tuple(d) for d in u.drawn}))')" "[('night',)]" "the first: only it"
eq "$(py 'opened("quick", STATE); p.hover(*mid("night")); u.drawn.clear(); p.hover(*mid("vrr")); print(sorted({tuple(d) for d in u.drawn}))')" "[('night', 'vrr')]"
eq "$(py 'opened("quick", STATE); p.hover(*mid("night")); u.drawn.clear(); n = mid("night"); p.hover(n[0] + 1, n[1] + 1); p.hover(n[0] + 90, n[1] - 3); print(u.drawn)')" "[]" "within the same item: nothing"
eq "$(py 'opened("quick", STATE); p.hover(*mid("night")); u.drawn.clear(); p.hover(*mid("dnd")); print(sorted({tuple(d) for d in u.drawn}))')" "[('night', 'dnd')]" "onto the next row: both"
eq "$(py 'opened("quick", STATE); p.hover(*mid("night")); u.drawn.clear(); p.hover(*seg("sound", 9)); print(sorted({tuple(d) for d in u.drawn}))')" "[('night', 'sound')]" "onto a meter: both, never the whole panel"
eq "$(py 'opened("quick", STATE); p.hover(*seg("sound", 3)); u.drawn.clear(); p.hover(*seg("sound", 14)); print(u.drawn)')" "[]" "along the same meter: nothing (one item)"
eq "$(py 'opened("quick", STATE); p.hover(*mid("night")); u.drawn.clear(); p.hover(5, 5); print(u.drawn, p.focus)')" "[['night']] night" "onto the frame: the one left, the cursor stays"
eq "$(py 'fresh(); p.focus = "theme"; u.drawn.clear(); p.key("Down"); print(u.drawn)')" "[['theme', 'night']]" "the keys: the cursor's two"

case_ "how each item is drawn (look): the cursor fills the item's place with the lacquer (select), its inks text_on_select; at rest the place is bare — a row's icon accent and its state strong when it is on, both muted when off, its name text; a meter's icon and words muted. The pointer adds nothing of its own: it moves the cursor"
lk() { py "fresh(${4:-}); i = p.item('$1'); l = kp.look(i, $2, $3); print(l['fill'], l['frame'], l['glyph'], l['label'], l['value'], l['on_fill'])"; }
eq "$(lk night False False)" "None None accent text strong False" "a row that is on"
eq "$(lk devices False False)" "None None muted text muted False" "a row that is off"
eq "$(lk theme False False)" "None None muted text muted False" "the theme: never on"
eq "$(lk record False False 'STATE + "record\ton\n"')" "None None accent text strong False" "recording: on"
eq "$(lk record False False)" "None None muted text muted False" "…not recording: off"
eq "$(lk wallpaper False False)" "None None muted text muted False" "a row with its words always, and never on"
eq "$(lk power False False)" "None None muted text muted False"
eq "$(lk sound False False)" "None None muted text muted False" "a meter at rest: nothing behind its segments"
eq "$(lk brightness False False)" "None None muted text muted False"
for k in night devices wallpaper power sound brightness; do
  eq "$(lk $k False True)" "$(lk $k False False)" "$k under the pointer: drawn as at rest (it has the cursor then)"
  eq "$(lk $k True False)" "select None text_on_select text_on_select text_on_select True" "$k the cursor: filled with the lacquer"
  eq "$(lk $k True True)" "select None text_on_select text_on_select text_on_select True" "$k the cursor and under the pointer: the same"
done
eq "$(lk night True False)" "select None text_on_select text_on_select text_on_select True" "an item that is on, under the cursor: the cursor's inks win (the vermilion lacquer takes no vermilion ink)"
eq "$(py 'fresh(); print(sorted({kp.look(i, False, True) == kp.look(i, False, False) for i in p.items}))')" "[True]" \
  "no item is drawn differently under the pointer: no tint, no frame, no vermilion of its own"
eq "$(py 'fresh(STATE + "saver\t15 min\nrecord\ton\nvrrnow\ton\n"); bad = []
for i in p.items:
    rest, cur = kp.look(i, False, False), kp.look(i, True, False)
    want = ("accent", "strong") if i.on else ("muted", "muted")
    if (rest["glyph"], rest["value"], rest["label"], rest["fill"]) != (want + ("text", None)): bad.append((i.key, "rest"))
    if (cur["fill"], cur["glyph"], cur["label"], cur["value"], cur["on_fill"]) != ("select", "text_on_select", "text_on_select", "text_on_select", True): bad.append((i.key, "cursor"))
print(bad, " ".join(sorted(i.key for i in p.items if i.on)))')" "[] backup bluetooth drives network night record saver vrr" \
  "every item in a state with many things on: on is accent and strong, off muted, the cursor's inks win"
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
case_ "a meter's pixels (quick settings', the sound panel's and the brightness slider's): twenty segments of 6 × 10 a cell apart — lit in the level's ink (asagi, flame, accent), the next one partly from the bottom, unlit edge; hollow (an outline) while muted; on the cursor's lacquer lit text_on_select, unlit select_lo"
has "$d" 'full, part = lit_of(pct)'
has "$d" 'lit_ink, off_ink = ("text_on_select", "select_lo") if on else (seg_ink(i), "edge")'
has "$d" 'rows = SEG_H if i < full else part if i == full else 0'
has "$d" 'frame(cr, x, top, SEG_W, rows, lit_ink)'
has "$d" 'segments(cr, it, Panel.slider_x(it), it.y + (ROW - SEG_H) // 2, pct, on)' "centred in its row"
has "$d" 'glyph(cr, it.x + GLYPH_X, ty, ic.get(it.icon, it.icon) if it.icon else "", lk["glyph"])' "its icon in the icon column"
has "$d" 'text(cr, it.x + it.w, ty, it.value, lk["value"], right=True)' "no level: the words alone, at the row's end"
case_ "a row's pixels (§4): its icon in the icon column in the state's ink — accent when on, muted when off —, its name from cell 4, its state right-aligned at the row's end, two cells of air before it (strong when on, muted when off); under the cursor the row in the lacquer, a cell beyond the content either side, every ink text_on_select"
has "$d" 'glyph(cr, it.x + GLYPH_X, ty, g, lk["glyph"])'
has "$d" 'right -= text(cr, right, ty, it.value, lk["value"], right=True) + 2 * CELL'
has "$d" 'text(cr, it.x + NAME_X, ty, it.name, lk["label"], width=end - (it.x + NAME_X))'
case_ "the chosen dot and a calendar's today, in pixels: a lit row with no value gets a 6 px vermilion dot at its right edge (text_on_select on the cursor), its corners left out; today a 1 px accent frame, its corners cut"
has "$d" 'if it.lit and not it.value:'
has "$d" 'dot(cr, it.x + it.w - DOT, it.y + (ROW - DOT) // 2, "text_on_select" if on else "accent")'
has "$d" 'box(cr, x + 1, y, DOT - 2, DOT, name)'; has "$d" 'box(cr, x, y + 1, DOT, DOT - 2, name)'
has "$d" 'frame(cr, x, y, w, h, "accent_text", cut=True)'
case_ "no two functions of the panel share a name in one scope (a later one shadows the earlier: the frame's hairline vanished once, r27-19k-7)"
eq "$(python3 -I -B -c 'import ast, collections, sys
t = ast.parse(open(sys.argv[1]).read())
bad = []
for scope in [t] + [n for n in ast.walk(t) if isinstance(n, (ast.FunctionDef, ast.ClassDef))]:
    c = collections.Counter(n.name for n in scope.body if isinstance(n, ast.FunctionDef))
    bad += [getattr(scope, "name", "module") + "." + k for k, v in c.items() if v > 1]
print(bad)' "$REPO/bin/kawa-panel")" "[]"
case_ "the ground as see-through as the terminal's (kawa-glass's file): on as it is made, its alpha as saved, opaque without one"
G=$HOME/.local/state/fedokawaii/foot-glass.ini; rm -f "$G"
ON=$(sed -n 's/^ON=//p' "$REPO/bin/kawa-glass")
eq "$(py 'print(kp.glass())')" "$ON" "no file yet: on, as kawa-glass ensure makes it (its ON, $ON)"
mkdir -p "${G%/*}"; printf '%s\n' '# kawa-glass' '[colors-dark]' 'alpha=1' '[colors-light]' 'alpha=1' >"$G"
eq "$(py 'print(kp.glass())')" 1.0 "off: opaque"
printf '%s\n' '[colors-dark]' 'alpha=0.92' '[colors-light]' 'alpha=0.92' >"$G"; eq "$(py 'print(kp.glass())')" 0.92 "on"
printf '%s\n' '[colors-dark]' >"$G"; eq "$(py 'print(kp.glass())')" 1.0 "a file without an alpha: opaque (as kawa-glass reads it)"
printf 'alpha=7\n' >"$G"; eq "$(py 'print(kp.glass())')" 1.0 "never more than opaque"
printf 'alpha=x\n' >"$G"; eq "$(py 'print(kp.glass())')" "$ON" "unreadable: as made"
rm -f "$G"
eq "$(grep -c 'see\[0\] = glass()' "$REPO/bin/kawa-panel")" 1 "read again as each window is made (a switch seen at the next open)"
case_ "a meter set fast: one wpctl at a time, the last level asked the one that stays"
eq "$(py 'fresh(); [p.step("sound", 5) for _ in range(4)]; print(sum(c.startswith("run kawa-quick --do volume") for c in u.calls)); u.answer(); print(u.calls[-1]); u.answer(); print(u.calls[-1])')" \
  "$(printf '%s\n' 1 'run kawa-quick --do volume 80' 'run kawa-quick --state')"
case_ "a level being set is shown as asked when the state comes back meanwhile"
eq "$(py 'fresh(); p.step("sound", 5); p.refresh(); u.pending.pop(1)(0, STATE); print(p.state["sound"])')" 65%
case_ "the wheel over a meter: ±5"
eq "$(py 'fresh(); p.wheel(*seg("brightness", 9), True); p.wheel(*seg("sound", 9), False); print(p.state["brightness"], p.state["sound"])')" "75% 60%" "(62 % down: 60, the next multiple of 5)"
eq "$(py 'fresh(); p.wheel(40, 55, True); p.wheel(*mid("sound"), False); print(p.state["brightness"], p.state["sound"])')" "75% 60%" "…anywhere on the meter's row, over its icon or name too"
eq "$(py 'fresh(); p.wheel(*mid("theme"), True); print(u.calls)')" "[]" "over a row that has no wheel: nothing"
eq "$(py 'fresh(); p.wheel(*mid("night"), True); p.wheel(*mid("night"), False); print(u.calls)')" "['run kawa-quick --do warmer', 'run kawa-quick --do cooler']" "… but the night light's: warmer, cooler"
eq "$(py 'fresh(); p.wheel(*air("sound"), True); p.wheel(100, 25, False); print(p.state["brightness"], p.state["sound"], u.calls)')" "70% 62% []" "over the air between the groups, or the heading: nothing"

# ── the state ─────────────────────────────────────────────────────────────────────────
case_ "one reading at a time: asked again meanwhile, read once more after"
eq "$(py 'fresh(); p.refresh(); p.refresh(); p.refresh(); print(sum(c == "run kawa-quick --state" for c in u.calls)); u.answer(STATE); print(sum(c == "run kawa-quick --state" for c in u.calls))')" "$(printf '1\n2')"
case_ "kawa-quick failing: the last state stays"
eq "$(py 'fresh(); p.refresh(); u.answer("", 1); print(p.state["night"])')" on
case_ "the colours: the theme's panel.conf, every name the drawing uses (surface: the level display's solid ground; accent_hi: the lit vermilion)"
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
eq "$(py 'fresh(); p.request(); b = seg("brightness", 9); p.hover(*b); p.press(*b); p.hover(*seg("brightness", 5), dragging=True); p.close("chosen"); p.request(); print(p.focus, p.hot, p.dragging, p.pointer)')" "None None None None"
eq "$(py 'fresh(); p.request(); p.focus = "brightness"; p.press(*seg("brightness", 9)); p.close("lost"); u.t += 1; p.request(); print(p.focus, p.hot, p.dragging)')" "None None None" "… also a cursor the keys had shown, and closed by a click outside"
eq "$(py 'fresh(); p.request(); p.press(*seg("brightness", 9)); p.close("chosen"); p.request(); i = p.item("brightness"); print(sorted({x for x in kp.look(i, i.key == p.focus, i.key == p.hot).values() if x}))')" \
  "['muted', 'text']" "the brightness meter drawn as at rest: no vermilion lacquer, its icon not lit"
eq "$(py 'fresh(); p.request(); p.press(*seg("brightness", 9)); p.close("chosen"); p.request(); n = len(u.calls); p.hover(*mid("night"), dragging=True); print([c for c in u.calls[n:] if "--do" in c], p.hot)')" "[] night" \
  "a motion with the button held after reopening: no drag carried over"
case_ "no cursor until a key asks: the first arrow, Tab or Enter puts it on the first item (the brightness meter) and does nothing else"
for k in Down Up Left Right h j k l Tab ISO_Left_Tab Return KP_Enter space; do
  eq "$(py "fresh(); p.request(); u.calls.clear(); p.key('$k'); print(p.focus, p.state['brightness'], [c for c in u.calls if c.startswith('run')])")" "brightness 70% []" "$k"
done
eq "$(py 'fresh(); p.request(); p.key("Down"); p.key("Down"); print(p.focus)')" sound "then the keys go on from there (down the list to the sound)"
eq "$(py 'fresh(); p.request(); p.key("Escape"); print(p.visible)')" False "Esc closes it, cursor or not"
eq "$(py 'fresh(); p.request(); p.key("F5"); print(p.focus)')" None "another key: nothing"
case_ "every open: the cursor gone, even when the keys showed it"
eq "$(py 'fresh(); p.request(); p.key("Down"); p.key("Down"); p.close("chosen"); p.request(); print(p.focus)')" None

# ── the pointer: in, out, over a panel that changes ────────────────────────────────────
case_ "the pointer coming in (enter-notify): what is under it hot at once — and the cursor there — before any motion, only that item redrawn"
eq "$(py 'fresh(); p.request(); u.drawn.clear(); p.enter(*mid("night")); print(p.hot, p.focus, sorted({tuple(d) for d in u.drawn}))')" "night night [('night',)]"
eq "$(py 'fresh(); p.request(); p.enter(5, 5); print(p.hot, p.focus)')" "None None" "on the frame: nothing"
eq "$(py 'fresh(); p.request(); p.press(*seg("brightness", 9)); p.enter(*mid("night")); print(p.hot)')" brightness "during a drag the hot one stays"
case_ "it opens under the pointer: the item there is hot as the window says the pointer is in"
eq "$(py 'fresh(); p.request(); p.enter(*mid("wallpaper")); print(p.hot, p.focus)')" "wallpaper wallpaper"
case_ "the pointer leaving: only a real leave clears it — not one into a child's window, not a grab's crossing"
eq "$(py 'print([kp.real_leave(m, d) for m, d in (("normal", "nonlinear"), ("normal", "ancestor"), ("ungrab", "nonlinear"), ("normal", "inferior"), ("grab", "nonlinear"), ("gtk-grab", "ancestor"), ("state-changed", "nonlinear"))])')" \
  "[True, True, True, False, False, False, False]"
has "$(cat "$REPO/bin/kawa-panel")" 'if real_leave(ev.mode.value_nick, ev.detail.value_nick):'
has "$(cat "$REPO/bin/kawa-panel")" 'win.connect("enter-notify-event", on_enter)'
has "$(cat "$REPO/bin/kawa-panel")" 'Gdk.EventMask.ENTER_NOTIFY_MASK'
case_ "a click acts on the item under the pointer — hot at once, even with no motion or enter before it"
eq "$(py 'fresh(); p.request(); u.calls.clear(); p.press(*mid("night")); print(p.hot, u.calls[-2:])')" "night ['redraw', 'run kawa-quick --do night']"
eq "$(py 'fresh(); p.request(); p.hover(*mid("night")); u.calls.clear(); p.press(*mid("vrr")); print(p.hot, u.calls[-1])')" "vrr run kawa-quick --do vrr" "a stale hot one does not matter: the click's place does"
case_ "let go: the hot one is what is under the pointer then (a drag may end anywhere)"
eq "$(py 'fresh(); p.request(); p.press(*seg("brightness", 9)); p.hover(*mid("night"), dragging=True); p.release(*mid("night")); print(p.hot, p.dragging)')" "night None"
eq "$(py 'fresh(); p.request(); p.press(*seg("brightness", 9)); p.release(600, 600); print(p.hot)')" None "let go outside: nothing"
case_ "the panel changing under a still pointer (a state read): the hot one is what is under it now"
eq "$(py 'fresh(); p.request(); p.enter(*mid("bluetooth")); a = p.hot; u.answer(STATE.replace("bluetooth\ton\n","").replace("devices\tnone\n","")); print(a, p.hot)')" "bluetooth drives" "no adapter: the bluetooth and devices rows gone, the drives row stands under the pointer now"
eq "$(py 'opened("sound", SOUND); p.enter(200, 171); print(p.hot); p.refresh(); u.answer(SOUND.replace("input\t90", "output\t91\t0\tUSB DAC\t\t\t\t\t\ninput\t90")); print(p.hot)')" \
  "$(printf '%s\n' out:73 out:73)" "a device added below: the same row still under it"
eq "$(py 'opened("sound", SOUND); p.enter(200, 151); print(p.hot); p.refresh(); u.answer("\n".join(l for l in SOUND.split("\n") if not l.startswith("output\t62"))); print(p.hot)')" \
  "$(printf '%s\n' out:62 out:73)" "the row under it gone: the one that took its place"
case_ "one light in every panel and menu: the pointer moves the cursor in the sound panel, in a menu and in the launcher, as in quick settings"
eq "$(py 'opened("sound", SOUND); p.enter(200, 171); print(p.hot, p.focus)')" "out:73 out:73" "the sound panel"
eq "$(py 'fresh(); p.request("menu x", kp.Menu(["a", "b", "c"]), lambda rc, t: 0); it = p.item("2"); p.enter(it.x + 2, it.y + 2); print(p.hot, p.focus)')" "2 2" "a menu"
eq "$(py 'fresh(); p.request("launcher", kp.Launcher([], {}), None); print(p.hot, p.focus)')" "None None" "the launcher, no entries: nothing to take"
eq "$(py 'fresh(); p.enter(*mid("night")); print(p.hot, p.focus)')" "night None" "a panel not on screen: no cursor to move"
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
eq "$(grep -c 'ui.hide()' "$REPO/bin/kawa-panel")" 1 "only close() takes the window away"
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
eq "$(py 'print(kp.hang(1563, 0, 1920, 410), kp.hang(1616, 0, 1920, 312), kp.hang(1900, 0, 1920, 410), kp.hang(30, 0, 1920, 410), kp.hang(960, 0, 1920, 410))')" "1358 1460 1502 8 755" \
  "the volume (the sound panel, 410 wide), the brightness (its slider, 312), the cat (quick settings, 410 wide as the sound panel: held at the right edge, 1920 − 410 − 8), the far left (8), the middle (960 − 205)"
eq "$(py 'print(kp.hang(1920 + 1563, 1920, 2560, 410), kp.hang(1920 + 2550, 1920, 2560, 410), kp.hang(1925, 1920, 2560, 410))')" "1358 2142 8" \
  "on a second output (its own x and width): the margin is the output's own"
eq "$(py 'print(kp.hang(100, 0, 300, 410))')" 8 "an output narrower than the panel: from its left edge"
case_ "dwl's record (X Y OUTPUT OUTPUT_X OUTPUT_WIDTH): taken only while fresh (under 1 s old), and only whole"
eq "$(py 'print(kp.bar_click("1563 15 DP-1 0 1920\n", 0.2), kp.bar_click("1563.7 15 DP-1 1920 2560", 0.0), kp.bar_click("1563 15 DP-1 0 1920", 1.5), kp.bar_click("1563 15 DP-1 0", 0.1), kp.bar_click("x 15 DP-1 0 1920", 0.1), kp.bar_click("", 0.1))')" \
  "(1563, 0, 1920) (1563, 1920, 2560) None None None None"
eq "$(py 'fresh(); u.at = (1563, 0, 1920); p.request("sound"); print(p.place); u.at = None; u.t += 1; p.request("sound"); u.t += 1; p.request("sound"); print(p.place)')" \
  "$(printf '%s\n' "('left', 1358, 0)" "('right', 7, None)")" "each open asks anew: a click's place does not stay for the key's"
eq "$(py 'fresh(); u.at = (1900, 0, 1920); p.request(); print(p.place)')" "('left', 1502, 0)" "the cat: under it, held 8 px from the right edge (1920 − 410 − 8)"
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
case_ "the calendar's days: 40 × 20, 8 apart, seven a row from the content's edge, a row under the weekdays for each week; today framed in vermilion (its state); its three keys the whole width (104 each) 8 under the last week"
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

case_ "a list only to read (Super+/'s rows, longer than its 24 lines): it stands on a line's top whatever moves it — no line ever cut at the top — Down / Up a line, Page Down / Up a page, End / Home its ends (the last line whole), the wheel three lines a notch; j, k and Space are the field's letters"
eq "$(py 'fresh(); L = ["part\tI\tlaunch"] + ["info\t\tSuper+%d\trow %d" % (i, i) for i in range(30)] + ["part\tY\tyazi\tmoving"] + ["info\t\tk%d\tr %d" % (i, i) for i in range(30)]
p.request("menu kawa-help", kp.Menu(L, prompt="", fuzzy=True, lines_shown=24), lambda rc, t: 0)
top, vh, full = p.view; st = p.stops(); R = kp.ROW; s = []
for k in ("Down", "Down", "Up", "Page_Down", "Page_Down", "Page_Up", "End", "Down", "Home", "Up"):
    p.key(k); s.append(p.scroll)
p.wheel(0, 0, False); w = p.scroll
print(all(x in st for x in s + [w]), s[:3] == [st[1], st[2], st[1]], 0 < s[3] - s[2] <= (vh // R - 1) * R, s[4] > s[3], 0 < s[4] - s[5] <= (vh // R - 1) * R,
      s[6] == st[-1] >= full - vh, s[7] == st[-1], s[8:] == [0, 0], w == max(y for y in st if y <= 3 * R))
p.key("j", "j"); p.key("space", " "); p.key("k", "k")
print(p.state.query == "j k", p.scroll)')" "$(printf '%s\n' "True True True True True True True True True" "True 0")"
case_ "...and at every place it stands no line is cut at either edge: the top a line's top (stops), the view drawn down to its last whole line's foot (shown), the mouse finding nothing under that"
eq "$(py 'fresh(); L = []
for n in range(6): L += ["part\tI\tpart %d\tvalue" % n] + ["info\t\tk%d.%d\trow %d" % (n, i, i) for i in range(7 + n)]
p.request("menu kawa-help", kp.Menu(L, prompt="", fuzzy=True, lines_shown=24), lambda rc, t: 0)
top, vh, full = p.view
lines = [(it.y - top, it.y + it.h - top) for it in p.items] + [(mk[2] - top, mk[2] + kp.ROW - top) for mk in p.marks if mk[0] in kp.SHOWN_KINDS] + [(hd[3] - top, hd[3] + kp.ROW - top) for hd in p.heads]
bad = []
for st in p.stops():
    p.scroll = st; sh = p.drawn_h()
    if not 0 < sh <= vh: bad.append(("shown", st, sh))
    for t, f in lines:
        if t < st < f or t < st + sh < f: bad.append((st, sh, t, f))
p.scroll = p.stops()[1]; sh = p.drawn_h()
print(bad[:3], len(p.stops()) > 5, p.at(30, top + sh + 2) is None)')" "[] True True"
case_ "...one mouse notch, one move: under Wayland a mouse's notch comes as a step and as 1.5 of smooth parts in one frame — the step counts (three lines; a meter one step), in either order; a touchpad's smooth parts summed as before"
eq "$(py 'fresh(); L = ["part\tI\tlaunch"] + ["info\t\tSuper+%d\trow %d" % (i, i) for i in range(60)]
M = lambda: p.request("menu kawa-help", kp.Menu(L, prompt="", fuzzy=True, lines_shown=24), lambda rc, t: 0)
M(); p.wheel(0, 0, False); one = p.scroll
M(); p.scroll = 0; p.scroll_event(0, 0, up=False); p.scroll_event(0, 0, dy=1.5, mouse=True); a = p.scroll
M(); p.scroll = 0; p.scroll_event(0, 0, dy=1.5, mouse=True); p.scroll_event(0, 0, up=False); b = p.scroll
M(); p.scroll = 0; p.scrolled = (None, 0.0); p.scroll_event(0, 0, dy=1.5); c = p.scroll; st = p.stops()
print(a == one == b, one == max(y for y in st if y <= 3 * kp.ROW), c == st[4])')" "True True True"
eq "$(py 'fresh(); x, y = seg("brightness", 9); p.scroll_event(x, y, up=True); p.scroll_event(x, y, dy=-1.5, mouse=True); print(p.state["brightness"])')" "75%" "a mouse notch on a meter: one step (70 → 75), not two"
eq "$(py 'fresh(); n = mid("night"); p.scroll_event(*n, up=True); p.scroll_event(*n, dy=-1.5, mouse=True); print([c for c in u.calls if c.startswith("run")])')" "['run kawa-quick --do warmer']" "…and on the night light: one warmer, not two"
case_ "...a touchpad's small scrolls summed: a line per third of a notch, never a line for each small part"
eq "$(py 'fresh(); L = ["part\tI\tlaunch"] + ["info\t\tSuper+%d\trow %d" % (i, i) for i in range(60)]
p.request("menu kawa-help", kp.Menu(L, prompt="", fuzzy=True, lines_shown=24), lambda rc, t: 0)
st = p.stops(); a = []
for _ in range(4): p.scroll_by(0, 0, 0.1); a.append(p.scroll)
print(a == [0, 0, 0, st[1]], p.scroll in st)')" "True True"

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
