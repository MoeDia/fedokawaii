# Chess app research digest (fetched 2026-11-04)

Goal under test: one adult complete beginner, zero to 1800 chess.com rapid in one year; 730 games (2 a day) against built-in Stockfish at lesson-matched levels, plus about 10 minutes of puzzles a day.
Every claim carries a source tag such as [A1]. The tags are defined in `docs/learn/chess/SOURCES.md` (URL, what it was used for, date fetched; all fetched 2026-11-04). "(from memory, unverified)" marks anything not read on a page. "(snippet only)" marks something seen only in a search-result summary, never on a fetched page. Section H lists what could not be fetched or verified. Quotes are short; the rest is my own wording. Numbers are written as the sources give them. The Python tables (sections A2, B4 and F1) are my own arithmetic on formulas the sources quote; they are labelled as such.

---

## At a glance: the findings that decide the design

1. Opponent strength: Stockfish's UCI_Elo is an engine-pool scale (CCRL, anchored on the Stash engine), floor 1320, with no human-rating claim; the formula is a cubic in (Elo-1320)/1870 [A1][A2][A6]. Skill Level picks among at least 4 root lines at search depth 1+level [A2][A3]. No source maps it to chess.com; the app must measure its own ladder (section A4).
2. Lichess's AI levels use movetime 50 to 1000 ms, depth 5 to 22 and Skill -9 to 20; the official engine rejects Skill values below 0, so levels 1 to 3 may not behave as intended (section A5, inference).
3. Puzzles: CC0 database, 6,193,530 puzzles, the first move in `Moves` is the opponent's setup move, a first wrong move is a failed attempt on lichess, 77 theme keys [B1][B2][B5].
4. Error labels: chess.com publishes expected-points thresholds 0.02 / 0.05 / 0.10 / 0.20 but its accuracy number is secret; lichess publishes both win% and accuracy formulas [C1][C3][B3].
5. Mastery gates that real curricula use: 80% correct to finish a Steps level [D2]; 11 of 22 points pass, 15 good, 19 excellent per Yusupov chapter, and 50% on revision tests [D14][D15].
6. Order of teaching: rules, then board vision and safety ("Is it safe?", counting), then mates and one- to two-move tactics, then endgames by rating class [D3][D12][D33].
7. Time control: Heisman says 10 to 30 minute games can hinder learners and wants 30+5 or slower [D22]; chess.com "rapid" starts at 10 minutes [C6].
8. Science: deliberate practice explains 34% of reliable variance in chess skill [E6]; a 7-year longitudinal study found games and coaching mattered and study hours did not [E20]; retrieval, spacing and interleaving are lab-proven on non-chess material [E11-E14]; error rates track position difficulty far more than skill or clock [E16].
9. Feasibility: 1 to 1.5 h a day is 365 to 548 h a year, about 12% to 17% of the average study hours of an under-2000 player in one sample [E6]; no source documents an adult from zero to 1800 in 12 months; the best 12-month datum is a self-reported 36-year-old at about 1450 [C18].
10. The 2-games-a-day plan uses 67% to 83% of a 1 to 1.5 h budget on play alone (section F1); one deep game plus one light session fits better.

---

## A. Stockfish and how lichess weakens its AI

### A1. The options that weaken play (official docs)
The wiki page "UCI & Commands" now lives on the docs site as "UCI Protocol and Stockfish Commands" [A1]. The old github.com wiki URL returned only an empty "create page" editor, so the docs mirror was used.

| Option | Type, default, range | What the docs say [A1] |
|---|---|---|
| Skill Level | spin, 20, 0 to 20 | "Lower the Skill Level in order to make Stockfish play weaker". "Internally, MultiPV is enabled, and with a certain probability depending on the Skill Level, a weaker move will be played." |
| UCI_LimitStrength | check, false | "Enable weaker play aiming for an Elo rating as set by UCI_Elo. This option overrides Skill Level." |
| UCI_Elo | spin, default 1320, min 1320, max 3190 | "If UCI_LimitStrength is enabled, it aims for an engine strength of the given Elo. This Elo rating has been calibrated at a time control of 120s+1s and anchored to CCRL 40/4." |
| UCI_ShowWDL | check, false | "show approximate WDL statistics as part of the engine output"; the numbers model engine self-play "at fishtest LTC conditions (60+0.6s per game)". |
| MultiPV | spin, 1, min 1 | N best lines; the page lists max 500 in the table and 256 in an example (page contradicts itself). |
| Threads, Hash, Move Overhead | Threads default 1 (max 1024); Hash default 16 MB; Move Overhead default 10 ms (max 5000) | Move Overhead: "Assume a time delay of x ms due to network and GUI overheads". |

`go` limits [A1]: `nodes x` "Stop the search when approximately x number of nodes have been reached"; `movetime x` "approximately x ms"; `depth x`; `wtime/btime x` clock milliseconds. All are "approximately", so a node limit is a soft cap.
Declared ranges in source: `options.add("Skill Level", Option(20, 0, 20));` and `UCI_Elo` between `Skill::LowestElo` and `HighestElo` in `src/engine.cpp` [A4]. Latest release tag at fetch: `sf_19`, "Stockfish 19", published 2026-09-05 [A7]; the source files below are `master` as fetched, not the tag.

How accurate is the UCI_Elo claim? The docs make no accuracy claim and no claim about human ratings [A1]. The FAQ says: "Rating Stockfish against a human scale, such as FIDE Elo, has become virtually impossible", because a human cannot get enough draws or wins and a reliable measure needs "very large data sets, typically tens of thousands of games" [A6]. The code comment says the mapping is "a fit of the Elo results for games played between Stockfish at various skill levels and various versions of the Stash engine" and that "Skill 0 .. 19 now covers CCRL Blitz Elo from 1320 to 3190, approximately" [A2]. So the scale is an engine-pool scale (CCRL, anchored on the Stash engine), not a human one.

### A2. The exact UCI_Elo to Skill formula (src/search.h, master) [A2]
```cpp
// "we convert it to an appropriate skill level, anchored to the Stash engine."
constexpr static int LowestElo  = 1320;
constexpr static int HighestElo = 3190;
// (other lines omitted)
double e = double(uci_elo - LowestElo) / (HighestElo - LowestElo);
level = std::clamp((((37.2473 * e - 40.8525) * e + 22.2943) * e - 0.311438), 0.0, 19.0);
// (other lines omitted)
bool enabled() const { return level < 20.0; }
bool time_to_pick(Depth depth) const { return depth == 1 + int(level); }
```
If UCI_Elo is zero the constructor uses `level = double(skill_level)`. The call site in `src/search.cpp` is `Skill(options["Skill Level"], options["UCI_LimitStrength"] ? int(options["UCI_Elo"]) : 0)` [A3].

My table from that formula (python3, arithmetic only):

| UCI_Elo | level | move picked at depth | weakness = 120 - 2*level | weakness/128 |
|---|---|---|---|---|
| 1320 | 0.00 | 1 | 120.0 | 0.938 |
| 1400 | 0.57 | 1 | 118.9 | 0.929 |
| 1500 | 1.49 | 2 | 117.0 | 0.914 |
| 1600 | 2.24 | 3 | 115.5 | 0.903 |
| 1800 | 3.35 | 4 | 113.3 | 0.885 |
| 2000 | 4.18 | 5 | 111.6 | 0.872 |
| 2200 | 5.01 | 6 | 110.0 | 0.859 |
| 2600 | 7.75 | 8 | 104.5 | 0.816 |
| 3000 | 13.75 | 14 | 92.5 | 0.723 |
| 3190 | 18.38 | 19 | 83.2 | 0.650 |

Consequences read from the arithmetic: (1) at UCI_Elo 3190 the polynomial gives 18.38, so the clamp at 19.0 never binds and no UCI_Elo setting reaches level 19 or 20 (level 20 only by switching the limit off). (2) From 1320 to about 1444 the level moves 0 to 1 and `weakness` changes from 120 to 118; the two ends are nearly the same engine, so the low end of the Elo scale has little real granularity. (3) Inverse: level 1 needs UCI_Elo about 1444, level 2 about 1566, level 3 about 1729, level 5 about 2197.

### A3. How Skill Level picks a move (src/search.cpp, master) [A3]
Quoted lines: `static PRNG rng(now());  // PRNG sequence should be non-deterministic`; `int delta = std::min(topScore - minScore, int(PawnValue));`; `double weakness = 120 - 2 * level;`; `int push = int(weakness * int(topScore - rootMoves[i].score)` `+ delta * (rng.rand<unsigned>() % int(weakness))) / 128;`; `if (rootMoves[i].score + push >= maxScore)`. In the iterative-deepening loop: `if (skill.enabled()) multiPV = std::max(multiPV, usize(4));` and `if (skill.enabled() && skill.time_to_pick(rootDepth)) skill.pick_best(rootMoves, multiPV);`; at the end `skill.best ? skill.best : skill.pick_best(rootMoves, multiPV)` chooses the played move.
Plain reading (mine, from the code): the search always keeps at least 4 root lines. At iteration depth `1 + int(level)` it scores each of those lines as (search score + push). `push` adds back `weakness/128` of the line's deficit to the best line, plus a random term up to about `delta * weakness/128`, `delta` being at most one pawn of eval. The line with the highest adjusted score is played. So (a) the engine never plays outside its own top `multiPV` lines (at least 4, as seen at that depth), (b) at level 0 the pick happens after the depth-1 iteration, so it chooses among four candidates ranked by a depth-1 search (a hanging piece can sit among them), (c) even at level 18 about 65 percent of the deficit between lines is erased, (d) a `go depth`/`nodes`/`movetime` limit that stops the search before depth `1+level` falls through to the last-resort `pick_best` call. There is no "random legal move" mode: the weakest official setting is still a four-candidate engine.

### A4. What this means for a beginner ladder
The weakest official setting is UCI_Elo 1320 on an engine scale (CCRL blitz, [A2]); no source says what that is against a chess.com 400-800 beginner. Community numbers disagree: a TalkChess poster ("lkaufman", 21 Apr 2021) says engines tuned to "CCRL 1500" are "significantly stronger than 1500 FIDE . about 1890 +/- 100", with no data [A14]; another poster (Ferdy) measured Stockfish 13 UCI_Elo 1500 at 67.5 percent over 100 games against Maia set at 1410 and converted that to "1539 FIDE" with a lichess-blitz-to-FIDE regression [A14]; a ChessUp forum post (2 Dec 2025) says a bot labelled "Stockfish elo: 1500" scored about 1924 on a Fritz 20 scale, a small unverified sample [A15]. A TalkChess poster in the Dec 2021 thread: "I know that the SF Elos are tied to CCRL" [A13]. I found no published human-versus-UCI_Elo study. Chess.com does not publish how its own bot ratings are set (forum users say so; snippet only). Conclusion: the app must measure its own opponent ladder (engine versus engine, then the learner's own results) and never show UCI_Elo as if it were a chess.com rating.

### A5. How lichess weakens AI levels 1 to 8 (fishnet source, main) [A8][A9]
`src/api.rs`, `impl SkillLevel`:

| Level | movetime (ms) `time()` | `skill_level()` | `depth()` |
|---|---|---|---|
| 1 | 50 | -9 | 5 |
| 2 | 100 | -5 | 5 |
| 3 | 150 | -1 | 5 |
| 4 | 200 | 3 | 5 |
| 5 | 300 | 7 | 5 |
| 6 | 400 | 11 | 8 |
| 7 | 500 | 16 | 13 |
| 8 | 1000 | 20 | 22 |

`src/stockfish.rs` (function `go_multiple`) sends `setoption name MultiPV value {chunk.work.multipv()}` and `setoption name Skill Level value {skill}` (20 for analysis, `level.skill_level()` for a move), then in `go` builds `go movetime {ms} depth {d}` and appends `wtime btime winc binc` if a clock is present [A9]. The file contains no `UCI_Elo` or `UCI_LimitStrength` [A9]. fishnet compiles the unpatched official Stockfish submodule with only `-DNNUE_EMBEDDING_OFF` added [A10][A11]; its README has no level table [A12].
A caution I found, not run: the official Stockfish declares Skill Level as 0 to 20 [A4], and `Option::operator=` silently ignores a spin value outside the range (no clamp, no error) [A5]. fishnet sends -9, -5 and -1 for levels 1 to 3. Unless the workers run a build with a wider range (build.rs shows none), those three values would be rejected and Skill Level would stay at 20, leaving only the 50 to 150 ms movetime and depth 5 to make levels 1 to 3 weak. This is inference from source; I did not run an engine. Do not copy lichess's table blindly.
Lichess shows nominal ratings per level; I found no staff statement. Forum users say the scale "is from 800-3000 instead of 1350-2600" and that level 3 is "roughly" 1400 [A16][A17]; one thread mentions a fishnet commit "update fishnet elo estimates" without showing numbers [A17]. Treat them as unverified labels.

### A6. Calibration protocol for the ladder (my proposal, built on the sources above)
- Define each rung as a tuple of `Skill Level` (or `UCI_Elo`) plus a node or movetime cap. `go nodes` and `movetime` are "approximately" limits and UCI_Elo was calibrated at 120s+1s [A1], so any short fixed limit changes the strength: measure at the limits the app really uses.
- Measure adjacent rungs engine against engine on this PC (hundreds of games from varied starts) and fit Elo differences; the FAQ stresses that Elo "is fundamentally relative" and depends on match conditions [A6].
- Anchor to humans only through humans: the learner's own results (Glicko with RD [C5]) and, as an outside reference, Maia 1100 / 1500 / 1900 on the lichess scale [E19]. Lichess and chess.com ratings differ by hundreds of points at the same skill [C13].
- Below the floor: UCI_Elo 1320 is Skill 0 (section A2). Weaker rungs need a node cap on top (a few nodes to a few dozen); the effect must be measured, no source gives it.
- Reproducibility: the pick uses `static PRNG rng(now())`, seeded from the clock [A3], so the same position can get different moves. Fine for variety; for regression tests record seeds of the app's own logic and test the ladder statistically.

---

## B. Lichess puzzle database and accuracy formulas

### B1. Facts from database.lichess.org [B1]
- Licence: the page header states "Database exports are released under the Creative Commons CC0 license." The puzzle section does not repeat it.
- File `lichess_db_puzzle.csv.zst`; "6,193,530 chess puzzles, rated, and tagged"; "last updated on 2026-11-03". The page gives no download size (not verified).
- CSV fields in the page's order: `PuzzleId, FEN, Moves, Rating, RatingDeviation, Popularity, NbPlays, Themes, GameUrl, OpeningTags` and `DailyDate` (Unix timestamp in milliseconds).
- `FEN`: "the position before the opponent makes their move"; `Moves`: UCI; the first move is the opponent's move that creates the puzzle; "The second move is the beginning of the solution"; "All player moves of the solution are 'only moves'". So the side to move in the FEN plays move 1, and the learner starts at move 2.
- `Popularity`: a number between 100 (best) and -100 (worst); `OpeningTags` is set only for puzzles starting before move 20 [B1].
- Rating: "each attempt to solve is considered as a Glicko2 rated game between the player and the puzzle" [B1].
- The README of the puzzle generator says only that it uses Stockfish and database.lichess.org to produce candidates and a validator with human review; it gives no thresholds [B7]. (github.com/lichess-org/lichess-puzzler returned 404; ornicar/lichess-puzzler was read.)

### B2. Theme keys (puzzleTheme.xml; 77 name keys, 74 description keys) [B2]
Keys with my one-line meanings (descriptions in that file, paraphrased):
- Goal: `advantage` (reach 200 to 600 cp), `crushing` (eval 600 cp or more after spotting a blunder), `equality` (recover from a losing position to 200 cp or less).
- Phase: `opening`, `middlegame`, `endgame`; material endgames `pawnEndgame`, `knightEndgame`, `bishopEndgame`, `rookEndgame`, `queenEndgame`, `queenRookEndgame`.
- Length: `oneMove`, `short` (two moves), `long` (three), `veryLong` (four or more).
- Source: `master`, `masterVsMaster`, `superGM` (games of titled or top players).
- Mate length: `mate`, `mateIn1`, `mateIn2`, `mateIn3`, `mateIn4`, `mateIn5` (5 or more).
- Mate patterns: `anastasiaMate`, `arabianMate`, `backRankMate`, `balestraMate`, `blindSwineMate`, `bodenMate`, `cornerMate`, `doubleBishopMate`, `dovetailMate`, `epauletteMate`, `hookMate`, `killBoxMate`, `morphysMate`, `operaMate`, `pillsburysMate`, `smotheredMate`, `swallowstailMate`, `triangleMate`, `vukovicMate`.
- Motifs: `attraction` (lure a piece), `capturingDefender`, `clearance`, `collinearMove` (a piece slides along an attack line without capturing), `deflection`, `discoveredAttack`, `discoveredCheck`, `doubleCheck`, `fork`, `hangingPiece`, `interference`, `intermezzo` (zwischenzug), `pin`, `skewer`, `trappedPiece`, `xRayAttack`, `zugzwang`, `sacrifice`, `quietMove`, `defensiveMove`, `exposedKing`, `advancedPawn`, `attackingF2F7`, `kingsideAttack`, `queensideAttack`, `castling`, `enPassant`, `promotion`, `underPromotion`.
- Not themes in the CSV sense (UI strings): `mix` ("healthy mix"), `playerGames`, `puzzleDownloadInformation`, `promotePawnToQueenRookOrMinor`.

### B3. How a puzzle attempt is rated [B4][B5]
- First wrong move: the client sets `lastFeedback = 'fail'`, takes the move back, enters mode `'try'` and calls `sendResult(false)` at once; the user may keep trying but the result is already sent (`if (this.resultSent) return`), so a later correct finish is not reported as a win. Giving up (view solution) also sends a failure. A hint shown before the result makes the attempt unrated (`this.rated() && !this.hintHasBeenShown()`). In streak mode a failure ends the run [B5].
- Server (`PuzzleFinisher.scala`): casual, unrated and repeat attempts change no rating; a first rated attempt is one Glicko-2 game "the player is white and the puzzle is black"; the puzzle's rating change is clamped by `Glicko.maxRatingDelta`; a theme-dependent weight blends old and new rating (`0.1` win / `0.4` loss for "obvious" themes such as mate in 1; `0.2` / `0.7` hinting themes; `0.7` / `0.8` endgame and opening; `1` for mix); the puzzle's own rating is only updated while `canUpdatePuzzleRating`, a rate limit of `300` per `1.day`, allows it [B4]. tau and the rating-deviation bounds are not in that file.
- A community critique says lichess does not implement textbook Glicko-2 (no rating periods, an artificial RD floor); contested, snippet only.
- The lichess FAQ (games): "Ratings are calculated using the Glicko-2 rating method"; a rating is provisional when the deviation is greater than 110; "It is best not to think of ratings as absolute numbers, or compare them against other organisations" [B6]. The FAQ has no puzzle section.

### B4. Win% and accuracy formulas (lichess.org/page/accuracy) [B3]
```
Win%      = 50 + 50 * (2 / (1 + exp(-0.00368208 * centipawns)) - 1)
Accuracy% = 103.1668 * exp(-0.04354 * (winPercentBefore - winPercentAfter)) - 3.1669
```
The page says the win-chance equation "is based on real game data" and may change. Game accuracy: sliding windows sized by game length; volatility of each window = standard deviation; volatility-weighted mean of move accuracies; harmonic mean of move accuracies; the final number is the average of the two means. Limits quoted: "It is flawed to compare accuracy to a numerical grade you would get on a test"; "There is no universally accepted way to compute accuracy percentages."
My arithmetic (python3): 100 cp is 59.1 percent, 200 cp 67.6, 300 cp 75.1, 600 cp 90.1. A move that loses 1, 5, 10, 20, 30 win-percentage points scores 95.6, 79.8, 63.6, 40.0, 24.8.

### B5. Ingest notes for the app
- The side to move in `FEN` plays `Moves[0]` (the opponent's setup move); the learner then plays the odd-numbered entries `Moves[1]`, `Moves[3]` and so on; the replies are the even-numbered entries from `Moves[2]` on [B1].
- Check on the first rows after download: that `Themes` and `Moves` are space-separated lists and that `OpeningTags` may be empty (from memory, unverified; the page does not say).
- `RatingDeviation` small means a settled puzzle rating; `Popularity` runs from -100 to 100; `NbPlays` shows exposure [B1].
- Licence CC0 [B1]: the database may be shipped or cached with the app; the page says nothing about attribution duties beyond that.
- Rating of a learner against puzzles: reuse lichess's rule (single Glicko-2 game against the puzzle, first wrong move fails, hints void the rating) [B4][B5].

---

## C. chess.com (official help pages first; forums labelled)

### C1. Game Review move classification [C1][C2]
Help-centre article "How are moves classified? What is a 'blunder' or 'brilliant,' etc.?", dated February 9, 2026, "Classification V2" [C1]. Model: Expected Points, an estimate of winning chances "from their rating and the engine evaluation"; "1.00 is always winning, 0.00 is always losing, and 0.50 is even"; after each move the system measures how the player's expected points changed.

| Label | Expected points lost, lower | upper |
|---|---|---|
| Best | 0.00 | 0.00 |
| Excellent | 0.00 | 0.02 |
| Good | 0.02 | 0.05 |
| Inaccuracy | 0.05 | 0.10 |
| Mistake | 0.10 | 0.20 |
| Blunder | 0.20 | 1.00 |

Rules beyond expected points [C1]: Great move = "critical to the outcome" (losing to equal, equal to winning, or the only good move), "more generous" for new players; Brilliant = a good piece sacrifice, you "should not be in a bad position after" and "should not be completely winning even if you hadn't found the move", always best or nearly best, again more generous for new players; Miss = failing to take advantage of an opponent's mistake, with the engine evaluation that counts as winning, equal or losing "varies by rating". Book is not defined on that page. History: a 10 Nov 2022 staff announcement narrowed Blunder to moves that lose material or allow forced mate and introduced Miss with a "Ø" glyph, no numeric thresholds [C2]; V2 supersedes it as far as the help page goes.

### C2. Accuracy and Game Rating [C3][C4]
Accuracy: "a measurement of how closely you played to what the computer has determined to be the best possible play"; 0 to 100; now CAPS2, "an improved version of the original Chess.com 'CAPS'"; under CAPS2 "the majority of scores now fall mostly between 50 and 95"; meant to "replicate the feeling of being graded on a test in school"; the page gives no formula [C3]. Old CAPS: about 40 percent "Best" moves gave a single-digit score, which discouraged low-rated players and fed cheating allegations at the top [C3]. Game Rating is a per-game performance estimate from "the quality of your moves" against what is expected at your rating; formula not published; "Over time, your Performance Rating will average out close to your actual rating" [C4]. So chess.com's classification is rating-aware and its accuracy is a trade-secret number; lichess publishes its formulas (section B4).

### C3. Lessons: structure as far as public pages show [C10][C11][C12]
- Learn Path (guided) versus Lesson Library (browse, filter by level, theme, instructor; tabs Openings, Strategy, Tactics, Endgames, Master Games, Attacking).
- Levels: New to Chess (moves, rules, castling, en passant) -> Beginner (basic strategy, finding checkmate, basic openings) -> Intermediate (endgames, full-board strategy, coordinating pieces) -> Advanced (deeper endgame, opening, tactics). Each level has its own colour; each has several courses; each course has several lessons "and challenges" (no counts published) [C10].
- Newer Learn Path lessons are "interactive, coach-guided exercises instead of videos"; old video lessons stay in the library. Tiles: locked / available / completed; first lesson of each course always unlocked; skipping ahead in a course asks for confirmation; a "Next Lesson" button walks the path in order [C10].
- Learning Rank: "Each lesson is worth 1 point, and your rank increases every 10 points": Pawn 10, Knight 20, Rook 30, Queen 40, King 50; after King each further 50 points adds a King level [C11].
- Access: Premium unlimited; Basic gets unlimited "Learn to Play" and one lesson a day elsewhere [C10].
- On the library page: "Learn To Play" is the only course tagged Beginner, 12 lessons; the first 25 courses total 194 lessons; most courses are 3 to 8 lessons; no durations are listed [C12].
- Lichess's own interactive path is much smaller: 6 piece stages, 6 "Fundamentals" (capture, protection, combat, check in one, out of check, mate in one), 4 "Intermediate" (board setup, castling, en passant, stalemate), 2 "Advanced" (piece value, check in two); no tactics or openings [B8].
- Evidence on lessons: a chess.com article by an NM studied 204 members rated below 1000 (6 months, May to Nov 2019): median lessons 56 / 51 / 2 in the three groups; in blitz a 25-year-old rated 900 was expected to gain 65.5 points in six months plus 3.8 per 60 games and 14.1 per 60 lessons; bullet showed nothing; rapid showed 15.5 points per 60 lessons; group differences were not significant; effects are associations [C17].

### C4. Rating system [C5][C6][C9]
- "Chess.com uses the Glicko rating system" with a rating deviation (RD); changes are larger when the rating gap is larger, when your rating is less certain, or when the opponent's is; "your rating will fluctuate significantly during your first few games" [C5]. (The official page says Glicko, not Glicko-2.)
- New account: the rating is "based on the skill level you chose when you created your account"; the official page lists no values [C5]. Forum, non-staff (Martin_Stahl, 27 Feb 2021): New to chess 400, Beginner 800, Intermediate 1200, Advanced 1600, Expert 2000; in Dec 2022 he adds the Expert option is gone and the rating is shown only after 5 or more games [C9]. A staff-flagged poster (MGleason, 9 Dec 2022) says a Beginner started at 800 and "New accounts get big rating adjustments to help them quickly narrow in on an approximately accurate rating" [C9].
- A new time class starts from the closest speed (Rapid uses Blitz before Bullet); "Very high ratings may be lowered when they carry over"; Live and Daily never carry over [C5].
- What counts as rapid: the help article says Rapid is "For games 10 minutes and longer", with the class set by estimated total time assuming 40 moves, so increment counts: a 2 | 12 game comes to about 10 minutes and is rated Rapid [C6]. Two chess.com glossary pages disagree: "rapid games consist of any game with a time control of 10 minutes or more" [C8] versus "longer than ten minutes per player" (so exactly 10 would be blitz) [C7]. The support article is the operative rule.
- Deflation/inflation (forum data, labelled): "TIL: 5 years ago, a 1000 rapid rating was 49th percentile. Today it's the 81st!" (Kraig, 16 Aug 2024; method unclear) [C16]; average rapid 664 over almost 51 million players (Martin_Stahl, 13 May 2023) and "the average rapid rating is 620" and "the median rating is 400" read off the leaderboard graph (kaegun, 14 Sep 2024; another poster says median about 550) [C15]. The pool is dominated by new players, so percentile cut-offs drift; rating-number targets drift with them.

### C5. Published percentile of 1800 rapid? None found
The chess.com leaderboard page returned no distribution to the fetch [C19]. Only user-collected points exist: racquetballCourt (8 Jul 2023) recorded from players' stats pages 1447 = 96.4th percentile, 1192 = 90.1, 1099 = 86.3, 967 = 79 and says "I'm sure there are mistakes" [C14]. 1800 lies beyond the highest point; top 1 percent or better is an extrapolation, not a figure from any source (a search snippet mentioned "99.5 percent at 1801", page not fetched).

### C6. Chess.com rapid versus FIDE versus lichess
Chessgoals.com "Chess Rating Comparison", "Updated July 2026": a third-party site (supported by Amazon and Chess.com affiliate links). Data kind: "thousands of active player profiles" and survey submissions; "All players included in this dataset have active profiles in both systems" but the page does not say how the pairs were matched or whether ratings are self-reported; sample sizes 9,300+ chess.com bullet and 10,100+ rapid profiles, 1,760 USCF and 1,923 FIDE players, 1,935 lichess blitz, 1,455 bullet, 1,066 rapid, 240 classical; lichess players need RD under 150; no accurate data under about 1550 FIDE; chess.com blitz is the baseline, tables are keyed by blitz [C13]. Two reads of the same page gave neighbouring rows: Rapid 1800 sits on the blitz-1700 row (USCF 1715, FIDE 1820, lichess rapid 2015) in one read, and the blitz-1800 row lists Rapid 1870 (USCF 1775, FIDE 1865) in the other. Read it as chess.com rapid 1800 being roughly FIDE 1820 to 1865, USCF 1715 to 1775, lichess rapid about 2000, with a wide error bar. The lichess FAQ itself warns against comparing across organisations [B6].

### C7. Does any source compare Stockfish UCI_Elo with chess.com?
No official or peer-reviewed source found. Stockfish's own FAQ rules out a human-scale rating [A6]; chess.com does not document how its bots are rated; only the community points in section A4 exist (lkaufman about 1890 +/- 100 FIDE for "CCRL 1500"; Ferdy 1539 via Maia; ChessUp thread about 1924). A lichess blog by user smach estimating Stockfish levels against chess.com bots was not fetchable (HTTP 403).

---

## D. Teaching methods (publisher or author pages where possible)

### D1. The Steps Method (Brunia and van Wijgerden) [D1-D13]
- Authors' site: "a teaching method designed to help children and adults learn how to play chess (better), from beginner to a high level (top 700 of the Netherlands)"; six steps; each step has a manual for trainer, teacher or parent plus workbooks; used in schools and clubs in the Netherlands (since 1987), Belgium, Germany, Austria, Switzerland, France, USA [D1]. The English site labels itself a test environment.
- Workbook families [D2][D12]: Basic (steps 1 to 6, plus Vorstufe 1 and 2 for ages about 6 to 9); Extra (1 to 6: first half the same topics as the step, second half unlabelled mixed exercises so that they resemble real game positions; the last pages of some are tests); Plus (1 to 5: new topics and deeper coverage); Mix (1 to 5: mixed exercises, theme shown only in the answers, so repeated mistakes point to a theme to revisit); Thinking ahead (2 and 3; blindfold-style). Steps 1 to 5 have 4 or 5 workbooks each; step 6 has 2 and is a self-study book [D2][D9].
- Mastery rule: "solving 80% of the exercises correctly means the Step has really been mastered", called "the ultimate test", for steps 1 to 5 [D2]. Readiness: move on when pupils "regularly apply what they have learned in their games"; a child who does not capture unprotected pieces is not ready for step 2; the step 1 manual advises "at least a year for the first step" [D3].
- Topics by step [D4-D9]: Step 1: all rules and basic skills, "Learning how to mate is postponed as long as possible"; workbook about 486 exercises, mix 723. Step 2: "the 'real' work begins", first tactics, winning material, positional ideas only lightly ("all games are decided by tactics"); workbook about 526, extra about 628, plus over 600 (pawn endings, stalemate danger), mix 718. Step 3: tactical themes, defence against tactics, trapping, first pawn endings, thinking ahead; 17 base and 14 plus lessons; extra 639, plus 636, mix 726. Step 4: solutions about 2½ moves deep; preparatory tactics (luring, eliminating the defence, chasing, aiming, clearance); positional play enters slowly (material advantage, endgame strategy, weak pawns); about 631 exercises, extra 617, mix 727. Step 5: the last step for group training; pawn structure, seventh rank, strong squares, open files, planned endgames, "Defending"; over 600 exercises. Step 6: self-study; strategy, endgame and one tactics chapter; "only useful" if the first 5 steps are mastered.
- Step 1 manual sample (German, authors' own) [D12]: 15 base lessons (board and pieces; how the pieces move; attack and capture; the pawn; defending; check; mate twice; castling; favourable exchange; double attack; draw; mating with the queen; en passant; notation) and 8 plus lessons (win material, defend, mate, board overview, defend against mate, draw, mate with thinking ahead, the passed pawn). Each lesson runs Orientation, Presentation (introduction, terms, instruction, summary), Processing (memory aids, workbook, "Spielformen" = playing forms), Result check, certificate. The manual says teaching, practice and playing are all needed ("Unterricht (Handbuch), Üben (Arbeitsheft) und Spielen sind notwendig"); handing out only the workbook is better than only playing but, in the authors' words (my translation), still far from the optimum; working memory holds only 4 to 7 elements and loses them within about 30 seconds without rehearsal; combine lessons with "viel Spielen" even before all rules are known; how many games a child needs for board overview differs (my translation: one child must play 300 games, another maybe 1000); the extra workbooks exist because pupils rush to the next step while playing strength usually rises irregularly; mixed tasks carry a three-question check (my translation of the German): can I win material, can I mate, is one of my pieces in danger [D12].
- Rating per step: not on the authors' pages. A chess.com forum post (dannyhume, 25 Sep 2019, no source) lists USCF "up to 800 / 1400 / 1600 / 1750 / 1900 / 2100" for steps 1 to 6 and says to subtract 100 for FIDE [D13]; a lichess blog with the same ceilings is snippet only (HTTP 403). Treat as folklore.
- Mini-games: public pages do not describe them; the manual's table of contents shows "Spielformen" under Processing (pp. 26 to 35) and a "Chess Tutor" CD supplements the books [D12]. Not verified further.

### D2. Yusupov, Build Up Your Chess (Quality Chess) [D14][D15][D16][D17]
- Shape: three levels (Fundamentals, Beyond the Basics, Mastery), three books each (Build Up / Boost / Chess Evolution); Part I, II, III of the exercise book "Revision & Exam 1" correspond to Build Up 1, Boost 1, Chess Evolution 1 [D14].
- Target ratings: Chess Evolution 1 is "Translated from the German edition Tigersprung auf DWZ 1500 III" [D15]; the German publisher's shop calls the 1800 series "A complete training program for the advancement from DWZ 1500 to a playing strength level DWZ 1800 in three volumes" and adds "The level of the books in this series is actually about 200-300 DWZ higher" [D16]; an opinion blog says the German titles are "Tigersprung auf 1500 / 1800 / 2100 DWZ" and that the Fundamentals volume is not for complete beginners (about 1200 suggested) [D17]. DWZ is the German federation rating, close to Elo.
- Chapter build (Chess Evolution 1, pp. 1-35 read) [D15]: 24 chapters plus a final test; each chapter opens with a contents checklist, explains the topic with annotated game examples, then 12 exercises (stars = difficulty = points, triangle = side to move), solutions with points per variation, and a Scoring box: "Maximum number of points is 22; 19 points and above Excellent; 15 and above Good; 11 points Pass mark"; below 11 "read the chapter again and repeat the exercises which you got wrong". Chapter topics rotate through tactics, opening, endgame, positional play, strategy and calculating variations (each chapter is tagged that way in the contents of [D14]), i.e. interleaved: 1 combinations with bishops, 2 diagonals, 3 queen sacrifices, 4 material advantage in a pawn ending, 5 realizing a material advantage [D15].
- Revision & Exam 1 [D14]: 72 tests of 432 positions (6 per test); "To pass each extra test you need to score at least 50% of the points"; "A 100% score is almost impossible"; solve without moving the pieces; "If you have not solved the position after 5-10 minutes, you should make a second attempt for approximately 10 minutes. Now you may move the pieces."; "Absolutely never use the computer!"; about one hour per test; write the variations down; "Mistakes are a part of the learning process!"
- Critique (opinion, not evidence): fixed topic order ignores motivation; reviewer needed up to two hours per chapter [D17].

### D3. Heisman, Everyone's 2nd Chess Book, and his articles [D18-D26]
- Book: subtitle "You Can't Play What You Don't See"; suggested rating range 800 to 1700; a greatly expanded second edition by Mongoose Press in 2018 (212 pages, ISBN 978-1936277841) [D19][D25]. The brief names Russell Enterprises; the pages I read show Mongoose Press (2018), and a search snippet says the 2nd edition was Thinkers' Press 2005 (Russell Enterprises published other Heisman books, snippet only). Publisher topics: board vision, what to do when way ahead, avoiding common thinking mistakes, when to "believe" your opponent, behaviour at the board; no chapter list on either page [D25]. (A Barnes & Noble snippet shows Chapter 1 "Learning, Chunking, and Chess Mistakes".)
- His definitions [D21]: Hope Chess = a move made "without considering whether a possible opponent reply of a check, capture, or threat can be safely met on your following move"; Real Chess = for every move you consider whether such a reply can be met; Counting = "Seeing if pieces are safe from capturing sequences"; Sanity Check = a beginner's final "is this move crazy" check; Seeds of Tactical Destruction = features that let the opponent play a tactic.
- "Is it safe?" [D26][D20]: ask "If I play this move, can my opponent reply with a move that on my following move I can't meet?"; the dangerous replies are always checks, captures or threats; after the opponent moves ask "What are ALL the things that move does?"; assume the answer is "no" and try to prove yourself wrong. Study: about 50% of study time on puzzles, mostly easy ones "roughly 950-1300 on ChessTempo" [D20]. "More players get stuck at 1700 than most other levels", which he links to failing Real Chess [D26]. Teach counting early, starting with whether "a series of exchanges on one square would win or lose material" [D26].
- Slow games [D22][D20][D23]: 45+45 if possible, at least 30+15; "faster time controls (between 10 and 30 min) can hinder improvement"; a 30-minute game with no increment gives about 45 seconds a move; "players trying to learn how to think cannot spend much time on each move"; avoid 15|10 (encourages bad habits); 5|5 is fine for practising safety recognition. "Play as much as you can, especially slow chess"; use nearly all your time; play mostly opponents 100 to 200 points stronger, also some 100 to 200 weaker; "Practice not until you get it right, but until you NEVER get it wrong"; ordinary games teach less than one rating point each (my paraphrase of the page) and a "Three rating point" game is one with several lessons; losses are useful if you find the cause; "Don't be afraid of losing. Be afraid of playing a game and not learning something" [D23].
- Not found: a Heisman "seven deadly sins"; the phrase belongs to Jonathan Rowson's 2000 book "The Seven Deadly Chess Sins" (snippet only). The Novice Nook archive on chesscafe is no longer linked; Heisman's site says students can get "more than 160" columns from him [D18].

### D4. Chernev, Logical Chess: Move by Move [D27][D28][D29]
First published 1957 (Simon & Schuster); "33 classic games from 1889 to 1952" (Wikipedia) [D27]. Batsford: 33 complete games; "going into the players' minds to explain the thought processes behind each and every move"; for readers who "have learned the basic moves" and ask "where can you go next?"; new edition 2026, 256 pages [D28][D29]. The idea: every move gets a sentence of reason, so the reader sees purpose, not just notation. The list of the 33 games was not fetched.

### D5. Seirawan, Winning Chess series [D30][D31]
Seven titles: Play Winning Chess, Winning Chess Tactics, Winning Chess Strategies, Winning Chess Openings, Winning Chess Endings, Winning Chess Brilliancies, Winning Chess Combinations; originally Microsoft Press, now Everyman Chess (Wikipedia; co-authored with Jeremy Silman there) [D30]. Play Winning Chess: basics first, then four topics, Force, Time, Space, Pawn Structure (a review of that book), then annotated real games, with quizzes and tests; "You really must run through the quizzes and tests" [D31]. Wikipedia does not mention the four principles; only the review does.

### D6. Silman, Complete Endgame Course (Silman-James Press; "Siles Press" in some listings) [D32][D33]
528 pages, ISBN 9781890085100; built by rating class ("The idea to divide material according to rating group is great!", Kaidanov blurb) [D32]. Library of Congress contents by part [D33]: One, Beginners (Unrated to 1000): basic checkmates (queen and rook), box and staircase methods, stalemate awareness. Two, Class E (1001-1199): which pieces can mate a lone king, minor pieces versus queen, king activity, opposition, rook-pawn draws. Three, Class D (1200-1399): deeper opposition, king and pawn endings, minor piece versus a pawn, rook versus pawn. Four, Class C (1400-1599): key king-and-pawn techniques, bishop and knight endings, Lucena and Philidor, queen versus pawn. Five, Class B (1600-1799): two healthy pawns versus king, tactical ideas, triangulation, outflanking, connected-pawn rook endings, bishop pairs and opposite-coloured bishops. Six, Class A (1800-1999): pawn races, king-and-pawn versus king-and-pawn, advanced rook technique, bishop fortresses, queen endings. Seven, Experts (2000-2199). Eight, Masters (2200-2399). Nine, "Pure Pleasure". Ladder for an 1800 goal: parts One to Six.

### D7. Polgár, Chess: 5334 Problems, Combinations and Games (Black Dog & Leventhal) [D34]
Publisher text: "306 problems for checkmate in one move", "3,412 mates in two moves", "744 mates in three moves", "144 simple endgames", "128 tournament game combinations"; "Organized by problem type", each keyed to a solution at the back; "More than 6,000 illustrations"; audience "the enthusiastic novice as well as the competitor". The itemised categories sum to 4,734 of the 5,334; the rest (about 600) is not itemised on the page (a retailer snippet says miniature games).

### D8. The Woodpecker Method (Smith and Tikkanen, Quality Chess 2018) [D35-D37]
Book not read (publisher sites blocked; the sample PDF returned 0 bytes). Retailer text: "over 1100 puzzles and solutions"; "solve a large number of puzzles in a row; then solve the same puzzles again and again, only faster" [D37]; another retailer blog says "over 1000" [D35]. Chessable's blog (a marketing text) gives the schedule: first cycle "a large number of exercises in 4 weeks", then re-solve 5 to 6 more times, each cycle half the previous, until the whole set takes a day (6 to 7 passes); focus per cycle: calculation, then recall, patterns, final cycle stamina [D36]. Claims: Hans Tikkanen "3 GM norms in just 7 weeks" after training in spring 2010 [D36]. Evidence offered: Tikkanen's own account, which he concedes "probably wasn't the only way" [D35]; the Chessable blog lists research figures (50 percent retention from active recall, 200 percent for spacing, 45 percent for deliberate practice) that it does not source and I could not check [D36]. No controlled study of the method exists in anything I read.

### D9. Study-plan pages
Only chess.com's Learn Path and lichess Learn (both in section C3) were read; no ChessBase plan was found that I could call reputable. ChessGoals sells a "study plan" (commercial; not used).

---

## E. Science of learning and of chess skill (peer-reviewed; numbers from the abstracts or the papers read)

Reading note: abstracts came from OpenAlex/Europe PMC/repository records; where a record had no abstract the paper itself was read (Hambrick 2014, Anderson 2016, Chase and Simon 1973 first pages). The fetch tool paraphrases abstracts; numbers were copied as given.

- **Ericsson, Krampe, Tesch-Römer 1993, Psychological Review 100(3):363-406, doi 10.1037/0033-295X.100.3.363 [E5]**
  - Finding: Expert performance is the end result of prolonged effortful activity designed to improve performance (deliberate practice); individual differences "closely related to" assessed amounts; "a minimum of 10 years". Violinists: the best had over 10,000 h by age 20, about 2500 h more than "good", about 5000 h more than "teachers" (as restated in [E6]).
  - Use in the app: Practice must be targeted and effortful with feedback, not just playing.
  - Evidence is thin where: Retrospective estimates; chess not studied there.
- **Charness, Tuffiash, Krampe, Reingold, Vasyukova 2005, Applied Cognitive Psychology 19(2):151-165, doi 10.1002/acp.1106 [E1]**
  - Finding: Two samples of tournament players: solitary study the strongest predictor in both; activities together explained about 40% of variance; grandmasters about 5,000 h of serious study in the first decade, nearly 5 times intermediate players. Study 1 N=200, r=.54; Study 2 N=164, r=.48 (table in [E6]).
  - Use in the app: Log and encourage solitary study (puzzles, review, lessons).
  - Evidence is thin where: Self-report recall.
- **Gobet and Campitelli 2007, Developmental Psychology 43(1):159-172, doi 10.1037/0012-1649.43.1.159 (PMID 17201516) [E2][E3]**
  - Finding: 104 Argentinian players: practice important but variable, "the slower player needed 8 times as much practice as the faster player to reach master level"; starting age correlated with skill.
  - Use in the app: No calendar promise; adapt to the learner.
  - Evidence is thin where: One country's club sample.
- **Campitelli and Gobet 2011, Current Directions in Psychological Science 20(5):280-285, doi 10.1177/0963721411421922 [E4]**
  - Finding: Chess review: abundant deliberate practice is "necessary (but not sufficient)"; "minimum requirement to achieve master level is 3,000 hours of DP"; other factors: general cognitive abilities, sensitive period, handedness, season of birth.
  - Use in the app: Do not equate hours with outcome.
  - Evidence is thin where: Review of the same few datasets.
- **Hambrick, Oswald, Altmann, Meinz, Gobet, Campitelli 2014, Intelligence 45:34-45, doi 10.1016/j.intell.2013.04.001 [E6]**
  - Finding: Reanalysis of six chess studies: deliberate practice explained 34% of reliable variance (66% unexplained); 30.2% to 45.3% if reliability is .90 to .60. In the Gobet-Campitelli sample (hours of study alone): intermediate under 2000 M=3,179 (SD 4,615), expert M=5,673 (SD 4,654), master M=10,530 (SD 7,414); masters ranged 832 to 24,284 h, "nearly three orders of magnitude". Polgár sisters: peak 2735 after an estimated 59,904 h versus 2577 after 79,248 h.
  - Use in the app: Track outcomes (error rates, rating estimate), not hours.
  - Evidence is thin where: Self-reported hours again.
- **Burgoyne, Sala, Gobet, Macnamara, Campitelli, Hambrick 2016, Intelligence 59:72-83, doi 10.1016/j.intell.2016.08.002 [E7]**
  - Finding: Meta-analysis: overall r=0.24; Gf 0.24, Gc 0.22, Gsm 0.25, Gs 0.24; Gf 0.32 in youth versus 0.11 in adults; 0.32 unranked versus 0.14 ranked; numerical 0.35, verbal 0.19, visuospatial 0.13. A 2018 corrigendum (snippet only) found Gc and Gs no longer significant after bias adjustment.
  - Use in the app: Adult skill differences lean less on general ability; no ability-based gating.
  - Evidence is thin where: Correlational; few adult samples.
- **Chase and Simon 1973, Cognitive Psychology 4(1):55-81, doi 10.1016/0010-0285(73)90004-2 [E8]**
  - Finding: Three players, master to novice, copy and 5-second recall tasks; glances and pauses mark "chunks". Masters rebuild game positions almost perfectly after 5 s but on random positions "could do no better than weaker players"; about five chunks of four or five pieces explain 20+ pieces recalled.
  - Use in the app: Teach patterns as chunks; train recall of real positions (board vision).
  - Evidence is thin where: Three subjects.
- **Gobet and Simon 1996, Cognitive Psychology 31(1):1-40, doi 10.1006/cogp.1996.0011 [E9]**
  - Finding: Class A to grandmaster recalled up to 5 positions shown 5 s each; experts recalled more than chunking alone predicts; one Chessmaster reproduced nine boards at over 70% average accuracy (as many as 160 pieces). Authors add long-term "templates".
  - Use in the app: A growing bank of known positions pays off; repeat and vary.
  - Evidence is thin where: Tiny N in experiment 3.
- **de Groot, Thought and Choice in Chess (Dutch 1946, English 1965), as summarised in [E8][E10]**
  - Finding: No gross differences between masters and weaker players in moves considered, heuristics or depth; masters "very good at coming up with the 'right' moves"; weaker players "spend considerable time analyzing the consequences of bad moves"; four stages: orientation, exploration, investigation, proof; much is decided in the first seconds.
  - Use in the app: Train candidate generation (what to look at) rather than "think deeper".
  - Evidence is thin where: Old, small think-aloud sample; read through secondary text.
- **Roediger and Karpicke 2006, Psychological Science 17(3):249-255, doi 10.1111/j.1467-9280.2006.01693.x [E11]**
  - Finding: Prose passages; at 5 min restudy beat testing; at 2 days and 1 week "prior testing produced substantially greater retention", though restudy raised confidence.
  - Use in the app: End every lesson with retrieval and no peeking; avoid re-reading.
  - Evidence is thin where: Prose, college students.
- **Cepeda, Pashler, Vul, Wixted, Rohrer 2006, Psychological Bulletin 132(3):354-380, doi 10.1037/0033-2909.132.3.354 [E12]**
  - Finding: 839 assessments in 317 experiments from 184 articles; the best gap grows with the retention interval.
  - Use in the app: Expanding gaps.
  - Evidence is thin where: Verbal recall tasks.
- **Cepeda, Vul, Rohrer, Wixted, Pashler 2008, Psychological Science 19(11):1095-1102, doi 10.1111/j.1467-9280.2008.02209.x [E13]**
  - Finding: More than 1,350 people; gaps to 3.5 months; tests to 1 year; best gap "about 20 to 40%" of a 1-week test delay and "5 to 10%" of a 1-year delay.
  - Use in the app: For a 12-month horizon, review gaps near 5 to 10% of the horizon (about 2 to 5 weeks) for old material; shorter for new.
  - Evidence is thin where: Facts, not skills.
- **Rohrer and Taylor 2007, Instructional Science 35(6):481-498, doi 10.1007/s11251-007-9015-8 [E14]**
  - Finding: College students; spaced beat massed practice (exp. 1), mixed beat blocked practice of several problem types (exp. 2); a week later mixed practice was "vastly superior" (from memory, unverified: roughly 63% versus 20%).
  - Use in the app: Interleave themes in puzzle sessions after the first weeks; Yusupov's chapter rotation does this.
  - Evidence is thin where: Maths; chess transfer unproven.
- **Anderson, Kleinberg, Mullainathan, KDD 2016, doi 10.1145/2939672.2939803, arXiv 1606.04956 [E15][E16]**
  - Finding: About 200 million FICS games and 1 million grandmaster games, positions with at most 6 pieces (24.6 million FICS instances, 880,000 GM); blunder = a move that worsens the tablebase result. Predicting a blunder: random 0.50; skill features 0.55; time left 0.53; difficulty features 0.75; all together 0.75; GM data 0.77. "Blunder potential" = share of legal moves that blunder. "each additional 0.2 increment in blunder potential contributes more, on average, to the aggregate empirical blunder rate than an additional 600 rating points" (FICS 1200 to 1800); players rated 2700 blunder more at potential 0.9 than players rated 1200 at 0.3. Time: error rate climbs sharply as time left approaches 0 and is flat above about 10 s in 3-minute games; more time spent on a move goes with more blunders. Human quiz: about 6000 responses, 0.69 accuracy versus 0.79 for the model on the quiz format.
  - Use in the app: Choose training positions by difficulty (share of moves that lose), not only by rating; clock panic matters in the last seconds, so slow play is about the thinking process, not the clock.
  - Evidence is thin where: Endgames only; 3-minute internet blitz.
- **McIlroy-Young, Sen, Kleinberg, Anderson, KDD 2020, doi 10.1145/3394486.3403219, arXiv 2006.01855 [E17][E19]**
  - Finding: Maia: AlphaZero-style networks trained on human lichess games (Jan 2017 to Nov 2019); nine models for 1100 to 1900; predict human moves better than existing engines; run in Lc0 with `go nodes 1`; "somewhat stronger than their target rating"; GPL-3.0; lichess bots maia1/maia5/maia9 "targeting ELO 1100/1500/1900". The project site now lists Maia-2 and Maia-3 covering 600 to 2600 on the lichess scale [E18].
  - Use in the app: A human-like opponent errs like a person of that rating; a second engine (Lc0) breaks "one tool per job", so use Maia as a calibration reference, not a dependency.
  - Evidence is thin where: Lichess scale, blitz-heavy data.
- **Howard 2012 (online 2011), Applied Cognitive Psychology 26(3):359-369, doi 10.1002/acp.1834 [E20]**
  - Finding: 533 players: log games played the strongest predictor of rating; tracked 7 years: "More study hours had negligible impact. Coaching had some effect over time, and the number of games had a strong effect even when participants were equated on time in the domain." Contradicts the retrospective study-hours result of Charness 2005.
  - Use in the app: Playing volume matters; study needs feedback (the app must act as coach).
  - Evidence is thin where: Tournament players, self-reported study hours.
- **Vaci et al. 2019, PNAS 116(37):18363-18369, doi 10.1073/pnas.1819086116 (PMID 31451633) [E23]**
  - Finding: Longitudinal chess players: intelligence and practice both help acquisition; more intelligent players gain more from the same practice.
  - Use in the app: Learning speed differs; adapt, do not fix the pace.
  - Evidence is thin where: Observational.

Synthesis: (1) the field agrees practice is necessary but explains only part of the variation (34% in [E6]); (2) retrospective studies favour solitary study [E1], the longitudinal study favours games and coaching and finds study hours negligible [E20]; the safe design does both and measures the result; (3) retrieval, spacing and interleaving are strong in lab studies [E11-E14] but none of those studies used chess; (4) I found no randomised trial of a chess curriculum on adults.

---

## F. Honest feasibility: zero to 1800 chess.com rapid in one year at 1 to 1.5 hours a day

### F1. Hours arithmetic (my arithmetic on the sources' numbers)
1 h a day is 365 h a year; 1.5 h a day is 547.5 h. Hambrick's table [E6] gives the average hours of study alone for intermediate players (under 2000) as 3,179 (SD 4,615): the plan is 11.5% to 17.2% of that mean; Campitelli and Gobet's estimate of a "minimum requirement" of "3,000 hours of DP" for master level [E4]: 12.2% to 18.2%. Those hours are study alone by players who mostly started young; the plan's hours also contain games. Two games a day at 20 to 25 minutes each is 243 to 304 h a year, 67% to 83% of the whole budget, leaving 10 to 20 minutes a day for puzzles, lessons and review. The large SD (4,615) shows some intermediates got there with far fewer hours, and "the slower player needed 8 times as much practice" [E2]; hours alone neither forbid nor predict 1800.

### F2. What data exist on adult improvement
- Peer-reviewed: none found that tracks adult beginners' rating gain per year. Related only: Roring and Charness 2007 (N=5,011 active elite players; peak age later than previously proposed) [E22]; adult versus youth ability link r=0.11 versus 0.32 [E7]; starting age correlates with skill [E2].
- Lichess data blog (GitHub README, one author, blitz only; 2.3 million players, 450 million games, 5.5 years, monthly average ratings) [F1]: players rated 800-1000 "typically gain 100 points in just a few months" (1 to 2 months in the filtered view); players rated 1600-2000 need "4 years or more" (3 to 4 filtered); median change 0, mean 22; "The majority 90% of players seem to hover around their initial rating"; about 120 players starting at 800-1200 gained over 800 and about 1,000 gained at least 500, in "a little less than 2 years" on average, and the author says they "are not 'ordinary' people"; the 100+ points a month cases were mostly cheaters, smurfs or bots; practice habits were not measured.
- Chess.com data article by an NM [C17]: under-1000 members who already had 300+ games: blitz +65.5 points in six months for a 25-year-old rated 900 (plus 3.8 per 60 games, 14.1 per 60 lessons); wide spread (interquartile range over 100 points).
- Forum anecdotes [C18] (Oct 2021, self-reported): age 36, began a year earlier, "now about 1450 rapid", goal 1600 (the only 12-month datum I found); 1450 to "1800 plus" in 30-minute rapid in under two years after 8+ years without improvement; "around 1800-2000" suggested as the cap for dedicated adults; "most adult improvers plateau between 1400 and 2000".
- Steps Method folklore (uncited): steps 1 to 6 end at USCF 800, 1400, 1600, 1750, 1900, 2100 [D13]; the authors advise at least a year for step 1 alone [D3] (written for children).

### F3. Verdict (my judgement from the orders of magnitude above; no source gives probabilities)
- Likely: from a signup rating of 400 to 800 [C9] to the high hundreds or low 1000s in rapid after 12 months of structured work; low 1000s to 1200 for a consistent learner.
- Stretch: 1400 to 1600 (the 36-year-old anecdote at about 1450 sits here).
- 1800: nothing I read documents an adult from zero reaching it in 12 months. The lichess tail (about 1,000 players with +500 or more, about 120 with +800, in about 2 years) is below the +1,000 to +1,400 needed, and those players are called non-ordinary by the data's author [F1]. Treat 1800 in 12 months as outside documented outcomes; keep it as the aspiration, publish the honest forecast, and let the app re-fit the date from the learner's own rating curve.
- Percentile context: 1800 rapid is far above the 96.4th percentile point recorded for 1447 in 2023 [C14]; rating numbers drift with the player pool [C16].

### F4. Milestones every 4 weeks (my proposal; gates use measures the app can compute)
| Week | Gate | Band if on track (rapid, judgement) |
|---|---|---|
| 4 | Rules and notation complete; Steps-1 style test at 80% or better [D2]; mate in 1 puzzles 90%; queen and rook mates unaided (Silman part one [D33]) | 400-600 |
| 8 | Captures every unprotected piece; "Is it safe?" prompt answered on every move; exchange counting test 80% [D20][D26] | 500-700 |
| 12 | Fork, pin, skewer, double attack: 75% on lichess puzzles under 1000; beats ladder step 3 | 600-800 |
| 16 | Mate in 2 at 70%; opposition and king-and-pawn basics (Silman parts two and three) | 700-900 |
| 20 | Step-3 topics: trapping, defence against tactics, intermediate move | 800-1000 |
| 24 | Half-year review: refit forecast; hang-rate per 100 moves halved from week 4 | 900-1100 |
| 28 to 48 | One new theme block each 4 weeks (Silman class ladder to Class B); each block gated at 80% | 1000-1400 |
| 52 | Re-test everything from week 4 onward on a fresh mixed set; compare error rates | 1100-1500 stretch; 1800 undocumented |

---

## G. Arguing with myself

### G1. What a complete beginner needs first versus what chess.com sells
Needs, in order of the evidence: (1) the rules and every piece move automatic, plus notation [D12][B8]; (2) board vision and safety: capture unprotected pieces, see every attack and defence, "Is it safe?" [D3][D20]; (3) basic mates and stalemate awareness [D33]; (4) one- and two-move tactics, since "all games are decided by tactics" at the early steps [D5]; (5) exchange counting [D26]; (6) opposition and basic pawn endings [D33].
Chess.com sells: a catalogue of courses by many instructors (openings, master games), gamified progress (1 point a lesson, rank every 10 [C11]), a rating-aware move classification and a trade-secret accuracy number [C1][C3], bots with unexplained ratings. Its own NM-run study found lesson effects small and mostly not significant [C17].

### G2. What the evidence says to cut
- The accuracy percentage as a headline: chess.com's is secret [C3]; lichess says it is "flawed" to read it as a school grade [B3]. Keep error classes tied to win-percentage loss.
- Bullet and blitz: Heisman says 10 to 30 minute controls "can hinder improvement" for learners [D22].
- Study hours and lesson counts as the success metric: Howard found study hours negligible once games are equal [E20].
- Opening memorisation before about 1200 (judgement: Steps puts opening work in step 4 plus [D7]; Yusupov's Fundamentals books have 6 opening chapters among 72, counted from the contents tags [D14]; no source supports line memorisation for beginners).
- Re-reading, massed topic blocks: [E11][E14].

### G3. Criticism of the 2-games-a-day plan
1. Time control. Chess.com rapid starts at 10 minutes [C6]. Heisman wants 30+5 or slower and calls 15|10 a bad-habit control [D20]. Two such games do not fit a 1 to 1.5 hour day (section F1). Options: one deep game a day with a generous clock plus one light session (set position or short game); the evidence (a coach's opinion [D22], not a trial) favours depth; Howard's volume result [E20] argues for more games, so the plan should keep both and measure.
2. Do low-level games teach? Anderson shows blunders follow position difficulty more than skill or clock [E16]; a learner who beats a weak engine is shown easy positions. Keep opponents where the learner scores about half; Heisman plays mostly 100 to 200 points above [D23]. A fixed ladder of "lesson-matched levels" cannot do that; it needs the learner's own results.
3. How many of the 730 from set positions? No source gives a number. Principle from the sources: the curricula are organised around positions, not whole games (Steps workbooks [D2], Yusupov tests [D14], Silman classes [D33]). My judgement: roughly 200 to 300 of the 730 from set positions (endgame conversions from Silman parts one to six, "play it out" tactical positions, the first 8 to 10 moves of two simple repertoires), the rest from the start position.
4. How much review? Heisman: ordinary games teach less than one rating point each and a good game about three (his "Three rating point" game) [D23]; Howard: coaching helped, study hours did not [E20]. So: every game gets about 3 minutes (three biggest swings, answer first, then engine), one game in five gets 10 to 15 minutes; about 15 minutes a day on average.
5. 730 is a vanity number: 730 games at 20 to 25 minutes is 243 to 304 hours of the 365 to 548 hour budget (section F1).

### G4. Ten design rules for the app, each tied to sources
1. Gate by mastery, not by calendar: unlock the next block at 80% on a mixed set (Steps [D2]); chapter tests use "Pass mark" 11 of 22 and "Good" 15 of 22, redo the missed exercises below the pass mark [D15]; the 12-month plan can slip, the gate cannot.
2. Weeks 1 to 4: rules, board vision, safety. Standard question card on every exercise (translated from the German manual): can I win material, can I mate, is one of my pieces in danger [D12]; lesson order follows lichess Learn and chess.com New to Chess [B8][C10].
3. Make "Is it safe?" and counting explicit skills with drills; after a game flag the moves that were Hope Chess (a check, capture or threat reply that could not be met) [D20][D21][D26].
4. Puzzles from the lichess database (CC0, 6,193,530 puzzles, themes by key [B1][B2]); first wrong move is a fail and a hint makes the attempt unrated, as on lichess [B5]; interleave themes after the first weeks [E14]; failed puzzles return at expanding gaps, near 5 to 10% of the remaining horizon for old material [E13]; pick positions by difficulty, not only rating [E16].
5. Games end with retrieval: ask for the learner's three biggest swings before showing the engine's [E11]; classify errors by win-percentage loss with the lichess formula (calibrated on real games, [B3]) and chess.com's 0.02/0.05/0.10/0.20 steps as a template [C1]; Stockfish's WDL is fitted to engine self-play, not to 1000-rated humans [A1].
6. Calibrate the opponent ladder by measurement: UCI_Elo is an engine-pool scale with a floor of 1320 and no human claim [A1][A2][A6]; build levels from Skill Level plus node limits, measure them engine versus engine on this PC, then adapt so the learner scores about half [D23]; never display UCI_Elo as a chess.com rating; keep Maia as a reference only [E19].
7. One deep game and one light session a day; no bullet or blitz; a generous clock and an "Is it safe?" prompt after each opponent move [D20][D22].
8. Endgames by Silman's class order: queen and rook mates, box and staircase, opposition, then Lucena, Philidor and triangulation as the rating bands are reached [D33]; each topic also gets a set-position game.
9. Be honest about progress: every four weeks show the gate result, the rating estimate with its uncertainty (Glicko RD [C5]) and the forecast; say on day one that 1800 in 12 months is outside documented outcomes (section F3) [F1][E6].
10. Stay minimal and sourced: no gamified rank (chess.com counts lessons, 1 point each [C11]); every number the app shows (thresholds, win%, levels) cites its formula; keep the games-per-day setting adjustable and show its time cost (section G3.5).

### G5. Curriculum blocks mapped to lichess theme keys (my proposal, to be tuned; keys from [B2])
The mapping is a design suggestion; only the keys and their meanings come from the source.
- Block 1, rules and safety (Steps 1; lichess Learn [B8]): `mateIn1`, `hangingPiece`, `oneMove`, `short`, `capturingDefender`, `trappedPiece`, `castling`, `enPassant`, `promotion`.
- Block 2, first tactics (Steps 2): `fork`, `pin`, `skewer`, `discoveredAttack`, `doubleCheck`, `attraction`, `deflection`, `backRankMate`, `smotheredMate`, `mateIn2`, `short`.
- Block 3, trapping and defence (Steps 3): `defensiveMove`, `intermezzo`, `xRayAttack`, `clearance`, `interference`, `underPromotion`, `pawnEndgame`, `mateIn3`, `advancedPawn`.
- Block 4, preparation and attack (Steps 4): `sacrifice`, `quietMove`, `exposedKing`, `kingsideAttack`, `queensideAttack`, `long`, `crushing`, `advantage`.
- Block 5, endgames (Silman classes [D33]): `endgame`, `pawnEndgame`, `rookEndgame`, `bishopEndgame`, `knightEndgame`, `queenEndgame`, `queenRookEndgame`, `zugzwang`, `equality`.
- Mate-pattern drills: `anastasiaMate`, `arabianMate`, `bodenMate`, `doubleBishopMate`, `dovetailMate`, `hookMate`, `operaMate`, `cornerMate` and the rest of the `*Mate` keys, taken as optional after block 2.
- Filter by `Rating` and `RatingDeviation` (small RD means a settled puzzle), `Popularity` for quality, `NbPlays` for exposure, and skip `master`, `masterVsMaster`, `superGM` for beginners if the positions look unnatural (my choice) [B1].

---

## H. Not verified, failed fetches, caveats

- `github.com/official-stockfish/Stockfish/wiki/UCI-&-Commands` returned only an empty "create page" form; the docs mirror [A1] was used. A search snippet of an older README mirror claimed UCI_Elo was calibrated at "60s+0.6s"; the current docs say 120s+1s.
- fishnet's levels were read from source only. Whether negative Skill Level values reach the engine was not run (section A5).
- Lichess's nominal level ratings: forum posts only, no staff source.
- Blocked or empty: lichess blogs (smach, NoelStuder, 403); qualitychess.co.uk (403); newinchess.com (403/404); simonandschuster (403); chess.co.uk, chess-tigers.de, shop.chessbase.in (429 on some tries); Woodpecker sample PDF (0 bytes); Semantic Scholar (429); PubMed search pages (cookie wall); the github.com `lichess-org/lichess-puzzler` path (404; `ornicar/lichess-puzzler` read instead).
- Not found: per-step ratings from the Steps authors; Steps mini-game descriptions; Chernev's 33-game list; a Heisman "seven deadly sins" (Rowson's book, snippet only); Quality Chess's own series-level page; chess.com's definition of Book, the official starting-rating values, any official percentile for 1800 rapid; the puzzle CSV download size.
- Silman's chapter list was condensed by the fetch tool from the Library of Congress contents; exact chapter titles were not reproduced.
- The Woodpecker book itself was not read; schedule and evidence come from retailer and Chessable pages.
- WebFetch summarises pages with a small model; formulas and code were fetched twice or from raw files and cross-checked; other numbers were copied as returned.

---

## I. Abbreviations used
- CCRL: Computer Chess Rating Lists, a rating list of engines; "CCRL 40/4" and "CCRL Blitz" are its pools [A1][A2] (40/4 read as 40 moves in 4 minutes: from memory, unverified).
- DWZ: Deutsche Wertungszahl, the German federation rating (used in Yusupov's German titles) [D15][D16]. USCF: US Chess Federation rating. FIDE: world federation rating.
- RD: rating deviation, the Glicko measure of how unsure a rating is [C5][B6]. Glicko / Glicko-2: Glickman's rating systems; chess.com says "Glicko" [C5], lichess says Glicko-2 [B6].
- cp: centipawns; WDL: win/draw/loss statistics; PV: principal variation; MultiPV: number of lines searched [A1].
- Gf, Gc, Gsm, Gs: fluid reasoning, comprehension-knowledge, short-term memory, processing speed [E7].
- DP: deliberate practice [E4][E6]. FICS: Free Internet Chess Server, the data source of [E16].
