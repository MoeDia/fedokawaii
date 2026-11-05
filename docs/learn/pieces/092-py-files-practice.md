---
id: py-files-practice
title: practice
part: python
chapter: 31
minutes: 18
needs: [py-json]
optional: no
---

**31.1 ★ Write and read.** Write three lines of your choice into `me.txt`, then read it back and print the number of
characters.

<!-- solution 31.1 -->
```python
from pathlib import Path

p = Path("me.txt")
p.write_text("Mohamed\nSharjah\nPython\n", encoding="utf-8")
print(len(p.read_text(encoding="utf-8")))
```

*You should see:*

```text
23
```
<!-- /solution -->

**31.2 ★ Number the lines.** Print every line of a file with its line number in front, like `cat -n`.

<!-- solution 31.2 -->
```python
from pathlib import Path

Path("poem.txt").write_text("old pond\na frog jumps in\nthe sound of water\n", encoding="utf-8")
with open("poem.txt", encoding="utf-8") as f:
    for i, line in enumerate(f, 1):
        print(f"{i:>3}  {line.rstrip()}")
```

*You should see:*

```text
  1  old pond
  2  a frog jumps in
  3  the sound of water
```
<!-- /solution -->

**31.3 ★ A diary.** Append today's line to `diary.txt` each run (mode `"a"`); run it twice and print the file.

<!-- solution 31.3 -->
```python
from pathlib import Path

for entry in ["2026-10-21 learnt files", "2026-10-22 learnt CSV"]:
    with open("diary.txt", "a", encoding="utf-8") as f:
        f.write(entry + "\n")
print(Path("diary.txt").read_text(encoding="utf-8"), end="")
```

*You should see:*

```text
2026-10-21 learnt files
2026-10-22 learnt CSV
```
<!-- /solution -->

**31.4 ★★ Word count.** Write `wc(path)` returning lines, words and characters of a file, as a tuple.

<!-- solution 31.4 -->
```python
from pathlib import Path

def wc(path):
    text = Path(path).read_text(encoding="utf-8")
    return len(text.splitlines()), len(text.split()), len(text)

Path("t.txt").write_text("one two\nthree\n", encoding="utf-8")
print(wc("t.txt"))
```

*You should see:*

```text
(2, 3, 14)
```
<!-- /solution -->

**31.5 ★★ Average from a CSV.** Make `marks.csv` with `name,mark` rows and print the average mark.

<!-- solution 31.5 -->
```python
import csv
from pathlib import Path

Path("marks.csv").write_text("name,mark\nSara,88\nOmar,92\nLina,79\n", encoding="utf-8")
with open("marks.csv", encoding="utf-8", newline="") as f:
    marks = [int(r["mark"]) for r in csv.DictReader(f)]
print(round(sum(marks) / len(marks), 1))
```

*You should see:*

```text
86.3
```
<!-- /solution -->

**31.6 ★★ Settings with defaults.** Load `settings.json` if it exists, otherwise use `{"theme": "dark"}`; set `"font_size"` to 14
and save it back.

<!-- solution 31.6 -->
```python
import json
from pathlib import Path

p = Path("my-settings.json")
settings = json.loads(p.read_text(encoding="utf-8")) if p.exists() else {"theme": "dark"}
settings["font_size"] = 14
p.write_text(json.dumps(settings, indent=2), encoding="utf-8")
print(p.read_text(encoding="utf-8"))
```

*You should see:*

```text
{
  "theme": "dark",
  "font_size": 14
}
```
<!-- /solution -->
