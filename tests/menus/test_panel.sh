#!/usr/bin/env bash
# tests/menus/test_panel.sh — kawa-panel, quick settings on screen. Its window needs a screen,
# so what is tested is everything but the drawing (which the real one is measured for in
# docs/build: placement 8 px under the bar and from the edge, the 12 px grid): the layout
# (every item, its place, three tiles a row, the keys at the foot centred), the tiles' words
# and seals for each state, the keys and the mouse, what each choice runs, the meters (set
# where clicked, the wheel, one level at a time), opening and closing (its key, Esc, a click
# outside — and the click on the bar's cat that made that click outside), the bar's cat lit
# while open, a fuzzel menu closed when it opens, the theme's colours, the pid file and its
# key, and the pointer's hot item apart from the keyboard's cursor (look(): what each is drawn
# with — no box under the pointer — and only the items that changed redrawn). The module is
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
Gtk = Gdk = Gio = GLib = GtkLayerShell = Pango = PangoCairo = _Any()
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
    def __init__(self): self.calls, self.t, self.pending, self.drawn = [], 100.0, [], []
    def now(self): return self.t
    def redraw(self, *items): self.calls.append("redraw"); self.drawn.append([i.key for i in items] or "all")
    def show(self): self.calls.append("show")
    def hide(self): self.calls.append("hide")
    def light(self, on): self.calls.append("light on" if on else "light off")
    def close_menu(self): self.calls.append("close menu")
    def run(self, argv, done): self.calls.append("run " + " ".join(argv)); self.pending.append(done)
    def launch(self, argv): self.calls.append("launch " + " ".join(argv))
    def answer(self, out="", rc=0):            # the oldest run comes back
        self.pending.pop(0)(rc, out)
STATE = ("theme\tdark\nbrightness\t70%\nnight\ton\nvrr\tin games\nwallpaper\tmishima-mist\nsound\t62%\n"
         "nettype\twifi\nnetwork\tHome Net 5G\nbluetooth\ton\ndevices\tnone\ndrives\tKINGSTON 58G\n"
         "backup\t3 days ago\ndnd\toff\n")
u = UI(); p = kp.Panel(u)
def fresh(state=STATE):
    global u, p
    u = UI(); p = kp.Panel(u); p.refresh(); u.answer(state); u.calls.clear()
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
eq "$(py 'fresh(); p.toggle(); print(", ".join(u.calls))')" "close menu, show, light on, run kawa-quick --state"
case_ "its key again closes it, the cat dark again"
eq "$(py 'fresh(); p.toggle(); u.calls.clear(); u.t += 0.6; p.toggle(); print(", ".join(u.calls), p.visible)')" "hide, light off False"
case_ "its key held (dwl repeats it): a toggle within half a second of the last is ignored — no flicker"
eq "$(py 'fresh(); p.toggle(); u.calls.clear(); u.t += 0.1; p.toggle(); u.t += 0.3; p.toggle(); print(u.calls, p.visible)')" "[] True"
eq "$(py 'fresh(); p.toggle(); u.t += 0.6; p.toggle(); u.calls.clear(); u.t += 0.2; p.toggle(); print(u.calls, p.visible)')" "[] False" "held after closing: stays closed"
case_ "another menu's key (SIGUSR2): closed as chosen — its key then opens it at once"
eq "$(py 'fresh(); p.toggle(); u.calls.clear(); p.close("chosen"); u.t += 0.1; p.toggle(); print(p.visible)')" True
has "$(cat "$REPO/bin/kawa-panel")" 'signal.SIGUSR2, lambda: panel.close("chosen")'
case_ "the bar's cat: lit by a marker of its own (a dropdown's, kawa-drop.open, is kawa-menu's)"
eq "$(py 'import os; print(os.path.basename(kp.MARK))')" kawa-panel.open
lacks "$(grep -v '^ *#' "$REPO/bin/kawa-panel" | grep -v '# own: a dropdown')" 'kawa-drop.open'
has "$(cat "$REPO/bin/kawa-panel")" '"kawa-dwlstatus", "--poke", "15"'
case_ "the meters: no number beside the squares (the bar shows both levels) — words only when there is no level"
lacks "$(cat "$REPO/bin/kawa-panel")" 'it.key != "sound"'
has "$(python3 -I "$REPO/bin/kawa-panel" --help)" "their levels are the"
case_ "Esc closes it"
eq "$(py 'fresh(); p.toggle(); u.calls.clear(); p.key("Escape"); print(", ".join(u.calls))')" "hide, light off"
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
    "hide, light off, launch kawa-quick --do $k" "$k"
done
case_ "Enter on the sound meter: its menu (outputs, the microphone); on brightness: nothing more"
eq "$(py 'fresh(); p.toggle(); u.calls.clear(); p.focus = "sound"; p.key("Return"); print(", ".join(u.calls))')" "hide, light off, launch kawa-quick --do sound"
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
case_ "the pointer over an item makes it the hot one — the keyboard's cursor stays; a click does it, and moves the cursor there"
eq "$(py 'fresh(); p.hover(150, 116); print(p.hot, p.focus)')" "night theme"
eq "$(py 'fresh(); p.hover(150, 116); p.hover(10, 116); print(p.hot, p.focus)')" "None theme" "over the frame or a gap: none"
eq "$(py 'fresh(); p.hover(150, 116); p.press(150, 116); print(p.hot, p.focus)')" "night night"
eq "$(py 'fresh(); p.press(150, 46); print(p.focus)')" sound "a click on a meter: the cursor there too"
eq "$(py 'fresh(); p.toggle(); u.calls.clear(); p.press(60, 316); print(", ".join(u.calls))')" "redraw, hide, light off, launch kawa-quick --do wallpaper"
eq "$(py 'fresh(); p.hover(150, 116); p.key("Right"); print(p.hot, p.focus)')" "night night" "the keys move the cursor from where it is, not from the pointer's"
eq "$(py 'fresh(); p.hover(150, 186); p.key("Down"); print(p.hot, p.focus)')" "bluetooth network"
case_ "the pointer leaving the panel: nothing hot, only that item redrawn; the cursor stays"
eq "$(py 'fresh(); p.hover(150, 116); u.drawn.clear(); p.leave(); print(p.hot, p.focus, u.drawn)')" "None theme [['night']]"
eq "$(py 'fresh(); u.drawn.clear(); p.leave(); print(u.drawn)')" "[]" "nothing was hot: nothing redrawn"
has "$(cat "$REPO/bin/kawa-panel")" 'win.connect("leave-notify-event", on_leave)'
has "$(cat "$REPO/bin/kawa-panel")" 'Gdk.EventMask.LEAVE_NOTIFY_MASK'
case_ "opened again: nothing hot until the pointer moves (a new window); a state read keeps it while it is there"
eq "$(py 'fresh(); p.toggle(); p.hover(150, 116); p.close("chosen"); p.toggle(); print(p.hot)')" None
eq "$(py 'fresh(); p.hover(150, 116); p.refresh(); u.answer(STATE); print(p.hot)')" night
eq "$(py 'fresh(); p.hover(150, 186); p.refresh(); u.answer(STATE.replace("bluetooth\ton\n","").replace("devices\tnone\n","")); print(p.hot)')" None "its tile gone: none"
case_ "a drag: the meter follows, the hot one does not move off it"
eq "$(py 'fresh(); p.hover(112, 24); p.press(112, 24); p.hover(150, 116, dragging=True); print(p.hot, p.focus)')" "brightness brightness"
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
eq "$(py 'fresh(); u.drawn.clear(); p.key("Right"); print(u.drawn)')" "[['theme', 'night']]" "the keys: the cursor's two"

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
src=$(sed -n '/    def draw(widget, cr):/,/        return True/p' "$REPO/bin/kawa-panel")
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
eq "$(py 'fresh(); p.scroll(150, 24, True); p.scroll(150, 46, False); print(p.state["brightness"], p.state["sound"])')" "75% 60%" "(62 % down: 60, the next multiple of 5)"
eq "$(py 'fresh(); p.scroll(150, 116, True); print(u.calls)')" "[]" "over a tile: nothing"

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

# ── use ───────────────────────────────────────────────────────────────────────────────
case_ "--help: what it is; anything else: exit 2"
out=$(python3 -I "$REPO/bin/kawa-panel" --help); has "$out" "quick settings"; has "$out" "SIGUSR1"; has "$out" "SIGUSR2: close"
rc 2 python3 -I "$REPO/bin/kawa-panel" --bogus; rc 2 python3 -I "$REPO/bin/kawa-panel" --open extra
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
