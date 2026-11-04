---
id: rs-maps-sets
title: BTreeMap, HashSet, VecDeque
part: rust
chapter: 55
minutes: 7
needs: [rs-hashmap]
optional: no
---

## 55.5 BTreeMap: sorted keys

Same methods as `HashMap`, but the keys are kept sorted — so printing and looping give a stable
order:

```rust
use std::collections::BTreeMap;

fn main() {
    let mut stock = BTreeMap::new();
    for (item, n) in [("tea", 3), ("milk", 1), ("rice", 2), ("tea", 4)] {
        *stock.entry(item).or_insert(0) += n;
    }
    println!("{:?}", stock);
    for (item, n) in &stock {
        println!("{item:<5}{n:>3}");
    }
    println!("{:?}", stock.first_key_value());
}
```

*You should see:*

```text
{"milk": 1, "rice": 2, "tea": 7}
milk   1
rice   2
tea    7
Some(("milk", 1))
```

## 55.6 HashSet: unique values

```rust
use std::collections::HashSet;

fn main() {
    let visits = ["sara", "omar", "sara", "lina", "omar"];
    let unique: HashSet<&str> = visits.iter().copied().collect();
    println!("{}", unique.len());
    let a: HashSet<i32> = [1, 2, 3, 4].into();
    let b: HashSet<i32> = [3, 4, 5].into();
    let mut both: Vec<_> = a.intersection(&b).copied().collect();
    both.sort();
    let mut either: Vec<_> = a.union(&b).copied().collect();
    either.sort();
    println!("{:?} {:?} {}", both, either, a.contains(&2));
}
```

*You should see:*

```text
3
[3, 4] [1, 2, 3, 4, 5] true
```

## 55.7 VecDeque: a queue

A `VecDeque` adds and removes at **both** ends quickly — a queue of jobs, a sliding window:

```rust
use std::collections::VecDeque;

fn main() {
    let mut queue = VecDeque::new();
    queue.push_back("first");
    queue.push_back("second");
    queue.push_front("urgent");
    while let Some(job) = queue.pop_front() {
        println!("doing {job}");
    }
}
```

*You should see:*

```text
doing urgent
doing first
doing second
```

*(`while let Some(x) = …` loops as long as the pattern matches: here, until the queue is empty)*

## 55.8 common mistakes

**1. Indexing past the end** panics: `v[10]` on a 3-item Vec. Use `v.get(10)` when the index
might be outside.

**2. Holding a reference while changing the collection** — chapter 52's rule. Finish reading
first, or collect what you need into a new value.

**3. Slicing a `String` by letters.** `&s[0..3]` is three *bytes*. Use `.chars()`.

**4. Expecting order from a `HashMap`.** Use `BTreeMap`, or sort.
