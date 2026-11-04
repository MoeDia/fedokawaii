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

## Reviewed, not merged
**art (4c86af4): PASS so far on what lasts, but its merge is undone.** I merged it at 20:05 and took it back at 20:10 when main held the gate; `git merge --no-ff lane-art` redoes it. The lane has since reopened: repairs to the Kōrin gods, Yoshino, Fudō and Oiwa are coming, and only then will its note end with the word. Then read just its follow-up diff. Take the whole branch, not parts: lane-ink and lane-saver already contain its history.
- Checked: the builder's diff, the design doc, `bin/fetch`, `theme.sh`, the pack tool; all 21 listed hashes match their pictures, no picture unlisted; Willow Kannon is public domain by the Met's own API (object 705791, `isPublicDomain: true`).
- Skimmed only, since lane-ink replaces them: `tools/build-lock.py`, `tools/build-heads.py`.
- Tests on the merged tree before I stopped them, under a hung PID 1, so not a verdict: test_masters, heads, generated, syntax, design_doc, saver, greeter, fetch, shell, bar all passed; test_wallpaper, lock and tiles were cut off. Run those again, above all "15 restores at once".
- Nits: `tools/art-pack.py`'s docstring says it needs numpy and it imports none; `bin/fetch`'s new `head()` shadows the `head` command (nothing else there calls it today).

**For the gates to come:**
- lane-ink: `tools/build-heads.py`, `art/heads.txt`, `tests/static/test_heads.sh`, `docs/art/heads.md` and lane-art's `build-lock.py` must leave with it if nothing uses them any more.
- lane-pixels: still writes `ICON_HEAD_KANNON`, which lane-art renames to `ICON_HEAD_ANGEL`; an unset icon is silent, so `grep -rn 'ICON_HEAD_KANNON\|head-kannon' bin configs tests tools` must be empty after those merges.
- lane-network: research2's note asks for `allow-host-ipv6` in `net_firewall_wrong`.
- lane-iso: the erase must come after Anaconda's checks (open question below).
- lane-browser: Helium's update lag behind Brave (about 1.3 days against 8 hours) must have been put to the owner.

## Baseline
No complete run yet. Two tries stopped by me: 202903b (17:45 to 18:36, serial, 49 of 129 files) and 8935ee7 (18:36 to 20:03, 53 of 129). On 8935ee7 three files were red on first try, not retried: content/test_fetch, content/test_tiles (the prompt's and fetch's new heads), engine/test_menu (a row's mark at column 66, expected 68). Seven installer files hit my 25-minute limit, but they were waiting, not hung: the harness allows one fake machine on the whole PC (`/tmp/kawa-installer-tests.lock`, shared with every lane's suite), so the installer area queues behind all of them. `suite.sh` now runs the other areas first, the installer area last and one at a time, and its limit only catches hangs.

## What main must do to merge and apply
- **Never remove a lane's worktree or local branch while the conductor runs.** `done_lane` reads the note in `~/repos/fk-NAME`: with the folder gone the lane counts as not finished, and `start_lane` makes a new worktree and starts it again (from main, if the branch is gone too). Remove them only after the round's `.claude/DONE`, or take the lane out of `~/.config/fedokawaii/r27-lanes` first. This overrides T25m's "the worktree gone".
- **research2:** nothing to apply. Its note has ledger lines ready to paste (r27-N numbering is main's), and says where the plan's text for T36–T39 is out of date. Its unit stopped at 19:14:32 and I deleted its branch on origin at 19:15 (T25m), because the branch's history held those identifiers; the only remote ref that did, no forks. The local branch stays, and the shared `refs/remotes/origin/lane-research2` was put back by hand so other lanes' `git show origin/lane-research2:…` still works: **never push that branch again, and do not run `git fetch --prune` before those lanes have finished.** GitHub still serves the old commits by exact id (`gh api`: exit 0), so the owner has been told on his page; only GitHub Support can purge them.
- **research:** nothing to apply. Plan and ledger items 2–8 in its note (`lane-research.md`, "What the main run must do to merge"): fold `iso-design.md` §9 into T45, T47, T56 and T57; `f45-changes.md` line 81 is wrong. Mark T55 done. Mark T32 as a record, not done: the VM is gone, ASOBI holds that number now. Its "Found on the way" list is real work for main: **a kernel bug on exactly this card** (amdgpu #6062: all cores stall up to about 65 ms on a static screen, heard as audio glitches, not yet measured here: T60), **`~/VM` in his backups** (86 GiB of harness, `bin/kawa-backup:223` and `backup-exclude`), `theme.sh`'s GRUB fonts under Secure Boot.

## The machine: the gate is open again (21:26)
The PC restarted at about 21:16 (up 9 min at 21:25): `systemctl --user` answers, nothing in D state, 13 zombies, 25 GiB available. Last boot's kernel log holds no new Oops; corruption_errs is still 10 at that boot's mount. Tonight's history is in the ledger (r27-wedge, main's). Owner 21:20: the display is cut for every agent, 12 lanes at most, heavy builds and VMs one at a time.
Results from before 21:16 are not trusted: lanes' test runs from then are not counted as evidence here.

## Where the gate stands
- **The train (21:40 on):** `~/.cache/r27-integrate/train` is a throw-away worktree where `train.sh` merges every lane's current head in the owner's order with rerere (`-c rerere.enabled=true`; the shared rr-cache keeps each resolution, so a lane that moves needs no second resolving; rerere stays off for every other worktree). `icons-res.sh` (mid-merge): `icons.txt` merged by blocks (`icons-merge.py`), icons.sh and both fonts rebuilt. Commits there named `gate-fix:` are what the combination needs: they come across after the real merges, in the same order. When a lane says the word: real merge on lane-integrate with the same rerere, cherry-pick the gate-fixes it needs, areas, then the suite.
- Doc trap: `docs/fedokawaii-guide.md` holds a merge conflict as a lesson (`>>>>>>> laptop`): never resolve that one.
- **Baseline running since 21:27 on c10d55a2** (main ef50141 + the look harness's pgrep fix, lane-review's, proven on test_lock: 180/0 in 36 s): `~/.cache/r27-integrate/suite-base-c10d55a2.log`.
- **lane-updates: a master is reviewing head 27ea578a ahead of its DONE** (the F45 move depends on it, so the merge must not wait on a first review; verdict in `~/.cache/r27-integrate/master-updates-1.md`, carried here when it lands). When the lane says DONE only its follow-up diff is left to read.
- **Trial merge of every lane at 21:28** (`~/.cache/r27-integrate/trial.sh`: throw-away commits, no ref moved), in the order updates, fixer, network, hardware, iso, regress, nvim, firealpaca, chess, typing, torrents, learning, pixels, appsui, art, ink, saver, asobi, browser, review. Clean: updates, hardware, regress, chess, typing, review. Conflicts: fixer 1 (`lib/cand-check.sh`), network 1, iso 2, ink 1, nvim 4, saver 4, firealpaca 5, art 5, appsui 8, pixels 9, learning 10, torrents 11, browser 29, asobi 30. The most shared: `setup.sh`, `docs/fedokawaii-learn.md`, `tools/README-tools.md`, `art/icons.txt` and the two icon fonts it builds (never merged by hand: resolve the text, then `python3 tools/build-icons.py`).
- No lane other than research and research2 has said it is finished, so nothing is left unmerged that is ready.

## Open questions
- For lane-iso's gate, from research's note: its erase came before Anaconda's checks, so a passing mirror fault could leave a blank disk. It must be fixed before that lane passes.

## OWNER VERDICT 2026-11-04 21:31 on your render final-sprint: comment
OWNER 21:30 — FINAL SPRINT: "you have 2 hours, finish the whole fedokawaii project fully". Deadline 23:30. Order of the night (relayed by Claude):
1. 21:30–22:30 every lane: finish the most valuable COMPLETE part of its task, test it, push, end its notes with a line DONE and a handover (what main must apply, what is left). No new scope. Never fake done.
2. lane-integrate: merge each DONE lane at once (master review, full offline suite), in this priority: ink, pixels, appsui, updates, iso, asobi, art, chess, typing, torrents, learning, firealpaca, nvim, fixer, hardware, network, saver.
3. main: 22:45 at the latest merge lane-integrate, then APPLY on the PC (he is here, screen takeover allowed; a notice on his page first) and check the desktop, the lock (lane-ink's M1 / M2) and the menus live.
4. main ~23:00: the Fedora 45 upgrade through the update button (snapshot first, btrfs scrub after; he decided to go ahead), unless the apply left something broken.
5. lane-iso: build and prove the final Fedora 45 ISO from merged main in its VM as soon as main has the merge, in parallel.
6. 23:30: main writes the owner's summary: what is done and proven, what is left (kept open in the plan for the next round), how to roll back.

## OWNER VERDICT 2026-11-04 21:35 on your render final-iso: comment
OWNER 21:34 — THE FINAL ISO: "make sure the final ISO has everything updated and installs Fedora 45 only, the newest everything, fully stable."
- Built from the FINAL merged main (after lane-integrate's last merge and main's apply), never from a stale branch; rebuild if main moves.
- Fedora 45 only: the F45 release repos + F45 updates enabled at build time, so every package is the newest stable update on the day it is built (no F44 package, no updates-testing, no rawhide, no COPR unless the repo needs one and it is pinned to F45); the latest stable F45 kernel only (one kernel).
- Everything fedokawaii ships comes from the repo at that commit: themes, the new lock (lane-ink M1/M2), the menus, the apps, ASOBI, Helium (with its Widevine fetch at first boot), the update button, the snapshots, the AI fixer; the round's own tooling never ships (no lanes, conductor, temporary sudo rule).
- Proof before it is called final: install it in a fresh VM unattended, first boot to the desktop, press the update button (nothing left to update or only same-day updates), log in and out, lock and unlock, restore a test backup; record the time and the result in the inbox.
- Name it with the date and commit; write its sha256 beside it.

## OWNER VERDICT 2026-11-04 21:41 on your render fedora-45-only: comment
OWNER 21:40 — FEDORA 45 ONLY: "ditch Fedora 44, we are fully for 45 now." From now on fedokawaii supports Fedora 45 only: no F44 code paths, no "works on both 44 and 45" branches, no F44 package names or repo URLs anywhere (setup.sh, the installer, the ISO kickstart, the update button, tests, docs, CLAUDE.md, the plan). The PC goes to 45 tonight through the update button (snapshot first, scrub after), and the ISO is F45 only. lane-f45: turn your "both 44 and 45" patches into F45-only ones. lane-integrate and lane-review: reject anything that adds F44 support back.

## OWNER VERDICT 2026-11-04 21:46 on your render bar-clock-seconds: comment
OWNER 21:46: the top bar's clock KEEPS ITS SECONDS. Claude's earlier note (17:24 / 18:00, "drop the seconds") is withdrawn — the owner wants the seconds shown. If they were removed, put them back.
