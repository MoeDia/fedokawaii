---
id: py-classes-mistakes
title: common mistakes
part: python
chapter: 34
minutes: 3
needs: [py-inheritance]
optional: no
---

## 34.7 common mistakes

**1. Forgetting `self`.** Every method's first parameter is `self`, and every attribute is
reached through it:

```python
class Light:
    def __init__(self):
        self.on = False

    def toggle():
        self.on = not self.on

Light().toggle()
```

*Python says:*

```text
Traceback (most recent call last):
  File "example.py", line 8, in <module>
    Light().toggle()
    ~~~~~~~~~~~~~~^^
TypeError: Light.toggle() takes 0 positional arguments but 1 was given
```

**2. `name` instead of `self.name` inside a method** — a `NameError`, or worse, a different
variable of the same name.

**3. Calling the class without its arguments.**

```python
class Dog:
    def __init__(self, name):
        self.name = name

d = Dog()
```

*Python says:*

```text
Traceback (most recent call last):
  File "example.py", line 5, in <module>
    d = Dog()
TypeError: Dog.__init__() missing 1 required positional argument: 'name'
```

**4. A list as a plain default.** In a normal class, `def __init__(self, items=[])` shares one
list between all objects. Use `items=None` and `self.items = items or []`; in a dataclass,
`field(default_factory=list)`.
