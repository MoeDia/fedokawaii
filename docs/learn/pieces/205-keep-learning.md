---
id: keep-learning
title: keep learning; a card for the wall
part: ai
chapter: 72
minutes: 8
needs: [own-every-line]
optional: no
---

## 72.4 keep learning, not just shipping

The danger is not that AI makes mistakes; it is that you stop being able to tell. Keep your own
skill growing:

- **Explain before you accept.** If you cannot say why the code works, ask until you can.
- **Write some of it yourself.** The exercises of Parts IV and V, by hand, before you ask.
- **Use it as a tutor.** "Don't give me the answer — give me a hint" is a fine request.
- **Predict, then check.** Before running its code, say what it will print.

People who understand the work direct AI far better than people who do not — the gap grows, it
does not close.

## 72.5 staying good as tools change

This part will date. The habits behind it will not. To learn a new model or tool in an afternoon:

1. Read its official documentation's best-practices page first, then its list of commands.
2. Try the basic loop (explore, plan, implement, check) on a toy project.
3. Move one real workflow to it, and compare — time, quality, mistakes.
4. Keep your `CLAUDE.md`, specs, hooks and skills as plain files in git: they move with you, and
   most agents read something like them.

And measure, not guess: when you change a prompt, a model or a setting, run the same task before
and after and compare the results. That one habit — evaluation — is what separates engineering
with AI from hoping.

## 72.6 a card for the wall

| Before | During | After |
|---|---|---|
| clean `git status` | Esc early when it drifts | read the whole diff |
| goal, context, constraints, done-when | two corrections, then start over | run the check yourself |
| plan if it is big or unclear | `/clear` between tasks | commit small, in your words |
| a test as the finish line | subagents for side research | update CLAUDE.md with what you learnt |

### exercises

**72.1 ★ Review one.** Take any AI-made diff of yours and go through the table of 72.3, writing
one line per row.

*You should see:* at least one thing worth changing.

<!-- solution 72.1 -->
```text
asked-for, all of it:   yes, but it also renamed two variables I didn't ask about
real functions:         Path.walk exists from Python 3.12 — fine on 3.14
edges:                  an empty folder crashes on max() of nothing → fix
weakened:               none
simpler:                the cache class can be a dict
project style:          f-strings, as ours — fine
```
<!-- /solution -->

**72.2 ★★ Predict.** Ask for a small function and its test. Before running them, write down what
the test run will print. Run it.

*You should see:* your prediction right — or a lesson in where your understanding stopped.

<!-- solution 72.2 -->
is in the failure's last line (chapter 3): often an edge you did not think of either — which is
exactly what the prediction was for.
<!-- /solution -->
