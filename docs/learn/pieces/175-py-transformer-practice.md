---
id: py-transformer-practice
title: practice
part: python
chapter: 45
minutes: 16
needs: [py-transformer]
optional: no
---

**45.1 ★ Temperature.** Generate with `temperature=0.3` and `1.5`.

*Expected:* 0.3 repeats safe phrases (`the the`, tables of `| **`); 1.5 invents words.

**45.2 ★★ Your voice.** Train it on your own notes, or on a book from `~/books` converted to
text (`pdftotext book.pdf book.txt`).

**45.3 ★★ Bigger.** `D = 384`, `LAYERS = 6`. Watch the card's memory in btop, and the
validation loss: lower, or overfitting?

**45.4 ★★ A prompt.** Start generation from a string of your own instead of `#`: encode it with
`stoi`.
