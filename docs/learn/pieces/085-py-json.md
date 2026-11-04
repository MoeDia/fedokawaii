---
id: py-json
title: JSON, and common mistakes
part: python
chapter: 31
minutes: 5
needs: [py-csv]
optional: no
---

## 31.6 JSON: nested data in text

**JSON** is how programs exchange data — web APIs, settings, Claude's tool calls. It looks
almost exactly like Python's dictionaries and lists, and `json` turns one into the other:

```python
import json
from pathlib import Path

settings = {"theme": "dark", "font_size": 12, "langs": ["python", "rust"], "beta": False}
Path("settings.json").write_text(json.dumps(settings, indent=2), encoding="utf-8")
print(Path("settings.json").read_text(encoding="utf-8"))
loaded = json.loads(Path("settings.json").read_text(encoding="utf-8"))
print(loaded["langs"][0], loaded == settings)
```

*You should see:*

```text
{
  "theme": "dark",
  "font_size": 12,
  "langs": [
    "python",
    "rust"
  ],
  "beta": false
}
python True
```

*(`dumps` — *dump to string* — makes JSON text; `loads` reads it back. Note `False` in Python is
`false` in JSON)*

## 31.7 common mistakes

**1. A file that is not there.**

```python
from pathlib import Path
print(Path("nope.txt").read_text())
```

*Python says:*

```text
Traceback (most recent call last):
  File "example.py", line 2, in <module>
    print(Path("nope.txt").read_text())
          ~~~~~~~~~~~~~~~~~~~~~~~~~~^^
  File "/root/.local/share/uv/python/cpython-3.14.6-linux-x86_64-gnu/lib/python3.14/pathlib/__init__.py", line 787, in read_text
    with self.open(mode='r', encoding=encoding, errors=errors, newline=newline) as f:
         ~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/root/.local/share/uv/python/cpython-3.14.6-linux-x86_64-gnu/lib/python3.14/pathlib/__init__.py", line 771, in open
    return io.open(self, mode, buffering, encoding, errors, newline)
           ~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
FileNotFoundError: [Errno 2] No such file or directory: 'nope.txt'
```

Check first with `.exists()`, or catch the error (chapter 32).

**2. A path relative to the wrong folder.** `Path("data.csv")` means *in the folder the program
was started from*, not the folder the script is in. For a file next to the script, use
`Path(__file__).parent / "data.csv"`.

**3. Forgetting that CSV values are text.** `row["age"] + 1` fails; `int(row["age"]) + 1`
works.

**4. Forgetting `encoding="utf-8"`.** On Linux it is usually the default, but not everywhere;
writing it costs nothing and makes your program work on every system.
