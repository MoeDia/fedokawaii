---
id: own-every-line
title: you own every line; specs; review
part: ai
chapter: 72
minutes: 3
needs: [claude-tools-practice]
optional: no
---

> **In this chapter**
>
> - you stay the author: the rules that keep quality yours
> - reviewing AI work quickly and well
> - keeping your own skills growing
> - staying good as the tools change

Anyone can get code from a model. What a professional adds is judgement: what to build, whether
it is right, and whether it is safe to ship. These habits are what employers and users pay for,
and none of them depends on which model or tool is current.

## 72.1 you own every line

The rule is simple: **you ship nothing you do not understand.** If it breaks at 3 a.m., "the AI
wrote it" fixes nothing. In practice:

1. **Small steps.** One change, one check, one commit. A diff you can read in two minutes gets
   read; one of two thousand lines gets skimmed.
2. **Commit before, review after.** `git diff` is the agent's work, exactly. Read it all.
3. **Tests are the contract.** Write or read them first. Read any change *to* a test with
   suspicion: a weakened test is the easiest way to make something "pass".
4. **Evidence, not assurance.** "It works" is a claim; the command and its output are evidence.
5. **Secrets stay secret.** Never in a prompt, a commit or a log.

## 72.2 specs carry decisions

A conversation ends; a file stays. For anything bigger than an afternoon, keep:

| File | Holds |
|---|---|
| `SPEC.md` | what it should do, what it must not, what is out of scope, how to check it end to end |
| `PLAN.md` | the steps, ticked off as they land |
| `CLAUDE.md` | how to work in this project |

A fresh session given the spec starts where the last one stopped, with none of its clutter. The
most useful specs name the files and interfaces, say what is out of scope, and end with a check
that proves the whole thing works.

## 72.3 reviewing AI work

AI code fails in typical ways. Read a diff with these questions:

| Look for | Because models tend to |
|---|---|
| does it do what was asked — all of it, and only it? | drift, or quietly skip the hard part |
| are the functions and options it calls real? | invent plausible names (67.6) |
| what happens on empty input, a missing file, no network? | write the happy path well and the edges less |
| was anything deleted or weakened — a check, a test, an error message? | remove what stands in the way of "passing" |
| is there a simpler way? | add layers, options and defensive code nobody needs |
| does it match the project? | write in their own default style instead of yours |

A second, fresh agent is a good first reviewer (71.4) — but you are the last one.
