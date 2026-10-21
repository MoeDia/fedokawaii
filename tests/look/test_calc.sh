#!/usr/bin/env bash
# tests/look/test_calc.sh — kawa-calc, the launcher's Calculator: the answer shows as you type
# (the real qalc works it out), Enter copies it and keeps the line above, a word alone or a
# qalc command is never sent, Esc closes. Typed on a terminal of its own (script).
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"
need qalc script python3

setup() {
  look
  argv wl-copy 'cat >"$FAKE_TMP/clip"'
  stub wl-paste '[ "$1" = --list-types ] && [ -e "$FAKE_TMP/clip" ] && echo "text/plain;charset=utf-8"'
}
# typed KEYS… — each argument typed after the one before has been answered (0.8 s), then Esc
typed() {
  local k q; printf -v q '%q ' kawa-calc
  { for k; do printf '%b' "$k"; /bin/sleep 0.8; done; printf '\e'; /bin/sleep 0.3; } \
    | timeout 30 script -qec "stty cols 64 rows 13; $q" /dev/null 2>&1 | tr -d '\r'
}
plain() { sed 's/\x1b\[[0-9;?]*[A-Za-z]//g; s/\x1b[78]//g' <<<"$1"; }

setup
case_ "a conversion: its answer as it is typed; the heading is 算 calculator"
out=$(plain "$(typed '5 ft to cm')"); has "$out" "算  calculator"; has "$out" "=  152.4 cm"
case_ "Enter: the answer copied, the line kept above, said in the footer"
out=$(plain "$(typed '6*7' '\r')"); eq "$(cat "$TMP/clip" 2>/dev/null)" 42; has "$out" "6*7 = 42"; has "$out" "copied: 42"
case_ "a word alone, or one of qalc's commands: no answer (never sent: exit would end qalc)"
setup; out=$(plain "$(typed 'steam' '\x15exit 5' '\x152+2')"); lacks "$out" "=  0"; has "$out" "=  4"
case_ "Backspace takes a letter back; the answer follows"
out=$(plain "$(typed '2*30' '\x7f')"); has "$out" "=  6"
case_ "each key one frame (a synchronised update), never cleared first; the footer only one-column letters"
raw=$(typed '1+1' '\x7f'); has "$raw" $'\e[?2026h'; has "$raw" $'\e[?2026l'; lacks "$raw" $'\e[2J'
has "$(plain "$raw")" "up again"; lacks "$raw" "↑"
case_ "a percentage in words: \"15% of 2400\" is qalc's 15% * 2400 (qalc alone: rem(15, 1 B))"
eq "$(kawa-calc --answer '15% of 2400')" 360; eq "$(kawa-calc --answer '120 * 15% of 10')" 180
rc 1 kawa-calc --answer steam
case_ "the launcher: a sum typed that matches no entry is worked out, copied, said in a notice"
setup; argv notify-send; rm -f "$TMP/clip"
kawa-calc --launch 15% of 2400; eq "$(cat "$TMP/clip" 2>/dev/null)" 360; called notify-send "15% of 2400 = 360 · copied"
case_ "the launcher: an entry picked (DESKTOP_ENTRY_ID) runs as it is; a program typed runs"
out=$(DESKTOP_ENTRY_ID=x.desktop kawa-calc --launch echo picked); eq "$out" picked
out=$(kawa-calc --launch echo typed); eq "$out" typed
has "$(cat "$REPO/bin/kawa-menu")" "fuzzel --launch-prefix='kawa-calc --launch'"
case_ "Esc closes (exit 0); misuse is 2"
rc 0 typed ''; rc 2 kawa-calc --frob
case_ "without qalc: said, exit 1"
hide qalc; out=$(kawa-calc 2>&1); eq "$?" 1; has "$out" "qalc is missing"

done_
