---
id: py-files-projects
title: projects
part: python
chapter: 31
minutes: 180
needs: [py-files-practice]
optional: yes
---

**31.7 ★★★ Biggest files.** List the three biggest files under a folder (`rglob("*")`, `.stat().st_size`), biggest first.

<!-- solution 31.7 -->
```python
from pathlib import Path

d = Path("sizes")
d.mkdir(exist_ok=True)
for name, n in [("a.txt", 10), ("b.txt", 300), ("c.txt", 50), ("d.txt", 7)]:
    (d / name).write_text("x" * n)
files = [p for p in d.rglob("*") if p.is_file()]
for p in sorted(files, key=lambda p: p.stat().st_size, reverse=True)[:3]:
    print(p.name, p.stat().st_size)
```

*You should see:*

```text
b.txt 300
c.txt 50
a.txt 10
```
<!-- /solution -->

**31.8 ★★★ CSV to JSON.** Turn `people.csv` (name, city, age) into a JSON list of dictionaries, with `age` as a number.

<!-- solution 31.8 -->
```python
import csv, json
from pathlib import Path

Path("people.csv").write_text("name,city,age\nSara,Sharjah,31\nOmar,Dubai,28\n", encoding="utf-8")
with open("people.csv", encoding="utf-8", newline="") as f:
    people = list(csv.DictReader(f))
for p in people:
    p["age"] = int(p["age"])
print(json.dumps(people, indent=1))
```

*You should see:*

```text
[
 {
  "name": "Sara",
  "city": "Sharjah",
  "age": 31
 },
 {
  "name": "Omar",
  "city": "Dubai",
  "age": 28
 }
]
```
<!-- /solution -->

**31.9 ★★★★ Find in files.** Write `grep(word, folder)`: every `.txt` file under the folder, every line containing the word
(any case), printed as `file:line: text` — your own small ripgrep.

<!-- solution 31.9 -->
```python
from pathlib import Path

d = Path("notes")
d.mkdir(exist_ok=True)
(d / "a.txt").write_text("buy rice\ncall Omar\n", encoding="utf-8")
(d / "b.txt").write_text("Rice cooker broken\n", encoding="utf-8")

def grep(word, folder):
    for p in sorted(Path(folder).rglob("*.txt")):
        with open(p, encoding="utf-8") as f:
            for n, line in enumerate(f, 1):
                if word.lower() in line.lower():
                    print(f"{p}:{n}: {line.rstrip()}")

grep("rice", "notes")
```

*You should see:*

```text
notes/a.txt:1: buy rice
notes/b.txt:1: Rice cooker broken
```
<!-- /solution -->
