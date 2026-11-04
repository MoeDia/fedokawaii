---
id: rs-guessing
title: checkpoint: a number-guessing machine
part: rust
chapter: 50
minutes: 30
needs: [rs-flow-mistakes]
optional: no
---

## 50.7 checkpoint project — a number-guessing machine

You think of a number from 1 to 1000; the machine guesses, and you answer *higher* or *lower*.
It halves the range each time — **binary search** — so it never needs more than 10 guesses
(2¹⁰ = 1024). Here the "you" is played by a `secret` variable, so the program runs by itself:

```rust
fn main() {
    let secret = 737;
    let (mut low, mut high) = (1, 1000);
    let mut tries = 0;
    loop {
        let guess = (low + high) / 2;
        tries += 1;
        if guess < secret {
            println!("{tries:>2}: {guess:>4} → higher");
            low = guess + 1;
        } else if guess > secret {
            println!("{tries:>2}: {guess:>4} → lower");
            high = guess - 1;
        } else {
            println!("{tries:>2}: {guess:>4} → yes!");
            break;
        }
    }
}
```

*You should see:*

```text
 1:  500 → higher
 2:  750 → lower
 3:  625 → higher
 4:  687 → higher
 5:  718 → higher
 6:  734 → higher
 7:  742 → lower
 8:  738 → lower
 9:  736 → higher
10:  737 → yes!
```

> **Checkpoint.** (1) Wrap it in a `for secret in 1..=1000` loop and find the largest number of
> tries over all secrets (it should be 10). (2) Read the answers from the keyboard instead:
> `let mut line = String::new(); std::io::stdin().read_line(&mut line).unwrap();` then
> `match line.trim() { "h" => …, "l" => …, "y" => …, _ => … }`. Level 1 done.
