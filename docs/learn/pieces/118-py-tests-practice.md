---
id: py-tests-practice
title: practice
part: python
chapter: 35
minutes: 18
needs: [py-tdd]
optional: no
---

**35.1 ★ Your first test file.** Test `is_even` (chapter 28) with three asserts in one test, and run pytest.

<!-- solution 35.1 -->
```python
def is_even(n):
    return n % 2 == 0

def test_is_even():
    assert is_even(2)
    assert not is_even(7)
    assert is_even(0)

test_is_even()
print("passed")
```

*You should see:*

```text
passed
```
<!-- /solution -->

**35.2 ★ Parametrize it.** Rewrite the test with `@pytest.mark.parametrize` and five cases.

<!-- solution 35.2 -->
```python
import pytest

@pytest.mark.parametrize("n, expected", [(0, True), (1, False), (2, True), (-3, False), (10, True)])
def test_is_even(n, expected):
    assert is_even(n) == expected
```
*(pytest reports `5 passed`)*
<!-- /solution -->

**35.3 ★ Expect an error.** Test that `int("x")` raises `ValueError`, with `pytest.raises`.

<!-- solution 35.3 -->
```python
import pytest

def test_not_a_number():
    with pytest.raises(ValueError):
        int("x")
```
<!-- /solution -->

**35.4 ★★ Test the Account.** Tests for chapter 34's `Account`: a deposit, a withdrawal, and that overdrawing raises with
`match="available"`.

<!-- solution 35.4 -->
```python
import pytest

class Account:
    def __init__(self, owner, balance=0):
        self.owner, self.balance = owner, balance
    def deposit(self, amount):
        self.balance += amount
    def withdraw(self, amount):
        if amount > self.balance:
            raise ValueError(f"only {self.balance} available")
        self.balance -= amount

def test_deposit():
    a = Account("x", 10); a.deposit(5); assert a.balance == 15

def test_withdraw():
    a = Account("x", 10); a.withdraw(4); assert a.balance == 6

def test_overdraw():
    with pytest.raises(ValueError, match="available"):
        Account("x", 10).withdraw(11)

for t in (test_deposit, test_withdraw, test_overdraw):
    t()
print("3 passed")
```

*You should see:*

```text
3 passed
```
<!-- /solution -->

**35.5 ★★ Files with tmp_path.** Test the `wc(path)` function of exercise 31.4 with `tmp_path`: an empty file, and a file of two
lines.

<!-- solution 35.5 -->
```python
from wc import wc

def test_empty(tmp_path):
    f = tmp_path / "e.txt"; f.write_text("")
    assert wc(f) == (0, 0, 0)

def test_two_lines(tmp_path):
    f = tmp_path / "t.txt"; f.write_text("one two\nthree\n")
    assert wc(f) == (2, 3, 14)
```
<!-- /solution -->

**35.6 ★★ Find the bug with a test.** This function should return the largest number, but has a bug. Write tests until one fails,
then fix it: `def biggest(nums): m = 0; for n in nums: m = max(m, n); return m`.

<!-- solution 35.6 -->
```python
def biggest_buggy(nums):
    m = 0
    for n in nums:
        m = max(m, n)
    return m

def biggest(nums):
    m = nums[0]
    for n in nums[1:]:
        m = max(m, n)
    return m

print(biggest_buggy([-5, -2, -9]), "← wrong: all negative")
assert biggest([-5, -2, -9]) == -2
assert biggest([3, 9, 4]) == 9
print("fixed")
```

*You should see:*

```text
0 ← wrong: all negative
fixed
```
<!-- /solution -->
