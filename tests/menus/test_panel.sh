#!/usr/bin/env bash
# tests/menus/test_panel.sh — kawa-panel, quick settings, the sound panel and the brightness
# slider on screen. Its window needs a screen,
# so what is tested is everything but the drawing (which the real one is measured for in
# docs/build: placement 8 px under the bar and from the edge, the 8 × 20 grid of
# docs/design-system.md §3): the layout (every item, its place, three tiles a row, the keys at
# the foot, the frame's box and the shadow that makes the window), the tiles' pictures and words
# for each state, the keys and the mouse, what each choice runs, the meters (twenty segments: the
# level a click, a drag or the wheel means, one level at a time), opening and closing (its key,
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
exec(sys.argv[3])
EOF
}

# ── the layout ─────────────────────────────────────────────────────────────────────────
case_ "the items, in order: two meters, the tiles (bluetooth and devices with an adapter), three keys"
eq "$(py 'fresh(); print(" ".join(i.key for i in p.items))')" \
  "brightness sound theme night vrr network bluetooth devices drives backup dnd saver record ocr wallpaper screenshot screenoff power"
eq "$(py 'fresh(STATE.replace("bluetooth\ton\n","").replace("devices\tnone\n","")); print(" ".join(i.key for i in p.items))')" \
  "brightness sound theme night vrr network drives backup dnd saver record ocr wallpaper screenshot screenoff power"
case_ "the captures: record (on while one runs: a click stops it) and read text, each closing the panel for its own picker"
eq "$(py 'fresh(); t = p.item("record"); print(t.icon, t.value, t.lit, p.item("ocr").icon, p.item("ocr").name)')" "tile_record off False tile_read read text"
eq "$(py 'fresh(STATE + "record\ton\n"); t = p.item("record"); print(t.value, t.lit)')" "recording True"
eq "$(py 'fresh(); p.request(); p.activate("record"); p.activate("ocr"); print([c for c in u.calls if c.startswith("launch")], p.visible)')" "['launch kawa-quick --do record', 'launch kawa-quick --do ocr'] False"
case_ "the size: 410 × 498 (a 1 px hairline, 16 px of pad, its heading and two meters, four rows of 120 × 80 tiles 8 apart, the keys; no day line: the bar's)"
eq "$(py 'fresh(); print(*p.size)')" "410 498"
eq "$(py 'print(kp.INNER, kp.INNER + 2 * (kp.PAD + kp.BORDER), kp.BORDER, kp.HAIR, kp.PAD)')" "376 410 1 1 16" "376 of content, 2 × 16 of pad, 2 × 1 of hairline"
case_ "the window is the frame's box and its shadow — a column at its right, two rows under it (411 × 500) — and never trimmed to its ink"
eq "$(py 'fresh(); print(*p.win, p.ox, p.dy, kp.SHADOW_R, kp.SHADOW_B)')" "411 500 0 0 1 2"
eq "$(py 'fresh(); print(p.win == (p.size[0] + kp.SHADOW_R, p.size[1] + kp.SHADOW_B), p.rules); opened("sound", SOUND); print(p.win == (p.size[0] + 1, p.size[1] + 2), p.rules); opened("brightness", "brightness\t70%\n"); print(p.win == (p.size[0] + 1, p.size[1] + 2), p.rules, p.dy)')" "$(printf '%s\n' "True []" "True []" "True [] 0")" "every panel the same: the box + 1 column, + 2 rows — no trimming (dy 0), nothing drawn between the groups"
case_ "it opens under its heading, as every panel: the sliders icon, quick settings, the rule to the right edge"
eq "$(py 'fresh(); print(p.heads)')" "[('sliders', 'quick settings', 17, 17)]"
case_ "notices are as wide: one column under the bar's right end"
has "$(cat "$REPO/configs/home/.config/mako/config")" "width=$(py 'fresh(); print(p.size[0])')"
case_ "the tiles: three a row (twelve: 3 3 3 3), 120 × 80, 8 apart; the content 17 px from every edge (the hairline and 16 of pad)"
eq "$(py 'fresh(); print(" ".join(f"{i.x},{i.y},{i.w},{i.h}" for i in p.items if i.kind == "tile"))')" \
  "17,101,120,80 145,101,120,80 273,101,120,80 17,189,120,80 145,189,120,80 273,189,120,80 17,277,120,80 145,277,120,80 273,277,120,80 17,365,120,80 145,365,120,80 273,365,120,80"
case_ "no adapter: ten tiles, three, three, then two and two — two a row are wider (never a lone tile), each row the full width"
eq "$(py 'fresh(STATE.replace("bluetooth\ton\n","").replace("devices\tnone\n","")); print(" ".join(f"{i.x}+{i.w}" for i in p.items if i.kind == "tile"))')" \
  "17+120 145+120 273+120 17+120 145+120 273+120 17+184 209+184 17+184 209+184"
eq "$(py 'print([kp.rows_of(n) for n in (9, 8, 7, 6, 4, 1)])')" "[[3, 3, 3], [3, 3, 2], [3, 2, 2], [3, 3], [2, 2], [1]]"
case_ "the keys at the foot: wallpaper, screenshot, screen off and power (each an icon alone, a 20 px square; screen off its tooltip) — the whole width, 8 apart, one row high"
eq "$(py 'fresh(); print(" ".join(f"{i.key}:{i.x}+{i.w}x{i.h}:{i.name or chr(45)}" for i in p.items if i.kind == "key"))')" \
  "wallpaper:17+156x20:wallpaper screenshot:181+156x20:screenshot screenoff:345+20x20:- power:373+20x20:-"
eq "$(py 'fresh(); print(p.item("screenoff").icon, p.item("screenoff").tip)')" "screen_off screen off"
eq "$(py 'fresh(); k=[i for i in p.items if i.kind=="key"]; print(k[0].x - 17, 393 - (k[-1].x + k[-1].w), p.size[1] - (k[0].y + k[0].h))')" "0 0 17" "edge to edge; 16 px of pad and the hairline under them"
case_ "the meters under the heading (its row, then 8 px of air): the full width, 20 px rows touching; the groups 16 px apart, nothing drawn between them"
eq "$(py 'fresh(); print(" ".join(f"{i.x},{i.y},{i.w},{i.h}" for i in p.items if i.kind == "meter"), p.rules)')" \
  "17,45,376,20 17,65,376,20 []"
eq "$(py 'fresh(); m=[i for i in p.items if i.kind=="meter"]; t=[i for i in p.items if i.kind=="tile"]; k=[i for i in p.items if i.kind=="key"][0]
print(m[0].y - (p.heads[0][3] + 20), m[1].y - (m[0].y + m[0].h), t[0].y - (m[-1].y + m[-1].h), k.y - (t[-1].y + t[-1].h))')" "8 0 16 16" "the heading's 8 px, the meters touching, then 16 px before the tiles and 16 before the keys"
eq "$(py 'print(kp.HEAD_H, kp.SECTION, kp.GROUP, kp.KEY_H, kp.METER_GAP, kp.GAP)')" "28 20 16 20 0 8" "the grid's own constants: a heading 28, 20 of air above one that is not first, groups 16 apart, keys 20, rows touching"

# ── the tiles' pictures and words ───────────────────────────────────────────────────────
t() { py "fresh($1); i = p.item('$2'); print(i.icon, i.name, '|', i.value, '|', 'lit' if i.lit else 'quiet')"; }
case_ "each tile: its own picture (an icon of the font), its name, how it stands; lit while it is on"
eq "$(t '' theme)" "tile_moon theme | dark | lit"
eq "$(t 'STATE.replace("theme\tdark","theme\tlight")' theme)" "tile_sun theme | light | lit" "light: the rising sun"
eq "$(t '' night)" "tile_lantern night light | on | lit"
eq "$(t 'STATE.replace("night\ton","night\toff")' night)" "tile_lantern night light | off | quiet"
eq "$(t 'STATE.replace("night\ton","night\t3500K")' night)" "tile_lantern night light | 3500K | lit" "on: its warmth"
eq "$(t 'STATE + "saver\t15 min\n"' saver)" "tile_saver screensaver | 15 min | lit"
eq "$(t 'STATE + "saver\toff\n"' saver)" "tile_saver screensaver | off | quiet"
eq "$(t '' vrr)" "tile_wave freesync | in games | lit"
eq "$(t 'STATE.replace("vrr\tin games","vrr\toff")' vrr)" "tile_wave freesync | off | quiet"
case_ "FreeSync's tile: the setting and the card's own state this moment (vrrnow), lit only while on"
eq "$(t 'STATE + "vrrnow\toff\n"' vrr)" "tile_wave freesync | games · off | quiet"
eq "$(t 'STATE + "vrrnow\ton\n"' vrr)" "tile_wave freesync | games · on | lit"
eq "$(t 'STATE.replace("vrr\tin games","vrr\talways") + "vrrnow\ton\n"' vrr)" "tile_wave freesync | always · on | lit"
eq "$(t 'STATE + "vrrnow\tnone\n"' vrr)" "tile_wave freesync | not offered | quiet"
eq "$(t 'STATE.replace("vrr\tin games","vrr\toff") + "vrrnow\toff\n"' vrr)" "tile_wave freesync | off | quiet"
case_ "the network tile's picture follows the kind of link: wired, Wi-Fi, none"
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
case_ "tiles_of: (key, picture, name, value, on) — five fields; every picture an icon of the font and no two alike (sixteen drawings over every state)"
eq "$(py 'S = [STATE.replace("theme\tdark", "theme\tlight"), STATE, STATE.replace("nettype\twifi", "nettype\tethernet"), STATE.replace("nettype\twifi", "nettype\toffline"), STATE.replace("dnd\toff", "dnd\ton")]
rows = [t for st in S for t in kp.tiles_of(kp.parse_state(st))]
pics = sorted({t[1] for t in rows}); ic = kp.icons()
print({len(t) for t in rows}, len(pics), [n for n in pics if n not in ic])
print(" ".join(pics))')" \
  "$(printf '%s\n' "{5} 16 []" "tile_backup tile_bell tile_bell_off tile_bluetooth tile_devices tile_drive tile_ethernet tile_lantern tile_moon tile_offline tile_read tile_record tile_saver tile_sun tile_wave tile_wifi")"
case_ "the wallpaper's name: the tip of its key"
eq "$(py 'fresh(); print(p.item("wallpaper").tip)')" mishima-mist
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
has "$(python3 -I "$REPO/bin/kawa-panel" --help)" "their levels are the"
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
case_ "a switch (theme, night light, freesync, bluetooth, dnd): done in place, the panel open, the state read after"
for k in theme night vrr bluetooth dnd; do
  eq "$(py "fresh(); p.request(); u.answer(STATE); u.calls.clear(); p.activate('$k'); u.answer(); print(', '.join(u.calls), p.visible)")" \
    "run kawa-quick --do $k, run kawa-quick --state True" "$k"
done
case_ "the others: the panel closes, then their own menu or window"
for k in network devices drives backup wallpaper screenshot screenoff power; do
  eq "$(py "fresh(); p.request(); u.calls.clear(); p.activate('$k'); print(', '.join(u.calls))")" \
    "hide, light quick off, launch kawa-quick --do $k" "$k"
done
case_ "Enter on the sound meter: the sound panel (outputs, inputs) in its place; on brightness: nothing more"
eq "$(py 'fresh(); p.request(); u.calls.clear(); p.focus = "sound"; p.key("Return"); print(", ".join(u.calls)); print(p.mode, p.visible, p.focus)')" \
  "$(printf '%s\n' "hide, light quick off, show, light sound on, run kawa-quick --state sound" "sound True None")"
eq "$(py 'fresh(); p.request(); u.calls.clear(); p.focus = "brightness"; p.key("Return"); print(u.calls)')" "[]"

# ── the keys ──────────────────────────────────────────────────────────────────────────
nav() { py "fresh(); p.focus = '$1'; [p.key(k) for k in '$2'.split()]; print(p.focus)"; }
case_ "arrows (and h j k l): along a row, and up and down to the nearest below or above"
eq "$(nav theme 'Right Right Right')" vrr "the end of a row stays"
eq "$(nav theme 'Down Down')" drives; eq "$(nav night 'Down')" bluetooth; eq "$(nav vrr 'j j j j')" screenoff "(the nearest centre below)"
eq "$(nav theme 'Up')" sound; eq "$(nav sound 'k k')" brightness; eq "$(nav brightness 'Up')" brightness
eq "$(nav dnd 'Down')" ocr; eq "$(nav saver 'Down')" wallpaper "the foot: the key nearest below"; eq "$(nav record 'Down')" screenshot
eq "$(nav screenshot 'Up')" record "(its centre, 259, nearer record's 205 than ocr's 333)"; eq "$(nav sound 'Down')" night "from a meter: the middle tile"
case_ "Tab and Shift+Tab: every item in turn, round"
eq "$(nav power 'Tab')" brightness; eq "$(nav brightness 'ISO_Left_Tab')" power
case_ "← → (h l) on a meter: its level by 5, at once and then set"
eq "$(py 'fresh(); p.focus = "sound"; p.key("Right"); print(p.state["sound"], u.calls[-1])')" "65% run kawa-quick --do volume 65"
eq "$(py 'fresh(); p.focus = "brightness"; p.key("h"); print(p.state["brightness"], u.calls[-1])')" "65% run kawa-quick --do brightness 65"
eq "$(py 'fresh(); p.focus = "brightness"; [p.key("Right") for _ in range(9)]; print(p.state["brightness"])')" 100% "no more than 100"
case_ "a meter without a level (no DDC/CI, muted, no output): ← → do nothing"
eq "$(py 'fresh(STATE.replace("70%","no DDC/CI")); p.focus = "brightness"; p.key("Right"); print(p.state["brightness"], u.calls)')" "no DDC/CI []"

# ── the mouse ─────────────────────────────────────────────────────────────────────────
# (quick settings, 12 tiles: night at x 145–265, y 101–181; the meters' segments from x 235, a
# cell each; brightness y 45–65, sound y 65–85; the keys y 461–481)
case_ "one light: the pointer over an item moves the cursor there (it is hot and the cursor at once), and the cursor stays where the pointer left it"
eq "$(py 'opened("quick", STATE); p.hover(200, 130); print(p.hot, p.focus)')" "night night"
eq "$(py 'opened("quick", STATE); p.hover(200, 130); p.hover(10, 130); print(p.hot, p.focus)')" "None night" "over the frame or a gap: nothing hot, the cursor where the pointer left it"
eq "$(py 'opened("quick", STATE); p.hover(200, 130); p.leave(); print(p.hot, p.focus)')" "None night" "the pointer gone: the cursor stays"
eq "$(py 'opened("quick", STATE); p.focus = "theme"; p.hover(200, 130); print(p.hot, p.focus)')" "night night" "a cursor the keys showed: the pointer takes it"
eq "$(py 'fresh(); p.hover(200, 130); print(p.hot, p.focus)')" "night None" "a panel not open shows no cursor"
case_ "a click does what is under the pointer, there and then"
eq "$(py 'opened("quick", STATE); p.hover(200, 130); p.press(200, 130); print(p.hot, p.focus)')" "night night"
eq "$(py 'fresh(); p.press(300, 75); print(p.focus)')" None "a click on a meter, with no cursor shown: none is shown for it"
eq "$(py 'fresh(); p.focus = "theme"; p.press(300, 75); print(p.focus)')" sound "… but a cursor the keys showed follows the click"
eq "$(py 'fresh(); p.request(); u.calls.clear(); p.press(60, 470); print(", ".join(u.calls))')" "redraw, hide, light quick off, launch kawa-quick --do wallpaper"
case_ "the keys move the cursor from where the pointer left it"
eq "$(py 'opened("quick", STATE); p.hover(330, 130); p.key("Left"); print(p.hot, p.focus)')" "vrr night"
eq "$(py 'opened("quick", STATE); p.hover(200, 220); p.key("Down"); print(p.hot, p.focus)')" "bluetooth backup"
case_ "the pointer leaving the panel: nothing hot, only that item redrawn; the cursor stays"
eq "$(py 'opened("quick", STATE); p.hover(200, 130); u.drawn.clear(); p.leave(); print(p.hot, p.focus, u.drawn)')" "None night [['night']]"
eq "$(py 'fresh(); u.drawn.clear(); p.leave(); print(u.drawn)')" "[]" "nothing was hot: nothing redrawn"
has "$(cat "$REPO/bin/kawa-panel")" 'win.connect("leave-notify-event", on_leave)'
has "$(cat "$REPO/bin/kawa-panel")" 'Gdk.EventMask.LEAVE_NOTIFY_MASK'
case_ "opened again: nothing hot until the pointer says where it is (a new window); a state read keeps it while it is there"
eq "$(py 'fresh(); p.request(); p.hover(200, 130); p.close("chosen"); p.request(); print(p.hot)')" None
eq "$(py 'fresh(); p.hover(200, 130); p.refresh(); u.answer(STATE); print(p.hot)')" night
eq "$(py 'fresh(); p.hover(205, 400); a = p.hot; p.refresh(); u.answer(STATE.replace("bluetooth\ton\n","").replace("devices\tnone\n","")); print(a, p.hot)')" "record None" "the last row reflowed to two wide tiles: the gap between them"
case_ "a drag: the meter follows, the hot one does not move off it (nor the cursor)"
eq "$(py 'opened("quick", STATE); p.hover(300, 55); p.press(300, 55); p.hover(200, 130, dragging=True); print(p.hot, p.focus)')" "brightness brightness"
eq "$(py 'fresh(); p.press(5, 5); print(u.calls)')" "[]" "on the frame: nothing"
case_ "a click on a meter's segments: the level of the segment under it (lit to its top); the air before the first: 0; a drag follows"
eq "$(py 'fresh(); print([ (p.press(235 + o, 55), p.state["brightness"])[1] for o in (0, 7, 76, 80, 157) ])')" "['5%', '5%', '50%', '55%', '100%']" "a segment is 6 px and 2 of air: off 0–7 the first, 76 the tenth, 80 the eleventh, 157 the last pixel of the twentieth"
eq "$(py 'fresh(); p.press(235 - 6, 55); print(p.state["brightness"])')" 0% "just left of the first segment: 0"
eq "$(py 'fresh(); p.press(235 - 9, 55); print(p.state["brightness"], [c for c in u.calls if c.startswith("run")])')" "70% []" "past the cell of air before it: on the meter's name, not its segments: nothing set"
eq "$(py 'fresh(); p.press(235 + 4, 75); p.hover(420, 75, dragging=True); print(p.state["sound"])')" 100%
eq "$(py 'fresh(); p.press(235 + 4, 75); p.release(); p.hover(420, 75, dragging=True); print(p.state["sound"])')" 5% "let go: no more"

case_ "the segments and the level, one rule both ways: a click lights through the segment under the pointer (to its top), the air before the first is 0"
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
eq "$(py 'fresh(); m = p.item("brightness"); x0 = p.slider_x(m); print(x0, [p.meter_at(m, x0 + o) for o in (-9, -8, -1, 0, 7, 8, 159, 167, 168)], p.meter_at(m, x0 - 300, held=True), p.meter_at(m, x0 + 900, held=True))')" \
  "235 [None, 0, 0, 5, 5, 10, 100, 100, None] 0 100" "the pointer counts from a cell before the run to a cell after it; dragged, anywhere (an end held)"
eq "$(py 'fresh(); m = p.item("brightness"); print(p.slider_x(m) + (kp.SEGS - 1) * kp.CELL + kp.SEG_W == m.x + m.w); m.trail = 20; print(p.slider_x(m))')" "$(printf '%s\n' True 215)" "the last segment's ink on the content's edge; before a value's room, further left"
eq "$(py 'print([callable(getattr(kp, n, None)) for n in ("lit_of", "seg_ink", "level_at", "snap")], hasattr(kp, "SEGS"))')" "[True, True, True, True] True" "the segments are the whole of the slider: what they light, in which ink, what a pointer on them means"
eq "$(py 'print([kp.snap(v, d) for v, d in ((62, 5), (62, -5), (60, 5), (60, -5), (0, -5), (98, 5), (100, 5))])')" \
  "[65, 60, 65, 55, 0, 100, 100]" "keys and the wheel: to the next multiple of 5"

case_ "a drag: every motion sets the level under the pointer at once, only that meter redrawn, one set at a time, the last one sent"
eq "$(py '
fresh(); p.press(235 + 30, 55); u.drawn.clear()
shown = []
for x in range(227, 420, 7):
    p.hover(x, 55, dragging=True); shown.append(p.state["brightness"] == f"{kp.level_at(x - 235)}%")
print(all(shown), all(d == ["brightness"] for d in u.drawn), sum(c.startswith("run kawa-quick --do brightness") for c in u.calls))
u.answer(); print(u.calls[-1]); p.release(); u.answer(); print(u.calls[-1])')" \
  "$(printf '%s\n' 'True True 1' 'run kawa-quick --do brightness 100' 'run kawa-quick --state')"
eq "$(py 'fresh(); p.press(235 + 30, 55); n = len(u.calls); p.hover(235 + 31, 55, dragging=True); p.hover(235 + 31.5, 55, dragging=True); print(len(u.calls) - n)')" 0 "the same level again (the same segment): nothing redrawn, nothing sent"
eq "$(py 'fresh(); p.press(235 + 4, 55); p.hover(-50, 55, dragging=True); a = p.state["brightness"]; p.hover(900, 55, dragging=True); print(a, p.state["brightness"])')" "0% 100%" "dragged past either end: that end"

case_ "no snapping back: a state read that comes back mid-drag, or was started before the last change, leaves the meter as set"
eq "$(py '
fresh(); p.refresh()                                  # (a read already under way: the open)
p.press(335, 55); v = p.state["brightness"]
u.pending.pop(1)(0, STATE)                            # (it comes back with the old 70 %)
print(v, p.state["brightness"])')" "65% 65%"
eq "$(py '
fresh(); p.press(335, 55); p.release(); p.refresh()
u.answer()                                            # (the level set: confirmed)
u.answer(STATE)                                       # (the read started before that: 70 %)
print(p.state["brightness"])')" 65% "a read started while it was being set: ignored"
eq "$(py '
fresh(); p.press(335, 55); p.release(); u.answer()
u.answer(STATE.replace("70%", "65%").replace("night\ton", "night\toff"))
print(p.state["brightness"], p.state["night"], p.held("brightness"))')" "65% off False" "a read after it: taken, and the meter free again"
eq "$(py '
fresh(); p.refresh(); p.press(335, 55); p.release(); p.refresh(); u.answer(STATE); u.answer(); u.answer(STATE); u.answer(STATE)
print(p.state["brightness"], p.held("brightness"))')" "70% False" "reads that started while it was set are ignored, but only those: the meter is not held for good"
eq "$(py '
fresh(); p.press(335, 55); p.release(); u.answer(); u.answer(STATE)
print(p.state["brightness"])')" 70% "… so a level the machine did not take shows as it is"

case_ "the wheel and a touchpad: a step per notch; a touchpad's small scrolls summed, not a step each"
eq "$(py 'fresh(); p.scroll_by(200, 55, -1.0); a = p.state["brightness"]; [p.scroll_by(200, 55, -0.25) for _ in range(3)]; b = p.state["brightness"]; p.scroll_by(200, 55, -0.25); print(a, b, p.state["brightness"])')" "75% 75% 80%"
eq "$(py 'fresh(); p.scroll_by(200, 55, 0.5); p.scroll_by(200, 75, 0.5); print(p.state["brightness"], p.state["sound"])')" "70% 62%" "half a step on one meter does not add to the other"

case_ "moving between items redraws only those that changed: the one left and the one entered (the cursor and the hot one together)"
eq "$(py 'opened("quick", STATE); p.hover(200, 130); print(sorted({tuple(d) for d in u.drawn}))')" "[('night',)]" "the first: only it"
eq "$(py 'opened("quick", STATE); p.hover(200, 130); u.drawn.clear(); p.hover(320, 130); print(sorted({tuple(d) for d in u.drawn}))')" "[('night', 'vrr')]"
eq "$(py 'opened("quick", STATE); p.hover(200, 130); u.drawn.clear(); p.hover(201, 131); p.hover(210, 150); print(u.drawn)')" "[]" "within the same item: nothing"
eq "$(py 'opened("quick", STATE); p.hover(200, 130); u.drawn.clear(); p.hover(210, 184); print(sorted({tuple(d) for d in u.drawn}))')" "[('night',)]" "onto the gap under it: the one left"
eq "$(py 'opened("quick", STATE); p.hover(200, 130); u.drawn.clear(); p.hover(10, 130); print(u.drawn, p.focus)')" "[['night']] night" "onto the frame: the one left, the cursor stays"
eq "$(py 'fresh(); p.focus = "theme"; u.drawn.clear(); p.key("Right"); print(u.drawn)')" "[['theme', 'night']]" "the keys: the cursor's two"

case_ "how each item is drawn (look): the cursor fills it with the lacquer (select); at rest a tile in its edge frame, on — its crest a vermilion seal with a paper ring, the picture knocked out in paper, its state strong — or off — the crest's outline edge2, its picture and name muted, its state faint; a key on its own fill in a 1 px frame; a meter bare. The pointer adds nothing of its own: it moves the cursor"
lk() { py "fresh(); i = p.item('$1'); l = kp.look(i, $2, $3); print(l['fill'], l['frame'], l['glyph'], l['label'], l['value'], l['on_fill'])"; }
eq "$(lk night False False)" "key edge key text strong False" "a tile that is on"
eq "$(lk devices False False)" "key edge muted muted faint False" "a tile that is off"
crest() { py "fresh(); i = p.item('$1'); l = kp.look(i, $2, False); print(l['seal'], l['ring'], l['outline'])"; }
eq "$(crest night False)" "accent key None" "on: the seal vermilion, its ring paper"
eq "$(crest devices False)" "None None edge2" "off: the outline"
eq "$(crest night True)" "text_on_select accent None" "on, under the cursor: the seal in its ink, the ring vermilion"
eq "$(crest devices True)" "None None text_on_select" "off, under the cursor: the outline in its ink"
eq "$(lk wallpaper False False)" "key edge text text muted False" "a key at rest: its fill and edge frame"
eq "$(lk power False False)" "key edge text text muted False"
eq "$(lk sound False False)" "None None muted text muted False" "a meter at rest: nothing behind it"
for k in night devices wallpaper power sound; do
  eq "$(lk $k False True)" "$(lk $k False False)" "$k under the pointer: drawn as at rest (it has the cursor then)"
  g=text_on_select; [[ $k == night ]] && g=select          # (a seal under the cursor: its picture the lacquer)
  eq "$(lk $k True False)" "select None $g text_on_select text_on_select True" "$k the cursor: filled with the lacquer"
  eq "$(lk $k True True)" "select None $g text_on_select text_on_select True" "$k the cursor and under the pointer: the same"
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
case_ "a meter's pixels: twenty segments of 6 × 10 a cell apart — lit in the level's ink (asagi, flame, accent), the next one partly from the bottom, unlit edge; hollow (an outline) while muted; on the cursor's lacquer lit text_on_select, unlit select_lo"
has "$d" 'full, part = lit_of(pct)'
has "$d" 'lit_ink, off_ink = ("text_on_select", "select_lo") if on else (seg_ink(i), "edge")'
has "$d" 'rows = SEG_H if i < full else part if i == full else 0'
has "$d" 'frame(cr, x, top, SEG_W, rows, lit_ink)'
has "$d" 'segments(cr, it, Panel.slider_x(it), it.y + (ROW - SEG_H) // 2, pct, on)' "centred in its row"
case_ "the chosen dot and a calendar's today, in pixels: a lit row with no value gets a 6 px vermilion dot at its right edge (text_on_select on the cursor), its corners left out; today a 1 px accent frame, its corners cut"
has "$d" 'if it.lit and not it.value:'
has "$d" 'dot(cr, it.x + it.w - DOT, it.y + (ROW - DOT) // 2, "text_on_select" if on else "accent")'
has "$d" 'box(cr, x + 1, y, DOT - 2, DOT, name)'; has "$d" 'box(cr, x, y + 1, DOT, DOT - 2, name)'
has "$d" 'frame(cr, x, y, w, h, "accent_text", cut=True)'
case_ "a tile's pixels (§4): its crest — a seal 28 px across on the tile's middle column, 4 px of air above it as under its state; on, a disc and a paper ring 2 px inside its edge, off, a 1 px outline — its picture (14 px) in its middle; its name on row 2, its state on row 3, centred by their ink"
has "$d" 'cx, cy = it.x + it.w // 2, it.y + CREST_TOP + CREST_R'
has "$d" 'for dy, a, b in disc_rows(r - 2, r - 3):'; has "$d" 'for dy, a, b in disc_rows(CREST_R, CREST_R - 1):'
has "$d" 'pic(cr, cx - 7, cy - 7, ic[it.icon], lk["glyph"])'
has "$d" 'text(cr, it.x + (it.w - ink_w.width) // 2 - ink_w.x, it.y + row * ROW + (ROW - LINE) // 2,'
eq "$(py 'print(kp.CREST_R, kp.CREST_TOP, kp.TILE_H - 2 * kp.ROW)')" "14 5 40" "28 px across, its top 5 px down the tile (the frame's pixel and 4 of air), in the two rows above the words"
eq "$(py 'r = kp.disc_rows(14); ys = sorted({y for y, a, b in r}); w = {y: b - a + 1 for y, a, b in r}
print(len(ys), ys[0], ys[-1], max(w.values()), all(a == -1 - b for y, a, b in r), all(w[y] == w[-1 - y] for y in ys))')" \
  "28 -14 13 28 True True" "the disc: 28 rows, 28 wide at its widest, symmetric left-right and top-bottom"
eq "$(py 'r = kp.disc_rows(14, 13); print(sorted({len([1 for y2, a, b in r if y2 == y]) for y in range(-14, 14)}))')" "[1, 2]" \
  "the outline: one run on its top and bottom rows, two (left, right) between"
case_ "a tile turned on while quick settings shows: its seal stamped (§11) — a pixel larger in accent_hi for STAMP_MS, then its size; never at an open, never turned off"
eq "$(py 'fresh(); p.request(); u.answer(STATE); s0 = dict(p.states["quick"]); print(p.stamps)
u.t = 200.0; p.refresh(); u.answer(STATE.replace("dnd\toff", "dnd\ton")); print(sorted(p.stamps), p.stamping("dnd"))
u.t = 200.0 + kp.STAMP_MS / 1000 + 0.001; print(p.stamping("dnd"))
u.t = 300.0; p.refresh(); u.answer(STATE); print(sorted(p.stamps))')" \
  "$(printf '%s\n' '{}' "['dnd'] True" 'False' "['dnd']")"
has "$d" 'box(cr, cx + a, cy + dy, b - a + 1, 1, "accent_hi" if big else lk["seal"])' "the stamp's ink"
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
eq "$(py 'fresh(); p.wheel(200, 55, True); p.wheel(200, 75, False); print(p.state["brightness"], p.state["sound"])')" "75% 60%" "(62 % down: 60, the next multiple of 5)"
eq "$(py 'fresh(); p.wheel(320, 170, True); print(u.calls)')" "[]" "over a tile: nothing"
eq "$(py 'fresh(); p.wheel(200, 170, True); p.wheel(200, 170, False); print(u.calls)')" "['run kawa-quick --do warmer', 'run kawa-quick --do cooler']" "… but the night light's: warmer, cooler"

# ── the state ─────────────────────────────────────────────────────────────────────────
case_ "one reading at a time: asked again meanwhile, read once more after"
eq "$(py 'fresh(); p.refresh(); p.refresh(); p.refresh(); print(sum(c == "run kawa-quick --state" for c in u.calls)); u.answer(STATE); print(sum(c == "run kawa-quick --state" for c in u.calls))')" "$(printf '1\n2')"
case_ "kawa-quick failing: the last state stays"
eq "$(py 'fresh(); p.refresh(); u.answer("", 1); print(p.state["night"])')" on
case_ "the colours: the theme's panel.conf, every name the drawing uses (surface: the level display's solid ground; accent_hi: a seal the moment it is stamped)"
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
eq "$(py 'fresh(); p.request(); p.hover(300, 55); p.press(300, 55); p.hover(260, 55, dragging=True); p.close("chosen"); p.request(); print(p.focus, p.hot, p.dragging, p.pointer)')" "None None None None"
eq "$(py 'fresh(); p.request(); p.focus = "brightness"; p.press(300, 55); p.close("lost"); u.t += 1; p.request(); print(p.focus, p.hot, p.dragging)')" "None None None" "… also a cursor the keys had shown, and closed by a click outside"
eq "$(py 'fresh(); p.request(); p.press(300, 55); p.close("chosen"); p.request(); i = p.item("brightness"); print(sorted({x for x in kp.look(i, i.key == p.focus, i.key == p.hot).values() if x}))')" \
  "['muted', 'text']" "the brightness meter drawn as at rest: no vermilion fill, its name not lit"
eq "$(py 'fresh(); p.request(); p.press(300, 55); p.close("chosen"); p.request(); n = len(u.calls); p.hover(200, 130, dragging=True); print([c for c in u.calls[n:] if "--do" in c], p.hot)')" "[] night" \
  "a motion with the button held after reopening: no drag carried over"
case_ "no cursor until a key asks: the first arrow, Tab or Enter puts it on the first item (and does nothing else)"
for k in Down Up Left Right Tab Return space j l; do
  eq "$(py "fresh(); p.request(); u.calls.clear(); p.key('$k'); print(p.focus, p.state['brightness'], [c for c in u.calls if c.startswith('run')])")" "brightness 70% []" "$k"
done
eq "$(py 'fresh(); p.request(); p.key("Down"); p.key("Down"); print(p.focus)')" sound "then the keys go on from there"
eq "$(py 'fresh(); p.request(); p.key("Escape"); print(p.visible)')" False "Esc closes it, cursor or not"
eq "$(py 'fresh(); p.request(); p.key("F5"); print(p.focus)')" None "another key: nothing"
case_ "every open: the cursor gone, even when the keys showed it"
eq "$(py 'fresh(); p.request(); p.key("Down"); p.key("Down"); p.close("chosen"); p.request(); print(p.focus)')" None

# ── the pointer: in, out, over a panel that changes ────────────────────────────────────
case_ "the pointer coming in (enter-notify): what is under it hot at once — and the cursor there — before any motion, only that item redrawn"
eq "$(py 'fresh(); p.request(); u.drawn.clear(); p.enter(200, 130); print(p.hot, p.focus, sorted({tuple(d) for d in u.drawn}))')" "night night [('night',)]"
eq "$(py 'fresh(); p.request(); p.enter(5, 5); print(p.hot, p.focus)')" "None None" "on the frame: nothing"
eq "$(py 'fresh(); p.request(); p.press(300, 55); p.enter(200, 130); print(p.hot)')" brightness "during a drag the hot one stays"
case_ "it opens under the pointer: the item there is hot as the window says the pointer is in"
eq "$(py 'fresh(); p.request(); p.enter(60, 470); print(p.hot, p.focus)')" "wallpaper wallpaper"
case_ "the pointer leaving: only a real leave clears it — not one into a child's window, not a grab's crossing"
eq "$(py 'print([kp.real_leave(m, d) for m, d in (("normal", "nonlinear"), ("normal", "ancestor"), ("ungrab", "nonlinear"), ("normal", "inferior"), ("grab", "nonlinear"), ("gtk-grab", "ancestor"), ("state-changed", "nonlinear"))])')" \
  "[True, True, True, False, False, False, False]"
has "$(cat "$REPO/bin/kawa-panel")" 'if real_leave(ev.mode.value_nick, ev.detail.value_nick):'
has "$(cat "$REPO/bin/kawa-panel")" 'win.connect("enter-notify-event", on_enter)'
has "$(cat "$REPO/bin/kawa-panel")" 'Gdk.EventMask.ENTER_NOTIFY_MASK'
case_ "a click acts on the item under the pointer — hot at once, even with no motion or enter before it"
eq "$(py 'fresh(); p.request(); u.calls.clear(); p.press(200, 130); print(p.hot, u.calls[-2:])')" "night ['redraw', 'run kawa-quick --do night']"
eq "$(py 'fresh(); p.request(); p.hover(200, 130); u.calls.clear(); p.press(320, 130); print(p.hot, u.calls[-1])')" "vrr run kawa-quick --do vrr" "a stale hot one does not matter: the click's place does"
case_ "let go: the hot one is what is under the pointer then (a drag may end anywhere)"
eq "$(py 'fresh(); p.request(); p.press(300, 55); p.hover(200, 130, dragging=True); p.release(200, 130); print(p.hot, p.dragging)')" "night None"
eq "$(py 'fresh(); p.request(); p.press(300, 55); p.release(420, 55); print(p.hot)')" None "let go outside: nothing"
case_ "the panel changing under a still pointer (a state read): the hot one is what is under it now"
eq "$(py 'fresh(); p.request(); p.enter(200, 260); u.answer(STATE.replace("bluetooth\ton\n","").replace("devices\tnone\n","")); print(p.hot)')" drives
eq "$(py 'opened("sound", SOUND); p.enter(200, 171); print(p.hot); p.refresh(); u.answer(SOUND.replace("input\t90", "output\t91\t0\tUSB DAC\t\t\t\t\t\ninput\t90")); print(p.hot)')" \
  "$(printf '%s\n' out:73 out:73)" "a device added below: the same row still under it"
eq "$(py 'opened("sound", SOUND); p.enter(200, 151); print(p.hot); p.refresh(); u.answer("\n".join(l for l in SOUND.split("\n") if not l.startswith("output\t62"))); print(p.hot)')" \
  "$(printf '%s\n' out:62 out:73)" "the row under it gone: the one that took its place"
case_ "one light in every panel and menu: the pointer moves the cursor in the sound panel, in a menu and in the launcher, as in quick settings"
eq "$(py 'opened("sound", SOUND); p.enter(200, 171); print(p.hot, p.focus)')" "out:73 out:73" "the sound panel"
eq "$(py 'fresh(); p.request("menu x", kp.Menu(["a", "b", "c"]), lambda rc, t: 0); it = p.item("2"); p.enter(it.x + 2, it.y + 2); print(p.hot, p.focus)')" "2 2" "a menu"
eq "$(py 'fresh(); p.request("launcher", kp.Launcher([], {}), None); print(p.hot, p.focus)')" "None None" "the launcher, no entries: nothing to take"
eq "$(py 'fresh(); p.enter(200, 130); print(p.hot, p.focus)')" "night None" "a panel not on screen: no cursor to move"
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
eq "$(py 'fresh(); print(p.slider_x(p.item("brightness")))')" 235 "quick settings' segments, their last on the content's edge too"
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
eq "$(py 'print(kp.hang(1563, 0, 1920, 410), kp.hang(1616, 0, 1920, 410), kp.hang(1900, 0, 1920, 410), kp.hang(30, 0, 1920, 410), kp.hang(960, 0, 1920, 410))')" "1358 1411 1502 8 755" \
  "the volume, the brightness, the cat (held at the right edge: 1920 − 410 − 8), the far left (8), the middle"
eq "$(py 'print(kp.hang(1920 + 1563, 1920, 2560, 410), kp.hang(1920 + 2550, 1920, 2560, 410), kp.hang(1925, 1920, 2560, 410))')" "1358 2142 8" \
  "on a second output (its own x and width): the margin is the output's own"
eq "$(py 'print(kp.hang(100, 0, 300, 410))')" 8 "an output narrower than the panel: from its left edge"
case_ "dwl's record (X Y OUTPUT OUTPUT_X OUTPUT_WIDTH): taken only while fresh (under 1 s old), and only whole"
eq "$(py 'print(kp.bar_click("1563 15 DP-1 0 1920\n", 0.2), kp.bar_click("1563.7 15 DP-1 1920 2560", 0.0), kp.bar_click("1563 15 DP-1 0 1920", 1.5), kp.bar_click("1563 15 DP-1 0", 0.1), kp.bar_click("x 15 DP-1 0 1920", 0.1), kp.bar_click("", 0.1))')" \
  "(1563, 0, 1920) (1563, 1920, 2560) None None None None"
eq "$(py 'fresh(); u.at = (1563, 0, 1920); p.request("sound"); print(p.place); u.at = None; u.t += 1; p.request("sound"); u.t += 1; p.request("sound"); print(p.place)')" \
  "$(printf '%s\n' "('left', 1358, 0)" "('right', 7, None)")" "each open asks anew: a click's place does not stay for the key's"
eq "$(py 'fresh(); u.at = (1900, 0, 1920); p.request(); print(p.place)')" "('left', 1502, 0)" "the cat: under it, held 8 px from the right edge"
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
for _ in {1..50}; do [[ -e $TMP/wb.log.up ]] && break; sleep 0.05; done
XDG_RUNTIME_DIR=$R3 py 'kp.poke("quick"); kp.poke("sound"); kp.poke("menu kawa-quick")'
for _ in {1..20}; do [[ $(wc -l <"$TMP/wb.log" 2>/dev/null) -ge 2 ]] && break; sleep 0.05; done
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
