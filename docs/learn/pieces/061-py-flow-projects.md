---
id: py-flow-projects
title: projects
part: python
chapter: 27
minutes: 210
needs: [py-flow-practice]
optional: yes
---

**27.7 ★★★ Password check.** Ask for a password until it has at least 8 characters and at least one digit; then print
`saved`.

<!-- solution 27.7 -->
```python
while True:
    pw = input("Password? ")
    has_digit = False
    for ch in pw:
        if ch.isdigit():
            has_digit = True
    if len(pw) >= 8 and has_digit:
        print("saved")
        break
    print("8 characters and a digit, please")
```

*You should see:*

```text
Password? short
8 characters and a digit, please
Password? longenough
8 characters and a digit, please
Password? longenough7
saved
```
<!-- /solution -->

**27.8 ★★★ Is it prime?.** Ask for a number and say whether it is prime (no divisor from 2 up to its square root —
`d * d <= n`).
*Expected:* 97 is prime, 91 is not (7 × 13).

<!-- solution 27.8 -->
```python
n = int(input("Number? "))
prime = n >= 2
d = 2
while d * d <= n:
    if n % d == 0:
        prime = False
        print(f"{n} = {d} × {n // d}")
        break
    d += 1
print(n, "is prime" if prime else "is not prime")
```

*You should see:*

```text
Number? 91
91 = 7 × 13
91 is not prime
```
<!-- /solution -->

**27.9 ★★★ A triangle of stars.** Ask for a height and print a right triangle of `*` that high.

<!-- solution 27.9 -->
```python
h = int(input("Height? "))
for row in range(1, h + 1):
    print("*" * row)
```

*You should see:*

```text
Height? 4
*
**
***
****
```
<!-- /solution -->

**27.10 ★★★★ The Collatz walk.** Start from a number `n`. If it is even, halve it; if odd, make it `3n + 1`. Repeat until it is 1,
printing each step, then the number of steps. Nobody has ever proved this always reaches 1.
*Expected:* for 6: `6 3 10 5 16 8 4 2 1` and `8 steps`.

<!-- solution 27.10 -->
```python
n = int(input("Start? "))
steps = 0
print(n, end=" ")
while n != 1:
    if n % 2 == 0:
        n = n // 2
    else:
        n = 3 * n + 1
    steps += 1
    print(n, end=" ")
print()
print(steps, "steps")
```

*You should see:*

```text
Start? 6
6 3 10 5 16 8 4 2 1 
8 steps
```
<!-- /solution -->
