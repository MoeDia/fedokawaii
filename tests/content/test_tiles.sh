#!/usr/bin/env bash
# tests/content/test_tiles.sh — the terminal at every size dwl tiles it to on a 1920×1080
# screen (gap 8, border 2; Fusion Pixel 10 at 20 px: 10 × 22 px cells, 10 px of paper round):
#   spiral   1900×1060 → 188×47 · 1170×1060 → 115×47 · 718×1060 → 69×47 · 718×650 → 69×28
#            718×398 → 69×17 · 439×398 → 41×17 · 267×398 → 24×17 · 267×241 → 24×10 · 267×145 → 24×5
#   columns  944 → 92×47 · 625 → 60×47 · 466 → 44×47
# The prompt's header (~/.bashrc.d/fedokawaii.sh): its layout as pure functions — which form
# fits, the path's three lengths, the cut in the middle — then real headers in a terminal of
# each width, the header laid out anew when the width changes under it (ble.sh runs the
# prompt command again then), and with the real ble.sh, when one is at hand, a window
# resized under a prompt. btop's start (the richest preset its window holds) and lazygit's
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
fn() { TERM=${T_TERM:-foot} bash -ic "$1" 2>/dev/null; }   # fn CODE — CODE in an interactive shell of the home
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

# ── the pure functions ────────────────────────────────────────────────────────
home
case_ "__kawa_fit: the richest form whose rule is still 6 columns or more (lead 3; the path 42/20/13; git 22, the branch 9; ✓ 2, the clock 15)"
# (COLS → the form: 0 all · 1 the folders above to letters · 2 no clock · 3 the folder alone ·
#  4 no git counts · 5 no time taken · 6 no branch · n no rule)
want="156:0 95:0 93:0 92:1 77:1 71:1 70:2 58:2 56:2 55:3 50:3 49:3 48:4 37:4 36:4 35:6 34:6 30:6 29:n 20:n"
got=$(fn 'for c in 156 95 93 92 77 71 70 58 56 55 50 49 48 37 36 35 34 30 29 20; do
  __kawa_fit $c 3 42 20 13 22 9 0 2 0 15; printf "%s:%s " $c $__fit; done')
eq "$got" "$want "
case_ "__kawa_fit: the time a slow command took goes after the clock and the git counts, before the branch"
got=$(fn 'for c in 41 40 36 35; do __kawa_fit $c 3 13 13 13 22 9 0 2 5 15; printf "%s:%s " $c $__fit; done')
eq "$got" "41:4 40:5 36:5 35:6 "
case_ "__kawa_fit: no rule at all under 30 columns, however little there is to show"
eq "$(fn '__kawa_fit 29 3 1 1 1 0 0 0 0 0 0; echo $__fit')" n
eq "$(fn '__kawa_fit 30 3 1 1 1 0 0 0 0 0 0; echo $__fit')" 0
case_ "__kawa_paths: as it is · the folders above to their first letter (a dot folder keeps its dot) · the folder alone"
out=$(fn '__kawa_paths "~/repos/fedokawaii/configs/home/.config"; printf "%s|" "${__kp_d[@]}" "$__kp_h" "${__kp_dw[@]}" "$__kp_hw"')
eq "$out" "~/repos/fedokawaii/configs/home/|~/r/f/c/h/|… /|.config|32|10|3|7|"
out=$(fn '__kawa_paths "/usr/share/.icons/Papirus"; printf "%s|" "${__kp_d[@]}" "$__kp_h"')
eq "$out" "/usr/share/.icons/|/u/s/.i/|… /|Papirus|"
case_ "__kawa_paths: never longer than the form before it — ~, /, ~/repos and /usr stay as they are"
for p in '~' / '~/repos' /usr; do
  out=$(fn "__kawa_paths '$p'; printf '%s' \"\${__kp_d[2]}\$__kp_h\"")
  eq "$out" "$p"
done
case_ "__kawa_paths: a folder named in Japanese counts two columns a letter; its first letter is kept whole"
out=$(fn '__kawa_paths "~/日本語のフォルダ/中"; printf "%s|" "${__kp_d[1]}" "${__kp_dw[0]}" "${__kp_dw[1]}" "$__kp_hw"')
eq "$out" "~/日/|19|5|2|"
case_ "__kawa_cut: in the middle with …, never wider than asked (foot's … is two columns: its second half)"
for m in 30 12 7 3; do
  out=$(fn "__kawa_cut 'a-folder-whose-name-is-far-longer' $m; printf '%s' \"\$__cut\"")
  [[ $(width "$out") -le $m ]] && _ok || _no "$m: [$out] is $(width "$out") wide"
done
eq "$(fn "__kawa_cut 'a-folder-whose-name-is-far-longer' 12; printf '%s' \"\$__cut\"")" "a-fol… onger"
eq "$(fn "__kawa_cut short 12; printf '%s' \"\$__cut\"")" short

# ── real headers at every tile's width ────────────────────────────────────────
for c in $WIDTHS; do
  H=$(headers "$c" 'cd ~/repos/fedokawaii/configs/home/.config' '(exit 3)' 'cd ~/a-folder-whose-name-is-far-longer-than-any-small-tile-is-wide' \
      'cd ~/日本語のフォルダ' '__kawa_t0=$((__kawa_t0 - 4200000))')
  case_ "$c columns: every header on one line, never wider than one column short of the edge (with a rule: exactly that)"
  eq "$(wc -l <<<"$H")" 6 "six prompts: $H"
  while IFS= read -r h; do
    w=$(width "$h")
    if ((c >= 30)) && [[ $h == *╌* ]]; then eq "$w" $((c - 1)) "[$h]"; else ((w <= c - 1)) && _ok || _no "$w wide: [$h]"; fi
  done <<<"$H"
  case_ "$c columns: after every command its mark — ✓, or ✗ and the code — at the header's right end, never dropped"
  # (then, when there is room: the time it took, the sky and the clock)
  for i in 2 3 4 5 6; do
    h=$(sed -n "${i}p" <<<"$H") m='V '; ((i == 3)) && m='X  3'
    [[ $h =~ ${m}(\ +[0-9]+\.[0-9]s)?(\ +I\ \ [0-9]{2}:[0-9]{2}:[0-9]{2}\ [AP]M)?$ ]] && _ok || _no "header $i: [$h]"
  done
  ((c >= 50)) && { has "$(sed -n 6p <<<"$H")" "V  4.2s" "the time taken"; }
  case_ "$c columns: the stitch (╌), from 30 columns up — none below"
  if ((c >= 30)); then [[ $(sed -n 2p <<<"$H") == *╌╌╌╌╌╌* ]] && _ok || _no "no rule: $(sed -n 2p <<<"$H")"
  else lacks "$H" ╌; fi
done
case_ "the deep path at each width: whole, then the folders above to letters, then the folder alone"
eq "$(headers 156 'cd ~/repos/fedokawaii/configs/home/.config' | sed -n 2p | cut -c1-59)" "I   ~/repos/fedokawaii/configs/home/.config  I  main +1 ?1 "
has "$(headers 77 'cd ~/repos/fedokawaii/configs/home/.config' | sed -n 2p)" "I   ~/r/f/c/h/.config  I  main +1 ?1 ╌"
has "$(headers 37 'cd ~/repos/fedokawaii/configs/home/.config' | sed -n 2p)" "I   … /.config  I  main ╌"
eq "$(headers 20 'cd ~/repos/fedokawaii/configs/home/.config' | sed -n 2p)" "I   … /.config   V "
case_ "a folder name longer than a small tile: no ~/ before it, cut in its middle, the mark still at the edge"
h=$(headers 20 'cd ~/a-folder-whose-name-is-far-longer-than-any-small-tile-is-wide' | sed -n 2p)
eq "$h" "I   a-fol… wide  V "

case_ "the stitch: ╌ in foot's colour 19 (edge2, the panels' stitched rules), both palettes have it; on the consoles - , faint"
out=$(fn 'COLUMNS=60; __kawa_prompt >/dev/null; printf "%s" "$__kawa_line"'); has "$out" $'\e[38;5;19m\002╌╌╌╌'
out=$(T_TERM=linux fn 'COLUMNS=60; __kawa_prompt >/dev/null; printf "%s" "$__kawa_line"'); has "$out" $'\e[90m\002----'; lacks "$out" ╌
eq "$(grep -c '^19=' "$REPO/configs/home/.config/foot/foot.ini")" 2

# ── laid out anew when the width changes (ble.sh runs the prompt command again) ──
case_ "a second run under the same prompt (ble.sh's line number unchanged) only lays the header out for the new width"
out=$(fn '_ble_edit_lineno=7; COLUMNS=156; cd ~/repos/fedokawaii/configs/home/.config
  __kawa_t0=$(( ${EPOCHREALTIME/[.,]/} - 4200000 )); (exit 3); __kawa_prompt >"$TMP/o1"; a=$__kawa_line
  COLUMNS=50; (exit 0); __kawa_prompt >"$TMP/o2"; b=$__kawa_line
  COLUMNS=156; __kawa_prompt >"$TMP/o3"; c=$__kawa_line
  printf "%s\n" "$a" "$b" "$c" | sed "s/\x01\|\x02//g; s/\x1b\[[0-9;]*m//g"
  wc -c <"$TMP/o2"; wc -c <"$TMP/o3"')
a=$(sed -n 1p <<<"$out") b=$(sed -n 2p <<<"$out") c=$(sed -n 3p <<<"$out")
eq "$(width "$a")" 155; eq "$(width "$b")" 49 "[$b]"; eq "$c" "$a" "back to the first width: the same header, clock and all"
has "$b" "  3"; has "$b" "4.2s"
eq "$(sed -n 4p <<<"$out")" 0 "nothing printed on a redraw (no OSC 133;D again, no title, no notice)"
eq "$(sed -n 5p <<<"$out")" 0
case_ "… and a new prompt (a new line number) is a new entry: its own mark, foot told the status"
out=$(fn '_ble_edit_lineno=7; COLUMNS=80; __kawa_t0=$(( ${EPOCHREALTIME/[.,]/} - 10 )); (exit 3); __kawa_prompt >/dev/null
  _ble_edit_lineno=8; (exit 0); __kawa_prompt; printf "\n%s\n" "$__kawa_line" | sed "s/\x01\|\x02//g; s/\x1b\[[0-9;]*m//g"')
has "$out" $'\e]133;D;0\e\\'; lacks "$(tail -n1 <<<"$out")" "  3"
case_ "without ble.sh every prompt is a new entry (bash never runs the prompt command twice)"
out=$(fn 'COLUMNS=80; __kawa_t0=$(( ${EPOCHREALTIME/[.,]/} - 10 )); (exit 3); __kawa_prompt >/dev/null; (exit 0); __kawa_prompt')
has "$out" $'\e]133;D;0\e\\'

# ── foot's reflow: where the prompt starts after the width changed ────────────
case_ "__kawa_reflow: the header that filled 95 columns takes 2 rows at 50, 5 at 20 — ble.sh goes up past all of them (no header left above the new one)"
# (ble.sh's state as it stands when a window is resized: the prompt drawn at the old width,
# the cursor on the line typed on; the stand-in for its cursor movement prints where it
# believes the cursor is when it goes to the prompt's top)
reflow() {   # reflow OLD NEW GAP HW Y X [PROY] [RPS1] → "y x" handed to ble.sh, or "theirs"
  fn "COLUMNS=$2 _ble_app_winsize=($1 30) _ble_canvas_panel_height=(4 0) _ble_prompt_ps1_data=(0 '' '' 0 ${7:-$(($3 + 1))})
    _ble_prompt_rps1_shown=${8-} __kawa_gap=$3 __kawa_hw=$4 _ble_canvas_y=$5 _ble_canvas_x=$6
    ble/canvas/panel#goto.draw() { printf '%s %s\n' \"\$_ble_canvas_y\" \"\$_ble_canvas_x\"; }
    ble/canvas/bflush.draw() { :; }
    __kawa_reflow || echo theirs"
}
eq "$(reflow 95 50 1 94 2 2)" "3 2" "the blank line, the header on 2 rows, then the line typed on"
eq "$(reflow 95 20 1 94 2 2)" "6 2" "five rows of header at 20 columns"
eq "$(reflow 95 20 '' 94 1 2)" "5 2" "no blank line (after clear, a short tile)"
eq "$(reflow 50 156 1 49 2 2)" "2 2" "wider: nothing wraps, the prompt starts where it did"
eq "$(reflow 95 95 1 94 2 2)" "2 2" "the same width (a change of height): as it was"
eq "$(reflow 95 50 1 94 2 70)" "4 20" "a command typed past 50 columns wraps too: the cursor a row further down"
eq "$(reflow 95 50 1 94 3 10)" "5 5" "a command on two rows at 95: 105 columns of it, three rows at 50"
eq "$(reflow 20 156 1 19 2 2)" "2 2" "a 20-column header in 156: one row"
eq "$(reflow 95 50 1 94 2 2 1)" theirs "another prompt (another number of rows): ble.sh's own redraw"
eq "$(reflow 95 50 1 94 2 2 '' 1)" theirs "a right-hand prompt: ble.sh's own"
eq "$(reflow 95 50 1 94 5 2)" theirs "the cursor below the prompt's panel (a menu): ble.sh's own"
case_ "the header's width as __kawa_reflow counts it: what __kawa_layout drew, every width"
for c in 156 95 77 58 50 37 34 30 29 20 12; do
  got=$(fn "cd ~/repos/fedokawaii; COLUMNS=$c; __kawa_t0=\$(( \${EPOCHREALTIME/[.,]/} - 10 )); (exit 3); __kawa_prompt >/dev/null
    printf '%s|%s' \"\$__kawa_hw\" \"\$__kawa_line\" | sed 's/\x01\|\x02//g; s/\x1b\[[0-9;]*m//g'" | plain)
  eq "${got%%|*}" "$(width "${got#*|}")" "$c columns: [${got#*|}]"
done
case_ "an entry once its command runs (ble.sh's final prompt): the header without the stitch — everything else kept, laid out again with the width"
for c in 188 69 24; do
  got=$(fn "cd ~/repos/fedokawaii; COLUMNS=$c; __kawa_t0=\$(( \${EPOCHREALTIME/[.,]/} - 10 )); (exit 3); __kawa_prompt >/dev/null
    printf '%s' \"\$__kawa_final\" | sed 's/\x01\|\x02//g; s/\x1b\[[0-9;]*m//g; s/\x1b\]133;A\x1b\\\\//'" | plain)
  lacks "$got" "╌" "$c: [$got]"; has "$got" "X  3" "$c: the mark"; has "$got" "fedokawaii" "$c: the place"
  [[ $got == *$'\n'?' ' && $got != *$'\n'*$'\n'*$'\n'* ]] && _ok || _no "$c: the header, then the line typed on: [$got]"
done
got=$(fn 'cd ~/repos/fedokawaii; COLUMNS=188; __kawa_prompt >/dev/null; a=$__kawa_final; _ble_edit_lineno=1 __kawa_lineno=1 COLUMNS=30 __kawa_prompt; [[ $a != "$__kawa_final" ]] && echo relaid')
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
    case_ "ble.sh ${BLESH_PIN:0:7}: a prompt up at ${from%x*} columns, the window made ${to%x*}: the header redrawn for ${to%x*}, its mark kept"
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
    if ((${to%x*} >= 30)); then eq "$w" $((${to%x*} - 1)) "[$h]"; else ((w <= ${to%x*} - 1)) && _ok || _no "$w wide: [$h]"; fi
    [[ $h =~ X\ \ 3($|\ \ ) ]] && _ok || _no "the mark: [$h]"
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
