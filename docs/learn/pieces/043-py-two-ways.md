---
id: py-two-ways
title: two ways to run Python
part: python
chapter: 25
minutes: 5
needs: [loop-commit]
optional: no
---

> **In this chapter**
>
> - Python's prompt, and how to run a file
> - numbers and arithmetic, with the four mistakes everyone makes once
> - variables: names for values
> - `print` and `input`: talk to the person running your program

This is level 1 of six. Each level has three chapters and ends with a small project that uses
everything in it — the *checkpoint*. Do not skip ahead: every later chapter assumes the
earlier ones. If you can do a level's checkpoint without looking back, you are ready for the
next level.

| Level | You learn | Chapters | Checkpoint |
|---|---|---|---|
| 1 | numbers, text, decisions, loops | 25–27 | a guessing game |
| 2 | functions, lists, dictionaries, sets | 28–30 | a contacts book |
| 3 | files, errors, modules, uv | 31–33 | an expense tracker |
| 4 | classes, tests, type hints | 34–36 | a tested library |
| 5 | comprehensions, generators, async, packaging, CLIs | 37–39 | a command of your own |
| 6 | data, NumPy, then machine learning | 40–47 | a network that learns |

Every example in this part was run with Python 3.14 as printed, and the output under
*You should see* is what it printed.

## 25.1 two ways to run Python

Python reads your code and does it, one line at a time. There are two ways to give it code.

**1. The prompt (the REPL).** Type a line, press Enter, see the answer at once. Use it to try
things.

```text
$ uv run python
Python 3.14.0 (main, …) [GCC 15.2.1] on linux
Type "help", "copyright", "credits" or "license" for more information.
>>>
```

*(`>>>` is Python waiting for you. `exit()` or **Ctrl+D** leaves.)*

> **Word — REPL.** *Read, Evaluate, Print, Loop*: Python reads a line, works it out, prints
> the result, and waits for the next. At the prompt, the value of an expression is printed by
> itself; in a file it is not — there you must call `print`.

```text
>>> 2 + 3
5
>>> 10 - 4
6
>>> "hello"
'hello'
```

**2. A file.** Write the lines into a file ending in `.py`, then run the whole file. Use it for
anything longer than a few lines, and for anything you want to keep.

`hello.py`:

```python
print("hello")
print(2 + 3)
```

*You should see:*

```text
hello
5
```

```text
$ uv run hello.py
hello
5
```

In the examples below, a block that starts with `>>>` is for the prompt; any other block is a
file: save it (as `example.py`, say) and run it.
