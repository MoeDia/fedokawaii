---
id: py-text-projects
title: projects
part: python
chapter: 26
minutes: 180
needs: [py-text-practice]
optional: yes
---

**26.7 ★★★ Title case for a sentence.** Ask for a sentence, and print it with only the first letter capital and the rest small, and
the number of words.
*Expected:* `tHE quick FOX` → `The quick fox (3 words)`.

<!-- solution 26.7 -->
```python
s = input("Sentence? ").strip()
fixed = s[0].upper() + s[1:].lower()
print(f"{fixed} ({len(s.split())} words)")
```

*You should see:*

```text
Sentence? tHE quick FOX
The quick fox (3 words)
```
<!-- /solution -->

**26.8 ★★★ Mask a card number.** Given `"4111222233334444"`, print it with all but the last 4 digits as `*`.
*Expected:* `************4444`.

<!-- solution 26.8 -->
```python
card = "4111222233334444"
print("*" * (len(card) - 4) + card[-4:])
```

*You should see:*

```text
************4444
```
<!-- /solution -->

**26.9 ★★★★ Caesar shift, one letter.** Using `ord` and `chr`, shift the small letter `c = "y"` forward by `k = 3` places, wrapping
from `z` back to `a` (use `% 26`).
*Expected:* `b`.

<!-- solution 26.9 -->
```python
c = "y"
k = 3
shifted = chr((ord(c) - ord("a") + k) % 26 + ord("a"))
print(shifted)
```

*You should see:*

```text
b
```
<!-- /solution -->
