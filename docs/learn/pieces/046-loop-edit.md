---
id: loop-edit
title: edit, test, debug
part: python
chapter: 24
minutes: 3
needs: [loop-project]
optional: no
---

## 24.3 edit in neovim

```text
$ nvim .
```

Python support is set up already: the language servers (basedpyright and ruff) and formatting on
save start with the first `.py` file. In one:

| Keys | Does |
|---|---|
| typing | completion appears; **Ctrl+N** moves into it, **Ctrl+Y** takes the word |
| `K` · `gd` · `grr` | the documentation of a name · its definition · everywhere it is used |
| **]d** · **Ctrl+W d** | the next problem · the full text of this line's problem |
| `gra` · `grn` | a fix the language server offers · rename everywhere |
| **Space c f** | format the file (also on every save) |
| **Space r f** | run this file (`uv run`: the project's `.venv`) |
| **Space r t** | run the project's tests (`pytest`), in a terminal under the code; `q` closes it |
| **Space r r** · **Space r c** · **Space r l** | a Python prompt (REPL) under the code · send it the cell (`# %%` lines part a file into cells) · the line |
| **Space d b** · **Space d c** | a breakpoint here · run with the debugger |
| **Space d n** · **Space d i** · **Space d o** | the next line · step into · out of |
| **Space d u** · **Space d t** | the debugger's panels · stop it |
| **Space g g** | lazygit |
| **Space f t** | a terminal at the bottom, and back |

## 24.4 test after every change

Change a line, save (**Ctrl+S**), press **Space r t**: pytest runs in a terminal under the code,
in a fraction of a second, and prints each failure with its message. `q` closes it, and you are
back where you were. Green means your last change kept everything working. This loop — change,
save, one key, read — is the fastest way to learn a language there is.

## 24.5 debug: look inside a running program

When a result is wrong and you cannot see why, stop the program in the middle and look:

1. Cursor on a line inside the function, **Space d b**: a red dot in the margin.
2. **Space d c**: the program runs and stops there; the panels show every variable's value.
3. **Space d n** steps one line; watch the values change. **Space d t** stops.
