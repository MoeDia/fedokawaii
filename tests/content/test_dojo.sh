#!/usr/bin/env bash
# tests/content/test_dojo.sh — dojo, the learning sandbox: the box is made with ONE host folder
# (~/dojo, labelled), no capabilities, no new privileges, memory/CPU/process caps, ports on
# 127.0.0.1 only; a run outside ~/dojo is refused (3); run gives the command a time limit; wipe
# asks and deletes nothing unless "wipe" is typed; reset never touches ~/dojo. podman is a
# stand-in that logs its arguments (the real box is proved by hand: ledger r28-sb01).
. "$(dirname "$0")/lib.sh"

setup() {
  sandbox
  mkdir -p "$HOME/dojo/p"; echo keep >"$HOME/dojo/p/file.txt"
  # a podman that remembers whether the box runs: "image exists" yes, inspect says running once run
  stub podman 'case $1 in
    image) exit 0 ;;
    inspect) [ -e "'"$TMP"'/up" ] && echo true || echo false; exit 0 ;;
    run) touch "'"$TMP"'/up" ;;
    rm|container) rm -f "'"$TMP"'/up" ;;
  esac'
  rm -f "$TMP/up"
}

case_ "the box: one bind mount (~/dojo, relabelled), no caps, no new privileges, caps, localhost ports"
setup
(cd "$HOME/dojo/p" && dojo run -- true) >/dev/null 2>&1
run=$(grep '^podman run' "$CALLS" | head -n1)
has "$run" "-v $HOME/dojo:$HOME/dojo:Z"
n=$(grep -o ' -v [^ ]*' <<<"$run" | grep -v "dojo-home\|dojo-pg\|$HOME/dojo:" | wc -l); eq "$n" 0 "no other host folder"
has "$run" "--cap-drop=all"; has "$run" "no-new-privileges"
has "$run" "--memory 4g"; has "$run" "--pids-limit 1024"; has "$run" "--cpus 4"
has "$run" "-p 127.0.0.1:8000-8099:8000-8099"
[[ $run != *" -p 8"* && $run != *" -p 0.0.0.0"* && $run != *"--privileged"* ]] && _ok || _no "a public port or privileged: $run"

case_ "run: in the folder under ~/dojo, with a time limit; outside ~/dojo: 3"
setup
(cd "$HOME/dojo/p" && dojo run -t 7 -- python3 x.py) >/dev/null 2>&1
has "$(grep 'exec' "$CALLS" | tail -n1)" "-w $HOME/dojo/p"
has "$(grep 'exec' "$CALLS" | tail -n1)" "timeout --foreground -k 5 7 python3 x.py"
(cd "$HOME" && rc 3 dojo run ls)
rc 3 dojo shell "$HOME/.ssh"
rc 3 dojo shell "$HOME/dojo/../x"

case_ "wipe: asks; anything but wipe deletes nothing; reset leaves the files"
setup
out=$(dojo wipe </dev/null 2>&1); echo "$?" >/dev/null; has "$out" "asks you at a terminal"
[[ -f $HOME/dojo/p/file.txt ]] && _ok || _no "wipe without a terminal deleted"
tty_run 80 bash -c 'echo no | dojo wipe' >/dev/null 2>&1
[[ -f $HOME/dojo/p/file.txt ]] && _ok || _no "wipe answered no deleted"
(dojo reset) >/dev/null 2>&1
[[ -f $HOME/dojo/p/file.txt ]] && _ok || _no "reset deleted a project file"
has "$(cat "$CALLS")" "volume rm"

case_ "misuse: 2; help: 0"
setup; rc 2 dojo frob; rc 2 dojo run -t x ls
rc 0 dojo --help

done_
