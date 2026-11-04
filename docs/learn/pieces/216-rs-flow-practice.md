---
id: rs-flow-practice
title: practice
part: rust
chapter: 50
minutes: 18
needs: [rs-guessing]
optional: no
---

**50.1 ★ Count down.** Print 10 down to 1, then `lift off!`, with `(1..=10).rev()`.

<!-- solution 50.1 -->
```rust
fn main() {
    for n in (1..=10).rev() {
        print!("{n} ");
    }
    println!("lift off!");
}
```

*You should see:*

```text
10 9 8 7 6 5 4 3 2 1 lift off!
```
<!-- /solution -->

**50.2 ★ FizzBuzz.** 1 to 15, with `Fizz`, `Buzz` and `FizzBuzz` — with `if`, then with
`match (n % 3, n % 5) { (0, 0) => …, (0, _) => …, (_, 0) => …, _ => … }`.

<!-- solution 50.2 -->
```rust
fn main() {
    for n in 1..=15 {
        match (n % 3, n % 5) {
            (0, 0) => println!("FizzBuzz"),
            (0, _) => println!("Fizz"),
            (_, 0) => println!("Buzz"),
            _ => println!("{n}"),
        }
    }
}
```

*You should see:*

```text
1
2
Fizz
4
Buzz
Fizz
7
8
Fizz
Buzz
11
Fizz
13
14
FizzBuzz
```
<!-- /solution -->

**50.3 ★ Sum of squares.** The sum of the squares of 1 to 10 with a `for` loop.
*Expected:* `385`.

<!-- solution 50.3 -->
```rust
fn main() {
    let mut s = 0;
    for n in 1..=10 {
        s += n * n;
    }
    println!("{s}");
}
```

*You should see:*

```text
385
```
<!-- /solution -->

**50.4 ★★ Leap years.** `fn is_leap(y: u32) -> bool`, and print the leap years from 1896 to 1912.
*Expected:* `1896 1904 1908 1912` — 1900 is not.

<!-- solution 50.4 -->
```rust
fn is_leap(y: u32) -> bool {
    (y % 4 == 0 && y % 100 != 0) || y % 400 == 0
}

fn main() {
    for y in 1896..=1912 {
        if is_leap(y) {
            print!("{y} ");
        }
    }
    println!();
}
```

*You should see:*

```text
1896 1904 1908 1912
```
<!-- /solution -->

**50.5 ★★ Times table.** A 5 × 5 times table, each number right-aligned in 4 characters.

<!-- solution 50.5 -->
```rust
fn main() {
    for r in 1..=5 {
        for c in 1..=5 {
            print!("{:>4}", r * c);
        }
        println!();
    }
}
```

*You should see:*

```text
   1   2   3   4   5
   2   4   6   8  10
   3   6   9  12  15
   4   8  12  16  20
   5  10  15  20  25
```
<!-- /solution -->

**50.6 ★★ Digits.** `fn digit_sum(mut n: u64) -> u64` with a `while` loop and `% 10`, `/ 10`.
*Expected:* `digit_sum(2026)` → `10`.

<!-- solution 50.6 -->
```rust
fn digit_sum(mut n: u64) -> u64 {
    let mut s = 0;
    while n > 0 {
        s += n % 10;
        n /= 10;
    }
    s
}

fn main() {
    println!("{}", digit_sum(2026));
}
```

*You should see:*

```text
10
```
<!-- /solution -->
