---
id: rs-collections-projects
title: projects
part: rust
chapter: 55
minutes: 180
needs: [rs-collections-practice]
optional: yes
---

**55.7 ★★★ Anagram groups.** Group `["listen", "silent", "enlist", "google", "gooegl", "cat"]` by their sorted letters in a
`BTreeMap<String, Vec<&str>>`.

<!-- solution 55.7 -->
```rust
use std::collections::BTreeMap;

fn main() {
    let words = ["listen", "silent", "enlist", "google", "gooegl", "cat"];
    let mut groups: BTreeMap<String, Vec<&str>> = BTreeMap::new();
    for w in words {
        let mut key: Vec<char> = w.chars().collect();
        key.sort();
        groups.entry(key.into_iter().collect()).or_default().push(w);
    }
    for g in groups.values() {
        println!("{:?}", g);
    }
}
```

*You should see:*

```text
["cat"]
["google", "gooegl"]
["listen", "silent", "enlist"]
```
<!-- /solution -->

**55.8 ★★★ Moving average.** With a `VecDeque<f64>` as a window of 3, print the moving average of `[1, 2, 3, 4, 5, 6]`.
*Expected:* `2 3 4 5`.

<!-- solution 55.8 -->
```rust
use std::collections::VecDeque;

fn main() {
    let mut w = VecDeque::new();
    for x in [1.0, 2.0, 3.0, 4.0, 5.0, 6.0] {
        w.push_back(x);
        if w.len() > 3 {
            w.pop_front();
        }
        if w.len() == 3 {
            print!("{} ", w.iter().sum::<f64>() / 3.0);
        }
    }
    println!();
}
```

*You should see:*

```text
2 3 4 5
```
<!-- /solution -->

**55.9 ★★★★ An inventory with history.** `struct Inventory { stock: BTreeMap<String, u32>, log: Vec<String> }` with `add(&mut self, item: &str,
n: u32)`, `take(&mut self, item: &str, n: u32) -> bool` (refusing to go below zero, logging the
refusal too), `low(&self, limit: u32) -> Vec<&str>`, and a report printing the stock and the log.

<!-- solution 55.9 -->
```rust
use std::collections::BTreeMap;

struct Inventory {
    stock: BTreeMap<String, u32>,
    log: Vec<String>,
}

impl Inventory {
    fn new() -> Self {
        Inventory { stock: BTreeMap::new(), log: Vec::new() }
    }
    fn add(&mut self, item: &str, n: u32) {
        *self.stock.entry(item.to_string()).or_insert(0) += n;
        self.log.push(format!("+{n} {item}"));
    }
    fn take(&mut self, item: &str, n: u32) -> bool {
        match self.stock.get_mut(item) {
            Some(have) if *have >= n => {
                *have -= n;
                self.log.push(format!("-{n} {item}"));
                true
            }
            _ => {
                self.log.push(format!("refused -{n} {item}"));
                false
            }
        }
    }
    fn low(&self, limit: u32) -> Vec<&str> {
        self.stock.iter().filter(|(_, n)| **n < limit).map(|(k, _)| k.as_str()).collect()
    }
}

fn main() {
    let mut inv = Inventory::new();
    inv.add("tea", 5);
    inv.add("rice", 2);
    inv.take("tea", 4);
    inv.take("rice", 3);
    println!("{:?}\n{:?}\n{:?}", inv.stock, inv.low(2), inv.log);
}
```

*You should see:*

```text
{"rice": 2, "tea": 1}
["tea"]
["+5 tea", "+2 rice", "-4 tea", "refused -3 rice"]
```
<!-- /solution -->
