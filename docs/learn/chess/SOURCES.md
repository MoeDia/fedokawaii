# Sources for the chess research digest

Digest: `.claude/notes/chess-research.md`. Every tag below (A1, B3, D12 ...) is cited in that digest.
All pages were fetched on **2026-11-04** unless a row says otherwise. Books are cited through the publisher's, the author's or an authoritative page that was actually read (never through memory); where only a retailer or a review could be read it says so. Source text is summarised in the digest's own words; nothing is copied beyond short quotes. "Read from PDF" means the fetch tool saved a PDF and the pages were read directly.

## A. Stockfish and the lichess AI

| Tag | Source | Used for |
|---|---|---|
| A1 | Stockfish docs site, "UCI Protocol and Stockfish Commands" (the former wiki page "UCI & Commands"), https://official-stockfish.github.io/docs/stockfish-wiki/UCI-Protocol-and-Stockfish-Commands.html | Skill Level, UCI_LimitStrength, UCI_Elo (range, calibration sentence), UCI_ShowWDL, MultiPV, `go nodes/movetime/depth` |
| A2 | Stockfish source, `src/search.h` (master), https://raw.githubusercontent.com/official-stockfish/Stockfish/master/src/search.h | struct Skill: LowestElo/HighestElo, the UCI_Elo to level polynomial, `enabled()`, `time_to_pick()`, comment on calibration against Stash and CCRL Blitz |
| A3 | Stockfish source, `src/search.cpp` (master), https://raw.githubusercontent.com/official-stockfish/Stockfish/master/src/search.cpp | `Skill::pick_best` (weakness, push, delta, PRNG), MultiPV raised to 4, where `pick_best` is called, the `Skill(...)` constructor call |
| A4 | Stockfish source, `src/engine.cpp` (master), https://raw.githubusercontent.com/official-stockfish/Stockfish/master/src/engine.cpp | Option declarations and ranges (`Skill Level` 0..20, `UCI_Elo`, `UCI_ShowWDL`, `MultiPV`) |
| A5 | Stockfish source, `src/ucioption.cpp` (master), https://raw.githubusercontent.com/official-stockfish/Stockfish/master/src/ucioption.cpp | Out-of-range spin values are silently rejected |
| A6 | Stockfish docs site, "Stockfish FAQ" (sections "The Elo rating of Stockfish", "How do Skill Level and UCI_Elo work"), https://official-stockfish.github.io/docs/stockfish-wiki/Stockfish-FAQ.html | Statement that a human-scale rating is virtually impossible; Elo is relative; UCI_Elo precedence |
| A7 | GitHub API, latest release of official-stockfish/Stockfish, https://api.github.com/repos/official-stockfish/Stockfish/releases/latest | Current release `sf_19`, 2026-09-05 |
| A8 | lichess-org/fishnet, `src/api.rs`, https://raw.githubusercontent.com/lichess-org/fishnet/main/src/api.rs | `SkillLevel` tables: movetime, skill level, depth for levels 1 to 8 |
| A9 | lichess-org/fishnet, `src/stockfish.rs`, https://raw.githubusercontent.com/lichess-org/fishnet/main/src/stockfish.rs | How the level values are sent (`setoption Skill Level`, `MultiPV`, `go movetime depth`); no UCI_Elo |
| A10 | lichess-org/fishnet, `.gitmodules`, https://raw.githubusercontent.com/lichess-org/fishnet/main/.gitmodules | Official Stockfish and Fairy-Stockfish submodules |
| A11 | lichess-org/fishnet, `build.rs`, https://raw.githubusercontent.com/lichess-org/fishnet/main/build.rs | No source patches, only `-DNNUE_EMBEDDING_OFF` |
| A12 | lichess-org/fishnet repository page and `src` listing, https://github.com/lichess-org/fishnet and https://github.com/lichess-org/fishnet/tree/main/src | Locating the level tables (README itself has none) |
| A13 | TalkChess thread "elo ratings in stockfish", https://talkchess.com/viewtopic.php?p=915494 (Dec 2021) | "SF Elos are tied to CCRL"; opinions on human comparison (community) |
| A14 | TalkChess thread "UCI_Elo 1500 engines and FIDE Elo", https://talkchess.com/viewtopic.php?p=890492 (Apr 2021) | Community estimates for UCI_Elo 1500 (1539 FIDE via Maia; "about 1890 +/- 100"); no developer posts |
| A15 | ChessUp community post "Just how strong is ChessUp bot level 12 'Stockfish elo: 1500' in actuality?", https://community.playchessup.com/t/just-how-strong-is-chessup-bot-level-12-stockfish-elo-1500-in-actuality-my-investigation/4029 (2 Dec 2025, revised 21 Dec 2025) | One community measurement of an "Elo 1500" Stockfish bot (small sample, unverified) |
| A16 | Lichess forum thread "computer-ai-levels-changed", https://lichess.org/forum/lichess-feedback/computer-ai-levels-changed | User reports of the level rating range (no staff post) |
| A17 | Lichess forum thread "the-play-against-computer-levels-dont-have-floating-rating-anymore-so-how-should", https://lichess.org/forum/lichess-feedback/the-play-against-computer-levels-dont-have-floating-rating-anymore-so-how-should | Estimated, unexplained level ratings; mention of a fishnet commit |
| (calc) | My own arithmetic with `python3 -I -B -c` on the formula in A2 and on the lichess formulas in B3 (no web source) | UCI_Elo to level table; win% and accuracy sample values; hours arithmetic |

## B. Lichess

| Tag | Source | Used for |
|---|---|---|
| B1 | Lichess open database, https://database.lichess.org/ (puzzle section, page updated 2026-11-03) | Licence statement, puzzle count, CSV fields, `FEN`/`Moves` convention, Popularity, OpeningTags, DailyDate, Glicko2 sentence |
| B2 | lila, `translation/source/puzzleTheme.xml`, https://raw.githubusercontent.com/lichess-org/lila/master/translation/source/puzzleTheme.xml | The 77 theme keys and their descriptions |
| B3 | Lichess, "Accuracy" page, https://lichess.org/page/accuracy | Win% and accuracy formulas, aggregation, limits |
| B4 | lila, `modules/puzzle/src/main/PuzzleFinisher.scala`, https://raw.githubusercontent.com/lichess-org/lila/master/modules/puzzle/src/main/PuzzleFinisher.scala | How an attempt updates player and puzzle ratings |
| B5 | lila, `ui/puzzle/src/ctrl.ts`, https://raw.githubusercontent.com/lichess-org/lila/master/ui/puzzle/src/ctrl.ts | First wrong move sends a failure; hints void rating; streak mode |
| B6 | Lichess FAQ, https://lichess.org/faq | Glicko-2, provisional rule (deviation over 110), warning against comparing ratings across organisations |
| B7 | ornicar/lichess-puzzler README, https://github.com/ornicar/lichess-puzzler | How candidates are generated and reviewed (no thresholds) |
| B8 | lila, `translation/source/learn.xml`, https://raw.githubusercontent.com/lichess-org/lila/master/translation/source/learn.xml (the page https://lichess.org/learn returned only its title) | Stages of the lichess interactive "Learn" path |

## C. chess.com and comparisons

| Tag | Source | Used for |
|---|---|---|
| C1 | Chess.com Help Center, "How are moves classified? What is a 'blunder' or 'brilliant,' etc.?" (Classification V2, dated Feb 9, 2026), https://support.chess.com/en/articles/8572705-how-are-moves-classified-what-is-a-blunder-or-brilliant-etc | Expected Points model, threshold table, Great/Brilliant/Miss rules |
| C2 | Chess.com announcement "New Classification System in Game Review" (10 Nov 2022), https://www.chess.com/announcements/view/new-classification-system-in-game-review | Earlier Blunder rule, introduction of Miss |
| C3 | Chess.com Help Center, "How is accuracy in analysis determined?", https://support.chess.com/en/articles/8708970-how-is-accuracy-in-analysis-determined | Accuracy definition, CAPS to CAPS2, typical range |
| C4 | Chess.com Help Center, "How is game rating calculated in Game Review?", https://support.chess.com/en/articles/10773754-how-is-game-rating-calculated-in-game-review | Game Rating description and caveats |
| C5 | Chess.com Help Center, "Ratings on Chess.com", https://support.chess.com/en/articles/8566476-how-do-ratings-work-on-chess-com | Glicko, RD, new-account and new-time-class starting ratings |
| C6 | Chess.com Help Center, "Why are there different ratings in Live Chess?", https://support.chess.com/en/articles/8705367-why-are-there-different-ratings-in-live-chess | Bullet/Blitz/Rapid definitions, 40-move total-time rule |
| C7 | Chess.com, "Time Controls" (terms), https://www.chess.com/terms/chess-time-controls | Glossary wording "longer than ten minutes" (conflicts with C6, C8) |
| C8 | Chess.com, "Rapid Chess" (terms), https://www.chess.com/terms/rapid-chess | Glossary wording "10 minutes or more"; FIDE definition |
| C9 | Chess.com forum, "How does chess.com decide initial ratings?", https://www.chess.com/forum/view/community/how-does-chess-com-decide-initial-ratings (posts of Feb 2021 and Dec 2022; forum, not official) | Signup skill levels 400/800/1200/1600/2000, 5-game display rule |
| C10 | Chess.com Help Center, "How do lessons work?", https://support.chess.com/en/articles/8609703-how-do-lessons-work | Learn Path, levels, tiles, library, free versus paid |
| C11 | Chess.com Help Center, "What is my Learning Rank?", https://support.chess.com/en/articles/8652811-what-is-my-learning-rank | Points per lesson and rank thresholds |
| C12 | Chess.com Lessons library, https://www.chess.com/lessons | Tabs, filters, "Learn To Play" 12 lessons, 194 lessons in the first 25 courses |
| C13 | ChessGoals.com, "Chess Rating Comparison" (updated July 2026; fetched twice), https://chessgoals.com/rating-comparison/ | Third-party conversion tables, data kind, sample sizes, caveats |
| C14 | Chess.com forum, "Rapid Rating Percentiles", https://chess.com/forum/view/general/rapid-rating-percentiles (8 Jul 2023; user-collected) | User-collected percentile points |
| C15 | Chess.com forum, "Chess.com Rating Distribution", https://www.chess.com/forum/view/community/chess-com-rating-distribution (2023 and 2024 posts) | Average and median rapid rating claims |
| C16 | Chess.com forum, "TIL: 5 years ago, a 1000 rapid rating was 49th percentile. Today it's the 81st!", https://chess.com/forum/view/general/til-5-years-ago-a-1000-rapid-rating-was-49th-percentile-today-its-the-81st (Aug 2024) | Pool drift (user claim, method unclear) |
| C17 | Chess.com article "Chess.com Lessons vs Improvement: The Stats" (by an NM, data May to Nov 2019), https://www.chess.com/article/view/chess-lessons-improvement-stats | Six-month rating gains of under-1000 members versus lessons |
| C18 | Chess.com forum, "adult rating improvement: how far can one go?", https://www.chess.com/forum/view/general/adult-rating-improvement-how-far-can-one-go (Oct 2021; anecdotes) | Self-reported adult improvement numbers |
| C19 | Chess.com Rapid Leaderboard, https://www.chess.com/leaderboard/live/rapid | Fetched; returned no distribution data |

## D. Teaching methods and books

| Tag | Source | Used for |
|---|---|---|
| D1 | Stappenmethode (Brunia, van Wijgerden), English site home, https://www.stappenmethode.nl/en/ | Six steps, adoption, aim "top 700 of the Netherlands" |
| D2 | Same site, "workbooks" info page, https://www.stappenmethode.nl/en/info/workbooks | Workbook families (basic, extra, plus, mix, thinking ahead), the 80% criterion |
| D3 | Same site, FAQ, https://www.stappenmethode.nl/en/faq | "At least a year for the first step"; readiness to move on |
| D4 | Same site, step 1 page, https://www.stappenmethode.nl/en/material/step1 | Step 1 scope and book list (about 486 exercises) |
| D5 | Same site, step 2 page, https://www.stappenmethode.nl/en/material/step2 | Step 2 scope and exercise counts |
| D6 | Same site, step 3 page, https://www.stappenmethode.nl/en/material/step3 | Step 3 scope and counts |
| D7 | Same site, step 4 page, https://www.stappenmethode.nl/en/material/step4 | Step 4 scope and counts |
| D8 | Same site, step 5 page, https://www.stappenmethode.nl/en/material/step5 | Step 5 scope |
| D9 | Same site, step 6 page, https://www.stappenmethode.nl/en/material/step6 | Step 6 scope |
| D10 | Same site, examples page, https://www.stappenmethode.nl/en/examples | Fetched; almost no content (a test-environment note) |
| D11 | Dutch site home, https://www.stappenmethode.nl/nl/ | Confirms landing text; no diploma or mini-game text |
| D12 | Brunia and van Wijgerden, "Schach lernen: Handbuch für Schachtrainer, Stufe 1" (German edition of the Steps Method, sample pages, © Cor van Wijgerden), https://www.spielezar.ch/sonstiges/leseproben/stappenmethode/handbuch-fuer-schachtrainer-stufe-1.pdf (read from PDF, 16 sample pages) | Lesson list, lesson structure, teaching, practice and playing, workbook roles, three-question check, number of games |
| D13 | Chess.com forum "Step Methods", post by dannyhume, 25 Sep 2019, https://chess.com/forum/view/chess-equipment/step-methods | Uncited per-step rating ceilings (folklore) |
| D14 | Yusupov, "Revision & Exam 1: The Fundamentals" (Quality Chess), excerpt PDF hosted by New in Chess, https://www.newinchess.com/media/wysiwyg/product_pdf/7610.pdf (read from PDF, pages 1 to 8) | Contents (chapter categories), introduction, pass rule, working method |
| D15 | Yusupov, "Chess Evolution 1: The Fundamentals" (Quality Chess 2011), excerpt PDF hosted by New in Chess, https://www.newinchess.com/media/wysiwyg/product_pdf/Chess-Evolution-1-excerpt.pdf (read from PDF, 11 pages) | German original title (DWZ 1500), 24 chapters plus final test, chapter build, scoring box |
| D16 | Chess Tigers shop, Jussupow "Tigersprung auf DWZ 1800 Bd. 1" (4th ed. 2017), https://chess-tigers.de/en/products/jussupow-tigersprung-auf-dwz-1800-bd-1 | "DWZ 1500 to DWZ 1800 in three volumes"; "about 200-300 DWZ higher" |
| D17 | Chess.com blog "Don't Buy Yusupov's Books" (Opferschach; opinion), https://www.chess.com/blog/Opferschach/dont-buy-yusupovs-books | German titles 1500/1800/2100 DWZ; critique (opinion only) |
| D18 | Dan Heisman, articles index, https://www.danheisman.com/articles--blogs.html | Article titles, Novice Nook availability note |
| D19 | Dan Heisman, "Everyone's 2nd Chess Book", https://www.danheisman.com/everyones-2nd-chess-book.html | Subtitle, suggested rating range 800-1700 |
| D20 | Dan Heisman, "Finding Safe Moves", https://www.danheisman.com/finding-safe-moves.html | Safety method, study split, time controls |
| D21 | Dan Heisman, "Definitions", https://www.danheisman.com/definitions.html | Hope Chess, Real Chess, Counting, Sanity Check, Seeds of Tactical Destruction |
| D22 | Dan Heisman, "Find Slow Chess on Chess.com", https://www.danheisman.com/find-slow-chess-on-chesscom.html | Slow-game recommendations and quotes |
| D23 | Dan Heisman, "Improve/Learn", https://www.danheisman.com/improvelearn.html | Practice, opponent strength, review quotes |
| D24 | Dan Heisman, "Get Better at Chess", https://www.danheisman.com/get-better-at-chess.html | Fetched; navigation list only |
| D25 | Mongoose Press, "Everyone's Second Chess Book" (2018, ISBN 978-1936277841), https://mongoosepress.com/product/everyones-second-chess-book/ | Publisher, page count, audience, topics |
| D26 | Chess.com article "Q&A with Coach Heisman, Aug 8, 2014", https://www.chess.com/article/view/qampa-with-coach-heisman-aug-8-2014 | "Is it safe?", counting, slow games, stuck at 1700 |
| D27 | Wikipedia, "Irving Chernev", https://en.wikipedia.org/wiki/Irving_Chernev | Logical Chess: Move by Move, 1957, 33 games 1889 to 1952 |
| D28 | Batsford, product page for Logical Chess: Move by Move, https://www.batsfordbooks.com/1454129 | Publisher description (every move explained, 33 complete games) |
| D29 | Rizzoli USA listing of the Batsford edition, https://www.rizzoliusa.com/book/9781837330560 | Page count and publisher description (retailer) |
| D30 | Wikipedia, "Yasser Seirawan", https://en.wikipedia.org/wiki/Yasser_Seirawan | Winning Chess series titles and publishers |
| D31 | Chess.com article "Book Review: Play Winning Chess" (menofsticks, updated 21 Jul 2008; a reader review), https://www.chess.com/article/view/book-review-play-winning-chess | Force, Time, Space, Pawn Structure; book structure |
| D32 | Silman-James Press catalogue page, "Silman's Complete Endgame Course", https://www.silmanjamespress.com/catalogs/silmans-complete-endgame-course | Publisher description, 528 pages, rating-group division |
| D33 | Library of Congress, table of contents for "Silman's complete endgame course" (CIP, 2006037884), https://catdir.loc.gov/catdir/toc/ecip076/2006037884.html (condensed by the fetch tool) | Parts by rating class with topics |
| D34 | Hachette Book Group, Polgár "Chess: 5334 Problems, Combinations and Games" (Black Dog & Leventhal), https://www.hachettebookgroup.com/titles/laszlo-polgar/chess-5334-problems-combinations-and-games/9781579125547/ | Problem counts by type, structure, audience |
| D35 | Forward Chess blog, "What is the Woodpecker Method?" (retailer), https://forwardchess.com/blog/what-is-the-woodpecker-method/ | Method description, Tikkanen's account |
| D36 | Chessable blog on Chess.com, "The Woodpecker Method Explained" (marketing), https://www.chess.com/blog/Chessable/the-woodpecker-method-explained-turbocharge-your-tactical-and-strategic-vision | Cycle schedule, claims, unsourced research figures |
| D37 | Caissa Chess listing for The Woodpecker Method, https://www.caissa-chess.com/tactic/-the-woodpecker-method-by-axel-smith-hans-tikkanen-k-5426-9781784830557-1079 | "over 1100 puzzles and solutions"; method sentence (retailer) |

## E. Peer-reviewed science, models and tools

| Tag | Source | Used for |
|---|---|---|
| E1 | Charness, Tuffiash, Krampe, Reingold, Vasyukova (2005), "The role of deliberate practice in chess expertise", Applied Cognitive Psychology 19(2):151-165, doi 10.1002/acp.1106; abstract via OpenAlex https://api.openalex.org/works/doi:10.1002/acp.1106 | Study as strongest predictor, 40% of variance, 5,000 hours |
| E2 | Gobet and Campitelli (2007), "The role of domain-specific practice, handedness, and starting age in chess", Developmental Psychology 43(1):159-172, doi 10.1037/0012-1649.43.1.159, PMID 17201516; Europe PMC https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=DOI:10.1037/0012-1649.43.1.159&format=json&resultType=core | N=104, 8 times practice ratio, starting age |
| E3 | Same paper via OpenAlex, https://api.openalex.org/works/doi:10.1037/0012-1649.43.1.159 | Cross-check of E2 |
| E4 | Campitelli and Gobet (2011), "Deliberate practice: Necessary but not sufficient", Current Directions in Psychological Science 20(5):280-285, doi 10.1177/0963721411421922; OpenAlex https://api.openalex.org/works/doi:10.1177/0963721411421922 | Necessary not sufficient; 3,000 hours |
| E5 | Ericsson, Krampe, Tesch-Römer (1993), "The role of deliberate practice in the acquisition of expert performance", Psychological Review 100(3):363-406, doi 10.1037/0033-295X.100.3.363; OpenAlex https://api.openalex.org/works/doi:10.1037/0033-295X.100.3.363 | Framework abstract |
| E6 | Hambrick, Oswald, Altmann, Meinz, Gobet, Campitelli (2014), "Deliberate practice: Is that all it takes to become an expert?", Intelligence 45:34-45, doi 10.1016/j.intell.2013.04.001; full text read from PDF (pages 1 to 6) at https://www.gwern.net/doc/psychology/chess/2014-hambrick.pdf; metadata also from Crossref https://api.crossref.org/works/10.1016/j.intell.2013.04.001 and LSE https://researchonline.lse.ac.uk/id/eprint/102316 | 34% of variance, hours by skill group, Table 1 study list, Polgár sisters |
| E7 | Burgoyne, Sala, Gobet, Macnamara, Campitelli, Hambrick (2016), "The relationship between cognitive ability and chess skill: A comprehensive meta-analysis", Intelligence 59:72-83, doi 10.1016/j.intell.2016.08.002; LSE record https://researchonline.lse.ac.uk/id/eprint/102241 (the 2018 corrigendum is from a search snippet only) | Correlations by ability, age and rank |
| E8 | Chase and Simon (1973), "Perception in chess", Cognitive Psychology 4(1):55-81, doi 10.1016/0010-0285(73)90004-2; first two pages read from PDF at https://gwern.net/doc/psychology/chess/1973-chase.pdf | Chunking abstract; de Groot's findings as summarised there |
| E9 | Gobet and Simon (1996), "Templates in chess memory: A mechanism for recalling several boards", Cognitive Psychology 31(1):1-40, doi 10.1006/cogp.1996.0011; Brunel repository record https://bura.brunel.ac.uk/handle/2438/1339 | Recall of several boards, templates |
| E10 | Wikipedia, "Adriaan de Groot", https://en.wikipedia.org/wiki/Adriaan_de_Groot | Four stages of move choice; Thought and Choice in Chess |
| E11 | Roediger and Karpicke (2006), "Test-enhanced learning: Taking memory tests improves long-term retention", Psychological Science 17(3):249-255, doi 10.1111/j.1467-9280.2006.01693.x; OpenAlex https://api.openalex.org/works/doi:10.1111/j.1467-9280.2006.01693.x | Testing effect |
| E12 | Cepeda, Pashler, Vul, Wixted, Rohrer (2006), "Distributed practice in verbal recall tasks: A review and quantitative synthesis", Psychological Bulletin 132(3):354-380, doi 10.1037/0033-2909.132.3.354; OpenAlex https://api.openalex.org/works/doi:10.1037/0033-2909.132.3.354 | Meta-analysis counts, optimal gap |
| E13 | Cepeda, Vul, Rohrer, Wixted, Pashler (2008), "Spacing effects in learning: A temporal ridgeline of optimal retention", Psychological Science 19(11):1095-1102, doi 10.1111/j.1467-9280.2008.02209.x; OpenAlex https://api.openalex.org/works/doi:10.1111/j.1467-9280.2008.02209.x | Optimal gap as a share of delay |
| E14 | Rohrer and Taylor (2007), "The shuffling of mathematics problems improves learning", Instructional Science 35(6):481-498, doi 10.1007/s11251-007-9015-8; USF repository https://digitalcommons.usf.edu/psy_facpub/1767/ | Mixed versus blocked and spaced versus massed |
| E15 | Anderson, Kleinberg, Mullainathan (2016), "Assessing Human Error Against a Benchmark of Perfection", KDD '16, doi 10.1145/2939672.2939803; arXiv abstract page https://arxiv.org/abs/1606.04956 | Abstract, venue |
| E16 | Same paper, full text read from PDF (pages 1 to 9), https://arxiv.org/pdf/1606.04956 | Data sizes, blunder definition, prediction accuracies, skill/time/difficulty findings |
| E17 | McIlroy-Young, Sen, Kleinberg, Anderson (2020), "Aligning Superhuman AI with Human Behavior: Chess as a Model System", KDD '20, doi 10.1145/3394486.3403219; arXiv https://arxiv.org/abs/2006.01855 | Maia abstract |
| E18 | Maia Chess project site, https://www.maiachess.com/ | Maia, Maia-2, Maia-3; lichess bots and ratings |
| E19 | CSSLab/maia-chess README, https://github.com/CSSLab/maia-chess | Nine models 1100-1900, training data, Lc0 usage, GPL-3.0 |
| E20 | Howard (2012; online 2011), "Longitudinal effects of different types of practice on the development of chess expertise", Applied Cognitive Psychology 26(3):359-369, doi 10.1002/acp.1834; OpenAlex https://api.openalex.org/works/doi:10.1002/acp.1834 | Games, study hours and coaching over 7 years |
| E21 | Howard (2014), "Learning curves in highly skilled chess players", Acta Psychologica 151:16-23, doi 10.1016/j.actpsy.2014.05.013; Europe PMC (PMID 24915472) | Read; not cited in the digest (grandmaster-level sample) |
| E22 | Roring and Charness (2007), "A multilevel model analysis of expertise in chess across the life span", Psychology and Aging 22(2):291-299, doi 10.1037/0882-7974.22.2.291; OpenAlex https://api.openalex.org/works/doi:10.1037/0882-7974.22.2.291 | N=5,011 elite players, peak age |
| E23 | Vaci, Edelsbrunner, Stern, Neubauer, Bilalić, Grabner (2019), "The joint influence of intelligence and practice on skill development throughout the life span", PNAS 116(37):18363-18369, doi 10.1073/pnas.1819086116, PMID 31451633; Europe PMC | Intelligence and practice interact |

## F. Improvement-rate data

| Tag | Source | Used for |
|---|---|---|
| F1 | jcw024, "lichess_database_ETL" README (one author; 2.3 million players, 450 million games, blitz), https://github.com/jcw024/lichess_database_ETL/blob/main/README.md | Rating-gain timelines by band, distribution, outliers, caveats |

## Fetched but returned nothing usable (not relied on)
- https://github.com/official-stockfish/Stockfish/wiki/UCI-&-Commands (empty "create page" form; replaced by A1).
- OpenAlex records without abstracts: Hambrick 2014, Burgoyne 2016, Chase and Simon 1973, Gobet and Simon 1996, Rohrer and Taylor 2007 (other records were used instead, see E6 to E9, E14); Europe PMC returned no record for Chase and Simon 1973 or Charness 2005.
- https://www.caissa-chess.com/index.php?controller=attachment&id_attachment=282 (Woodpecker sample PDF, 0 bytes).
- https://api.openalex.org/works?search=... queries (used only to find DOIs); https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=... topic search (only to find Vaci 2019 and Howard 2014).
- Blocked or rate limited: qualitychess.co.uk (403), newinchess.com product pages (403/404), simonandschuster (403), chess.co.uk (429), chess-tigers.de (429 on later tries; one page fetched), shop.chessbase.in (429), lichess blogs by smach and NoelStuder (403), Semantic Scholar API (429), PubMed search (cookie wall), sciencedirect.com (403), pmc.ncbi.nlm.nih.gov (browser check), the Rohrer personal PDF (connection refused), bedfordnhlibrary.org and bemis2.marmot.org records (403), the Stappenmethode Dutch FAQ (404), github.com/lichess-org/lichess-puzzler (404).

## Seen only in search-result summaries (snippet only; pages not fetched; marked in the digest)
- Barnes and Noble contents line "Learning, Chunking, and Chess Mistakes"; Thinkers' Press 2005 second edition of Heisman's book; Jonathan Rowson's "The Seven Deadly Chess Sins" (Gambit, 2000); Burgoyne corrigendum (2018); a lichess blog giving Steps rating ceilings; "99.5 percent at 1801" on a chess.com forum; the claim that Chess.com bots use the Komodo engine; the older "60s+0.6s" UCI_Elo wording on a README mirror; the lichess commit "update fishnet elo estimates".
