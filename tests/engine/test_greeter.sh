#!/usr/bin/env bash
# tests/engine/test_greeter.sh — kawa-greeter, the login on tty1 (greetd runs it as its own
# user): agreety asks for any user's name and password, then starts the session launcher.
# A launcher that is gone must not turn the login into a loop that only comes back to itself.
. "$(dirname "$0")/lib.sh"

fresh() {
  sandbox
  pointed "$REPO/system/kawa-greeter" "$STUBS/kawa-greeter" "s|/usr/local/bin/start-dwl|$TMP/start-dwl|g"
  printf '#!/bin/sh\nexec dwl\n' >"$TMP/start-dwl"; chmod 755 "$TMP/start-dwl"
  # agreety: says how it was started, and whether it replaced the greeter (same process)
  stub agreety 'echo "agreety pid $$"'
}

case_ "the login: an empty screen, then agreety, which starts the desktop's session"
fresh
out=$(bash -c 'echo "greeter pid $$"; exec kawa-greeter' 2>&1); eq "$?" 0
has "$out" $'\e[H\e[2J\e[3J'
called "^agreety --cmd $TMP/start-dwl\$"
eq "$(sed -n 's/^greeter pid //p' <<<"$out")" "$(sed -n 's/.*agreety pid //p' <<<"$out")" "agreety replaces the greeter (greetd watches that process)"
case_ "verify's check finds the line it looks for (the greeter as setup installs it)"
grep -q 'exec agreety --cmd /usr/local/bin/start-dwl' "$REPO/system/kawa-greeter" && _ok || _no "verify.sh's grep would fail"

case_ "the session launcher missing: said on the screen, and a login gives a text console"
fresh; rm -f "$TMP/start-dwl"
out=$(kawa-greeter 2>&1); eq "$?" 0
has "$out" "fedokawaii repair"; has "$out" "$TMP/start-dwl"
called '^agreety --cmd /bin/bash -l$'
case_ "the launcher there but not executable: the same"
fresh; chmod 644 "$TMP/start-dwl"; kawa-greeter >/dev/null 2>&1; called '^agreety --cmd /bin/bash -l$'
case_ "any user may log in (names with digits, dots, a dash): the greeter names none"
lacks "$(cat "$REPO/system/kawa-greeter")" "--user"; lacks "$(cat "$REPO/system/kawa-greeter")" "USERNAME"
case_ "the messages fit the console (80 columns) and use only what its font has"
fresh; rm -f "$TMP/start-dwl"; out=$(plain "$(kawa-greeter 2>&1)"); out=${out//$TMP\/start-dwl//usr/local/bin/start-dwl}
(( $(widest "$(grep -v '^agreety' <<<"$out")") <= 80 )) && _ok || _no "a line wider than 80"
lacks "$out" "—"; lacks "$out" "·"; lacks "$out" "…"

done_
