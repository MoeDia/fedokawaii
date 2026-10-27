#!/usr/bin/env bash
# tests/session/test_tag.sh — kawa-tag N, what a click on workspace N in the bar does: Super+N
# through a virtual keyboard (wtype), so dwl switches exactly as for the key. wtype is a stand-in.
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"

case_ "workspaces 1–9: Super held, N pressed, Super let go; exit 0"
sandbox; stub wtype
for n in 1 2 3 4 5 6 7 8 9; do rc 0 kawa-tag "$n"; called "^wtype -M logo -k $n -m logo$"; done
eq "$(wc -l <"$CALLS")" 9
case_ "the bar's own clicks: every custom/tagN runs kawa-tag N"
eq "$(grep -oE '"custom/tag[1-9]": \{.*"on-click": "kawa-tag [1-9]"' "$REPO/configs/home/.config/waybar/config.jsonc" \
  | sed -E 's/"custom\/tag([1-9])".*"kawa-tag ([1-9])"/\1=\2/' | tr '\n' ' ')" "1=1 2=2 3=3 4=4 5=5 6=6 7=7 8=8 9=9 "

case_ "the layout icon: next / the one before, from the layout shown — spiral ⇄ columns only"
sandbox; stub wtype; mkdir -p "$XDG_RUNTIME_DIR/dwl-bar/DP-2"
lay() { printf '{"text":"x","class":"%s"}\n' "$1" >"$XDG_RUNTIME_DIR/dwl-bar/${2:-}layout.json"; }
lay spiral; rc 0 kawa-tag layout next; called "^wtype -M logo -k t -m logo$" "spiral → columns"
lay columns; reset_calls; kawa-tag layout next; called "^wtype -M logo -k s -m logo$" "columns → spiral"
lay spiral; reset_calls; kawa-tag layout prev; called "^wtype -M logo -k t -m logo$" "spiral ← columns"
lay columns; reset_calls; kawa-tag layout prev; called "^wtype -M logo -k s -m logo$" "columns ← spiral"
case_ "…never into floating (it stacks the windows), nor a key no layout has (Super+M): from floating, next is the spiral, prev columns"
for k in y m; do
  lay spiral; reset_calls; kawa-tag layout next; kawa-tag layout prev; not_called "^wtype -M logo -k $k "
  lay columns; reset_calls; kawa-tag layout next; kawa-tag layout prev; not_called "^wtype -M logo -k $k "
done
lay float; reset_calls; kawa-tag layout next; called "^wtype -M logo -k s -m logo$" "float → spiral"
lay float; reset_calls; kawa-tag layout prev; called "^wtype -M logo -k t -m logo$" "float ← columns"
case_ "…on the clicked bar's monitor: its own layout, not the focused one's"
lay spiral; lay columns DP-2/; reset_calls
WAYBAR_OUTPUT_NAME=DP-2 kawa-tag layout next; called "^wtype -M logo -k s -m logo$" "DP-2: columns → spiral"
WAYBAR_OUTPUT_NAME=HDMI-A-1 kawa-tag layout next; called "^wtype -M logo -k t -m logo$" "no file of its own: the focused one's"
case_ "anything but 1–9: exit 2, usage said, no key pressed"
sandbox; stub wtype
for a in 0 10 -1 a "" " 1" "1 " $'1\n2' 01 "\$(touch $TMP/pwned)" '1;id' '*'; do
  rc 2 kawa-tag "$a"; has "$(kawa-tag "$a" 2>&1)" "usage"
done
rc 2 kawa-tag; rc 2 kawa-tag 1 2
not_called '^wtype'; [[ ! -e $TMP/pwned ]] && _ok || _no "an argument ran as a command"
case_ "--help: what it does, exit 0"
has "$(kawa-tag --help)" "workspace"; rc 0 kawa-tag --help

case_ "wtype not installed: exit 1, and a notice says what to do (a click that did nothing otherwise)"
sandbox; rm -f "$STUBS/wtype"
out=$(PATH="$STUBS:$REPO/bin:/nonexistent" "$BASH" "$REPO/bin/kawa-tag" 3 2>&1); r=$?
eq "$r" 1; has "$out" "wtype"
called "^notify-send -a desktop .*wtype"
case_ "wtype failing (no virtual keyboard: not dwl, or not running): its failure passed on"
sandbox; stub wtype 'echo "Compositor does not support the virtual keyboard protocol" >&2; exit 1'
rc 1 kawa-tag 4

case_ "a held click (20 in a row): 20 presses, each whole"
sandbox; stub wtype
for _ in $(seq 1 20); do kawa-tag 2; done
eq "$(grep -c '^wtype -M logo -k 2 -m logo$' "$CALLS")" 20

case_ "kb next (the bar's US · AR tile): \"kb next\" into dwl's fifo — dwl switches the layout (a virtual keyboard could not); no wtype, never a wait"
sandbox; stub wtype; mkfifo "$XDG_RUNTIME_DIR/dwl-warm"; exec 7<>"$XDG_RUNTIME_DIR/dwl-warm"
rc 0 kawa-tag kb next
read -r -t 1 -u 7 l; eq "$l" "kb next" "the line dwl reads (kbnext)"
not_called '^wtype'
exec 7<&-
rm -f "$XDG_RUNTIME_DIR/dwl-warm"; rc 1 kawa-tag kb next   # (no fifo, no dwl of ours: exit 1, nothing waits)
: >"$XDG_RUNTIME_DIR/dwl-warm"; rc 1 kawa-tag kb next   # (not a fifo)
rc 2 kawa-tag kb; rc 2 kawa-tag kb prev; rc 2 kawa-tag kb next x

case_ "kawa-tag is clean (bash -n, shellcheck)"
rc 0 bash -n "$REPO/bin/kawa-tag"; rc 0 shellcheck -S warning -x "$REPO/bin/kawa-tag"

done_
