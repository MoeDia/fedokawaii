---
id: claude-steps
title: the four steps, steering a session
part: ai
chapter: 70
minutes: 2
needs: [claude-starting]
optional: no
---

## 70.3 the four steps

1. **Explore** (plan mode): *"read `src/` and explain how expenses are stored. Change nothing."*
2. **Plan** (still plan mode): *"I want monthly budgets with a warning when one is exceeded.
   Which files change? What are the risks? Write a plan."* Read it. Edit it (**Ctrl+G** opens it
   in your editor). Ask about anything unclear.
3. **Implement** (accept the plan, or **Shift+Tab** out): *"implement the plan. Write the tests
   first, run them, then make them pass."*
4. **Commit**: read `git diff` yourself, then *"commit with a message in this repository's
   style"*.

Skip the plan when you could describe the whole change in one sentence. Use it when the change
touches several files, when you do not know the code, or when you are not sure of the approach.

## 70.4 steering a session

| Command | When |
|---|---|
| **Esc** | it is heading the wrong way: stop, then say what you want instead |
| **Esc Esc** or `/rewind` | go back to an earlier point: the conversation, the code, or both |
| `/clear` | a new, unrelated task: an empty context (67.4) |
| `/compact focus on the parser` | a long task that must go on: summarise the past, keep what you name |
| `/context` | see what fills the context |
| `/btw a question` | a quick side question that does not stay in the context |
| `/model` | switch model (67.7) |
| `claude --continue` · `claude --resume` | the last session again · choose one from a list |
| `/rename budgets` | name this session, to find it later |

> **Careful.** Rewind restores files Claude Code changed through its own editing. Changes made by
> commands it ran (a script that moved files, an installed package) are not undone by it. Git and
> your snapshots are the real undo: commit before you start.
