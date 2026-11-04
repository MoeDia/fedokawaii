# Typing: the course

From the keys of the home row to 100 words a minute and past it. `kawa-typing` builds every lesson from
this table (`course.py`); `kawa-typing --course` prints it, and `tests/content/test_typing.sh` holds the two
equal. Why it is this way: `.claude/notes/typing-research.md`. Sources: `SOURCES.md`.

## The measures

| measure | exactly |
|---|---|
| net wpm | `(C − 1) / 5 / minutes`: C the characters standing correct at the end, spaces included (flowing text: those of whole correct words) |
| raw wpm | the same, every press that typed something |
| accuracy | correct presses ÷ all presses. Backspace does not count; a corrected error stays an error. A held key's repeat is no press |
| consistency | `100 × (1 − tanh(c + c³/3 + c⁵/5))`, c = σ ÷ mean of the raw speed per second (Monkeytype's) |
| rollover | presses made while the previous key was still down ÷ all presses (Dhakal 2018) |
| time | first press to last. More than 5 s without a key, or the window out of focus, stops the clock |

## Passing

**Accuracy before speed.** Under 97 % a lesson is not passed, however fast. At 97 % or more the lesson is
passed if the speed reached its minimum, and it earns seals:

| seals | needs |
|---|---|
| 1 | accuracy ≥ 97 %, speed ≥ the minimum |
| 2 | speed ≥ ⅓ of the way from the minimum to the goal |
| 3 | speed ≥ ⅔ of the way |
| 4 | speed ≥ the goal |
| 5 | speed ≥ the goal, accuracy ≥ 99 % |
| the gold seal | speed ≥ 1.5 × the goal, accuracy 100 % |

A key's first lesson has no score. Failing costs nothing: the same lesson again, on fresh text.

## How it flows

**Today** is 20 minutes: `Enter` on the first row goes on where you stopped. A warm-up on your weakest keys, then
lessons, then, when the minutes are up, a one-minute test: the line you watch rise. Then it says so, and you may go
on. Short and daily beats long and rare (Baddeley & Longman 1978).

**The crossover**: the first thing the app asks for is one minute of plain words typed the way you type now.
That number stays on the progress page, until touch typing passes it. Before that day the old way feels
faster, and most people go back to it there (Yechiam 2003). Past that day it stops mattering.

**Block or flow.** Stages 1–3 and every key's lessons block: a wrong key does not move on. From the first
sentences on, the text flows: a wrong letter stands in red, Backspace corrects, the error still counts.

**Eyes up.** In sentences and passages an eye opens under the text every 40–60 s: press Tab within 2 s, or the text
dims and waits till you do. Looking at your hands is how you miss it (Yechiam 2003). Never in a check or a test.

## The stages

| # | stage | keys | lessons | min → goal wpm | mode |
|---|---|---|---|---|---|
| 1 | home row | `f j` · `d k` · `s l` · `a ;` · `g h` + space | 25 | 5 → 12 | block |
| 2 | top row | `r u` · `e i` · `w o` · `q p` · `t y` | 25 | 6 → 15 | block |
| 3 | bottom row | `v m` · `c ,` · `z /` · `b n` · `x .` | 26 | 8 → 18 | block |
| 4 | first sentences | the whole alphabet, comma, period, no capitals | 20 | 10–16 → 20–26 | flow |
| 5 | capitals | opposite shift: `FDSA` · `JKL:` · `GHTY` · `RUEI` · `WOQP` · `VMC?` · `ZNXB` · `' " -` | 30 | 8–12 → 20 | block, then flow |
| 6 | numbers | `4 7` · `3 8` · `2 9` · `1 0` · `5 6` | 21 | 5–10 → 20 | block, then flow |
| 7 | symbols | `$ &` · `# *` · `@ (` · `) !` · `% ^` | 18 | 5–8 → 18 | block, then flow |
| 8 | more symbols | `[ ]` · `\ \|` · `_ +` · `= <` · `> ~` · `` ` { `` · `}` | 24 | 5–8 → 18 | block, then flow |
| 9 | speed | passages, patterns, a pacer, a check, each 5 wpm from 30 to 110; real code after the bands of 40 · 50 · 60 · 70 · 80 | 132 | goal − 10 → goal | flow |
| | | **total** | **321** | | |

## A key's lessons (stages 1–3)

| kind | what | text |
|---|---|---|
| meet | the two new keys, finger named; no score | ~30 characters |
| drill | the two keys and space | ~60 |
| mix | the two keys among everything known | ~80 |
| words | real words holding them (pseudo-words only while fewer than 15 real ones exist) | ~100 |

Each stage ends with: **anchor** (one hand holds `f` or `j` down, the other types: lifting it stops the
text; home row and top row, one per hand) or **travel** (a column at a time, up and down through its home
key: bottom row), **review** ×2 (the stage's keys, the weakest most), and a **check** (one minute, words of
the stage, its goal).

## Capitals, numbers and symbols

Each group: meet · drill · words or lines that use them. Then a few sentences or real lines holding them all:
dates, prices, ports, paths, addresses, code. The shift pressed must be the opposite hand's (the keyboard
shows it); pressing the wrong one is said, and counted apart: not an accuracy error, a habit to fix.

## Speed (stage 9)

17 bands, 30 to 110 wpm. A band's six lessons: **passage** ×3 (Okakura, Hearn, Nitobe, as printed: longer and
harder as the bands rise, 200–500 characters) · **patterns** (the commonest pairs and triples, alone, then
in the words that hold them: the chunks of a fast typist) · **pacer** (a passage with a second caret running
at the goal; beat it to the end) · **check** (one minute, plain words, the band's goal at 97 %). After the bands
of 40, 50, 60, 70 and 80: six lessons of real code (bash · git · python · rust · c), goal 0.8 × the band.

Rollover is shown from here on, with its number from the fast typists of Dhakal 2018 (about half of the
presses). It is not taught: it comes.

## Milestones

| wpm | what it means |
|---|---|
| your old speed | the crossover |
| 50 | the average of 168,000 typists (Dhakal 2018: 51.56) |
| 75 | a trained typist of the older studies (Feit 2016, citing them) |
| 90 | the fast group's mean (89.56) |
| 100 | his goal |
| 120 | the fastest of that study |

No date is promised. After two weeks of practice the progress page fits a line to your own tests and shows
when it reaches 100; it moves with you.

## Outside the course

- **Practice**: adaptive. Each key's time and errors are kept (smoothed, α = 0.1, keybr's way). The text leans
  on the weakest keys and the slowest pairs. Always there, endless.
- **Test**: 15, 30 or 60 seconds, plain words, flowing, Monkeytype's measure.
- **Your own text**: `kawa-typing FILE` types a file: code, notes, anything.
