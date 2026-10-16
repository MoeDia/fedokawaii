#!/usr/bin/env bash
# tests/session/test_keybinds_meaning.sh — the help sheet (Super+/, keybinds.txt) against dwl's
# config.h, by meaning: each row's keys do what its words say (Super+J "focus next" is
# focusstack +1, "terminal" runs foot's client, T / Y / M are tile · float · monocle…), no key
# is bound twice, and every kawa-* a key runs exists and knows the word it is given.
# (tests/static/test_generated.sh checks that both name the same keys; keyacts.py has the
# meaning of every row.)
. "$(dirname "$0")/../lib/harness.sh"
D=$(cd "$(dirname "$0")" && pwd)

case_ "every row of the sheet means what config.h does; every binding is on the sheet"
out=$(python3 -I "$D/keyacts.py" "$REPO"); r=$?
while IFS= read -r ln; do [[ -n $ln ]] && _no "$ln"; done <<<"$out"
eq "$r" 0

# a copy of the three files, changed one way at a time: the check must notice each
copy() {
  sandbox; W=$TMP/w; mkdir -p "$W/src/dwl" "$W/configs/home/.config/fedokawaii" "$W/bin" "$W/system"
  cp "$REPO/src/dwl/config.h" "$W/src/dwl/"; cp "$REPO/configs/home/.config/fedokawaii/keybinds.txt" "$W/configs/home/.config/fedokawaii/"
  cp "$REPO"/bin/kawa-* "$W/bin/"; cp "$REPO/system/fedokawaii" "$W/system/"
  CH=$W/src/dwl/config.h KB=$W/configs/home/.config/fedokawaii/keybinds.txt
}
says() { has "$(python3 -I "$D/keyacts.py" "$W")" "$1"; }

case_ "… and is not blind: J and K swapped in config.h"
copy; sed -i -e 's/XKB_KEY_j,                 focusstack,       {.i = +1}/XKB_KEY_j, focusstack, {.i = -1}/' \
  -e 's/XKB_KEY_k,                 focusstack,       {.i = -1}/XKB_KEY_k, focusstack, {.i = +1}/' "$CH"
says "Super+J / K (Super+j) is 'focus next / previous', but config.h does focusstack:-1"
case_ "… the browser key running something else"
copy; sed -i 's/"brave-origin", NULL/"firefox", NULL/' "$CH"; says "config.h does spawn:firefox"
case_ "… the layouts in another order (Super+Y would tile)"
copy; python3 -I - "$CH" <<'EOF'
import sys; p = sys.argv[1]; s = open(p).read()
s = s.replace('{ "[]=",      tile },', '@T@').replace('{ "><>",      NULL },', '{ "[]=",      tile },').replace('@T@', '{ "><>",      NULL },')
open(p, "w").write(s)
EOF
says "layouts[] is"
case_ "… a key bound twice (the second binding never runs)"
copy; sed -i 's|^\t{ MODKEY,          XKB_KEY_q,                 killclient,       {0} },|&\n\t{ MODKEY, XKB_KEY_q, spawn, SHCMD("kawa-lock") },|' "$CH"
says "config.h binds Super+q 2 times"
case_ "… a binding gone from config.h"
copy; sed -i '/SHCMD("kawa-screenshot full")/d' "$CH"; says "Shift+Print (Shift+Print) is 'full screen', but config.h does (nothing)"
case_ "… a helper given a word it does not know"
copy; sed -i 's/kawa-screenshot region/kawa-screenshot regoin/' "$CH"; says "kawa-screenshot never mentions 'regoin'"
case_ "… a helper that is not there"
copy; rm "$W/bin/kawa-calendar"; says "config.h runs kawa-calendar, which is not in the repository"
case_ "… a row reworded so it no longer says what the key does"
copy; sed -i 's/^Super+F                 fullscreen/Super+F                 float/' "$KB"; says "Super+F says 'float', not 'fullscreen'"
case_ "… a new row the check does not know yet"
copy; sed -i 's/^Super+Tab               previous workspace/&\nSuper+G                 something new/' "$KB"
says "'Super+G' — a row this check does not know"

done_
