#!/usr/bin/env bash
# tests/regress/test_wiring.sh — the checks really run where they are promised (r27-never-2, -3): before
# a push to main (tools/prepush.sh, its git hook) and in the selftest. A clone of stand-ins: its
# suite, its headless set and its verify only say they ran and how they end.
. "$(dirname "$0")/lib.sh"

sandbox
git config --global user.name t; git config --global user.email t@t
git config --global init.defaultBranch main
C=$TMP/clone; mkdir -p "$C/tests" "$C/tools/regress"; cd "$C" || exit 1
git init -q; cp "$REPO/tools/prepush.sh" tools/; cp "$REPO/tools/regress/items.py" tools/regress/
printf '%s\n' '#!/bin/bash' 'echo suite >>"$RAN"; exit "${SUITE_RC:-0}"' >tests/run.sh
printf '%s\n' '#!/bin/bash' 'echo "headless $*" >>"$RAN"; exit "${HEADLESS_RC:-0}"' >tools/regress/run.sh
git add -A; git commit -qm first
stub fedokawaii 'echo "verify $*" >>"$RAN"; exit "${VERIFY_RC:-0}"'
stub sudo 'exit "${SUDO_RC:-0}"'
export RAN=$TMP/ran; : >"$RAN"
ran() { tr '\n' ',' <"$RAN"; : >"$RAN"; }
P() { bash tools/prepush.sh "$@"; }

case_ "prepush runs everything: the suite, the headless set from the repository's state, verify; a passed tree once"
out=$(P 2>&1); eq "$?" 0 "$out"
if compgen -G '/dev/dri/renderD*' >/dev/null; then eq "$(ran)" "suite,headless --bin bin --repo-art,verify verify,"; else eq "$(ran)" "suite,verify verify,"; fi
out=$(P 2>&1); eq "$?" 0; has "$out" "passed already"; eq "$(ran)" ""
item r27-never-2 "the suite, the headless set and verify before a push, none twice on one tree"

case_ "prepush: any part red is red, the others still run, and the next try runs again"
echo x >x; git add x; git commit -qm x
SUITE_RC=1 P >/dev/null 2>&1; eq "$?" 1; has "$(ran)" "verify"
HEADLESS_RC=1 P >/dev/null 2>&1; eq "$?" 1; ran >/dev/null
VERIFY_RC=3 P >/dev/null 2>&1; eq "$?" 1; ran >/dev/null
out=$(P 2>&1); eq "$?" 0 "$out"; has "$(ran)" "suite"

case_ "prepush tests the commit, not the working tree: an uncommitted change is not what is judged"
echo y >y; git add y; git commit -qm y
printf '%s\n' '#!/bin/bash' 'exit 1' >tests/run.sh
out=$(P 2>&1); eq "$?" 0 "$out"; git checkout -q tests/run.sh; : >"$RAN"

case_ "verify asks a password: said, not run, no failure"
echo z >z; git add z; git commit -qm z
out=$(SUDO_RC=1 P 2>&1); eq "$?" 0; has "$out" "not run"; lacks "$(ran)" "verify"

case_ "the hook: a push to main runs it; another branch passes untouched; a branch deleted too"
out=$(P --install 2>&1); eq "$?" 0 "$out"
H=$(git rev-parse --git-common-dir)/hooks/pre-push; [[ -x $H ]] && _ok || _no "no hook"
echo w >w; git add w; git commit -qm w; S=$(git rev-parse HEAD)
: >"$RAN"; printf 'refs/heads/lane-x %s refs/heads/lane-x 0000\n' "$S" | "$H" >/dev/null 2>&1; eq "$?" 0; eq "$(ran)" ""
SUITE_RC=1 bash -c "printf 'refs/heads/main $S refs/heads/main 0000\n' | '$H'" >/dev/null 2>&1; eq "$?" 1 "a red push to main went through"; has "$(ran)" "suite"
printf '(delete) 0000000000000000000000000000000000000000 refs/heads/main abc\n' | "$H" >/dev/null 2>&1; eq "$?" 0
out=$(P --install 2>&1); eq "$?" 0 "installing again"
printf '#!/bin/sh\nexit 0\n' >"$H"; out=$(P --install 2>&1); eq "$?" 2; has "$out" "left alone"
out=$(P --nonsense 2>&1); eq "$?" 2

case_ "selftest runs the checks: --sandbox, as the desktop's user, the stand-ins and, with a GPU, the headless set"
s=$(sed -n '/^if ((SANDBOX)); then/,/^fi/p' "$REPO/tools/selftest.sh")
has "$s" 'tests/run.sh regress'; has "$s" 'tools/regress/run.sh --dwl /usr/local/bin/dwl'; has "$s" 'runuser -u "$U"'; has "$s" 'renderD'
item r27-never-3 "fedokawaii selftest --sandbox: tests/regress, tools/regress on the installed dwl"

# the section itself, as selftest runs it: its words stand-ins, runuser a plain call, the clone a folder
section_run() {   # section_run HOME → the verdicts it said, a line each
  (
    h=$1 U=me; said() { printf '%s %s\n' "$1" "$2"; }
    section() { :; }; pass() { said pass "$1"; }; fail() { said fail "$1"; }; warn() { said warn "$1"; }; info() { said info "$1"; }
    stub runuser 'while [ "$1" != -- ]; do shift; done; shift; exec "$@"'
    # shellcheck disable=SC2030,SC2031  # (the section's own variables)
    eval "$(sed -n '/section "never again/,/fedokawaii copy makes one"; fi$/p' "$REPO/tools/selftest.sh")"
  )
}
fake_clone() {   # fake_clone SUITE_RC HEADLESS_RC → a home with a clone that ends so
  local d=$TMP/home2; rm -rf "$d"; mkdir -p "$d/repos/fedokawaii/tests" "$d/repos/fedokawaii/tools/regress"
  printf '#!/bin/bash\necho "suite $*" >>"$RAN"; echo last line; exit %s\n' "$1" >"$d/repos/fedokawaii/tests/run.sh"
  printf '#!/bin/bash\necho "headless $*" >>"$RAN"; echo "✔ one"; echo "regress: said"; exit %s\n' "$2" >"$d/repos/fedokawaii/tools/regress/run.sh"
  printf '%s' "$d"
}
gpu=0; compgen -G '/dev/dri/renderD*' >/dev/null && gpu=1

case_ "selftest's section: the stand-ins and the headless set hold: said so; the desktop's user runs them from the clone"
: >"$RAN"; o=$(section_run "$(fake_clone 0 0)"); has "$o" "pass the stand-in checks hold"
has "$(cat "$RAN")" "suite regress"
if ((gpu)); then has "$o" "pass the headless checks hold"; has "$(cat "$RAN")" "headless --dwl /usr/local/bin/dwl"; else has "$o" "no GPU here"; fi

case_ "selftest's section: a red stand-in or headless check is a failure; a check that could not run a warning"
: >"$RAN"; has "$(section_run "$(fake_clone 1 0)")" "fail the stand-in checks"
if ((gpu)); then
  has "$(section_run "$(fake_clone 0 1)")" "fail the headless checks"
  has "$(section_run "$(fake_clone 0 2)")" "warn a headless check could not run"
fi

case_ "selftest's section: no clone: a warning that says how to make one, nothing run"
: >"$RAN"; d=$TMP/home3; mkdir -p "$d"; has "$(section_run "$d")" "warn no clone with the checks"; eq "$(cat "$RAN")" ""
done_
