---
id: py-dataclasses
title: dataclasses
part: python
chapter: 34
minutes: 6
needs: [py-special]
optional: no
---

## 34.5 dataclasses: the short way

Most classes start as "a few fields, with a nice `repr` and `==`". `@dataclass` writes
`__init__`, `__repr__` and `__eq__` for you from the fields you list:

```python
from dataclasses import dataclass, field

@dataclass
class Item:
    name: str
    price: float
    count: int = 1

    def cost(self):
        return self.price * self.count

@dataclass
class Basket:
    items: list[Item] = field(default_factory=list)

    def total(self):
        return sum(i.cost() for i in self.items)

b = Basket()
b.items.append(Item("rice", 7.25, 3))
b.items.append(Item("tea", 12.5))
print(b.items[0])
print(b.total())
print(Item("tea", 12.5) == Item("tea", 12.5))
```

*You should see:*

```text
Item(name='rice', price=7.25, count=3)
34.25
True
```

*(`field(default_factory=list)` gives each basket its own new list; a plain `= []` would be
one list shared by every basket — Python refuses it)*

`@dataclass(frozen=True)` makes objects that cannot change — safe as dictionary keys:

```python
from dataclasses import dataclass

@dataclass(frozen=True)
class Point:
    x: float
    y: float

p = Point(1, 2)
print(p, {p: "home"})
p.x = 5
```

*Python says:*

```text
Point(x=1, y=2) {Point(x=1, y=2): 'home'}
Traceback (most recent call last):
  File "example.py", line 10, in <module>
    p.x = 5
    ^^^
  File "<string>", line 16, in __setattr__
dataclasses.FrozenInstanceError: cannot assign to field 'x'
```
