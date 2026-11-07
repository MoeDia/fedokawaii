---
id: tests-first
title: A test before the code
part: 2
minutes: 15
needs: [git-remote]
---
## idea
A test is a few lines that say what a function must return and shout when it does not. Write it before the function. It fails first, which proves the test can fail, and then your code makes it pass. The tool is the word assert: assert total([1, 2]) == 3 does nothing when true and stops with an AssertionError when false. When it passes, you know the function works today, and every day after.

## exercise
In ~/dojo/test write test.py first. It imports total from total, asserts that total([1, 2, 3]) is 6 and total([]) is 0, then prints ok. Run it and see it fail. Then write total.py with a function total(numbers) that adds them up, and run test.py again.

## check
```check
run: python3 test.py
in: test
expect: ok
```

## answer
Both asserts hold, so the last line runs and prints ok.

```file total.py
def total(numbers):
    result = 0
    for n in numbers:
        result += n
    return result
```

```file test.py
from total import total

assert total([1, 2, 3]) == 6
assert total([]) == 0
print("ok")
```
