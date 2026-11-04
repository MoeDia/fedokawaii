---
id: hallucination
title: reasoning, hallucination, choosing a model
part: ai
chapter: 67
minutes: 3
needs: [training]
optional: no
---

## 67.5 reasoning, and why "think first" works

Each token is written with a fixed amount of computation. A hard problem needs more steps than
one token can hold — so a model that writes its reasoning out first (the steps, the cases, a
plan) gets more computation, and each later token can build on the earlier ones. Modern models
do this on their own: they **think** before they answer, at an effort you can often set. Two
lessons for you:

- For a hard task, ask for a plan, the options or the reasoning before the answer.
- For a trivial task, more thinking costs time and money and buys nothing.

## 67.6 hallucination

> **Word — hallucination.** A confident answer that is wrong: a function that does not exist, a
> command-line option that was never there, a quotation nobody said, a test reported passing
> that was never run.

It follows from 67.2: the model produces *likely* text. A plausible function name is likely;
the fact that it does not exist in your library's version is not in the context. Hallucination
is most likely when:

| Situation | Why | What to do |
|---|---|---|
| a fact past the cutoff | it is not in the training | give it the facts, or let it search the web or read the docs |
| a rare library or your own project | little or nothing to learn from | let it read the code and the docs first |
| exact details: versions, flags, numbers, quotations | many near-misses are all likely | check against the source, run the command |
| "did it work?" | saying yes is likely | ask for evidence: the command and its real output |

The professional's answer is not distrust, it is **verification**: every claim that matters is
checked against something that cannot hallucinate — a test, a compiler, the real output, the
documentation. Chapter 69 builds this into the way you work.

## 67.7 choosing a model

Models come in sizes. A larger one reasons better and knows more; a smaller one is faster and
cheaper. A sensible rule: use the strongest model for planning, hard bugs and design, and a
faster one for routine, well-described work. Whatever you use, the habits in this part matter
more than the choice — a strong model given a vague task in a cluttered context still does worse
than a modest one given a clear task and a test.
