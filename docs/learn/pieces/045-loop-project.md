---
id: loop-project
title: the tools, and a new project
part: python
chapter: 24
minutes: 3
needs: [nvim-moves, git-moves]
optional: no
---

> **In this chapter**
>
> - make a project with its own Python and libraries (uv)
> - edit with completion and errors shown as you type (neovim)
> - run, test on every save, debug with breakpoints
> - commit and push (lazygit, GitHub)

Professional programmers repeat one loop all day: *edit → run → test → commit*. Set it up once
here; every later chapter uses it.

## 24.1 the tools, and what each does

| Tool | Job |
|---|---|
| **uv** | makes a project, picks its Python, installs its libraries into the project's own folder, runs it |
| **neovim** (LazyVim) | the editor: completion, errors as you type, formatting, tests, the debugger |
| **pytest** | runs your tests — from neovim, once or on every save |
| **ruff** | finds mistakes and formats the code (neovim runs it on save) |
| **git**, **lazygit**, **gh** | history, and GitHub |

> **Word — virtual environment (venv).** A folder (`.venv`) holding one project's Python and its
> libraries, apart from every other project's. uv makes and fills it; you never activate it by
> hand: `uv run` uses it.

## 24.2 a new project

```text
$ cd ~/dojo
$ uv init hello
Initialized project `hello` at `/home/you/dojo/hello`
$ cd hello
$ ls -a
.  ..  .git  .gitignore  main.py  pyproject.toml  .python-version  README.md
$ uv run main.py
Hello from hello!
```

*(uv made a git repository too, with a `.gitignore` that keeps `.venv` out of it)*

| File | Holds |
|---|---|
| `main.py` | your program |
| `pyproject.toml` | the project's name, its Python version and its libraries |
| `.python-version` | which Python this project uses |
| `uv.lock` | (after the first `uv add`) the exact version of every library: the same everywhere |

Libraries come in with `uv add`; tools you only need while developing, with `--dev`:

```text
$ uv add --dev pytest
Resolved 6 packages in 0.4s
Installed 5 packages in 12ms
```
