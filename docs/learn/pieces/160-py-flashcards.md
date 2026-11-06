---
id: py-flashcards
title: flashcards
part: python
chapter: 42
minutes: 5
needs: [py-chart]
optional: no
---

## 42.2 flashcards

Learning Japanese or Arabic words? A file of `front = back` lines becomes a quiz.

```python
"""flash — flashcards from a file of "front = back" lines"""
import random
import sys
from pathlib import Path

def load(text: str) -> list[tuple[str, str]]:
    cards = []
    for line in text.splitlines():
        if "=" in line and not line.startswith("#"):
            front, back = line.split("=", 1)
            cards.append((front.strip(), back.strip()))
    return cards

def check(answer: str, back: str) -> bool:
    return answer.strip().lower() == back.lower()

def main() -> None:
    cards = load(Path(sys.argv[1]).read_text(encoding="utf-8"))
    random.shuffle(cards)
    right = 0
    for front, back in cards:
        if check(input(f"{front} → "), back):
            right += 1
            print("  ✓")
        else:
            print(f"  ✗ {back}")
    print(f"{right} of {len(cards)}")

if __name__ == "__main__":
    main()
```

```text
$ uv run flash.py ~/notes/japanese.txt
water → mizu
  ✓
book → hono
  ✗ hon
1 of 2
```

**Test it:** `load` and `check` take strings, so their tests need no file and no keyboard.
**Extend it:** keep the cards you missed in a second file and quiz those first next time — the
idea behind spaced repetition.
