---
id: rs-hashmap
title: HashMap: look up by key
part: rust
chapter: 55
minutes: 5
needs: [rs-string]
optional: no
---

## 55.4 HashMap: look up by key

`HashMap<K, V>` maps keys to values (Python's `dict`). It lives in `std::collections`:

```rust
use std::collections::HashMap;

fn main() {
    let mut phone: HashMap<String, String> = HashMap::new();
    phone.insert("Sara".into(), "050 111".into());
    phone.insert("Omar".into(), "055 222".into());
    println!("{:?}", phone.get("Sara"));
    println!("{:?}", phone.get("Zaid"));
    println!("{} {}", phone.len(), phone.contains_key("Omar"));
    phone.remove("Omar");
    println!("{}", phone.len());
}
```

*You should see:*

```text
Some("050 111")
None
2 true
1
```

The **entry** API is how you count and group — one lookup, inserting a starting value if the key
is new:

```rust
use std::collections::HashMap;

fn main() {
    let text = "the cat and the dog and the bird";
    let mut counts: HashMap<&str, u32> = HashMap::new();
    for w in text.split_whitespace() {
        *counts.entry(w).or_insert(0) += 1;
    }
    let mut pairs: Vec<(&str, u32)> = counts.into_iter().collect();
    pairs.sort_by(|a, b| b.1.cmp(&a.1).then(a.0.cmp(b.0)));
    println!("{:?}", pairs);

    let mut by_letter: HashMap<char, Vec<&str>> = HashMap::new();
    for w in ["apple", "avocado", "banana"] {
        by_letter.entry(w.chars().next().unwrap()).or_default().push(w);
    }
    println!("{:?}", by_letter[&'a']);
}
```

*You should see:*

```text
[("the", 3), ("and", 2), ("bird", 1), ("cat", 1), ("dog", 1)]
["apple", "avocado"]
```

*(a `HashMap` keeps no order — printing it directly shows a different order each run. Collect
into a `Vec` and sort, or use a `BTreeMap`)*
