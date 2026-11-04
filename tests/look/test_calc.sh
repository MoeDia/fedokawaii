#!/usr/bin/env bash
# tests/look/test_calc.sh — the calculator (kawa-panel's Calc) and the launcher's sums, driven with a stand-in ui; kawa-calc
# --answer with the real qalc: a word alone or a qalc command is never sent.
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"
need qalc python3

setup() {
  look
  argv wl-copy 'cat >"$FAKE_TMP/clip"'
  stub wl-paste '[ "$1" = --list-types ] && [ -e "$FAKE_TMP/clip" ] && echo "text/plain;charset=utf-8"'
}
setup
case_ "a percentage in words: \"15% of 2400\" is qalc's 15% * 2400 (qalc alone: rem(15, 1 B))"
eq "$(kawa-calc --answer '15% of 2400')" 360; eq "$(kawa-calc --answer '120 * 15% of 10')" 180
rc 1 kawa-calc --answer steam
# the launcher (kawa-panel's): its Panel driven with a stand-in ui that notes what it is asked
lp() {
  local G=$TMP/gi; mkdir -p "$G/gi/repository"
  echo 'def require_version(*a): pass' >"$G/gi/__init__.py"
  printf '%s\n' 'class _Any:' '    def __init__(self, *a, **k): pass' '    def __call__(self, *a, **k): return _Any()' \
    '    def __getattr__(self, n): return _Any()' 'Gtk = Gdk = Gio = GioUnix = GLib = GLibUnix = GtkLayerShell = Pango = PangoCairo = _Any()' >"$G/gi/repository/__init__.py"
  python3 -I -B - "$REPO/bin/kawa-panel" "$G" "$1" <<'PY'
import importlib.machinery, importlib.util, sys
sys.dont_write_bytecode = True; sys.path.insert(0, sys.argv[2])
l = importlib.machinery.SourceFileLoader("kp", sys.argv[1]); kp = importlib.util.module_from_spec(importlib.util.spec_from_loader("kp", l)); l.exec_module(kp)
class UI:
    def __init__(self): self.calls, self.t, self.at, self.cid = [], 100.0, None, None
    def clicked(self): return None
    def click(self): return None
    def push(self, *a): pass
    def trim(self, size): return 0, size[1], size[0]
    def now(self): return self.t
    def redraw(self, *items): pass
    def show(self): self.calls.append("show")
    def hide(self): self.calls.append("hide")
    def light(self, mode, on): pass
    def run(self, argv, done): pass
    def launch(self, argv): self.calls.append("launch " + " ".join(argv))
    def later(self, ms, fn): pass
    def calc(self, m): self.calls.append(f"calc {m.query}")
    def copy_answer(self, text): self.calls.append(f"copy {text}")
    def copy_answer_of(self, m, q): self.calls.append(f"copy-of {q}")
    def copy_quiet(self, text): self.calls.append(f"quiet {text}")
    def calc_now_(self, m, q): self.calls.append(f"now {q}")
    def start(self, app): self.calls.append(f"start {app.id}")
    def command(self, text): self.calls.append(f"command {text}")
apps = [kp.App("brave-origin.desktop", "Brave Origin", "Web browser", ["internet"], None, None),
        kp.App("kawa-calc.desktop", "Calculator", "Sums and conversions", ["math"], "calc", None)]
u = UI(); p = kp.Panel(u)
def typed(text):
    for c in text: p.typed("space" if c == " " else c, c)
if sys.argv[3].startswith("#calc"):
    p.request("calc", kp.Calc(), None)
else:
    p.request("launcher", kp.Launcher(apps, {}), None)
exec(sys.argv[3])
PY
}
# the calculator (kawa-panel's Calc): a panel as the launcher, its own keys
pc() { lp "#calc
def typed(text):
    for c in text: p.key('space' if c == ' ' else c, c)
def ans(q, a):
    m = p.state; m.calc = (q, a); m.pending = None; p.answered(m)
$1"; }
case_ "kawa-calc: the panel's calculator, asked as the launcher is; nothing of a terminal left in it"
stub kawa-menu 'echo "kawa-menu $*" >>"$FAKE_TMP/menu"'; rc 0 kawa-calc; eq "$(cat "$TMP/menu")" "kawa-menu --calc"
has "$(cat "$REPO/bin/kawa-menu")" 'ask "toggle $toggle"'; has "$(cat "$REPO/configs/home/.local/share/applications/kawa-calc.desktop")" "Exec=@HOME@/.local/bin/kawa-calc"
lacks "$(cat "$REPO/bin/kawa-calc")" "stty"; lacks "$(cat "$REPO/configs/home/.local/share/applications/kawa-calc.desktop")" "kawa-term"
case_ "a sum typed: asked of qalc as it is typed, the line and the answer in their marks, the size never moves"
eq "$(pc 'typed("5 ft to cm"); print([c for c in u.calls if c.startswith("calc")][-1]); s0 = p.size; ans("5 ft to cm", "152.4 cm")
print([m[5] for m in p.marks if m[0] == "answer"], [m[-1] for m in p.marks if m[0] == "input"], p.size == s0)')" \
  "$(printf '%s\n' 'calc 5 ft to cm' "['152.4 cm'] ['5 ft to cm'] True")"
case_ "opens clean: no cursor on a row, what it can do in faint until there is a sum; the heading the calculator's icon (§13: no kanji)"
eq "$(pc 'print(p.focus, [h[:2] for h in p.heads], [m[5] for m in p.marks if m[0] == "off"][:2])')" "None [('calc', 'calculator')] ['15% of 2400', '120 usd to aed']"
case_ "Enter: the answer copied without a notice (the panel says it), kept below, the line clean, the panel still there"
eq "$(pc 'typed("6*7"); ans("6*7", "42"); p.key("Return"); print(u.calls[-1], p.visible, repr(p.state.query), [(i.name, i.value) for i in p.items], [m[5:] for m in p.marks if m[0] == "answer"], p.focus)')" \
  "quiet 42 True '' [('6*7', '42')] [('42', '42')] None"
case_ "Enter before its answer came: asked at once, done when it comes — never the earlier answer"
eq "$(pc 'typed("5 ft"); ans("5 ft", "1.524 m"); u.calc = lambda m: setattr(m, "pending", m.query); typed(" to cm"); p.key("Return"); print(u.calls[-1]); ans("5 ft to cm", "152.4 cm"); print(u.calls[-1], [(i.name, i.value) for i in p.items][0])')" \
  "$(printf '%s\n' 'now 5 ft to cm' "quiet 152.4 cm ('5 ft to cm', '152.4 cm')")"
case_ "the session's sums: the newest first, Down goes to them, Enter copies one and comes back to the line; Up on the line takes the last back; a new panel keeps them, its line clean"
eq "$(pc 'kp.Calc.done = []; typed("1+1"); ans("1+1", "2"); p.key("Return"); typed("2+2"); ans("2+2", "4"); p.key("Return")
print([i.name for i in p.items]); p.key("Down"); print(p.focus); p.key("Return"); print(u.calls[-1], p.focus, p.state.copied); p.key("Down"); p.key("Down"); print(p.focus); p.key("Up"); p.key("Up"); print(p.focus)
p.key("Up"); print(p.state.query); p.key("Escape"); print(p.visible); p.request("calc", kp.Calc(), None); print(repr(p.state.query), [i.name for i in p.items], p.visible)')" \
  "$(printf '%s\n' "['2+2', '1+1']" d0 'quiet 4 None 4' d1 None 2+2 False "'' ['2+2', '1+1'] True")"
case_ "Backspace and Ctrl+U on the line; Ctrl+Q closes it and opens qalc's own prompt in a window of its own; the same sum twice kept once"
eq "$(pc 'typed("2*30"); p.key("BackSpace"); print(p.state.query); p.key("u"); print(repr(p.state.query)); p.key("q"); print(p.visible, u.calls[-1][:44])')" \
  "$(printf '%s\n' '2*3' "''" 'False launch setsid -f -- kawa-term --float --once')"
eq "$(pc 'kp.Calc.done = []; typed("1+1"); ans("1+1", "2"); p.key("Return"); typed("1+1"); ans("1+1", "2"); p.key("Return"); print(len(kp.Calc.done))')" 1
case_ "the launcher: a sum typed is worked out as it is typed (ui.calc, each letter); its answer, once come, the first row — Enter copies it (the notice says so, with it)"
eq "$(lp 'typed("15% of 2400"); print([c for c in u.calls if c.startswith("calc")][-1]); m = p.state; m.calc = (m.query, "360"); p.answered(m)
print(p.items[0].key, p.items[0].name, p.items[0].value, p.focus); p.key("Return"); print(u.calls[-1], p.visible)')" \
  "$(printf '%s\n' 'calc 15% of 2400' 'calc 360 copy calc' 'copy 360 False')"
eq "$(lp 'typed("2+2"); m = p.state; m.calc = ("2+", "3"); p.answered(m); print([i.key for i in p.items])')" "[]" "an answer to what was typed before: not shown"
case_ "bug 6 (the answer's row flickered as each key was typed): while the new text's answer is worked out (asked: calc_ask marks it pending) the last answer stays in its row, the list never jumps; it changes in place when the new one comes, and goes at once when the text is no sum"
eq "$(lp 'typed("12*3"); m = p.state; m.calc = ("12*3", "36"); p.answered(m)
u.calc = lambda m: setattr(m, "pending", m.query)    # (as calc_ask: a sum asked is pending)
typed("4"); print(p.items[0].key, p.items[0].name, p.focus)
m.calc = ("12*34", "408"); m.pending = None; p.answered(m); print(p.items[0].key, p.items[0].name, p.focus)
u.calc = lambda m: setattr(m, "pending", None)       # (no sum: nothing asked)
typed(" apples"); print([i.key for i in p.items if i.key == "calc"])')" \
  "$(printf '%s\n' 'calc 36 calc' 'calc 408 calc' '[]')"
has "$(sed -n '/    def calc_ask(m):/,/qc\["next"\] = (m, q)/p' "$REPO/bin/kawa-panel")" "m.pending = q" "calc_ask marks what it asks"
has "$(sed -n '/    def calc_line(stream, res):/,/    def calc_end/p' "$REPO/bin/kawa-panel")" "elif m.pending == q:" "an answer that is none: the last one goes"
case_ "bug 6, the rest (seen frame by frame 1 Nov: typing \"5 ft to cm\" the row ran through 1524 kg*m, 5 B*t*ft, …s*c — a half-typed word is another unit to qalc): a sum is asked once the typing settles (SETTLE ms without a key), never mid-word; Enter while the row still shows an earlier text's answer copies THIS text's, once it comes — never the earlier one"
eq "$(lp 'typed("5 ft"); m = p.state; m.calc = ("5 ft", "1.524 m"); p.answered(m)
u.calc = lambda m: setattr(m, "pending", m.query)
typed(" to cm"); print(p.items[0].name); p.key("Return"); print(u.calls[-1], p.visible)')" \
  "$(printf '%s\n' '1.524 m' 'copy-of 5 ft to cm False')"
eq "$(lp 'typed("5 ft"); m = p.state; m.calc = ("5 ft", "1.524 m"); m.pending = None; p.answered(m); p.key("Return"); print(u.calls[-1])')" "copy 1.524 m" "its own answer shown: copied as it is"
src=$(sed -n '/    def calc_ask(m):/,/    def calc_start():/p' "$REPO/bin/kawa-panel")
has "$src" 'qc["settle"] = GLib.timeout_add(SETTLE, settled, m, q)' "asked when the typing settles"
has "$(sed -n '/^    SETTLE = /p' "$REPO/bin/kawa-panel")" "SETTLE = 250"
has "$(sed -n '/    def calc_line(stream, res):/,/    def calc_end/p' "$REPO/bin/kawa-panel")" 'panel.ui.copy_answer(money(a))' "Enter's answer copied when it comes"
setup; argv notify-send; rm -f "$TMP/clip"
src=$(sed -n '/        def copy_answer(self, text):/,/^$/p' "$REPO/bin/kawa-panel" | python3 -c 'import sys, re; t = sys.stdin.read(); print(re.search(r"\"bash\", \"-c\", (.*?), \"_\", text\]", t, re.S).group(1))')
script=$(python3 -c 'import ast, sys; print("".join(ast.literal_eval("(" + sys.argv[1] + ")")))' "$src")
bash -c "$script" _ 360; eq "$(cat "$TMP/clip" 2>/dev/null)" 360 "the answer on the clipboard"; called notify-send "copied 360"
case_ "the launcher: an entry picked (a click or Enter) starts it; text that finds nothing runs as a command"
eq "$(lp 'typed("brav"); print([i.name for i in p.items]); p.key("Return"); print(u.calls[-1], p.visible)')" "$(printf '%s\n' "['Brave Origin']" 'start brave-origin.desktop False')"
eq "$(lp 'typed("math"); print([i.name for i in p.items])')" "['Calculator']" "found by its keywords"
eq "$(lp 'typed("htop -d 5"); print([i.key for i in p.items]); p.key("Return"); print(u.calls[-1], p.visible)')" "$(printf '%s\n' '[]' 'command htop -d 5 False')"
lacks "$(cat "$REPO/bin/kawa-menu")" "fuzzel" "kawa-menu --launcher asks the panel, nothing else"
has "$(cat "$REPO/bin/kawa-menu")" "toggle launcher"
case_ "misuse is 2"
rc 2 kawa-calc --frob
case_ "without qalc: said, exit 1"
hide qalc; out=$(kawa-calc --answer 1+1 2>&1); eq "$?" 1; has "$out" "qalc is missing"

done_
