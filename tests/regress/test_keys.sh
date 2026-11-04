#!/usr/bin/env bash
# tests/regress/test_keys.sh — never again a key he needs that his board does not have (r24-37: a
# 61-key board has no Print key), and a conversion read as nonsense (r24-17: "100 eur in usd"
# answered in inches).
. "$(dirname "$0")/lib.sh"

case_ "the capture keys: a region, an edit and read-text, none of them on Print"
c=$REPO/src/dwl/config.h s=$REPO/configs/home/.config/fedokawaii/keybinds.txt
for k in "s:region" "a:edit" "x:text"; do
  grep -qE "MODKEY\|SHIFT, +XKB_KEY_${k%%:*}, +spawn, +SHCMD\(\"kawa-screenshot ${k#*:}\"\)" "$c" && _ok || _no "Super+Shift+${k%%:*} no longer runs kawa-screenshot ${k#*:}"
  grep -qiE "super\+shift\+${k%%:*}\b" "$s" && _ok || _no "Super+Shift+${k%%:*} is not on the sheet (Super+/)"
done
item r24-37 "Super+Shift+S region, +A edit, +X read text: bound and on the sheet"

case_ "a currency conversion: the words read as money, never as inches"
if command -v qalc >/dev/null; then
  sandbox
  a=$(timeout 60 "$REPO/bin/kawa-calc" --answer "100 eur in usd" 2>/dev/null)
  [[ $a == *'$'* || $a == *USD* || $a == *dollar* ]] && _ok || _no "100 eur in usd → [$a]"
  lacks "$a" "in" "read as inches: $a"
  item r24-17 "100 eur in usd → $a (qalc's own rates)"
else
  item r24-17 "no qalc here: not measured"
fi
done_
