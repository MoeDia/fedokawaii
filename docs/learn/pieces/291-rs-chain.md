---
id: rs-chain
title: collect, and a real chain
part: rust
chapter: 60
minutes: 4
needs: [rs-into-iter]
optional: no
---

## 60.6 collect into anything

`collect` builds whatever type you name — a `Vec`, a `String`, a `HashMap`, even a `Result`:

```rust
use std::collections::{BTreeMap, HashSet};

fn main() {
    let words = ["tea", "rice", "tea", "milk"];
    let set: HashSet<&str> = words.iter().copied().collect();
    let lens: BTreeMap<&str, usize> = words.iter().map(|w| (*w, w.len())).collect();
    let initials: String = words.iter().map(|w| w.chars().next().unwrap()).collect();
    let nums: Result<Vec<i32>, _> = ["1", "2", "x"].iter().map(|s| s.parse::<i32>()).collect();
    println!("{} {:?} {initials} {}", set.len(), lens, nums.is_err());
}
```

*You should see:*

```text
3 {"milk": 4, "rice": 4, "tea": 3} trtm true
```

## 60.7 a real chain

Word statistics in one expression each — the shape most Rust data code takes:

```rust
fn main() {
    let text = "the borrow checker checks the borrows of the program";
    let words: Vec<&str> = text.split_whitespace().collect();
    let longest = words.iter().max_by_key(|w| w.len()).unwrap();
    let avg = words.iter().map(|w| w.len()).sum::<usize>() as f64 / words.len() as f64;
    let caps: Vec<String> = words
        .iter()
        .filter(|w| w.len() > 3)
        .map(|w| w[..1].to_uppercase() + &w[1..])
        .collect();
    let pairs: Vec<(&str, &str)> = words.windows(2).map(|p| (p[0], p[1])).filter(|(a, _)| *a == "the").collect();
    println!("{longest} {avg:.2}\n{:?}\n{:?}", caps, pairs);
}
```

*You should see:*

```text
program 4.89
["Borrow", "Checker", "Checks", "Borrows", "Program"]
[("the", "borrow"), ("the", "borrows"), ("the", "program")]
```

*(and it is fast: the compiler turns such chains into the same machine code as a hand-written
loop — "zero-cost abstractions")*
