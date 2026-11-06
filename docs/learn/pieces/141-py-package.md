---
id: py-package
title: a package, installed as your own command
part: python
chapter: 39
minutes: 7
needs: [py-exit-pipes]
optional: no
---

## 39.5 a package: src layout and an entry point

A script runs with `uv run file.py`. A **package** can be installed as a command you type
anywhere, like `rg` or `bat`. uv makes the layout:

```text
$ uv init --package wordfreq
Initialized project `wordfreq` at `/home/you/dojo/wordfreq`
$ find wordfreq -type f | sort
wordfreq/.python-version
wordfreq/README.md
wordfreq/pyproject.toml
wordfreq/src/wordfreq/__init__.py
```

| File | Holds |
|---|---|
| `src/wordfreq/__init__.py` | the package; `main()` is the command's start |
| `pyproject.toml` | name, version, dependencies — and `[project.scripts]`: the command's name |

`wordfreq/src/wordfreq/__init__.py`:

```python
"""wordfreq — the most common words of a text."""
import argparse
import re
import sys
from collections import Counter

def top_words(text: str, n: int) -> list[tuple[str, int]]:
    words = re.findall(r"[a-z']+", text.lower())
    return Counter(words).most_common(n)

def main() -> None:
    p = argparse.ArgumentParser(prog="wordfreq", description=__doc__)
    p.add_argument("file", nargs="?", help="a text file (default: the pipe)")
    p.add_argument("-n", type=int, default=5, help="how many words")
    args = p.parse_args()
    text = open(args.file, encoding="utf-8").read() if args.file else sys.stdin.read()
    for word, count in top_words(text, args.n):
        print(f"{count:>5}  {word}")
```

```text
$ grep -A1 'project.scripts' wordfreq/pyproject.toml
[project.scripts]
wordfreq = "wordfreq:main"
$ cd wordfreq && echo "the cat and the hat and the bat" | uv run -q wordfreq -n 2
    3  the
    2  and
```

*(`uv run wordfreq` runs the command inside the project. `[project.scripts]` says the command
`wordfreq` calls `wordfreq:main`)*

## 39.6 install it as your own command

```text
$ uv tool install --editable .
Installed 1 executable: wordfreq
$ cd ~ && wordfreq -n 3 ~/notes/notes.md
```

`uv tool install` puts the command in `~/.local/bin`, which is on your `PATH` — it now works from
any folder, in its own venv. `--editable` means a change to the code works at once, without
installing again. `uv tool list` shows your tools; `uv tool uninstall wordfreq` removes it.

**Sharing it.** `uv build` makes a *wheel* (`dist/wordfreq-0.1.0-py3-none-any.whl`): one file
anyone can install with `uv tool install wordfreq-0.1.0-py3-none-any.whl`. Pushed to GitHub,
anyone can install it straight from there:
`uv tool install git+https://github.com/you/wordfreq`.

```text
$ cd wordfreq && uv build -q && ls dist
wordfreq-0.1.0-py3-none-any.whl
wordfreq-0.1.0.tar.gz
```

## 39.7 common mistakes

**1. Printing errors to stdout.** They end up in the next program's input. `print(…,
file=sys.stderr)`.

**2. Exiting with 0 after a failure.** `sys.exit(1)` (or any non-zero) after an error, so scripts
and `&&` know.

**3. Code at the top level of the package** (outside functions): it runs on every import, even
for `--help`. Keep everything in functions, started from `main()`.
