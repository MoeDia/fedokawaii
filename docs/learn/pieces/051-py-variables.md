---
id: py-variables
title: variables and types
part: python
chapter: 25
minutes: 7
needs: [py-arithmetic]
optional: no
---

## 25.3 variables: names for values

A **variable** is a name that points at a value. `=` means *let this name point at this
value* — not "equals" as in maths.

```text
>>> price = 12.5
>>> count = 4
>>> price * count
50.0
>>> count = count + 1
>>> count
5
```

Read `count = count + 1` from the right: *work out `count + 1` (that is 5), then let `count`
point at 5*. It is so common that it has a short form:

```text
>>> score = 10
>>> score += 5
>>> score
15
>>> score -= 3
>>> score
12
>>> score *= 2
>>> score
24
```

Good names say what the value *is*: `price`, `total_hours`, `user_name`. The rules:

- letters, digits and `_`, not starting with a digit: `day2` yes, `2day` no;
- lowercase words joined by `_` (*snake case*): `total_hours`, not `TotalHours`;
- case matters: `Price` and `price` are two different names.

> **Word — expression.** Anything that has a value: `3`, `price * count`, `"hi"`. A
> **statement** does something: `count = 4` makes a variable; it has no value of its own.

## 25.4 types: what kind of value

Every value has a **type**, and the type decides what you can do with it. `type()` tells you.

```text
>>> type(7)
<class 'int'>
>>> type(7.0)
<class 'float'>
>>> type("7")
<class 'str'>
>>> type(True)
<class 'bool'>
```

| Type | Holds | Examples |
|---|---|---|
| `int` | whole numbers | `0`, `42`, `-7` |
| `float` | numbers with a point | `3.5`, `0.1` |
| `str` | text (a *string* of characters) | `"hello"`, `'7'` |
| `bool` | true or false | `True`, `False` |

The same sign can mean different things for different types:

```text
>>> 3 + 4
7
>>> "3" + "4"
'34'
>>> "ab" * 3
'ababab'
```

You change a value's type with the type's name, used like a function:

```text
>>> int("42") + 1
43
>>> float("2.5") * 2
5.0
>>> str(42) + "!"
'42!'
>>> int(3.99)
3
```

*(`int(3.99)` cuts the decimals off; it does not round. `round(3.99)` gives 4.)*
