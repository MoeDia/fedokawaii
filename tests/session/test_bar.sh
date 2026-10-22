#!/usr/bin/env bash
# tests/session/test_bar.sh — the bar's buttons are lit (class "active") exactly while what
# they opened is on screen: kawa-bar's markers and their pids (the panel's own for its panels
# and dropdowns and the launcher — the panel's toggling: tests/menus/test_panel.sh; kawa-menu
# --launcher asks it), kawa-term --float's windows, the long-running modules woken by a poke, an opener
# killed with kill -9 (its button dark at the next poke); no tooltip while lit; and waybar's
# config and style: every opener apart from the bar, a click running only its command, no box
# (the patches are pictures), a tooltip or none (never the word "false").
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/../menus/lib.sh"

setup() {
  session_sandbox; waybar_up
  export FZ=$TMP/fz WAYLAND_DISPLAY=wayland-test
  mkdir -p "$FZ" "$TMP/bin"; : >"$FZ/answers"
  cp "$REPO/tests/menus/fake_panel" "$STUBS/kawa-panel"; chmod 755 "$STUBS/kawa-panel"   # (the menus' backend)
  . "$HOME/.config/fedokawaii/icons.sh"
  # a bar button's script, as kawa-calendar is: its rows into a dropdown (kawa-menu knows it
  # by its name)
  for s in kawa-calendar kawa-timer kawa-steam; do
    printf '#!/bin/bash\nprintf "a\\nb\\n" | kawa-menu --drop --width 32 "$@" >/dev/null\n' >"$TMP/bin/$s"; chmod 755 "$TMP/bin/$s"
  done
}
R=""; setrun() { R=$XDG_RUNTIME_DIR; }
alive() { sleep 300 >/dev/null 2>&1 6>&- 7>&- & P=$!; BG_PIDS+=("$P"); }   # a live opener: its pid in P
dead() { local p; sleep 0 >/dev/null 2>&1 & p=$!; wait "$p"; echo "$p"; }
until_() { local i; for ((i = 0; i < 1000; i++)); do eval "$1" && return 0; nap 0.01; done; return 1; }
wbexec() { python3 -B -c 'import json,sys; sys.path.insert(0,sys.argv[1]); import parsecheck as p
c=json.loads(p.strip_jsonc(open(sys.argv[2]).read())); print(c[sys.argv[3]][sys.argv[4]])' "$REPO/tests/static" "$REPO/configs/home/.config/waybar/config.jsonc" "$1" "${2:-exec}"; }

# ── kawa-bar: each item, lit by its marker's live pid ─────────────────────────────────
case_ "the items at rest: the torii, the cat, the date in English (Mon 19 Oct), the day's kanji"
setup; setrun
eq "$(kawa-bar torii)" "{\"text\":\"$ICON_TORII\"}"
eq "$(kawa-bar cat)" "{\"text\":\"$ICON_CAT\"}"
[[ $(LC_ALL=tr_TR.UTF-8 kawa-bar date) =~ ^\{\"text\":\"(Mon|Tue|Wed|Thu|Fri|Sat|Sun)\ [0-3][0-9]\ [A-Z][a-z]{2}\",\"class\":\"r[0-3]\"\}$ ]] && _ok || _no "date: $(kawa-bar date)"
# (its month's last letter's air, as a class: Jul's l 3 px, Oct's t 1, Nov's v none — width.sh)
mon() { M=$1 bash -c 'printf() { if [[ $1 == -v && $3 == "%(%a %d %b)T" ]]; then builtin printf -v "$2" %s "Thu 22 $M"; else builtin printf "$@"; fi; }
  export -f printf; kawa-bar date'; }
eq "$(mon Jul) $(mon Oct) $(mon Nov)" '{"text":"Thu 22 Jul","class":"r3"} {"text":"Thu 22 Oct","class":"r1"} {"text":"Thu 22 Nov","class":"r0"}' "the month's last letter's air"
k=(月 火 水 木 金 土 日); d=$(kawa-bar day); u=$(date +%u)
if ((u == 1)); then eq "$d" '{"text":"月","class":"mon"}'; else eq "$d" "{\"text\":\"${k[u - 1]}\"}"; fi
# (each weekday in turn: the clock's day stood in for — printf's %(%u)T, kawa-bar's only clock)
onday() { DAY=$1 bash -c 'printf() { if [[ $1 == -v && $3 == "%(%u)T" ]]; then builtin printf -v "$2" %s "$DAY"; else builtin printf "$@"; fi; }
  export -f printf; kawa-bar day'; }
eq "$(onday 1)" '{"text":"月","class":"mon"}' "Monday: 月 (13 px of ink in its 16) a class of its own, so style.css centres it"
eq "$(onday 2) $(onday 7)" '{"text":"火"} {"text":"日"}'
alive; echo "$P kawa-calendar" >"$R/kawa-drop.open"
eq "$(onday 1) $(onday 3)" '{"text":"月","class":["mon","active"]} {"text":"水","class":"active"}' "lit while the calendar is open"
rm -f "$R/kawa-drop.open"

case_ "each item and its marker: lit only while the pid in it lives (and, for a dropdown, only its own script's)"
alive; p=$P; d=$(dead)
while read -r item mark name; do
  rm -f "$R"/kawa-*.open
  rc 1 kawa-bar --lit "$item"
  if [[ $name == - ]]; then echo "$p" >"$R/$mark"; else echo "$p $name" >"$R/$mark"; fi
  rc 0 kawa-bar --lit "$item"
  if [[ $name != - ]]; then echo "$p kawa-power" >"$R/$mark"; rc 1 kawa-bar --lit "$item"; fi
  echo "$d${name/#-/}" >"$R/$mark"; [[ $name != - ]] && echo "$d $name" >"$R/$mark"; rc 1 kawa-bar --lit "$item"
  for junk in "" "-1" "0" "abc" "x $p"; do printf '%s\n' "$junk" >"$R/$mark"; rc 1 kawa-bar --lit "$item"; done
done <<'EOF'
torii kawa-launcher.open -
date kawa-drop.open kawa-calendar
day kawa-drop.open kawa-calendar
time kawa-drop.open kawa-timer
drives kawa-drop.open kawa-drives
steam kawa-drop.open kawa-steam
weather kawa-drop.open kawa-weather
layout kawa-drop.open kawa-tag
memory kawa-term-btop.open -
volume kawa-panel-sound.open -
brightness kawa-panel-brightness.open -
cat kawa-panel.open -
mode kawa-panel.open -
EOF
rm -f "$R"/kawa-*.open

case_ "lit: the cat smiles, the others take the class \"active\"; a module's own line keeps its classes"
alive; p=$P; echo "$p" >"$R/kawa-panel.open"
eq "$(kawa-bar cat)" "{\"text\":\"$ICON_CAT_HAPPY\",\"class\":\"active\"}"
echo "$p" >"$R/kawa-panel-brightness.open"
eq "$(kawa-bar brightness -- echo '{"text":"x","class":"a"}')" '{"text":"x","class":["a","active"]}'
eq "$(kawa-bar brightness -- echo '{"text":"x","class":["a","count"]}')" '{"text":"x","class":["active","a","count"]}'
eq "$(kawa-bar brightness -- echo '{"text":"x","tooltip":"t"}')" '{"text":"x","tooltip":"","class":"active"}' "lit: no tooltip (it would show behind its menu)"
eq "$(kawa-bar weather -- echo '{"text":"x","tooltip":"a \"b\" · c","class":"hot"}')" '{"text":"x","tooltip":"a \"b\" · c","class":"hot"}' "not lit: the tooltip as it came"
echo "$p kawa-weather" >"$R/kawa-drop.open"
eq "$(kawa-bar weather -- echo '{"text":"x","tooltip":"a \"b\" · c","class":"hot"}')" '{"text":"x","tooltip":"","class":["hot","active"]}' "lit: none (quotes inside it too)"
rm -f "$R/kawa-drop.open"
eq "$(kawa-bar brightness -- true)" "" "nothing printed: nothing added (the module hidden)"
rc 3 kawa-bar brightness -- sh -c 'echo "{\"text\":\"\"}"; exit 3'
rm -f "$R/kawa-panel-brightness.open"
eq "$(kawa-bar brightness -- echo '{"text":"x","class":"a"}')" '{"text":"x","class":"a"}' "not lit: the line as it came"
case_ "the mode seal: 静 or 共有 with a tooltip that says what it is and does; lit with quick settings"
stub makoctl 'echo do-not-disturb'
eq "$(kawa-bar mode)" '{"text":"静","class":["dnd","active"],"tooltip":""}'
rm -f "$R/kawa-panel.open"
eq "$(kawa-bar mode)" '{"text":"静","class":"dnd","tooltip":"do not disturb"}'
stub makoctl 'printf "sharing\ndefault\n"'; has "$(kawa-bar mode)" '"text":"共有"'
stub makoctl 'echo default'; eq "$(kawa-bar mode)" '{"text":""}'
case_ "the layout: kawa-dwlstatus's own line for this bar's monitor, lit by a layout menu"
mkdir -p "$R/dwl-bar/DP-1"; echo '{"text":"L","class":"spiral"}' >"$R/dwl-bar/DP-1/layout.json"; echo '{"text":"F","class":"float"}' >"$R/dwl-bar/layout.json"
eq "$(WAYBAR_OUTPUT_NAME=DP-1 kawa-bar layout)" '{"text":"L","class":"spiral"}'
eq "$(WAYBAR_OUTPUT_NAME=HDMI-A-1 kawa-bar layout)" '{"text":"F","class":"float"}' "another monitor: the focused one's"
alive; echo "$P kawa-tag" >"$R/kawa-drop.open"; eq "$(WAYBAR_OUTPUT_NAME=DP-1 kawa-bar layout)" '{"text":"L","class":["spiral","active"]}'
rm -f "$R/kawa-drop.open"
case_ "misuse"
rc 2 kawa-bar; rc 2 kawa-bar frobnicate; rc 2 kawa-bar --lit; rc 2 kawa-bar drives x; rc 0 kawa-bar --help

# ── kill -9: the button dark within one poke ─────────────────────────────────────────
case_ "quick settings killed with kill -9 (no trap runs): the cat dark at the next poke"
setup; setrun
cat_ex=$(wbexec custom/menu)
printf '#!/bin/bash\necho $$ >"$XDG_RUNTIME_DIR/kawa-panel.open"\nkawa-dwlstatus --poke 15\nexec sleep 300\n' >"$TMP/bin/kawa-panel"; chmod 755 "$TMP/bin/kawa-panel"
"$TMP/bin/kawa-panel" & kp=$!; BG_PIDS+=("$kp")
until_ '[[ -s $R/kawa-panel.open ]]'; nap 0.2
eq "$(pokes)" "12 15" "the cat poked (and the mode seal with it)"
eq "$(sh -c "$cat_ex")" "{\"text\":\"$ICON_CAT_HAPPY\",\"class\":\"active\"}" "lit while it runs"
kill -9 "$kp"; wait "$kp" 2>/dev/null
kawa-dwlstatus --poke 15; pokes >/dev/null  # the next poke, whoever sends it: the module runs again
eq "$(sh -c "$cat_ex")" "{\"text\":\"$ICON_CAT\"}" "dark: its marker is left, its pid dead"
case_ "the panel killed with kill -9 under a dropdown: its button dark at the next run (the marker's pid dead)"
alive; p=$P; echo "$p kawa-calendar" >"$R/kawa-drop.open"
d=$(LC_ALL=C date '+%a %d %b'); a=$(. "$HOME/.config/fedokawaii/width.sh"; air "$d"; echo "${__air#* }")
eq "$(kawa-bar date)" "{\"text\":\"$d\",\"class\":[\"active\",\"$a\"]}"
kill -9 "$p"; wait "$p" 2>/dev/null
eq "$(kawa-bar date)" "{\"text\":\"$d\",\"class\":\"$a\"}" "dark at the next run"
rm -f "$R/kawa-drop.open"

# ── the launcher: the panel's, lit while it shows it ──────────────────────────────────
case_ "the launcher (the torii, Super+Space): the panel's — kawa-menu --launcher asks it (\"toggle launcher\"), nothing else; the torii's click runs only that"
setup; setrun; menus_sandbox; setrun
reset_calls; rc 0 kawa-menu --launcher
until_ 'grep -q "^kawa-panel toggle launcher$" "$CALLS"' && _ok || _no "the panel was not asked: $(tr '\n' '|' <"$CALLS")"
eq "$(grep -c . "$CALLS")" 1 "one line, no menu of its own"
eq "$(wbexec custom/torii on-click)" "setsid -f kawa-menu --launcher"
rc 2 kawa-menu --launcher --drop
case_ "the torii lit exactly while the panel shows the launcher: its marker written by the panel's own mark() (its pid), read by kawa-bar; dark once it is taken away, or its pid dead"
out=$(python3 -I -B - "$REPO/bin/kawa-panel" <<'EOF' 2>&1
import importlib.machinery as m, importlib.util as u, os, subprocess, sys
sys.modules["gi"] = None
l = m.SourceFileLoader("kp", sys.argv[1]); k = u.module_from_spec(u.spec_from_loader("kp", l)); l.exec_module(k)
lit = lambda: subprocess.call(["kawa-bar", "--lit", "torii"])
drawn = lambda: subprocess.check_output(["kawa-bar", "torii"], text=True).strip()
k.mark("launcher", True)
print(lit(), open(k.MARKS["launcher"]).read().strip() == str(os.getpid()), drawn())
k.mark("launcher", False)
print(lit(), os.path.exists(k.MARKS["launcher"]), drawn())
EOF
)
eq "$out" "0 True {\"text\":\"$ICON_TORII\",\"class\":\"active\"}
1 False {\"text\":\"$ICON_TORII\"}"
dead >"$R/kawa-launcher.open"; rc 1 kawa-bar --lit torii; rm -f "$R/kawa-launcher.open"

# ── the pokes and the wakes ──────────────────────────────────────────────────────────
case_ "kawa-dwlstatus --poke 15 tells the mode seal too; every poke wakes the long-running modules' fifos"
setup; setrun
kawa-dwlstatus --poke 15; eq "$(pokes)" "12 15"
kawa-dwlstatus --poke 19 20; eq "$(pokes)" "19 20"
mkfifo "$R/kawa-bar.wake.$$" "$R/kawa-bar.wake.$(dead)"; exec 6<>"$R/kawa-bar.wake.$$"
kawa-dwlstatus --wake; read -r -t 1 -u 6 && _ok || _no "--wake: no line in the live module's fifo"
eq "$(ls "$R" | grep -c 'kawa-bar.wake')" 1 "the dead module's fifo taken away"
kawa-dwlstatus --poke 16; read -r -t 1 -u 6 && _ok || _no "--poke: no wake"
rc 2 kawa-dwlstatus --wake x
exec 6<&-; rm -f "$R/kawa-bar.wake.$$"

case_ "memory: lit while btop's window (kawa-term --float --once btop) is open, dark at the next wake once its pid is gone"
printf 'MemTotal: 33554432 kB\nMemAvailable: 27262976 kB\n' >"$TMP/mi"
KAWA_PROC_MEMINFO=$TMP/mi KAWA_MEM_EVERY=30 kawa-mem >"$TMP/mem" & BG_PIDS+=($!)
until_ '[[ -s $TMP/mem ]]'; lacks "$(tail -n1 "$TMP/mem")" active
has "$(tail -n1 "$TMP/mem")" '"tooltip":"RAM 18% of 32 GB"'
alive; p=$P; echo "$p" >"$R/kawa-term-btop.open"; kawa-dwlstatus --wake
until_ 'grep -q active "$TMP/mem"' && _ok || _no "not lit after a wake: $(tail -n1 "$TMP/mem")"
has "$(tail -n1 "$TMP/mem")" '"class":["calm","active"]'
kill -9 "$p"; wait "$p" 2>/dev/null; kawa-dwlstatus --wake
until_ '[[ $(tail -n1 "$TMP/mem") != *active* ]]' && _ok || _no "still lit: $(tail -n1 "$TMP/mem")"
case_ "the time: the clock and its menu's light (kawa-timer bar); the timer a cell of its own (kawa-timer bar timer), lit with it, empty while none runs"
kawa-timer bar >"$TMP/time" & BG_PIDS+=($!)
kawa-timer bar timer >"$TMP/tcell" & BG_PIDS+=($!)
until_ '[[ -s $TMP/tcell ]]'; eq "$(tail -n1 "$TMP/tcell")" '{"text":""}' "no timer: an empty cell (waybar hides it)"
until_ '[[ -s $TMP/time ]]'
[[ $(tail -n1 "$TMP/time") =~ ^\{\"text\":\"[01][0-9]:[0-5][0-9]:[0-5][0-9]\ [AP]M\"\}$ ]] && _ok || _no "$(tail -n1 "$TMP/time")"
alive; p=$P; echo "$p kawa-timer" >"$R/kawa-drop.open"; kawa-dwlstatus --wake
until_ '[[ $(tail -n1 "$TMP/time") == *active* ]]' && _ok || _no "not lit: $(tail -n1 "$TMP/time")"
kawa-timer start 10
until_ '[[ $(tail -n1 "$TMP/tcell") == *timer* ]]'
[[ $(tail -n1 "$TMP/tcell") =~ ^\{\"text\":\"$ICON_BAR_HOURGLASS(10:00|09:5[0-9])\",\"class\":\[\"timer\",\"active\"\]\}$ ]] && _ok || _no "the timer: $(tail -n1 "$TMP/tcell")"
[[ $(tail -n1 "$TMP/time") =~ ^\{\"text\":\"[01][0-9]:[0-5][0-9]:[0-5][0-9]\ [AP]M\",\"class\":\"active\"\}$ ]] && _ok || _no "the clock keeps to the time: $(tail -n1 "$TMP/time")"
kill -9 "$p"; wait "$p" 2>/dev/null; kawa-dwlstatus --wake
until_ '[[ $(tail -n1 "$TMP/time") != *active* && $(tail -n1 "$TMP/tcell") != *active* ]]' && _ok || _no "still lit: $(tail -n1 "$TMP/time") $(tail -n1 "$TMP/tcell")"
has "$(tail -n1 "$TMP/tcell")" '"class":"timer"'
kawa-timer cancel
until_ '[[ $(tail -n1 "$TMP/tcell") == "{\"text\":\"\"}" ]]' && _ok || _no "cancelled, still shown: $(tail -n1 "$TMP/tcell")"
case_ "the volume: PipeWire's level, mute and default output as they change (pw-mon's Node and Metadata blocks), lit by the sound panel"
echo "Volume: 0.62" >"$TMP/vol"
stub wpctl 'cat "$TMP/vol"'
mkfifo "$TMP/pw"; exec 7<>"$TMP/pw"
stub pw-mon 'exec cat "$TMP/pw"'
kawa-volume bar >"$TMP/v" 7>&- & vp=$!; BG_PIDS+=("$vp")
until_ '[[ -s $TMP/v ]]'
eq "$(tail -n1 "$TMP/v")" "{\"text\":\"$ICON_BAR_VOL_3""62<span fgalpha='55%'>%</span>\",\"tooltip\":\"volume 62%\"}"
echo "Volume: 0.25 [MUTED]" >"$TMP/vol"; n=$(wc -l <"$TMP/v")
printf 'added:\n\tid: 50\n\ttype: PipeWire:Interface:Client (version 3)\n' >&7; nap 0.3
eq "$(wc -l <"$TMP/v")" "$n" "a Client (every wpctl is one) changes nothing: no loop"
printf 'changed:\n\tid: 43\n\ttype: PipeWire:Interface:Node (version 3)\n' >&7
until_ '[[ $(tail -n1 "$TMP/v") == *off* ]]' && _ok || _no "the mute not drawn: $(tail -n1 "$TMP/v")"
eq "$(tail -n1 "$TMP/v")" "{\"text\":\"$ICON_BAR_VOL_MUTE<span fgalpha='55%'>off</span>\",\"tooltip\":\"muted\",\"class\":\"muted\"}"
for l in 0.00:$ICON_BAR_VOL_0 0.01:$ICON_BAR_VOL_1 0.25:$ICON_BAR_VOL_1 0.26:$ICON_BAR_VOL_2 0.50:$ICON_BAR_VOL_2 0.51:$ICON_BAR_VOL_3 0.76:$ICON_BAR_VOL_4 1.20:$ICON_BAR_VOL_4; do
  echo "Volume: ${l%%:*}" >"$TMP/vol"; printf 'changed:\n\ttype: PipeWire:Interface:Metadata (version 3)\n' >&7
  until_ '[[ $(tail -n1 "$TMP/v") == *"\"text\":\"${l#*:}"[0-9]* && $(tail -n1 "$TMP/v") != *off* ]]' && _ok || _no "at ${l%%:*}: $(tail -n1 "$TMP/v")"
done
alive; p=$P; echo "$p" >"$R/kawa-panel-sound.open"; kawa-dwlstatus --poke 16
until_ '[[ $(tail -n1 "$TMP/v") == *active* ]]' && _ok || _no "not lit by the sound panel: $(tail -n1 "$TMP/v")"
kill -9 "$p"; wait "$p" 2>/dev/null; kawa-dwlstatus --poke 16
until_ '[[ $(tail -n1 "$TMP/v") != *active* ]]' && _ok || _no "still lit: $(tail -n1 "$TMP/v")"
case_ "PipeWire gone (pw-mon ends): the module ends, its feeder and fifo with it (waybar starts it again)"
exec 7>&-                                    # (pw-mon's stand-in reads the end of its pipe)
until_ '! kill -0 '"$vp"' 2>/dev/null' && _ok || _no "still running"
until_ '[[ ! -e $R/kawa-bar.wake.'"$vp"' ]]' && _ok || _no "its fifo stayed"

case_ "kawa-term --float --once: its marker holds its pid while the window is open, gone after; the module woken both times"
setup; setrun
mkfifo "$R/kawa-bar.wake.$$"; exec 6<>"$R/kawa-bar.wake.$$"
stub footclient 'sleep 0.5'
kawa-term --float --once btop btop 112x33 -- btop & f=$!
until_ '[[ -s $R/kawa-term-btop.open ]]'; eq "$(cat "$R/kawa-term-btop.open")" "$f"
read -r -t 1 -u 6 && _ok || _no "not woken as it opened"
wait "$f"; [[ -e $R/kawa-term-btop.open ]] && _no "the marker stayed" || _ok
read -r -t 1 -u 6 && _ok || _no "not woken as it closed"
stub footclient 'exec sleep 31.5'; kawa-term --float --once btop btop 112x33 -- btop & f=$!
until_ '[[ -s $R/kawa-term-btop.open ]]'; kill -TERM "$f"; pkill -f "sleep 31.5"; wait "$f" 2>/dev/null
[[ -e $R/kawa-term-btop.open ]] && _no "killed (TERM): the marker stayed" || _ok
exec 6<&-

# ── the config and the style ─────────────────────────────────────────────────────────
case_ "waybar's config: every button that opens something runs it apart (setsid -f) — or asks the panel, which takes no time (kawa-quick); no module waits on 'interval: once'; a click runs only its command (\"exec-on-event\": false)"
C=$REPO/configs/home/.config/waybar/config.jsonc
python3 -B - "$REPO/tests/static" "$C" <<'EOF' && _ok || _no "see above"
import json, sys
sys.path.insert(0, sys.argv[1]); import parsecheck as p
c = json.loads(p.strip_jsonc(open(sys.argv[2]).read())); bad = 0
openers = {"kawa-menu", "kawa-calendar", "kawa-timer", "kawa-drives", "kawa-steam", "kawa-weather", "kawa-term", "kawa-panel", "kawa-downloads"}
for k, v in c.items():
    if not isinstance(v, dict): continue
    if v.get("interval") == "once": print(k, "interval once"); bad = 1
    for e in ("on-click", "on-click-right", "on-click-middle"):
        cmd = v.get(e, "")
        w = cmd.split()
        if w and w[0] in openers: print(k, e, cmd, "— not apart from the bar"); bad = 1
        if w[:2] == ["setsid", "-f"] and w[2] not in openers: print(k, e, cmd, "— apart, but opens nothing"); bad = 1
    if k.startswith("custom/") and "on-click" in v and v.get("exec-on-event") is not False:
        print(k, "— a click runs its module's command again (exec-on-event)"); bad = 1
sys.exit(bad)
EOF
eq "$(wbexec custom/volume on-click)" "kawa-quick sound"
eq "$(wbexec custom/brightness on-click)" "kawa-quick brightness"
eq "$(wbexec custom/menu on-click) $(wbexec custom/mode on-click)" "kawa-quick kawa-quick"
eq "$(wbexec custom/volume on-click-right) | $(wbexec custom/volume on-scroll-up) | $(wbexec custom/volume on-scroll-down)" "kawa-volume mute | kawa-volume up 2 | kawa-volume down 2"
eq "$(wbexec custom/torii on-click)" "setsid -f kawa-menu --launcher"
eq "$(wbexec custom/weather on-click)" "setsid -f kawa-weather --menu"
eq "$(wbexec custom/date on-click) $(wbexec custom/day on-click)" "setsid -f kawa-calendar setsid -f kawa-calendar"
eq "$(wbexec custom/time on-click)" "setsid -f kawa-timer"
case_ "each lit item's module answers the signal its opener pokes (the panel's: its panels, dropdowns and the launcher)"
for m in custom/torii:20 custom/date:19 custom/day:19 custom/drives:13 custom/steam:17 custom/weather:18 custom/brightness:14 custom/menu:15 custom/mode:12 custom/layout:9; do
  eq "$(wbexec "${m%:*}" signal)" "${m#*:}" "${m%:*}"
done
eq "$(python3 -I -B -c 'import importlib.machinery as m, importlib.util as u, sys
sys.modules["gi"] = None
l = m.SourceFileLoader("kp", sys.argv[1]); k = u.module_from_spec(u.spec_from_loader("kp", l)); l.exec_module(k)
print(*[f"{c}:{k.poke_sigs("menu " + c)}" for c in ("kawa-calendar", "kawa-drives", "kawa-steam", "kawa-weather", "kawa-tag", "kawa-timer")])' "$REPO/bin/kawa-panel")" \
  "kawa-calendar:[19] kawa-drives:[13] kawa-steam:[17] kawa-weather:[18] kawa-tag:[9] kawa-timer:[]" "the panel pokes each dropdown's button with its module's signal (the timer's: woken)"
eq "$(python3 -I -B -c 'import importlib.machinery as m, importlib.util as u, sys
sys.modules["gi"] = None
l = m.SourceFileLoader("kp", sys.argv[1]); k = u.module_from_spec(u.spec_from_loader("kp", l)); l.exec_module(k)
print(k.POKE["launcher"], k.poke_sigs("launcher"))' "$REPO/bin/kawa-panel")" "20 [20]" "the launcher: the panel pokes the torii's +20"
case_ "tooltips: a module either says what it is and does (a string from its JSON), or none at all (\"tooltip\": false) — never a JSON false (waybar shows the word)"
python3 -B - "$REPO/tests/static" "$C" <<'EOF' && _ok || _no "see above"
import json, sys
sys.path.insert(0, sys.argv[1]); import parsecheck as p
c = json.loads(p.strip_jsonc(open(sys.argv[2]).read())); bad = 0
says = {"custom/mode", "custom/steam", "custom/mem", "custom/volume", "custom/brightness", "custom/weather"}
for k, v in c.items():
    if not isinstance(v, dict) or not k.startswith("custom/") or "exec" not in v and "format" not in v: continue
    if k in says:
        if "tooltip" in v: print(k, "has a tooltip of its own: none in the config"); bad = 1
    elif v.get("tooltip") is not False: print(k, "says nothing: \"tooltip\": false"); bad = 1
sys.exit(bad)
EOF
lacks "$(grep -h -- '"tooltip":false\|tooltip: false\|"tooltip": false' "$REPO"/bin/kawa-* 2>/dev/null)" tooltip "a script's JSON with a tooltip of false"
case_ "the style (紙 kami): no bar of its own — tiles of washi; every colour one of waybar.css's tokens; no ring anywhere; the workspaces by their numeral's ink, where you are a seal; every lit item recoloured, nothing else"
S_=$REPO/configs/home/.config/waybar/style.css
grep -q '^window#waybar { background: transparent;' "$S_" && _ok || _no "the bar has a ground of its own"
toks=" $(sed -n 's/^@define-color \([a-z-]*\) .*/\1/p' "$REPO/configs/home/.config/fedokawaii/themes/dark/waybar.css" | tr '\n' ' ')"
eq "$toks" " faint muted text strong accent-text strong-on-accent asagi tile kami-red seal-ink " "waybar.css: these and no more"
for t in light; do eq " $(sed -n 's/^@define-color \([a-z-]*\) .*/\1/p' "$REPO/configs/home/.config/fedokawaii/themes/$t/waybar.css" | tr '\n' ' ')" "$toks" "$t: the same names"; done
bad=""; for u in $(grep -o '@[a-z-]*' "$S_" | grep -v '^@import' | sort -u); do [[ $toks == *" ${u#@} "* ]] || bad+=" $u"; done
eq "${bad:-none}" none "style.css names a colour waybar.css does not define"
bad=$(grep -nE 'background(-color)?: *@' "$S_" | grep -vE '@(tile|kami-red);')
eq "$bad" "" "a ground other than the paper's or the corners' vermilion"
grep -q 'box-shadow: *inset' "$S_" && _no "a ring is back" || _ok
lacks "$(cat "$REPO/configs/home/.config/foot/foot.ini")" $'\n24=' "foot's palette has no tile colour of the bar's (24) any more"
st() { grep -E "^\.tag\.$1 *\{" -A4 "$S_" | tr -d '\n'; }
has "$(st occupied)" "color: @text;" "a workspace with windows: its numeral in the text's ink"
has "$(st urgent)" "color: @asagi;" "one asking for you: asagi"
has "$(st selected)" "color: @seal-ink;" "where you are: on the seal, the paper's ink"
has "$(st selected)" 'url("../fedokawaii/current/kami-seal.png")'
has "$(grep -E '^\.tag \{' "$S_")" "color: @faint;" "an empty one: faint"
for m in custom-torii custom-layout custom-menu custom-steam custom-mem custom-volume custom-brightness custom-weather custom-drives custom-date custom-day custom-time custom-mode; do
  grep -q "#$m\.active" "$S_" && _ok || _no "#$m has no lit look"
done
python3 -I - "$S_" <<'EOF' && _ok || _no "see above"
import re, sys
css = re.sub(r"/\*.*?\*/", "", open(sys.argv[1]).read(), flags=re.S); bad = 0
for sel, body in re.findall(r"([^{}]+)\{([^}]*)\}", css):
    if ".active" in sel:
        props = {p.split(":")[0].strip() for p in body.split(";") if ":" in p}
        if props != {"color"}: print(sel.strip(), "changes", props); bad = 1
sys.exit(bad)
EOF

done_
