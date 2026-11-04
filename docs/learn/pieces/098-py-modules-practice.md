---
id: py-modules-practice
title: practice
part: python
chapter: 33
minutes: 18
needs: [py-expenses]
optional: no
---

**33.1 ★ Dice.** With `random.randint`, roll two dice ten times and print each pair and its sum (seed it with
`random.seed(3)` to compare).

<!-- solution 33.1 -->
```python
import random

random.seed(3)
for _ in range(10):
    a, b = random.randint(1, 6), random.randint(1, 6)
    print(a, b, a + b)
```

*You should see:*

```text
2 5 7
5 2 7
3 5 8
4 6 10
5 1 6
5 1 6
4 3 7
5 2 7
2 6 8
4 5 9
```
<!-- /solution -->

**33.2 ★ Days to go.** With `datetime.date`, print how many days from today to 31 December this year.

<!-- solution 33.2 -->
```python
from datetime import date

today = date(2026, 10, 21)   # date.today() in your version
print((date(today.year, 12, 31) - today).days)
```

*You should see:*

```text
71
```
<!-- /solution -->

**33.3 ★ Statistics.** Use `statistics.mean`, `median` and `stdev` on `[2, 4, 4, 4, 5, 5, 7, 9]`.

<!-- solution 33.3 -->
```python
import statistics as st

data = [2, 4, 4, 4, 5, 5, 7, 9]
print(st.mean(data), st.median(data), round(st.stdev(data), 3))
```

*You should see:*

```text
5 4.5 2.138
```
<!-- /solution -->

**33.4 ★★ Your module.** Make `textutil.py` with `vowels(s)` and `words(s)`, a `__main__` demo, and use both from
`main.py`.

<!-- solution 33.4 -->
```python
from pathlib import Path
import subprocess, sys

Path("textutil.py").write_text('''def vowels(s):
    return sum(ch in "aeiou" for ch in s.lower())

def words(s):
    return len(s.split())

if __name__ == "__main__":
    print("demo:", vowels("Fedora"), words("a b c"))
''')
Path("main2.py").write_text('from textutil import vowels, words\nprint(vowels("Sharjah"), words("one two"))\n')
print(subprocess.run([sys.executable, "textutil.py"], capture_output=True, text=True).stdout, end="")
print(subprocess.run([sys.executable, "main2.py"], capture_output=True, text=True).stdout, end="")
```

*You should see:*

```text
demo: 3 3
2 2
```
<!-- /solution -->

**33.5 ★★ Counter and defaultdict.** Count the letters of `"hello world"` with `Counter`, then group words by first letter with
`collections.defaultdict(list)`.

<!-- solution 33.5 -->
```python
from collections import Counter, defaultdict

print(Counter("hello world").most_common(3))
groups = defaultdict(list)
for w in "tea toast rice rye milk".split():
    groups[w[0]].append(w)
print(dict(groups))
```

*You should see:*

```text
[('l', 3), ('o', 2), ('h', 1)]
{'t': ['tea', 'toast'], 'r': ['rice', 'rye'], 'm': ['milk']}
```
<!-- /solution -->

**33.6 ★★ A project of your own.** `uv init quotes`, `uv add --dev pytest`, write `main.py` that prints a random line from
`quotes.txt`. Check `pyproject.toml` lists pytest under the dev group, and commit with
`uv.lock`.

<!-- solution 33.6 -->
```text
$ uv init quotes && cd quotes
$ uv add --dev pytest
$ printf 'Simple is better than complex.\nReadability counts.\n' > quotes.txt
$ cat > main.py <<'EOF'
import random
from pathlib import Path
print(random.choice(Path("quotes.txt").read_text().splitlines()))
EOF
$ uv run main.py
Readability counts.
$ grep -A2 dependency-groups pyproject.toml
[dependency-groups]
dev = [
    "pytest>=9.1.1",
$ git add -A && git commit -m "quotes: a random line"
```
*(not run here line by line; the same commands are run in 33.5 and chapter 35)*
<!-- /solution -->
