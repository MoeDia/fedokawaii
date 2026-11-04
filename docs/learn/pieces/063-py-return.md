---
id: py-return
title: return, defaults, keyword arguments
part: python
chapter: 28
minutes: 6
needs: [py-function]
optional: no
---

## 28.3 return: a value coming back

`print` shows a value to the person; `return` hands it back to the code that called, so it
can be used again. Most functions should `return`, not print:

```python
def area(width, height):
    return width * height

a = area(3, 4)
print(a)
print(area(2, 5) + area(1, 1))
```

*You should see:*

```text
12
11
```

`return` ends the function at once. A function with no `return` gives back `None` — Python's
value for *nothing*:

```python
def sign(n):
    if n > 0:
        return "positive"
    if n < 0:
        return "negative"
    return "zero"

def shout(text):
    print(text.upper())

print(sign(5), sign(-2), sign(0))
result = shout("hi")
print(result)
```

*You should see:*

```text
positive negative zero
HI
None
```

A function can return several values at once, as a tuple (chapter 29):

```python
def min_max(a, b, c):
    return min(a, b, c), max(a, b, c)

low, high = min_max(7, 2, 9)
print(low, high)
```

*You should see:*

```text
2 9
```

## 28.4 defaults and keyword arguments

A parameter can have a **default**: the value it takes when the call leaves it out.

```python
def price_with_vat(price, rate=0.05):
    return round(price * (1 + rate), 2)

print(price_with_vat(100))
print(price_with_vat(100, 0.15))
print(price_with_vat(rate=0.2, price=50))
```

*You should see:*

```text
105.0
115.0
60.0
```

Naming the argument in the call (`rate=0.2`) is a **keyword argument**: clearer to read, and
the order no longer matters. Python's own functions use them all the time:
`print(..., sep="-")`, `sorted(..., reverse=True)`.
