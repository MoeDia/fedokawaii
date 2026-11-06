#!/usr/bin/env bash
# tests/regress/test_gone.sh — what he had taken out stays out, in what a person reads: kanji only on
# the workspace stamps, the lock's quote and the bar's day seal (r27-dec-3b, r27-kanji-words), and no
# dashed rule in any text screen (bug 17). A sweep of the desktop's own files, comments left out.
. "$(dirname "$0")/lib.sh"
lines=$(code_lines)

case_ "kanji only where he allows: the stamps, the lock's quote, the day's seal"
# (the place each lives, and why it may: a width table and file names are no words on a screen)
allowed='^(bin/kawa-bar|configs/home/.bashrc.d/fedokawaii.sh|configs/home/.local/share/fedokawaii/wallpapers.list|system/fedokawaii-report|system/fonts/LICENSE|system/60-fedokawaii-pixel.conf|configs/home/.config/waybar/style.css|docs/):'
found=$(/usr/bin/grep -P '[\x{3400}-\x{9fff}]' <<<"$lines" | /usr/bin/grep -vE "$allowed")
if [[ -z $found ]]; then _ok; else while IFS= read -r x; do _no "${x:0:140}"; done <<<"$found"; fi
n=$(/usr/bin/grep -cP '[\x{3400}-\x{9fff}]' <<<"$lines")
item "r27-dec-3b r27-kanji-words" "$n lines with kanji, all in the places allowed"

case_ "no dashed rule in any text screen, menu or sheet"
found=$(/usr/bin/grep -P '[\x{2504}-\x{250b}\x{254c}-\x{254f}]' <<<"$lines" | /usr/bin/grep -vE '^bin/kawa-panel:.*(BOX|box)')
if [[ -z $found ]]; then _ok; else while IFS= read -r x; do _no "${x:0:140}"; done <<<"$found"; fi
item r27-bug-17 "no ┄ ╌ ┈ line in bin/, system/, lib/, configs/home"
case_ "sketching stays gone: no FireAlpaca, no Sketch, no tablet in the desktop, dwl or the lessons"
found=$(/usr/bin/grep -iE 'firealpaca|kawa-sketch|xp-?pen|drawing tablet' <<<"$lines" | /usr/bin/grep -vE '^(lib/upstream\.sh|theme\.sh):')
if [[ -z $found ]]; then _ok; else while IFS= read -r x; do _no "${x:0:140}"; done <<<"$found"; fi
/usr/bin/grep -qE 'wlr_tablet|zwp_tablet' "$REPO/src/dwl/dwl.patch" && _no "dwl still takes the pen" || _ok
/usr/bin/grep -qE '^L.sketch.' "$REPO/docs/learn/index.tsv" && _no "the lesson is still in the index" || _ok
item r28-d2 "nothing of Sketch left to start, build, fetch or teach"

done_
