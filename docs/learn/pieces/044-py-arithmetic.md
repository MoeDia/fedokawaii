---
id: py-arithmetic
title: numbers and arithmetic
part: python
chapter: 25
minutes: 6
needs: [py-two-ways]
optional: no
---

## 25.2 numbers and arithmetic

Python is a calculator first. It knows two kinds of numbers:

- **int** — a whole number: `7`, `-3`, `2026`. As big as you like.
- **float** — a number with a point: `3.5`, `0.1`, `-2.0`.

```text
>>> 7 + 3
10
>>> 7 - 3
4
>>> 7 * 3
21
>>> 7 / 2
3.5
>>> 7 // 2
3
>>> 7 % 2
1
>>> 2 ** 10
1024
```

| Sign | Does | Example | Gives |
|---|---|---|---|
| `+` `-` `*` | add, subtract, multiply | `7 * 3` | `21` |
| `/` | divide — always gives a float | `6 / 2` | `3.0` |
| `//` | divide and drop the remainder | `7 // 2` | `3` |
| `%` | the remainder | `7 % 2` | `1` |
| `**` | power | `2 ** 10` | `1024` |

Python follows the order you learnt at school: powers, then `* / // %`, then `+ -`.
Brackets go first, so use them whenever you are unsure.

```text
>>> 2 + 3 * 4
14
>>> (2 + 3) * 4
20
>>> 10 - 2 - 3
5
>>> 2 ** 3 ** 2
512
```

*(the last one is `2 ** 9`: powers are worked out from the right)*

Ints can be huge — Python never overflows them:

```text
>>> 2 ** 100
1267650600228229401496703205376
>>> 1_000_000 * 3
3000000
```

*(underscores in a number are only for your eyes: `1_000_000` is one million)*

**Floats are close, not exact.** A computer stores `0.1` in binary, where it cannot be written
exactly, just as 1/3 cannot be written exactly in decimal:

```text
>>> 0.1 + 0.2
0.30000000000000004
>>> round(0.1 + 0.2, 2)
0.3
>>> round(3.14159, 3)
3.142
```

This is not a bug in Python: every language does it. For money, count in whole fils or cents
(ints), or round when you show the result.
