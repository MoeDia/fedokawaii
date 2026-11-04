
## OWNER 17:32 — TONIGHT
The owner wants the whole round finished today; he is at the PC until 23:30. Finish, test, push and end this file with a line DONE by 21:30. Complete and working first, refine after; never fake done; list what is left for main. Run heavy builds and tests with nice -n 10. Questions for him: append to ~/repos/fedokawaii/.claude/inbox.md as "## <time> — question from lane-chess".

<!-- status -->
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
| `tests/content/` | test_chess_rules.sh · test_chess.sh · test_chess_destroy.sh · chess_pty.py chess_lib.py fake_stockfish.py chess_walk.py chess_sweep.py chess_fuzz.py chess_games.py chess_puzzles200.py |

theme.sh needs **no change**: its home tree installs configs/home/ as it is, bin/* goes to ~/.local/bin.

## What the main run must do to merge

1. Merge `lane-chess`. No font or icon was rebuilt (only existing icons are used), so nothing binary conflicts.
2. `git apply .claude/notes/lane-chess-integration.patch` — the edits to files this lane may not touch: lib/manifest.sh (stockfish), PACKAGES.md,
   tools/packages.evidence, tests/static/fixtures/programs.txt, tests/look/fixtures/{launched,not-launched}.txt, tests/look/test_launcher.sh,
   system/fedokawaii (the learning row: chess is no longer "soon", opens `kawa-chess --window`), tests/engine/test_menu.sh, docs/design-system.md §14.
   If the typing lane changed `SOON` first, its one line conflicts: keep both removed.
3. `fedokawaii apply` in its turn installs stockfish (dnf) and the files. Look at it: Super+U → learning → chess.
4. `tests/content/` here run with the stand-in engine anywhere, and with the real one once stockfish is on PATH (or `KAWA_TEST_STOCKFISH=PATH`).
5. Plan: mark T25a, T25b, T25c from the ledger lines below; master-trace r27-dec-9a–h.

Not done here, on purpose (other lanes' or main's files, or his word): the design-system.md §-numbers for the board (a row in §14 is in the patch; a § of its own when the main run wants it); T27 cutting docs/learn/chess/README.md into the Learn pieces; VM proof of the install (T54); T19p's review pack may want a chess page (tools/chess-gallery.sh writes the shots).

## Decisions (the digest's argument: chess-research.md §G; "five changes it forced" for T25a's accept)

1. **Two games a day stay, but one deep and one light**: deep = a whole game on a long clock (20+10 → 15+10 → 10+5 → 10+0); light = a set position, an opening line, or a tactic from the puzzle bank to play out, 5+5. 336 light games, 325 from set positions. Two rapid games a day would be 67–83 % of a 1–1.5 h budget (digest F1), and Heisman wants slow games (D22).
2. **Our own measured ladder** instead of trusting UCI_Elo: it is an engine pool's scale with a floor of 1320 and no human claim (Stockfish's FAQ). `tools/chess-ladder.py`, ladder.md: below 1320 a lot drawn among depth-1 moves; levels named from measured gaps; never shown as a chess.com rating.
3. **Exams at 80 % every four weeks that hold the plan** (Steps Method), gates on the endings you must know (K+Q, K+R, Lucena, Philidor; Silman's order).
4. **Judgement first in the review** (Roediger & Karpicke 2006): he says which move he would take back, then finds the better move before being shown. Win chance: Lichess's published formula (fitted on humans), not Stockfish's WDL (fitted on engines); classes: chess.com's published 0.02/0.05/0.10/0.20.
5. **Honesty**: nothing on record shows zero to 1800 in a year (digest F3): said once in the first lesson, in the Learn piece, and the progress tab draws his line against the plan's with a forecast from his own month. The final answer is chess.com.

Others: Sixel, not sextants: a 40 px square would be 10 × 6 blocks in two inks a cell; sixels are 0.4–1.3 ms a frame in Python (bytes.translate + big ints), 18–23 MB RSS, foot at 7 ticks and the app at 12 over 8 s of play with two animated moves. Cell-aligned squares (40/80/120 px = 5×2, 10×4, 15×6 cells), one drawing on a 40-grid at ×1 ×2 ×3 (×3 is the wallpapers' pixel). DEC 2031 for the theme switch, no polling. Lessons live in one file (154 `place` calls in theme.sh would cost a second).

r27-extra, for his veto: the ladder's ten faces (kodama to shuten-doji), sparks on a capture, the toppling king, a seal stamped on the year when a day is done, the squares drill.

## Lines for the ledger

- r27-25 (T25a) research digest `.claude/notes/chess-research.md` (105 pages fetched, tags in docs/learn/chess/SOURCES.md), curriculum docs/learn/chess/curriculum.md (365 days, written from syllabus.py by tools/build-chess-curriculum.py), ladder docs/learn/chess/ladder.md. Verified: every lesson's FEN, move and page by tools/check-chess-lessons.py against the rules and Stockfish 19; every set position's goal by Stockfish; five changes forced: above.
- r27-26 (T25b) the app. Verified: see "How it was tested".
- r27-27 (T25c) tested to destruction: see below.

## How it was tested
