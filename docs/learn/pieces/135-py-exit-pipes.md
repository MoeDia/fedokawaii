---
id: py-exit-pipes
title: exit codes, the error stream, pipes
part: python
chapter: 39
minutes: 6
needs: [py-argparse]
optional: no
---

## 39.3 exit codes and the error stream

A program tells the shell how it went with its **exit code**: `0` for success, anything else
for failure. Scripts and `&&` rely on it. Errors go to the **error stream** (`stderr`), so they
are not mixed into output piped to the next program:

`check_age.py`:

```python
import sys

def main() -> int:
    if len(sys.argv) != 2 or not sys.argv[1].isdigit():
        print("usage: check_age.py AGE", file=sys.stderr)
        return 2
    age = int(sys.argv[1])
    print("adult" if age >= 18 else "minor")
    return 0

if __name__ == "__main__":
    sys.exit(main())
```

```text
$ uv run check_age.py 20; echo "exit code $?"
adult
exit code 0
$ uv run check_age.py old; echo "exit code $?"
usage: check_age.py AGE
exit code 2
```

## 39.4 pipes: stdin and stdout

A good tool reads from a pipe when given no file, so it fits between others
(`cat file | yourtool | sort`). `sys.stdin` is the pipe coming in, line by line:

`upper.py`:

```python
import sys

for line in sys.stdin:
    sys.stdout.write(line.upper())
```

```text
$ printf 'tea\nrice\n' | uv run upper.py | sort
RICE
TEA
```

`argparse.FileType`, or the convention `-` for "the pipe", lets one tool do both:

`count.py`:

```python
import argparse, sys

p = argparse.ArgumentParser()
p.add_argument("files", nargs="*", default=["-"])
args = p.parse_args()
for name in args.files:
    f = sys.stdin if name == "-" else open(name, encoding="utf-8")
    print(f"{sum(1 for _ in f):>6} {name}")
```

```text
$ printf 'a\nb\nc\n' > three.txt
$ uv run count.py three.txt
     3 three.txt
$ cat three.txt three.txt | uv run count.py
     6 -
```
