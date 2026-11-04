---
id: py-dicts-projects
title: projects
part: python
chapter: 30
minutes: 180
needs: [py-dicts-practice]
optional: yes
---

**30.7 ★★★ Word lengths.** Group the words of a sentence by their length: `{3: ['the', 'cat'], 5: ['house']}`.

<!-- solution 30.7 -->
```python
text = "the cat left the house quietly"
groups = {}
for w in text.split():
    groups.setdefault(len(w), []).append(w)
print(groups)
```

*You should see:*

```text
{3: ['the', 'cat', 'the'], 4: ['left'], 5: ['house'], 7: ['quietly']}
```
<!-- /solution -->

**30.8 ★★★ Anagrams.** Group `["listen", "silent", "enlist", "google", "gooegl", "cat"]` into anagram families: words
with the same letters. Hint: `"".join(sorted(word))` is the same for anagrams — use it as the key.

<!-- solution 30.8 -->
```python
words = ["listen", "silent", "enlist", "google", "gooegl", "cat"]
fam = {}
for w in words:
    fam.setdefault("".join(sorted(w)), []).append(w)
print(list(fam.values()))
```

*You should see:*

```text
[['listen', 'silent', 'enlist'], ['google', 'gooegl'], ['cat']]
```
<!-- /solution -->

**30.9 ★★★★ The most common word.** Read a paragraph (a string), make everything small, remove `.` and `,`, ignore the words
`the`, `a`, `and`, `of`, and print the three most common words with their counts — first with
a plain dictionary and `sorted`, then with `Counter`.

<!-- solution 30.9 -->
```python
from collections import Counter

text = """The cat sat on the mat. The cat ate a fish, and the dog
watched the cat and the fish."""
stop = {"the", "a", "and", "of"}
words = [w for w in text.lower().replace(".", "").replace(",", "").split() if w not in stop]
counts = {}
for w in words:
    counts[w] = counts.get(w, 0) + 1
print(sorted(counts.items(), key=lambda kv: kv[1], reverse=True)[:3])
print(Counter(words).most_common(3))
```

*You should see:*

```text
[('cat', 3), ('fish', 2), ('sat', 1)]
[('cat', 3), ('fish', 2), ('sat', 1)]
```
<!-- /solution -->
