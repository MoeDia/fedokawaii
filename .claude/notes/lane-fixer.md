# lane-fixer — T47, the local AI fixer (owner 4 Nov 17:32: finished, tested, pushed, DONE by 21:30)

Branch lane-fixer, worktree ~/repos/fk-fixer. Scratch: ~/.cache/r27-fixer (a subvolume of its own, out of /home's
snapshots; deleted at the end). Everything GPU at nice 15 + ionice idle, the server on its own network namespace.

## Status (newest first)
- 19:20 the harness (system/kawa-fixer), the updater's side (lib/fixer.sh + hooks in lib/update.sh, lib/cand-check.sh,
  setup.sh, theme.sh, verify.sh), tests (test_fixer, test_update_fixer) committed and pushed. The finalists (gpt-oss-20b,
  Qwen3.5-9B) running three seeds each on the frozen harness; after that: the pin, the real install in ~/.local, one whole
  run from nothing, the frames while it generates.
- 18:20 harness + tests + bench committed (756d31a).

## The interface with lane-updates (read this, lane-updates) — as built, in my branch, tell me if you move these
Files of mine: system/kawa-fixer (Python, stdlib only), lib/fixer.sh (sourced by setup.sh right after lib/update.sh),
tools/fixer-bench.py, tools/fixer-frames.sh, tools/vm-inject/fixer-candidate.sh, tests/installer/test_fixer.sh,
test_update_fixer.sh, fixer-stub-server.py.
My small hunks in YOUR files (all merge-clean against your 19:10 tree when I looked):
1. lib/update.sh cand_run: `[[ -d $UP_HOME ]] && ref+=(--bind="$UP_HOME:/home")`, and the checks from before the packages,
   `[[ -s $UPD/cand-before ]] && ref+=(--bind-ro="$UPD/cand-before:/run/fk-before")`.
2. cand_try: `/run/fk-check --before` once before the replay (into UPD/cand-before); `fixes_cand` after the replay.
3. u_candidate: `up_top; up_home_copy` (a writable snapshot of /home at UP_TOP/home.cand: real configs for every candidate,
   which also closes a fake green: `foot --check-config` used to check NO config in a candidate).
4. up_bisect: `up_fix "$UPD/why" "${s[@]}" || up_hold …` (0 = mended and kept in fixes.new, nothing to hold).
5. u_undo and up_boot: `fixes_undo` · up_leftovers: drops fixes.new and a stale home.cand · up_exit: `up_home_drop`.
6. u_report: UP_FIX_LINES into the report's lines (what the fixer did, or why not).
7. setup.sh do_update: `fixes_commit` right after `up_phase steps`, `fixes_apply` after update_steps, `fixes_settled` after
   a green u_check; `step_on "the local AI fixer" install_fixer` in update_steps; s_fixer in s_upstream; r_upstream.
8. lib/cand-check.sh: `--before` mode, and the configs' checks by `kawa-fixer checks` (foot, mako, mpv, nvim, greetd, the bar's
   and the lock's CSS; yazi only when named: pinned), only what is new against /run/fk-before counts. Your T45 (H) 7 / T58's
   "three checks" (yazi, greetd, nvim): greetd and nvim are in this list now; red-line labels are "<prog> does not take its config — detail".
Rows of T49: 13 tools/fixer-bench.py + tools/vm-inject/fixer-candidate.sh · 21, 22 tests (stubs): the design's table says so.
PLEASE RUN in your VM, once merged (I may not: no VM): `bash tools/vm-inject/fixer-candidate.sh VM TREE` from your state
"inject" (it uses your lib.sh and fk-inject-pkg; a stand-in model, a VM has no card). It proves the real nspawn runner,
the real home snapshot and the theme staying in sync. Written against your harness, NOT yet run by anyone.
Also useful in your F45 VM: `python3 -I /usr/local/sbin/kawa-fixer checks --user dia` says whether Fedora 45's foot, mako,
mpv, nvim, greetd take our configs as they are.

## What main must do to merge and apply
(filled in as it is built)

## Open questions
none

## OWNER ANSWER 2026-11-04 19:01 — to your question «2026-11-04 19:00 — question from lane-fixer»
remove it its a stray or dont since remember when all done i will nuke this install and doa. fresh one
