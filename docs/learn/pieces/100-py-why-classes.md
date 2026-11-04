---
id: py-why-classes
title: why classes; self
part: python
chapter: 34
minutes: 7
needs: [py-modules-practice]
optional: no
---

> **In this chapter**
>
> - a class: your own kind of value, with data and behaviour together
> - `__init__`, `self`, methods, and the special methods that make `print` and `==` work
> - dataclasses: the short way
> - inheritance, briefly — and when not to use it

## 34.1 why classes

Until now, data and the functions working on it lived apart: a dictionary for an account, and
functions that take the dictionary. A **class** keeps them together: it describes a new kind of
value — an *account* — with its data (**attributes**) and what it can do (**methods**). Each
value made from it is an **object** (or *instance*).

```python
class Dog:
    def __init__(self, name, age):
        self.name = name
        self.age = age

    def bark(self):
        return f"{self.name} says woof"

rex = Dog("Rex", 3)
luna = Dog("Luna", 5)
print(rex.name, rex.age)
print(luna.bark())
```

*You should see:*

```text
Rex 3
Luna says woof
```

| Piece | Means |
|---|---|
| `class Dog:` | a new kind of value, named with a capital by habit |
| `__init__` | runs when an object is made: `Dog("Rex", 3)` calls it |
| `self` | the object itself — Python passes it in for you |
| `self.name = name` | an attribute: data stored on this object |
| `def bark(self)` | a method: a function every Dog can do |

## 34.2 self, step by step

`rex.bark()` is Python's short way to write `Dog.bark(rex)`: the object before the dot becomes
`self`. That is how one method serves every dog:

```python
class Dog:
    def __init__(self, name):
        self.name = name

    def bark(self):
        return f"{self.name}: woof"

rex = Dog("Rex")
print(rex.bark())
print(Dog.bark(rex))
```

*You should see:*

```text
Rex: woof
Rex: woof
```

Attributes can change; each object has its own:

```python
class Counter:
    def __init__(self):
        self.count = 0

    def click(self):
        self.count += 1

a = Counter()
b = Counter()
a.click(); a.click(); b.click()
print(a.count, b.count)
```

*You should see:*

```text
2 1
```
