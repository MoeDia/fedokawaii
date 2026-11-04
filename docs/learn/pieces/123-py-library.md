---
id: py-library
title: checkpoint: a tested, typed library
part: python
chapter: 36
minutes: 40
needs: [py-generic]
optional: no
---

## 36.9 checkpoint project — a tested, typed library

Level 4 in one: a small library with a class, type hints everywhere, tests for every function,
and a clean type check. The subject is a **grade book**.

`gradebook.py`:

```python
"""A grade book: students, their marks, and averages."""
from dataclasses import dataclass, field
from statistics import mean

@dataclass
class Student:
    name: str
    marks: dict[str, float] = field(default_factory=dict)

    def average(self) -> float | None:
        return mean(self.marks.values()) if self.marks else None

class GradeBook:
    def __init__(self) -> None:
        self.students: dict[str, Student] = {}

    def add(self, name: str) -> Student:
        if name in self.students:
            raise ValueError(f"{name} is already in the book")
        s = self.students[name] = Student(name)
        return s

    def mark(self, name: str, subject: str, value: float) -> None:
        if not 0 <= value <= 100:
            raise ValueError(f"a mark is 0-100, got {value}")
        self.students[name].marks[subject] = value

    def ranking(self) -> list[tuple[str, float]]:
        scored = [(s.name, a) for s in self.students.values() if (a := s.average()) is not None]
        return sorted(scored, key=lambda pair: pair[1], reverse=True)
```

`test_gradebook.py`:

```python
import pytest
from gradebook import GradeBook

@pytest.fixture
def book() -> GradeBook:
    b = GradeBook()
    for name in ("Sara", "Omar", "Lina"):
        b.add(name)
    b.mark("Sara", "maths", 90); b.mark("Sara", "art", 80)
    b.mark("Omar", "maths", 95)
    return b

def test_average(book: GradeBook) -> None:
    assert book.students["Sara"].average() == 85

def test_no_marks_no_average(book: GradeBook) -> None:
    assert book.students["Lina"].average() is None

def test_ranking_skips_unmarked(book: GradeBook) -> None:
    assert book.ranking() == [("Omar", 95), ("Sara", 85)]

def test_duplicate_name(book: GradeBook) -> None:
    with pytest.raises(ValueError, match="already"):
        book.add("Sara")

@pytest.mark.parametrize("bad", [-1, 101])
def test_mark_range(book: GradeBook, bad: float) -> None:
    with pytest.raises(ValueError, match="0-100"):
        book.mark("Sara", "maths", bad)
```

```text
$ uv run pytest -q test_gradebook.py
......                                                                   [100%]
6 passed in 0.01s
$ uvx mypy gradebook.py test_gradebook.py
Success: no issues found in 2 source files
```

*(`(a := s.average())` is the *walrus* operator: it names a value inside an expression, so the
average is worked out once)*

> **Checkpoint.** Add `subject_average(subject) -> float | None` and `report() -> str` (a table of
> every student and their average, `—` for none). Tests first; then make pytest and mypy both
> clean. Level 4 done: you can now write code other people can trust.
