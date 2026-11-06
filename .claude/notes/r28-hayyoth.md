# Hayyoth: design and work philosophy (r28 f17, 6 Nov 2026)

Who: "The guardian of the craft of manual programming": a programmer's YouTube channel, active
since at least 15 Oct 2026, hand-coding in C, plain JS and HTML with no AI. Their timeline: self-taught,
corporate IT, software freedom, independent, farming for control of their time, AI, then the
decision not to let the algorithm set their direction.

Read: hayyoth.org and its white paper (both whole), the Hayyoth Lab README's opening, the channel's video
list, ten video titles with their descriptions. **Not heard:** the videos have no captions and no
speech-to-text is installed here, so nothing below rests on what is said inside a video. One Tildes
thread gave a viewer's reading, marked below.

## What they hold
- **Your work shows who you are.** "Your website is your soul, it must reflect your personality."
  ("Pure HTML just works and beats AI Slop") AI-made pages lose because they look like everything else.
- **Simple, and doing its job.** "Content and accessibility are key; keep your website extremely
  simple and ensure it performs its intended function." (same) A viewer's reading (Tildes): use
  complexity only when it is needed, not because it became the standard. Their own page practises it: 3.5 KB,
  no script, one CSS rule (table borders).
- **Simple state + simple rules = emergence.** Hayyoth Lab: "You define a state and the rules that
  transform it", "You build the machine, run it, and see what emerges." Small C, 15 fps Game of Life
  in a page of code.
- **Learn from zero.** "start from zero (scratch) / no abstraction / make everything simplicity"
  ("How we (Human) learn better than AI?"). The practice: `ed` in 100 lines, `tree`, the Linux file
  utilities, a hash table, all rebuilt by hand. Flat over layered ("If everything is Flat, you can't go wrong").
- **One step, then look.** White paper IV: "I need only to make the next step, observe its
  consequence, and continue from there." "the road still has to be travelled one state at a time."
- **Coding as calm.** "Programming is the manual craft I love the most"; "just pure JS hand coding to relax".
- **A real record.** "pure HTML with history" ("What AI cannot fake"); their home page is a dated
  table of what they chased and what they quit, ending "Quit quitting." Their tagline: "Understand the
  Game. Don't Play It Blindly."
- **Keep a door for being wrong.** White paper I: "Believe, but remember you may be wrong."
- Not anti-tech: "I've used AI from day one... I took an extreme path to prove a point: No AI."

## What fits, and where it went (decided)
1. **Alive by a rule**, `docs/design-system.md` §11: a long-running living thing is a small state stepped
   by a small rule, not a long drawn loop. It suits "alive, never boring" at almost no cost, and it never repeats exactly.
2. **Could it be anybody's?**, §15 item 11: the soul test, the same thing as "a world, not a theme".
3. **Take it away**, §15 item 12: every part must earn its place by doing the surface's job.
4. **Learning** (row f25, note added): their way suits the owner's "small daily consistent effort" and
   slow, tiny steps. Part 2's exercises rebuild a small real tool from zero by hand in Python, then Rust
   (their `tree` and `ed` are the model; the languages stay the owner's). Each lesson is one step, then
   its check. The progress view is a real dated record of days done, never a score.

## What does not fit
- **No AI, by hand only:** a stance for their own craft. This desktop is built with Claude at the owner's request.
  The lessons take the hand-coding, not the ban.
- **The unstyled look:** their bare HTML says "simple"; ours is an artwork. The root is shared, the surface is not.
- **The white paper's metaphysics and its language of spells:** their own world, not ours to borrow.
  No quotes of theirs on the desktop.
- **Audible key sounds** (a viewer rebuilt their keyboard's sound as a pack): a one-person desk needs no such
  thing; not proposed.

## Sources (6 Nov 2026)
https://hayyoth.org · https://hayyoth.org/white-paper · https://www.youtube.com/@hayyoth-org ·
https://codeberg.org/hayyoth/hayyoth-lab · https://tildes.net/~tech/1wql/pure_html_just_works_and_beats_ai_slop ·
https://dev.to/christophervistal25/i-built-a-keyboard-sound-app-for-myself-and-fell-in-love-with-it-2dnj
