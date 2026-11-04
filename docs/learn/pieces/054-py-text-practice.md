---
id: py-text-practice
title: practice
part: python
chapter: 26
minutes: 18
needs: [py-text-mistakes]
optional: no
---

**26.1 ★ Initials.** From `first = "mohamed"` and `last = "eldoush"`, print the initials in capitals.
*Expected:* `M.E.`

<!-- solution 26.1 -->
```python
first = "mohamed"
last = "eldoush"
print(f"{first[0].upper()}.{last[0].upper()}.")
```

*You should see:*

```text
M.E.
```
<!-- /solution -->

**26.2 ★ Shout.** Ask for a sentence and print it in capitals with three `!` after it.
*Expected:* for `hello`: `HELLO!!!`

<!-- solution 26.2 -->
```python
s = input("Say something: ")
print(s.upper() + "!!!")
```

*You should see:*

```text
Say something: hello
HELLO!!!
```
<!-- /solution -->

**26.3 ★ The extension.** From `filename = "report.final.pdf"`, print the extension (`pdf`) using `split` and `[-1]`.

<!-- solution 26.3 -->
```python
filename = "report.final.pdf"
print(filename.split(".")[-1])
```

*You should see:*

```text
pdf
```
<!-- /solution -->

**26.4 ★★ Palindrome check.** Ask for a word and print `True` if it reads the same backwards (ignore capitals).
*Expected:* `Level` → `True`, `kyoto` → `False`.

<!-- solution 26.4 -->
```python
w = input("Word? ").lower()
print(w == w[::-1])
```

*You should see:*

```text
Word? Level
True
```
<!-- /solution -->

**26.5 ★★ Count the vowels.** Count a, e, i, o, u in `"Fedokawaii is a desktop"` using `.count` five times.
*Expected:* `10`.

<!-- solution 26.5 -->
```python
s = "Fedokawaii is a desktop".lower()
print(s.count("a") + s.count("e") + s.count("i") + s.count("o") + s.count("u"))
```

*You should see:*

```text
10
```
<!-- /solution -->

**26.6 ★★ Date flip.** Turn `"2026-10-21"` into `"21/10/2026"` with `split` and `join`.

<!-- solution 26.6 -->
```python
parts = "2026-10-21".split("-")
print("/".join([parts[2], parts[1], parts[0]]))
```

*You should see:*

```text
21/10/2026
```
<!-- /solution -->
