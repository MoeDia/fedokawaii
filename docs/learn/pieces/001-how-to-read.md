---
id: how-to-read
title: how this works
part: zero
chapter: 0
minutes: 5
needs: []
optional: no
---

This book is the practical one. It teaches by doing: a short example, what you should see,
then an exercise of your own. The full handbook — how every part of the desktop is built and
why — stays in the project's repository on GitHub (`docs/fedokawaii-guide.md`), for the day
you want to know how something works inside. This book is about *using* it.

It has six parts. Read Part I first if you have never typed a command. After that, go where
you need to: each chapter stands on its own and says what it expects you to know.

| Part | You learn | Chapters |
|---|---|---|
| I — From zero | what a terminal, a file, a path, a program and a variable are; how to read an error | 1–3 |
| II — The desktop | the keys, windows, the bar and menus, the clipboard, screenshots, updates, snapshots | 4–8 |
| III — The programs | each program, its best moves, real uses and exercises | 9–22 |
| IV — Python | a daily development routine, then a full course in six levels: from your first number to classes, tests, async and packaging, then data, NumPy, a neural network, a transformer, fine-tuning and an agent | 23–47 |
| V — Rust | a full course in six levels: from cargo to ownership, traits, lifetimes, tests, iterators and threads, then a CLI, your own autograd, models in Rust, and Rust inside Python | 48–66 |
| VI — Working with AI | how a language model works — tokens, context, training, hallucination —; asking well; agents and their risks; Claude Code from the daily loop to your own hooks, skills and subagents; the professional's habits that outlast any tool | 67–72 |
| Appendices | a glossary; the worked solution to every exercise of Parts IV, V and VI | A–D |

### How a lesson looks

Every new idea comes as an example first: you type it, then you see what it printed.

```text
$ echo hello
hello
```

*(the `$` is the prompt — do not type it; the line under it is what you should see)*

A line starting with `$` is what you type, without the `$`. The lines under it are what the
computer answers. Your answer may differ in details (a name, a date, a number): what matters
is its shape. A block without `$` is a file's contents, to type into an editor.

### The boxes

> **Word — prompt.** The text the terminal shows when it waits for your command. Each new word
> gets a box like this the first time it appears.

> **Checkpoint.** A short test at the end of a section. If you can do it without looking back,
> go on. If not, read the section again: it costs five minutes now and saves an hour later.

> **Careful.** Something that can lose work or break a setting. Read it before you type.

### The exercises

Each chapter ends with exercises, graded by stars:

| Stars | Means | Takes |
|---|---|---|
| ★ | do exactly what the chapter showed, on your own files | a minute |
| ★★ | combine two things from the chapter | five minutes |
| ★★★ | a small project: you decide how | half an hour |
| ★★★★ | a challenge: it stretches what the chapter taught | an evening |

Every exercise says what you should see when it works. In Parts IV, V and VI, every exercise has
a worked solution at the back — appendix B for Python, C for Rust, D for working with AI, under
the exercise's number — with the output it printed. Try for real before you look: the struggle is where the learning
happens; the solution is there to check, or to unstick you after twenty honest minutes. Keep a line for each one you finish in
your notes (**Super+N**): `- [x] 10.3 every PDF I own`. Watching that list grow is half the fun.

### Three rules that make learning fast

1. **Type, never paste.** Your fingers learn the shapes: brackets, quotes, the order of words.
2. **One small step, then check.** Run it after every change. A mistake found at once is a
   mistake you understand.
3. **Read the error.** The last line of an error message almost always says what is wrong
   (chapter 3 shows how).
