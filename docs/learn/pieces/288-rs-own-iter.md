---
id: rs-own-iter
title: your own iterator; common mistakes
part: rust
chapter: 60
minutes: 6
needs: [rs-chain]
optional: no
---

## 60.8 your own iterator

Implement the `Iterator` trait — one method, `next`, returning `Some(value)` or `None` when done —
and every adapter above works on your type for free:

```rust
struct Fibonacci {
    a: u64,
    b: u64,
}

impl Iterator for Fibonacci {
    type Item = u64;
    fn next(&mut self) -> Option<u64> {
        let r = self.a;
        self.a = self.b;
        self.b += r;
        Some(r)
    }
}

fn fib() -> Fibonacci {
    Fibonacci { a: 0, b: 1 }
}

fn main() {
    println!("{:?}", fib().take(12).collect::<Vec<_>>());
    println!("{}", fib().take_while(|&x| x < 1000).filter(|x| x % 2 == 0).sum::<u64>());
}
```

*You should see:*

```text
[0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89]
798
```

## 60.9 common mistakes

**1. Forgetting the consumer.** `v.iter().map(|x| x * 2);` does nothing — the compiler warns
*unused `Map` that must be used*. Add `.collect()` (or use a `for` loop for side effects).

**2. `collect` without a type.** `type annotations needed` — say what to build:
`let v: Vec<_> = …collect();` or `.collect::<Vec<_>>()`.

```rust
fn main() {
    let v = [1, 2, 3].iter().map(|x| x * 2).collect();
}
```

*The compiler says:*

```text
error[E0283]: type annotations needed
 --> src/main.rs:2:9
  |
2 |     let v = [1, 2, 3].iter().map(|x| x * 2).collect();
  |         ^                                   ------- type must be known at this point
  |
  = note: the type must implement `FromIterator<i32>`
note: required by a bound in `collect`
```

**3. Too many `&`.** `filter` gets a *reference to* each item, so on `iter()` of numbers it is
`&&i32`: write `|&&x| x > 2`, or `|x| **x > 2` — or use `.copied()` first.
