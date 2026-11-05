#!/usr/bin/env bash
# the patch for the main run, made against main as it stands now
T=$(mktemp -d /dev/shm/lane-typing/wire.XXXX)
git -C /home/dia/repos/fedokawaii archive main system/fedokawaii tests/engine/test_menu.sh bin/kawa-help tests/menus/test_help.sh docs/design-system.md | tar -x -C "$T"
cd "$T" && git init -q . && git add -A >/dev/null && git -c user.name=x -c user.email=x@x commit -qm base
python3 -I /dev/shm/lane-typing/scratch/wiring.py || exit 1
git add -N configs/home/.config/fedokawaii/keys/typing.txt
git diff > /home/dia/repos/fk-typing/.claude/notes/lane-typing-wiring.patch
git -C /home/dia/repos/fedokawaii log -1 --format='against main %h %ci' main
wc -l /home/dia/repos/fk-typing/.claude/notes/lane-typing-wiring.patch
git reset -q; git checkout -q .; rm -f configs/home/.config/fedokawaii/keys/typing.txt; git apply --check /home/dia/repos/fk-typing/.claude/notes/lane-typing-wiring.patch && echo applies
cd /; rm -rf "$T"
