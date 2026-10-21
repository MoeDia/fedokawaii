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

# trapped CODE · trapped_theme CODE — CODE under setup.sh's (theme.sh's) own error report: its ERR
# trap as the script sets it, errexit and pipefail on, contained as setup has it
SETUP_TRAP=$(awk '/^trap .rc=\$\?; \(\(BASH_SUBSHELL == 0\)\)/ { on = 1 } on { print } on && /. ERR$/ { exit }' "$REPO/setup.sh")
THEME_TRAP=$(grep -m1 "^trap 'rc=\$?; ((BASH_SUBSHELL == 0))" "$REPO/theme.sh")
CONTAINED=$(awk '/^contained\(\) \{/ { on = 1 } on { print } on && /^}/ { exit }' "$REPO/setup.sh")
[[ $SETUP_TRAP == *"' ERR" && $THEME_TRAP == *"' ERR" && $CONTAINED == *"CONTAINED_RC=\$?"* ]] || echo "test_common: setup.sh's or theme.sh's trap not found" >&2
trapped() {   # (a script file, as setup is one: its lines and its call stack as a script's)
  printf '%s\n' 'set -Eeuo pipefail' "IFS=\$'\\n\\t'" ". '$REPO/lib/common.sh'" 'CONTAINED_RC=0' "$CONTAINED" \
    "${TRAP:-$SETUP_TRAP}" "$1" >"$TMP/trapped.sh"
  OUT=$(LOG_FILE=${LOGF:-$TMP/log} bash "$TMP/trapped.sh" 2>&1); RC=$?
}
trapped_theme() { TRAP=$THEME_TRAP trapped "$@"; }

case_ "setup's error report names the command that failed: run's — not run's own tee or return"
trapped 's_media() { run sh -c "echo from dnf; exit 3"; echo after; }; s_media'
eq "$RC" 3; has "$OUT" "from dnf"; has "$OUT" "in s_media()"; has "$OUT" ": sh -c echo from dnf; exit 3 (exit 3)"
lacks "$OUT" "tee -a"; lacks "$OUT" ": return"; lacks "$OUT" "after"
case_ "…dnf_install's: the whole install named, not its return; each package alone first, the one at fault said"
stub dnf 'exit 1'
trapped 's_base() { dnf_install foo bar; echo after; }; s_base'
eq "$RC" 1; has "$OUT" "dnf attempt 3/4 failed (other)"; has "$OUT" ": dnf -y install foo bar (exit 1)"
has "$OUT" "✘ dnf could not install 2 of 2 package(s):"; has "$OUT" "    foo — other: "
lacks "$OUT" ": return"; lacks "$OUT" "after"
case_ "dnf_install: what a new try mends is tried again (fresh metadata, longer pauses); what none mends stops at once"
# dnf FAILS-LEFT MESSAGE — dnf failing that many times with dnf's own words, then installing
dnf_failing() { echo "$1" >"$TMP/dnf-left"; stub dnf "n=\$(cat \$TMP/dnf-left); if [ \"\$n\" -gt 0 ]; then echo \$((n - 1)) >\$TMP/dnf-left; echo '$2' >&2; exit 1; fi; exit 0"; }
stub rpm 'exit 1'
for m in "Librepo error: Status code: 404 for https://mirror/x.rpm|net" "Cannot prepare internal mirrorlist: metalink|net" \
         "Downloading successful, but checksum does not match|checksum" "Curl error (18): Transferred a partial file|net" \
         "Failed to obtain rpm transaction lock. Another transaction is in progress.|lock" "Signature verification failed. OpenPGP check|gpg"; do
  reset_calls; dnf_failing 2 "${m%|*}"
  lib 'dnf_install foo bar; echo "rc=$?"'; has "$OUT" "rc=0" "${m#*|}: in on the third try"
  has "$OUT" "dnf attempt 1/4 failed (${m#*|})"; has "$OUT" "dnf attempt 2/4 failed (${m#*|})"
  eq "$(grep -c -- "--refresh" "$CALLS")" 2 "${m#*|}: every try after a failure refreshes the metadata (another mirror)"
done
lib 'dnf_install foo; echo "rc=$?"'; has "$OUT" "rc=0"
reset_calls; dnf_failing 9 "Error: No match for argument: foo"
lib 'mkdir -p $STATE_DIR; dnf_install foo; echo "rc=$?"'; has "$OUT" "rc=1"
lacks "$OUT" "dnf attempt" "a name no repository has: never tried again"
has "$OUT" "foo — missing: no enabled repository has 'foo' — renamed or retired in this Fedora?"
eq "$(grep -c '^dnf' "$CALLS")" 1; eq "$(cat "$TMP/state/dnf-failed")" "foo|missing" "kept for the health report"
case_ "dnf_install: a batch with one bad name — each alone, the good ones in, only the bad one named"
stub dnf 'for a; do [ "$a" = renamedpkg ] && { echo "No match for argument: renamedpkg" >&2; exit 1; }; done; exit 0'
lib 'mkdir -p $STATE_DIR; dnf_install --allowerasing a renamedpkg b; echo "rc=$?"'; has "$OUT" "rc=1"
has "$OUT" "✘ dnf could not install 1 of 3 package(s):"; has "$OUT" "renamedpkg — missing"; lacks "$OUT" "    a — "
called '^dnf -y install --allowerasing a --refresh$'; called '^dnf -y install --allowerasing b --refresh$'
lib 'dnf_install renamedpkg2; echo "rc=$?"'; has "$OUT" "rc=0"
lib 'printf "%s\n" "x|net" "renamedpkg2|missing" >$STATE_DIR/dnf-failed; dnf_install renamedpkg2; cat $STATE_DIR/dnf-failed'
has "$OUT" "x|net"; lacks "$OUT" "renamedpkg2|" "a package in at last leaves the list"
case_ "dnf_install: the network down — no each-alone round (none would get through), the fix said"
reset_calls; dnf_failing 9 "Curl error (6): Could not resolve host: mirrors.fedoraproject.org"
lib 'dnf_install a b; echo "rc=$?"'; has "$OUT" "rc=1"; eq "$(grep -c '^dnf' "$CALLS")" 4 "four tries, no more"
has "$OUT" "a — net: the network or the mirrors failed every try"
eq "$(grep '^sleep' "$CALLS" | tr '\n' ' ')" "sleep 15 sleep 30 sleep 45 " "pauses that grow, none after the last"
case_ "dnf_install: a full disk is said at once, with the fix"
reset_calls; dnf_failing 9 "Error: not enough free space: 512 MB more space needed on /"
lib 'dnf_install a; echo "rc=$?"'; has "$OUT" "rc=1"; has "$OUT" "a — disk: the disk is full — df -h /"; eq "$(grep -c '^dnf' "$CALLS")" 1
stub rpm 'exit 0'
trapped 's_dwl() { retry 2 10 false --fetch codeberg; }; s_dwl'; has "$OUT" "in s_dwl(), called from line"; has "$OUT" ": false --fetch codeberg (exit 1)"
case_ "…a plain command as it is; one run saw fail earlier, and dealt with, is never named for another"
trapped 'f() { echo x | grep -q y; echo after; }; f'; has "$OUT" ": grep -q y (exit 1)"; lacks "$OUT" after
trapped $'run false || true\ng() { return 4; }\ng'; has "$OUT" ": return 4 (exit 4)"; lacks "$OUT" ": false"
case_ "…inside contained (update's and repair's steps): run's command named; a function that said why stays quiet"
trapped $'contained run sh -c "exit 5"; echo "rc=$CONTAINED_RC"\nf() { log "f: the reason"; return 1; }\ncontained f; echo "rc=$CONTAINED_RC"'
has "$OUT" ": sh -c exit 5 (exit 5)"; has "$OUT" "rc=5"; has "$OUT" "f: the reason"; has "$OUT" "rc=1"; lacks "$OUT" ": return 1"
case_ "theme.sh's error report: the same"
trapped_theme 'f() { run sh -c "exit 6"; }; f'; eq "$RC" 6; has "$OUT" "in f(), called from line"; has "$OUT" ": sh -c exit 6 (exit 6)"
trapped_theme 'false'; has "$OUT" ": false (exit 1)"
case_ "a log that cannot be written (a full disk) never stops a run: run's status is its command's"
LOGF=$TMP/no-such-folder/log trapped 'log "one"; run true; run sh -c "echo two"; echo "went on"'
eq "$RC" 0; has "$OUT" "▸ one"; has "$OUT" "two"; has "$OUT" "went on"
LOGF=$TMP/no-such-folder/log trapped 'run sh -c "exit 7"; echo after'; eq "$RC" 7; has "$OUT" ": sh -c exit 7 (exit 7)"

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
eq "$OUT" "    ✔  a
    !  b — why

  ✔  verified — 1 checks passed, 1 warning(s)
rc=0" "a row: 4 spaces, the mark, 2 spaces; the verdict: 2, the mark, 2 (not on a terminal: no colour, no wrapping)"
lib 'pass "a"; fail "b" "why"; check "c" false; summary "verified"; echo "rc=$?"'
eq "$OUT" "    ✔  a
    ✘  b — why
    ✘  c

  ✘  2 of 3 checks failed:
       b — why
       c
rc=1" "each failure listed again under the verdict, 7 spaces in"
lib 'info "note"'; eq "$OUT" "    ·  note"
case_ "check: a probe that fails, or one that is not there, is a failure — never a pass"
lib 'check "x" no-such-command-kawa; summary v; echo "rc=$?"'; has "$OUT" "    ✘  x"; has "$OUT" "rc=1"

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

done_
