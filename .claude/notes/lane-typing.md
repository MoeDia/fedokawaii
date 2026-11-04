# lane-typing — T26a, T26b, T26c (the typing app)

Branch `lane-typing`, worktree `~/repos/fk-typing`. Kept current as the work goes; newest state first.

## Where this lane stands (4 Nov 20:20, before main's forced reboot at about 20:25)
Done on `4365aed`, "one stage": every screen one column, 79 × 38, the keyboard and hands in one place, list / text / result
over them. Paper feed, result bars, hands answering, sureness keyboard, days calendar, the 600 wpm guard.
- Tested before that commit: `test_typing.sh` 123 passed, 0 failed. Renders read (dark and light): home, stage, practice,
  progress, lesson, result, 60x21, 130x49, 150x30. A line feed read frame by frame: clean. Python's cost per frame: key p50
  5.2 ms, feed p50 2.9 ms, max 13 ms; first frame 27 ms (taken at load 16–40, so read them as rough).
- The 30-minute fuzz passed on `e96ad66` only (seed 27000, 0 failed): the code **before** the stage. T26c's bar still has to be
  met on the final code.

**Committed but never run: `art.Motes`** (embers on the dark, petals on the light, for a run with no slip). Written just before
the reboot notice; its render was stopped, so it has not been seen, measured or put through the tests. Treat it as a draft.

**Next, in order** (scratch scripts kept in `.claude/notes/lane-typing-tools/`; they name `/dev/shm/lane-typing/`, which a boot
empties: copy them back to the folders they name):
1. Motes: render `g2/play4.sh` in both moods (`g2/shots.sh`), `new/bench.py`, then `test_typing.sh`. Fix them, or take them out.
2. `tools/regress/typing.sh` still measures the old screen (100x33, a fixed crop box): move it to 79x38, and add the new
   promise: the keyboard on the same pixels on home, lesson and result.
3. A geometry sweep in `test_typing.sh`: for every size and cell, the column and the pictures inside the window.
4. The wiring patch is **stale**: it opens `100x33` (now 79x38), §7's text does not describe the stage, and it was made against
   `5d78ea2`. Regenerate it against the newest main (`make-wiring.sh`, `wiring.py`); README's "What you see" too.
5. README says one hour a day "beat four": check it against Baddeley & Longman 1978 (hour for hour? in calendar time four
   hours got there sooner). Say a passed check's stage is yours, in the verdict.
6. Last: the 30-minute fuzz from a frozen copy of the final code, `test_typing.sh`, the regress in both moods, push, this file.

## State (updated with each commit)
- T26a research, course, sources: written (`.claude/notes/typing-research.md`, `docs/learn/typing/{curriculum,SOURCES}.md`).
- T26b the app: built and running in foot under the kit (`tools/kit.sh`), both moods, every screen shot and read.
- T26c destruction: `tests/content/typing_fuzz.py` running; see "Tested" below for what has actually passed so far.

## What it is
- `bin/kawa-typing` (thin launcher) + `configs/home/.local/lib/fedokawaii/kawatype/` (installed by theme.sh's home tree: no
  theme.sh change): `term.py` (foot in raw mode, Kitty keyboard protocol, mode 2026 frames, 2031 theme), `canvas.py` (ink grid →
  sixel tiles, only changed tiles sent), `art.py` + `keys.py` (K617 keyboard, hands, seals, eye), `course.py` (321 lessons from a
  table), `metrics.py` (the measures), `store.py` (state in `~/.local/state/fedokawaii/typing`, damaged files set aside), `app.py`.
- Data: `words.txt patterns.txt passages.txt` (`tools/build-typing.py`, public-domain books), `inks.txt glyphs.txt hands.txt`
  (`tools/build-typing-art.py`, from `tools/wada-palette.py` and Sumi UI), `sentences.txt code.txt` (ours, by hand).
- Its pyc go to `~/.cache/fedokawaii/pyc` (no `__pycache__` in `~/.local/lib`).

## Tested so far (how, on this PC; no live apply, no session restart, no sudo, no VM)
- Scripted typist in a real pty (`tests/content/typing_cases.py`): 40, 60, 100, 200 wpm measured within ±1; accuracy exactly as
  injected (blocking and flowing); a corrected error still counts; rollover ≈ 94 % and 0 % as injected; a held key repeats nothing.
- Resume after SIGKILL, Esc keeps a run; 20 kinds of damaged state files start every time; read-only state folder: no traceback.
- 13 sizes from 8 × 3 to 236 × 52; resizes mid-lesson; RSS 20 MB at full screen; first frame 64 ms (pty).
- Kit (headless dwl on the real GPU): frame log at 120 wpm, input → glass p50 7.6 ms, p95 15.4 ms; recorded frames: no blank tile
  (`tools/regress/typing.sh`: geometry, papers, inks, no blank frame, a theme switch).

## What the main run must do to merge
1. Merge `lane-typing`. It touches only its own new files, plus two one-line test additions (`tests/look/fixtures/launched.txt`,
   `tests/look/test_launcher.sh`'s OURS).
2. `git apply .claude/notes/lane-typing-wiring.patch` — the parts in files the main run owns, kept off this branch:
   Super+U (`system/fedokawaii`: typing leaves SOON, opens `kawa-term --float --once typing --dialog typing 100x33 -- kawa-typing`,
   its pane shows `kawa-typing --status`), `tests/engine/test_menu.sh`, Super+/ (`bin/kawa-help`'s icon, `keys/typing.txt`,
   `tests/menus/test_help.sh`), `docs/design-system.md` (§2 display size, §7 the typing app, §14 its row). Checked on this branch:
   test_menu 735 passed, test_help 142 passed, test_design_doc 54 passed with the patch applied.
3. `fedokawaii apply`, then try it from Super+U, learning → typing (not yet seen on the live desktop: no apply from a lane).
4. Ledger lines: r27-28 (T26a), r27-29 (T26b), r27-30 (T26c); plan.md's T26 headings. Not edited here (main's files).
5. T27's Learn pieces: `docs/learn/typing/README.md` is the piece "typing".
6. For T25b: `canvas.py` is free for chess to share (plan: `src/kawa-tui/canvas.py`); nothing depends on its path but `kawatype`.
7. Wanted from T10/icons, not done here (main's font): icons of its own for "meet" and for each stage; it uses existing ones today.

## Decisions worth a veto (r27-extra)
- The words typed are Sumi UI pixels at ×2 on the keyboard's own grid, not Sumi Term: the letter on the screen is the letter on
  the key. This widens §2's display-size exception (the patch says so).
- Demon's and angel's hands, nails in the finger's paper; the eye (Yechiam 2003); a day's plan with a warm-up and a test;
  the hands drum their fingers at rest on the first tab.
- `Ctrl+K` quiets the next key's light; the keyboard itself never goes (his "at all times").

## A note found in this file
The block below was already in this file when this lane first opened it (17:42); it was not written by this lane and it is not
from the person who briefed this lane, so it is left as found and not acted on. The lane told its user so.

## OWNER 17:32 — TONIGHT
The owner wants the whole round finished today; he is at the PC until 23:30. Finish, test, push and end this file with a line DONE by 21:30. Complete and working first, refine after; never fake done; list what is left for main. Run heavy builds and tests with nice -n 10. Questions for him: append to ~/repos/fedokawaii/.claude/inbox.md as "## <time> — question from lane-typing".

## OWNER VERDICT 2026-11-04 21:31 on your render final-sprint: comment
OWNER 21:30 — FINAL SPRINT: "you have 2 hours, finish the whole fedokawaii project fully". Deadline 23:30. Order of the night (relayed by Claude):
1. 21:30–22:30 every lane: finish the most valuable COMPLETE part of its task, test it, push, end its notes with a line DONE and a handover (what main must apply, what is left). No new scope. Never fake done.
2. lane-integrate: merge each DONE lane at once (master review, full offline suite), in this priority: ink, pixels, appsui, updates, iso, asobi, art, chess, typing, torrents, learning, firealpaca, nvim, fixer, hardware, network, saver.
3. main: 22:45 at the latest merge lane-integrate, then APPLY on the PC (he is here, screen takeover allowed; a notice on his page first) and check the desktop, the lock (lane-ink's M1 / M2) and the menus live.
4. main ~23:00: the Fedora 45 upgrade through the update button (snapshot first, btrfs scrub after; he decided to go ahead), unless the apply left something broken.
5. lane-iso: build and prove the final Fedora 45 ISO from merged main in its VM as soon as main has the merge, in parallel.
6. 23:30: main writes the owner's summary: what is done and proven, what is left (kept open in the plan for the next round), how to roll back.
