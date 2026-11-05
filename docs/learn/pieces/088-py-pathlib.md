---
id: py-pathlib
title: paths, whole files
part: python
chapter: 31
minutes: 4
needs: [py-dicts-practice]
optional: no
---

> **In this chapter**
>
> - read and write text files, the whole file or line by line
> - paths with `pathlib`: join, look, list
> - CSV and JSON: the two formats you will meet everywhere

A variable lives only while the program runs. A **file** stays on the disk: notes, settings,
data, results. Every program that remembers anything between runs uses files.

## 31.1 paths with pathlib

`Path` (from the `pathlib` module) is Python's way to name a file. `/` joins pieces of a path —
on any system:

```python
from pathlib import Path

p = Path("notes") / "2026" / "october.md"
print(p)
print(p.name, p.stem, p.suffix)
print(p.parent)
print(Path.home().is_absolute())
```

*You should see:*

```text
notes/2026/october.md
october.md october .md
notes/2026
True
```

| Part | `Path("notes/2026/october.md")` |
|---|---|
| `.name` | `october.md` |
| `.stem` · `.suffix` | `october` · `.md` |
| `.parent` | `notes/2026` |
| `.exists()` · `.is_file()` · `.is_dir()` | `True`/`False` |

## 31.2 write, then read, a whole file

`write_text` makes (or replaces) a file; `read_text` gives the whole file as one string. Always
say `encoding="utf-8"`, so Arabic, kanji and emoji come back as they went in:

```python
from pathlib import Path

f = Path("hello.txt")
f.write_text("first line\nsecond line\n日本語\n", encoding="utf-8")
text = f.read_text(encoding="utf-8")
print(text)
print(len(text.splitlines()), "lines")
```

*You should see:*

```text
first line
second line
日本語

3 lines
```

> **Careful.** `write_text` replaces the whole file without asking. Write to a new name when
> you are not sure.
