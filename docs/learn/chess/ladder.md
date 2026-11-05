# The ladder: what a level is

A level in kawa-chess is a place on one scale, measured here, engine against engine, with the settings the app uses.
`tools/chess-ladder.py A B GAMES` plays the two levels against each other, colours by turns, two random plies a side first
so no two games are alike; the score gives the gap. **These are not chess.com ratings, and no one can convert them:**
Stockfish's own FAQ says a human scale cannot be claimed for it, and its UCI_Elo is a fit against other engines (CCRL blitz,
anchored on the Stash engine). The one measure that says what you are on chess.com is chess.com.

## Below 1320: a lot drawn among Stockfish's moves

Depth-1 search of every root move, then a choice weighted by how good each move is (temperature in centipawns), and with some
chance any legal move at all. The flatter the draw, the more pieces hung and mates missed, as a beginner does.

Measured 4 Nov 2026 (Stockfish 19, Fedora's; 200 games each pair):

| temperature | any legal move | ahead of the row above |
|---|---|---|
| none (any legal move) | 100 % | |
| 1500 | 30 % | +26 |
| 800 | 20 % | +33 |
| 500 | 15 % | +49 |
| 350 | 10 % | +44 |
| 250 | 7 % | +69 |
| 180 | 5 % | +98 |
| 130 | 3 % | +145 |
| 90 | 2 % | +171 |
| 60 | 1 % | +145 |
| 40 | 0 | +139 |

Against Stockfish's own floor (UCI_Elo 1320, 30,000 nodes): temperature 90: 13.5 of 200 (−456); 60: 52.5 of 200 (−179);
40: 102 of 200 (+7, the same strength). Temperature 40 is therefore where the two scales meet.

Then the levels as they are named in `engine.py`, checked again with 300 games a pair:

| levels (first table's names) | gap measured | named gap |
|---|---|---|
| 300 → 450 | +153 | 150 |
| 450 → 600 | +109 | 150 |
| 600 → 800 | +163 | 200 |
| 800 → 1000 | +166 | 200 |
| 1000 → 1200 | +167 | 200 |
| 1200 → 1320 | +115 | 120 |

so the levels were renamed from those numbers, counting down from 1320: the random mover is level 440.

## From 1320: Stockfish's own limit

`UCI_LimitStrength` and `UCI_Elo`, on a budget of nodes rather than time, so that a busy machine does not change the strength
(30,000 nodes; 200,000 above UCI_Elo 2200; a million above 2600). Stockfish calibrates UCI_Elo at 120 s + 1 s; at these budgets
200 games a pair gave:

| UCI_Elo | gap | level (`uci_elo()` inverts this) |
|---|---|---|
| 1320 | | 1320 |
| 1500 | +191 | 1511 |
| 1700 | +145 | 1656 |
| 1900 | +121 | 1777 |
| 2100 | +133 | 1910 |
| 2300 | +143 | 2053 |

The error of a 200-game gap is around ±40. A stronger or newer Stockfish moves all of this: `tools/chess-ladder.py` measures it again.

## Where 1800 on chess.com might be

Only rough outside points exist (research digest, sections A4 and C6): chess.com rapid 1800 is about FIDE 1820–1865
(ChessGoals' survey, wide error); "UCI_Elo 1500" has been put at FIDE 1539 (a forum post measuring through Maia) and at FIDE 1890
(another, with no data). So the plan's last mark, level 1800, is a guess with a wide margin, and that is why week 52 sends you to
chess.com to find out.
