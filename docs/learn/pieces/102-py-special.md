---
id: py-special
title: special methods
part: python
chapter: 34
minutes: 4
needs: [py-account]
optional: no
---

## 34.4 special methods: print, ==, +

Methods with double underscores (*dunder* methods) let your objects work with Python's own
signs and functions:

```python
class Money:
    def __init__(self, amount, currency="AED"):
        self.amount = amount
        self.currency = currency

    def __repr__(self):
        return f"Money({self.amount}, {self.currency!r})"

    def __str__(self):
        return f"{self.amount:.2f} {self.currency}"

    def __eq__(self, other):
        return self.amount == other.amount and self.currency == other.currency

    def __add__(self, other):
        return Money(self.amount + other.amount, self.currency)

a = Money(10)
b = Money(5.5)
print(a + b)
print(repr(a + b))
print(a == Money(10), a == b)
```

*You should see:*

```text
15.50 AED
Money(15.5, 'AED')
True False
```

| Method | Used by |
|---|---|
| `__init__` | making the object |
| `__repr__` | the prompt, `repr()`, lists: an exact description, for programmers |
| `__str__` | `print`, f-strings: a friendly one |
| `__eq__` · `__lt__` | `==` · `<` (and so `sorted`) |
| `__add__` | `+` |
| `__len__` | `len()` |
