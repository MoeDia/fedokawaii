# lane-integrate — the merger and the master gate (T19n, T25m)

Started 4 Nov 17:42. Main merges **lane-integrate only** (plan, TONIGHT 17:42); lane-updates must be through here by about 20:30, because main upgrades the PC around 21:00.

## How a pass runs (read this, not the whole plan)
1. `bash ~/.cache/r27-integrate/status.sh`: every lane's note (worktree and committed), pushed or not, merged or not, conflicts against lane-integrate, and the suites' last lines.
2. A lane is ready when its committed note has a line that is only the word (the conductor's regex) and its branch is pushed. Review its whole diff (`git diff $(git merge-base lane-integrate lane-X) lane-X`), strictly, against CLAUDE.md and its plan task; big code lanes go to a fresh master (Agent, model fable, effort max, T19n), notes-only lanes I review myself.
3. Fix what fails, on lane-integrate, after the merge (never in the lane's worktree while its loop runs).
4. `git merge --no-ff main`, then `git merge --no-ff lane-X`; the areas it touched, then the whole suite (`setsid -f bash ~/.cache/r27-integrate/suite.sh LABEL [AREA…]`; niced, cut off from the session, runs from a copy, so the tree can move on meanwhile). Push only what is green: lane-iso rebuilds from this branch whenever it moves.
5. Log it below. Commits: `git -c user.name='Mohamed Eldoush' -c user.email='49558059+MoeDia@users.noreply.github.com' commit`, ending with the Co-Authored-By line.

Fences: no apply, no sudo, no VM, no service or dwl restart; probes with `env -u WAYLAND_DISPLAY -u DISPLAY DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent XDG_RUNTIME_DIR=<own dir>`; never `git stash` bare; `/usr/bin/grep` when reproducing a test's grep.

**This note must never hold a line that is only the finishing word.** My registry line says never to write it ("all night"); the generic lines after it say to end with it. I decided the task's own line wins: writing it stops this unit for good (the conductor), and a lane finishing after that would go unmerged. The round's `.claude/DONE` ends this lane. By 21:30 this note says exactly what is merged and what is left for main.

## Merges and verdicts
| Lane | Merged | Verdict | Findings |
|---|---|---|---|
| research2 (notes for T31a, T36–T39) | 19:13, squashed, 9a4f9c2 | PASS, reviewed by me (notes only: every digest read, sources and honesty checked) | One fixed in the merge: its handover named the commits that held his hardware serials and IPv6 prefix; a public note must not point at them. Identifiers absent from this branch's history (`git log -S`: 0). No tests touched: nothing reads these files |
| research (T55; T32 as a record) | 19:20, 509e97b | PASS, reviewed by me (notes only: T55's accept checked against `iso-design.md`: boot flow, questions, kickstart, pinned inputs, Secure Boot, test matrix; the handover read in full, the digests by structure and sampled; the lane's own check fetched all 128 links) | None to fix. No identifiers in its history (`git log -S`, MAC and IPv6 patterns). `vm-design.md` and `vm-research.md` are records since the VM was dropped (17:38) |

## Baseline
No complete run yet. Two tries stopped by me: 202903b (17:45 to 18:36, serial, 49 of 129 files) and 8935ee7 (18:36 to 20:03, 53 of 129). On 8935ee7 three files were red on first try, not retried: content/test_fetch, content/test_tiles (the prompt's and fetch's new heads), engine/test_menu (a row's mark at column 66, expected 68). Seven installer files hit my 25-minute limit, but they were waiting, not hung: the harness allows one fake machine on the whole PC (`/tmp/kawa-installer-tests.lock`, shared with every lane's suite), so the installer area queues behind all of them. `suite.sh` now runs the other areas first, the installer area last and one at a time, and its limit only catches hangs.

## What main must do to merge and apply
- **Never remove a lane's worktree or local branch while the conductor runs.** `done_lane` reads the note in `~/repos/fk-NAME`: with the folder gone the lane counts as not finished, and `start_lane` makes a new worktree and starts it again (from main, if the branch is gone too). Remove them only after the round's `.claude/DONE`, or take the lane out of `~/.config/fedokawaii/r27-lanes` first. This overrides T25m's "the worktree gone".
- **research2:** nothing to apply. Its note has ledger lines ready to paste (r27-N numbering is main's), and says where the plan's text for T36–T39 is out of date. Its unit stopped at 19:14:32 and I deleted its branch on origin at 19:15 (T25m), because the branch's history held those identifiers; the only remote ref that did, no forks. The local branch stays, and the shared `refs/remotes/origin/lane-research2` was put back by hand so other lanes' `git show origin/lane-research2:…` still works: **never push that branch again, and do not run `git fetch --prune` before those lanes have finished.** GitHub still serves the old commits by exact id (`gh api`: exit 0), so the owner has been told on his page; only GitHub Support can purge them.
- **research:** nothing to apply. Plan and ledger items 2–8 in its note (`lane-research.md`, "What the main run must do to merge"): fold `iso-design.md` §9 into T45, T47, T56 and T57; `f45-changes.md` line 81 is wrong. Mark T55 done. Mark T32 as a record, not done: the VM is gone, ASOBI holds that number now. Its "Found on the way" list is real work for main: **a kernel bug on exactly this card** (amdgpu #6062: all cores stall up to about 65 ms on a static screen, heard as audio glitches, not yet measured here: T60), **`~/VM` in his backups** (86 GiB of harness, `bin/kawa-backup:223` and `backup-exclude`), `theme.sh`'s GRUB fonts under Secure Boot.

## The machine (20:03)
PID 1 and the user manager have been in D state since about 19:51, and zombies were past 13,000 and rising about 1,000 a minute (`pids.max` 81,548). A kernel Oops at 19:15:04, global OOM kills at 18:15 and 19:48, page allocation failures at 18:01 and 18:06, and the filesystem's first ten checksum errors ever, the last three on files that now read clean. Main was told by message at 20:02 with the full evidence, the owner on his page at 20:03; the restart is theirs. I stopped my own suite and start no heavy test until it is resolved. A pass that finds the same state: keep reviewing with light checks.

## Open questions
- For lane-iso's gate, from research's note: its erase came before Anaconda's checks, so a passing mirror fault could leave a blank disk. It must be fixed before that lane passes.

## OWNER VERDICT 2026-11-04 19:29 on your render fk-remote-install: comment
This exception to your hard limits is allowed by the owner for this one command only (it is not a design render).
OWNER-AUTHORISED ONE-OFF (he said yes at 19:22, relayed by Claude): install the cleaned-up remote page now, before anything else in your pass. It is only the page's two files plus a restart of fk-remote (no sudo, nothing else touched). Skip it if ~/.local/share/fedokawaii/remote/server.py already contains the word selfupdate. Command, exactly:
d=$(mktemp -d) && git clone -q -b remote --depth 1 https://github.com/MoeDia/fedokawaii $d/r && grep -q selfupdate $d/r/server.py && install -m644 $d/r/server.py $d/r/index.html ~/.local/share/fedokawaii/remote/ && systemctl --user restart fk-remote && rm -rf $d && echo installed
Then append one line to ~/repos/fedokawaii/.claude/inbox.md: "## <time> — fk-remote v5 installed by <who>". From now on the page updates itself (its "update this page" button), so this is the last time anyone installs it by hand.
