---
id: py-cli-practice
title: practice
part: python
chapter: 39
minutes: 12
needs: [py-notes]
optional: no
---

**39.1 ★ Add an option.** Give `greet.py` a `--lang` option with `choices=["en", "ar"]` that greets with `hello` or
`marhaba`.

<!-- solution 39.1 -->
```python
import argparse

p = argparse.ArgumentParser()
p.add_argument("name")
p.add_argument("--lang", choices=["en", "ar"], default="en")
for argv in (["Sara"], ["Sara", "--lang", "ar"]):
    args = p.parse_args(argv)
    print({"en": "hello", "ar": "marhaba"}[args.lang], args.name)
```

*You should see:*

```text
hello Sara
marhaba Sara
```
<!-- /solution -->

**39.2 ★ Exit codes.** A script `isnum.py X` that exits 0 if X is a number and 1 if not; try it with `&& echo yes`.

<!-- solution 39.2 -->
```python
import sys

def main(argv):
    try:
        float(argv[0])
        return 0
    except (ValueError, IndexError):
        return 1

print(main(["3.5"]), main(["abc"]))
```

*You should see:*

```text
0 1
```
<!-- /solution -->

**39.3 ★★ Sum from a pipe.** `sumcol.py` reads numbers from stdin, one per line, and prints their sum, skipping blank lines.
`seq 1 100 | uv run sumcol.py` should print `5050`.

<!-- solution 39.3 -->
```python
import io, sys

def sumcol(stream):
    return sum(float(line) for line in stream if line.strip())

print(sumcol(io.StringIO("".join(f"{i}\n" for i in range(1, 101)) + "\n")))
```

*You should see:*

```text
5050.0
```
<!-- /solution -->

**39.4 ★★ Many files.** Give `count.py` a `--words` flag that counts words instead of lines, and a total line when
given two or more files.

<!-- solution 39.4 -->
```python
import argparse, io

def count(files, words=False):
    total = 0
    for name, f in files:
        n = sum(len(l.split()) if words else 1 for l in f)
        total += n
        print(f"{n:>6} {name}")
    if len(files) > 1:
        print(f"{total:>6} total")

count([("a", io.StringIO("x y\nz\n")), ("b", io.StringIO("w\n"))], words=True)
```

*You should see:*

```text
     3 a
     1 b
     4 total
```
<!-- /solution -->
