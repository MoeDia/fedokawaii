---
id: py-function
title: what a function is; parameters
part: python
chapter: 28
minutes: 4
needs: [py-flow-practice]
optional: no
---

> **In this chapter**
>
> - define a function, give it values, get a result back
> - default and keyword arguments
> - where a variable lives (scope)
> - small functions that each do one thing — and how to check them with `assert`

## 28.1 what a function is

A **function** is a piece of work with a name. You write it once with `def`, then **call**
it — run it — as often as you like, each time with different values.

```python
def greet():
    print("hello!")
    print("welcome to fedokawaii")

greet()
greet()
```

*You should see:*

```text
hello!
welcome to fedokawaii
hello!
welcome to fedokawaii
```

The lines under `def` (indented) are the function's **body**. Defining it does nothing yet;
calling it — `greet()`, with brackets — runs the body.

## 28.2 parameters: values going in

Names in the brackets of `def` are **parameters**: they receive the values you pass when you
call it (the **arguments**).

```python
def greet(name):
    print(f"hello, {name}!")

greet("Sara")
greet("Omar")
```

*You should see:*

```text
hello, Sara!
hello, Omar!
```

```python
def rectangle(width, height):
    print(f"{width} × {height} = {width * height}")

rectangle(3, 4)
rectangle(10, 2)
```

*You should see:*

```text
3 × 4 = 12
10 × 2 = 20
```

> **Word — parameter, argument.** In `def rectangle(width, height)`, `width` and `height` are
> parameters: the names. In `rectangle(3, 4)`, `3` and `4` are arguments: the values.
