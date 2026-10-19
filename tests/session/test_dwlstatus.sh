#!/usr/bin/env bash
# tests/session/test_dwlstatus.sh — kawa-dwlstatus, the reader of dwl's status stream that
# writes the bar's files (workspaces, layout, window title, keyboard layout) and pokes waybar.
# The streams: fixtures/*.status were recorded from the real patched dwl 0.9 (headless, one
# monitor; two, then a third plugged in, the focused one pulled out, another plugged in);
# the rest is written here line by line as dwl prints it (lib.sh block). waybar is a stand-in
# that counts each signal (fake_waybar.py).
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"
F=$SD/fixtures
# shellcheck source=/dev/null
. "$REPO/configs/home/.config/fedokawaii/icons.sh"

# upto FILE PATTERN [BLOCKS] — FILE up to the end of the block where PATTERN first appears
# (and BLOCKS more blocks after it)
upto() { awk -v p="$2" -v n="${3:-0}" '{ print } !hit && index($0, p) { hit = 1 } hit && / kblayout / { if (n-- <= 0) exit }' "$1"; }
# blk FILE PATTERN [BLOCKS] — only that block (and BLOCKS more): with one monitor every block
# is the whole state, so the bar must come out the same as after the whole session up to there
blk() { awk -v p="$2" -v n="${3:-0}" '$2 == "title" { b = "" } { b = b $0 "\n" } !hit && index($0, p) { hit = 1 }
  $2 == "kblayout" { if (hit) { printf "%s", b; if (n-- <= 0) exit } b = "" }' "$1"; }
# title_is WANT — the title the bar shows is WANT, and valid Pango markup (waybar shows a
# custom module's text as markup): nothing printed when both hold
title_is() {
  python3 -I - "$BAR/title.json" "$1" <<'EOF'
import json, sys, xml.etree.ElementTree as E
t = json.load(open(sys.argv[1], encoding="utf-8"))["text"]
if t != sys.argv[2]:
    print(f"shows [{t[:200]}], wanted [{sys.argv[2][:200]}]")
try:
    E.fromstring("<markup>" + t + "</markup>")
except Exception as e:
    print(f"not valid markup: {e}")
EOF
}
# delta A B — the pokes that B adds after A (a stream of A then B, less A on its own)
delta() {
  local a b x out=""; local -a c=()
  rm -rf "$BAR"; status "$1"; a=$(pokes)
  rm -rf "$BAR"; status "$1" "$2"; b=$(pokes)
  for x in $b; do ((c[x]++)); done; for x in $a; do ((c[x]--)); done
  for x in "${!c[@]}"; do while ((c[x]-- > 0)); do out+="$x "; done; done
  printf '%s' "${out% }"
}
wbexec() {   # wbexec MODULE — the command waybar's config runs for that module
  python3 -I - "$REPO/configs/home/.config/waybar/config.jsonc" "$1" <<'EOF'
import json, sys
src, out, i, s = open(sys.argv[1], encoding="utf-8").read(), [], 0, False
while i < len(src):          # JSONC → JSON: drop // comments outside strings
    c = src[i]
    if s:
        out.append(c)
        if c == "\\": out.append(src[i + 1]); i += 1
        elif c == '"': s = False
    elif c == '"': s = True; out.append(c)
    elif src.startswith("//", i):
        while i < len(src) and src[i] != "\n": i += 1
        continue
    else: out.append(c)
    i += 1
print(json.loads("".join(out))[sys.argv[2]]["exec"])
EOF
}

# ── the recorded sessions ────────────────────────────────────────────────────
session_sandbox; waybar_up
# a Turkish and an Arabic locale from glibc's own definitions, built meanwhile (LOCPATH): the
# Turkish one is where capitals differ from English (i → İ). C.UTF-8 stays reachable beside them.
mkdir -p "$TMP/locale"; cp -r /usr/lib/locale/C.utf8 "$TMP/locale/" 2>/dev/null   # (a copy: nothing written here reaches /usr)
{ localedef -i tr_TR -f UTF-8 "$TMP/locale/tr_TR.UTF-8"; localedef -i ar_EG -f UTF-8 "$TMP/locale/ar_EG.UTF-8"; } >/dev/null 2>&1 &
LOCPID=$!; BG_PIDS+=("$LOCPID")
case_ "a whole recorded session (one monitor, real dwl): the bar ends where dwl did, every file valid JSON"
rc 0 status "$F/one-monitor.status"
eq "$(tagrow)" "1:emp 2:sel 3:emp 4:- 5:- 6:- 7:- 8:- 9:-" "after quitting: no windows, workspace 2 shown"
eq "$(bar layout)" "{\"text\":\"$ICON_SPIRAL\",\"class\":\"spiral\"}"
eq "$(bar title)" '{"text":""}'
eq "$(bar kb)" '{"text":"US","class":"first"}'
eq "$(json_ok)" ""
eq "$(find "$BAR" -name '*.tmp' | wc -l)" 0 "no half-written file left"

case_ "recorded: a window asks for attention on workspace 1 while 2 is shown; 5 holds a window"
rm -rf "$BAR"; blk "$F/one-monitor.status" "tags 19 2 2 1" | kawa-dwlstatus
eq "$(tagrow)" "1:urg 2:sel 3:emp 4:- 5:occ 6:- 7:- 8:- 9:-"
eq "$(jtext title)" "日本語のタイトル・テスト"
case_ "recorded: monocle's [2] (an older session; monocle is gone): a symbol it does not know, as text; then the floating layout"
rm -rf "$BAR"; blk "$F/one-monitor.status" "layout [2]" | kawa-dwlstatus
eq "$(bar layout)" '{"text":"[2]","class":"other"}'
eq "$(title_is 'bell &lt;b&gt;&amp;amp; "q" \x $(id) `id`')" "" "a title with markup, quotes, \$(…) and backticks: shown as typed"
rm -rf "$BAR"; blk "$F/one-monitor.status" "layout ><>" | kawa-dwlstatus
eq "$(bar layout)" "{\"text\":\"$ICON_FLOAT\",\"class\":\"float\"}"
case_ "recorded: Alt+Shift to Arabic shows AR, back to US"
rm -rf "$BAR"; blk "$F/one-monitor.status" "kblayout 1" | kawa-dwlstatus
eq "$(bar kb)" '{"text":"AR","class":"other"}'
rm -rf "$BAR"; blk "$F/one-monitor.status" "kblayout 1" 1 | kawa-dwlstatus
eq "$(bar kb)" '{"text":"US","class":"first"}'
case_ "recorded: a 2048-character title (foot's limit) and a title emptied by its program"
rm -rf "$BAR"; blk "$F/one-monitor.status" "title xxxxxxxxxx" | kawa-dwlstatus
eq "$(jtext title | wc -c)" 2049
rm -rf "$BAR"; blk "$F/one-monitor.status" "title xxxxxxxxxx" 1 | kawa-dwlstatus
eq "$(bar title)" '{"text":""}'

case_ "recorded hot-plug: two monitors, each bar its own, the top files the focused one's"
rm -rf "$BAR"; upto "$F/hotplug.status" "HEADLESS-3" | head -n -8 | kawa-dwlstatus
m=("$BAR"/HEADLESS-*); eq "${#m[@]}" 2
eq "$(tagrow HEADLESS-1/)" "1:occ 2:emp 3:sel 4:- 5:- 6:- 7:- 8:- 9:-" "HEADLESS-1: workspace 3 shown, windows on 1 and 3"
eq "$(tagrow HEADLESS-2/)" "1:sel 2:emp 3:emp 4:- 5:- 6:- 7:- 8:- 9:-"
eq "$(tagrow)" "$(tagrow HEADLESS-2/)" "the focused monitor (HEADLESS-2) at the top"
case_ "recorded hot-plug: a third monitor plugged in gets its own bar files"
rm -rf "$BAR"; upto "$F/hotplug.status" "HEADLESS-3 kblayout" | kawa-dwlstatus
eq "$(tagrow HEADLESS-3/)" "1:sel 2:emp 3:emp 4:- 5:- 6:- 7:- 8:- 9:-"
eq "$(tagrow)" "$(tagrow HEADLESS-2/)" "the focus stays where it was"
case_ "recorded hot-plug: the focused monitor pulled out — the top follows the focus to the next one"
rm -rf "$BAR"; upto "$F/hotplug.status" "HEADLESS-3 selmon 1" | kawa-dwlstatus
eq "$(tagrow)" "$(tagrow HEADLESS-3/)"
eq "$(jtext title)" "$(jtext HEADLESS-3/title)"
eq "$(tagrow HEADLESS-3/)" "1:sel 2:emp 3:emp 4:- 5:- 6:- 7:- 8:- 9:-" "its window moved over"
case_ "recorded hot-plug, whole: four monitors seen, every file valid JSON, focus back on HEADLESS-1"
rm -rf "$BAR"; rc 0 status "$F/hotplug.status"
eq "$(cd "$BAR" && ls -d HEADLESS-* | tr '\n' ' ')" "HEADLESS-1 HEADLESS-2 HEADLESS-3 HEADLESS-4 "
eq "$(tagrow)" "$(tagrow HEADLESS-1/)"
eq "$(json_ok)" ""

case_ "real output names (DP-1, HDMI-A-1, eDP-1, DP-10): one folder each, DP-1 never mixed with DP-10"
rm -rf "$BAR"
sed -e 's/^HEADLESS-1 /DP-1 /; s/^HEADLESS-2 /HDMI-A-1 /; s/^HEADLESS-3 /eDP-1 /; s/^HEADLESS-4 /DP-10 /' \
  "$F/hotplug.status" | kawa-dwlstatus
eq "$(cd "$BAR" && ls -d */ | tr '\n' ' ')" "DP-1/ DP-10/ HDMI-A-1/ eDP-1/ "
eq "$(tagrow DP-1/)" "1:emp 2:emp 3:sel 4:- 5:- 6:- 7:- 8:- 9:-"
eq "$(tagrow DP-10/)" "1:sel 2:emp 3:emp 4:- 5:- 6:- 7:- 8:- 9:-"
eq "$(tagrow)" "$(tagrow DP-1/)"
eq "$(json_ok)" ""

# ── the workspaces ───────────────────────────────────────────────────────────
case_ "1–3 always; 4–9 only while they hold a window, are shown or ask for attention"
rm -rf "$BAR"; block DP-1 1 $((1 << 5)) 1 $((1 << 7)) '(@)' 0 x | kawa-dwlstatus
eq "$(tagrow)" "1:sel 2:emp 3:emp 4:- 5:- 6:occ 7:- 8:urg 9:-"
rm -rf "$BAR"; block DP-1 1 0 $((1 << 8)) 0 '(@)' 0 | kawa-dwlstatus
eq "$(tagrow)" "1:emp 2:emp 3:emp 4:- 5:- 6:- 7:- 8:- 9:sel" "an empty workspace 9 you went to"
case_ "a workspace that leaves the bar again when its last window goes"
rm -rf "$BAR"; { block DP-1 1 $((1 << 4 | 1)) 1 0 '(@)' 0 x; block DP-1 1 1 1 0 '(@)' 0 x; } | kawa-dwlstatus
eq "$(bar tag5)" '{"text":""}'
case_ "Super+0 (all at once): every workspace shown as selected; urgent wins over selected"
rm -rf "$BAR"; block DP-1 1 511 511 4 '(@)' 0 x | kawa-dwlstatus
eq "$(tagrow)" "1:sel 2:sel 3:urg 4:sel 5:sel 6:sel 7:sel 8:sel 9:sel"
case_ "tags past the ninth (a mask dwl would never print) and odd lines are no harm"
rm -rf "$BAR"; { block DP-1 1 1023 1 0 '(@)' 0 x; printf 'DP-1 tags\nDP-1 tags a b c d\nDP-1 tags 1 $(id) 0 0\n'; block DP-1 1 1 1 0 '(@)' 0 x; } | kawa-dwlstatus
eq "$(tagrow)" "1:sel 2:emp 3:emp 4:- 5:- 6:- 7:- 8:- 9:-"
eq "$(json_ok)" ""

# ── the layout ───────────────────────────────────────────────────────────────
case_ "each of dwl's layout symbols as its pixel icon"
for t in "(@)#$ICON_SPIRAL#spiral" "|||#$ICON_TILE#columns" "><>#$ICON_FLOAT#float"; do
  IFS='#' read -r sym icon cls <<<"$t"
  rm -rf "$BAR"; block DP-1 1 1 1 0 "$sym" 0 x | kawa-dwlstatus
  eq "$(bar layout)" "{\"text\":\"$icon\",\"class\":\"$cls\"}" "layout $sym"
done
case_ "a layout of your own (config.h): its symbol as text, escaped"
rm -rf "$BAR"; block DP-1 1 1 1 0 '<&"\>' 0 x | kawa-dwlstatus
eq "$(jtext layout)" '&lt;&amp;"\&gt;'; eq "$(json_ok)" ""

# ── the window title ─────────────────────────────────────────────────────────
case_ "titles: JSON and markup breakers, Arabic, Japanese, emoji — valid JSON and markup, shown as typed"
while IFS='|' read -r raw want; do
  rm -rf "$BAR"; block DP-1 1 1 1 0 '(@)' 0 "$raw" | kawa-dwlstatus
  eq "$(title_is "$want")" "" "title [$raw]"
done <<'EOF'
say "hi" \n \\ A /|say "hi" \n \\ A /
<b>bold</b> & <i|&lt;b&gt;bold&lt;/b&gt; &amp; &lt;i
&amp; &lt; &#x41; ]]>|&amp;amp; &amp;lt; &amp;#x41; ]]&gt;
مرحبا بالعالم — Firefox|مرحبا بالعالم — Firefox
日本語のタイトル・テスト〜|日本語のタイトル・テスト〜
🎉 party 👍🏽 ‏rtl‎ mark|🎉 party 👍🏽 ‏rtl‎ mark
EOF
# (the probe names a file in this test's own folder: should a title ever run, nothing outside it is touched)
probe='$(touch '"$TMP"'/pwned) `touch '"$TMP"'/pwned` ${HOME} %s %n'
rm -rf "$BAR"; block DP-1 1 1 1 0 '(@)' 0 "$probe" | kawa-dwlstatus
eq "$(title_is "$probe")" "" "title [\$(…) \`…\` \${HOME} %s]"
[[ ! -e $TMP/pwned ]] && _ok || _no "a title ran as a command"
case_ "control characters (should dwl ever pass one): a space, never a broken file"
rm -rf "$BAR"; block DP-1 1 1 1 0 '(@)' 0 $'a\tb\x1b[31mc\rd\x7fe\x01f' | kawa-dwlstatus
eq "$(jtext title)" "a b [31mc d e f"; eq "$(json_ok)" ""
case_ "an empty title, and one of spaces: an empty title"
rm -rf "$BAR"; block DP-1 1 1 1 0 '(@)' 0 "" | kawa-dwlstatus; eq "$(bar title)" '{"text":""}'
rm -rf "$BAR"; block DP-1 1 1 1 0 '(@)' 0 "     " | kawa-dwlstatus; eq "$(bar title)" '{"text":""}'
case_ "an 8 KB title of nothing but < & > (the most an X11 program gets through XWayland): written whole, valid"
long=$(printf '%.0s<&>' {1..2731})
rm -rf "$BAR"; block DP-1 1 1 1 0 '(@)' 0 "$long" | kawa-dwlstatus
eq "$(jtext title | wc -c)" 35504 "every < & > escaped (13 bytes for the three, + newline)"
eq "$(json_ok)" ""

# ── the keyboard layout ──────────────────────────────────────────────────────
case_ "us,ara: US then AR; a third layout's index past the list: ?; a single layout: nothing shown"
rm -rf "$BAR"; block DP-1 1 1 1 0 '(@)' 0 x | kawa-dwlstatus; eq "$(bar kb)" '{"text":"US","class":"first"}'
rm -rf "$BAR"; block DP-1 1 1 1 0 '(@)' 1 x | kawa-dwlstatus; eq "$(bar kb)" '{"text":"AR","class":"other"}'
rm -rf "$BAR"; block DP-1 1 1 1 0 '(@)' 2 x | kawa-dwlstatus; eq "$(bar kb)" '{"text":"?","class":"other"}'
rm -rf "$BAR"; block DP-1 1 1 1 0 '(@)' 2 x | XKB_DEFAULT_LAYOUT=de,us,ara kawa-dwlstatus; eq "$(bar kb)" '{"text":"AR","class":"other"}'
rm -rf "$BAR"; block DP-1 1 1 1 0 '(@)' 0 x | XKB_DEFAULT_LAYOUT=us kawa-dwlstatus; eq "$(bar kb)" '{"text":""}'
rm -rf "$BAR"; block DP-1 1 1 1 0 '(@)' 0 x | env -u XKB_DEFAULT_LAYOUT kawa-dwlstatus; eq "$(bar kb)" '{"text":""}'
case_ "no letter ranges in the helpers' =~ patterns: in a Turkish locale [a-z] leaves out the i (classes instead)"
for f in kawa-dwlstatus kawa-float kawa-tag; do
  eq "$(grep -nE '=~[^#]*\[[^]]*(a-z|A-Z)' "$REPO/bin/$f")" "" "$f"
done
case_ "a Turkish or Arabic locale: the layout names in plain capitals (no dotted İ), titles intact"
wait "$LOCPID" 2>/dev/null
# (in locale/ C.UTF-8 is there beside them; in locale-tr/ only Turkish, so the reader cannot
# switch to C.UTF-8 and runs in Turkish itself, where [a-z] leaves out i)
mkdir -p "$TMP/locale-tr"; cp -r "$TMP/locale/tr_TR.UTF-8" "$TMP/locale-tr/" 2>/dev/null
for loc in tr_TR.UTF-8 ar_EG.UTF-8 tr_TR.UTF-8:locale-tr; do
  l=${loc%%:*} d=locale; [[ $loc == *:* ]] && d=${loc#*:}
  rm -rf "$BAR"
  { block HDMI-A-1 1 1 1 0 '(@)' 1 "قائمة — liste ışık"; } | XKB_DEFAULT_LAYOUT=fi,ir LOCPATH=$TMP/$d LC_ALL=$l kawa-dwlstatus 2>/dev/null
  eq "$(bar kb)" '{"text":"IR","class":"other"}' "$loc"
  eq "$(title_is "قائمة — liste ışık")" "" "$loc"
  eq "$(tagrow HDMI-A-1/)" "1:sel 2:emp 3:emp 4:- 5:- 6:- 7:- 8:- 9:-" "$loc: HDMI-A-1 (an i in its name) has its own files"
done

# ── the per-monitor files, as each bar reads them ────────────────────────────
case_ "each bar shows its own monitor; a bar told no name, or a monitor not reported yet: the focused one's"
rm -rf "$BAR"
{ block DP-1 0 3 1 0 '(@)' 0 "on the left"; block HDMI-A-1 1 $((1 << 4)) $((1 << 4)) 0 '><>' 0 "on the right"; } | kawa-dwlstatus
for m in tag1 tag5 layout title; do
  ex=$(wbexec "custom/$m")
  eq "$(WAYBAR_OUTPUT_NAME=DP-1 sh -c "$ex")" "$(bar "DP-1/$m")" "$m on DP-1"
  eq "$(WAYBAR_OUTPUT_NAME=HDMI-A-1 sh -c "$ex")" "$(bar "HDMI-A-1/$m")" "$m on HDMI-A-1"
  eq "$(env -u WAYBAR_OUTPUT_NAME sh -c "$ex")" "$(bar "HDMI-A-1/$m")" "$m with no name: the focused monitor's"
  eq "$(WAYBAR_OUTPUT_NAME=DP-3 sh -c "$ex")" "$(bar "HDMI-A-1/$m")" "$m on a monitor not reported yet"
done
eq "$(WAYBAR_OUTPUT_NAME=DP-1 sh -c "$(wbexec custom/title)")" '{"text":"on the left"}'
eq "$(WAYBAR_OUTPUT_NAME=DP-1 sh -c "$(wbexec custom/kb)")" '{"text":"US","class":"first"}' "the keyboard: one for all"
case_ "the focus moves to the other monitor: the top files follow it, in either order dwl lists them"
rm -rf "$BAR"
{ block DP-1 0 3 1 0 '(@)' 0 "left"; block HDMI-A-1 1 1 1 0 '><>' 0 "right"
  block DP-1 1 3 1 0 '(@)' 0 "left"; block HDMI-A-1 0 1 1 0 '><>' 0 "right"; } | kawa-dwlstatus
eq "$(jtext title)" "left"; eq "$(bar layout)" "$(bar DP-1/layout)"
{ block DP-1 1 3 1 0 '(@)' 0 "left"; block HDMI-A-1 0 1 1 0 '><>' 0 "right"
  block DP-1 0 3 1 0 '(@)' 0 "left"; block HDMI-A-1 1 1 1 0 '><>' 0 "right"; } | kawa-dwlstatus
eq "$(jtext title)" "right"; eq "$(bar layout)" "$(bar HDMI-A-1/layout)"
case_ "an output name that is no folder name (should one ever come): ignored, nothing outside dwl-bar"
rm -rf "$BAR"; for m in ../x .. . 'a b' -x; do block "$m" 1 1 1 0 '(@)' 0 "evil" | kawa-dwlstatus; done
eq "$(ls -A "$XDG_RUNTIME_DIR" | tr '\n' ' ')" "dwl-bar "; eq "$(ls -A "$BAR")" ""

# ── the stream itself ────────────────────────────────────────────────────────
case_ "a line that comes in two pieces (a slow pipe) is read as one"
rm -rf "$BAR"; mkfifo "$TMP/pipe"
kawa-dwlstatus <"$TMP/pipe" & sp=$!
{ printf 'DP-1 title half a '; sleep 0.3; printf 'title\n'; block DP-1 1 1 1 0 '(@)' 0 | tail -n +2; } >"$TMP/pipe"
wait "$sp"; eq "$(jtext title)" "half a title"
case_ "dwl stops mid-line (it crashed): the cut line is dropped, the bar keeps the last whole state, exit 0"
rm -rf "$BAR"; { block DP-1 1 3 2 0 '(@)' 0 "whole"; printf 'DP-1 title cu'; } >"$TMP/s"
rc 0 kawa-dwlstatus <"$TMP/s"; eq "$(jtext title)" "whole"
{ block DP-1 1 3 2 0 '(@)' 0 "whole"; printf 'DP-1 title next\nDP-1 selmon 0\n'; } >"$TMP/s"
rc 0 kawa-dwlstatus <"$TMP/s"
case_ "an empty stream (dwl gone at once), and no stream: nothing written, exit 0"
rm -rf "$BAR"; rc 0 kawa-dwlstatus </dev/null; eq "$(ls -A "$BAR" 2>/dev/null)" ""
case_ "lines cut and run together (dwl drops what a full pipe cannot take): no garbage in the bar"
rm -rf "$BAR"
{ block DP-1 1 3 2 0 '(@)' 1 "before"
  printf 'DP-1 layout []DP-1 kblayout 0\nDP-1 kblayout 1DP-1 title x\nDP-1 tags 3 2DP-1 layout []=\nDP-1 layout [DP-1 title y\n'
  printf 'DP-1 tags 7 1 1 0\nDP-1 kblayout 1\n'; } | kawa-dwlstatus
eq "$(bar layout)" "{\"text\":\"$ICON_SPIRAL\",\"class\":\"spiral\"}" "the layout stays the last good one"
eq "$(bar kb)" '{"text":"AR","class":"other"}' "the keyboard stays the last good one"
eq "$(tagrow)" "1:sel 2:occ 3:occ 4:- 5:- 6:- 7:- 8:- 9:-" "the next whole tags line counts"
eq "$(json_ok)" ""
case_ "a burst of 1000 lines (125 title changes at once): all read, the last one shown, quickly"
rm -rf "$BAR"; pokes >/dev/null
for i in $(seq 1 125); do block DP-1 1 3 1 0 '(@)' 0 "title number $i"; done >"$TMP/burst"
eq "$(wc -l <"$TMP/burst")" 1000
t0=$EPOCHREALTIME; kawa-dwlstatus <"$TMP/burst"; t1=$EPOCHREALTIME
eq "$(jtext title)" "title number 125"
(( ${t1%.*} - ${t0%.*} < 30 )) && _ok || _no "1000 lines took $(( ${t1%.*} - ${t0%.*} )) s"
eq "$(pokes | tr ' ' '\n' | grep -c '^10$')" 125 "one title poke per change, none for the unchanged half of each block"

# ── what is poked ────────────────────────────────────────────────────────────
case_ "the first status: every module once (8 workspaces, 9 layout, 10 title, 11 keyboard)"
rm -rf "$BAR"; pokes >/dev/null; block DP-1 1 1 1 0 '(@)' 0 x | kawa-dwlstatus; eq "$(pokes)" "8 9 10 11"
block DP-1 1 1 1 0 '(@)' 0 x >"$TMP/a"
case_ "only what changed is poked"
block DP-1 1 1 1 0 '(@)' 0 x >"$TMP/b"; eq "$(delta "$TMP/a" "$TMP/b")" "" "the same status again: nothing"
block DP-1 1 1 1 0 '(@)' 0 y >"$TMP/b"; eq "$(delta "$TMP/a" "$TMP/b")" "10" "a new title"
block DP-1 1 3 2 0 '(@)' 0 x >"$TMP/b"; eq "$(delta "$TMP/a" "$TMP/b")" "8" "another workspace"
block DP-1 1 1 1 0 '|||' 0 x >"$TMP/b"; eq "$(delta "$TMP/a" "$TMP/b")" "9" "another layout"
block DP-1 1 1 1 0 '(@)' 1 x >"$TMP/b"; eq "$(delta "$TMP/a" "$TMP/b")" "11" "Alt+Shift"
block DP-1 1 3 2 0 '|||' 0 y >"$TMP/b"; eq "$(delta "$TMP/a" "$TMP/b")" "8 9 10" "a window sent away"
case_ "two monitors: a change on the one not focused still pokes (its own bar shows it)"
{ block DP-1 1 1 1 0 '(@)' 0 x; block HDMI-A-1 0 1 1 0 '(@)' 0 z; } >"$TMP/a"
{ block DP-1 1 1 1 0 '(@)' 0 x; block HDMI-A-1 0 1 1 0 '(@)' 0 z2; } >"$TMP/b"
eq "$(delta "$TMP/a" "$TMP/b")" "10"
{ block DP-1 0 1 1 0 '(@)' 0 x; block HDMI-A-1 1 1 1 0 '(@)' 0 z; } >"$TMP/b"
eq "$(delta "$TMP/a" "$TMP/b")" "10" "the focus moves: the top title changes; the workspaces look the same"

case_ "waybar still starting (no handlers yet): never poked — the signal would kill it"
waybar_down; waybar_up ignore
rm -rf "$BAR"; block DP-1 1 1 1 0 '(@)' 0 x | kawa-dwlstatus; rc 0 kawa-dwlstatus --poke 12
kill -0 "$WBPID" 2>/dev/null && _ok || _no "waybar was killed by a poke"
eq "$(json_ok)" "" "the files are written all the same: waybar reads them when it is up"
case_ "waybar not running: the files are written, nothing fails"
waybar_down; rm -rf "$BAR"; rc 0 status "$F/one-monitor.status"; eq "$(tagrow)" "1:emp 2:sel 3:emp 4:- 5:- 6:- 7:- 8:- 9:-"
case_ "waybar restarted (a new PID) while the reader runs: the new one is found and poked"
waybar_up; rm -rf "$BAR"; mkfifo "$TMP/p2"; kawa-dwlstatus <"$TMP/p2" & sp=$!; exec 7>"$TMP/p2"
block DP-1 1 1 1 0 '(@)' 0 a >&7; sleep 0.5; pokes >/dev/null
waybar_down; waybar_up
block DP-1 1 1 1 0 '(@)' 0 b >&7; exec 7>&-; wait "$sp"
eq "$(pokes)" "10"

# ── --poke, for the others ───────────────────────────────────────────────────
case_ "--poke N…: exactly those signals; waybar not running: exit 0, quiet"
pokes >/dev/null; rc 0 kawa-dwlstatus --poke 12; eq "$(pokes)" "12"
kawa-dwlstatus --poke 12 13; eq "$(pokes)" "12 13"
waybar_down; eq "$(kawa-dwlstatus --poke 13 2>&1)" ""; rc 0 kawa-dwlstatus --poke 13
case_ "--poke from a service with no runtime folder (systemd's ExecStopPost): still pokes, writes nothing"
waybar_up; rm -rf "$BAR"; pokes >/dev/null
rc 0 env -u XDG_RUNTIME_DIR kawa-dwlstatus --poke 12; eq "$(pokes)" "12"
[[ ! -e $BAR ]] && _ok || _no "--poke made the bar's folder"
case_ "--poke misused (no number, words, \$(…)): exit 2, nothing poked, nothing run"
rc 2 kawa-dwlstatus --poke; rc 2 kawa-dwlstatus --poke abc; rc 2 kawa-dwlstatus --poke 99
rc 2 kawa-dwlstatus --poke 'a[$(touch '"$TMP"'/pwned)]'
[[ ! -e $TMP/pwned ]] && _ok || _no "--poke ran a command"
eq "$(pokes)" ""
case_ "--help says what it is (exit 0); anything else: exit 2 without waiting on stdin"
has "$(kawa-dwlstatus --help </dev/null)" "status stream"; rc 0 kawa-dwlstatus --help </dev/null
rc 2 timeout 5 kawa-dwlstatus --bogus </dev/null

# ── where it writes ──────────────────────────────────────────────────────────
case_ "a write that fails (the runtime folder full): the bar catches up with the next status"
rm -rf "$BAR"; mkdir -p "$BAR/title.tmp"     # (a folder where the file goes: fails even for root)
mkfifo "$TMP/p3"; kawa-dwlstatus <"$TMP/p3" 2>"$TMP/err" & sp=$!; exec 7>"$TMP/p3"
block DP-1 1 1 1 0 '(@)' 0 "new title" >&7; sleep 0.5; rmdir "$BAR/title.tmp"
block DP-1 1 1 1 0 '(@)' 0 "new title" >&7; exec 7>&-; wait "$sp"
eq "$(jtext title)" "new title"
eq "$(cat "$TMP/err")" "" "no error flood in dwl.log"
case_ "the bar's folder deleted under it: the files come back with the next status"
mkfifo "$TMP/p4"; kawa-dwlstatus <"$TMP/p4" & sp=$!; exec 7>"$TMP/p4"
block DP-1 1 1 1 0 '(@)' 0 "same" >&7; sleep 0.5; rm -rf "$BAR"
block DP-1 1 1 1 0 '(@)' 0 "same" >&7; exec 7>&-; wait "$sp"
eq "$(jtext title)" "same"; eq "$(tagrow)" "1:sel 2:emp 3:emp 4:- 5:- 6:- 7:- 8:- 9:-"
case_ "a runtime folder with a space in its path"
mkdir -p "$TMP/run time"; XDG_RUNTIME_DIR="$TMP/run time" kawa-dwlstatus < <(block DP-1 1 1 1 0 '(@)' 0 "spaced")
eq "$(cat "$TMP/run time/dwl-bar/title.json")" '{"text":"spaced"}'
case_ "icons.sh missing (a theme run that never finished): no made-up symbols — it stops, said (autostart drains dwl's pipe meanwhile)"
mv "$HOME/.config/fedokawaii/icons.sh" "$TMP/icons.sh"; rm -rf "$BAR"
err=$({ block DP-1 1 1 1 0 '(@)' 0 "second"; } | kawa-dwlstatus 2>&1 >/dev/null); r=$?
[[ $r != 0 ]] && _ok || _no "it went on without its icons"; has "$err" "icons.sh"
mv "$TMP/icons.sh" "$HOME/.config/fedokawaii/icons.sh"
case_ "a home folder with a space"
mkdir -p "$TMP/my home/.config/fedokawaii"; cp "$HOME/.config/fedokawaii/icons.sh" "$TMP/my home/.config/fedokawaii/"
rm -rf "$BAR"; HOME="$TMP/my home" kawa-dwlstatus < <(block DP-1 1 1 1 0 '(@)' 0 "home")
eq "$(bar layout)" "{\"text\":\"$ICON_SPIRAL\",\"class\":\"spiral\"}"
case_ "the cat: lit only while quick settings' marker holds a live pid (a pid that died, an empty or broken marker, a dropdown's: dark)"
cat_ex=$(wbexec custom/menu)
lit_=$(. "$HOME/.config/fedokawaii/icons.sh"; printf '{"text":"%s","class":"active"}' "$ICON_CAT_HAPPY")
dark_=$(. "$HOME/.config/fedokawaii/icons.sh"; printf '{"text":"%s"}' "$ICON_CAT")
rm -f "$XDG_RUNTIME_DIR"/kawa-*.open
eq "$(sh -c "$cat_ex")" "$dark_" "no marker: dark"
echo $$ >"$XDG_RUNTIME_DIR/kawa-panel.open"; eq "$(sh -c "$cat_ex")" "$lit_" "a live pid: lit"
sleep 0 & dead=$!; wait "$dead"; echo "$dead" >"$XDG_RUNTIME_DIR/kawa-panel.open"
eq "$(sh -c "$cat_ex")" "$dark_" "a dead pid: dark"
for junk in "" "-1" "x"; do printf '%s\n' "$junk" >"$XDG_RUNTIME_DIR/kawa-panel.open"; eq "$(sh -c "$cat_ex")" "$dark_" "[$junk]: dark"; done
rm -f "$XDG_RUNTIME_DIR/kawa-panel.open"; echo "$$ kawa-calendar" >"$XDG_RUNTIME_DIR/kawa-drop.open"
eq "$(sh -c "$cat_ex")" "$dark_" "a dropdown lights its own button, not the cat"
lacks "$(bash -c "$cat_ex" 2>&1)" "No such" "no error from a dead marker"
rm -f "$XDG_RUNTIME_DIR"/kawa-*.open

case_ "no runtime folder at all: exit 1, said"
rc 1 env -u XDG_RUNTIME_DIR kawa-dwlstatus </dev/null
has "$(env -u XDG_RUNTIME_DIR kawa-dwlstatus </dev/null 2>&1)" "XDG_RUNTIME_DIR"

case_ "dwl speaks only once its pipe to the bar is there: the monitors made before it (backend start) put no status lines in dwl.log (src/dwl/dwl.patch)"
p=$(cat "$REPO/src/dwl/dwl.patch")
has "$p" $'+static int status_ready;'
has "$p" $'+\tif (!status_ready)\n+\t\treturn;' "printstatus() does not wait for the pipe"
has "$p" $'\tif (fd_set_nonblock(STDOUT_FILENO) < 0)\n \t\tclose(STDOUT_FILENO);\n \n+\tstatus_ready = 1;\n \tprintstatus();' "run() does not open the status after the pipe"
eq "$(grep -c 'status_ready = 1' <<<"$p")" 1 "set anywhere but run()"

done_
