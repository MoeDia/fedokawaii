#!/usr/bin/env bash
# tests/regress/test_lock.sh — never again a wrong password that takes two seconds to say so (bug 4,
# r27-20-wire-2: PAM's own delay) or a lock that fails taking another lock screen with it (r26-fu-9:
# "kawa-lock killed every gtklock on its 10 s failure"). The PAM file is read; the kill is watched
# through a stand-in pkill that kills nothing.
. "$(dirname "$0")/lib.sh"
. "$REPO/tests/look/lib.sh"
need python3 flock setsid

case_ "a wrong password reports fast: PAM's delay 300 ms, pam_unix without its own; setup installs it, verify holds it"
pam=$REPO/system/gtklock.pam
ms=$(sed -n 's/^auth .*pam_faildelay\.so delay=\([0-9]*\).*/\1/p' "$pam")
((ms > 0 && ms <= 300000)) && _ok || _no "pam_faildelay delay=$ms µs (at most 300000: libpam spreads it to 0.45 s)"
has "$(grep -E '^auth .*pam_unix' "$pam")" nodelay "pam_unix keeps its own 2 s"
lacks "$(grep -v '^#' "$pam")" "include" "a stack included brings its delay back"
grep -q 'lock_pam' "$REPO/setup.sh" && _ok || _no "setup.sh no longer installs the file"
grep -q 'gtklock' <(grep -n 'pam' "$REPO/verify.sh") && _ok || _no "verify no longer holds the file"
item "r27-bug-4b r27-20-wire-2" "pam_faildelay $((ms / 1000)) ms (0.15–0.45 s as libpam spreads it), pam_unix nodelay"

case_ "only its keeper's own gtklock: a lock that never comes kills nothing else"
# (every kill of a gtklock anywhere in the desktop names its parent; the one that fired, watched)
l=$(grep -rnE '(pkill|killall)[^#]*gtklock' "$REPO/bin" "$REPO/system" "$REPO/configs/home" 2>/dev/null)
while IFS= read -r x; do [[ -z $x ]] && continue; [[ $x == *-P* ]] && _ok || _no "kills every gtklock: ${x#"$REPO"/}"; done <<<"$l"
look
config .config/fedokawaii/lock.ui .local/share/fedokawaii/dark .local/share/fedokawaii/light
argv gtklock 'trap "exit 0" TERM; while :; do /bin/sleep 0.05; done'
argv wlopm; stub logger
mkdir -p "$HOME/.local/lib/fedokawaii"; : >"$HOME/.local/lib/fedokawaii/kawa-lockmod.so"
stub pkill 'echo "$@" >>"$TMP/pkill.args"'
daemon dwl >/dev/null
kawa-lock >/dev/null 2>&1; r=$?
eq "$r" 1 "a lock that never came is a failure"
a=$(cat "$TMP/pkill.args" 2>/dev/null)
has "$a" "-P" "pkill without its parent named: it would take the owner's lock screen too"
has "$a" gtklock
item r26-fu-9 "given up after 10 s: pkill ${a:-(not called)}"
done_
