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
| research2 (notes for T31a, T36–T39) | 19:15, squashed, 9a4f9c2 | PASS, reviewed by me (notes only: every digest read, sources and honesty checked) | One fixed in the merge: its handover named the commits that held his hardware serials and IPv6 prefix; a public note must not point at them. Identifiers absent from this branch's history (`git log -S`: 0). No tests touched: nothing reads these files |

## Baseline
Suite of main 202903b, the tree before any merge: running since 17:45 (`~/.cache/r27-integrate/suite-base-202903b.log`). Its red files are not any lane's fault.

## What main must do to merge and apply
- **Never remove a lane's worktree or local branch while the conductor runs.** `done_lane` reads the note in `~/repos/fk-NAME`: with the folder gone the lane counts as not finished, and `start_lane` makes a new worktree and starts it again (from main, if the branch is gone too). Remove them only after the round's `.claude/DONE`, or take the lane out of `~/.config/fedokawaii/r27-lanes` first. This overrides T25m's "the worktree gone".
- **research2:** nothing to apply. Its note has ledger lines ready to paste (r27-N numbering is main's), and says where the plan's text for T36–T39 is out of date.

## Open questions
(none)
