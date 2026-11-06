---
id: py-classes-projects
title: projects
part: python
chapter: 34
minutes: 180
needs: [py-classes-practice]
optional: yes
---

**34.7 ★★★ A stack.** `Stack` with `push`, `pop` (raising `IndexError("empty stack")` when empty), `peek`, and
`__len__`. Use it to check that brackets in `"(a[b]{c})"` are balanced.

<!-- solution 34.7 -->
```python
class Stack:
    def __init__(self):
        self._items = []
    def push(self, x):
        self._items.append(x)
    def pop(self):
        if not self._items:
            raise IndexError("empty stack")
        return self._items.pop()
    def peek(self):
        return self._items[-1] if self._items else None
    def __len__(self):
        return len(self._items)

def balanced(text):
    pairs = {")": "(", "]": "[", "}": "{"}
    s = Stack()
    for ch in text:
        if ch in "([{":
            s.push(ch)
        elif ch in pairs:
            if s.peek() != pairs[ch]:
                return False
            s.pop()
    return len(s) == 0

print(balanced("(a[b]{c})"), balanced("(a[b)]"), balanced("(("))
```

*You should see:*

```text
True False False
```
<!-- /solution -->

**34.8 ★★★ Money that refuses to mix.** Make `Money.__add__` raise `ValueError` when the currencies differ, and `__mul__` for
`Money(10) * 3`.

<!-- solution 34.8 -->
```python
class Money:
    def __init__(self, amount, currency="AED"):
        self.amount, self.currency = amount, currency
    def __add__(self, other):
        if other.currency != self.currency:
            raise ValueError(f"cannot add {self.currency} and {other.currency}")
        return Money(self.amount + other.amount, self.currency)
    def __mul__(self, n):
        return Money(self.amount * n, self.currency)
    def __str__(self):
        return f"{self.amount:.2f} {self.currency}"

print(Money(10) * 3, Money(1) + Money(2))
try:
    Money(1) + Money(1, "USD")
except ValueError as e:
    print(e)
```

*You should see:*

```text
30.00 AED 3.00 AED
cannot add AED and USD
```
<!-- /solution -->

**34.9 ★★★★ An inventory.** `Product` (a frozen dataclass: name, price) and `Inventory` holding a dictionary product → count,
with `add(product, n)`, `remove(product, n)` (an error if too few), `value()` (the total worth)
and `low(limit)` (products below `limit`, sorted by name).

<!-- solution 34.9 -->
```python
from dataclasses import dataclass

@dataclass(frozen=True)
class Product:
    name: str
    price: float

class Inventory:
    def __init__(self):
        self.stock = {}
    def add(self, p, n=1):
        self.stock[p] = self.stock.get(p, 0) + n
    def remove(self, p, n=1):
        if self.stock.get(p, 0) < n:
            raise ValueError(f"only {self.stock.get(p, 0)} {p.name} left")
        self.stock[p] -= n
    def value(self):
        return sum(p.price * n for p, n in self.stock.items())
    def low(self, limit):
        return sorted((p.name for p, n in self.stock.items() if n < limit))

tea, rice = Product("tea", 12.5), Product("rice", 7.25)
inv = Inventory()
inv.add(tea, 4); inv.add(rice, 10); inv.remove(tea, 3)
print(inv.value(), inv.low(5))
try:
    inv.remove(tea, 2)
except ValueError as e:
    print(e)
```

*You should see:*

```text
85.0 ['tea']
only 1 tea left
```
<!-- /solution -->
