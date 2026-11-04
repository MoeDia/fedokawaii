---
id: py-modules-projects
title: projects
part: python
chapter: 33
minutes: 180
needs: [py-modules-practice]
optional: yes
---

**33.7 ★★★ A web request.** With `urllib.request` and `json`, fetch `https://api.github.com/repos/python/cpython` and print
its stars and its description. (Needs the network.)

<!-- solution 33.7 -->
```python
import json
from urllib.request import urlopen

with urlopen("https://api.github.com/repos/python/cpython", timeout=10) as r:
    repo = json.load(r)
print(repo["stargazers_count"], "stars —", repo["description"])
```
*(the numbers change daily, so no output is printed here; you should see a number of stars,
then "The Python programming language")*
<!-- /solution -->

**33.8 ★★★ SQLite.** With `sqlite3`, make a table `expenses(date, category, amount)` in `money.db`, insert three
rows, and print the total per category with `GROUP BY`.

<!-- solution 33.8 -->
```python
import sqlite3

db = sqlite3.connect(":memory:")   # "money.db" keeps it on disk
db.execute("CREATE TABLE expenses (date TEXT, category TEXT, amount REAL)")
db.executemany("INSERT INTO expenses VALUES (?, ?, ?)",
               [("2026-10-21", "food", 32.5), ("2026-10-21", "taxi", 18), ("2026-10-22", "food", 12.25)])
for cat, total in db.execute("SELECT category, SUM(amount) FROM expenses GROUP BY category ORDER BY category"):
    print(cat, total)
```

*You should see:*

```text
food 44.75
taxi 18.0
```
<!-- /solution -->

**33.9 ★★★★ Back up a folder.** Write `backup.py SRC DEST`: copy every file of SRC (keeping sub-folders) into a new folder
`DEST/SRC-YYYY-MM-DD`, skip files over 10 MB, and print how many were copied and skipped. Use
`pathlib`, `shutil.copy2` and `datetime.date.today()`.

<!-- solution 33.9 -->
```python
import shutil
from datetime import date
from pathlib import Path

def backup(src, dest, limit=10 * 1024 * 1024, today=None):
    src, dest = Path(src), Path(dest)
    target = dest / f"{src.name}-{(today or date.today()).isoformat()}"
    copied = skipped = 0
    for p in src.rglob("*"):
        if not p.is_file():
            continue
        if p.stat().st_size > limit:
            skipped += 1
            continue
        out = target / p.relative_to(src)
        out.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(p, out)
        copied += 1
    return target, copied, skipped

Path("docs/sub").mkdir(parents=True, exist_ok=True)
Path("docs/a.txt").write_text("a"); Path("docs/sub/b.txt").write_text("b")
Path("docs/big.bin").write_bytes(b"0" * 2000)
print(backup("docs", "backups", limit=1000, today=date(2026, 10, 21)))
```

*You should see:*

```text
(PosixPath('backups/docs-2026-10-21'), 2, 1)
```
<!-- /solution -->
