---
id: five-parts
title: the five parts of a good request
part: ai
chapter: 68
minutes: 3
needs: [model-practice]
optional: no
---

> **In this chapter**
>
> - the five parts of a good request: goal, context, constraints, done-when, form
> - examples beat descriptions; questions before answers
> - iterating: a better request beats more corrections

A model is a brilliant colleague who joined your team this morning: it knows a great deal in
general and nothing about your project, your taste, or what you already tried. Everything you
would tell such a person, tell the model.

## 68.1 the five parts of a good request

| Part | Question it answers | Example |
|---|---|---|
| **goal** | what do you want, and why? | "add a `--json` option to `expenses list`, so another script can read it" |
| **context** | what does it need to know? | "the command is in `src/expenses/cli.py`; `expenses add` already has a `--json` you can copy" |
| **constraints** | what must not happen? | "no new dependencies; keep the text output exactly as it is" |
| **done when** | how will we both know it worked? | "a pytest test checks the JSON for two expenses; `uv run pytest` passes" |
| **form** | what should the answer look like? | "the diff, then one paragraph on anything you were unsure of" |

You will not need all five every time — "fix the typo on line 12 of README.md" is complete as it
stands. The bigger and vaguer the task, the more each part saves you.

**Done when** matters most. A model stops when the work *looks* finished. Give it a check it can
run — a test, a build, a command whose output it compares — and "finished" means *passes*, not
*looks right*.

## 68.2 show, do not describe

One example of what you want beats a paragraph describing it:

```text
weak:    write commit messages in our style
strong:  write the commit message in the style of these three:
         "Bar: the clock keeps its width when the seconds change"
         "Panel: a row's glyph centred in its column"
         "Wallpaper: the picker opens on the picture shown now"
```

The same holds for code: "follow the pattern of `bin/kawa-weather`" lets it read a real example
and match it, instead of guessing at your style.
