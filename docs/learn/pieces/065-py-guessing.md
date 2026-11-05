---
id: py-guessing
title: checkpoint: a guessing game
part: python
chapter: 27
minutes: 30
needs: [py-break]
optional: no
---

## 27.7 checkpoint project — a guessing game

Everything from level 1 in one program: the computer picks a number from 1 to 100; you guess;
it says *higher* or *lower* until you have it, and counts your tries.

`random.randint(1, 100)` picks the number. `random.seed(7)` makes the "random" choice the same
every run, so you can check your output against this one — remove it to play for real.

```python
import random

random.seed(7)
secret = random.randint(1, 100)
tries = 0
while True:
    guess = int(input("Your guess? "))
    tries += 1
    if guess < secret:
        print("higher")
    elif guess > secret:
        print("lower")
    else:
        print(f"yes! {secret} in {tries} tries")
        break
```

*You should see:*

```text
Your guess? 50
lower
Your guess? 25
higher
Your guess? 37
higher
Your guess? 43
lower
Your guess? 40
higher
Your guess? 42
yes! 42 in 6 tries
```

> **Checkpoint.** Add three things, one at a time, running after each: (1) refuse a guess
> that is not a number (`isdigit`), without counting it; (2) give up after 7 tries and show the
> number; (3) at the end, ask *play again? (y/n)* and loop the whole game. If you can do all
> three without looking back, level 1 is done.
