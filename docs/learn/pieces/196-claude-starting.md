---
id: claude-starting
title: starting, permission modes
part: ai
chapter: 70
minutes: 2
needs: [git-moves, agents-moves, injection]
optional: no
---

> **In this chapter**
>
> - modes: from asking before every change to planning only
> - the four-step loop: explore, plan, implement, commit
> - steering: stop, rewind, clear, compact, resume
> - `CLAUDE.md`: what your project tells every session

## 70.1 starting

```text
$ cd ~/repos/hello
$ git status                       # start clean: every change after this is the agent's
$ claude
```

| You type | Does |
|---|---|
| a request, **Enter** | starts the loop |
| `@src/app.py` in a request | puts that file in the context first |
| a picture pasted or dragged in | it can see it: a screenshot of a bug, a design to match |
| **Enter** while it works | queues a correction it reads before its next step |
| **Esc** | stops at once; nothing is lost, you can redirect |
| `/help` | every command |

## 70.2 permission modes

**Shift+Tab** cycles the modes; the line under the prompt shows the current one.

| Mode | What it may do without asking |
|---|---|
| **manual** | nothing: it asks before every edit and command |
| **accept edits** | edit files and run simple file commands (`mkdir`, `mv`); asks before other commands |
| **plan** | read and explore only; it proposes a plan and changes nothing |
| **auto** | most things: a separate safety check reviews each action and blocks risky ones |

The mode is the dial of 69.4. Start strict on unfamiliar ground, looser where git and tests have
your back.
