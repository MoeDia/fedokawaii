---
id: ask-iterate
title: ask it to ask you; iterate
part: ai
chapter: 68
minutes: 13
needs: [five-parts]
optional: no
---

## 68.3 ask it to ask you

For anything you have not fully thought through, turn it around:

```text
I want a small tool that reminds me to drink water. Before writing anything, ask me
the questions you need answered — the hard ones, not the obvious ones. Then write a
short spec to SPEC.md and wait for my yes.
```

It will ask what you had not decided: how it reminds you, how often, whether it pauses while you
are in a game, where it keeps its state. Your answers become a **spec** — the most valuable file
of a project done with AI, because it carries the decisions from one session to the next.

## 68.4 iterate on the request, not the result

When an answer is wrong, you can correct it ("no, the other file") or ask again from the start
with a better request. Two corrections in, start over: a context full of failed attempts pulls
the model back towards them (67.4). The better request has what you learnt in it:

```text
The last attempt edited the wrong function: the bug is in parse_date, not format_date.
It fails for dates written 2026-1-5 (no zero padding). Write a failing test for that
first, then fix parse_date, then run the tests.
```

## 68.5 questions are cheap; use them

Some of the best uses of a model change nothing at all:

- "Explain this function line by line, as to a beginner."
- "What are three ways to do this, and what does each cost?"
- "What would break if I changed this?"
- "Review this diff as a strict senior engineer would. Only real problems."
- "What did I not ask that I should have?"

Asking before you build is how you keep learning yourself — and how you catch a wrong plan
before it becomes a wrong program.

> **Checkpoint.** Take a request you made to an AI this week. Name its goal, context,
> constraints, done-when and form. Which were missing?

### exercises

**68.1 ★ Five parts.** Rewrite this request with all five parts, for a real file of yours:
*"make my script better"*.

*You should see:* a request whose done-when is something you can run.

<!-- solution 68.1 -->
```text
Goal: make ~/bin/backup.sh safe to run twice at once, so a timer and a manual run cannot
corrupt the archive.
Context: it is plain bash; it writes ~/Backups/home-DATE.tar.zst.
Constraints: no new tools beyond flock (util-linux); keep the archive's name and contents.
Done when: running it twice at once makes one archive and the second run says "already
running" and exits 1; `shellcheck ~/bin/backup.sh` is clean.
Form: the diff, then a two-line test I can paste to try both runs.
```
<!-- /solution -->

**68.2 ★★ Example versus description.** Ask for five commit messages for made-up changes, first
described ("short, present tense, area first"), then shown three real ones from `git log
--oneline` of `~/dojo/fedokawaii`. Compare.

*You should see:* the shown style matched far more closely than the described one (68.2).

<!-- solution 68.2 -->
("Add date validation to parser"). Shown three from `git log --oneline`, it copies their real
shape — the area, a colon, what the user now sees (`Parser: a date without zero padding reads
right`). One example carries length, grammar, tone and vocabulary at once.
<!-- /solution -->

**68.3 ★★ The interview.** Use the request of 68.3 for a tool you actually want. Answer its
questions; keep the `SPEC.md` it writes.

*You should see:* at least one question you had not thought of, and a spec you could hand to
someone else.

<!-- solution 68.3 -->
during a game or a video call? What counts as "drank" — a key, a click, nothing? What happens
after a sleep? Where does it keep its count, and should the count survive a reboot? How does it
stop?* A short spec from the answers:

```markdown
# sip — a water reminder
- every 45 min of active use (not idle, not fullscreen), a notice "sip ·  drink some water"
- clicking the notice records a glass; `sip status` prints today's count
- state in ~/.local/state/sip/YYYY-MM-DD; nothing kept over 30 days
- out of scope: sounds, charts, other drinks
- done when: a 1-minute test interval shows a notice, a click counts, `sip status` says 1
```
<!-- /solution -->
