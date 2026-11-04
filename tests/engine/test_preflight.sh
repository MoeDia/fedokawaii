#!/usr/bin/env bash
# tests/engine/test_preflight.sh — tools/vm-preflight.sh, the test VM the update button runs before a
# new Fedora, with stand-ins for the VM's own tools: green, red with the failing checks named, "could
# not run" (no verdict), the VM gone afterwards whatever came of it, a toolkit without .git given a
# throw-away copy that goes too. The real run: tools/vm-preflight.sh on the PC (lane-updates' notes).
. "$(dirname "$0")/lib.sh"

# the tool beside stand-ins, as in a toolkit (no .git). $S/smoke-rc, $S/smoke-summary, $S/verify-log,
# $S/check-red, $S/create-rc shape what they answer; every call in $S/log
fresh() {
  sandbox
  T=$TMP/toolkit S=$TMP/say
  mkdir -p "$T/tools/vm-inject" "$S"
  cp "$REPO/tools/vm-preflight.sh" "$T/tools/"
  mk() { printf '%s\n' '#!/bin/bash' "echo \"${1##*/} \$*\" >>$S/log" "${2:-exit 0}" >"$T/tools/$1"; }
  mk vm-create.sh "mkdir -p \$HOME/VM/harness/\$1; exit \$(cat $S/create-rc 2>/dev/null || echo 0)"
  mk vm-smoke.sh "d=\$HOME/VM/harness/\$1/smoke-1; mkdir -p \$d; [ -f $S/smoke-summary ] && cp $S/smoke-summary \$d/summary; [ -f $S/verify-log ] && cp $S/verify-log \$d/verify.log; exit \$(cat $S/smoke-rc 2>/dev/null || echo 0)"
  mk vm-snap.sh "[ \"\$2\" = destroy ] && rm -rf \$HOME/VM/harness/\$1; exit 0"
  mk vm-run.sh
  mk vm-inject/f45-checks.sh "[ -f $S/check-red ] && cat $S/check-red; echo 'ok        tty1'; exit 0"
  stub virt-install; stub virsh; stub qemu-img; stub renice
  stub df 'printf "Avail\n %s\n" "$(cat "$TMP/say/avail" 2>/dev/null || echo 900G)"'
  # (the machine's KVM: the harness cannot take /dev/kvm away, so this file runs only where it is there)
  mkdir -p "$HOME/VM/harness"
  out=$TMP/out
}
pf() { bash "$T/tools/vm-preflight.sh" 45 --out "$out" --port "$PORT" "$@" 2>"$TMP/err"; }
PORT=61099
[[ -r /dev/kvm && -w /dev/kvm ]] || { printf '%s: skipped — no /dev/kvm here\n' "$(basename "$0" .sh)"; exit 0; }

case_ "green: Fedora 45 made, this desktop on it, checked; nothing in the verdict; the VM gone"
fresh; pf; eq "$?" 0 "$(tail -n3 "$TMP/err")"; eq "$(cat "$out")" ""
has "$(cat "$S/log")" "vm-create.sh pf-45 --release 45 --port $PORT --ram 8192"; has "$(cat "$S/log")" "vm-smoke.sh pf-45"; has "$(cat "$S/log")" "f45-checks.sh pf-45"
has "$(cat "$S/log")" "vm-snap.sh pf-45 destroy"; [[ ! -e $HOME/VM/harness/pf-45 ]] && _ok || _no "the VM stayed"
case_ "--ram, --name, --keep: its size and its name; kept, to look at it"
fresh; pf --ram 4096 --name try --keep; eq "$?" 0; has "$(cat "$S/log")" "vm-create.sh try --release 45 --port $PORT --ram 4096"; [[ -d $HOME/VM/harness/try ]] && _ok || _no "not kept"
case_ "red: the desktop does not install or start there — the reason, then what verify names; the VM gone"
fresh; echo 1 >"$S/smoke-rc"; echo '2026-11-04 · pf-45 · red · verify exit 3 · 2 of 250 checks failed' >"$S/smoke-summary"
printf '    \033[31m✘\033[0m  waybar config loads\n    ✘  mako running\n' >"$S/verify-log"
pf; eq "$?" 1; w=$(cat "$out"); has "$w" "verify exit 3"; has "$w" "waybar config loads"; has "$w" "mako running"
[[ ! -e $HOME/VM/harness/pf-45 ]] && _ok || _no "the VM stayed"
case_ "red with nothing written: said so, never an empty red"
fresh; echo 1 >"$S/smoke-rc"; pf; eq "$?" 1; has "$(cat "$out")" "the install stopped, with no reason written"
case_ "the desktop starts, what a new Fedora brings is red: named"
fresh; echo 'red       python: 2 programs warn' >"$S/check-red"; pf; eq "$?" 1; eq "$(cat "$out")" "python: 2 programs warn"
case_ "Fedora 45 cannot be installed (its tree, the network): no verdict on Fedora 45, said"
fresh; echo 1 >"$S/create-rc"; pf; eq "$?" 2; has "$(cat "$out")" "could not be installed in the test VM"; not_called vm-smoke
case_ "too little room in the home: no verdict, said"
fresh; echo 10G >"$S/avail"; pf; eq "$?" 2; has "$(cat "$out")" "only 10 GB free in your home; the test VM needs 40"; [[ ! -s $S/log ]] && _ok || _no "$(cat "$S/log")"
case_ "the port taken: no verdict"
fresh; python3 -I -c 'import socket,time; s=socket.socket(); s.bind(("127.0.0.1",61098)); s.listen(); time.sleep(8)' & l=$!; sleep 0.5
bash "$T/tools/vm-preflight.sh" 45 --out "$out" --port 61098 2>/dev/null; eq "$?" 2; has "$(cat "$out")" "port 61098 is taken"; kill "$l" 2>/dev/null; wait "$l" 2>/dev/null
case_ "from a toolkit with no .git: a throw-away copy is what goes in, and it goes"
fresh; pf; eq "$?" 0; n=$(find "$HOME/.cache" -maxdepth 1 -name 'tmp.*' | wc -l); eq "$n" 0 "the copy gone"
case_ "a VM left by a run that was cut: never kept"
fresh; mkdir -p "$HOME/VM/harness/pf-45/old"; pf; eq "$?" 0; has "$(sed -n 1p "$S/log")" "vm-snap.sh pf-45 destroy"
case_ "no argument: misuse"
fresh; bash "$T/tools/vm-preflight.sh" 2>/dev/null; eq "$?" 2

done_
