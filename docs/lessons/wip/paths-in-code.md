---
id: paths-in-code
title: Paths, now inside a program
part: 2
minutes: 12
needs: [files-writing]
---
## idea
Paths in the shell are text, and in Python too, but pathlib makes them objects you can ask questions. Path("a") / "b.txt" joins with the right slash. The object knows its name, its suffix, its parent, and whether it exists. It can also read and write directly.

```python
from pathlib import Path

p = Path("data") / "notes.txt"
print(p.name, p.suffix, p.parent)
```

That prints notes.txt .txt data. A Path never touches the disk until you ask: exists() and read_text() do.

## exercise
In ~/dojo/py write paths.py. Make p = Path("data") / "list.txt". Print its name, then its suffix, then its parent. Make the folder with p.parent.mkdir(exist_ok=True), write the text hi with p.write_text, and print p.exists() and p.read_text().

## check
```check
run: python3 paths.py
in: py
expect: list.txt
expect: .txt
expect: data
expect: True
expect: hi
```

## answer
exist_ok=True makes the second run harmless.

```file paths.py
from pathlib import Path

p = Path("data") / "list.txt"
print(p.name)
print(p.suffix)
print(p.parent)
p.parent.mkdir(exist_ok=True)
p.write_text("hi")
print(p.exists())
print(p.read_text())
```
