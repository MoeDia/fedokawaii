---
id: tests-pytest
title: pytest runs your tests for you
part: 2
minutes: 15
needs: [tests-first]
---
## idea
Asserts in a script stop at the first failure. pytest finds files named test_something.py, runs every function whose name starts with test_, and reports each one: a dot for a pass, an F for a fail, then what differed. You write plain asserts, nothing to import. Run it from the folder with uvx pytest -q, which fetches pytest for one run and leaves nothing installed. The last line counts the results.

## exercise
In ~/dojo/test, where total.py already is, write test_total.py with two functions. test_adds asserts total([1, 2, 3]) == 6. test_empty asserts total([]) == 0. Start the file with from total import total. Run uvx pytest -q 2>&1 | tail -1.

## check
```check
run: uvx pytest -q 2>&1 | tail -1 | cut -d' ' -f1-2
in: test
expect: 2 passed
```

## answer
Two test functions ran and both passed.

```file test_total.py
from total import total


def test_adds():
    assert total([1, 2, 3]) == 6


def test_empty():
    assert total([]) == 0
```
