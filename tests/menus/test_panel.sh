#!/usr/bin/env bash
# tests/menus/test_panel.sh — kawa-panel, quick settings, the sound panel and the brightness
# slider on screen. Its window needs a screen,
# so what is tested is everything but the drawing (which the real one is measured for in
# docs/build: placement 8 px under the bar and from the edge, the 12 px grid): the layout
# (every item, its place, three tiles a row, the keys at the foot centred), the tiles' words
# and seals for each state, the keys and the mouse, what each choice runs, the meters (set
# where clicked, the wheel, one level at a time), opening and closing (its key, Esc, a click
# outside — and the click on the bar's cat that made that click outside), the bar's cat lit
# while open, a fuzzel menu closed when it opens, the theme's colours, the pid file and its
# key, and the pointer's hot item apart from the keyboard's cursor (look(): what each is drawn
# with — no box under the pointer — and only the items that changed redrawn). Then the two
# other panels (--sound, --brightness): their layouts, what each choice runs, one panel at a
# time, each its own marker and poke on every way in and out, the pointer's enter and leave,
# and every open starting afresh (no cursor, nothing hot, no drag remembered). The module is
# loaded with a stand-in for gi (it is imported only to draw).
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
    def __init__(self): self.calls, self.t, self.pending, self.drawn, self.click = [], 100.0, [], [], None
    def clicked(self): return self.click
    def now(self): return self.t
    def redraw(self, *items): self.calls.append("redraw"); self.drawn.append([i.key for i in items] or "all")
    def show(self): self.calls.append("show")
    def hide(self): self.calls.append("hide")
    def light(self, mode, on): self.calls.append(f"light {mode} {'on' if on else 'off'}")
    def close_menu(self): self.calls.append("close menu")
    def run(self, argv, done): self.calls.append("run " + " ".join(argv)); self.pending.append(done)
    def launch(self, argv): self.calls.append("launch " + " ".join(argv))
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
    fresh(); p.toggle(mode); u.answer(state); u.calls.clear(); u.drawn.clear()
exec(sys.argv[3])
EOF
}

# ── the layout ─────────────────────────────────────────────────────────────────────────
case_ "the items, in order: two meters, the tiles (bluetooth and devices with an adapter), three keys"
eq "$(py 'fresh(); print(" ".join(i.key for i in p.items))')" \
  "brightness sound theme night vrr network bluetooth devices drives backup dnd wallpaper screenshot power"
eq "$(py 'fresh(STATE.replace("bluetooth\ton\n","").replace("devices\tnone\n","")); print(" ".join(i.key for i in p.items))')" \
  "brightness sound theme night vrr network drives backup dnd wallpaper screenshot power"
case_ "the size: 304 × 340 (2 px frame, 12 px margin, three 88 px tiles 6 px apart; no day line: the bar's)"
eq "$(py 'fresh(); print(*p.size)')" "304 340"
case_ "notices are as wide: one column under the bar's right end"
has "$(cat "$REPO/configs/home/.config/mako/config")" "width=$(py 'fresh(); print(p.size[0])')"
case_ "the tiles: three a row, 88 × 64, 6 px apart; the content 14 px from every edge"
eq "$(py 'fresh(); print(" ".join(f"{i.x},{i.y},{i.w},{i.h}" for i in p.items if i.kind == "tile"))')" \
  "14,77,88,64 108,77,88,64 202,77,88,64 14,147,88,64 108,147,88,64 202,147,88,64 14,217,88,64 108,217,88,64 202,217,88,64"
case_ "no adapter: seven tiles, three then two and two (never a lone tile), each row the full width"
eq "$(py 'fresh(STATE.replace("bluetooth\ton\n","").replace("devices\tnone\n","")); print(" ".join(f"{i.x}+{i.w}" for i in p.items if i.kind == "tile"))')" \
  "14+88 108+88 202+88 14+135 155+135 14+135 155+135"
eq "$(py 'print([kp.rows_of(n) for n in (9, 8, 7, 6, 4, 1)])')" "[[3, 3, 3], [3, 3, 2], [3, 2, 2], [3, 3], [2, 2], [1]]"
case_ "the keys at the foot: wallpaper, screenshot, power (an icon alone) — centred, 26 px each side"
eq "$(py 'fresh(); print(" ".join(f"{i.key}:{i.x}+{i.w}:{i.name or chr(45)}" for i in p.items if i.kind == "key"))')" \
  "wallpaper:40+94:wallpaper screenshot:140+94:screenshot power:240+24:-"
eq "$(py 'fresh(); k=[i for i in p.items if i.kind=="key"]; print(k[0].x - 14, 290 - (k[-1].x + k[-1].w))')" "26 26"
case_ "the meters first (14 px from the top, as every edge): the full width, 20 px rows 2 px apart; the rules 10 px from what they part"
eq "$(py 'fresh(); print(" ".join(f"{i.x},{i.y},{i.w},{i.h}" for i in p.items if i.kind == "meter"), p.rules)')" \
  "14,14,276,20 14,36,276,20 [66, 291]"

# ── the tiles' words and seals ─────────────────────────────────────────────────────────
t() { py "fresh($1); i = p.item('$2'); print(i.icon, i.kanji, i.name, '|', i.value, '|', 'stamped' if i.lit else 'plain')"; }
case_ "each tile: its icon, its kanji, its name, how it stands; the seal stamped while it is on"
eq "$(t '' theme)" "moon 夜 theme | dark | stamped"
eq "$(t 'STATE.replace("theme\tdark","theme\tlight")' theme)" "sun 昼 theme | light | stamped"
eq "$(t '' night)" "lantern 灯 night light | on | stamped"
eq "$(t 'STATE.replace("night\ton","night\toff")' night)" "lantern 灯 night light | off | plain"
eq "$(t '' vrr)" "window 滑 freesync | in games | stamped"
eq "$(t 'STATE.replace("vrr\tin games","vrr\toff")' vrr)" "window 滑 freesync | off | plain"
eq "$(t '' network)" "wifi 網 network | Home Net 5G | stamped"
eq "$(t 'STATE.replace("nettype\twifi","nettype\tethernet").replace("Home Net 5G","wired")' network)" "ethernet 網 network | wired | stamped"
eq "$(t 'STATE.replace("nettype\twifi","nettype\toffline").replace("Home Net 5G","offline")' network)" "offline 網 network | offline | plain"
eq "$(t '' bluetooth)" "bluetooth 青 bluetooth | on | stamped"
eq "$(t '' devices)" "headphones 対 devices | none | plain"
eq "$(t 'STATE.replace("devices\tnone","devices\tWH-1000XM5")' devices)" "headphones 対 devices | WH-1000XM5 | stamped"
eq "$(t '' drives)" "drive 盤 drives | KINGSTON 58G | stamped"
eq "$(t 'STATE.replace("KINGSTON 58G","none")' drives)" "drive 盤 drives | none | plain"
eq "$(t '' backup)" "archive 蔵 backup | 3 days ago | stamped"
eq "$(t 'STATE.replace("3 days ago","never")' backup)" "archive 蔵 backup | never | plain"
eq "$(t '' dnd)" "bell 静 dnd | off | plain"
eq "$(t 'STATE.replace("dnd\toff","dnd\ton")' dnd)" "bell_off 静 dnd | on | stamped"
case_ "the wallpaper's name: the tip of its key"
eq "$(py 'fresh(); print(p.item("wallpaper").tip)')" mishima-mist
case_ "the date: in kanji, then in English; 1…31 as kanji numbers"
eq "$(py 'print(hasattr(kp, "date_line"), hasattr(kp, "kanji_number"))')" "False False" "no day or weather line: the bar shows them, right above"
case_ "the icons by name, from icons.sh (none hard-coded)"
eq "$(py 'i = kp.icons(); print(len(i) > 40, sorted(k for k in ("moon","sun","lantern","window","wifi","ethernet","offline","bluetooth","drive","archive","bell","bell_off","picture","camera","power") if k not in i))')" "True []"

# ── opening and closing ───────────────────────────────────────────────────────────────
case_ "its key opens it: a fuzzel menu on screen goes first, it shows, the bar's cat lights, the state is read"
eq "$(py 'fresh(); p.toggle(); print(", ".join(u.calls))')" "close menu, show, light quick on, run kawa-quick --state"
case_ "its key again closes it, the cat dark again"
eq "$(py 'fresh(); p.toggle(); u.calls.clear(); u.t += 0.6; p.toggle(); print(", ".join(u.calls), p.visible)')" "hide, light quick off False"
case_ "its key held (dwl repeats it): a toggle within half a second of the last is ignored — no flicker"
eq "$(py 'fresh(); p.toggle(); u.calls.clear(); u.t += 0.1; p.toggle(); u.t += 0.3; p.toggle(); print(u.calls, p.visible)')" "[] True"
eq "$(py 'fresh(); p.toggle(); u.t += 0.6; p.toggle(); u.calls.clear(); u.t += 0.2; p.toggle(); print(u.calls, p.visible)')" "[] False" "held after closing: stays closed"
case_ "another menu's key (SIGUSR2): closed as chosen — its key then opens it at once"
eq "$(py 'fresh(); p.toggle(); u.calls.clear(); p.close("chosen"); u.t += 0.1; p.toggle(); print(p.visible)')" True
has "$(cat "$REPO/bin/kawa-panel")" 'signal.SIGUSR2, lambda: panel.close("chosen")'
case_ "its signals through GLibUnix.signal_add (GLib.unix_signal_add is deprecated: a warning in kawa-panel.log at every start)"
lacks "$(cat "$REPO/bin/kawa-panel")" "GLib.unix_signal_add"; has "$(cat "$REPO/bin/kawa-panel")" 'gi.require_version("GLibUnix", "2.0")'
eq "$(grep -c 'GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, ' "$REPO/bin/kawa-panel")" 3
case_ "the bar's cat: lit by a marker of its own (a dropdown's, kawa-drop.open, is kawa-menu's), poked with SIGRTMIN+15"
eq "$(py 'import os; print(os.path.basename(kp.MARK))')" kawa-panel.open
lacks "$(grep -v '^ *#' "$REPO/bin/kawa-panel")" 'kawa-drop.open'
eq "$(py 'print(kp.POKE["quick"])')" 15
has "$(cat "$REPO/bin/kawa-panel")" 'self.launch(["kawa-dwlstatus", "--poke", str(POKE[mode])])'
case_ "the meters: no number beside the squares (the bar shows both levels) — words only when there is no level"
lacks "$(cat "$REPO/bin/kawa-panel")" 'it.key != "sound"'
has "$(python3 -I "$REPO/bin/kawa-panel" --help)" "their levels are the"
case_ "Esc closes it"
eq "$(py 'fresh(); p.toggle(); u.calls.clear(); p.key("Escape"); print(", ".join(u.calls))')" "hide, light quick off"
case_ "a click outside closes it — and the click on the cat that did so does not open it again at once"
eq "$(py 'fresh(); p.toggle(); p.close("lost"); u.t += 0.3; p.toggle(); print(p.visible)')" False
eq "$(py 'fresh(); p.toggle(); p.close("lost"); u.t += 0.7; p.toggle(); print(p.visible)')" True "its key later opens it"
eq "$(py 'fresh(); p.toggle(); p.close("chosen"); u.t += 0.1; p.toggle(); print(p.visible)')" True "closed otherwise: its key opens it at once"
case_ "closing what is closed does nothing"
eq "$(py 'fresh(); p.close("lost"); print(u.calls, p.lost_at)')" "[] -1000000000.0"

# ── doing ─────────────────────────────────────────────────────────────────────────────
case_ "a switch (theme, night light, freesync, bluetooth, dnd): done in place, the panel open, the state read after"
for k in theme night vrr bluetooth dnd; do
  eq "$(py "fresh(); p.toggle(); u.answer(STATE); u.calls.clear(); p.activate('$k'); u.answer(); print(', '.join(u.calls), p.visible)")" \
    "run kawa-quick --do $k, run kawa-quick --state True" "$k"
done
case_ "the others: the panel closes, then their own menu or window"
for k in network devices drives backup wallpaper screenshot power; do
  eq "$(py "fresh(); p.toggle(); u.calls.clear(); p.activate('$k'); print(', '.join(u.calls))")" \
    "hide, light quick off, launch kawa-quick --do $k" "$k"
done
case_ "Enter on the sound meter: the sound panel (outputs, inputs) in its place; on brightness: nothing more"
eq "$(py 'fresh(); p.toggle(); u.calls.clear(); p.focus = "sound"; p.key("Return"); print(", ".join(u.calls)); print(p.mode, p.visible, p.focus)')" \
  "$(printf '%s\n' "close menu, hide, light quick off, show, light sound on, run kawa-quick --state sound" "sound True None")"
eq "$(py 'fresh(); p.toggle(); u.calls.clear(); p.focus = "brightness"; p.key("Return"); print(u.calls)')" "[]"

# ── the keys ──────────────────────────────────────────────────────────────────────────
nav() { py "fresh(); p.focus = '$1'; [p.key(k) for k in '$2'.split()]; print(p.focus)"; }
case_ "arrows (and h j k l): along a row, and up and down to the nearest below or above"
eq "$(nav theme 'Right Right Right')" vrr "the end of a row stays"
eq "$(nav theme 'Down Down')" drives; eq "$(nav night 'Down')" bluetooth; eq "$(nav vrr 'j j j')" power
eq "$(nav theme 'Up')" sound; eq "$(nav sound 'k k')" brightness; eq "$(nav brightness 'Up')" brightness
eq "$(nav drives 'Down')" wallpaper "the foot: the key nearest below"; eq "$(nav dnd 'Down')" power
eq "$(nav screenshot 'Up')" backup; eq "$(nav sound 'Down')" night "from a meter: the middle tile"
case_ "Tab and Shift+Tab: every item in turn, round"
eq "$(nav power 'Tab')" brightness; eq "$(nav brightness 'ISO_Left_Tab')" power
case_ "← → (h l) on a meter: its level by 5, at once and then set"
eq "$(py 'fresh(); p.focus = "sound"; p.key("Right"); print(p.state["sound"], u.calls[-1])')" "65% run kawa-quick --do volume 65"
eq "$(py 'fresh(); p.focus = "brightness"; p.key("h"); print(p.state["brightness"], u.calls[-1])')" "65% run kawa-quick --do brightness 65"
eq "$(py 'fresh(); p.focus = "brightness"; [p.key("Right") for _ in range(9)]; print(p.state["brightness"])')" 100% "no more than 100"
case_ "a meter without a level (no DDC/CI, muted, no output): ← → do nothing"
eq "$(py 'fresh(STATE.replace("70%","no DDC/CI")); p.focus = "brightness"; p.key("Right"); print(p.state["brightness"], u.calls)')" "no DDC/CI []"

# ── the mouse ─────────────────────────────────────────────────────────────────────────
case_ "the pointer over an item makes it the hot one — no cursor shown for it; a click does it, and shows none"
eq "$(py 'fresh(); p.hover(150, 116); print(p.hot, p.focus)')" "night None"
eq "$(py 'fresh(); p.hover(150, 116); p.hover(10, 116); print(p.hot, p.focus)')" "None None" "over the frame or a gap: none"
eq "$(py 'fresh(); p.hover(150, 116); p.press(150, 116); print(p.hot, p.focus)')" "night None"
eq "$(py 'fresh(); p.press(150, 46); print(p.focus)')" None "a click on a meter: no cursor (none to remember)"
eq "$(py 'fresh(); p.focus = "theme"; p.press(150, 46); print(p.focus)')" sound "… but a cursor the keys showed follows the click"
eq "$(py 'fresh(); p.toggle(); u.calls.clear(); p.press(60, 316); print(", ".join(u.calls))')" "redraw, hide, light quick off, launch kawa-quick --do wallpaper"
eq "$(py 'fresh(); p.focus = "theme"; p.hover(150, 116); p.key("Right"); print(p.hot, p.focus)')" "night night" "the keys move the cursor from where it is, not from the pointer's"
eq "$(py 'fresh(); p.focus = "theme"; p.hover(150, 186); p.key("Down"); print(p.hot, p.focus)')" "bluetooth network"
case_ "the pointer leaving the panel: nothing hot, only that item redrawn; the cursor stays"
eq "$(py 'fresh(); p.focus = "theme"; p.hover(150, 116); u.drawn.clear(); p.leave(); print(p.hot, p.focus, u.drawn)')" "None theme [['night']]"
eq "$(py 'fresh(); u.drawn.clear(); p.leave(); print(u.drawn)')" "[]" "nothing was hot: nothing redrawn"
has "$(cat "$REPO/bin/kawa-panel")" 'win.connect("leave-notify-event", on_leave)'
has "$(cat "$REPO/bin/kawa-panel")" 'Gdk.EventMask.LEAVE_NOTIFY_MASK'
case_ "opened again: nothing hot until the pointer says where it is (a new window); a state read keeps it while it is there"
eq "$(py 'fresh(); p.toggle(); p.hover(150, 116); p.close("chosen"); p.toggle(); print(p.hot)')" None
eq "$(py 'fresh(); p.hover(150, 116); p.refresh(); u.answer(STATE); print(p.hot)')" night
eq "$(py 'fresh(); p.hover(150, 186); p.refresh(); u.answer(STATE.replace("bluetooth\ton\n","").replace("devices\tnone\n","")); print(p.hot)')" None "its tile gone: none"
case_ "a drag: the meter follows, the hot one does not move off it"
eq "$(py 'fresh(); p.hover(112, 24); p.press(112, 24); p.hover(150, 116, dragging=True); print(p.hot, p.focus)')" "brightness None"
eq "$(py 'fresh(); p.press(5, 5); print(u.calls)')" "[]" "on the frame: nothing"
case_ "a click on a meter's squares: the level there, dragged: it follows"
eq "$(py 'fresh(); p.press(110 + 71, 24); print(p.state["brightness"])')" 54% "the gap after the 6th square: the top of the six-square levels"
eq "$(py 'fresh(); p.press(110 + 60, 24); print(p.state["brightness"])')" 46% "the 6th square's first pixel: the bottom of them"
eq "$(py 'fresh(); p.press(112, 46); p.hover(252, 46, dragging=True); print(p.state["sound"])')" 100%
eq "$(py 'fresh(); p.press(112, 46); p.release(); p.hover(252, 46, dragging=True); print(p.state["sound"])')" 3% "let go: no more"
eq "$(py 'fresh(); p.press(105, 24); print(p.state["brightness"])')" 0% "just left of the first square: 0"

case_ "the squares and the level, one rule both ways: the lit edge is where the pointer is"
eq "$(py '
bad = []
for o in range(-20, 170):
    want = 0 if o < 0 else min(12, o // 12 + 1)
    if kp.lit_of(kp.level_at(o)) != want: bad.append(o)
print(bad)')" "[]" "every pixel lights the squares up to the one under it"
eq "$(py 'v = [kp.level_at(o) for o in range(-20, 170)]; print(all(a <= b for a, b in zip(v, v[1:])), max(b - a for a, b in zip(v, v[1:])), v[0], v[-1], kp.level_at(-1), kp.level_at(0), kp.level_at(139), kp.level_at(140))')" \
  "True 1 0 100 0 1 99 100" "even (at most 1 % a pixel), never back; the ends 0 and 100 exactly"
eq "$(py 'print([kp.lit_of(v) for v in (0, 1, 4, 12, 13, 50, 95, 96, 100)])')" "[0, 1, 1, 1, 2, 6, 11, 12, 12]" "any level above 0 lights a square; only 100's neighbours light all"
eq "$(py 'print([kp.snap(v, d) for v, d in ((62, 5), (62, -5), (60, 5), (60, -5), (0, -5), (98, 5), (100, 5))])')" \
  "[65, 60, 65, 55, 0, 100, 100]" "keys and the wheel: to the next multiple of 5"

case_ "a drag: every motion sets the level under the pointer at once, only that meter redrawn, one set at a time, the last one sent"
eq "$(py '
fresh(); p.press(110 + 30, 24); u.drawn.clear()
shown = []
for x in range(140, 300, 7):
    p.hover(x, 24, dragging=True); shown.append(p.state["brightness"] == f"{kp.level_at(x - 110)}%")
print(all(shown), all(d == ["brightness"] for d in u.drawn), sum(c.startswith("run kawa-quick --do brightness") for c in u.calls))
u.answer(); print(u.calls[-1]); p.release(); u.answer(); print(u.calls[-1])')" \
  "$(printf '%s\n' 'True True 1' 'run kawa-quick --do brightness 100' 'run kawa-quick --state')"
eq "$(py 'fresh(); p.press(110 + 30, 24); n = len(u.calls); p.hover(110 + 30, 24, dragging=True); p.hover(110 + 30.5, 24, dragging=True); print(len(u.calls) - n)')" 0 "the same level again: nothing redrawn, nothing sent"
eq "$(py 'fresh(); p.press(112, 24); p.hover(-50, 24, dragging=True); a = p.state["brightness"]; p.hover(900, 24, dragging=True); print(a, p.state["brightness"])')" "0% 100%" "dragged past either end: that end"

case_ "no snapping back: a state read that comes back mid-drag, or was started before the last change, leaves the meter as set"
eq "$(py '
fresh(); p.refresh()                                  # (a read already under way: the open)
p.press(110 + 100, 24); v = p.state["brightness"]
u.pending.pop(1)(0, STATE)                            # (it comes back with the old 70 %)
print(v, p.state["brightness"])')" "74% 74%"
eq "$(py '
fresh(); p.press(110 + 100, 24); p.release(); p.refresh()
u.answer()                                            # (the level set: confirmed)
u.answer(STATE)                                       # (the read started before that: 70 %)
print(p.state["brightness"])')" 74% "a read started while it was being set: ignored"
eq "$(py '
fresh(); p.press(110 + 100, 24); p.release(); u.answer()
u.answer(STATE.replace("70%", "74%").replace("night\ton", "night\toff"))
print(p.state["brightness"], p.state["night"], p.held("brightness"))')" "74% off False" "a read after it: taken, and the meter free again"
eq "$(py '
fresh(); p.refresh(); p.press(110 + 100, 24); p.release(); p.refresh(); u.answer(STATE); u.answer(); u.answer(STATE); u.answer(STATE)
print(p.state["brightness"], p.held("brightness"))')" "70% False" "reads that started while it was set are ignored, but only those: the meter is not held for good"
eq "$(py '
fresh(); p.press(110 + 100, 24); p.release(); u.answer(); u.answer(STATE)
print(p.state["brightness"])')" 70% "… so a level the machine did not take shows as it is"

case_ "the wheel and a touchpad: a step per notch; a touchpad's small scrolls summed, not a step each"
eq "$(py 'fresh(); p.scroll_by(150, 24, -1.0); a = p.state["brightness"]; [p.scroll_by(150, 24, -0.25) for _ in range(3)]; b = p.state["brightness"]; p.scroll_by(150, 24, -0.25); print(a, b, p.state["brightness"])')" "75% 75% 80%"
eq "$(py 'fresh(); p.scroll_by(150, 24, 0.5); p.scroll_by(150, 46, 0.5); print(p.state["brightness"], p.state["sound"])')" "70% 62%" "half a step on one meter does not add to the other"

case_ "moving between items redraws only those that changed: the one left and the one entered"
eq "$(py 'fresh(); u.drawn.clear(); p.hover(150, 116); print(u.drawn)')" "[['night']]" "the first: only it (the cursor on theme untouched)"
eq "$(py 'fresh(); p.hover(150, 116); u.drawn.clear(); p.hover(250, 116); print(u.drawn)')" "[['night', 'vrr']]"
eq "$(py 'fresh(); p.hover(150, 116); u.drawn.clear(); p.hover(151, 117); p.hover(160, 130); print(u.drawn)')" "[]" "within the same item: nothing"
eq "$(py 'fresh(); p.hover(150, 116); u.drawn.clear(); p.hover(10, 116); print(u.drawn)')" "[['night']]" "onto a gap: the one left"
eq "$(py 'fresh(); p.focus = "theme"; u.drawn.clear(); p.key("Right"); print(u.drawn)')" "[['theme', 'night']]" "the keys: the cursor's two"

case_ "how each item is drawn: the cursor filled, the pointer's only its glyph and name lit, both: drawn as the cursor"
lk() { py "fresh(); i = p.item('$1'); l = kp.look(i, $2, $3); print(l['fill'], l['frame'], l['glyph'], l['label'], l['value'], l['on_fill'])"; }
for k in night wallpaper power; do
  [[ $k == night ]] && label=strong || label=text
  eq "$(lk $k False False)" "key edge text $label muted False" "$k at rest: its key fill and edge frame"
  eq "$(lk $k False True)" "key edge accent_text accent_text muted False" "$k under the pointer: the same fill and frame, no box — glyph and name accent_text"
  eq "$(lk $k True False)" "accent None text_on_accent text_on_accent text_on_accent True" "$k the cursor: filled in vermilion"
  eq "$(lk $k True True)" "accent None text_on_accent text_on_accent text_on_accent True" "$k the cursor and under the pointer: drawn as the cursor"
done
eq "$(lk devices False False)" "key edge text text muted False" "a tile that is off: its name in text"
eq "$(lk sound False False)" "None None accent_text text muted False" "a meter at rest: nothing behind it"
eq "$(lk sound False True)" "None None accent_text accent_text muted False" "a meter under the pointer: still nothing behind it, its name accent_text"
eq "$(lk sound True False)" "accent None text_on_accent text_on_accent text_on_accent True"
eq "$(lk sound True True)" "accent None text_on_accent text_on_accent text_on_accent True"
eq "$(py 'fresh(); print(sorted({kp.look(i, False, True)["fill"] == kp.look(i, False, False)["fill"] and kp.look(i, False, True)["frame"] == kp.look(i, False, False)["frame"] and kp.look(i, False, True)["on_fill"] is False for i in p.items}))')" "[True]" \
  "no item under the pointer gets a fill, a frame or the vermilion seal it does not have at rest"
case_ "draw() takes every colour from look(): the cursor and the pointer, nothing else decides"
src=$(sed -n '/    def draw(widget, cr):/,/^    def on_key/p' "$REPO/bin/kawa-panel")
has "$src" 'lk = look(it, it.key == panel.focus, it.key == panel.hot)'
lacks "$src" '"accent" if'; lacks "$src" 'text_on_accent" if on else "text'
case_ "no GTK widget with a hover look: the window holds one drawing area, painted whole; no transitions"
has "$(cat "$REPO/bin/kawa-panel")" '* { transition: none; animation: none; }'
eq "$(grep -oE 'Gtk\.(Button|EventBox|ToggleButton|Scale|Switch|Label|Box|Grid|ListBox|MenuItem|Image)\b' "$REPO/bin/kawa-panel" | sort -u)" "" "no widgets but the window and its drawing area"
has "$src" 'box(cr, 0, 0, W, H, "surface")'
case_ "a meter set fast: one wpctl at a time, the last level asked the one that stays"
eq "$(py 'fresh(); [p.step("sound", 5) for _ in range(4)]; print(sum(c.startswith("run kawa-quick --do volume") for c in u.calls)); u.answer(); print(u.calls[-1]); u.answer(); print(u.calls[-1])')" \
  "$(printf '%s\n' 1 'run kawa-quick --do volume 80' 'run kawa-quick --state')"
case_ "a level being set is shown as asked when the state comes back meanwhile"
eq "$(py 'fresh(); p.step("sound", 5); p.refresh(); u.pending.pop(1)(0, STATE); print(p.state["sound"])')" 65%
case_ "the wheel over a meter: ±5"
eq "$(py 'fresh(); p.wheel(150, 24, True); p.wheel(150, 46, False); print(p.state["brightness"], p.state["sound"])')" "75% 60%" "(62 % down: 60, the next multiple of 5)"
eq "$(py 'fresh(); p.wheel(150, 116, True); print(u.calls)')" "[]" "over a tile: nothing"

# ── the state ─────────────────────────────────────────────────────────────────────────
case_ "one reading at a time: asked again meanwhile, read once more after"
eq "$(py 'fresh(); p.refresh(); p.refresh(); p.refresh(); print(sum(c == "run kawa-quick --state" for c in u.calls)); u.answer(STATE); print(sum(c == "run kawa-quick --state" for c in u.calls))')" "$(printf '1\n2')"
case_ "kawa-quick failing: the last state stays"
eq "$(py 'fresh(); p.refresh(); u.answer("", 1); print(p.state["night"])')" on
case_ "the colours: the theme's panel.conf, every name the drawing uses"
for m in dark light; do
  eq "$(py "c = kp.colours('$REPO/configs/home/.config/fedokawaii/themes/$m/panel.conf'); print(sorted(c) == sorted(['surface','key','edge','edge2','faint','muted','text','strong','accent','accent_text','accent_lo','text_on_accent','asagi']), all(0 <= v <= 1 for t in c.values() for v in t))")" "True True" "$m"
done
used=$(grep -oE '"(surface|key|edge|edge2|faint|muted|text|strong|accent|accent_text|accent_lo|text_on_accent|asagi|[a-z_]+)"' "$REPO/bin/kawa-panel" | sort -u | tr -d '"' | tr '\n' ' ')
for n in surface key edge edge2 faint muted text strong accent accent_text accent_lo text_on_accent asagi; do has " $used" " $n " "$n is drawn with"; done

# ── every open afresh: nothing remembered ──────────────────────────────────────────────
case_ "a meter dragged, closed, opened again: no cursor, nothing hot, no drag — nothing highlighted"
eq "$(py 'fresh(); p.toggle(); p.hover(170, 24); p.press(170, 24); p.hover(200, 24, dragging=True); p.close("chosen"); p.toggle(); print(p.focus, p.hot, p.dragging, p.pointer)')" "None None None None"
eq "$(py 'fresh(); p.toggle(); p.focus = "brightness"; p.press(170, 24); p.close("lost"); u.t += 1; p.toggle(); print(p.focus, p.hot, p.dragging)')" "None None None" "… also a cursor the keys had shown, and closed by a click outside"
eq "$(py 'fresh(); p.toggle(); p.press(170, 24); p.close("chosen"); p.toggle(); i = p.item("brightness"); print(sorted({x for x in kp.look(i, i.key == p.focus, i.key == p.hot).values() if x}))')" \
  "['accent_text', 'muted', 'text']" "the brightness meter drawn as at rest: no vermilion fill, its name not lit"
eq "$(py 'fresh(); p.toggle(); p.press(170, 24); p.close("chosen"); p.toggle(); n = len(u.calls); p.hover(150, 116, dragging=True); print([c for c in u.calls[n:] if "--do" in c], p.hot)')" "[] night" \
  "a motion with the button held after reopening: no drag carried over"
case_ "no cursor until a key asks: the first arrow, Tab or Enter puts it on the first item (and does nothing else)"
for k in Down Up Left Right Tab Return space j l; do
  eq "$(py "fresh(); p.toggle(); u.calls.clear(); p.key('$k'); print(p.focus, p.state['brightness'], [c for c in u.calls if c.startswith('run')])")" "brightness 70% []" "$k"
done
eq "$(py 'fresh(); p.toggle(); p.key("Down"); p.key("Down"); print(p.focus)')" sound "then the keys go on from there"
eq "$(py 'fresh(); p.toggle(); p.key("Escape"); print(p.visible)')" False "Esc closes it, cursor or not"
eq "$(py 'fresh(); p.toggle(); p.key("F5"); print(p.focus)')" None "another key: nothing"
case_ "every open: the cursor gone, even when the keys showed it"
eq "$(py 'fresh(); p.toggle(); p.key("Down"); p.key("Down"); p.close("chosen"); p.toggle(); print(p.focus)')" None

# ── the pointer: in, out, over a panel that changes ────────────────────────────────────
case_ "the pointer coming in (enter-notify): what is under it hot at once, before any motion"
eq "$(py 'fresh(); p.toggle(); u.drawn.clear(); p.enter(150, 116); print(p.hot, u.drawn)')" "night [['night']]"
eq "$(py 'fresh(); p.toggle(); p.enter(5, 5); print(p.hot)')" None "on the frame: nothing"
eq "$(py 'fresh(); p.toggle(); p.press(112, 24); p.enter(150, 116); print(p.hot)')" brightness "during a drag the hot one stays"
case_ "it opens under the pointer: the item there is hot as the window says the pointer is in"
eq "$(py 'fresh(); p.toggle(); p.enter(60, 316); print(p.hot)')" wallpaper
case_ "the pointer leaving: only a real leave clears it — not one into a child's window, not a grab's crossing"
eq "$(py 'print([kp.real_leave(m, d) for m, d in (("normal", "nonlinear"), ("normal", "ancestor"), ("ungrab", "nonlinear"), ("normal", "inferior"), ("grab", "nonlinear"), ("gtk-grab", "ancestor"), ("state-changed", "nonlinear"))])')" \
  "[True, True, True, False, False, False, False]"
has "$(cat "$REPO/bin/kawa-panel")" 'if real_leave(ev.mode.value_nick, ev.detail.value_nick):'
has "$(cat "$REPO/bin/kawa-panel")" 'win.connect("enter-notify-event", on_enter)'
has "$(cat "$REPO/bin/kawa-panel")" 'Gdk.EventMask.ENTER_NOTIFY_MASK'
case_ "a click acts on the item under the pointer — hot at once, even with no motion or enter before it"
eq "$(py 'fresh(); p.toggle(); u.calls.clear(); p.press(150, 116); print(p.hot, u.calls[-2:])')" "night ['redraw', 'run kawa-quick --do night']"
eq "$(py 'fresh(); p.toggle(); p.hover(150, 116); u.calls.clear(); p.press(250, 116); print(p.hot, u.calls[-1])')" "vrr run kawa-quick --do vrr" "a stale hot one does not matter: the click's place does"
case_ "let go: the hot one is what is under the pointer then (a drag may end anywhere)"
eq "$(py 'fresh(); p.toggle(); p.press(170, 24); p.hover(150, 116, dragging=True); p.release(150, 116); print(p.hot, p.dragging)')" "night None"
eq "$(py 'fresh(); p.toggle(); p.press(170, 24); p.release(400, 24); print(p.hot)')" None "let go outside: nothing"
case_ "the panel changing under a still pointer (a state read): the hot one is what is under it now"
eq "$(py 'fresh(); p.toggle(); p.enter(120, 186); u.answer(STATE.replace("bluetooth\ton\n","").replace("devices\tnone\n","")); print(p.hot)')" network
eq "$(py 'opened("sound", SOUND); p.enter(150, 168); print(p.hot); p.refresh(); u.answer(SOUND.replace("input\t90", "output\t91\t0\tUSB DAC\t\t\t\t\t\ninput\t90")); print(p.hot)')" \
  "$(printf '%s\n' out:73 out:73)" "a device added below: the same row still under it"
eq "$(py 'opened("sound", SOUND); p.enter(150, 146); print(p.hot); p.refresh(); u.answer("\n".join(l for l in SOUND.split("\n") if not l.startswith("output\t62"))); print(p.hot)')" \
  "$(printf '%s\n' out:62 out:73)" "the row under it gone: the one that took its place"
case_ "the pointer works whether or not the panel has the keyboard: motion, enter and clicks never ask for it"
lacks "$(sed -n '/^class Panel/,/^def mark/p' "$REPO/bin/kawa-panel")" 'has_focus'
case_ "the keyboard: the panel's own while open (exclusive: dwl treats it as a menu — a click outside takes it, closing it)"
has "$(cat "$REPO/bin/kawa-panel")" 'GtkLayerShell.set_keyboard_mode(win, GtkLayerShell.KeyboardMode.EXCLUSIVE)'
case_ "only the window on screen closes it: the one just replaced losing the keyboard a moment later does not"
has "$(cat "$REPO/bin/kawa-panel")" 'win.connect("focus-out-event", lambda w, ev: (w is view["win"] and panel.close("lost")) or False)'
has "$(cat "$REPO/bin/kawa-panel")" 'win.connect("unmap-event", lambda w, ev: (w is view["win"] and panel.close("lost")) or False)'

# ── the sound panel (--sound) ──────────────────────────────────────────────────────────
case_ "the sound panel: 音 sound (the volume, mute, mixer), 出 output and 入 input (a row each, the default ticked), mute microphone"
eq "$(py 'opened("sound", SOUND); print(" ".join(i.key for i in p.items)); print(p.heads)')" \
  "$(printf '%s\n' "sound mute mixer out:62 out:73 in:67 in:90 mic" "[('音', 'sound', 14, 14), ('出', 'output', 14, 111), ('入', 'input', 14, 200)]")"
eq "$(py 'opened("sound", SOUND); print(" ".join(f"{i.key}:{i.kind}:{i.x},{i.y},{i.w},{i.h}" for i in p.items), p.size)')" \
  "sound:meter:14,43,276,20 mute:key:14,69,135,24 mixer:key:155,69,135,24 out:62:row:14,140,276,20 out:73:row:14,162,276,20 in:67:row:14,229,276,20 in:90:row:14,251,276,20 mic:key:14,277,276,24 (304, 315)" \
  "quick settings' width, grid and parts: 14 px margins, the seals 23 px, 6 px under each, 18 px between parts"
eq "$(py 'opened("sound", SOUND); print(" | ".join(f"{i.icon} {i.name} {i.lit}" for i in p.items if i.kind == "row"))')" \
  "box_on line out · analog True | box_off LG ULTRAGEAR · HDMI False | box_on rear mic True | box_off front mic False"
eq "$(py 'opened("sound", SOUND); print(p.item("mute").icon, p.item("mute").name, "|", p.item("mixer").icon, p.item("mixer").name, "|", p.item("mic").icon, p.item("mic").name)')" \
  "speaker_off mute | sliders mixer | mic_off mute microphone" "as kawa-audio said them: each what it will do"
eq "$(py 'opened("sound", SOUND.replace("muted\toff", "muted\ton").replace("mic\ton", "mic\tmuted")); print(p.item("mute").icon, p.item("mute").name, p.item("sound").muted, p.item("sound").value, "|", p.item("mic").icon, p.item("mic").name)')" \
  "speaker unmute True 62% | mic unmute microphone" "muted: unmute (the level kept, its squares hollow), the microphone too"
eq "$(py 'opened("sound", "sound\tno output\nmuted\toff\nmic\tnone\n"); print(" ".join(i.key for i in p.items), p.nones, p.size)')" \
  "sound mute mixer [(14, 140), (14, 207)] (304, 241)" "no devices: each list says none; no input, no microphone to mute"
case_ "the sound meter's icon is the bar's: no wave at 0, one to 25 %, two to 50, three to 75, four above; crossed out muted"
eq "$(py 'print(*[kp.vol_icon(v, False) for v in (0, 1, 25, 26, 50, 51, 75, 76, 100, 130)], kp.vol_icon(40, True), kp.vol_icon(None, False))')" \
  "vol_0 vol_1 vol_1 vol_2 vol_2 vol_3 vol_3 vol_4 vol_4 vol_4 vol_mute vol_0"
eq "$(py 'i = kp.icons(); print(all(f"vol_{n}" in i for n in (0, 1, 2, 3, 4, "mute")), all(k in i for k in ("speaker", "speaker_off", "sliders", "mic", "mic_off", "box_on", "box_off")))')" "True True"
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
case_ "every short name fits its row whole (41 columns of the 12 px font: the row's 246 px) — no …"
eq "$(py 's = kp.parse_sound(SOUND); print(max(len(n) for _, _, n in s["outputs"] + s["inputs"]) <= 41)')" True
case_ "a row's look: the one in use in strong ink, the others' box quiet; the pointer lights glyph and name, the cursor fills it"
eq "$(py 'opened("sound", SOUND); a, b = p.item("out:62"), p.item("out:73"); print(*[" ".join(str(v) for v in kp.look(i, f, h).values()) for i, f, h in ((a, False, False), (b, False, False), (b, False, True), (b, True, False))], sep=" | ")')" \
  "None None strong strong muted False text | None None muted text muted False text | None None accent_text accent_text muted False text | accent None text_on_accent text_on_accent text_on_accent True text_on_accent"
case_ "another output picked (a click or Enter): the default (kawa-quick --do output ID: wpctl set-default), the panel stays and reads again"
eq "$(py 'opened("sound", SOUND); p.press(150, 168); print(u.calls[-1]); u.answer(); print(u.calls[-1], p.visible)')" \
  "$(printf '%s\n' 'run kawa-quick --do output 73' 'run kawa-quick --state sound True')"
eq "$(py 'opened("sound", SOUND); p.press(150, 256); print(u.calls[-1])')" "run kawa-quick --do input 90" "an input"
eq "$(py 'opened("sound", SOUND); p.focus = "out:73"; p.key("Return"); print(u.calls[-1])')" "run kawa-quick --do output 73" "Enter"
eq "$(py 'opened("sound", SOUND); p.press(150, 146); p.press(150, 234); print([c for c in u.calls if c.startswith("run")])')" "[]" "the one in use: nothing to change"
case_ "mute and mute microphone: switched over, the panel stays; mixer: the panel closes, wiremix opens (kawa-quick --do mixer)"
eq "$(py 'opened("sound", SOUND); p.press(40, 80); print(u.calls[-1]); u.answer(); print(u.calls[-1], p.visible)')" \
  "$(printf '%s\n' 'run kawa-quick --do mute' 'run kawa-quick --state sound True')"
eq "$(py 'opened("sound", SOUND); p.press(150, 290); print(u.calls[-1], p.visible)')" "run kawa-quick --do micmute True"
eq "$(py 'opened("sound", SOUND); p.press(200, 80); print(", ".join(u.calls[-3:]), p.visible)')" "hide, light sound off, launch kawa-quick --do mixer False"
case_ "the volume: dragged, clicked, the wheel, ← →, as quick settings' (kawa-quick --do volume N), one at a time"
eq "$(py 'opened("sound", SOUND); p.press(110 + 71, 53); print(p.state["sound"], u.calls[-1])')" "54% run kawa-quick --do volume 54"
eq "$(py 'opened("sound", SOUND); p.press(112, 53); p.hover(252, 53, dragging=True); p.hover(200, 53, dragging=True); print(sum(c.startswith("run kawa-quick --do volume") for c in u.calls)); u.answer(); print(u.calls[-1])')" \
  "$(printf '%s\n' 1 'run kawa-quick --do volume 67')"
eq "$(py 'opened("sound", SOUND); p.wheel(150, 53, True); print(p.state["sound"])')" 65%
eq "$(py 'opened("sound", SOUND); p.key("Down"); p.key("Right"); print(p.focus, p.state["sound"])')" "sound 65%"
case_ "muted: a level set unmutes (kawa-quick --do volume does) — even the same level; the squares solid again at once"
eq "$(py 'opened("sound", SOUND.replace("muted\toff", "muted\ton")); p.press(110 + 83, 53); print(p.state["sound"], p.state["muted"], p.item("sound").muted, u.calls[-1])')" \
  "62% off False run kawa-quick --do volume 62"
case_ "no snapping back: a read of the sound panel started before a change leaves the volume (and its unmute) as set"
eq "$(py 'opened("sound", SOUND.replace("muted\toff", "muted\ton")); p.press(110 + 100, 53); p.release(); p.refresh(); u.answer(); u.answer(SOUND.replace("muted\toff", "muted\ton")); print(p.state["sound"], p.state["muted"])')" "74% off"
case_ "a level set in one panel is every panel's: quick settings shows it too, and its older read does not undo it"
eq "$(py 'opened("sound", SOUND); p.refresh("quick"); p.press(110 + 100, 53); print(p.states["quick"]["sound"]); u.answer(STATE); print(p.states["quick"]["sound"])')" \
  "$(printf '%s\n' 74% 74%)"
eq "$(py 'opened("brightness", "brightness\t70%\n"); p.key("Right"); print(p.states["quick"]["brightness"], p.state["brightness"])')" "75% 75%"
case_ "the arrows: up and down through the rows (two keys in one), left and right along the keys"
eq "$(py 'opened("sound", SOUND); p.focus = "sound"; [p.key(k) for k in ("Down", "Right", "Down", "Down", "Down", "Down", "Down")]; print(p.focus)')" mic
eq "$(py 'opened("sound", SOUND); p.focus = "mic"; p.key("Up"); p.key("Up"); print(p.focus)')" in:67

# ── the brightness slider (--brightness) ───────────────────────────────────────────────
case_ "the brightness slider: the meter alone, as quick settings' (the same row, the same squares)"
eq "$(py 'opened("brightness", "brightness\t70%\n"); print([(i.key, i.kind, i.kanji, i.name, i.x, i.y, i.w, i.h) for i in p.items], p.size, p.squares_x(p.items[0]))')" \
  "[('brightness', 'meter', '明', 'brightness', 14, 14, 276, 20)] (304, 48) 110"
eq "$(py 'fresh(); print(p.squares_x(p.item("brightness")))')" 110 "the squares where quick settings has them"
case_ "its keys: ← → (h l) change it from the first press (it is all there is) — no cursor drawn for that; a click, a drag, the wheel"
eq "$(py 'opened("brightness", "brightness\t70%\n"); p.key("Right"); p.key("h"); print(p.focus, p.state["brightness"], [c for c in u.calls if c.startswith("run")][0])')" \
  "None 70% run kawa-quick --do brightness 75"
eq "$(py 'opened("brightness", "brightness\t70%\n"); p.press(110 + 71, 24); print(p.state["brightness"])')" 54%
eq "$(py 'opened("brightness", "brightness\t70%\n"); p.wheel(150, 24, False); print(p.state["brightness"])')" 65%
eq "$(py 'opened("brightness", "brightness\tno DDC/CI\n"); p.key("Right"); print(p.state["brightness"], u.calls)')" "no DDC/CI []" "no DDC/CI: the words, the keys do nothing"
eq "$(py 'opened("brightness", "brightness\t70%\n"); p.key("Tab"); print(p.focus)')" brightness "Tab shows the cursor on it"

# ── one panel at a time, each its own key, marker and poke ─────────────────────────────
case_ "each mode reads its own state (kawa-quick --state, --state sound, --state brightness)"
for m in sound brightness; do
  eq "$(py "fresh(); p.toggle('$m'); print(u.calls[-1])")" "run kawa-quick --state $m" "$m"
done
case_ "--sound, --brightness: open, and the same again closes it"
for m in sound brightness; do
  eq "$(py "fresh(); p.toggle('$m'); print(', '.join(u.calls), p.visible, p.mode); u.calls.clear(); u.t += 0.6; p.toggle('$m'); print(', '.join(u.calls), p.visible)")" \
    "$(printf '%s\n' "close menu, show, light $m on, run kawa-quick --state $m True $m" "hide, light $m off False")" "$m"
done
case_ "opening one closes the one open: never two (quick settings, sound, brightness, in any order)"
eq "$(py 'fresh(); p.toggle(); u.calls.clear(); p.toggle("sound"); print(", ".join(u.calls), p.mode, p.visible)')" \
  "close menu, hide, light quick off, show, light sound on, run kawa-quick --state sound sound True"
eq "$(py 'fresh(); p.toggle("sound"); u.calls.clear(); p.toggle("brightness"); print(", ".join(u.calls))')" \
  "close menu, hide, light sound off, show, light brightness on, run kawa-quick --state brightness"
eq "$(py 'fresh(); p.toggle("brightness"); u.calls.clear(); p.toggle(); print(", ".join(u.calls))')" \
  "close menu, hide, light brightness off, show, light quick on, run kawa-quick --state"
eq "$(py '
fresh(); lit = set()
u.light = lambda m, on: lit.add(m) if on else lit.discard(m)
for m in ("quick", "sound", "brightness", "sound", "quick", "brightness", "brightness", "quick"):
    u.t += 1; p.toggle(m); print(sorted(lit), end=" ")')" \
  "['quick'] ['sound'] ['brightness'] ['sound'] ['quick'] ['brightness'] [] ['quick'] " "one lit at most, the one open"
case_ "a click on another module while one is open: that click closed it (outside) — the other opens all the same"
eq "$(py 'fresh(); p.toggle("sound"); p.close("lost"); u.t += 0.1; p.toggle("brightness"); print(p.mode, p.visible)')" "brightness True"
eq "$(py 'fresh(); p.toggle("sound"); p.close("lost"); u.t += 0.1; p.toggle("sound"); print(p.visible)')" False "its own module's click: closed it stays"
eq "$(py 'fresh(); p.toggle("sound"); u.t += 0.1; p.toggle("brightness"); u.t += 0.1; p.toggle("sound"); print(p.mode, p.visible)')" "sound True" "another's key is never a held key"
case_ "every way out takes its marker away: its key, Esc, a click outside, another menu (SIGUSR2), a choice, another panel"
for m in quick sound brightness; do
  for how in 'p.toggle(M)' 'p.key("Escape")' 'p.close("lost")' 'p.close("chosen")' 'p.toggle(OTHER)'; do
    eq "$(py "M = '$m'; OTHER = 'sound' if M != 'sound' else 'quick'; fresh(); p.toggle(M); u.t += 1; u.calls.clear(); $how; print('light ' + M + ' off' in u.calls)")" True "$m: $how"
  done
done
eq "$(py 'fresh(); p.toggle("sound"); u.answer(SOUND); u.calls.clear(); p.press(200, 80); print("light sound off" in u.calls)')" True "sound: mixer"
eq "$(py 'fresh(); p.toggle(); u.calls.clear(); p.activate("power"); print("light quick off" in u.calls)')" True "quick: an opener"
case_ "… even when taking the window away fails"
eq "$(py '
fresh(); p.toggle("sound"); u.calls.clear()
def bad(): raise RuntimeError("gone")
u.hide = bad
try: p.close("chosen")
except RuntimeError: pass
print(u.calls, p.visible)')" "['light sound off'] False"
case_ "the markers: each mode's file, holding the panel's pid while open, gone when closed; one left by a panel gone, cleared as it starts"
eq "$(py 'import os; print(*[os.path.basename(kp.MARKS[m]) for m in kp.MODES])')" \
  "kawa-panel.open kawa-panel-sound.open kawa-panel-brightness.open"
eq "$(py 'print(kp.POKE)')" "{'quick': 15, 'sound': 16, 'brightness': 14}" "the cat +15 · a new +16 for the sound · the brightness module's own +14"
R=$TMP/rt; mkdir -p "$R"
eq "$(XDG_RUNTIME_DIR=$R py '
import os
kp.mark("sound", True); print(sorted(os.listdir(kp.RUN)), open(kp.MARKS["sound"]).read().strip() == str(os.getpid()))
kp.mark("sound", False); kp.mark("sound", False); print(sorted(os.listdir(kp.RUN)))')" \
  "$(printf '%s\n' "['kawa-panel-sound.open'] True" "[]")" "written whole (a rename), then gone; twice gone is no error"
: >"$R/kawa-panel.open"; echo 1 >"$R/kawa-panel-brightness.open"; ln -sf /nonexistent "$R/kawa-panel-sound.open"
eq "$(XDG_RUNTIME_DIR=$R py 'print(kp.stale_marks()); import os; print(sorted(os.listdir(kp.RUN)))')" \
  "$(printf '%s\n' "['quick', 'sound', 'brightness']" "[]")" "a dangling link too"
has "$(sed -n '/    finally:/,/return 0/p' "$REPO/bin/kawa-panel")" 'panel.ui.light(panel.mode, False)' "ended (SIGTERM, SIGHUP, Ctrl+C): the open one's marker goes"
has "$(cat "$REPO/bin/kawa-panel")" 'for mode in stale_marks():' "killed or crashed: its next start clears it (and the bar's lit() checks the pid meanwhile)"
case_ "the panel never hides alive with a marker: closing always destroys its window and takes the marker"
has "$(sed -n '/        def hide(self):/,/destroy/p' "$REPO/bin/kawa-panel")" 'GLib.idle_add(w.destroy)'
eq "$(grep -n 'ui.hide()' "$REPO/bin/kawa-panel" | wc -l)" 1 "only close() takes the window away"
eq "$(py 'fresh(); p.toggle(); p.close("chosen"); print(p.visible, u.calls[-2:])')" "False ['hide', 'light quick off']"
case_ "opened by its key: quick settings 8 px from the right edge, the others under their module on a 1920 px bar; 8 px under the bar"
eq "$(py 'print(kp.MARGIN)')" "{'quick': 8, 'sound': 86, 'brightness': 29, 'menu': 8}" "(a menu dropped from the bar by a key: as quick settings)"
for m in quick sound brightness; do
  eq "$(py "fresh(); p.toggle('$m'); print(p.place)")" "('right', $(py "print(kp.MARGIN['$m'])"), None)" "$m"
done
has "$(cat "$REPO/bin/kawa-panel")" 'GtkLayerShell.set_margin(win, edge, margin)'
case_ "opened by a click on the bar: centred under the pointer, on that output, kept 8 px inside its edges"
eq "$(py 'print(kp.hang(1563, 0, 1920, 304), kp.hang(1616, 0, 1920, 304), kp.hang(1900, 0, 1920, 304), kp.hang(30, 0, 1920, 304), kp.hang(960, 0, 1920, 304))')" "1411 1464 1608 8 808" \
  "the volume, the brightness, the cat (held at the right edge: 1920 − 304 − 8), the far left (8), the middle"
eq "$(py 'print(kp.hang(1920 + 1563, 1920, 2560, 304), kp.hang(1920 + 2550, 1920, 2560, 304), kp.hang(1925, 1920, 2560, 304))')" "1411 2248 8" \
  "on a second output (its own x and width): the margin is the output's own"
eq "$(py 'print(kp.hang(100, 0, 300, 304))')" 8 "an output narrower than the panel: from its left edge"
case_ "dwl's record (X Y OUTPUT OUTPUT_X OUTPUT_WIDTH): taken only while fresh (under 1 s old), and only whole"
eq "$(py 'print(kp.bar_click("1563 15 DP-1 0 1920\n", 0.2), kp.bar_click("1563.7 15 DP-1 1920 2560", 0.0), kp.bar_click("1563 15 DP-1 0 1920", 1.5), kp.bar_click("1563 15 DP-1 0", 0.1), kp.bar_click("x 15 DP-1 0 1920", 0.1), kp.bar_click("", 0.1))')" \
  "(1563, 0, 1920) (1563, 1920, 2560) None None None None"
eq "$(py 'fresh(); u.click = (1563, 0, 1920); p.toggle("sound"); print(p.place); u.click = None; u.t += 1; p.toggle("sound"); u.t += 1; p.toggle("sound"); print(p.place)')" \
  "$(printf '%s\n' "('left', 1411, 0)" "('right', 86, None)")" "each open asks anew: a click's place does not stay for the key's"
eq "$(py 'fresh(); u.click = (1900, 0, 1920); p.toggle(); print(p.place)')" "('left', 1608, 0)" "the cat: under it, held 8 px from the right edge"
eq "$(XDG_RUNTIME_DIR=$TMP py 'import os; print(os.path.basename(kp.POINTER), kp.FRESH, kp.EDGE)')" "dwl-pointer 1.0 8"
case_ "a state read for another panel than the open one: kept, the open one's layout untouched"
eq "$(py 'opened("sound", SOUND); n = len(p.items); p.refresh("quick"); u.answer(STATE); print(len(p.items) == n, p.mode, p.states["quick"]["night"])')" "True sound on"

# ── asking the running panel ───────────────────────────────────────────────────────────
case_ "--sound and --brightness with a panel running: the mode written (kawa-panel.ask), then SIGUSR1; --open: SIGUSR1 alone"
R=$TMP/ask; mkdir -p "$R"
eq "$(XDG_RUNTIME_DIR=$R py '
import os, signal
got = []
signal.signal(signal.SIGUSR1, lambda *a: got.append(kp.asked()))
kp.ask(os.getpid(), "sound"); kp.ask(os.getpid(), "brightness"); kp.ask(os.getpid(), "quick")
print(got, os.listdir(kp.RUN))')" "['sound', 'brightness', 'quick'] []" "each read once and taken away"
for m in sound brightness; do
  XDG_RUNTIME_DIR=$R python3 -I -c 'import signal, sys, time, os
signal.signal(signal.SIGUSR1, lambda *a: open(sys.argv[1], "a").write(open(os.environ["XDG_RUNTIME_DIR"] + "/kawa-panel.ask").read()))
open(sys.argv[2], "w").close(); time.sleep(30)' "$TMP/got-$m" "$TMP/up-$m" kawa-panel & pp=$!
  for _ in {1..50}; do [[ -e $TMP/up-$m ]] && break; sleep 0.05; done
  echo "$pp" >"$R/kawa-panel.pid"
  rc 0 env XDG_RUNTIME_DIR="$R" PYTHONPATH="$P" python3 "$REPO/bin/kawa-panel" "--$m"
  for _ in {1..50}; do [[ -s $TMP/got-$m ]] && break; sleep 0.05; done
  eq "$(cat "$TMP/got-$m" 2>/dev/null)" "$m" "--$m"
  kill "$pp" 2>/dev/null; wait "$pp" 2>/dev/null
done
rm -f "$R/kawa-panel.pid" "$R/kawa-panel.ask"
case_ "the bar's sound and brightness modules and Super+A can ask for them: kawa-quick --do sound opens the sound panel"
has "$(cat "$REPO/bin/kawa-quick")" 'sound)      exec kawa-panel --sound ;;'

# ── a menu's size ─────────────────────────────────────────────────────────────────────
case_ "a menu sizes to its content: the value 12 px after the widest detail, 6 px to the edge (the weather's week)"
eq "$(py 'm = kp.Menu(["part\t天\tSharjah", "row\t☼\tMon 19\tscorching\t31°", "row\t☁\tTue 20\tmild\t24°"])
print(m.inner(), kp.columns([l[2] for l in m.lines if l[1] == "row"], kp.px_of))')" "162 (72, 156)" "the names 36 px: details at 24 + 36 + 12 = 72; scorching (54) ends at 126, + 12 + the widest value (18): 156; + 6: 162 wide"
eq "$(py 'print(kp.Menu(["row\tx\tlock", "row\tx\tshut down"]).inner())')" 120 "a short menu: 120 px at least"
eq "$(py 'print(kp.Menu(["key\tx\tprevious", "key\tx\tnext", "key\tx\ttoday"]).inner())')" "$((3 * (30 + 48) + 2 * 6))" "keys sharing a row: each as wide as the widest"
eq "$(py 'print(kp.px_of("a—b…"))')" 36 "the letters Fusion Pixel draws wide (width.sh) count 12"
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
out=$(python3 -I "$REPO/bin/kawa-panel" --help); has "$out" "quick settings"; has "$out" "SIGUSR1"; has "$out" "SIGUSR2: close"
has "$out" "--sound"; has "$out" "--brightness"
rc 2 python3 -I "$REPO/bin/kawa-panel" --bogus; rc 2 python3 -I "$REPO/bin/kawa-panel" --open extra
rc 2 python3 -I "$REPO/bin/kawa-panel" --sound --brightness; rc 2 python3 -I "$REPO/bin/kawa-panel" sound
case_ "one at a time: with one running, a second exits at once — or, with --open, asks it to open"
export XDG_RUNTIME_DIR=$TMP/run; mkdir -p "$XDG_RUNTIME_DIR"
python3 -I -c 'import signal, sys, time
signal.signal(signal.SIGUSR1, lambda *a: open(sys.argv[1], "a").write("open\n"))
open(sys.argv[2], "w").close(); time.sleep(30)' "$TMP/got" "$TMP/up" kawa-panel & pp=$!
for _ in {1..50}; do [[ -e $TMP/up ]] && break; sleep 0.05; done
echo "$pp" >"$XDG_RUNTIME_DIR/kawa-panel.pid"
rc 0 env PYTHONPATH="$P" python3 "$REPO/bin/kawa-panel"
rc 0 env PYTHONPATH="$P" python3 "$REPO/bin/kawa-panel" --open
for _ in {1..50}; do [[ -s $TMP/got ]] && break; sleep 0.05; done
eq "$(cat "$TMP/got" 2>/dev/null)" open
kill "$pp" 2>/dev/null; wait "$pp" 2>/dev/null

# ── where it comes from ───────────────────────────────────────────────────────────────
case_ "the session starts it (autostart, kept running), its colours come with each theme, the bar's cat asks for it"
has "$(cat "$REPO/configs/home/.config/dwl/autostart.sh")" 'keep kawa-panel'
for m in dark light; do [[ -s $REPO/configs/home/.config/fedokawaii/themes/$m/panel.conf ]] && _ok || _no "no $m panel.conf"; done
has "$(cat "$REPO/configs/home/.config/waybar/config.jsonc")" '"on-click": "kawa-quick"'
done_
