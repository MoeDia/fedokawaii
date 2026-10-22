#!/usr/bin/env bash
# tests/content/test_tiles.sh — the terminal at every size dwl tiles it to on a 1920×1080
# screen (gap 8, border 2; Sumi Term at 20 px: 10 × 24 px cells, 10 px of paper round):
#   spiral   1900×1060 → 188×43 · 1170×1060 → 115×43 · 718×1060 → 69×43 · 718×650 → 69×26
#            718×398 → 69×15 · 439×398 → 41×15 · 267×398 → 24×15 · 267×241 → 24×9 · 267×145 → 24×5
#   columns  944 → 92×43 · 625 → 60×43 · 466 → 44×43
# (the sizes below were measured at the cells' earlier 22 px height: each still a size a
# window can have, each the layout it shows)
# The prompt (~/.bashrc.d/fedokawaii.sh): one short line — what it gives up as the window
# narrows (the time, the jobs, the branch, the folder above, then the folder's end), real
# prompts in a terminal of each width, the line laid out anew when the width changes under it
# (ble.sh runs the prompt command again then), foot's reflow, and with the real ble.sh, when
# one is at hand, a window resized under a prompt. btop's start (the richest preset its window holds) and lazygit's
# portrait mode for tall narrow tiles. (yazi's panes: tests/yazi/test_yazi.sh.)
. "$(dirname "$0")/lib.sh"
# the real ble.sh, built at lib/upstream.sh's commit (FEDOKAWAII_BLESH, or the one in your home)
BLESH_DIR=${FEDOKAWAII_BLESH:-$HOME/.local/share/blesh}
BLESH_PIN=$(sed -n 's/^BLESH_COMMIT=//p' "$REPO/lib/upstream.sh")
REAL_LAZYGIT=$(command -v lazygit 2>/dev/null)
YD=$(cd "$C/../yazi" && pwd)
WIDTHS="188 115 92 69 60 44 41 24"

home() {   # home — a fresh home with the shell's files (Fedora's ~/.bashrc reads ~/.bashrc.d)
  sandbox
  config .bashrc.d/fedokawaii.sh .config/readline/inputrc .config/blesh .config/fedokawaii/fzf.opts .config/bat .config/btop
  export INPUTRC=$HOME/.config/readline/inputrc   # (/etc/profile.d/fedokawaii-home.sh, on the machine)
  printf '%s\n' 'for rc in ~/.bashrc.d/*; do [ -f "$rc" ] && . "$rc"; done; unset rc' >"$HOME/.bashrc"
  stub zoxide 'case $1 in init) printf "%s\n" "__zoxide_z() { builtin cd \"\$@\"; }" "cd() { __zoxide_z \"\$@\"; }" ;; esac'
  stub eza; stub bat
  mkdir -p "$HOME/repos/fedokawaii/configs/home/.config" "$HOME/日本語のフォルダ" \
           "$HOME/a-folder-whose-name-is-far-longer-than-any-small-tile-is-wide"
  git -C "$HOME/repos/fedokawaii" init -q -b main
  echo a >"$HOME/repos/fedokawaii/a"; git -C "$HOME/repos/fedokawaii" add a; echo b >"$HOME/repos/fedokawaii/b"
}
# fn CODE — CODE in an interactive shell of the home, one a command has run in (__kawa_ran:
# a fresh window, whose width is asked of its terminal, has its own case below)
fn() { TERM=${T_TERM:-foot} bash -ic "__kawa_ran=1; $1" 2>/dev/null; }
# shellcheck source=/dev/null
. "$REPO/configs/home/.config/fedokawaii/icons.sh"
# plain TEXT — TEXT as the tests read it: ✓ as V, ✗ as X, every other pixel icon as I
plain() { python3 -I -c '
import sys
V, X = sys.argv[1], sys.argv[2]
for line in sys.stdin.read().split("\n"):
    print("".join("V" if c == V else "X" if c == X else "I" if 0xFE000 <= ord(c) <= 0xFEFFF else c for c in line))' \
  "$ICON_CHECK" "$ICON_CROSS"; }
# headers COLS LINE… — the header of each prompt (plain) of a bash -i COLS wide, each LINE
# typed at its own prompt
headers() {
  local c=$1 a=(); shift
  for l in "$@" exit; do a+=(--line "$l"); done
  (cd "$HOME" && TERM=foot python3 -I "$C/pty_run.py" --cols "$c" --rows 30 --timeout 30 --each '\x1b]133;A' \
    "${a[@]}" -- bash -i 2>&1) | python3 -I -c '
import re, sys
raw = sys.stdin.buffer.read().decode("utf-8", "replace")
for seg in raw.split("\x1b]133;A\x1b\\")[1:]:
    print(re.sub(r"\x1b\[[0-9;]*m|\x1b\][^\x1b]*\x1b\\\\|[\x01\x02]", "", seg.split("\n")[0].rstrip("\r")))' | plain
}
width() { python3 -I -c 'import sys, unicodedata; print(sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in sys.argv[1]))' "$1"; }

# ── the line at every width: what goes first ─────────────────────────────────────
home
# lay COLS — __kawa_layout of a line with everything on it (repos/fedokawaii, main with
# changes, exit 2, 4.2s, a job) at COLS, as it reads (I a pixel icon)
lay() { fn "COLUMNS=$1; __kawa_place=fedokawaii __kawa_above=repos/ __g_branch=main __g_dirty='*' __kawa_ok=0 __kawa_rc=2 __kawa_took=4.2s __kawa_jobs='jobs 1'
  __kawa_layout; printf '%s' \"\$__kawa_line\"" | sed 's/\x01\|\x02//g; s/\x1b\[[0-9;]*m//g' | plain; }
case_ "__kawa_layout: all of it while it fits a column short of the edge; then the time goes, the jobs, the branch, the folder above, then the folder's end — never an ellipsis"
eq "$(lay 52)" "I  repos/fedokawaii  I  main*  2  4.2s  jobs 1  I  " "52 columns: everything"
eq "$(lay 51)" "I  repos/fedokawaii  I  main*  2  jobs 1  I  " "the time first"
eq "$(lay 46)" "I  repos/fedokawaii  I  main*  2  jobs 1  I  "
eq "$(lay 45)" "I  repos/fedokawaii  I  main*  2  I  " "then the jobs"
eq "$(lay 36)" "I  repos/fedokawaii  2  I  " "then the branch"
eq "$(lay 26)" "I  fedokawaii  2  I  " "then the folder above"
eq "$(lay 20)" "I  fedokawa  2  I  " "then the folder's end"
for c in 80 52 45 36 26 20 16; do w=$(width "$(lay "$c")"); ((w <= c - 1)) && _ok || _no "$c columns: $w wide"; done
lacks "$(lay 12)" "…"; [[ $(lay 12) == "I  "?*"  2  I  " ]] && _ok || _no "a letter of the folder kept at least: [$(lay 12)]"

# ── real prompts at every tile's width ────────────────────────────────────────
for c in $WIDTHS; do
  H=$(headers "$c" 'cd ~/repos/fedokawaii/configs/home/.config' '(exit 3)' 'cd ~/a-folder-whose-name-is-far-longer-than-any-small-tile-is-wide' \
      'cd ~/日本語のフォルダ' '__kawa_t0=$((__kawa_t0 - 4200000))')
  case_ "$c columns: every prompt one short line, never as wide as the window; the code after a failure kept while the folder can make room"
  eq "$(wc -l <<<"$H")" 6 "six prompts: $H"
  while IFS= read -r h; do
    h=${h%"  I  "*}; w=$(width "$h")            # (the line up to its ›: what is typed after it is not the prompt)
    ((w + 5 <= c - 1)) && _ok || _no "$((w + 5)) wide: [$h]"
  done <<<"$H"
  [[ $(sed -n 3p <<<"$H") == *'  3  '* ]] && _ok || _no "header 3: [$(sed -n 3p <<<"$H")]"
  [[ $(sed -n 2p <<<"$H") == *'.config'* || $c -lt 30 ]] && _ok || _no "the folder: [$(sed -n 2p <<<"$H")]"
done
case_ "deep in a repository: the folder and the one above it, the branch while there is room"
eq "$(headers 80 'cd ~/repos/fedokawaii/configs/home/.config' | sed -n 2p)" "I  home/.config  I  main*  I  exit"
eq "$(headers 20 'cd ~/repos/fedokawaii/configs/home/.config' | sed -n 2p)" "I  .config  I  exit"

# ── laid out anew when the width changes (ble.sh runs the prompt command again) ──
case_ "a second run under the same prompt (ble.sh's line number unchanged) only lays the line out for the new width — its result and time kept, nothing printed"
out=$(fn '_ble_edit_lineno=7; COLUMNS=156; cd ~/repos/fedokawaii/configs/home/.config
  __kawa_t0=$(( ${EPOCHREALTIME/[.,]/} - 4200000 )); (exit 3); __kawa_prompt >"$TMP/o1"; a=$__kawa_line
  COLUMNS=24; (exit 0); __kawa_prompt >"$TMP/o2"; b=$__kawa_line
  COLUMNS=156; __kawa_prompt >"$TMP/o3"; c=$__kawa_line
  printf "%s\n" "$a" "$b" "$c" | sed "s/\x01\|\x02//g; s/\x1b\[[0-9;]*m//g"
  wc -c <"$TMP/o2"; wc -c <"$TMP/o3"')
a=$(sed -n 1p <<<"$out") b=$(sed -n 2p <<<"$out") c=$(sed -n 3p <<<"$out")
[[ $a =~ \ \ 3\ \ 4\.[2-9]s\ \  ]] && _ok || _no "the first width: [$a]"
((${#b} < ${#a})) && _ok || _no "narrower: [$b]"; has "$b" "  3  " "its code kept (the run of exit 0 between is a redraw, not a command)"
eq "$c" "$a" "back to the first width: the same line"
eq "$(sed -n 4p <<<"$out")" 0 "nothing printed on a redraw (no OSC 133;D again, no title, no notice)"
eq "$(sed -n 5p <<<"$out")" 0
case_ "… and a new prompt (a new line number) is a new entry: its own result, foot told the status"
out=$(fn '_ble_edit_lineno=7; COLUMNS=80; __kawa_t0=$(( ${EPOCHREALTIME/[.,]/} - 10 )); (exit 3); __kawa_prompt >/dev/null
  _ble_edit_lineno=8; __kawa_t0=$(( ${EPOCHREALTIME/[.,]/} - 10 )); (exit 0); __kawa_prompt; printf "\n%s\n" "$__kawa_line" | sed "s/\x01\|\x02//g; s/\x1b\[[0-9;]*m//g"')
has "$out" $'\e]133;D;0\e\\'; lacks "$(tail -n1 <<<"$out")" "  3  "
case_ "without ble.sh every prompt is a new entry (bash never runs the prompt command twice)"
out=$(fn 'COLUMNS=80; __kawa_t0=$(( ${EPOCHREALTIME/[.,]/} - 10 )); (exit 3); __kawa_prompt >/dev/null; (exit 0); __kawa_prompt')
has "$out" $'\e]133;D;0\e\\'

# ── foot's reflow: where the prompt starts after the width changed ────────────
case_ "__kawa_reflow: nothing above the line typed on but the blank line — ble.sh goes up past it, the line typed on rewrapped"
# (ble.sh's state as it stands when a window is resized: the prompt drawn at the old width,
# the cursor on the line typed on; the stand-in for its cursor movement prints where it
# believes the cursor is when it goes to the prompt's top)
reflow() {   # reflow OLD NEW GAP Y X [PROY] [RPS1] → "y x" handed to ble.sh, or "theirs"
  fn "COLUMNS=$2 _ble_app_winsize=($1 30) _ble_canvas_panel_height=(4 0) _ble_prompt_ps1_data=(0 '' '' 0 ${6:-$((${3:-0} ? 1 : 0))})
    _ble_prompt_rps1_shown=${7-} __kawa_gap=$3 _ble_canvas_y=$4 _ble_canvas_x=$5
    ble/canvas/panel#goto.draw() { printf '%s %s\n' \"\$_ble_canvas_y\" \"\$_ble_canvas_x\"; }
    ble/canvas/bflush.draw() { :; }
    __kawa_reflow || echo theirs"
}
eq "$(reflow 95 50 1 1 30)" "1 30" "the blank line, then the line typed on: short enough, nothing wraps"
eq "$(reflow 95 50 1 1 70)" "2 20" "a line typed past 50 columns wraps: the cursor a row further down"
eq "$(reflow 95 50 '' 0 70)" "1 20" "no blank line (after clear, a short tile)"
eq "$(reflow 95 50 1 2 10)" "3 5" "a line on two rows at 95: 105 columns of it, three rows at 50"
eq "$(reflow 50 156 1 1 30)" "1 30" "wider: as it was"
eq "$(reflow 95 50 1 1 2 2)" theirs "another prompt (another number of rows): ble.sh's own redraw"
eq "$(reflow 95 50 1 1 2 '' 1)" theirs "a right-hand prompt: ble.sh's own"
eq "$(reflow 95 50 1 5 2)" theirs "the cursor below the prompt's panel (a menu): ble.sh's own"
case_ "a window nothing has run in yet (opened in a burst, retiled again and again): drawn again from the top, its width let settle first"
out=$(TERM=foot bash -ic "COLUMNS=50 _ble_app_winsize=(95 30) _ble_canvas_y=3 _ble_canvas_x=2
  ble/util/msleep() { echo sleep >>\"\$HOME/sleeps\"; }; ble/textarea#invalidate() { :; }; ble/canvas/panel/goto-top-dock.draw() { :; }
  ble/canvas/bflush.draw() { :; }; ble/util/buffer() { printf '%q' \"\$1\"; }; _ble_term_clear=CLEAR
  __kawa_reflow && printf ' %s %s' \"\$_ble_canvas_y\" \"\$_ble_canvas_x\"" 2>/dev/null)
eq "$out" "\$'CLEAR\\E[3J' 0 0" "the screen cleared, then its scrollback (3J after the clear: foot brings no row of the old heading back down)"; rm -f "$HOME/sleeps"
case_ "an entry once its command runs (ble.sh's final prompt): the same line, its torii's colour and all — the history a column of them"
got=$(fn 'cd ~/repos/fedokawaii; COLUMNS=120; __kawa_prompt >/dev/null; __kawa_t0=$(( ${EPOCHREALTIME/[.,]/} - 10 )); (exit 3); __kawa_prompt >/dev/null; [[ $__kawa_final == $'"'"'\n'"'"'"$__kawa_line" ]] && echo same')
eq "$got" same "the blank line, then the line itself"
got=$(fn 'cd ~/repos/fedokawaii; COLUMNS=188; __kawa_prompt >/dev/null; a=$__kawa_final; _ble_edit_lineno=1 __kawa_lineno=1 COLUMNS=20 __kawa_prompt; [[ $a != "$__kawa_final" ]] && echo relaid')
eq "$got" relaid "a change of width lays the final form out again too"
lacks "$(fn 'COLUMNS=80; __kawa_prompt >/dev/null; printf %s "$__kawa_final"')" $'\e]133;A' "no second prompt mark (foot's prompt jumps, and a typed session, count them)"
case_ "ble.sh shows it: prompt_ps1_final names it (set once ble.sh is loaded)"
grep -q "bleopt prompt_ps1_final='\${__kawa_final}'" "$HOME/.bashrc.d/fedokawaii.sh" && _ok || _no "no prompt_ps1_final"

# ── the real ble.sh: a window resized under a prompt ──────────────────────────
if [[ -n $BLESH_PIN && $(bash "$BLESH_DIR/ble.sh" --version 2>/dev/null) == *"+${BLESH_PIN:0:7}" ]]; then
  case_ "ble.sh ${BLESH_PIN:0:7}: its redraw on a change of width asks __kawa_reflow first"
  home; mkdir -p "$HOME/.local/share"; cp -a "$BLESH_DIR" "$HOME/.local/share/blesh"
  out=$(cd "$HOME" && LANG=C.UTF-8 TERM=foot python3 -I "$C/pty_run.py" --cols 80 --rows 24 --timeout 60 --quiet 1 --each '\x1b]133;A' \
    --line 'declare -f ble/function#advice/around:ble/application/onwinch/panel.process-redraw-here | grep -c "__kawa_reflow"' \
    --line exit -- bash -i 2>&1)
  has "$out" $'\e]133;C\e\\1\r' "the advice is in place"
  for step in "120x30 50x30" "50x30 156x30" "95x30 20x14"; do
    read -r from to <<<"$step"
    case_ "ble.sh ${BLESH_PIN:0:7}: a prompt up at ${from%x*} columns, the window made ${to%x*}: the line redrawn for ${to%x*}, its code kept"
    home; mkdir -p "$HOME/.local/share"; cp -a "$BLESH_DIR" "$HOME/.local/share/blesh"
    # (exit 3) run at the first width; the window resized; then the header as it stands
    # (the line the prompt shows: what a command typed next still sees of it)
    out=$(cd "$HOME/repos/fedokawaii/configs/home/.config" && LANG=C.UTF-8 TERM=foot python3 -I "$C/pty_run.py" \
      --cols "${from%x*}" --rows "${from#*x}" --timeout 60 --quiet 1 --each '\x1b]133;A' --line '(exit 3)' --line-resize "$to" \
      --line 'printf "LINE[%s] C=%s\\n" "$__kawa_line" "$COLUMNS"' --line exit -- bash -i 2>&1)
    h=$(grep -a -o 'LINE\[.*\] C=[0-9]*' <<<"$out" | tail -n1 | sed 's/\x01\|\x02//g; s/\x1b\[[0-9;]*m//g' | plain)
    eq "${h##* C=}" "${to%x*}" "the shell knows the new width: $h"
    h=${h#LINE[} h=${h%] C=*}
    w=$(width "$h")
    ((w <= ${to%x*} - 1)) && _ok || _no "$w wide: [$h]"
    [[ $h == *'  3  '* ]] && _ok || _no "the code: [$h]"
  done 2>/dev/null
else
  case_ "ble.sh resize"; skip "no ble.sh ${BLESH_PIN:0:7} at $BLESH_DIR (FEDOKAWAII_BLESH names one)"
fi

# ── the blank line before each entry: none in a short tile ───────────────────
home
case_ "the blank line before each prompt: kept from 10 rows, dropped under (a 20×4 tile would show ble.sh's \"(line 3) …\"), and after clear"
for rows in 40 14 10 9 8 4; do
  got=$(fn "LINES=$rows __kawa_fresh=0; __kawa_prompt >/dev/null; [[ \$PS1 == '\\n'* ]] && echo gap || echo none")
  if ((rows >= 10)); then eq "$got" gap "$rows rows"; else eq "$got" none "$rows rows"; fi
done
eq "$(fn 'LINES=40; __kawa_fresh=1; __kawa_prompt >/dev/null; [[ $PS1 == "\\n"* ]] && echo gap || echo none')" none "after clear"

# ── btop: the richest preset the window holds ─────────────────────────────────
home
case_ "btop's start: all five boxes from 80×35 (the graphics card's too), then the four without it, cpu over gpu over proc, cpu over proc, gpu over proc, cpu over gpu, proc, mem over net, mem — none under 36 columns (never the gpu box alone: btop 1.4.5 stops on it)"
sizes="188x47 115x47 92x47 69x47 60x47 44x47 69x28 69x17 41x17 24x17 24x10 24x5 140x41 92x17 115x28"
want="188x47:all 115x47:all 92x47:all 69x47:1 60x47:2 44x47:5 69x28:2 69x17:5 41x17:6 24x17: 24x10: 24x5: 140x41:all 92x17:5 115x28:0"
got=$(fn 'for s in '"$sizes"'; do __kawa_btop_preset ${s%x*} ${s#*x} 1; printf "%s:%s " $s "$__preset"; done')
eq "$got" "$want "
case_ "… and on a machine without a graphics card btop can read: the layouts without its box (all four boxes from 80×24)"
want="188x47:all 115x47:all 92x47:all 69x47:2 60x47:2 44x47:5 69x28:2 69x17:5 41x17:6 24x17: 24x10: 24x5: 140x41:all 92x17:5 115x28:all"
got=$(fn 'for s in '"$sizes"'; do __kawa_btop_preset ${s%x*} ${s#*x} 0; printf "%s:%s " $s "$__preset"; done')
eq "$got" "$want "
case_ "with or without the card's layouts: as btop.conf shows the card (theme.sh writes its box there only for a discrete AMD card)"
eq "$(fn '__kawa_btop_preset 69 47; echo "$__preset"')" 1 "a gpu box shown: cpu over gpu over proc"
sed -i 's/^shown_boxes = .*/shown_boxes = "cpu mem net proc"/' "$HOME/.config/btop/btop.conf"
eq "$(fn '__kawa_btop_preset 69 47; echo "$__preset"')" 2 "none: cpu over proc"
config .config/btop/btop.conf
case_ "btop.conf's presets are the layouts the shell's table names, each needing what btop says it needs (btop_tools.cpp's get_min_size), with the card and without"
python3 -I - "$HOME/.config/btop/btop.conf" "$(fn 'printf "%s\n" "${__kawa_btop_presets[@]}"')" <<'PY' && _ok || _no "the presets and the table disagree"
import re, sys
conf, table = open(sys.argv[1]).read(), sys.argv[2].split("\n")
shown = re.search(r'^shown_boxes = "(.*)"$', conf, re.M).group(1).split()
# "all": the boxes btop.conf shows (btop started without -p) · 0: btop's own, fixed · then btop.conf's
presets = {"all": ",".join(b + ":0:default" for b in shown), "0": "cpu:0:default,mem:0:default,net:0:default,proc:0:default"}
presets.update({str(i): v for i, v in enumerate(re.search(r'^presets = "(.*)"$', conf, re.M).group(1).split(), 1)})
MIN = {"cpu": (60, 8), "mem": (36, 10), "net": (36, 6), "proc": (44, 16), "gpu0": (41, 11)}
def need(boxes, gpu, first):   # btop 1.4's Term::get_min_size (a gpu box counts only where btop found a card)
    g = gpu and "gpu0" in boxes
    if not gpu and "gpu0" in boxes and not first: return None   # (a layout made for the card: skipped without one)
    w = MIN["mem"][0] if ("mem" in boxes or "net" in boxes) else 0
    w += MIN["proc"][0] if "proc" in boxes else 0
    if "cpu" in boxes: w = max(w, MIN["cpu"][0])
    if g: w = max(w, MIN["gpu0"][0])
    h = MIN["cpu"][1] if "cpu" in boxes else 0
    h += MIN["proc"][1] if "proc" in boxes else (MIN["mem"][1] if "mem" in boxes else 0) + (MIN["net"][1] if "net" in boxes else 0)
    h += MIN["gpu0"][1] if g else 0
    return w, h
ok = len(table) == len(presets) and "gpu0" in shown
for row in table:
    p, gw, gh, w, h = row.split()
    boxes = [b.split(":")[0] for b in presets[p].split(",")]
    w0, h0 = need(boxes, True, p == "all")
    # (btop's minimum — and with the card's box, 66 columns: its words take 41 at any width,
    # and its load graph gets 25 of its own)
    ok &= (int(gw), int(gh)) == ((max(w0, 66) if "gpu0" in boxes and p != "all" else w0), h0)
    ok &= need(boxes, False, p == "all") == (None if w == "-" else (int(w), int(h)))
    ok &= all(re.fullmatch(r"(cpu|mem|net|proc|gpu0):[01]:(default|braille|block|tty)", b) for b in presets[p].split(","))
    ok &= p == "all" or len(boxes) <= 4   # (btop takes four boxes a preset at most)
    ok &= boxes != ["gpu0"]                # (btop 1.4.5 stops on the gpu box alone)
sys.exit(0 if ok else 1)
PY
case_ "btop typed: started with that preset; a preset asked for (-p) is kept as asked"
stub btop
(cd "$HOME" && TERM=foot python3 -I "$C/pty_run.py" --cols 58 --rows 40 --timeout 20 --each '\x1b]133;A' --line btop --line 'btop -p 2' --line exit -- bash -i >/dev/null 2>&1)
called '^btop( -p [0-9])?$'; called '^btop -p 2$'
(cd "$HOME" && TERM=foot python3 -I "$C/pty_run.py" --cols 34 --rows 14 --timeout 20 --each '\x1b]133;A' --line btop --line exit -- bash -i >/dev/null 2>&1)
called '^btop ?$'

# ── lazygit: tall and narrow, the panels above the diff ───────────────────────
if [[ -n $REAL_LAZYGIT ]]; then
  for s in 156x40 77x40 58x40 37x40 58x24; do
    case_ "lazygit at ${s}: $([[ $s == 156x40 || $s == 58x24 ]] && echo "the panels beside the diff" || echo "the panels above the diff (portrait)")"
    home; config .config/lazygit
    # (no greeting, no notes on what changed since the last version: straight to the panels)
    mkdir -p "$XDG_STATE_HOME/lazygit"
    printf 'startuppopupversion: 99\nlastversion: %s\n' "$("$REAL_LAZYGIT" --version | sed -n 's/.*version=\([0-9.]*\),.*/\1/p')" \
      >"$XDG_STATE_HOME/lazygit/state.yml"
    out=$(python3 -I "$YD/drive.py" --size "$s" --cwd "$HOME/repos/fedokawaii" -- "$REAL_LAZYGIT" 2>&1 <<'EOF'
wait Status
settle
screen
quit q
EOF
)
    # the main view's frame — [0], whatever its title (delta draws the diff: "Diff"; git's
    # own: "Unstaged changes") —: its row, and the column its corner stands in
    read -r row col < <(python3 -I -c '
import sys
for y, l in enumerate(sys.stdin.read().split("\n")):
    i = l.find("[0]")
    if i >= 0:
        print(y, l.rfind("┌", 0, i)); break
else:
    print(-1, -1)' <<<"$out")
    if [[ $s == 156x40 || $s == 58x24 ]]; then ((col > 0 && row < 3)) && _ok || _no "the diff's frame at column $col: $out"
    else ((col == 0 && row > 5)) && _ok || _no "the diff's frame at row $row, column $col: $out"; fi
  done
else
  case_ "lazygit"; skip "lazygit is not installed"
fi

done_
