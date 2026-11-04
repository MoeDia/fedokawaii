---
id: py-modules-mistakes
title: common mistakes
part: python
chapter: 33
minutes: 2
needs: [py-main]
optional: no
---

## 33.6 common mistakes

**1. Naming your file after a module.** A file called `random.py` or `json.py` in your folder
is found *before* the real one, and `import random` imports yours:

`random.py`:

```python
print("this is my random.py, not Python's")
```

```python
import random
print(random.randint(1, 6))
```

*Python says:*

```text
this is my random.py, not Python's
Traceback (most recent call last):
  File "example.py", line 2, in <module>
    print(random.randint(1, 6))
          ^^^^^^^^^^^^^^
AttributeError: module 'random' has no attribute 'randint' (consider renaming 'random.py' since it has the same name as the standard library module named 'random' and prevents importing that standard library module)
```

Rename yours (`dice.py`), and delete any `__pycache__` folder next to it.

```text
$ rm random.py && rm -rf __pycache__
```

**2. A missing package.** `ModuleNotFoundError: No module named 'numpy'` means it is not in
*this* project's venv: `uv add numpy`, and run with `uv run`.

**3. Running with the system's `python3`** instead of `uv run`: the project's packages are not
there. In a uv project, always `uv run`.
