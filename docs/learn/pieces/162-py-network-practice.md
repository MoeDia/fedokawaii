---
id: py-network-practice
title: practice
part: python
chapter: 43
minutes: 12
needs: [py-calculus]
optional: no
---

**43.1 ★ Too simple.** Remove the hidden layer (scores straight from `X @ W + b`). What
accuracy does the spiral reach now?

*Expected:* about 0.5: a straight line cannot separate a spiral. The hidden layer is what lets a
network bend.

**43.2 ★ Learning rate.** Try `lr = 5.0` and `lr = 0.01`.

*Expected:* 5.0 jumps about or blows up (`nan`); 0.01 learns, but slowly. Choosing it is half
the craft.

**43.3 ★★ Check another.** Gradient-check `b1` of `mlp.py` the same way as 43.4.

**43.4 ★★ Digits.** Train the same network on the digits: `D = 64`, `K = 10`. Keep the last 297
pictures apart, never trained on, and measure the accuracy on them.

*Expected:* above 0.9 on pictures it has never seen.
