#!/usr/bin/env bash
# tests/look/test_calc.sh — kawa-calc, the launcher's Calculator: the answer shows as you type
# (the real qalc works it out), Enter copies it and keeps the line above, a word alone or a
# qalc command is never sent, Esc closes. Typed on a terminal of its own (script).
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"
need qalc python3

setup() {
  look
  argv wl-copy 'cat >"$FAKE_TMP/clip"'
  stub wl-paste '[ "$1" = --list-types ] && [ -e "$FAKE_TMP/clip" ] && echo "text/plain;charset=utf-8"'
}
# typed KEYS… — each argument typed after the one before has been answered (0.8 s), then Esc
typed() {
  local k
  { for k; do printf '%b' "$k"; /bin/sleep 0.8; done; printf '\e'; /bin/sleep 0.3; } \
    | python3 -I "$REPO/tests/lib/pty_run.py" --stdin --cols 64 --rows 13 --timeout 30 -- kawa-calc 2>&1 | tr -d '\r'
}
plain() { sed 's/\x1b\[[0-9;?]*[A-Za-z]//g; s/\x1b[78]//g' <<<"$1"; }

setup
case_ "a conversion: its answer as it is typed; the heading is the calculator's icon, calculator"
. "$REPO/configs/home/.config/fedokawaii/icons.sh"
out=$(plain "$(typed '5 ft to cm')"); has "$out" "$ICON_CALC  calculator"; has "$out" "$ICON_EQUALS  152.4 cm"
lacks "$out" "算" "no kanji (§13)"
case_ "Enter: the answer copied, the line kept above, said on the last line"
out=$(plain "$(typed '6*7' '\r')"); eq "$(cat "$TMP/clip" 2>/dev/null)" 42; has "$out" "6*7 = 42"; has "$out" "copied: 42"
case_ "a word alone, or one of qalc's commands: no answer (never sent: exit would end qalc)"
setup; out=$(plain "$(typed 'steam' '\x15exit 5' '\x152+2')"); lacks "$out" "$ICON_EQUALS  0"; has "$out" "$ICON_EQUALS  4"
case_ "Backspace takes a letter back; the answer follows"
out=$(plain "$(typed '2*30' '\x7f')"); has "$out" "$ICON_EQUALS  6"
case_ "each key one frame (a synchronised update), never cleared first; the last line its own key alone (§7), the answer's copy at its right"
raw=$(typed '1+1' '\x7f'); has "$raw" $'\e[?2026h'; has "$raw" $'\e[?2026l'; lacks "$raw" $'\e[2J'
has "$(plain "$raw")" "ctrl+q  qalc's prompt"; lacks "$(plain "$raw")" "esc close"; lacks "$(plain "$raw")" "enter copy"; lacks "$raw" "↑"
has "$(plain "$raw")" "copy" "the answer's copy"
has "$raw" "   "$'\e[38;5;20m'"$ICON_CHEVRON_RIGHT"$'\e[0m  1+1' "the line typed: the chevron (accent_text) at the rows' icon column, the words at their names'"
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
    def listen(self, on): pass
    def calc(self, m): self.calls.append(f"calc {m.query}")
    def copy_answer(self, text): self.calls.append(f"copy {text}")
    def start(self, app): self.calls.append(f"start {app.id}")
    def command(self, text): self.calls.append(f"command {text}")
apps = [kp.App("brave-origin.desktop", "Brave Origin", "Web browser", ["internet"], None, None),
        kp.App("kawa-calc.desktop", "Calculator", "Sums and conversions", ["math"], "calc", None)]
u = UI(); p = kp.Panel(u)
def typed(text):
    for c in text: p.typed("space" if c == " " else c, c)
p.request("launcher", kp.Launcher(apps, {}), None)
exec(sys.argv[3])
PY
}
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
case_ "Esc closes (exit 0); misuse is 2"
rc 0 typed ''; rc 2 kawa-calc --frob
case_ "without qalc: said, exit 1"
hide qalc; out=$(kawa-calc 2>&1); eq "$?" 1; has "$out" "qalc is missing"

done_
