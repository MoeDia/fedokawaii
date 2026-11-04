
## OWNER 17:32 — TONIGHT
The owner wants the whole round finished today; he is at the PC until 23:30. Finish, test, push and end this file with a line DONE by 21:30. Complete and working first, refine after; never fake done; list what is left for main. Run heavy builds and tests with nice -n 10. Questions for him: append to ~/repos/fedokawaii/.claude/inbox.md as "## <time> — question from lane-chess".

<!-- status -->
# lane-chess — T25a, T25b, T25c: the chess app

Branch `lane-chess`. Working: `kawa-chess` runs, plays, teaches and reviews; every test below is green unless it says otherwise.

## What is there

| path | what |
|---|---|
| `bin/kawa-chess` | the launcher (thin: the program compiles once, its pyc in ~/.cache/kawa-chess/pyc) |
| `configs/home/.local/lib/fedokawaii/kawa-chess/` | the program: board (rules) · canvas (sixel) · art (board, men, marks) · term · ui (§7 grammar) · engine (UCI, levels) · store · app (loop) · play · review · puzzles · lesson · progress · course · syllabus (52 weeks) · home |
| `configs/home/.local/share/fedokawaii/chess/` | pieces.txt (the men, 40 × 40) · inks.txt (written by tools/build-chess-inks.py) · lessons.txt (154) · puzzles.tsv (24,478 of Lichess's, CC0) |
| `configs/home/.config/fedokawaii/keys/chess.txt`, `.local/share/applications/kawa-chess.desktop` | Super+/ sheet (the window's title is "chess"), launcher entry |
| `docs/learn/chess/` | README.md (the Learn piece) · curriculum.md (365 days, written from the syllabus) · ladder.md (the measured levels) · SOURCES.md |
| `.claude/notes/chess-research.md` | the research digest, cited |
| `tools/` | build-chess-inks.py · build-chess-puzzles.py · build-chess-curriculum.py · check-chess-lessons.py · chess-ladder.py · chess-gallery.sh |
| `tests/content/` | test_chess_rules.sh · test_chess.sh · test_chess_destroy.sh · chess_pty.py chess_lib.py fake_stockfish.py chess_walk.py chess_sweep.py chess_fuzz.py chess_games.py chess_puzzles200.py |

theme.sh needs **no change**: its home tree installs configs/home/ as it is, bin/* goes to ~/.local/bin.

## What the main run must do to merge

1. Merge `lane-chess`. Generated files are not shared with other lanes; no font or icon was rebuilt (only existing icons are used).
2. `git apply .claude/notes/lane-chess-integration.patch` — the edits to files this lane may not touch: lib/manifest.sh (stockfish), PACKAGES.md,
   tools/packages.evidence, tests/static/fixtures/programs.txt, tests/look/fixtures/{launched,not-launched}.txt, tests/look/test_launcher.sh,
   system/fedokawaii (the learning row: chess is no longer "soon", opens `kawa-chess --window`), tests/engine/test_menu.sh, docs/design-system.md §14.
   Proven on this branch's tree: check-packages clean, test_launcher green, test_menu green. If the typing lane changed `SOON` first, its one line conflicts: keep both removed.
3. `fedokawaii apply` in its turn installs stockfish (dnf) and the files. Then see it in Super+U → learning → chess.
4. Plan and ledger: T25a, T25b, T25c lines (the text is below, ready to paste). master-trace r27-dec-9a–h.
