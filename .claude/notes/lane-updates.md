# lane-updates — T45, T46 (the mechanism), T48, T49 (owner 4 Nov 17:32: finished, tested, pushed, DONE by 21:30; merge-ready 20:30)

VM: `r27-updates` (port 2290; ~/VM/harness/r27-updates; clone of f44's states, rebased onto its own base image). Frozen trees for proofs: ~/.cache/r27-updates/tree.

## Status (newest first)
- 19:11 PC dry run (`dnf5 --releasever=45 distro-sync --assumeno`, a throw-away cache): without --allowerasing it fails: Fedora 45's protobuf-compiler 33 vs grpc-cpp (a dependency of libarrow-flight here). With it (do_move's second try): 1916 upgrades, 38 new, 4 harmless downgrades (gh, pyOpenSSL, xen-libs, xen-licenses: F44's updates newer than F45's day-one), one removal: protobuf-compiler, nobody needs it. 2 GiB to fetch. So the PC's move resolves.
- 18:58 T46 code committed (lib/move.sh, tools/vm-preflight.sh; test_upgrade, test_status green). T45 (i) built: the button updates fedokawaii itself from the newest v… tag (test_toolkit_move 49/0). Super+U: one item, update (the rows "fedokawaii" and "Fedora N" gone). tools/vm-inject/lib.sh, run-all.sh (27 rows), release-move.sh written. The real 44 → 45 in VM r27-updates: build running (state "armed", then green, cut, red); then the host pre-flight (vm-preflight.sh 45 --ram 4096); then run-all.
- 17:50 started; design + code read; VM cloned and booting; baseline apply running.

## What main must do to merge and apply
Merge: lane-integrate carries it. New files: lib/move.sh, tools/vm-preflight.sh, tools/vm-inject/{lib,run-all,release-move}.sh, tests/installer/test_toolkit_move.sh, tests/installer/stubs/rpmdb. Super+U loses the rows "fedokawaii" and "Fedora N"; lane-pixels' row work merges beside it.
The PC's move, after the merged apply: (1) the test VM's verdict: `bash tools/vm-preflight.sh 45 --ram 4096 --out /tmp/pf` from the merged tree (about an hour; green writes nothing by itself) then `printf 'green %s pc\n\n' "$(date +%s)" | sudo tee /var/lib/fedokawaii/update/preflight-45` — or take the lane's green run below, it stays valid 30 days whatever the toolkit; (2) tell him on the page 2 minutes before; (3) `sudo fedokawaii upgrade --now`: the update first, then the whole move in a copy, the snapshot, the download, a notice, 30 seconds, the restart. The next start judges it before the login (20–40 minutes in all on tty1); greetd's [initial_session] as CLAUDE.md START 4 if the desktop must come back unattended. A red ends back on Fedora 44 with one more restart, said on login and in UPD/report.

For the final ISO (T56/T54b): tag the commit it is built from `vYYYY.MM.DD` and push the tag: that is what every later press of the button adopts (only v… tags, only forward; no tag yet: the toolkit stays, nothing asked). build-iso.sh should put the tag in a file `RELEASE` in the toolkit's tar (one line): setup records it, so the first press does not fetch the same release again; without it, only a harmless re-fetch. A machine set up from the ISO (MODE build) follows the releases; `fedokawaii apply` or `pull` marks it as following its copy (/var/lib/fedokawaii/toolkit-from-copy).

## Open questions
none

## OWNER 18:15 — memory
The PC is at 26 of 31 GB RAM with 21 agents. Your VMs: at most 4 GB RAM each, shut them down as soon as a test ends, never two of yours at once.
