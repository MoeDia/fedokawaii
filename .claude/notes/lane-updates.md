# lane-updates — T45, T46 (the mechanism), T48, T49 (owner 4 Nov 17:32: finished, tested, pushed, DONE by 21:30; merge-ready 20:30)

VM: `r27-updates` (port 2290; ~/VM/harness/r27-updates; clone of f44's states, rebased onto its own base image). Frozen trees for proofs: ~/.cache/r27-updates/tree.

## Status (newest first)
- 18:58 T46 code committed (lib/move.sh, tools/vm-preflight.sh; test_upgrade, test_status green). T45 (i) built: the button updates fedokawaii itself from the newest v… tag (test_toolkit_move 49/0). Super+U: one item, update (the rows "fedokawaii" and "Fedora N" gone). tools/vm-inject/lib.sh, run-all.sh (27 rows), release-move.sh written. The real 44 → 45 in VM r27-updates: build running (state "armed", then green, cut, red); then the host pre-flight (vm-preflight.sh 45 --ram 4096); then run-all.
- 17:50 started; design + code read; VM cloned and booting; baseline apply running.

## What main must do to merge and apply
(filled in as it is built)

## Open questions
none

## OWNER 18:15 — memory
The PC is at 26 of 31 GB RAM with 21 agents. Your VMs: at most 4 GB RAM each, shut them down as soon as a test ends, never two of yours at once.
