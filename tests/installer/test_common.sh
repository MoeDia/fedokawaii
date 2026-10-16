#!/usr/bin/env bash
# tests/installer/test_common.sh — lib/common.sh's plumbing, which every installer script stands
# on: output and the log, run (its status, not tee's), retry (tries, pauses — none after the
# last), step (done once, a "/" in a name), write_file (whole or not at all), user_put (written
# by the user, never through a planted link), take_lock (one run at a time, said plainly),
# make_tmp (removed on exit), the report (pass/warn/fail/summary), the wlroots copy kept for dwl.
# (user_put, which needs the fake machine's user: test_upstream.sh)
FK_PURE=1 . "$(dirname "$0")/lib.sh"
sandbox
# lib CODE — bash CODE with lib/common.sh loaded (its log in $TMP/log), here as this user
lib() { OUT=$(LOG_FILE=$TMP/log STATE_DIR=$TMP/state bash -c '. "$1/lib/common.sh"; eval "$2"' _ "$REPO" "$1" 2>&1); RC=$?; }
stub sleep

case_ "log, ok, die: one line each, also in the log; die on stderr, exit 1"
lib 'log "a  b"; ok "done"'; has "$OUT" "▸ a  b"; has "$OUT" "✔ done"; has "$(cat "$TMP/log")" "✔ done"
lib 'die "broken"; echo after'; eq "$RC" 1; has "$OUT" "✘ broken"; lacks "$OUT" after
err=$(LOG_FILE=$TMP/log bash -c '. "$1/lib/common.sh"; die "x"' _ "$REPO" 2>&1 >/dev/null); has "$err" "✘ x" "die writes to stderr"
case_ "the IFS of the scripts (newline + tab): words still joined with spaces"
lib 'IFS=$'"'"'\n\t'"'"'; log one two "three four"'; has "$OUT" "▸ one two three four"

case_ "run: the command shown and logged, its own exit status (not tee's)"
lib 'run false; echo "rc=$?"'; has "$OUT" '$ false'; has "$OUT" "rc=1"
lib 'run sh -c "echo out; exit 7"; echo "rc=$?"'; has "$OUT" "rc=7"; has "$(cat "$TMP/log")" "out"

case_ "retry: as many tries as asked, the pause between them — and none after the last (it gives up at once)"
reset_calls; lib 'retry 3 10 false; echo "rc=$?"'
has "$OUT" "rc=1"; has "$OUT" "attempt 1/3 failed: false — retrying in 10s"; has "$OUT" "attempt 2/3 failed"
lacks "$OUT" "attempt 3/3 failed: false — retrying" "no 'retrying' after the last try"
eq "$(grep -c '^sleep' "$CALLS")" 2 "two pauses for three tries"
case_ "retry: a command that works the second time returns 0; one that works at once, no pause"
reset_calls; lib 'c=0; f() { c=$((c + 1)); ((c >= 2)); }; retry 3 5 f; echo "rc=$? c=$c"'
has "$OUT" "rc=0 c=2"; eq "$(grep -c '^sleep' "$CALLS")" 1
reset_calls; lib 'retry 3 5 true; echo "rc=$?"'; has "$OUT" "rc=0"; not_called '^sleep'

case_ "step: runs once, recorded; a second time skipped; a '/' in its name never makes a folder"
lib 'f() { echo ran; }; step "1.2 a/b step" f; step "1.2 a/b step" f'
eq "$(grep -c '^ran$' <<<"$OUT")" 1; has "$OUT" "skip (done): 1.2 a/b step"
[[ -f "$TMP/state/done.1.2 a-b step" ]] && _ok || _no "no mark (or a folder made of the /)"
case_ "step: a function that fails is not recorded as done"
lib 'set -e; f() { false; }; step "2.0 failing" f' ; [[ ! -e "$TMP/state/done.2.0 failing" ]] && _ok || _no "a failed step was marked done"

case_ "write_file: whole or not at all, the mode asked, a link in its place replaced (not followed)"
mkdir -p "$TMP/wf"; echo secret >"$TMP/wf/target"; ln -s "$TMP/wf/target" "$TMP/wf/f"
lib "printf 'new\n' | write_file '$TMP/wf/f' 0600"
eq "$(cat "$TMP/wf/target")" secret "the link's target untouched"; [[ ! -L $TMP/wf/f ]] && _ok || _no "still a link"
eq "$(cat "$TMP/wf/f")" new; eq "$(stat -c %a "$TMP/wf/f")" 600
lib "write_file '$TMP/wf/g' </dev/null"; eq "$(stat -c %a "$TMP/wf/g")" 644 "the default mode"
eq "$(find "$TMP/wf" -name '.*' | wc -l)" 0 "no temp file left beside it"
case_ "write_file never changes the folder it writes into (its mode stays); one it cannot write: fails, the old file kept"
mkdir -p "$TMP/ro"; echo old >"$TMP/ro/f"; chmod 555 "$TMP/ro"
lib "echo new | write_file '$TMP/ro/f'; echo rc=\$?"
eq "$(stat -c %a "$TMP/ro")" 555 "the folder's mode"
if [[ $EUID -ne 0 ]]; then has "$OUT" "rc=1"; eq "$(cat "$TMP/ro/f")" old
else _ok; _ok; fi                                                     # (root writes anywhere)
mkdir -p "$TMP/priv"; chmod 700 "$TMP/priv"; lib "echo x | write_file '$TMP/priv/f'"; eq "$(stat -c %a "$TMP/priv")" 700 "a private folder stays private"
lib "echo x | write_file '$TMP/new/sub/f'"; eq "$(stat -c %a "$TMP/new/sub")" 755 "a missing folder is made, 755"
chmod 755 "$TMP/ro"

case_ "take_lock: a second run waits a few seconds, then stops with a plain sentence (exit 1)"
( exec 9>"$TMP/lock"; flock 9; /bin/sleep 8 ) & holder=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do flock -n "$TMP/lock" true 2>/dev/null || break; /bin/sleep 0.2; done
lib "take_lock '$TMP/lock'; echo got"; eq "$RC" 1; lacks "$OUT" got
has "$OUT" "another Fedokawaii run (an update, a repair, setup or Theme) is going on — wait for it to finish"
kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
lib "take_lock '$TMP/lock'; echo got"; has "$OUT" got "free again"
case_ "take_lock on a folder of yours: opened read-only, never truncated or replaced"
mkdir -p "$TMP/d"; echo keep >"$TMP/d/x"; lib "take_lock '$TMP/d'; echo got"; has "$OUT" got; eq "$(cat "$TMP/d/x")" keep

case_ "make_tmp: a private folder, removed when the script ends (also by die)"
lib 'make_tmp; echo "$KAWA_TMP"; die x'; d=$(head -n1 <<<"$OUT")
[[ -n $d && ! -e $d ]] && _ok || _no "the temp folder $d was left"

case_ "the report: pass, warn, fail, info; summary 0 with warnings, 1 with a failure and the list"
lib 'pass "a"; warn "b" "why"; summary "verified"; echo "rc=$?"'
has "$OUT" "✔ a"; has "$OUT" "! b — why"; has "$OUT" "✔ verified — 1 checks passed, 1 warning(s)"; has "$OUT" "rc=0"
lib 'pass "a"; fail "b" "why"; check "c" false; summary "verified"; echo "rc=$?"'
has "$OUT" "✘ 2 of 3 checks failed:"; has "$OUT" "    b — why"; has "$OUT" "    c"; has "$OUT" "rc=1"
case_ "check: a probe that fails, or one that is not there, is a failure — never a pass"
lib 'check "x" no-such-command-kawa; summary v; echo "rc=$?"'; has "$OUT" "✘ x"; has "$OUT" "rc=1"

case_ "wlr_kept / dwl_make_args: the kept copy's flags and an rpath to it"
mkdir -p "$TMP/wl/lib" "$TMP/wl/include/wlroots-0.20"; : >"$TMP/wl/lib/libwlroots-0.20.so"; echo "-I/x" >"$TMP/wl/cflags"
lib "wlr_home() { echo '$TMP/wl'; }; DWL_WLROOTS=0.20; wlr_kept; echo kept=\$?; DWL_MAKE=(A=1 'B=x y'); dwl_make_args"
has "$OUT" "kept=1" "an empty library is not a kept copy"
printf 'x' >"$TMP/wl/lib/libwlroots-0.20.so"
lib "wlr_home() { echo '$TMP/wl'; }; DWL_WLROOTS=0.20; wlr_kept; echo kept=\$?; DWL_MAKE=(A=1 'B=x y'); dwl_make_args"
has "$OUT" "kept=0"; has "$OUT" "B=x y"; has "$OUT" "WLR_INCS=-I/x"; has "$OUT" "-Wl,--disable-new-dtags,-rpath,$TMP/wl/lib"

case_ "the harness's guard: this machine's accounts changed during a test file are caught, and fail it"
# shellcheck disable=SC2034  # (read by host_sums and host_guard)
( HOST_FILES=("$TMP/acct"); echo a >"$TMP/acct"; HOST_SUMS=$(host_sums); echo b >>"$TMP/acct"; host_guard ) 2>"$TMP/guard"
eq "$?" 1; has "$(cat "$TMP/guard")" "THIS MACHINE CHANGED: $TMP/acct"
# shellcheck disable=SC2034
( HOST_FILES=("$TMP/acct"); HOST_SUMS=$(host_sums); host_guard ); eq "$?" 0 "unchanged: quiet"

case_ "keep_dwl_prev: the dwl in place becomes the fallback, by a rename (never written into)"
mkdir -p "$TMP/dwlbin"; printf '#!/bin/sh\necho new\n' >"$TMP/dwlbin/dwl"; chmod 755 "$TMP/dwlbin/dwl"
printf '#!/bin/sh\necho old\n' >"$TMP/dwlbin/dwl.prev"; chmod 755 "$TMP/dwlbin/dwl.prev"; ino=$(stat -c %i "$TMP/dwlbin/dwl.prev")
lib "KAWA_DWL_DIR='$TMP/dwlbin' keep_dwl_prev"; eq "$RC" 0
eq "$(cat "$TMP/dwlbin/dwl.prev")" "$(cat "$TMP/dwlbin/dwl")" "dwl.prev is now the dwl that was in place"
[[ $(stat -c %i "$TMP/dwlbin/dwl.prev") != "$ino" ]] && _ok || _no "dwl.prev written into, not replaced (a running one: Text file busy)"
[[ -z $(find "$TMP/dwlbin" -name '.dwl.prev.*') ]] && _ok || _no "a temporary copy left behind"
case_ "keep_dwl_prev: while a session runs on dwl.prev (the new build failed), the fallback is kept as it is"
printf '#!/bin/sh\necho good\n' >"$TMP/dwlbin/dwl.prev"; printf '#!/bin/sh\necho broken\n' >"$TMP/dwlbin/dwl"
cp /bin/sleep "$TMP/dwl.prev"; "$TMP/dwl.prev" 30 & runner=$!   # (the real sleep: this file stubs sleep)
for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -x dwl.prev >/dev/null && break; /bin/sleep 0.1; done
lib "KAWA_DWL_DIR='$TMP/dwlbin' keep_dwl_prev"; eq "$RC" 0
eq "$(cat "$TMP/dwlbin/dwl.prev")" "$(printf '#!/bin/sh\necho good')" "the working fallback kept"
kill "$runner" 2>/dev/null; wait "$runner" 2>/dev/null
case_ "keep_dwl_prev: no dwl yet — nothing to keep, no error"
rm -f "$TMP/dwlbin/dwl"; lib "KAWA_DWL_DIR='$TMP/dwlbin' keep_dwl_prev"; eq "$RC" 0

done_
