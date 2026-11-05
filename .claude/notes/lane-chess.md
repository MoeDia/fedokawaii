
## OWNER 17:32 — TONIGHT
The owner wants the whole round finished today; he is at the PC until 23:30. Finish, test, push and end this file with a line DONE by 21:30. Complete and working first, refine after; never fake done; list what is left for main. Run heavy builds and tests with nice -n 10. Questions for him: append to ~/repos/fedokawaii/.claude/inbox.md as "## <time> — question from lane-chess".

<!-- status 23:54: everything is committed at 0985441 and pushed. The final proof runs on a frozen copy of that commit (results in /dev/shm/lane-chess/logs-k/summary.txt). The line DONE comes when it is green. -->
# lane-chess — T25a, T25b, T25c: the chess app

Branch `lane-chess`. State at the end of this file. `kawa-chess` runs, plays, teaches and reviews.

## What is there

| path | what |
|---|---|
| `bin/kawa-chess` | the launcher (thin: the program compiles once, its pyc in ~/.cache/kawa-chess/pyc) |
| `configs/home/.local/lib/fedokawaii/kawa-chess/` | the program: board (rules) · canvas (sixel) · art (board, men, marks) · term · ui (§7 grammar) · engine (UCI, levels) · store · app (loop) · play · review · puzzles · lesson · progress · course · syllabus (52 weeks) · home |
| `configs/home/.local/share/fedokawaii/chess/` | pieces.txt (the men, 40 × 40) · faces.txt (the ladder's ten) · inks.txt (written by tools/build-chess-inks.py) · lessons.txt (154) · puzzles.tsv (24,478 of Lichess's, CC0) |
| `configs/home/.config/fedokawaii/keys/chess.txt`, `.local/share/applications/kawa-chess.desktop` | Super+/ sheet (the window's title is "chess"), launcher entry |
| `docs/learn/chess/` | README.md (the Learn piece) · curriculum.md (365 days, written from the syllabus) · ladder.md (the measured levels) · SOURCES.md |
| `.claude/notes/chess-research.md` | the research digest, cited (105 pages fetched) |
| `tools/` | build-chess-inks.py · build-chess-puzzles.py · build-chess-curriculum.py · check-chess-lessons.py · chess-ladder.py · chess-gallery.sh |
| `tests/content/` | test_chess_rules.sh · test_chess.sh · test_chess_year.sh · test_chess_destroy.sh · chess_pty.py chess_lib.py fake_stockfish.py chess_walk.py chess_sweep.py chess_ghost.py chess_year.py chess_fuzz.py chess_games.py chess_puzzles200.py |

theme.sh needs **no change**: its home tree installs configs/home/ as it is, bin/* goes to ~/.local/bin.

## What the main run must do to merge

lane-integrate's train (`train-head`, gate-fix 86c8c9f) already holds this lane and its wiring. What is left for it:

1. Merge `lane-chess` again: two commits since (faces, titles, the keys' tile). Only this lane's files: no conflict.
   **Merge after lane-appsui, as the owner's order has it**: `ui.py`'s `tile()` now writes the tile lane-appsui's Sumi Icons Term
   carries (U+FF001, U+FF000 + each letter, U+FF002, as `screen_tile`). Without those fonts the keys would be empty boxes.
2. Two lines of `.claude/notes/lane-chess-integration.patch` changed for FEDORA 45 ONLY; copy them to the train:
   `tools/packages.evidence` "F45 updates: stockfish 19-1.fc45 (mdapi.fedoraproject.org/f45/pkg/stockfish, dnf --releasever=45
   repoquery; …", `tests/static/fixtures/programs.txt` "… /usr/bin/stockfish, Fedora 45 updates". Checked at 23:44: Fedora 45 has
   stockfish 19-1.fc45, the same 19 every test here played against.
3. The patch's row for docs/design-system.md §14 ("chess: the board (sixels), its men, its panel …") is not in the train yet (checked 23:53): add it.
4. `fedokawaii apply` in its turn installs stockfish (dnf) and the files. Look at it: Super+U → learning → chess.
5. `tests/content/` here run with the stand-in engine anywhere, and with the real one once stockfish is on PATH (or `KAWA_TEST_STOCKFISH=PATH`).
6. Plan: mark T25a, T25b, T25c from the ledger lines below; master-trace r27-dec-9a–h.

For a tree that has no train: the whole patch still applies on main b0656c4 (checked 23:30); on a tree with lane-pixels or
lane-appsui, `system/fedokawaii` conflicts in its SOON line and the learning rows: no chess in SOON, `[[ -n $desk ]] && e learning chess …`.

Not done here, on purpose (other lanes' or main's files, or his word): the design-system.md §-numbers for the board (a row in §14 is in the patch; a § of its own when the main run wants it); T27 cutting docs/learn/chess/README.md into the Learn pieces; VM proof of the install (T54); T19p's review pack may want a chess page (tools/chess-gallery.sh writes the shots).

## Decisions (the digest's argument: chess-research.md §G; "five changes it forced" for T25a's accept)

1. **Two games a day stay, but one deep and one light**: deep = a whole game on a long clock (20+10 → 15+10 → 10+5 → 10+0); light = a set position, an opening line, or a tactic from the puzzle bank to play out, 5+5. 336 light games, 325 from set positions. Two rapid games a day would be 67–83 % of a 1–1.5 h budget (digest F1), and Heisman wants slow games (D22).
2. **Our own measured ladder** instead of trusting UCI_Elo: it is an engine pool's scale with a floor of 1320 and no human claim (Stockfish's FAQ). `tools/chess-ladder.py`, ladder.md: below 1320 a lot drawn among depth-1 moves; levels named from measured gaps; never shown as a chess.com rating.
3. **Exams at 80 % every four weeks that hold the plan** (Steps Method), gates on the endings you must know (K+Q, K+R, Lucena, Philidor; Silman's order).
4. **Judgement first in the review** (Roediger & Karpicke 2006): he says which move he would take back, then finds the better move before being shown. Win chance: Lichess's published formula (fitted on humans), not Stockfish's WDL (fitted on engines); classes: chess.com's published 0.02/0.05/0.10/0.20.
5. **Honesty**: nothing on record shows zero to 1800 in a year (digest F3): said once in the first lesson, in the Learn piece, and the progress tab draws his line against the plan's with a forecast from his own month. The final answer is chess.com.

Others: Sixel, not sextants: a 40 px square would be 10 × 6 blocks in two inks a cell; sixels are 0.4–1.3 ms a frame in Python (bytes.translate + big ints), 18–23 MB RSS, foot at 7 ticks and the app at 12 over 8 s of play with two animated moves. Cell-aligned squares (40/80/120 px = 5×2, 10×4, 15×6 cells), one drawing on a 40-grid at ×1 ×2 ×3 (×3 is the wallpapers' pixel). DEC 2031 for the theme switch, no polling. Lessons live in one file (154 `place` calls in theme.sh would cost a second).

r27-extra, for his veto: the ladder's ten faces (kodama, an old cedar with its rope and a sprout; tanuki with his leaf; kappa with his dish; karakasa, the one-eyed umbrella on its geta; the fox mask; tengu; yuki-onna; oni; hannya; shuten-doji in fire, three horns and a third eye), sparks on a capture, the toppling king, a seal stamped on the year when a day is done, the squares drill.

## Lines for the ledger

- r27-25 (T25a) research digest `.claude/notes/chess-research.md` (105 pages fetched, tags in docs/learn/chess/SOURCES.md), curriculum docs/learn/chess/curriculum.md (365 days, written from syllabus.py by tools/build-chess-curriculum.py), ladder docs/learn/chess/ladder.md. Verified: every lesson's FEN, move and page by tools/check-chess-lessons.py against the rules and Stockfish 19; every set position's goal by Stockfish; five changes forced: above.
- r27-26 (T25b) the app. Verified: see "How it was tested".
- r27-27 (T25c) tested to destruction: see below.

## How it was tested

All on this PC, in a pty of its own (tests/content/chess_pty.py) or a headless dwl (tools/kit.sh), never the session. The machine stood at load 20–70 throughout.

| what | result | when, on what |
|---|---|---|
| tests/content/test_chess_rules.sh | 7/7 | 19:35, 3beaf78's tree |
| tests/content/test_chess.sh, with the real Stockfish 19 | 12/12 | 19:58, before the drag and the large face: **to run again** |
| 20 games against Stockfish, levels first to strong (chess_games.py) | 20 played, 20 PGNs replayed by Stockfish to the same position, no crash | 19:50, before the drag: **to run again** |
| 200 puzzles (chess_puzzles200.py) | 200 different, tries 200, right first time 100, rating moved, due 100, no crash | 19:20, before the solved-puzzle beat: **to run again** |
| every lesson walked by keyboard (chess_walk.py) | 154 of 154 done, no crash | 20:03, frozen b (before the large face) |
| every key on every screen, 3 sizes, 2 moods (chess_sweep.py) | 3600 keys, no crash, nothing cut | 19:59, frozen a: **to run again** |
| nothing left behind (chess_ghost.py, new) | old code: 5 of 16 moves left pixels of the moving man on the squares around; fixed: 0 of 24, then 0 of 15 with drags | 20:02 |
| the fuzz (chess_fuzz.py) | 90 s clean (1285 actions, 59 runs) after the harness fix. **The 30 minutes have not been run on the final code: the accept of T25c is still open** | 20:05 |
| RSS | 20–33 MB (limit 80), Stockfish 259–318 MB only during a game; up in 0.24 s; 0 CPU ticks in 5 s at your move | 20:10 |
| frames: the scroll's opening and closing, recorded (wf-recorder, ffmpeg passthrough, not for timing) | 47 and 40 frames, 6–14 ms apart, every frame clean | 19:51 |
| shots: all screens, dark (gal5) and light (gal4), 60×20 to 236×51 | looked at; findings below | 20:05–20:14 |

Found and fixed in this pass, each with its test where a test can see it:
- **A man's ghost.** A slide ended by a late frame or a key in flight repainted only its two squares; his last frame stayed on the squares around (stray crown pieces, seen in a shot). chess_ghost.py composites every sixel and compares with a whole redraw.
- **Sparks 8 px too high**: a capture's frames were placed by a square's corner, not on the cell grid.
- **A wrong key**: `Kf3` with no king move became `f3`; `Nf4` flagged wrong still played the only `Nf…` on Enter. test_chess.sh has the case.
- Words cut in half in narrow panels (`teng`, `game 57 of`, `reading the gam`): `_cut` cuts at a word or not at all; the sweep fails on any line wider than the panel.
- Replay's dangling "you won:" with no termination; the seal's large frame spilled past the paper and stayed (see-through margin): kept on the paper.
- SIGTERM with a terminal that will not read: no longer waited for.
- **A light game from a puzzle** (245 of the 730) began before the opponent's move, so a weak engine could simply not play it and the tactic never came: the first move is on the board now (checked for all 245: legal, you to move). Its start was also searched for again at every frame of the row under the cursor: once now.
- The tests: fixed sleeps at start-up replaced by Tty.settle (they failed at load 50); the walk waits for its drills; **the fuzz started a second program after every restart** (the first kept the lock, the second sat in cooked mode, a random Ctrl+\\ dumped core): one at a time now, and SIGQUIT ignored in the tests' programs.

New since the last notes (r27-extra, for his veto, with those above): the year's scroll unrolls and rolls up (420 ms, the rod in whole art pixels with its shadow), a torii at the end of the plan's path at 1800, a large face across a large board, the face of who you meet on today's game row, a drag with the man under the pointer, sparks in puzzles and lessons, a solved puzzle's beat (the square lit, `✓ solved +8`, 0.55 s, any key goes on), chess's own ?? ? ?! in the review, arrows redrawn on the art's pixels, board and panel one centred block in a large window (the panel no wider than 60 columns: a tile is the usual size, 236 × 51 alone on a workspace).

For the main run: my fuzz's Ctrl+\\ left python core dumps in /var/lib/systemd/coredump (87 python3.14 of uid 1000 today, not all from this lane; 1 GB in all with others'). No sudo here, so I left them: systemd-tmpfiles ages them out, or `sudo rm` them when convenient.

## OWNER VERDICT 2026-11-04 21:31 on your render final-sprint: comment
OWNER 21:30 — FINAL SPRINT: "you have 2 hours, finish the whole fedokawaii project fully". Deadline 23:30. Order of the night (relayed by Claude):
1. 21:30–22:30 every lane: finish the most valuable COMPLETE part of its task, test it, push, end its notes with a line DONE and a handover (what main must apply, what is left). No new scope. Never fake done.
2. lane-integrate: merge each DONE lane at once (master review, full offline suite), in this priority: ink, pixels, appsui, updates, iso, asobi, art, chess, typing, torrents, learning, firealpaca, nvim, fixer, hardware, network, saver.
3. main: 22:45 at the latest merge lane-integrate, then APPLY on the PC (he is here, screen takeover allowed; a notice on his page first) and check the desktop, the lock (lane-ink's M1 / M2) and the menus live.
4. main ~23:00: the Fedora 45 upgrade through the update button (snapshot first, btrfs scrub after; he decided to go ahead), unless the apply left something broken.
5. lane-iso: build and prove the final Fedora 45 ISO from merged main in its VM as soon as main has the merge, in parallel.
6. 23:30: main writes the owner's summary: what is done and proven, what is left (kept open in the plan for the next round), how to roll back.
