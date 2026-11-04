---
id: py-lines
title: line by line, folders
part: python
chapter: 31
minutes: 4
needs: [py-pathlib]
optional: no
---

## 31.3 line by line, with open

For big files, or to add to the end, use `open` inside a `with` block. `with` closes the file
for you when the block ends — even if an error happens inside:

```python
with open("log.txt", "w", encoding="utf-8") as f:
    f.write("started\n")
with open("log.txt", "a", encoding="utf-8") as f:
    f.write("step 1 done\n")
    f.write("step 2 done\n")
with open("log.txt", encoding="utf-8") as f:
    for number, line in enumerate(f, start=1):
        print(number, line.rstrip())
```

*You should see:*

```text
1 started
2 step 1 done
3 step 2 done
```

| Mode | Means |
|---|---|
| `"r"` (the default) | read |
| `"w"` | write: a new, empty file (replacing one there) |
| `"a"` | append: add to the end |
| `"rb"` · `"wb"` | read · write bytes (pictures, zips — not text) |

*(each line read keeps its `\n`; `.rstrip()` takes it off)*

## 31.4 folders

```python
from pathlib import Path

d = Path("project")
(d / "data").mkdir(parents=True, exist_ok=True)
(d / "data" / "a.csv").write_text("x\n1\n")
(d / "data" / "b.csv").write_text("x\n2\n")
(d / "readme.md").write_text("# project\n")
for p in sorted(d.rglob("*")):
    print(p, "(folder)" if p.is_dir() else f"{p.stat().st_size} bytes")
print([p.name for p in sorted(d.glob("data/*.csv"))])
```

*You should see:*

```text
project/data (folder)
project/data/a.csv 4 bytes
project/data/b.csv 4 bytes
project/readme.md 10 bytes
['a.csv', 'b.csv']
```

*(`glob("*.csv")` finds matching names in one folder; `rglob` searches every folder below)*
