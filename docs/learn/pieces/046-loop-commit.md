---
id: loop-commit
title: commit, and the whole loop
part: python
chapter: 24
minutes: 12
needs: [loop-edit]
optional: no
---

## 24.6 commit and push

**Space g g**, **a** (stage all), **c**, a message that says *why*, **Enter**, **P**. The first
time, put the project on GitHub:

```text
$ gh repo create hello --private --source . --push
✓ Created repository you/hello on GitHub
✓ Pushed commits to https://github.com/you/hello.git
```

## 24.7 the whole loop, on one card

| Step | Command or keys |
|---|---|
| new project | `uv init NAME && cd NAME && uv add --dev pytest` |
| a library | `uv add numpy` |
| edit | `nvim .` · **Space Space** a file |
| run | **Space r f** |
| test on save | **Space t w** in a test file |
| debug | **Space d b**, **Space d c** |
| commit · push | **Space g g**, **a**, **c**, **P** |

### exercises

**24.1 ★ The loop once.** Make the `hello` project, add pytest, write `tests/test_one.py` with
`def test_one(): assert 1 + 1 == 2`, run `uv run pytest`.

*Expected:* `1 passed`.

**24.2 ★★ Red, then green.** Watch the test file (**Space t w**), change the test to `1 + 1 == 3`, save: see it fail,
read the message, put it back.

*Expected:* the failure shows `assert 2 == 3` — pytest prints both sides.

**24.3 ★★ A breakpoint.** In `main.py`, make a variable, put a breakpoint on the next line, run
the debugger, and read the variable's value in the panel.
