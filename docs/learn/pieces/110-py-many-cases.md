---
id: py-many-cases
title: many cases, files in tests
part: python
chapter: 35
minutes: 7
needs: [py-failure]
optional: no
---

## 35.5 many cases, one test

`@pytest.mark.parametrize` runs one test with many inputs — each counts as a test of its own,
so a failure names the case:

`test_grade.py`:

```python
import pytest

def grade(score):
    if score >= 90: return "A"
    if score >= 75: return "B"
    if score >= 60: return "C"
    return "F"

@pytest.mark.parametrize("score, expected", [
    (100, "A"), (90, "A"), (89, "B"), (75, "B"), (60, "C"), (59, "F"), (0, "F"),
])
def test_grade(score, expected):
    assert grade(score) == expected
```

```text
$ uv run pytest -v test_grade.py
test_grade.py::test_grade[100-A] PASSED                                  [ 14%]
test_grade.py::test_grade[90-A] PASSED                                   [ 28%]
test_grade.py::test_grade[89-B] PASSED                                   [ 42%]
test_grade.py::test_grade[75-B] PASSED                                   [ 57%]
test_grade.py::test_grade[60-C] PASSED                                   [ 71%]
test_grade.py::test_grade[59-F] PASSED                                   [ 85%]
test_grade.py::test_grade[0-F] PASSED                                    [100%]
============================== 7 passed in 0.01s ===============================
```

*(the header lines pytest prints first — its version, the folder — are left out here. The
edges — 90, 89, 75, 60, 59 — are where mistakes hide; test them)*

## 35.6 files in tests: tmp_path

A test must not touch your real files. Name a parameter `tmp_path` and pytest hands it a new,
empty folder for that test alone — a **fixture**:

`notes.py`:

```python
from pathlib import Path

def add_note(path, text):
    with open(path, "a", encoding="utf-8") as f:
        f.write(f"- {text}\n")

def count_notes(path):
    p = Path(path)
    if not p.exists():
        return 0
    return sum(1 for line in p.read_text(encoding="utf-8").splitlines() if line.startswith("- "))
```

`test_notes.py`:

```python
from notes import add_note, count_notes

def test_new_file_has_none(tmp_path):
    assert count_notes(tmp_path / "n.md") == 0

def test_add_two(tmp_path):
    f = tmp_path / "n.md"
    add_note(f, "buy rice")
    add_note(f, "call Omar")
    assert count_notes(f) == 2
    assert f.read_text(encoding="utf-8").splitlines()[1] == "- call Omar"
```

```text
$ uv run pytest -q test_notes.py
..                                                                       [100%]
2 passed in 0.01s
```
