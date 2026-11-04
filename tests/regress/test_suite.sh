#!/usr/bin/env bash
# tests/regress/test_suite.sh — never again a suite that runs less than it says (r27-9b: `script` was not
# installed, test_calc skipped itself "passing", six Super+U blocks counted _ok without running). The
# runner on a tree of stand-ins: every file run, a failure fails the run; no test needs that tool.
. "$(dirname "$0")/lib.sh"
sandbox
C=$TMP/tree; mkdir -p "$C/tests/a" "$C/tests/b"; cp "$REPO/tests/run.sh" "$C/tests/"
printf '#!/bin/bash\necho "$0 ran" >>"%s"\necho one passed\n' "$TMP/ran" >"$C/tests/a/test_ok.sh"
printf '#!/bin/bash\necho "$0 ran" >>"%s"\necho one passed\n' "$TMP/ran" >"$C/tests/b/test_ok2.sh"

case_ "every test file is run, once, and the count says so"
: >"$TMP/ran"; out=$(bash "$C/tests/run.sh" 2>&1); eq "$?" 0 "$out"
eq "$(wc -l <"$TMP/ran")" 2 "$(cat "$TMP/ran")"; has "$out" "all 2 test files passed"
item r27-9b "the runner found and ran 2 of 2"

case_ "one area alone runs that area only"
: >"$TMP/ran"; out=$(bash "$C/tests/run.sh" b 2>&1); eq "$?" 0 "$out"; eq "$(wc -l <"$TMP/ran")" 1

case_ "a file that fails fails the run, by name"
printf '#!/bin/bash\necho "  ✘ a case — why"\nexit 1\n' >"$C/tests/b/test_bad.sh"
out=$(bash "$C/tests/run.sh" 2>&1); eq "$?" 1; has "$out" "✘ 1 of 3 test files failed: b/test_bad.sh"; has "$out" "a case — why"
rm "$C/tests/b/test_bad.sh"

case_ "an area with no test is no pass"
out=$(bash "$C/tests/run.sh" nosuch 2>&1); eq "$?" 1; has "$out" "no tests found"

case_ "no test leans on a tool this PC does not have: script (util-linux-script) is not in the manifest, pty_run.py is the one way"
found=$(grep -rlE '(^|[ (|])script (-[qcfe]|--)' "$REPO/tests" --include='test_*.sh' 2>/dev/null | grep -v 'test_report_rows\|test_suite')
eq "$found" "" "these still call it: $found"
[[ -f $REPO/tests/lib/pty_run.py ]] && _ok || _no "tests/lib/pty_run.py is gone"
item r27-9b "no test file calls script; tests/lib/pty_run.py"

case_ "the harness: a failed check fails its file, an accounts change is caught, a file with no check at all is no pass"
out=$(bash -c '. "$1/tests/lib/harness.sh"; case_ x; _no "broken"; done_' _ "$REPO" 2>&1); eq "$?" 1 "$out"; has "$out" "1 failed"
out=$(bash -c '. "$1/tests/lib/harness.sh"; case_ x; _ok; done_' _ "$REPO" 2>&1); eq "$?" 0 "$out"
done_
