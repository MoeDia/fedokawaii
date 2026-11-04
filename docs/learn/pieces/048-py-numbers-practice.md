---
id: py-numbers-practice
title: practice
part: python
chapter: 25
minutes: 18
needs: [py-numbers-mistakes]
optional: no
---

**25.1 ★ Seconds in a day.** Use the prompt to work out how many seconds there are in a day, then in a week.
*Expected:* `86400` and `604800`.

<!-- solution 25.1 -->
```python
day = 24 * 60 * 60
print(day)
print(day * 7)
```

*You should see:*

```text
86400
604800
```
<!-- /solution -->

**25.2 ★ Your first file.** Write `me.py` that prints your name on one line and your city on the next.

<!-- solution 25.2 -->
```python
print("Mohamed")
print("Sharjah")
```

*You should see:*

```text
Mohamed
Sharjah
```
<!-- /solution -->

**25.3 ★ Even or odd.** Use `%` to find the remainder of 17, 18 and 2026 divided by 2. Which are even?
*Expected:* `1 0 0` — 18 and 2026 are even.

<!-- solution 25.3 -->
```python
print(17 % 2, 18 % 2, 2026 % 2)
```

*You should see:*

```text
1 0 0
```
<!-- /solution -->

**25.4 ★★ Shopping total.** Make variables for 3 kg of rice at 7.25 a kilo and 2 packs of tea at 12.5 each. Print the
total with two decimals.
*Expected:* `Total: 46.75`.

<!-- solution 25.4 -->
```python
rice = 3 * 7.25
tea = 2 * 12.5
print(f"Total: {rice + tea:.2f}")
```

*You should see:*

```text
Total: 46.75
```
<!-- /solution -->

**25.5 ★★ Minutes and seconds.** Given `seconds = 754`, print it as minutes and seconds using `//` and `%`.
*Expected:* `12 min 34 s`.

<!-- solution 25.5 -->
```python
seconds = 754
print(f"{seconds // 60} min {seconds % 60} s")
```

*You should see:*

```text
12 min 34 s
```
<!-- /solution -->

**25.6 ★★ Celsius to Fahrenheit.** Ask for a temperature in Celsius and print it in Fahrenheit (F = C × 9 / 5 + 32), with one
decimal.
*Expected:* for `31`: `31.0 °C is 87.8 °F`.

<!-- solution 25.6 -->
```python
c = float(input("Celsius? "))
f = c * 9 / 5 + 32
print(f"{c:.1f} °C is {f:.1f} °F")
```

*You should see:*

```text
Celsius? 31
31.0 °C is 87.8 °F
```
<!-- /solution -->
