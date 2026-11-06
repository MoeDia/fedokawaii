---
id: agents-moves
title: agents, a quick start
part: programs
chapter: 21
minutes: 8
needs: [git-moves]
optional: no
---

> **Word — agent.** A program that uses an AI model to work on a task in steps: it reads files,
> runs commands and edits, asking you first. **Claude Code** is one, in the terminal.

**Best at:** explaining code and errors, planning a change, writing tests, doing a well-described
chore. You stay the author: you read every change before you keep it.

| In a terminal | Does |
|---|---|
| `cd ~/dojo/hello && claude` | start it in a project |
| type a request, **Enter** | it plans, asks, then works |
| **Esc** | stop it at once |
| **Shift+Tab** | switch modes: ask before edits · accept edits · plan only |
| `/clear` · `/init` | a fresh conversation · write a `CLAUDE.md` describing the project |
| `/exit` | leave |

**herdr** runs several agents side by side, with a sidebar marking each *working*, *blocked*
(it needs you) or *idle*. *Agents* in the launcher. Every herdr key is **Ctrl+B**, then one key:
**Ctrl+B a** a new Claude, **Ctrl+B v** a split, **Ctrl+B h/j/k/l** move, **Ctrl+B o** the agent
that just called, **Ctrl+B q** close the window (the agents keep working).

Habits that keep you learning:

1. Commit before you ask for a change: `git diff` then shows exactly what it did.
2. Ask it to *explain* first, *write* second: "explain what this function does, line by line".
3. Ask for tests with every change, and run them yourself.
4. Never paste a secret into a prompt.

This chapter is the quick start. Part VI (chapters 67–72) is the whole craft: how the model
works, how to ask, how agents fail, Claude Code in depth, and the habits of people who use it
professionally.

### exercises

**21.1 ★ Explain.** In `~/dojo/fedokawaii`, ask Claude Code: *"explain bin/kawa-weather to a
beginner, step by step — do not change anything"*.

**21.2 ★★ Two at once.** In herdr, run one agent writing tests for your `hello` project while
another explains git's reflog to you.
