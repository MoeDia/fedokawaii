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

Python support is set up already: the language servers (basedpyright and ruff), formatting on
save, the test runner and the debugger load with the first `.py` file. In one:

| Keys | Does |
|---|---|
| typing | completion appears; **Enter** takes it, **Ctrl+Space** asks for it |
| `K` · `gd` · `gr` | the documentation of a name · its definition · everywhere it is used |
| **]d** · **Space c d** | the next problem · the full text of this line's problem |
| **Space c a** · **Space c r** | a fix the language server offers · rename everywhere |
| **Space c f** | format the file (also on every save) |
| **Space r f** | run this file (`uv run`: the project's `.venv`) |
| **Space r r** · **Space r c** · **Space r l** | a Python prompt (REPL) under the code · send it the cell (`# %%` lines part a file into cells) · the line |
| **Space t t** · **Space t r** · **Space t w** | run this file's tests · the test under the cursor · run them on every save |
| **Space t s** · **Space t o** | the test summary · the last test's output |
| **Space d b** · **Space d c** | a breakpoint here · run with the debugger |
| **Space t d** | debug the test under the cursor |
| **Space d i** · **Space d O** · **Space d o** | step into · over · out of |
| **Space d u** · **Space d t** | the debugger's panels · stop it |
| **Space c v** | choose the project's `.venv` (when a project has more than one) |
| **Space g g** | lazygit |
| **Ctrl+/** | a terminal at the bottom, and back |

## 24.4 test on every save

Open a test file and press **Space t w**: neovim now runs its tests every time you save
(**Ctrl+S**), in a fraction of a second, and marks each test in the margin — ✓ green, ✗ red, the
failure's message beside the line. **Space t s** keeps the summary open on the right. Green
means your last change kept everything working. This loop — change, save, glance at the
margin — is the fastest way to learn a language there is. **Space t w** again stops watching.

## 24.5 debug: look inside a running program

When a result is wrong and you cannot see why, stop the program in the middle and look:

1. Cursor on a line inside the function, **Space d b**: a red dot in the margin.
2. **Space d c**: the program runs and stops there; the panels show every variable's value.
3. **Space d O** steps one line; watch the values change. **Space d t** stops.
