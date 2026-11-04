---
id: tokens
title: tokens and next-token prediction
part: ai
chapter: 67
minutes: 4
needs: [agents-moves]
optional: no
---

Tools change every few months. What makes someone good with them does not: knowing what a model
is and is not, giving it what it needs, checking what it gives back, and staying the author of
the work. This part teaches that first, and Claude Code with it. Chapters 67–69 are the ideas,
true of any model and any agent. Chapters 70–71 are Claude Code itself, from the daily loop to
your own hooks, skills and subagents. Chapter 72 is the craft: how professionals use all of it
on real projects, and how to keep learning when the tools move on. Every chapter ends with
exercises; appendix D has a worked answer for each.

> **Careful.** Commands and key names in chapters 70–71 are Claude Code's as of October 2026.
> If one has changed, `/help` inside Claude Code and the documentation (`code.claude.com/docs`)
> say what it is now. The ideas around them will not have changed.

> **In this chapter**
>
> - tokens, the context window and next-token prediction: the whole machine in three ideas
> - how a model is trained, and why that makes it good at some things and bad at others
> - hallucination: where it comes from, and the habits that catch it
>
> Chapter 45 (your own tiny transformer) helps, but is not needed.

Every habit in the rest of this part follows from how the machine works. Ten minutes here saves
you months of guessing why a model did something odd.

## 67.1 tokens

> **Word — token.** A piece of text the model reads and writes as one unit: a common word, part
> of a rarer word, a space, a punctuation mark. A model never sees letters; it sees tokens.

A rough guide for English: a token is about three quarters of a word, so a thousand words are
about 1,300 tokens. Code, other languages and unusual words take more. Three things follow:

1. **Length is measured in tokens**, and so are limits and prices.
2. **Letter-level tasks are hard for it.** Counting the r's in "strawberry", reversing a word,
   rhyming exactly: the model does not see the letters. Ask it to write code that does the
   task instead — code sees letters.
3. **Numbers are tokens too.** Long arithmetic done "in its head" can slip. Ask it to calculate
   with a tool (Python, `qalc`) and show the result.

## 67.2 next-token prediction

A language model does one thing: given the tokens so far, it gives a probability for every
possible next token. One token is chosen, added to the text, and the step repeats. A whole
answer, a whole program, is written this way — one token at a time, each chosen in the light of
everything before it.

> **Word — sampling.** Choosing the next token from the model's probabilities. **Temperature**
> sets how adventurous the choice is: low, nearly always the most likely token; high, more
> variety (and more mistakes).

This is why the same question can get different answers, and why a model never "looks up" a
fact: it produces text that is likely given its training and what you gave it. Most of the time
likely and true are the same thing. Where they part is where mistakes come from.
