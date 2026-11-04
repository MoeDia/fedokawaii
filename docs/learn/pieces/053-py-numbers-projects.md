---
id: py-numbers-projects
title: projects
part: python
chapter: 25
minutes: 180
needs: [py-numbers-practice]
optional: yes
---

**25.7 ★★★ Swap without a third name.** Given `a = 5` and `b = 9`, make `a` 9 and `b` 5. First with a third variable; then look up
Python's `a, b = b, a`.
*Expected:* `9 5`.

<!-- solution 25.7 -->
```python
a = 5
b = 9
tmp = a
a = b
b = tmp
print(a, b)
a, b = b, a
print(a, b)
```

*You should see:*

```text
9 5
5 9
```
<!-- /solution -->

**25.8 ★★★ A receipt.** Ask for an item's name, its price and how many; print a receipt line with the name left in
12 characters and the total right in 8, with two decimals (`{name:<12}` and `{total:>8.2f}`).
*Expected:* for `tea`, `8.5`, `3`: `tea            25.50`.

<!-- solution 25.8 -->
```python
name = input("Item? ")
price = float(input("Price? "))
count = int(input("How many? "))
total = price * count
print(f"{name:<12}{total:>8.2f}")
```

*You should see:*

```text
Item? tea
Price? 8.5
How many? 3
tea            25.50
```
<!-- /solution -->

**25.9 ★★★★ Change in coins.** Ask for an amount in fils (an int, say `385`) and print the fewest coins for it using 100, 50,
25, 10, 5 and 1 fils coins — only `//`, `%` and variables, no loops yet.
*Expected:* for 385: `100×3 50×1 25×1 10×1 5×0 1×0`.

<!-- solution 25.9 -->
```python
amount = int(input("Fils? "))
c100 = amount // 100; amount = amount % 100
c50 = amount // 50; amount = amount % 50
c25 = amount // 25; amount = amount % 25
c10 = amount // 10; amount = amount % 10
c5 = amount // 5; amount = amount % 5
print(f"100×{c100} 50×{c50} 25×{c25} 10×{c10} 5×{c5} 1×{amount}")
```

*You should see:*

```text
Fils? 385
100×3 50×1 25×1 10×1 5×0 1×0
```
<!-- /solution -->
