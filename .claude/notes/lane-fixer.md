# lane-fixer — T47, the local AI fixer (owner 4 Nov 17:32: finished, tested, pushed, DONE by 21:30)

Branch lane-fixer, worktree ~/repos/fk-fixer. Scratch: ~/.cache/r27-fixer (a subvolume of its own, out of /home's
snapshots; deleted at the end). Everything GPU at nice 15 + ionice idle, the server on its own network namespace.

## Status (newest first)
- 18:20 harness + tests + bench committed (756d31a, test_fixer 215/0); sweeping the four candidate models through the
  graded set in the background; writing lib/fixer.sh (the updater's side).

## The interface with lane-updates (read this, lane-updates)
Files of mine: system/kawa-fixer (the program, Python, stdlib only), lib/fixer.sh (sourced by setup.sh next to
lib/update.sh: `up_fix`, `fixes_apply`), tools/fixer-bench.py, tests/installer/test_fixer.sh.
What lib/update.sh needs (three lines; I add them in my branch where they do not fight yours, tell me if you move them):
1. u_candidate → up_bisect, once the culprits are known and BEFORE they are held: `up_fix "$why" NAME… && <retry>`.
   Exit 0: their set went through a candidate with the fix in; nothing is held; the kept fix is in $UPD/fixes.
   Exit 1: no fix: hold as today, the report's line says why (UPD/fix-line).
2. cand_try, after the replay and before /run/fk-check: the kept fixes on the candidate's copy (`fixes_apply_cand`).
3. the live steps (after theme, before u_check): `fixes_apply` — the same fixes on the running system.
The candidate has no /home after the split (design attack 6): lib/fixer.sh snapshots home → $UP_TOP/home.fix for its own
candidate and binds it; cand_run gains one array, UP_CAND_EXTRA, for that. foot --check-config in lib/cand-check.sh runs with no
config at all unless cand_run binds a home (a fake green today): cand_try should bind that same snapshot.

## What main must do to merge and apply
(filled in as it is built)

## Open questions
none

## OWNER ANSWER 2026-11-04 19:01 — to your question «2026-11-04 19:00 — question from lane-fixer»
remove it its a stray or dont since remember when all done i will nuke this install and doa. fresh one
