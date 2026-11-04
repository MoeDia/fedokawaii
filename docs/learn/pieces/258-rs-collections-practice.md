---
id: rs-collections-practice
title: practice
part: rust
chapter: 55
minutes: 18
needs: [rs-maps-sets]
optional: no
---

**55.1 ★ Sum and average.** A `Vec<f64>` of five prices: print the sum, the average, and the largest (with `fold` or a loop).

<!-- solution 55.1 -->
```rust
fn main() {
    let v = vec![3.5, 12.0, 7.25, 9.0, 1.75];
    let sum: f64 = v.iter().sum();
    let max = v.iter().cloned().fold(f64::MIN, f64::max);
    println!("{sum} {} {max}", sum / v.len() as f64);
}
```

*You should see:*

```text
33.5 6.7 12
```
<!-- /solution -->

**55.2 ★ Reverse the words.** `"one two three"` → `"three two one"` with `split_whitespace`, `rev` and `join`.

<!-- solution 55.2 -->
```rust
fn main() {
    let s = "one two three";
    let r: Vec<&str> = s.split_whitespace().rev().collect();
    println!("{}", r.join(" "));
}
```

*You should see:*

```text
three two one
```
<!-- /solution -->

**55.3 ★ Capitals.** A `HashMap` of four countries and capitals; print the capital of Japan, and `unknown` for Peru.

<!-- solution 55.3 -->
```rust
use std::collections::HashMap;

fn main() {
    let caps = HashMap::from([("UAE", "Abu Dhabi"), ("Japan", "Tokyo"), ("Egypt", "Cairo"), ("France", "Paris")]);
    for c in ["Japan", "Peru"] {
        println!("{c}: {}", caps.get(c).unwrap_or(&"unknown"));
    }
}
```

*You should see:*

```text
Japan: Tokyo
Peru: unknown
```
<!-- /solution -->

**55.4 ★★ Letter frequency.** Count each letter of `"mississippi"` into a `BTreeMap<char, usize>` and print it.

<!-- solution 55.4 -->
```rust
use std::collections::BTreeMap;

fn main() {
    let mut m = BTreeMap::new();
    for c in "mississippi".chars() {
        *m.entry(c).or_insert(0usize) += 1;
    }
    println!("{:?}", m);
}
```

*You should see:*

```text
{'i': 4, 'm': 1, 'p': 2, 's': 4}
```
<!-- /solution -->

**55.5 ★★ Remove duplicates, keep order.** `fn unique(v: &[i32]) -> Vec<i32>` with a `HashSet` of seen values.

<!-- solution 55.5 -->
```rust
use std::collections::HashSet;

fn unique(v: &[i32]) -> Vec<i32> {
    let mut seen = HashSet::new();
    let mut out = Vec::new();
    for &x in v {
        if seen.insert(x) {
            out.push(x);
        }
    }
    out
}

fn main() {
    println!("{:?}", unique(&[3, 1, 3, 2, 1]));
}
```

*You should see:*

```text
[3, 1, 2]
```
<!-- /solution -->

**55.6 ★★ Palindrome.** `fn is_palindrome(s: &str) -> bool`, ignoring case and anything that is not a letter.
*Expected:* `"A man, a plan, a canal: Panama"` → `true`.

<!-- solution 55.6 -->
```rust
fn is_palindrome(s: &str) -> bool {
    let letters: Vec<char> = s.chars().filter(|c| c.is_alphanumeric()).flat_map(|c| c.to_lowercase()).collect();
    letters.iter().eq(letters.iter().rev())
}

fn main() {
    println!("{} {}", is_palindrome("A man, a plan, a canal: Panama"), is_palindrome("Rust"));
}
```

*You should see:*

```text
true false
```
<!-- /solution -->
