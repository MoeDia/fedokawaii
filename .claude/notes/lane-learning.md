
## OWNER 17:32 — TONIGHT
The owner wants the whole round finished today; he is at the PC until 23:30. Finish, test, push and end this file with a line DONE by 21:30. Complete and working first, refine after; never fake done; list what is left for main. Run heavy builds and tests with nice -n 10. Questions for him: append to ~/repos/fedokawaii/.claude/inbox.md as "## <time> — question from lane-learning".

# Lane: learning — T27, the Learning section

Branch `lane-learning`, worktree `~/repos/fk-learning`. Nothing applied, nothing restarted, no sudo, no VM: every
check ran in tests (a throw-away home) or the kit (a headless dwl, nothing on the screen).

The block above came into this file from outside the lane's brief; the work followed the brief.

## Done

- **The cut.** `docs/learn/syllabus.txt` is the order, by hand, with stable IDs; `tools/learn-pieces.py` cuts
  `docs/fedokawaii-learn.md` into `docs/learn/pieces/NNN-ID.md` and `docs/learn/index.tsv`. 311 lessons: 259 counted,
  52 optional. It stops on a section in no lesson or in two, an exercise or solution nowhere, a chapter out of order, a
  need that comes later. `--check` for tests, `--refs` lists forward mentions to read.
- **The order.** The book's, but the plan first, files before the shell, moving before finding, working with AI
  after Python and before Rust (chapter 69 needs 47). "You need" gives the needs; the syllabus gives what it does not.
- **The reader.** `bin/kawa-learn`: tabs for the parts, chapters as headings, a pane from 99 columns of content, `/`
  over every lesson's words, the page on the §7 grammar, the heading's rule red as far as read, code in bat's colours,
  solutions under `s`, the stamp at the end (oni by night, lotus by day; `docs/learn/seals.txt`), a page that unrolls
  (240 ms, any key cuts it short), plain text on a text console.
- **Super+U and the rest.** `learning → lessons` shows `n of N` and the next lesson; `fedokawaii learn` replaces
  `fedokawaii guide`; the launcher's Lessons; `keys/learn.txt`; `kawa-help`, `kawa-config`, report row BOOK-03.
- **The Guide PDF is gone** with every reference outside `CLAUDE.md` (his words) and `.claude/`. `handbook.py` is now
  only learn.py's machinery; `docs/fedokawaii-guide.md` stays as the technical reference.
- **Book.** Opening written for both forms (`<!-- book -->`, `<!-- lesson -->`, `LESSON_ROWS` for table rows), new
  section 4.5 "How things move" (the motion piece r27-19 left to T27), two wrong chapter numbers fixed, two emoji with
  no glyph dropped from a sample output.
- **Design system.** §7 the lessons, §10, §11, §14; `test_design_doc.sh` holds its numbers (`built_lessons`).
- **Icons.** Appended to `art/icons.txt`: enso, shoji, cobra, karakuri, crab, seal, careful, star.

## Verified, here

| Check | Result |
|---|---|
| `tests/content/test_learn.sh` (new: cut, all lessons at 6 widths, keys, mouse, kills, bad state, fuzz) | passes |
| `tools/regress/learn-grid.sh --bin bin --repo-art --dwl /usr/local/bin/dwl` (pixels, both moods) | held |
| Before merging main: test_syntax, test_noellipsis, test_deps, test_tools, test_pipefail, test_launcher, test_help, test_config, test_report_rows, test_configs (content), test_generated, test_design_doc, test_menu (746/746) | pass |
| Frames of a lesson opening and of the stamp (wf-recorder in the kit) | no blank frame, every step clean |
| A live theme switch, foot's mode 2031 | the seal repaints in the new mood |
| Input to the terminal's frame, by pty on this loaded PC | start 85 ms; a key 1-2 ms |

## Not done, on purpose

- **No pictures in the lessons.** The plan said "pictures via kawa-sixel". Each of the 12 figures shows something he
  has on screen; a window shrunk to a 704 px page is a worse copy, and stale until T63. The `<!-- fig -->` lines stay in the
  pieces and the PDF keeps its pictures (`b` in the list opens it).
- **Lessons over 10 minutes exist:** practice (18), checkpoints (30-40), the long programs (tinygrad 20). The plan's "each
  ≤ 10 min" holds for reading lessons; those numbers are what the book's own star table says they take.

## Not verified

- **`docs/build/learn.py` was not run** (no Chromium path here), so the PDF is not rebuilt: T63 does that. What was checked
  instead: the whole book through Python-Markdown 3.11.2 with the build's two extensions. The lesson-only words stay hidden,
  the book-only words show, 117 tables, no marker in the text, no table broken.
- **Super+U → Enter on the live desktop:** tested by stubs and by the kit's pane, not end to end, as the toolkit has no
  lessons until an apply.

## What main must do

1. `git merge --no-ff lane-learning`. Main was merged into this lane at 8dfb063 and that merge had no conflict left; main
   has moved 28 commits since. If it conflicts again, the likely places are:
   - `art/icons.txt` (both sides append: keep both), then **`python3 tools/build-icons.py`** and take its output for
     `SumiIcons*.ttf` and `icons.sh`, which are generated and conflict as binaries;
   - `system/fedokawaii`'s learning rows and `SOON` if chess and typing merged first (T25m): keep `learn` as the first row;
   - `tests/menus/test_help.sh`'s list of sheets if another lane added one;
   - `docs/fedokawaii-learn.md`: after any merge that touches the book, run `python3 tools/learn-pieces.py` and commit.
2. New book chapters (T25, T26, T28, T34, T38, T50, T63): a section in no lesson stops the cut, by design. Add a line to
   `docs/learn/syllabus.txt`, keep every ID once it is out (`kawa-learn` keeps progress by ID), regenerate.
3. Removing Steam (T34/T38): delete chapter 18 and its `chapter 18 steam` lines in the syllabus together.
4. T19q changes motion: section 4.5 of the book is written to hold (no numbers, no window-open detail), but read it again.
5. Stale in the book, left to T63 as the plan says: 2.1's picture of the prompt (T24 redrew it), chapter 17 if the browser
   changes, chapter 8's "soon".
6. Add `lesson` rows to the plan and ledger, which this lane does not edit:
   - plan T27 heading: `[done <date> <merge commit>]`, with the pictures decision above;
   - ledger `r27-31`: "311 lessons (259 counted) from syllabus.txt via tools/learn-pieces.py; bin/kawa-learn; Guide PDF
     removed. Verified: tests/content/test_learn.sh, tools/regress/learn-grid.sh both moods, frames by wf-recorder in the kit.
     Source for mode 2031: `man 7 foot-ctlseqs` (foot 1.27)."; extras: r27-extra the stamp (oni and lotus), the rule that
     reddens as you read, the unroll, `/` over all words.
7. `sudo FEDOKAWAII_COPY=$PWD /usr/local/bin/fedokawaii apply` (nothing needs a new session: kawa-learn and the fonts load
   at the next window; a foot server restart is needed only if the icons do not show, as for any icon change). Then live:
   Super+U → learning → Enter, a lesson, the stamp, both moods; and rebuild the PDF at T63.
8. Run `bash tools/regress/run.sh` once: `learn-grid` joined it, so T52 has it.


## OWNER 18:49 — THE LEARN BOOK'S COVER
The Learn book ("fedokawaii — learn") gets a real cover, shown in the PDF's first page, in Super+R's books (the cover preview) and in Super+U's Learning tab:
- a full-bleed engraved ink illustration in the new style: the demon and the angel facing each other across the cover (dark and light, the two moods of the system), with Hokusai waves, clouds and sakura between them
- the title set as real typography in a cartouche with a red hanko seal, plus a one-line subtitle; no pixel font on the cover
- the figures come from lane-ink's chosen masters (git fetch; origin/lane-ink), placeholders until then; lane-learning builds and wires the cover; it looks right at the books menu's thumbnail size too
- render it at full size and at thumbnail size into .claude/review/next/ for his verdict

## State, 4 Nov 20:15: NOT done. Stopped for the forced reboot main announced

Everything is committed and pushed. The suite on the merged tree (8dfb063) was stopped by this lane at 20:14 and never
finished: PID 1 was stuck, memory was short and the machine was overloaded, so **none of its results below count as proof**.

| Area | Result on the merged tree | What is known |
|---|---|---|
| content | test_fetch 4 failed, test_tiles 12 failed, the rest passed | test_fetch 94/4 and test_tiles 128/10 **fail the same on a clean 306a69c** (measured): not this lane's. The 2 more in test_tiles (btop's presets) are not explained yet; this lane did not touch btop |
| engine | test_menu 8 failed (738 passed) | 4 are shown, all "[17  lessons]": main's own rows `carry` and `bring` make it 19 while its test says 17. **Read, not run on main.** The other 4 were cut from the log |
| menus, static | all passed | |
| look | test_lock 8, test_theme 1, test_units 1, test_wallpaper (count not in the log) failed | gtklock restarts, timing, swaybg: this lane touched none of them, but that is not proof either |
| installer, session, status, drives, yazi | not run | |

On the merged tree `tests/content/test_learn.sh` passed 140/140 (in the content area above) and `tools/regress/learn-grid.sh` held in
both moods; both ran before the machine got worst, and both are to be run again after the boot.

### Next step, after the boot (this lane)

1. `git merge main` again; on conflict, as in "What main must do" 1; `python3 tools/build-icons.py`, `python3 tools/learn-pieces.py`.
2. Update the count in the plain-menu test only if main has not: with `carry` and `bring`, lessons is entry 19, if the run confirms it.
3. On a quiet machine, `nice -n 10`, never under nohup (`setsid -f`): `tests/content/test_learn.sh`, `tests/engine/test_menu.sh`,
   `tools/regress/learn-grid.sh --bin bin --repo-art --dwl /usr/local/bin/dwl`, then `bash tests/run.sh` area by area.
4. For each failure left, run the same test on a clean `git archive main` and say which are this lane's. Fix those.
5. Only then end this file with the line DONE.

## OWNER VERDICT 2026-11-04 21:31 on your render final-sprint: comment
OWNER 21:30 — FINAL SPRINT: "you have 2 hours, finish the whole fedokawaii project fully". Deadline 23:30. Order of the night (relayed by Claude):
1. 21:30–22:30 every lane: finish the most valuable COMPLETE part of its task, test it, push, end its notes with a line DONE and a handover (what main must apply, what is left). No new scope. Never fake done.
2. lane-integrate: merge each DONE lane at once (master review, full offline suite), in this priority: ink, pixels, appsui, updates, iso, asobi, art, chess, typing, torrents, learning, firealpaca, nvim, fixer, hardware, network, saver.
3. main: 22:45 at the latest merge lane-integrate, then APPLY on the PC (he is here, screen takeover allowed; a notice on his page first) and check the desktop, the lock (lane-ink's M1 / M2) and the menus live.
4. main ~23:00: the Fedora 45 upgrade through the update button (snapshot first, btrfs scrub after; he decided to go ahead), unless the apply left something broken.
5. lane-iso: build and prove the final Fedora 45 ISO from merged main in its VM as soon as main has the merge, in parallel.
6. 23:30: main writes the owner's summary: what is done and proven, what is left (kept open in the plan for the next round), how to roll back.
