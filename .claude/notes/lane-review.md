# lane-review — T19n, the master for main's own commits (owner 4 Nov 18:45)

Reviews every main commit since 2026-11-04 17:00, strictly, against CLAUDE.md, docs/design-system.md and the
owner's verdicts (~/repos/fedokawaii/.claude/review/feedback.md). Findings go to ~/repos/fedokawaii/.claude/inbox.md
as "## <time> — open" with "from lane-review:" and the exact fix. Never edits main's files.

**This note must never hold a line that is only the finishing word.** My registry line says never to write it (a
standing job, as lane-integrate's); the generic lines after it say to end with it. The task's own line wins.

## How a pass runs
1. `git fetch`; `git -C ~/repos/fedokawaii log <last reviewed>..main`; read feedback.md's new verdicts.
2. Merge main into this branch (`git -c user.name=… -c user.email=… merge --no-edit main`) so tests run on its state.
3. Private dwl tree (never ~/.local/src/dwl): /dev/shm/lane-review/dwl (`git clone`, 98bea2c, the repo's dwl.patch and
   config.h, `make` as CLAUDE.md says). Kit: `export PATH=$HOME/.local/bin:$PATH; nice -n 10 bash tools/kit.sh --dwl BIN
   --bin bin --repo-art …`. Measuring tools: /dev/shm/lane-review/tools (frames.py rail per frame, ff.py change boxes,
   sheet.py contact sheets, curves.py dwl's curves at 144 Hz). A play: /dev/shm/lane-review/m1/play.sh.
4. Heading times from `date`, never guessed (done wrong once on 4 Nov, corrected).

## Reviewed (commit → verdict → findings filed in the inbox, all 4 Nov)
| commit | what | verdict | findings |
|---|---|---|---|
| e230cac | design-review.sh | pass (ShellCheck clean) | — |
| b198be2, 202903b, b9ecd44, 715219e, be862f9 | plan | pass | — |
| 306a69c | heads, prompt, fetch | superseded by the owner 18:32, 19:12 (lane-ink); the prompt's and fetch's code pass: test_shell 187/0, fetch's facts all there at each picture size (8 rows each, none lost) | §3, §8 stale: 19:22 |
| ebb4566 | Super+X plain, motion v1, band | Super+X: lane-pixels goes on; clock after a sleep FAIL | clock: 19:13 |
| c8ded20 | test_panel | pass, 650/0 | — |
| 19ceede | start-dwl | pass, 114/0 | — |
| 66e6751 | band reverted | pass: no band anywhere, test_bar guards `background: transparent`, bar-geometry held on my build, both moods looked at ×2 | — |
| 30c2301 | T19s first pass | in lane-pixels' and lane-appsui's hands; tests green | — |
| 2440693, d6f60ad | motion v2 | curves pass (every frame at 144 Hz: no kink; open 120 px, past by 5; strip past by 15; steps ≤ 2 px at the end); rail FAIL; roll-up of floats FAIL | rail 19:13 with a proven patch; floats 19:16; rail colour and rod pop 19:22 |
| 8935ee7 | lock's gate | works both moods on lane-art's frames (shut, keys nothing, Tab, marks, Enter, wrong → open, Esc); first Tab on a dark lock lost FAIL; 5 small fixes | 19:13 ×2, §9 stale |
| a850edb | saver | lane-saver goes on; doc stale, dead colours | 19:13 |
| a051970 | flatpak | ok with lane-asobi's verify.sh (its branch); PACKAGES.md:100 still lists flatpak among the forbidden on both: for lane-asobi's merge | note here |
| a1b175d | ledger | pass | — |
| ac239d4, 33f51cc | kawa-carry, hint | test_carry 26/0, ShellCheck clean, the EXIT trap runs on TERM; hint only at login FAIL | 19:13 |
| bdb5da6 | lock's life | timers run in the dark FAIL | 19:13 |
| b5cdea6, 5d78ea2, 278b699, 9d0188a | prompt ink, pack words, contrast | pass: test_contrast 21/0 at main | — |
| bad3e35 | bar's rows, popup over fullscreen | pass: test_bar 265/0 | — |

Last reviewed: main bad3e35 (19:08).

Measured, no finding: tile-widths, prompt-burst, menu-cursor, menu-first-click, calendar-middle, window-frame, level-display,
warm-exit, bar-burst (on the rail's patch too), lock-gate (LOCK_HOME from lane-art) all held; one-popup broken (known to main,
r27-found-open; exact cause and fix filed 19:22). Timings tonight are not judged: gpu_busy 93 % from other lanes (a frame of 140 ms in
the kit's log, F line), so anim-check fails at load; the curves are judged from the code, positions from the recordings.

The rail's patch: `.claude/notes/lane-review/rail.diff` (against dwl.c at 2440693's patch), ASan clean under 1-2-3-1 bursts ×6 with
windows closed mid-move (676 c2, 767 c3 steps; leaks at exit only, none in rail code).

## What main must do to merge and apply
Nothing to merge but this log. Findings are in the inbox; the patch is on this branch.

## Open questions
None.
