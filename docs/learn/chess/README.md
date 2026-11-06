# Chess: the piece of the Learn book that belongs here

`kawa-chess` is a whole course in one terminal window: Super+U → learning → chess, or the launcher. It opens on today.

## The day

One row after another; Enter does the next one, and it remembers everything if you stop halfway (a kill or a power cut
loses at most the move in your hand).

- **A lesson**, on its first days of the week: a few pages, a position and few words, moves you must find, puzzles of its
  theme. Five minutes.
- **The deep game.** A whole game on a long clock, with one goal (it is written above the clock). Twenty-five minutes.
- **Its review.** First you say which of your moves you would take back. Then the three moments that cost most: you find
  the move, then you are shown it and why. Then you write down one thing to remember.
- **Ten minutes of puzzles.** From Lichess's database, around your rating; what you miss comes back on the first, third,
  seventh and twenty-first day after.
- **The light game.** A set position, a line of your opening, or a tactic to find and play out. Short clock.
- **Its review.**

On the seventh day of a week there is a report; every fourth week an exam: twenty puzzles, sixteen to pass. If you do not
pass, the plan waits for you: try again another day, with new puzzles. A few endgames (king and queen, king and rook, the
Lucena, the Philidor) are the same: the plan goes on when you have done them.

## On the board

Type moves: `Nf3`, `exd5`, `O-O`; lower case and no `x` are fine (`nf3`, `ed5`, `oo`). A piece and the squares it can reach
light up as you type. Or click, or drag, or use the arrows and Enter. `?` is a hint if the game allows one: the lantern on the
piece, again for the arrow. `t` turns the marks on your pieces in danger on or off. Esc lets go of what is in your hand;
then it opens the game's menu: a hint, turn the board round, offer a draw, resign, leave and come back later.

Super+/ shows all of this while chess is in front.

## The levels, and what the numbers mean

Your opponents sit on a ladder from a tree spirit (kodama) past a wandering ronin and a warrior monk to the shogun. A level is this program's
own number: Stockfish's own limit from 1320 up, and below that a drawn lot among its moves, measured engine against engine
(`ladder.md`). **It is not a chess.com rating.** Nothing can honestly convert it. The level follows your results, so you
should score about half; test games are a level above.

The goal is 1800 in chess.com's rapid in a year. Be clear about that: nothing on record shows an adult going from zero to
1800 in twelve months, and the research (`.claude/notes/chess-research.md`, section F) puts a consistent learner much
lower. The plan is built to try; the progress tab draws your line against the plan's and says where your own pace points.
The only true measure is chess.com at the end. Play there when week 52 says so.

## What is kept, and where

- `~/.local/state/fedokawaii/chess/`: your progress and the game in hand (`progress.json`, `current.json`), every game as
  PGN and what you wrote about it. A file cut short is replaced by its last good copy. It is in the backups with the rest.
- `~/.local/share/fedokawaii/chess/`: the lessons, the puzzles, the drawings of the board. Installed, never changed.
- `~/.local/lib/fedokawaii/kawa-chess/`: the program.

Stockfish is Fedora's package. It runs only while it is needed: for your opponent's move, and for the review, and goes away
at once after that.

## Why it is built this way

Every choice has its source in `SOURCES.md` and the argument in `.claude/notes/chess-research.md`. In one line each:
the three questions and the slow games are Heisman's and the Steps Method's; the 80 % exams are the Steps Method's; the
endings follow Silman's order by rating class; the puzzles and their rating are Lichess's (CC0, Glicko-2); moves are scored
by chess.com's published expected-points steps with Lichess's published win-chance formula; first your own judgement, then
the engine's, because what you have to recall you keep (Roediger and Karpicke 2006).
