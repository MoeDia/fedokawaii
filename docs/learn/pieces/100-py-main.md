---
id: py-main
title: __name__, PyPI, a project with uv
part: python
chapter: 33
minutes: 6
needs: [py-import]
optional: no
---

## 33.3 if __name__ == "__main__"

A module's top-level code runs when it is imported. To have code that runs only when the file
is run *itself* — a demo, or the program's start — put it under this line:

`temperature.py`:

```python
def c_to_f(c):
    return c * 9 / 5 + 32

if __name__ == "__main__":
    print("demo:", c_to_f(100))
```

`use_it.py`:

```python
from temperature import c_to_f
print(c_to_f(37))
```

```text
$ uv run temperature.py
demo: 212.0
$ uv run use_it.py
98.6
```

*(run directly, `__name__` is `"__main__"`; imported, it is the module's name, so the demo is
skipped)*

## 33.4 packages from the internet: PyPI

Beyond the standard library are over half a million packages on **PyPI** (the Python Package
Index) — NumPy, requests, PyTorch. You install them into a project with uv.

> **Word — package, library, dependency.** A *package* is code you install; a *library* is a
> package meant to be used by other code; a *dependency* is a package your project needs.

> **Word — virtual environment (venv).** A project's own folder (`.venv`) holding its Python
> and its packages, apart from every other project and from the system. Two projects can need
> two versions of the same library: each venv has its own.

## 33.5 a project with uv

`uv` (chapter 24) does the whole job: makes the project, picks its Python, makes its venv,
installs packages, writes the lock file, runs your code inside the venv:

```text
$ uv init --app expenses
Initialized project `expenses` at `/home/you/repos/expenses`
$ ls expenses
README.md  main.py  pyproject.toml
$ cat expenses/pyproject.toml
[project]
name = "expenses"
version = "0.1.0"
description = "Add your description here"
readme = "README.md"
requires-python = ">=3.14"
dependencies = []
```

*(`dependencies` fills as you `uv add`; `ls -a` would show `.python-version`, `.gitignore`
and `.git` too)*

| Command | Does |
|---|---|
| `uv init NAME` | a new project: `pyproject.toml`, `main.py`, `.python-version`, git |
| `uv add NAME` | install a package, and write it into `pyproject.toml` and `uv.lock` |
| `uv add --dev NAME` | a package needed only while developing (pytest, ruff) |
| `uv remove NAME` | the opposite |
| `uv run FILE` · `uv run CMD` | run inside the project's venv (made on the first run) |
| `uv sync` | make `.venv` match the lock file exactly (after `git pull`, say) |
| `uv tree` | the dependencies, and theirs |
| `uv python list` | the Pythons uv knows and has |
| `uvx TOOL` | run a tool once without installing it: `uvx ruff check .` |

> **Careful.** Never `sudo pip install`. It mixes packages into the system's Python, which
> Fedora's own tools use. Always a project and `uv add`; for a tool you want everywhere,
> `uv tool install NAME`.

**The lock file.** `uv.lock` records the exact version of every package, and of every package
those need. Commit it to git: on another machine, `uv sync` rebuilds exactly the same `.venv`,
so the code runs the same.
