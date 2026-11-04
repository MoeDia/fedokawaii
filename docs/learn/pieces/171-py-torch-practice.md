---
id: py-torch-practice
title: practice
part: python
chapter: 44
minutes: 12
needs: [py-torch-digits]
optional: no
---

**44.1 ★ Your card.** Run `gpu.py` and write your two times in your notes.

**44.2 ★ Watch it.** Raise the benchmark to 1 000 runs and watch btop's GPU line while it works.

**44.3 ★★ Less memorising.** Add `weight_decay=1e-3` to the optimiser and `nn.Dropout(0.2)`
after the ReLU (call `model.train()` before training and `model.eval()` before testing). Does
the test accuracy hold up better?

**44.4 ★★ A test for the model.** In `tests/test_digits.py`, check that `Net()(torch.zeros(5,
64)).shape == (5, 10)`. Shape tests catch most model bugs, in milliseconds, without the card.
