---
id: py-flow-practice
title: practice
part: python
chapter: 27
minutes: 18
needs: [py-guessing]
optional: no
---

**27.1 ★ Positive, negative, zero.** Ask for a number and print `positive`, `negative` or `zero`.

<!-- solution 27.1 -->
```python
n = float(input("Number? "))
if n > 0:
    print("positive")
elif n < 0:
    print("negative")
else:
    print("zero")
```

*You should see:*

```text
Number? -4
negative
```
<!-- /solution -->

**27.2 ★ Count down.** Print 10 down to 1, then `lift off!`, with `range`.

<!-- solution 27.2 -->
```python
for n in range(10, 0, -1):
    print(n, end=" ")
print("lift off!")
```

*You should see:*

```text
10 9 8 7 6 5 4 3 2 1 lift off!
```
<!-- /solution -->

**27.3 ★ Sum of evens.** Add up the even numbers from 2 to 100.
*Expected:* `2550`.

<!-- solution 27.3 -->
```python
total = 0
for n in range(2, 101, 2):
    total += n
print(total)
```

*You should see:*

```text
2550
```
<!-- /solution -->

**27.4 ★★ FizzBuzz.** Print 1 to 15, but `Fizz` for multiples of 3, `Buzz` for multiples of 5, and `FizzBuzz` for
both.

<!-- solution 27.4 -->
```python
for n in range(1, 16):
    if n % 15 == 0:
        print("FizzBuzz")
    elif n % 3 == 0:
        print("Fizz")
    elif n % 5 == 0:
        print("Buzz")
    else:
        print(n)
```

*You should see:*

```text
1
2
Fizz
4
Buzz
Fizz
7
8
Fizz
Buzz
11
Fizz
13
14
FizzBuzz
```
<!-- /solution -->

**27.5 ★★ Leap year.** A year is a leap year if it divides by 4, except centuries, which must divide by 400. Ask for
a year and say whether it is one.
*Expected:* 2024 yes, 1900 no, 2000 yes.

<!-- solution 27.5 -->
```python
y = int(input("Year? "))
if (y % 4 == 0 and y % 100 != 0) or y % 400 == 0:
    print(y, "is a leap year")
else:
    print(y, "is not a leap year")
```

*You should see:*

```text
Year? 1900
1900 is not a leap year
```
<!-- /solution -->

**27.6 ★★ Vowels by loop.** Count the vowels of a typed word with a `for` loop and `in "aeiou"`.

<!-- solution 27.6 -->
```python
count = 0
for ch in input("Word? ").lower():
    if ch in "aeiou":
        count += 1
print(count, "vowels")
```

*You should see:*

```text
Word? Fedokawaii
6 vowels
```
<!-- /solution -->
