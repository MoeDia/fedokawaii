---
id: rs-flow-projects
title: projects
part: rust
chapter: 50
minutes: 180
needs: [rs-flow-practice]
optional: yes
---

**50.7 ★★★ Primes below 50.** `fn is_prime(n: u32) -> bool` (trial division up to the square root, `d * d <= n`), and print the
primes below 50.

<!-- solution 50.7 -->
```rust
fn is_prime(n: u32) -> bool {
    if n < 2 {
        return false;
    }
    let mut d = 2;
    while d * d <= n {
        if n % d == 0 {
            return false;
        }
        d += 1;
    }
    true
}

fn main() {
    for n in 1..50 {
        if is_prime(n) {
            print!("{n} ");
        }
    }
    println!();
}
```

*You should see:*

```text
2 3 5 7 11 13 17 19 23 29 31 37 41 43 47
```
<!-- /solution -->

**50.8 ★★★ Collatz, longest.** For each start from 1 to 10 000, count the Collatz steps (chapter 27's exercise); print the start
with the most steps.
*Expected:* `6171 takes 261 steps`.

<!-- solution 50.8 -->
```rust
fn steps(mut n: u64) -> u32 {
    let mut s = 0;
    while n != 1 {
        n = if n % 2 == 0 { n / 2 } else { 3 * n + 1 };
        s += 1;
    }
    s
}

fn main() {
    let mut best = (1, 0);
    for n in 1..=10_000 {
        let s = steps(n);
        if s > best.1 {
            best = (n, s);
        }
    }
    println!("{} takes {} steps", best.0, best.1);
}
```

*You should see:*

```text
6171 takes 261 steps
```
<!-- /solution -->

**50.9 ★★★★ A diamond.** `fn diamond(n: usize)` prints a diamond of `*` of height `2n − 1`, using `" ".repeat(k)` and
`"*".repeat(k)`.

<!-- solution 50.9 -->
```rust
fn diamond(n: usize) {
    for i in (1..=n).chain((1..n).rev()) {
        println!("{}{}", " ".repeat(n - i), "*".repeat(2 * i - 1));
    }
}

fn main() {
    diamond(4);
}
```

*You should see:*

```text
   *
  ***
 *****
*******
 *****
  ***
   *
```
<!-- /solution -->
