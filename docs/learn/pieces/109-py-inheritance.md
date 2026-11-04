---
id: py-inheritance
title: inheritance, briefly
part: python
chapter: 34
minutes: 4
needs: [py-dataclasses]
optional: no
---

## 34.6 inheritance, briefly

A class can **inherit** from another: it gets all its methods, and can add or replace some.
`super()` calls the parent's version:

```python
class Animal:
    def __init__(self, name):
        self.name = name

    def speak(self):
        return "..."

    def intro(self):
        return f"{self.name} says {self.speak()}"

class Cat(Animal):
    def speak(self):
        return "meow"

class Kitten(Cat):
    def speak(self):
        return super().speak() + " (tiny)"

for a in [Animal("thing"), Cat("Tama"), Kitten("Mochi")]:
    print(a.intro())
print(isinstance(Kitten("x"), Animal))
```

*You should see:*

```text
thing says ...
Tama says meow
Mochi says meow (tiny)
True
```

Use it sparingly. Most of the time a class that *holds* another (an Account holding a list of
transactions) is clearer than one that *is* another. Inheritance is right when the new thing
truly is a kind of the old one — as your own exceptions are kinds of `Exception` (chapter 32).
