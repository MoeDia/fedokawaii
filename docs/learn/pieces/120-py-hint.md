---
id: py-hint
title: what a type hint is, and checking
part: python
chapter: 36
minutes: 4
needs: [py-classes-practice, py-tests-practice]
optional: no
---

> **In this chapter**
>
> - write down what kind of value each name holds
> - let the editor (and a checker) find mistakes before you run anything
> - lists, dictionaries, optional values and your own types
> - the checkpoint for level 4: a small, typed, tested library

## 36.1 what a type hint is

A **type hint** says what kind of value a name should hold: `price: float`,
`def total(prices: list[float]) -> float`. Python itself ignores them when it runs. But your
editor reads them — neovim's basedpyright underlines a wrong call as you type — and a checker
can test a whole project at once. They are also the best documentation: they say exactly what
goes in and what comes out.

```python
def greet(name: str, times: int = 1) -> str:
    return ", ".join([f"hello {name}"] * times)

age: int = 31
print(greet("Sara", 2))
print(greet.__annotations__)
```

*You should see:*

```text
hello Sara, hello Sara
{'name': <class 'str'>, 'times': <class 'int'>, 'return': <class 'str'>}
```

## 36.2 checking: the mistake found before it runs

Python runs this without complaint until the bad line, and the result is nonsense:

`typed.py`:

```python
def area(width: float, height: float) -> float:
    return width * height

print(area(3, 4))
print(area("3", 4))
```

```text
$ uv run typed.py
12
3333
```

*(`"3" * 4` is `"3333"` — no error, just a wrong answer)*

A type checker finds it without running anything. neovim shows it as you type; on the command
line, `mypy` (or `basedpyright`) checks a file or a whole project:

```text
$ uvx mypy typed.py
typed.py:5: error: Argument 1 to "area" has incompatible type "str"; expected "float"  [arg-type]
Found 1 error in 1 file (checked 1 source file)
```
