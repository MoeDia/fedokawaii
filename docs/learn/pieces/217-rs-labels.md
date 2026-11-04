---
id: rs-labels
title: continue, labels, a first match
part: rust
chapter: 50
minutes: 6
needs: [rs-loops]
optional: no
---

## 50.4 continue, and labelled loops

`continue` skips to the next turn. In nested loops, a **label** (`'outer:`) says which loop a
`break` or `continue` means:

```rust
fn main() {
    for n in 1..=10 {
        if n % 3 == 0 {
            continue;
        }
        print!("{n} ");
    }
    println!();

    'outer: for a in 1..10 {
        for b in 1..10 {
            if a * b == 42 {
                println!("found {a} × {b}");
                break 'outer;
            }
        }
    }
}
```

*You should see:*

```text
1 2 4 5 7 8 10 
found 6 × 7
```

## 50.5 match on numbers, a first look

`match` compares a value against patterns, top to bottom, and runs the first that fits. It must
cover every possible value — `_` means "anything else". Chapter 54 shows its full power:

```rust
fn describe(n: i32) -> &'static str {
    match n {
        0 => "zero",
        1 | 2 | 3 => "a few",
        4..=9 => "several",
        _ if n < 0 => "negative",
        _ => "many",
    }
}

fn main() {
    for n in [0, 2, 7, -5, 100] {
        println!("{n}: {}", describe(n));
    }
}
```

*You should see:*

```text
0: zero
2: a few
7: several
-5: negative
100: many
```
