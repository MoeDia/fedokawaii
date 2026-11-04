---
id: py-classes-practice
title: practice
part: python
chapter: 34
minutes: 18
needs: [py-classes-mistakes]
optional: no
---

**34.1 ★ A rectangle.** `Rectangle(width, height)` with `area()` and `perimeter()`.

<!-- solution 34.1 -->
```python
class Rectangle:
    def __init__(self, width, height):
        self.width = width
        self.height = height

    def area(self):
        return self.width * self.height

    def perimeter(self):
        return 2 * (self.width + self.height)

r = Rectangle(3, 4)
print(r.area(), r.perimeter())
```

*You should see:*

```text
12 14
```
<!-- /solution -->

**34.2 ★ A nice print.** Give the rectangle a `__str__` that prints `3×4 rectangle`.

<!-- solution 34.2 -->
```python
class Rectangle:
    def __init__(self, width, height):
        self.width, self.height = width, height

    def __str__(self):
        return f"{self.width}×{self.height} rectangle"

print(Rectangle(3, 4))
```

*You should see:*

```text
3×4 rectangle
```
<!-- /solution -->

**34.3 ★ As a dataclass.** Write the rectangle again as a `@dataclass`, and compare two equal ones with `==`.

<!-- solution 34.3 -->
```python
from dataclasses import dataclass

@dataclass
class Rectangle:
    width: float
    height: float

    def area(self):
        return self.width * self.height

print(Rectangle(3, 4), Rectangle(3, 4) == Rectangle(3, 4), Rectangle(3, 4).area())
```

*You should see:*

```text
Rectangle(width=3, height=4) True 12
```
<!-- /solution -->

**34.4 ★★ A to-do list.** `TodoList` with `add(text)`, `done(n)` and `__str__` that prints `[ ]` / `[x]` lines, numbered.

<!-- solution 34.4 -->
```python
class TodoList:
    def __init__(self):
        self.items = []

    def add(self, text):
        self.items.append([text, False])

    def done(self, n):
        self.items[n - 1][1] = True

    def __str__(self):
        return "\n".join(f"{i}. [{'x' if d else ' '}] {t}" for i, (t, d) in enumerate(self.items, 1))

t = TodoList()
t.add("shop"); t.add("cook"); t.done(1)
print(t)
```

*You should see:*

```text
1. [x] shop
2. [ ] cook
```
<!-- /solution -->

**34.5 ★★ Temperature.** `Temperature(celsius)` with a `fahrenheit()` method and `__lt__`, so a list of them can be
`sorted`.

<!-- solution 34.5 -->
```python
class Temperature:
    def __init__(self, celsius):
        self.celsius = celsius

    def fahrenheit(self):
        return self.celsius * 9 / 5 + 32

    def __lt__(self, other):
        return self.celsius < other.celsius

    def __repr__(self):
        return f"{self.celsius}°C"

print(sorted([Temperature(31), Temperature(-2), Temperature(18)]))
print(Temperature(100).fahrenheit())
```

*You should see:*

```text
[-2°C, 18°C, 31°C]
212.0
```
<!-- /solution -->

**34.6 ★★ Shapes.** `Shape` with `area()` returning 0, and `Circle` and `Square` inheriting from it. Print the total
area of a list of mixed shapes.

<!-- solution 34.6 -->
```python
import math

class Shape:
    def area(self):
        return 0

class Circle(Shape):
    def __init__(self, r):
        self.r = r
    def area(self):
        return math.pi * self.r ** 2

class Square(Shape):
    def __init__(self, s):
        self.s = s
    def area(self):
        return self.s ** 2

print(round(sum(s.area() for s in [Circle(1), Square(2), Shape()]), 3))
```

*You should see:*

```text
7.142
```
<!-- /solution -->
