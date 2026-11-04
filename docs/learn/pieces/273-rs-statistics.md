---
id: rs-statistics
title: checkpoint: a generic statistics library
part: rust
chapter: 58
minutes: 40
needs: [rs-static]
optional: no
---

## 58.7 checkpoint project — a generic statistics library

Level 4 in one: a trait with default methods, generics with bounds, `Display`, and a function that
borrows from its input with an explicit lifetime.

```rust
use std::fmt;

trait Stats {
    fn values(&self) -> Vec<f64>;

    fn mean(&self) -> Option<f64> {
        let v = self.values();
        if v.is_empty() { None } else { Some(v.iter().sum::<f64>() / v.len() as f64) }
    }

    fn median(&self) -> Option<f64> {
        let mut v = self.values();
        if v.is_empty() {
            return None;
        }
        v.sort_by(|a, b| a.total_cmp(b));
        let m = v.len() / 2;
        Some(if v.len() % 2 == 0 { (v[m - 1] + v[m]) / 2.0 } else { v[m] })
    }
}

struct Series<T> {
    name: String,
    data: Vec<T>,
}

impl<T: Into<f64> + Copy> Stats for Series<T> {
    fn values(&self) -> Vec<f64> {
        self.data.iter().map(|&x| x.into()).collect()
    }
}

impl<T: Into<f64> + Copy> fmt::Display for Series<T> {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match (self.mean(), self.median()) {
            (Some(a), Some(m)) => write!(f, "{}: n={} mean={a:.2} median={m:.2}", self.name, self.data.len()),
            _ => write!(f, "{}: empty", self.name),
        }
    }
}

fn top<'a, T: PartialOrd>(items: &'a [T], n: usize) -> Vec<&'a T> {
    let mut refs: Vec<&T> = items.iter().collect();
    refs.sort_by(|a, b| b.partial_cmp(a).unwrap());
    refs.truncate(n);
    refs
}

fn main() {
    let temps = Series { name: "temps".into(), data: vec![31.5_f32, 28.0, 35.25, 33.0] };
    let steps = Series { name: "steps".into(), data: vec![8000_u32, 12000, 4000] };
    let none: Series<u8> = Series { name: "none".into(), data: vec![] };
    println!("{temps}\n{steps}\n{none}");
    println!("{:?}", top(&steps.data, 2));
}
```

*You should see:*

```text
temps: n=4 mean=31.94 median=32.25
steps: n=3 mean=8000.00 median=8000.00
none: empty
[12000, 8000]
```

*(`T: Into<f64>` accepts any number type that converts to `f64` without loss — `f32`, `u32`,
`u8`, `i32` …; `Series<f64>` works too)*

> **Checkpoint.** Add `std_dev` and `min_max` as default methods of `Stats`; implement `Stats`
> for a plain `Vec<f64>` too; and add a `fn longest_name<'a>(a: &'a Series<f64>, b: &'a Series<f64>) -> &'a str`.
> Level 4 done: you can read almost any Rust library's signatures now.
