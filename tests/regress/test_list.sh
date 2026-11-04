#!/usr/bin/env bash
# tests/regress/test_list.sh — the never-again list stays true (tools/regress/README.md, held by
# tools/regress/items.py): every item of the ledger and of the master's trace has a row; every row's
# check is there, word for word; every check is some row's; a task marked done leaves no "open" row.
# And the holder itself is not blind: each way the list can go wrong, made on a copy, is caught.
. "$(dirname "$0")/lib.sh"
sandbox
I=$REPO/tools/regress/items.py

case_ "the list is whole: every item a row, every row's check there"
out=$(python3 -I -B "$I" check "$REPO" 2>&1); r=$?
eq "$r" 0 "$out"
item "r27-never-1" "${out#the list is whole — }"

# a copy of what it reads, to spoil
copy() {
  C=$TMP/copy; rm -rf "$C"; mkdir -p "$C/.claude/notes"
  cp -r "$REPO/tools" "$REPO/tests" "$C/"
  cp "$REPO/.claude/notes/02-LEDGER.md" "$REPO/.claude/notes/master-trace.md" "$C/.claude/notes/"
  cp "$REPO/.claude/plan.md" "$C/.claude/"
}
holder() { python3 -I -B "$I" check "$C" 2>&1; }
R=tools/regress/README.md

case_ "not blind: a ledger item with no row"
copy; printf -- '- r27-brandnew (4 Nov) something he reported, fixed\n' >>"$C/.claude/notes/02-LEDGER.md"
has "$(holder)" "no row for r27-brandnew"
case_ "not blind: a verdict needs no row, a fix does"
copy; printf -- '- r27-77-master-1 (4 Nov) VERDICT\n- r27-77-fix (4 Nov) what it found\n' >>"$C/.claude/notes/02-LEDGER.md"
o=$(holder); lacks "$o" "r27-77-master-1"; has "$o" "no row for r27-77-fix"
case_ "not blind: a row gone"
copy; sed -i '/^| r24-45 /d' "$C/$R"
has "$(holder)" "no row for r24-45"
case_ "not blind: a test file gone"
copy; rm "$C/tests/look/test_saver.sh"
has "$(holder)" "tests/look/test_saver.sh is not there"
case_ "not blind: the case a row names renamed"
copy; sed -i 's/its colours: the theme.s saver.conf/the colours/' "$C/tests/look/test_saver.sh"
has "$(holder)" "tests/look/test_saver.sh has no case with"
case_ "not blind: words in a comment are no case"
copy; sed -i "s/^\( *\)case_ \"its colours: the theme's saver.conf/\1# case_ \"its colours: the theme's saver.conf/" "$C/tests/look/test_saver.sh"
has "$(holder)" "tests/look/test_saver.sh has no case with"
case_ "not blind: a check here that is no row's"
copy; printf '#!/bin/sh\n' >"$C/tools/regress/new-check.sh"
has "$(holder)" "tools/regress/new-check.sh is no row's check"
case_ "not blind: an id twice; an id nowhere; a bad line"
copy; printf '| r24-45 | again | record: twice |\n| r27-nosuch | x | record: y |\n| r24-1 | no third cell |\n' >>"$C/$R"
o=$(holder); has "$o" "r24-45 is on line"; has "$o" "r27-nosuch is in neither"; has "$o" "2 cells, not 3"
case_ "not blind: a task marked done leaves no open row"
copy; sed -i 's/^### T59 .*/### T59 — maniac testing [DONE 5 Nov]/' "$C/.claude/plan.md"
has "$(holder)" "T59 is done now"
case_ "not blind: more than five by hand; a kind with no reason"
copy; for i in 1 2 3 4 5; do printf '| r27-rule-%d | x | manual: a step |\n' $((i + 2)) >>"$C/$R"; done
has "$(holder)" "rows done by hand"
copy; sed -i 's/^| r25-4 .*/| r25-4 | the bar without boxes | gone T14: |/' "$C/$R"
has "$(holder)" "gone with no reason"

case_ "blame: a run's ✘ lines say which of his items they break"
copy
cat >"$TMP/run.log" <<'LOG_END'
  ✘ its colours: the theme's saver.conf, all eight — missing, it says what to repair — expected [x]
✘ wash               wash (dark): 3 frames late
  ok lines are left alone
LOG_END
b=$(python3 -I -B "$I" blame "$TMP/run.log")
has "$b" "r24-45"; has "$b" "r24-7"; has "$b" "r26-fu-8"
done_
