# Typing: the research behind `kawa-typing` (T26a, 4 Nov 2026)

Every claim here was read in the source named, on 4 Nov 2026: PDFs through `pdftotext`, keybr and
Monkeytype in their repositories through the GitHub API. URLs: `docs/learn/typing/SOURCES.md`.
Numbers are quoted as the source gives them. Where the evidence is thin it says so.

## 1. How EdClub / TypingClub teaches (its own Teacher Handbook, "Typing Jungle")

The default lesson plan, read from the official handbook:

| section | lessons | min → goal wpm | what |
|---|---|---|---|
| home row | 1–23 | 3 → 10 | a s d f g h j k l ; — "feel for the bumps on the F & J keys … look up" |
| top row | 24–51 | 3 → 10 | diagonal reach up, every finger back home after each key |
| bottom row | 52–88 | 3 → 10 | z x c v b n m , . / |
| basic level 1 | 89–126 | 3–13 → 10–20 | simple sentences: whole alphabet, commas, periods, no capitals yet |
| tricky words 1 | 127–137 | 13 → 20 | commonly confused and misspelled words |
| shift | 138–191 | 3–10 → 10–20 | "use the opposite shift key from the hand being used" |
| common patterns 1 | 192–202 | 10 → 20 | the most frequent letter combinations: alone, then in words |
| basic level 2 | 203–233 | 11–20 → 21–30 | sentences with capitals and simple punctuation |
| tricky words 2 | 234–244 | 15 → 25 | |
| numbers | 245–274 | 3–15 → 10–25 | "travel" along the diagonals |
| common patterns 2 | 275–285 | 19 → 29 | |
| basic level 3 | 286–316 | 21–30 → 31–40 | capitals, punctuation, numbers |
| symbols | 317–346 | 3–10 → 10–25 | `$ & # * @ ( ! ) % ^` |
| common patterns 3 | 347–357 | 20 → 30 | |
| advanced level 1 | 358–388 | 25–30 → 41–45 | content-based passages, endurance |
| more symbols | 389–418 | 3–10 → 10–20 | `[ ] \ | - _ + = < > ~ ` ' " { }` |
| tricky words 3 | 419–429 | 20 → 30 | |
| advanced 2–9 | 430–684 | 31–50 → 46–75 | passages; "speed will come with time and practice" |

The order of keys (its 36-week syllabus): `fjkdsl` · `a;gh` · `rueiwo` · `qypt` · `vmc,` · `z/bn`
(with `x .`), then shift (FJDK · SLA:GHTY · RUEIWOQP · VMC?ZNXB), numbers `47` then `38291056`,
symbols. Two keys at a time, one from each hand, mirror fingers wherever it can.

What makes it quick, as far as the handbook shows:
- **Small steps.** 684 lessons in 36 weeks at its recommended "1 hour per week" is about 19 lessons
  an hour, 3 minutes each, retries and videos included. A new key costs almost nothing to meet.
- **A new key is met score-free**, with the finger named: "Paying proper attention to introducing
  new keys is paramount to adopting correct technique."
- **Stars, not a percent.** 5 stars out of each lesson. The glossary: "If the speed goal is reached
  along with the accuracy goal of 100%, all five stars are earned"; the perfect (platinum) score is
  "approximately 2.5 times the lesson's WPM goal with near perfect accuracy". The handbook repeats:
  "just passing the lesson isn't the real goal. Mastery equals 5 stars!"
- **Anchoring lessons**: one hand holds F or J down while the other types: "Trying to hunt and peck
  becomes very difficult". **Travel lessons**: diagonals, every finger through its home, top, bottom key.
- **Common patterns** (bigrams and trigrams alone, then in words) and **tricky words**.
- **Dynamic lessons**: "text … dynamically generated based on each student's weaknesses", at the end
  of the advanced section.
- **Results**: requirements beside performance, the mistyped characters, a playback of the attempt;
  a practice calendar "full of green squares", test results over time, strongest and weakest fingers.
- **Settings it offers**: virtual keyboard guide, hand guides ("beneficial, especially in the early
  lessons … When students reach advanced lessons, the guides can be disabled"), live WPM,
  "block on error(s)" after the 1st, 2nd or 3rd.
- **Its rules**: accuracy first; look at the screen; complete lessons in order; "short sessions".

## 2. keybr's adaptive letters (its source, AGPL: the idea is taken, not a line of code)

`packages/keybr-lesson/lib/guided.ts`, `target.ts`, `keybr-result/lib/keystats.ts`, `settings.ts`:
- Per key, a smoothed time-to-type (exponential filter, `makeFilter(0.1)`), and its best.
- **confidence = target time ÷ smoothed time**, the target speed by default 175 characters a minute
  (35 wpm), settable from 75 to 750.
- Letters in frequency order; it starts with 6; **a new letter comes only when every included
  letter has reached the target** (once, or now with `recoverKeys`).
- **The least confident included key is the focus**: the generated text leans on it.
- Text: real words from the letters allowed, topped up with pseudo-words from a phonetic model
  when fewer than 15 real ones exist.

## 3. How speed and accuracy are measured (decided before any code)

Monkeytype (`frontend/src/ts/test/test-logic.ts`, `test/events/stats.ts`, `utils/numbers.ts`):
- `calculateWpm(chars, seconds) = chars / 5 / (seconds / 60)`.
- **wpm** = `calculateWpm(correctWord, duration)`: characters of correct words, spaces included.
- **raw** = `calculateWpm(allCorrect + incorrect + extra, duration)`.
- **acc** = correct presses ÷ all presses that had a verdict (`getAccuracy`), corrected or not.
- **consistency** = `kogasa(stddev / mean)` of the raw speed second by second, where
  `kogasa(cov) = 100 × (1 − tanh(cov + cov³/3 + cov⁵/5))`.

Text-entry research (Soukoreff & MacKenzie, as restated by their successors; Dhakal 2018 uses "any
five characters", first keypress to last): `wpm = (|T| − 1) / seconds × 60 × 1/5`. The −1: the clock
starts on the first key, so the first key took no time.

**Ours, exactly** (in `metrics.py`, tested by a scripted typist):
- `time` — first press to last press; a pause of more than 5 s, or the window losing focus, stops
  the clock (Dhakal drops intervals over 5000 ms for the same reason). A timed test ends on its clock.
- `net wpm` — `(C − 1) / 5 / minutes`, C = characters standing correct when it ends, spaces included;
  in a free-flowing text, as Monkeytype, only those of whole correct words (the last word may be
  partial). The −1 keeps a short drill honest: a typist at a steady 120 ms a key measures 100.0 wpm
  over 20 characters or 2000. On a 60 s test it differs from Monkeytype's by 0.2 wpm at most.
- `raw wpm` — the same with every press that typed something, right or wrong.
- `accuracy` — correct presses ÷ all presses, Backspace not counted, corrected errors still errors
  (EdClub calls this "real accuracy"; Monkeytype's `acc`). A held key's auto-repeat is not a press.
- `consistency` — Monkeytype's formula on the raw speed per second.
- `rollover` — presses made while the previous key was still down ÷ all presses (Dhakal's rollover
  ratio). A terminal normally cannot see this. **foot can**: the Kitty keyboard protocol
  (`foot-ctlseqs(7)`: `CSI > flags u`, flags 1 + 2 + 4 + 8 + 16) reports presses, repeats, releases,
  each modifier by itself (so left shift from right), the base-layout key and the text.

## 4. What the studies say (and what each changes here)

**Dhakal, Feit, Kristensson, Oulasvirta 2018** (168,000 volunteers, 136 M keystrokes; Table 3):
mean 51.56 wpm (σ 20.20), fast group 89.56, slow 20.91. Inter-key 121.70 ms fast, 481.03 ms slow.
Corrections 3.40 % of presses fast, 9.05 % slow; uncorrected errors 0.71 % and 1.78 %. **Rollover
49.90 % fast, 7.60 % slow, r = 0.73 with wpm**: "the majority of fast typists use rollover for 40–70%
of keypresses". Keys overlap by about 30 ms. Different-hand pairs are the quick ones (108.62 ms
against 124.37 / 117.24 same-hand, fast group). Having taken a course: 54.35 against 49.00 wpm, d = 0.27.
→ Accuracy and speed go together: 97 % correct presses is stricter than the fast group's own average
(3.40 % corrected + 0.71 % left: roughly 96 %), and a fair bar for lessons. Rollover is measured and shown from the speed stages on,
never taught early. A course alone is no magic (d = 0.27): what is done with it matters.

**Feit, Weir, Oulasvirta 2016** (30 typists, 34–79 wpm, motion capture and eye tracking):
touch and self-taught typists reached like speeds (57.8 and 58.9 wpm). Touch typists looked at the
keyboard less (0.20 against 0.41 of the time) and used more fingers (8.54 against 6.24). Three
predictors of high performance: **one finger for each key, always** (low entropy), **preparing
upcoming keystrokes**, little global hand motion.
→ Consistent mapping is what the hands and the lit finger are for. Preparation needs preview: the
text always shows what comes next, and lines scroll before the caret reaches the end.

**Yechiam, Erev, Yehene, Gopher 2003** (22 students, *Human Factors* 45): touch-typing training does
not carry into everyday use by itself. Pretraining the visually guided speed was 18.4 wpm, touch 8.1;
the typist's old way wins for a long time, so people go back to it (**melioration**). Typing their own
homework with a mild secondary task (a blue square on screen to be answered by a key, the screen
darkening when missed) the group improved about 25 % more, 30 % at a 2-week delayed test (d = .81).
Touch typing is robust to nonwords where visual typing is not. Encouragement "should continue until
touch-typing performance in everyday typing tasks … exceeds" the old speed. They used a pacer: a
rabbit running from 8 to 36 wpm.
→ The first thing the app does is measure his present speed, however he types. **The crossover** —
touch typing passing it — is a milestone of its own. Pseudo-words stay in the drills (they cannot be
done by looking), real words and passages carry over to life. The watching eye (below) and the
pacer are taken from here. Their sample is small: a modest claim, and cheap to try.

**Baddeley & Longman 1978** (*Ergonomics* 21: postmen, alphanumeric code): one hour a day beat two
one-hour sessions, one two-hour, and most of all two two-hour sessions. Hours to learn the whole
keyboard: 34.9 at 1 × 1 h, 42.6 at 2 × 1 h, 43.2 at 1 × 2 h, and the slowest for 2 × 2 h ("the fastest subject
in this group is slower than the slowest" of 1 × 1 and 1 × 2). After a nominal 60 h: 79.3 correct keystrokes a
minute at 1 × 1 h, about 73 and 71 at the two middle schedules. About 30 % of the speed went after 1, 3 or
9 months unused. The 1 × 1 h group liked its schedule least and learned most.
→ A daily session, short; the app says when today's is done, and it feels slower than it is.
Everyday use afterwards matters: the skill decays if not used.

**Keith & Ericsson 2007** (60 everyday typists, mean 33.02 net wpm on meaningful text):
the best typists had both attended a typing class and **held the goal of typing fast in everyday
typing** (β .73 with a class, .15 without). Deliberate practice (Ericsson, Krampe, Tesch-Römer 1993):
focused, effortful, with feedback, aimed at what is weak.
→ Each lesson's goal stated, the weak keys named after each one, and the speed goal visible.

**Logan & Crump 2011; Crump & Logan 2010; Yamaguchi & Logan 2016**: skilled typing is two nested loops,
the outer deciding words, the inner running keystrokes in parallel; chunks form.
→ From the speed stages on, words and passages rather than letters.

**Salmoni, Schmidt & Walter 1984; Winstein & Schmidt 1990**: feedback given every time can become a
crutch; retention, not the session's score, shows learning. Not universal (2010, 2016 studies differ
by feedback type).
→ See the argument below.

**Not found**: the "type 10–20 % above your comfortable speed" figure often credited to Ericsson. No
primary source turned up, so it is not cited. The pacer's step is our own decision, stated as such.

## 5. Arguing with myself

**Accuracy first or speed first?** EdClub, the handbook's "accuracy first", Dhakal's fast group making
fewer errors, and the plan all say accuracy. Against: Keith & Ericsson's speed goal, and a typist who
never pushes settles. Answer: **both, in order**. Below the speed stages the bar is 97 % and the speed
bar is low (a minimum to rule out searching for keys). From the speed stages the 97 % stays and the goal
rises in steps of 5 wpm, with a pacer one step ahead. A lesson with 97 % but under the goal passes
without its top seals; under 97 % never passes, however fast.

**Block on error, or flow?** Blocking gives each key its correct response at once; real typing needs
noticing and Backspace. Answer: lessons up to the first sentences **block** (a wrong key does not move
on, it costs accuracy). From sentences on, **flow**: wrong letters stand, Backspace corrects, errors
count anyway. Timed tests flow, like Monkeytype's.

**The keyboard at all times against the guidance hypothesis.** He asked for it at all times, and EdClub
itself says the guides "can be disabled" late. A key lit ten times a second is a crutch and a flicker.
Answer: it is drawn at all times, always right, as he asked; the app never hides it, checks included.
One key (`k`) quietens the next key's light for the one who wants it (the keys stay, the held keys still
move), remembered until pressed again: his choice, never the app's. The transfer is carried by the
watching eye and measured by the crossover. Revisit with his data.

**Real words or pseudo-words?** Real words transfer, and fixed passages can be memorised; pseudo-words
force touch typing (Yechiam) but train nothing else. Answer: real words wherever the letters allow them,
always freshly drawn; pseudo-words only where too few words exist (the first keys, keybr's rule of 15).

**Daily minutes.** Baddeley's best was the shortest he tried, 1 h; nobody tested 20 min on this path, and
EdClub asks for 1 h a week. He also has 2 chess games and puzzles daily. Decided: 20 minutes a day, not
evidence but a fit; the meter fills and says so; he can go on.

**Is 100 wpm in a year honest?** The fast group's mean is 89.56 and the fastest of 168,000 typed about
120. Nobody published hours-to-100. So the app shows no promise: after two weeks it fits his own curve
(power law of practice) and draws its line toward 100.

**Is the course too long?** 309 lessons against EdClub's 684. Tricky words are left out (spelling is not
the goal), games too, the videos become a line or two. Nothing that moves speed is left out; the
adaptive practice replaces what the repetition of 684 lessons does.

**The watching eye.** Yechiam's blue square: cheap, supported by one small study, and it fits the world:
at random, every 40–60 s in the sentences stage, the demon's (or angel's) eye opens above the text: press
the key it names within 2 s, or the screen dims till you do. Off in checks and speed-measured runs.

## 6. What this desktop adds that no web course can

- Real press and release from foot: the keyboard on screen moves when the real one does, keys held show
  held, a real rollover ratio, an anchoring lesson that truly checks the finger stays down, the opposite
  shift really checked (left shift from right).
- His own keyboard drawn: the K617 Fizz's 60 % layout (Redragon: 61 keys, US QWERTY, full rollover).
- The world: the demon's hands on the dark, the angel's on the light; Wada's four papers as finger colours;
  a daily seal; passages from Okakura, Hearn and Nitobe, in English, public domain, chosen to be read.
