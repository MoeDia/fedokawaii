---
id: py-argparse
title: arguments and argparse
part: python
chapter: 39
minutes: 6
needs: [py-modules-practice, py-tests-practice, py-generators-practice]
optional: no
---

> **In this chapter**
>
> - a real command-line tool with `argparse`: options, help, exit codes
> - reading from a pipe, writing to another
> - a package layout with `src/`, an entry point, and `uv tool install`
> - the checkpoint for level 5: a command of your own, installed

## 39.1 a program that takes arguments

A command-line program gets its words from the command line: `sys.argv` is the list of them,
the program's own name first:

`args.py`:

```python
import sys
print(sys.argv)
```

```text
$ uv run args.py hello 42 --loud
['args.py', 'hello', '42', '--loud']
```

Parsing that list by hand gets messy fast. `argparse` does it, and writes `--help` for you.

## 39.2 argparse

`greet.py`:

```python
"""greet — say hello, a number of times."""
import argparse

def main() -> None:
    parser = argparse.ArgumentParser(description="Say hello.")
    parser.add_argument("name", help="who to greet")
    parser.add_argument("-n", "--times", type=int, default=1, help="how many times (default 1)")
    parser.add_argument("--loud", action="store_true", help="in capitals")
    args = parser.parse_args()
    text = f"hello, {args.name}"
    for _ in range(args.times):
        print(text.upper() if args.loud else text)

if __name__ == "__main__":
    main()
```

```text
$ uv run greet.py Sara
hello, Sara
$ uv run greet.py Sara -n 2 --loud
HELLO, SARA
HELLO, SARA
$ uv run greet.py --help
usage: greet.py [-h] [-n TIMES] [--loud] name

Say hello.

positional arguments:
  name               who to greet

options:
  -h, --help         show this help message and exit
  -n, --times TIMES  how many times (default 1)
  --loud             in capitals
$ uv run greet.py
usage: greet.py [-h] [-n TIMES] [--loud] name
greet.py: error: the following arguments are required: name
```

| `add_argument(…)` | Makes |
|---|---|
| `"name"` | a positional argument: required, in order |
| `"-n", "--times", type=int` | an option with a value, changed to an int |
| `default=1` | its value when left out |
| `action="store_true"` | a flag: `True` when given |
| `choices=["a", "b"]` | only these values |
| `nargs="+"` · `nargs="*"` | one or more · any number of values, as a list |
