---
id: py-calling
title: functions calling functions
part: python
chapter: 28
minutes: 4
needs: [py-scope]
optional: no
---

## 28.7 functions calling functions

Big programs are small functions that call each other. Each one does one thing, has a name
that says what, and can be checked on its own:

```python
def is_vowel(ch):
    return ch.lower() in "aeiou"

def count_vowels(text):
    n = 0
    for ch in text:
        if is_vowel(ch):
            n += 1
    return n

def describe(word):
    return f"{word}: {count_vowels(word)} vowels, {len(word)} letters"

print(describe("Fedokawaii"))
print(describe("rhythm"))
```

*You should see:*

```text
Fedokawaii: 6 vowels, 10 letters
rhythm: 0 vowels, 6 letters
```

A function may even call itself: that is **recursion**. Each call works on a smaller problem
until one is so small it is answered directly:

```python
def factorial(n):
    if n <= 1:
        return 1
    return n * factorial(n - 1)

print(factorial(5))
print(factorial(20))
```

*You should see:*

```text
120
2432902008176640000
```
