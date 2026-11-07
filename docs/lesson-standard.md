# The lesson standard (standard 2)

Every lesson, Part 1 and Part 2, is written to this page. `lib/lessons.py` holds a lesson marked
`standard: 2` to every rule below that a program can check; a fresh-context review (opus) checks the
rest before a lesson ships. The owner's words: inbox S18 to S21, S24, S25 (7 Nov 2026).

## Who it is for
A slow, careful learner who learns from examples and practice and stops at any word nobody defined.
So: easy to follow, hard to answer. Every step is spelled out; the thinking is the challenge.

## A lesson, in its order
| Section | What it holds | Checked by the parser |
|---|---|---|
| `remember` | a warm-up from a lesson before: 1 or 2 questions | one ```` ```quiz ```` (q:/a:); required when `needs` is set |
| `example` | a small working example first, then what it printed | code fence(s), then ```` ```output ````; 80 words of prose |
| `idea` | the one new idea, explained from the example | 200 words; ```` ```term NAME ```` boxes |
| `exercise` | Warm-up, Real, Stretch: a paragraph each, every step spelled out (which window, which key, what to type, what he sees) | the three in order; exactly two ```` ```hint ```` fences (a nudge, a bigger one: the answer is the third layer); 250 words |
| `check` | what is true when it is learnt (a run or an ask: as standard 1) | as standard 1 |
| `answer` | the steps that make a run check pass | as standard 1 |
| `behind` | Behind the scenes: what really happens, a drawing, a peek with a real tool | a ```` ```picture ```` and a ```` ```peek ````; 150 words |
| `mistakes` | the common mistakes box | 1 to 4 lines, each `- ` |
| `quiz` | the 3-question check | one ```` ```quiz ````, exactly 3 pairs |
| `next` | one line on what comes next | one line, 30 words |
| `checked` | the primary docs it was checked against, with versions | lines `- DOC, VERSION: URL` |

## Rules of the words
- **One idea per lesson.** Tiny steps. Earlier ideas come back in `remember` and in the exercises (interleaving).
- **2 parts doing, 1 part reading.** The prose of example, idea, behind and mistakes is read at
  150 words a minute and may take a third of the lesson's minutes at most (13 minutes: 650 words).
- **Short sentences:** 25 words at most each. No jargon chains.
- **Every term defined** the first time it appears in the lesson, in a box: ```` ```term venv ```` with
  one line, "a private folder of Python packages for one project" (100 columns at most). A word has
  one meaning in the whole course: the glossary (`load()["glossary"]`) is collected from the boxes,
  and a second, different definition is refused.
- **Keys are keycaps:** written `[[Super+R]]`, drawn as the keycaps of h2 (S2, S25). A bare
  `Super+…`, `Ctrl+…`, `Alt+…`, `Shift+…` in prose is refused.
- **Real, relatable examples:** his folders, his notes, his books, his desktop.
- **Puzzles that make him think:** predict the output before running it, find the bug, fill in the
  missing line, choose between two designs and say why.
- **Never "…"**: cut at a word, or fit (as everywhere).
- **Accurate to the dot:** every fact from the current primary docs (November 2026), named in
  `checked`; every code example is run by the test suite with its expected output (sb04).

## The page (sb02b builds it; S21)
Lessons open as a calm local page (offline, in Helium, launched by kawa-learn), pictures, code and
exercises together. Nothing in the page's look may distract:
- a text column of 66 characters, line height 1.6, body 20/32 px in Noto Sans (the UI sans; 20 not 19 so
  1.6 lands on the grid), code 16/24 in Sumi Term; everything on one 4 px grid; 48 px between sections;
- the theme's soft contrast in both moods (never pure black on pure white, no glaring accent);
  every text/background pair WCAG AA at least (4.5:1 body, 3:1 large), measured by the build;
- pictures (SVG) in the theme's muted inks, one idea each, only where they teach; step-by-step
  pictures advance on a click or a key, never by themselves; `prefers-reduced-motion` honoured;
- the dojo rank and streak (sb03) quiet in a corner or on their own page, never in the lesson's way.

Built: `lib/lessonpage.py` renders it, `tools/build-themes.py` writes the sheet
(`~/.local/share/fedokawaii/learn/lesson.css`, both moods) and stops if a text pair falls under AA;
`kawa-learn --page [ID]` (or `p` on the day) writes `~/.cache/fedokawaii/learn/ID.html` and opens it in
Helium. A step picture is an ```` ```picture ```` holding `<svg>`, its parts `data-step="N"`, its inks the
classes `ink`, `soft`, `line`, `mark`; the rank and streak stay on kawa-learn's own pages (a, r).

## The learning science it follows
- Worked examples first, then the help fades (Sweller & Cooper 1985; Renkl & Atkinson 2003).
- Retrieval practice: the remember warm-up and the quiz (Roediger & Karpicke 2006).
- Spaced review after 1, 3, 7 and 14 days (Cepeda et al. 2006): sb03's daily review.
- Words and pictures together, one idea per picture (Mayer, *Multimedia Learning*).
