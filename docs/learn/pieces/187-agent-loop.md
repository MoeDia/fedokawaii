---
id: agent-loop
title: the loop, and what goes wrong
part: ai
chapter: 69
minutes: 3
needs: [py-agent-practice, model-practice, ask-iterate]
optional: no
---

> **In this chapter**
>
> - the agent loop: gather context, act, check — and why the check is everything
> - what can go wrong, and the guard rails against each
> - prompt injection: why text an agent reads is data, never orders

In chapter 47 you built an agent: a model, a list of tools, and a loop that runs whatever tool the
model asks for and hands back the result. Claude Code is the same loop with tools for files, the
shell, the web and more. Understanding the loop tells you how to steer it.

## 69.1 the loop

```text
your request
   │
   ▼
gather context ──► act ──► check ──► done?
   ▲                                  │ no
   └──────────────────────────────────┘
```

1. **Gather context**: read files, search, run commands to see the state of things.
2. **Act**: edit a file, run a command, write a test.
3. **Check**: run the tests, the build, the program — read the result.
4. Repeat until the check passes, or ask you.

Each tool result goes back into the context (67.4), so the agent learns as it goes. The quality of
the whole run depends on step 3. With a real check, the loop corrects itself. Without one, the
agent's only signal is that the work *looks* done — and you become the check.

## 69.2 what goes wrong

| Failure | Looks like | Guard rail |
|---|---|---|
| wrong problem | a fine solution to something you did not ask | plan first; read the plan (70.4) |
| drift | it "improves" things you did not mention | constraints in the request; review the diff |
| false finish | "all tests pass" — but they were not run, or a test was weakened | ask for the command and its real output; read test changes first |
| loops | the same failed fix, again and again | stop it (**Esc**); start over with what you learnt (68.4) |
| context rot | a long session gets worse | `/clear` between tasks; subagents for research (71.4) |
| overreach | it deletes, pushes, installs, spends | permission modes and rules (70.2, 71.1); commit before you start |
