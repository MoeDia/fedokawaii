---
id: read-errors
title: last line first, and the ten you will meet
part: zero
chapter: 3
minutes: 10
needs: [time-savers]
optional: no
---

> **In this chapter**
>
> - read an error message from its last line up
> - recognise the ten errors you will meet most

An error is not a failure: it is the computer telling you, quite precisely, what it could not
do. Programmers spend much of their day reading them. The trick is to read in the right order.

## 3.1 the method: last line first

1. Read the **last line**. It names the problem.
2. Find the **file and line number** it mentions. Go there.
3. Only then read the rest, from the bottom up: it is the path that led there.

```text
$ python3 hello.py
Traceback (most recent call last):
  File "/home/you/hello.py", line 3, in <module>
    print(nmae)
          ^^^^
NameError: name 'nmae' is not defined
```

*(the last line says what: a name nobody defined; the line above says where: line 3)*

## 3.2 the ten you will meet most

| You see | It means | Do |
|---|---|---|
| `command not found` | no program by that name: a typo, or not installed | check the spelling; `tldr` the name |
| `No such file or directory` | the path is wrong | `ls` the folder; use Tab to complete paths |
| `Permission denied` | not yours to change | system files: `sudoedit FILE`; a script: `chmod +x FILE` |
| `Is a directory` | you gave a folder where a file was wanted | add the file's name |
| `SyntaxError` (Python) | the code is not well formed: a missing `:`, `)` or quote | look at the line named, *and the one before* |
| `IndentationError` (Python) | the spaces at a line's start do not match | use the editor's indent (4 spaces) everywhere |
| `NameError` (Python) | a name used before it was given a value, or misspelt | compare the spelling with where you made it |
| `ModuleNotFoundError` (Python) | a library is not in this project | `uv add NAME` (chapter 24) |
| `error[E0382]: borrow of moved value` (Rust) | a value was given away, then used again | chapters 51–52: borrow it with `&` |
| `mismatched types` (Rust) | a number where text was expected, or similar | read the `expected … found …` lines |

> **Careful.** A long red error is not worse than a short one. Python and Rust print the whole
> path of calls; only the top and the bottom usually matter.

## 3.3 ask for an explanation

When an error makes no sense, copy it (select it in the terminal: selecting copies) and ask
Claude Code in the same folder (chapter 21): *"explain this error and what I should look at —
do not fix it"*. You learn more from the explanation than from a fix.

### exercises

**3.1 ★ Break it on purpose.** Run `cd Nowhere`, `lss`, and `cat ~/Pictures`. Read each
message.

*Expected:* `No such file or directory`, `command not found`, `Is a directory`.

**3.2 ★★ Find the line.** Save this as `~/practice/oops.py` (in neovim: `nvim
~/practice/oops.py`, **i**, type, **Esc**, `:wq`), run `python3 ~/practice/oops.py`, and fix it
from the message alone:

```python
prices = [3, 5, 8]
total = sum(prices)
print("total:" total)
```

*Expected:* `SyntaxError: invalid syntax. Perhaps you forgot a comma?` on line 3. With the comma
(`print("total:", total)`) it prints `total: 16`.
