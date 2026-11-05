---
id: rs-loops
title: loop, while, for and ranges
part: rust
chapter: 50
minutes: 8
needs: [rs-if]
optional: no
---

## 50.2 loop, while

`loop` repeats forever, until a `break`. `break` can hand a value out of the loop:

```rust
fn main() {
    let mut n = 1;
    let first_big = loop {
        n *= 3;
        if n > 100 {
            break n;
        }
    };
    println!("{first_big}");

    let mut countdown = 3;
    while countdown > 0 {
        println!("{countdown}…");
        countdown -= 1;
    }
    println!("go!");
}
```

*You should see:*

```text
243
3…
2…
1…
go!
```

## 50.3 for and ranges

`for` walks through anything iterable: a range, an array, a list. `a..b` runs from `a` up to
*but not including* `b`; `a..=b` includes `b`:

```rust
fn main() {
    for i in 0..3 {
        print!("{i} ");
    }
    println!();
    for i in (1..=10).step_by(3) {
        print!("{i} ");
    }
    println!();
    for i in (1..4).rev() {
        print!("{i} ");
    }
    println!();
    let cities = ["Sharjah", "Dubai", "Kyoto"];
    for (i, city) in cities.iter().enumerate() {
        println!("{i}: {city}");
    }
}
```

*You should see:*

```text
0 1 2 
1 4 7 10 
3 2 1 
0: Sharjah
1: Dubai
2: Kyoto
```

*(`print!` is `println!` without the new line)*

Sums and counts with a `for`:

```rust
fn main() {
    let mut total = 0;
    for n in 1..=100 {
        total += n;
    }
    let evens = (1..=100).filter(|n| n % 2 == 0).count();
    println!("{total} {evens}");
}
```

*You should see:*

```text
5050 50
```

*(the second line is a taste of chapter 60: `filter` keeps the numbers for which the little
function `|n| n % 2 == 0` — a **closure** — is true)*
